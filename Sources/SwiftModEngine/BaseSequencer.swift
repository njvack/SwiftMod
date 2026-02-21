import Foundation
import SwiftModCore

public class BaseSequencer: @unchecked Sendable {
    public let module: Module

    // Position
    private(set) public var orderIndex: Int = 0
    private(set) public var rowIndex: Int = 0
    public var tick: Int = 0

    // Timing
    public var speed: Int = 0
    private(set) public var tempo: Int = 0

    // Channel state (public set: mixer writes back sample positions)
    public var channels: [ChannelState] = []

    // Playback status
    private(set) public var isFinished: Bool = false

    // Pattern delay
    private var patternDelayCount: Int = 0

    // Samples per tick (cached, recomputed when tempo changes)
    private(set) public var samplesPerTick: Int = 0
    private let sampleRate: Int

    // Row change notification — fires on audio thread, suppressed during seek
    public var onRow: ((Int, Int) -> Void)?
    private var isSeeking: Bool = false

    // Sine table for vibrato/tremolo (64 entries, 0..255)
    private static let sineTable: [Int] = {
        var table = [Int](repeating: 0, count: 64)
        for i in 0..<64 {
            table[i] = Int(sin(Double(i) * .pi / 32.0) * 255.0)
        }
        return table
    }()

    public init(module: Module, sampleRate: Int = 44100) {
        self.module = module
        self.sampleRate = sampleRate
        reset()
    }

    // Resets all mutable playback state to initial values and processes row 0.
    private func reset() {
        orderIndex = 0
        rowIndex = 0
        tick = 0
        isFinished = false
        patternDelayCount = 0
        speed = module.initialSpeed
        tempo = module.initialTempo
        samplesPerTick = BaseSequencer.computeSamplesPerTick(tempo: module.initialTempo, sampleRate: sampleRate)

        var chans = [ChannelState]()
        for i in 0..<module.channelCount {
            var ch = ChannelState()
            if i < module.defaultPanning.count {
                ch.panning = module.defaultPanning[i]
            }
            chans.append(ch)
        }
        channels = chans

        processRow()
    }

    /// Seek to the given order/row by replaying from the start (correctly rebuilds channel state).
    /// Distinct from Bxx positionJump, which jumps orderIndex directly without resetting state.
    public func seek(toOrder targetOrder: Int, row targetRow: Int = 0) {
        isSeeking = true
        reset()
        while !isFinished {
            if orderIndex > targetOrder { break }
            if orderIndex == targetOrder && rowIndex >= targetRow { break }
            advanceTick()
        }
        isSeeking = false
    }

    public static func computeSamplesPerTick(tempo: Int, sampleRate: Int) -> Int {
        Int(Double(sampleRate) * 2.5 / Double(tempo))
    }

    // MARK: - Advance

    public func advanceTick() {
        guard !isFinished else { return }

        tick += 1

        if tick >= speed {
            tick = 0

            // Handle pattern delay
            if patternDelayCount > 0 {
                patternDelayCount -= 1
                processRow()
                return
            }

            // Advance to next row
            rowIndex += 1
            let pattern = currentPattern
            if rowIndex >= pattern.rowCount {
                advanceOrder()
                if isFinished { return }
            }
            processRow()
        } else {
            processTickN()
        }
    }

    // MARK: - Pattern Navigation

    private var currentPattern: Pattern {
        let patternIndex = module.patternOrder[orderIndex]
        return module.patterns[patternIndex]
    }

    private func advanceOrder() {
        orderIndex += 1
        rowIndex = 0
        if orderIndex >= module.patternOrder.count {
            isFinished = true
        }
    }

    // MARK: - Row Processing (tick 0)

    private func processRow() {
        let pattern = currentPattern
        guard rowIndex < pattern.rowCount else { return }
        let row = pattern.rows[rowIndex]

        for ch in 0..<min(row.count, channels.count) {
            let note = row[ch]

            // Reset per-tick offsets at start of each row
            channels[ch].vibratoOffset = 0
            channels[ch].tremoloOffset = 0

            // Restore base period if arpeggio was active on previous row
            if channels[ch].arpeggioBasePeriod > 0 {
                channels[ch].period = channels[ch].arpeggioBasePeriod
                channels[ch].arpeggioBasePeriod = 0
            }

            processNote(note, channel: ch)
            channels[ch].currentEffect = note.effect
        }

        if !isSeeking { onRow?(orderIndex, rowIndex) }
    }

