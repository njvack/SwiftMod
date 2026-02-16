import AVFoundation
import Foundation
import SwiftModCore
import SwiftModFormats
import SwiftModEngine

// Audio setup must be nonisolated so the render callback
// doesn't inherit @MainActor isolation from top-level code.
nonisolated func startAudio(renderer: ModuleRenderer, sampleRate: Double) throws -> AVAudioEngine {
    let renderFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: sampleRate,
        channels: 2,
        interleaved: false
    )!

    // Pre-allocate interleaved render buffer (max 4096 frames should cover any callback size)
    let maxFrames = 4096
    let renderBuffer = UnsafeMutableBufferPointer<Float>.allocate(capacity: maxFrames * 2)

    let sourceNode = AVAudioSourceNode(format: renderFormat) { _, _, frameCount, audioBufferList -> OSStatus in
        let count = Int(frameCount)
        let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)

        // Render interleaved into pre-allocated buffer
        let buf = UnsafeMutableBufferPointer(start: renderBuffer.baseAddress!, count: count * 2)
        renderer.render(into: buf, frameCount: count)

        // Deinterleave into the non-interleaved output buffers
        let leftData = ablPointer[0].mData!.assumingMemoryBound(to: Float.self)
        let rightData = ablPointer[1].mData!.assumingMemoryBound(to: Float.self)
        for i in 0..<count {
            leftData[i] = buf[i &* 2]
            rightData[i] = buf[i &* 2 &+ 1]
        }

        return noErr
    }

    let engine = AVAudioEngine()
    engine.attach(sourceNode)
    engine.connect(sourceNode, to: engine.mainMixerNode, format: renderFormat)
    try engine.start()
    return engine
}

// MARK: - Main

func printUsage() {
    print("Usage: modplay <file.mod>")
}

let args = Array(CommandLine.arguments.dropFirst())
guard let path = args.first else {
    printUsage()
    exit(1)
}

let data = try Data(contentsOf: URL(fileURLWithPath: path))
let module = try MODLoader.load(data)

let sampleRate: Double = 44100
let renderer = ModuleRenderer(module: module, sampleRate: Int(sampleRate))

let engine = try startAudio(renderer: renderer, sampleRate: sampleRate)

let title = module.title.isEmpty ? URL(fileURLWithPath: path).lastPathComponent : module.title
print("Playing: \(title)")
print("Format: \(module.formatDescription)")
print("Channels: \(module.channelCount), Patterns: \(module.patterns.count), Orders: \(module.patternOrder.count)")
print("Press Ctrl-C to stop.")
print()
fflush(stdout)

signal(SIGINT) { _ in
    print("\nStopping...")
    exit(0)
}

while !renderer.isFinished {
    Thread.sleep(forTimeInterval: 0.1)
}

Thread.sleep(forTimeInterval: 0.5)
engine.stop()
