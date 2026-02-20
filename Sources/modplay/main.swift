import AVFoundation
import Foundation
import SwiftModCore
import SwiftModFormats
import SwiftModEngine
import ModCLI

// MARK: - Note formatting (duplicated from modpattern — no shared abstraction yet)

let noteNames = ["C-", "C#", "D-", "D#", "E-", "F-", "F#", "G-", "G#", "A-", "A#", "B-"]

func noteDisplayName(_ noteValue: NoteValue) -> String {
    switch noteValue {
    case .note(let index):
        let name = noteNames[index % 12]
        let octave = index / 12 + 2
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
    let notePart: String
    if let nv = note.noteValue, let period = note.period {
        notePart = "\(noteDisplayName(nv))(\(String(format: "%3d", period)))"
    } else if let period = note.period {
        notePart = "???(\(String(format: "%3d", period)))"
    } else {
        notePart = "...     "
    }

    let instPart: String
    if let inst = note.instrument, inst > 0 {
        instPart = String(format: "%02X", inst)
    } else {
        instPart = ".."
    }

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

// MARK: - Audio setup

nonisolated func startAudio(renderer: ModuleRenderer, sampleRate: Double) throws -> AVAudioEngine {
    let renderFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: sampleRate,
        channels: 2,
        interleaved: false
    )!

    let sourceNode = AVAudioSourceNode(format: renderFormat) { _, _, frameCount, audioBufferList -> OSStatus in
        let count = Int(frameCount)
        let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)

        guard let leftRaw = ablPointer[0].mData,
              let rightRaw = ablPointer[1].mData else { return noErr }
        let left = UnsafeMutableBufferPointer(
            start: leftRaw.assumingMemoryBound(to: Float.self),
            count: count
        )
        let right = UnsafeMutableBufferPointer(
            start: rightRaw.assumingMemoryBound(to: Float.self),
            count: count
        )
        renderer.render(left: left, right: right, frameCount: count)

        return noErr
    }

    let engine = AVAudioEngine()
    engine.attach(sourceNode)
    engine.connect(sourceNode, to: engine.mainMixerNode, format: renderFormat)
    try engine.start()
    return engine
}

// MARK: - Main

let cli = CLIArgs.parse(usage:
    "Usage: modplay <file.mod> [--start-order N] [--end-order N]")

let orderStart = cli.startOrder
let orderEnd: Int? = cli.endOrder == Int.max ? nil : cli.endOrder

let data = try Data(contentsOf: URL(fileURLWithPath: cli.inputPath))
let module = try MODLoader.load(data)

let sampleRate: Double = 44100
let renderer = ModuleRenderer(module: module, sampleRate: Int(sampleRate))

let title = module.title.isEmpty ? URL(fileURLWithPath: cli.inputPath).lastPathComponent : module.title
print("Playing: \(title)")
print("Format: \(module.formatDescription)")
print("Channels: \(module.channelCount), Patterns: \(module.patterns.count), Orders: \(module.patternOrder.count)")
if let end = orderEnd {
    print("Order range: \(orderStart)–\(end)")
}
print("Press Ctrl-C to stop.")
print()

// Column header
var header = "Ord  Row"
for ch in 1...module.channelCount {
    let label = "Ch\(ch)"
    header += " | \(label)\(String(repeating: " ", count: 15 - label.count))"
}
print(header)
fflush(stdout)

// Row callback — fires on audio thread, prints the row as it plays
renderer.onRow = { order, row in
    let patternIndex = module.patternOrder[order]
    let pattern = module.patterns[patternIndex]
    guard row < pattern.rowCount else { return }
    let rowData = pattern.rows[row]

    var line = String(format: "%3d  %02d", order, row)
    for ch in 0..<module.channelCount {
        line += " | \(formatNote(rowData[ch]))"
    }
    print(line)
    fflush(stdout)
}

// Seek if needed (isSeeking suppresses onRow during fast-forward)
if orderStart > 0 {
    renderer.seek(toOrder: orderStart)
}

// Fire the initial row manually — onRow doesn't fire for the starting position
// (callback was set after init, and is suppressed during seek)
renderer.onRow?(renderer.orderIndex, renderer.rowIndex)

signal(SIGINT) { _ in
    print("\nStopping...")
    exit(0)
}

let engine = try startAudio(renderer: renderer, sampleRate: sampleRate)

while !renderer.isFinished {
    if let end = orderEnd, renderer.orderIndex > end { break }
    Thread.sleep(forTimeInterval: 0.05)
}

Thread.sleep(forTimeInterval: 0.5)
engine.stop()
