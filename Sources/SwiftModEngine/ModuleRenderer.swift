import Foundation
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
    public var samplesPerTick: Int { sequencer.samplesPerTick }
    public let module: Module

    public var onRow: ((Int, Int) -> Void)? {
        get { sequencer.onRow }
        set { sequencer.onRow = newValue }
    }

    public func seek(toOrder targetOrder: Int, row targetRow: Int = 0) {
        sequencer.seek(toOrder: targetOrder, row: targetRow)
        sampleCounter = 0
    }

    public init(module: Module, sampleRate: Int = 44100) {
        self.module = module
        self.sequencer = BaseSequencer(module: module, sampleRate: sampleRate)
        self.mixer = LinearMixer(sampleRate: sampleRate)
        self.mixer.prepare(module: module)
    }

    public init(sequencer: BaseSequencer, module: Module, sampleRate: Int = 44100) {
        self.module = module
        self.sequencer = sequencer
        self.mixer = LinearMixer(sampleRate: sampleRate)
        self.mixer.prepare(module: module)
    }

    /// Render stereo audio into separate left/right buffers.
    /// Called from the audio render callback.
    public func render(
        left: UnsafeMutableBufferPointer<Float>,
        right: UnsafeMutableBufferPointer<Float>,
        frameCount: Int
    ) {
        guard !sequencer.isFinished else {
            // Zero and return
            memset(left.baseAddress!, 0, frameCount * MemoryLayout<Float>.size)
            memset(right.baseAddress!, 0, frameCount * MemoryLayout<Float>.size)
            return
        }

        var framesRendered = 0

        while framesRendered < frameCount && !sequencer.isFinished {
            let framesUntilTick = sequencer.samplesPerTick - sampleCounter
            let framesToRender = min(framesUntilTick, frameCount - framesRendered)

            if framesToRender > 0 {
                let leftSlice = UnsafeMutableBufferPointer(
                    start: left.baseAddress! + framesRendered,
                    count: framesToRender
                )
                let rightSlice = UnsafeMutableBufferPointer(
                    start: right.baseAddress! + framesRendered,
                    count: framesToRender
                )
                mixer.render(
                    channels: &sequencer.channels,
                    frameCount: framesToRender,
                    left: leftSlice,
                    right: rightSlice
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
            let remaining = frameCount - framesRendered
            memset(left.baseAddress! + framesRendered, 0, remaining * MemoryLayout<Float>.size)
            memset(right.baseAddress! + framesRendered, 0, remaining * MemoryLayout<Float>.size)
        }
    }
}
