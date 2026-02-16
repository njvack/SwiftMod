import SwiftModCore

public protocol Mixer {
    var sampleRate: Int { get }

    /// Pre-process sample data into whatever format the mixer needs for
    /// efficient rendering. Called once at setup time.
    mutating func prepare(module: Module)

    /// Render `frameCount` stereo frames into separate left/right buffers,
    /// using current channel states from the sequencer.
    mutating func render(
        channels: inout [ChannelState],
        frameCount: Int,
        left: UnsafeMutableBufferPointer<Float>,
        right: UnsafeMutableBufferPointer<Float>
    )
}
