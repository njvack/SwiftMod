import Foundation
import SwiftModCore
import SwiftModFormats
import ModCLI

let noteNames = ["C-", "C#", "D-", "D#", "E-", "F-", "F#", "G-", "G#", "A-", "A#", "B-"]

func noteDisplayName(_ noteValue: NoteValue) -> String {
    switch noteValue {
    case .note(let index):
        let name = noteNames[index % 12]
        let octave = index / 12 + 2  // Standard display convention: PT octave 1 = display octave 2
        return "\(name)\(octave)"
    case .noteOff:
        return "==="
    case .noteCut:
        return "^^^"
    case .noteFade:
        return "~~~"
    }
}

func effectLetter(_ rawEffect: UInt8) -> Character {
    if rawEffect <= 9 {
        return Character(String(rawEffect))
    } else {
        return Character(UnicodeScalar(UInt8(ascii: "A") + rawEffect - 10))
    }
}

func formatNote(_ note: Note) -> String {
    // Note name + period
    let notePart: String
    if let nv = note.noteValue, let period = note.period {
        let name = noteDisplayName(nv)
        notePart = "\(name)(\(String(format: "%3d", period)))"
    } else if let period = note.period {
        notePart = "???(\(String(format: "%3d", period)))"
    } else {
        notePart = "...     "
    }

    // Instrument
    let instPart: String
    if let inst = note.instrument, inst > 0 {
        instPart = String(format: "%02X", inst)
    } else {
        instPart = ".."
    }

    // Effect
    let effectPart: String
    if let rawEff = note.rawEffect, let rawParam = note.rawEffectParam,
       !(rawEff == 0 && rawParam == 0) {
        let letter = effectLetter(rawEff)
        effectPart = "\(letter)\(String(format: "%02X", rawParam))"
    } else {
        effectPart = "..."
    }

    return "\(notePart) \(instPart) \(effectPart)"
}

// Main
let cli = CLIArgs.parse(usage:
    "Usage: modpattern <file.mod> [--start-order N] [--end-order N] [--start-row N] [--end-row N]")

let orderStart = cli.startOrder
let orderEnd: Int? = cli.endOrder == Int.max ? nil : cli.endOrder
let rowStart = cli.startRow
let rowEnd: Int? = cli.endRow == Int.max ? nil : cli.endRow

do {
    let url = URL(fileURLWithPath: cli.inputPath)
    let data = try Data(contentsOf: url)
    let module = try MODLoader.load(data)

    let lastOrder = orderEnd ?? (module.patternOrder.count - 1)

    for orderIndex in orderStart...lastOrder {
        guard orderIndex < module.patternOrder.count else { break }
        let patternIndex = module.patternOrder[orderIndex]
        guard patternIndex < module.patterns.count else { continue }
        let pattern = module.patterns[patternIndex]

        print("--- Order \(orderIndex) (Pattern \(patternIndex)) ---")

        // Header
        var header = "Row"
        for ch in 1...module.channelCount {
            header += " | Ch\(ch)           "
        }
        print(header)

        let lastRow = min(rowEnd ?? (pattern.rowCount - 1), pattern.rowCount - 1)

        for row in rowStart...lastRow {
            var line = String(format: "%02d ", row)
            for ch in 0..<module.channelCount {
                let note = pattern.rows[row][ch]
                line += " | \(formatNote(note))"
            }
            print(line)
        }
        print()
    }
} catch {
    print("Error: \(error)")
    exit(1)
}
