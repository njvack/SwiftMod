import AVFoundation
import Foundation
import SwiftModCore
import SwiftModFormats

func printUsage() {
    print("Usage: modsample <file.mod> [sample#]")
    print("  sample# is 1-based (default: lists samples, plays first non-empty one)")
}

// --- Load the module ---

let args = Array(CommandLine.arguments.dropFirst())
guard let path = args.first else {
    printUsage()
    exit(1)
}

let data = try Data(contentsOf: URL(fileURLWithPath: path))
let module = try MODLoader.load(data)

// Find non-empty samples
let nonEmpty: [(index: Int, instrument: Instrument)] = module.instruments.enumerated().compactMap { i, inst in
    guard let s = inst.samples.first, s.data.frameCount > 0 else { return nil }
    return (i, inst)
}

guard !nonEmpty.isEmpty else {
    print("No samples with data in this file.")
    exit(1)
}

// Pick which sample to play
let chosenIndex: Int
if args.count > 1, let n = Int(args[1]) {
    chosenIndex = n - 1  // 1-based input
} else {
    // List samples and play the first one
    print("Samples in \(module.title.isEmpty ? path : module.title):")
    for (i, inst) in nonEmpty {
        let s = inst.samples[0]
        print("  \(i + 1). \(s.name.isEmpty ? "(unnamed)" : s.name)  (\(s.data.frameCount) frames)")
    }
    print()
    chosenIndex = nonEmpty[0].index
}

guard chosenIndex >= 0, chosenIndex < module.instruments.count else {
    print("Sample number out of range (1-\(module.instruments.count))")
    exit(1)
}

let instrument = module.instruments[chosenIndex]
guard let sample = instrument.samples.first, sample.data.frameCount > 0 else {
    print("Sample \(chosenIndex + 1) is empty.")
    exit(1)
}

// --- Set up audio and play ---

let sampleRate = Double(sample.sampleRate)  // typically 8363 Hz
let frameCount = sample.data.frameCount

guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false) else {
    print("Failed to create audio format")
    exit(1)
}

guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else {
    print("Failed to create audio buffer")
    exit(1)
}
buffer.frameLength = AVAudioFrameCount(frameCount)

// Convert Int8 samples to Float32 (-1.0 .. 1.0)
guard let floatChannelData = buffer.floatChannelData else {
    print("Failed to access float channel data")
    exit(1)
}
let floatData = floatChannelData[0]
switch sample.data {
case .int8(let samples):
    for i in 0..<frameCount {
        floatData[i] = Float(samples[i]) / 128.0
    }
case .int16(let samples):
    for i in 0..<frameCount {
        floatData[i] = Float(samples[i]) / 32768.0
    }
}

let engine = AVAudioEngine()
let player = AVAudioPlayerNode()
engine.attach(player)
engine.connect(player, to: engine.mainMixerNode, format: format)

try engine.start()

let name = sample.name.isEmpty ? "(unnamed)" : sample.name
let duration = Double(frameCount) / sampleRate
print("Playing sample \(chosenIndex + 1): \(name)  (\(String(format: "%.2f", duration))s at \(Int(sampleRate)) Hz)")

let semaphore = DispatchSemaphore(value: 0)

player.scheduleBuffer(buffer, at: nil, options: []) {
    semaphore.signal()
}
player.play()

semaphore.wait()

// Give a tiny bit of time for the audio to finish draining
Thread.sleep(forTimeInterval: 0.1)

engine.stop()
