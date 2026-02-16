import SwiftModCore

public class ModuleRenderer: @unchecked Sendable {
    private let sequencer: BaseSequencer
    private var mixer: LinearMixer
    private var sampleCounter: Int = 0

    public var isFinished: Bool { sequencer.isFinished }

    public var orderIndex: Int { sequencer.orderIndex }
    public var rowIndex: Int { sequencer.rowIndex }
    public var speed: Int { sequencer.speed }
    public var tempo: Int { sequencer.tempo }
    public let module: Module

    public init(module: Module, sampleRate: Int = 44100) {
        self.module = module
        self.sequencer = BaseSequencer(module: module, sampleRate: sampleRate)
        self.mixer = LinearMixer(sampleRate: sampleRate)
    }

    public init(sequencer: BaseSequencer, module: Module, sampleRate: Int = 44100) {
        self.module = module
        self.sequencer = sequencer
        self.mixer = LinearMixer(sampleRate: sampleRate)
    }

    /// Render stereo interleaved Float audio into the buffer.
    /// Called from the audio render callback.
    public func render(into buffer: UnsafeMutableBufferPointer<Float>, frameCount: Int) {
        guard !sequencer.isFinished else {
            // Zero and return
            for i in 0..<(frameCount * 2) { buffer[i] = 0.0 }
            return
        }

        var framesRendered = 0

        while framesRendered < frameCount && !sequencer.isFinished {
            let framesUntilTick = sequencer.samplesPerTick - sampleCounter
            let framesToRender = min(framesUntilTick, frameCount - framesRendered)

            if framesToRender > 0 {
                let offset = framesRendered * 2
                let sliceBuffer = UnsafeMutableBufferPointer(
                    start: buffer.baseAddress! + offset,
                    count: framesToRender * 2
                )
                mixer.render(
                    channels: &sequencer.channels,
                    module: module,
                    frameCount: framesToRender,
                    into: sliceBuffer
                )

                framesRendered += framesToRender
                sampleCounter += framesToRender
            }

            if sampleCounter >= sequencer.samplesPerTick {
                sampleCounter = 0
                sequencer.advanceTick()
            }
        }

        // Zero any remaining frames if sequencer finished mid-buffer
        if framesRendered < frameCount {
            for i in (framesRendered * 2)..<(frameCount * 2) {
                buffer[i] = 0.0
            }
        }
    }
}
