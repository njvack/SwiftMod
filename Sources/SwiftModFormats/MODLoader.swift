import Foundation
import SwiftModCore

public struct MODLoader: FormatLoader {

    // Known format tags at offset 1080
    private static let tagInfo: [String: Int] = [
        "M.K.": 4, "M!K!": 4, "FLT4": 4,
        "6CHN": 6,
        "8CHN": 8, "FLT8": 8, "OCTA": 8,
    ]

    public static func identify(_ data: Data) -> Int {
        guard data.count >= 1084 else { return 0 }

        let tagBytes = data[1080..<1084]
        if let tag = String(bytes: tagBytes, encoding: .ascii) {
            if tagInfo[tag] != nil { return 100 }
            // Check for xxCH pattern (e.g. "16CH", "32CH")
            if tag.hasSuffix("CH"), let n = Int(tag.prefix(2)), n > 0, n <= 32 {
                return 100
            }
        }

        return 0
    }

    public static func load(_ data: Data) throws -> Module {
        var reader = BinaryReader(data: data)

        // Detect format
        guard data.count >= 1084 else { throw FormatError.truncatedFile }
        let tagBytes = data[1080..<1084]
        guard let tag = String(bytes: tagBytes, encoding: .ascii) else {
            throw FormatError.unrecognizedFormat
        }

        let channelCount: Int
        if let ch = tagInfo[tag] {
            channelCount = ch
        } else if tag.hasSuffix("CH"), let n = Int(tag.prefix(2)), n > 0 {
            channelCount = n
        } else {
            throw FormatError.unrecognizedFormat
        }

        // Song title (20 bytes)
        let title = try reader.readASCII(20)

        // 31 sample headers
        var sampleHeaders: [(name: String, length: Int, finetune: Int, volume: Int, loopStart: Int, loopLength: Int)] = []
        for _ in 0..<31 {
            let name = try reader.readASCII(22)
            let lengthWords = try reader.readUInt16BE()
            let finetuneByte = try reader.readUInt8()
            let volume = try reader.readUInt8()
            let loopStartWords = try reader.readUInt16BE()
            let loopLengthWords = try reader.readUInt16BE()

            sampleHeaders.append((
                name: name,
                length: Int(lengthWords) * 2,
                finetune: Int(finetuneByte & 0x0F),
                volume: min(Int(volume), 64),
                loopStart: Int(loopStartWords) * 2,
                loopLength: Int(loopLengthWords) * 2
            ))
        }

        // Song length
        let songLength = Int(try reader.readUInt8())

        // Restart position
        let restartPosition = Int(try reader.readUInt8())

        // Pattern order table (128 bytes)
        var patternOrder: [Int] = []
        for _ in 0..<128 {
            patternOrder.append(Int(try reader.readUInt8()))
        }

        // Skip the format tag (already read)
        reader.skip(4)

        // Determine pattern count
        let usedOrders = Array(patternOrder.prefix(songLength))
        let patternCount = (usedOrders.max() ?? 0) + 1

        // Read patterns
        var patterns: [Pattern] = []

        for _ in 0..<patternCount {
            var rows: [[Note]] = []
            for _ in 0..<64 {
                var row: [Note] = []
                for _ in 0..<channelCount {
                    let noteData = try reader.readBytes(4)
                    let note = decodeNote(noteData)
                    row.append(note)
                }
                rows.append(row)
            }
            patterns.append(Pattern(rowCount: 64, rows: rows))
        }

        // Read sample data and build instruments
        var instruments: [Instrument] = []
        for header in sampleHeaders {
            let sampleData: SampleData
            if header.length > 0 {
                let availableBytes = min(header.length, reader.remaining)
                if availableBytes > 0 {
                    let pcmData = try reader.readInt8Array(availableBytes)
                    sampleData = .int8(pcmData)
                } else {
                    sampleData = .int8([])
                }
            } else {
                sampleData = .int8([])
            }

            let loop: Loop?
            if header.loopLength > 2 {
                loop = Loop(
                    start: header.loopStart,
                    length: header.loopLength,
                    type: .forward
                )
            } else {
                loop = nil
            }

            let sample = Sample(
                name: header.name,
                data: sampleData,
                sampleRate: 8363,
                volume: header.volume,
                loop: loop,
                finetune: finetuneToSigned(header.finetune)
            )

            // Identity key-to-sample map: all notes use sample 0
            let keyMap = [Int](repeating: 0, count: 120)

            let instrument = Instrument(
                name: header.name,
                samples: [sample],
                keyToSampleMap: keyMap
            )
            instruments.append(instrument)
        }

        // Format hints
        let hints = FormatHints(
            sourceFormat: .mod,
            frequencyModel: .amigaPeriods,
            amigaLimits: true
        )

        // Default panning: hard left/right Amiga style (LRRL)
        var panning = [Int](repeating: 128, count: channelCount)
        for i in 0..<channelCount {
            switch i % 4 {
            case 0, 3: panning[i] = 64   // left
            case 1, 2: panning[i] = 192  // right
            default: break
            }
        }

        return Module(
            title: title,
            formatDescription: "ProTracker MOD (\(tag))",
            channelCount: channelCount,
            patternOrder: usedOrders,
            restartPosition: restartPosition,
            patterns: patterns,
            instruments: instruments,
            formatHints: hints
        )
    }

