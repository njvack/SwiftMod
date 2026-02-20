import AVFoundation
import AppKit
import Foundation
import SwiftModCore
import SwiftModFormats
import SwiftModEngine

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

let args = Array(CommandLine.arguments.dropFirst())
guard let path = args.first else {
    print("Usage: modlive <file.mod>")
    exit(1)
}

let data = try Data(contentsOf: URL(fileURLWithPath: path))
let module = try MODLoader.load(data)

let sampleRate: Double = 44100
let sequencer = LiveSequencer(module: module, sampleRate: Int(sampleRate))
let renderer = ModuleRenderer(sequencer: sequencer, module: module, sampleRate: Int(sampleRate))

nonisolated(unsafe) let engine = try startAudio(renderer: renderer, sampleRate: sampleRate)
_ = engine  // keep alive

let app = NSApplication.shared
app.setActivationPolicy(.regular)
nonisolated(unsafe) let delegate = AppDelegate(module: module, sequencer: sequencer)
app.delegate = delegate
app.run()
