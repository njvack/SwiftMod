import Foundation
import SwiftModCore

public struct NoteEvent: Sendable {
    public let channel: Int
    public let period: Int
    public let instrument: Int  // 1-based instrument index
    public let effect: Effect?

    public init(channel: Int, period: Int, instrument: Int, effect: Effect? = nil) {
        self.channel = channel
        self.period = period
        self.instrument = instrument
        self.effect = effect
    }
}

public struct ReleaseEvent: Sendable {
    public let channel: Int

    public init(channel: Int) {
        self.channel = channel
    }
}

public class LiveSequencer: BaseSequencer, @unchecked Sendable {
    private let lock = NSLock()
    private var pendingNotes: [NoteEvent] = []
    private var pendingReleases: [ReleaseEvent] = []

    public override init(module: Module, sampleRate: Int = 44100) {
        super.init(module: module, sampleRate: sampleRate)
        // Silence all channels — super.init triggers row 0 from the pattern
        for ch in 0..<channels.count {
            channels[ch].playing = false
            channels[ch].volume = 0
            channels[ch].period = 0
            channels[ch].currentEffect = nil
        }
        tick = 0
    }

    public func setTempo(_ bpm: Int) {
        processEffect(.setTempo(bpm: bpm), channel: 0)
    }

    public func triggerNote(_ event: NoteEvent) {
        lock.lock()
        pendingNotes.append(event)
        lock.unlock()
    }

    public func releaseNote(_ event: ReleaseEvent) {
        lock.lock()
        pendingReleases.append(event)
        lock.unlock()
    }

    public override func advanceTick() {
        // Dequeue events
        lock.lock()
        let notes = pendingNotes
        let releases = pendingReleases
        pendingNotes.removeAll()
        pendingReleases.removeAll()
        lock.unlock()

        // Process releases
        for release in releases {
            let ch = release.channel
            guard ch >= 0, ch < channels.count else { continue }
            channels[ch].playing = false
            channels[ch].currentEffect = nil
            channels[ch].channelTick = 0
        }

        // Trigger new notes immediately — this is tick 0 of a new "row"
        for event in notes {
            let ch = event.channel
            guard ch >= 0, ch < channels.count else { continue }

            let note = Note(
                period: event.period,
                instrument: event.instrument,
                effect: event.effect
            )
            channels[ch].vibratoOffset = 0
            channels[ch].tremoloOffset = 0
            if channels[ch].arpeggioBasePeriod > 0 {
                channels[ch].period = channels[ch].arpeggioBasePeriod
                channels[ch].arpeggioBasePeriod = 0
            }
            processNote(note, channel: ch)
            channels[ch].currentEffect = event.effect
            channels[ch].channelTick = 0
            channels[ch].channelRow = 0
        }

        // Advance per-channel ticks and run effects for playing channels.
        // Each channel runs its own row cycle: tick 0 = row start, ticks 1..speed-1 = effects.
        // At the row boundary, tick-0 processing re-applies the effect without retriggering
        // the note — like a tracker row with "--- -- <effect>" (effect continuation).
        for ch in 0..<channels.count {
            guard channels[ch].playing else { continue }

            channels[ch].channelTick += 1

            if channels[ch].channelTick >= speed {
                // Row boundary: reset per-row state, re-apply tick-0 effect
                channels[ch].channelTick = 0
                channels[ch].channelRow += 1
                channels[ch].vibratoOffset = 0
                channels[ch].tremoloOffset = 0
                if channels[ch].arpeggioBasePeriod > 0 {
                    channels[ch].period = channels[ch].arpeggioBasePeriod
                    channels[ch].arpeggioBasePeriod = 0
                }
                if let effect = channels[ch].currentEffect {
                    // Re-process effect as tick-0 (effect-only, no note retrigger)
                    let effectOnly = Note(effect: effect)
                    processNote(effectOnly, channel: ch)
                }
            } else if let effect = channels[ch].currentEffect {
                // Ticks 1..speed-1: run tick-N effects
                tick = channels[ch].channelTick
                processTickNEffect(effect, channel: ch)
            }
        }
    }
}
