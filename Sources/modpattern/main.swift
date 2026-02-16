import Foundation
import SwiftModCore
import SwiftModFormats

let noteNames = ["C-", "C#", "D-", "D#", "E-", "F-", "F#", "G-", "G#", "A-", "A#", "B-"]

func printUsage() {
    print("Usage: modpattern <file.mod> [order_start[:order_end]] [row_start[:row_end]]")
    print()
    print("Examples:")
    print("  modpattern foo.mod          All orders, all rows")
    print("  modpattern foo.mod 3        Order 3 only")
    print("  modpattern foo.mod 0:5      Orders 0-5")
    print("  modpattern foo.mod 0 0:15   Order 0, rows 0-15")
}

func parseRange(_ arg: String) -> (Int, Int?) {
    let parts = arg.split(separator: ":", maxSplits: 1)
    let start = Int(parts[0])!
    let end = parts.count > 1 ? Int(parts[1])! : nil
    return (start, end)
}

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
let args = Array(CommandLine.arguments.dropFirst())

if args.isEmpty {
    printUsage()
    exit(1)
}

let path = args[0]

// Parse optional order range
var orderStart = 0
var orderEnd: Int? = nil
if args.count >= 2 {
    let (start, end) = parseRange(args[1])
    orderStart = start
    orderEnd = end ?? start
}

// Parse optional row range
var rowStart = 0
var rowEnd: Int? = nil
if args.count >= 3 {
    (rowStart, rowEnd) = parseRange(args[2])
}

do {
    let url = URL(fileURLWithPath: path)
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