    func processNote(_ note: Note, channel ch: Int) {
        // Check for note delay — suppress tick-0 trigger
        if let effect = note.effect,
           case .noteDelay(let delayTick) = effect,
           delayTick > 0 {
            // Store effect memory but don't trigger note or instrument
            channels[ch].delayedInstrument = note.instrument
            channels[ch].delayedPeriod = note.period
            processEffect(effect, channel: ch)
            return
        }

        // Instrument change
        if let inst = note.instrument, inst >= 1, inst <= module.instruments.count {
            let instrument = module.instruments[inst - 1]
            channels[ch].instrumentIndex = inst - 1
            channels[ch].sampleIndex = 0
            channels[ch].volume = instrument.samples.first?.volume ?? 64
        }

        // Note trigger (period set)
        let isTonePorta = isTonePortamento(note.effect)
        if let period = note.period, period > 0 {
            if isTonePorta {
                channels[ch].targetPeriod = period
            } else {
                channels[ch].period = period
                channels[ch].targetPeriod = period
                channels[ch].samplePosition = 0.0
                channels[ch].playing = true
                // Reset vibrato/tremolo position unless waveform bit 2 is set
                if !channels[ch].vibratoNoRetrigger {
                    channels[ch].vibratoPosition = 0
                }
                if !channels[ch].tremoloNoRetrigger {
                    channels[ch].tremoloPosition = 0
                }
            }
        }

        // Volume column
        if let vol = note.volume {
            channels[ch].volume = clampVolume(vol)
        }

        // Effects (tick 0)
        if let effect = note.effect {
            processEffect(effect, channel: ch)
        }
    }

    private func isTonePortamento(_ effect: Effect?) -> Bool {
        guard let effect else { return false }
        switch effect {
        case .tonePortamento, .tonePortamentoVolumeSlide: return true
        default: return false
        }
    }

    // MARK: - Effect Processing (tick 0)

