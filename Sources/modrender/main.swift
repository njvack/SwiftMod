import Foundation
import SwiftModCore
import SwiftModFormats
import SwiftModEngine

func printUsage() {
    fputs("Usage: modrender <input.mod> [output.wav] [--loops N]\n", stderr)
}

// MARK: - Argument parsing

var inputPath: String?
var outputPath: String?
var maxLoops = 0

var args = Array(CommandLine.arguments.dropFirst())
var i = 0
while i < args.count {
    if args[i] == "--loops" {
        i += 1
        guard i < args.count, let n = Int(args[i]), n >= 0 else {
            fputs("Error: --loops requires a non-negative integer\n", stderr)
            exit(1)
        }
        maxLoops = n
    } else if inputPath == nil {
        inputPath = args[i]
    } else if outputPath == nil {
        outputPath = args[i]
    } else {
        fputs("Error: unexpected argument '\(args[i])'\n", stderr)
        printUsage()
        exit(1)
    }
    i += 1
}

guard let inputPath else {
    printUsage()
    exit(1)
}

let inputURL = URL(fileURLWithPath: inputPath)
let outputURL: URL
if let outputPath {
    outputURL = URL(fileURLWithPath: outputPath)
} else {
    let baseName = inputURL.deletingPathExtension().lastPathComponent
    outputURL = inputURL.deletingLastPathComponent().appendingPathComponent(baseName + ".wav")
}

// MARK: - Load module

let data = try Data(contentsOf: inputURL)
let module = try MODLoader.load(data)

let title = module.title.isEmpty ? inputURL.lastPathComponent : module.title
fputs("Rendering: \(title)\n", stderr)
fputs("Channels: \(module.channelCount), Patterns: \(module.patterns.count), Orders: \(module.patternOrder.count)\n", stderr)

// MARK: - Render

let sampleRate = 44100
let renderer = ModuleRenderer(module: module, sampleRate: sampleRate)

let chunkSize = 4096
var leftBuf = [Float](repeating: 0, count: chunkSize)
var rightBuf = [Float](repeating: 0, count: chunkSize)
var pcmData = Data()

struct VisitedPosition: Hashable {
    let order: Int
    let row: Int
}

var visited = Set<VisitedPosition>()
visited.insert(VisitedPosition(order: 0, row: 0))
var remainingLoops = maxLoops
var lastReportedOrder = -1
var prevOrder = 0
var prevRow = 0
var shouldStop = false

while !renderer.isFinished && !shouldStop {
    let framesToRender = renderer.samplesPerTick

    // Grow buffers if needed
    if leftBuf.count < framesToRender {
        leftBuf = [Float](repeating: 0, count: framesToRender)
        rightBuf = [Float](repeating: 0, count: framesToRender)
    }

    leftBuf.withUnsafeMutableBufferPointer { leftPtr in
        rightBuf.withUnsafeMutableBufferPointer { rightPtr in
            renderer.render(left: leftPtr, right: rightPtr, frameCount: framesToRender)
        }
    }

    // Convert Float32 stereo to interleaved Int16 PCM
    for j in 0..<framesToRender {
        let l = max(-1.0, min(1.0, leftBuf[j]))
        let r = max(-1.0, min(1.0, rightBuf[j]))
        var li = Int16(l * 32767)
        var ri = Int16(r * 32767)
        pcmData.append(Data(bytes: &li, count: 2))
        pcmData.append(Data(bytes: &ri, count: 2))
    }

    // Progress
    let currentOrder = renderer.orderIndex
    if currentOrder != lastReportedOrder && currentOrder < module.patternOrder.count {
        fputs("\rRendering order \(currentOrder + 1)/\(module.patternOrder.count)...", stderr)
        lastReportedOrder = currentOrder
    }

    // Loop detection — only check when position changes
    let curOrder = renderer.orderIndex
    let curRow = renderer.rowIndex
    if curOrder != prevOrder || curRow != prevRow {
        let pos = VisitedPosition(order: curOrder, row: curRow)
        if visited.contains(pos) {
            if remainingLoops > 0 {
                remainingLoops -= 1
                visited.removeAll()
            } else {
                shouldStop = true
            }
        }
        visited.insert(pos)
        prevOrder = curOrder
        prevRow = curRow
    }
}

fputs("\r\n", stderr)

// MARK: - Write WAV

let numChannels: UInt16 = 2
let bitsPerSample: UInt16 = 16
let byteRate = UInt32(sampleRate) * UInt32(numChannels) * UInt32(bitsPerSample / 8)
let blockAlign = numChannels * (bitsPerSample / 8)
let dataSize = UInt32(pcmData.count)
let fileSize = 36 + dataSize

var wav = Data()
wav.append(contentsOf: "RIFF".utf8)
wav.appendLittleEndian(fileSize)
wav.append(contentsOf: "WAVE".utf8)

// fmt chunk
wav.append(contentsOf: "fmt ".utf8)
wav.appendLittleEndian(UInt32(16))       // chunk size
wav.appendLittleEndian(UInt16(1))        // PCM format
wav.appendLittleEndian(numChannels)
wav.appendLittleEndian(UInt32(sampleRate))
wav.appendLittleEndian(byteRate)
wav.appendLittleEndian(blockAlign)
wav.appendLittleEndian(bitsPerSample)

// data chunk
wav.append(contentsOf: "data".utf8)
wav.appendLittleEndian(dataSize)
wav.append(pcmData)

try wav.write(to: outputURL)

let totalFrames = pcmData.count / Int(numChannels) / Int(bitsPerSample / 8)
let duration = Double(totalFrames) / Double(sampleRate)
let minutes = Int(duration) / 60
let seconds = Int(duration) % 60
let fileSizeMB = Double(wav.count) / (1024 * 1024)

fputs("Wrote \(outputURL.lastPathComponent): \(minutes):\(String(format: "%02d", seconds)), \(String(format: "%.1f", fileSizeMB)) MB\n", stderr)

// MARK: - Helpers

extension Data {
    mutating func appendLittleEndian(_ value: UInt16) {
        var v = value.littleEndian
        append(Data(bytes: &v, count: 2))
    }

    mutating func appendLittleEndian(_ value: UInt32) {
        var v = value.littleEndian
        append(Data(bytes: &v, count: 4))
    }
}
