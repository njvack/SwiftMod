import Foundation
import SwiftModCore
import SwiftModFormats

func printUsage() {
    print("Usage: modinfo <file.mod> [file2.mod ...]")
}

func formatBytes(_ bytes: Int) -> String {
    if bytes < 1024 { return "\(bytes) B" }
    if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024) }
    return String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
}

func showInfo(path: String) throws {
    let url = URL(fileURLWithPath: path)
    let data = try Data(contentsOf: url)
    let module = try MODLoader.load(data)

    let filename = url.lastPathComponent
    let bar = String(repeating: "─", count: max(filename.count, 40))

    print("┌─\(bar)─┐")
    print("│ \(filename.padding(toLength: bar.count, withPad: " ", startingAt: 0)) │")
    print("└─\(bar)─┘")
    print("  Title:       \(module.title.isEmpty ? "(untitled)" : module.title)")
    print("  Format:      \(module.formatDescription)")
    print("  Channels:    \(module.channelCount)")
    print("  Patterns:    \(module.patterns.count)")
    print("  Orders:      \(module.patternOrder.count)")
    print("  Speed/Tempo: \(module.initialSpeed)/\(module.initialTempo)")
    print("  File size:   \(formatBytes(data.count))")

    // Samples
    let usedSamples = module.instruments.filter { inst in
        inst.samples.first.map { $0.data.frameCount > 0 } ?? false
    }

    print("  Samples:     \(usedSamples.count) of \(module.instruments.count)")
    print()

    for (i, inst) in module.instruments.enumerated() {
        guard let sample = inst.samples.first, sample.data.frameCount > 0 else { continue }

        let num = String(format: "%2d", i + 1)
        let name = sample.name.isEmpty ? "(unnamed)" : sample.name
        let len = formatBytes(sample.data.frameCount)
        let vol = String(format: "%2d", sample.volume)
        let ft = sample.finetune
        let loopStr: String
        if let loop = sample.loop {
            loopStr = "loop \(loop.start)..+\(loop.length)"
        } else {
            loopStr = ""
        }

        let ftStr = ft != 0 ? " ft:\(ft)" : ""
        print("  \(num). \(name.padding(toLength: 22, withPad: " ", startingAt: 0))  \(len.padding(toLength: 10, withPad: " ", startingAt: 0)) vol:\(vol)\(ftStr) \(loopStr)")
    }
    print()
}

// Main
let args = CommandLine.arguments.dropFirst()

if args.isEmpty {
    printUsage()
    exit(1)
}

var hadError = false
for path in args {
    do {
        try showInfo(path: path)
    } catch {
        print("Error reading \(path): \(error)")
        hadError = true
    }
}

if hadError { exit(1) }