    func processEffect(_ effect: Effect, channel ch: Int) {
        switch effect {
        case .setSpeed(let speed):
            self.speed = max(speed, 1)

        case .setTempo(let bpm):
            self.tempo = bpm
            self.samplesPerTick = BaseSequencer.computeSamplesPerTick(tempo: bpm, sampleRate: sampleRate)

        case .setVolume(let vol):
            channels[ch].volume = clampVolume(vol)

        case .positionJump(let order):
            if order < module.patternOrder.count {
                orderIndex = order
                rowIndex = 0
                tick = 0
                processRow()
            } else {
                isFinished = true
            }

        case .patternBreak(let row):
            advanceOrder()
            if !isFinished {
                let pattern = currentPattern
                rowIndex = min(row, pattern.rowCount - 1)
                processRow()
            }

        case .sampleOffset(let offset):
            let byteOffset = offset * 256
            if offset != 0 {
                channels[ch].sampleOffsetMemory = byteOffset
            }
            let effectiveOffset = offset != 0 ? byteOffset : channels[ch].sampleOffsetMemory
            channels[ch].samplePosition = Float(effectiveOffset)

        case .slideUp(let speed):
            if speed != 0 { channels[ch].slideUpSpeed = speed }

        case .slideDown(let speed):
            if speed != 0 { channels[ch].slideDownSpeed = speed }

        case .tonePortamento(let speed):
            if speed != 0 { channels[ch].tonePortaSpeed = speed }

        case .vibrato(let speed, let depth):
            if speed != 0 { channels[ch].vibratoSpeed = speed }
            if depth != 0 { channels[ch].vibratoDepth = depth }

        case .tremolo(let speed, let depth):
            if speed != 0 { channels[ch].tremoloSpeed = speed }
            if depth != 0 { channels[ch].tremoloDepth = depth }

        case .volumeSlide(let upDown):
            if upDown != 0 { channels[ch].volumeSlideSpeed = upDown }

        case .tonePortamentoVolumeSlide(let upDown):
            if upDown != 0 { channels[ch].volumeSlideSpeed = upDown }

        case .vibratoVolumeSlide(let upDown):
            if upDown != 0 { channels[ch].volumeSlideSpeed = upDown }

        case .arpeggio(let x, let y):
            channels[ch].arpeggioX = x
            channels[ch].arpeggioY = y
            channels[ch].arpeggioBasePeriod = channels[ch].period

        case .fineSlideUp(let amount):
            if amount > 0 {
                channels[ch].period = max(channels[ch].period - amount, minPeriod)
            }

        case .fineSlideDown(let amount):
            if amount > 0 {
                channels[ch].period = min(channels[ch].period + amount, maxPeriod)
            }

        case .fineVolumeSlideUp(let amount):
            channels[ch].volume = clampVolume(channels[ch].volume + amount)

        case .fineVolumeSlideDown(let amount):
            channels[ch].volume = clampVolume(channels[ch].volume - amount)

        case .setPanning(let value):
            channels[ch].panning = value

        case .setVibratoWaveform(let waveform):
            channels[ch].vibratoWaveform = WaveformType(rawValue: waveform & 3) ?? .sine
            channels[ch].vibratoNoRetrigger = waveform & 4 != 0

        case .setTremoloWaveform(let waveform):
            channels[ch].tremoloWaveform = WaveformType(rawValue: waveform & 3) ?? .sine
            channels[ch].tremoloNoRetrigger = waveform & 4 != 0

        case .patternDelay(let rows):
            if patternDelayCount == 0 {
                patternDelayCount = rows
            }

        case .patternLoop(let count):
            if count == 0 {
                channels[ch].patternLoopRow = rowIndex
            } else {
                if channels[ch].patternLoopCount == 0 {
                    channels[ch].patternLoopCount = count
                    rowIndex = channels[ch].patternLoopRow - 1
                } else {
                    channels[ch].patternLoopCount -= 1
                    if channels[ch].patternLoopCount > 0 {
                        rowIndex = channels[ch].patternLoopRow - 1
                    }
                }
            }

        case .retrigNote(let interval):
            if interval != 0 { channels[ch].retrigInterval = interval }

        case .noteDelay:
            break // Handled in processNote; memory is the note itself

        case .noteCut:
            break // Only fires on tick N (handled in processTickN)

        case .setFilter, .glissandoControl, .setFinetune:
            break

        default:
            break
        }
    }

    // MARK: - Tick N Processing (ticks 1+)

    func processTickN() {
        for ch in 0..<channels.count {
            guard let effect = channels[ch].currentEffect else { continue }
            processTickNEffect(effect, channel: ch)
        }
    }

    func processTickNEffect(_ effect: Effect, channel ch: Int) {
        switch effect {
        case .slideUp:
            channels[ch].period = max(channels[ch].period - channels[ch].slideUpSpeed, minPeriod)

        case .slideDown:
            channels[ch].period = min(channels[ch].period + channels[ch].slideDownSpeed, maxPeriod)

        case .tonePortamento:
            doTonePortamento(channel: ch)

        case .tonePortamentoVolumeSlide:
            doTonePortamento(channel: ch)
            doVolumeSlide(channel: ch)

        case .vibrato:
            doVibrato(channel: ch)

        case .vibratoVolumeSlide:
            doVibrato(channel: ch)
            doVolumeSlide(channel: ch)

        case .tremolo:
            doTremolo(channel: ch)

        case .volumeSlide:
            doVolumeSlide(channel: ch)

        case .arpeggio:
            doArpeggio(channel: ch)

        case .noteCut(let cutTick):
            if tick == cutTick {
                channels[ch].volume = 0
            }

        case .noteDelay(let delayTick):
            if tick == delayTick {
                // Now trigger the delayed note
                if let inst = channels[ch].delayedInstrument, inst >= 1, inst <= module.instruments.count {
                    channels[ch].instrumentIndex = inst - 1
                    channels[ch].sampleIndex = 0
                    channels[ch].volume = module.instruments[inst - 1].samples.first?.volume ?? 64
                }
                if let period = channels[ch].delayedPeriod, period > 0 {
                    channels[ch].period = period
                    channels[ch].targetPeriod = period
                    channels[ch].arpeggioBasePeriod = period
                    channels[ch].samplePosition = 0.0
                    channels[ch].playing = true
                }
            }

        case .retrigNote:
            let interval = channels[ch].retrigInterval
            if interval > 0 && tick % interval == 0 {
                channels[ch].samplePosition = 0.0
            }

        default:
            break
        }
    }