    // MARK: - Note Decoding

    private static func decodeNote(_ data: Data) -> Note {
        let b0 = data[data.startIndex]
        let b1 = data[data.startIndex + 1]
        let b2 = data[data.startIndex + 2]
        let b3 = data[data.startIndex + 3]

        // Sample number: upper 4 bits of byte 0 + upper 4 bits of byte 2
        let sampleNum = Int(b0 & 0xF0) | Int(b2 >> 4)

        // Period: lower 4 bits of byte 0 + all of byte 1
        let period = Int(b0 & 0x0F) << 8 | Int(b1)

        // Effect: lower 4 bits of byte 2 = effect command, byte 3 = parameter
        let effectCmd = Int(b2 & 0x0F)
        let effectParam = Int(b3)

        let noteValue = periodToNote(period: period)
        let storePeriod = period > 0 ? period : nil
        let instrument = sampleNum > 0 ? sampleNum : nil
        let effect = decodeEffect(command: effectCmd, param: effectParam)

        let rawEff: UInt8? = (effectCmd != 0 || effectParam != 0) ? UInt8(effectCmd) : nil
        let rawParam: UInt8? = (effectCmd != 0 || effectParam != 0) ? UInt8(effectParam) : nil

        return Note(
            noteValue: noteValue,
            period: storePeriod,
            instrument: instrument,
            effect: effect,
            rawEffect: rawEff,
            rawEffectParam: rawParam
        )
    }

    // command is a 4-bit value (0..F), param is a full byte (0..FF)
    private static func decodeEffect(command: Int, param: Int) -> Effect? {
        assert(command >= 0 && command <= 0xF, "MOD effect command must be 0..F")
        assert(param >= 0 && param <= 0xFF, "MOD effect param must be 0..FF")
        let x = param >> 4
        let y = param & 0x0F

        switch command {
        case 0x0:
            if param != 0 {
                return .arpeggio(x: x, y: y)
            }
            return nil
        case 0x1: return .slideUp(speed: param)
        case 0x2: return .slideDown(speed: param)
        case 0x3: return .tonePortamento(speed: param)
        case 0x4: return .vibrato(speed: x, depth: y)
        case 0x5: return .tonePortamentoVolumeSlide(upDown: param)
        case 0x6: return .vibratoVolumeSlide(upDown: param)
        case 0x7: return .tremolo(speed: x, depth: y)
        case 0x8: return .setPanning(value: param)
        case 0x9: return .sampleOffset(offset: param)
        case 0xA: return .volumeSlide(upDown: param)
        case 0xB: return .positionJump(order: param)
        case 0xC: return .setVolume(volume: param)
        case 0xD: return .patternBreak(row: x * 10 + y)  // BCD encoding
        case 0xE: return decodeExtendedEffect(x: x, y: y)
        case 0xF:
            if param == 0 { return nil }
            if param <= 32 { return .setSpeed(speed: param) }
            return .setTempo(bpm: param)
        default: return nil
        }
    }

    private static func decodeExtendedEffect(x: Int, y: Int) -> Effect? {
        switch x {
        case 0x0: return .setFilter(on: y == 0)
        case 0x1: return .fineSlideUp(amount: y)
        case 0x2: return .fineSlideDown(amount: y)
        case 0x3: return .glissandoControl(on: y != 0)
        case 0x4: return .setVibratoWaveform(waveform: y)
        case 0x5: return .setFinetune(value: y)
        case 0x6: return .patternLoop(count: y)
        case 0x7: return .setTremoloWaveform(waveform: y)
        case 0x9: return .retrigNote(interval: y)
        case 0xA: return .fineVolumeSlideUp(amount: y)
        case 0xB: return .fineVolumeSlideDown(amount: y)
        case 0xC: return .noteCut(tick: y)
        case 0xD: return .noteDelay(tick: y)
        case 0xE: return .patternDelay(rows: y)
        default: return nil
        }
    }
}