    // MARK: - Effect Helpers

    private func doTonePortamento(channel ch: Int) {
        let target = channels[ch].targetPeriod
        let speed = channels[ch].tonePortaSpeed
        guard target > 0 else { return }

        if channels[ch].period < target {
            channels[ch].period = min(channels[ch].period + speed, target)
        } else if channels[ch].period > target {
            channels[ch].period = max(channels[ch].period - speed, target)
        }
    }

    private func doVolumeSlide(channel ch: Int) {
        let param = channels[ch].volumeSlideSpeed
        let up = param >> 4
        let down = param & 0x0F
        if up > 0 {
            channels[ch].volume = clampVolume(channels[ch].volume + up)
        } else {
            channels[ch].volume = clampVolume(channels[ch].volume - down)
        }
    }

    private func doVibrato(channel ch: Int) {
        let delta = waveformValue(
            position: channels[ch].vibratoPosition,
            waveform: channels[ch].vibratoWaveform,
            depth: channels[ch].vibratoDepth
        )
        channels[ch].vibratoOffset = delta
        channels[ch].vibratoPosition = (channels[ch].vibratoPosition + channels[ch].vibratoSpeed) & 63
    }

    private func doTremolo(channel ch: Int) {
        let delta = waveformValue(
            position: channels[ch].tremoloPosition,
            waveform: channels[ch].tremoloWaveform,
            depth: channels[ch].tremoloDepth
        )
        channels[ch].tremoloOffset = delta
        channels[ch].tremoloPosition = (channels[ch].tremoloPosition + channels[ch].tremoloSpeed) & 63
    }

    /// Compute a signed waveform value for vibrato/tremolo.
    /// Returns a value in roughly -depth..+depth range.
    private func waveformValue(position: Int, waveform: WaveformType, depth: Int) -> Int {
        let pos = position & 63

        let amplitude: Int
        switch waveform {
        case .sine:
            amplitude = BaseSequencer.sineTable[pos]
        case .rampDown:
            // 0 at pos 0, ramps to 255 at pos 31, then -256 at 32, ramps to -1 at 63
            if pos < 32 {
                amplitude = pos * 8
            } else {
                amplitude = (pos - 64) * 8
            }
        case .square:
            amplitude = pos < 32 ? 255 : -255
        case .random:
            amplitude = Int.random(in: -255...255)
        }

        return (amplitude * depth) / 128
    }

    private func doArpeggio(channel ch: Int) {
        let basePeriod = channels[ch].arpeggioBasePeriod
        guard basePeriod > 0 else { return }

        let step = tick % 3
        switch step {
        case 0:
            channels[ch].period = basePeriod
        case 1:
            channels[ch].period = periodForSemitoneOffset(basePeriod: basePeriod, semitones: channels[ch].arpeggioX)
        case 2:
            channels[ch].period = periodForSemitoneOffset(basePeriod: basePeriod, semitones: channels[ch].arpeggioY)
        default:
            break
        }
    }

    private func periodForSemitoneOffset(basePeriod: Int, semitones: Int) -> Int {
        guard semitones > 0 else { return basePeriod }
        let factor = pow(2.0, -Double(semitones) / 12.0)
        return max(Int(Double(basePeriod) * factor), minPeriod)
    }

    private func clampVolume(_ v: Int) -> Int {
        max(0, min(64, v))
    }
}
