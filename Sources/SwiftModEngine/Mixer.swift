import SwiftModCore

public protocol Mixer {
    var sampleRate: Int { get }

    /// Render `frameCount` stereo interleaved Float frames into the buffer,
    /// using current channel states from the sequencer.
    mutating func render(
        channels: inout [ChannelState],
        module: Module,
        frameCount: Int,
        into buffer: UnsafeMutableBufferPointer<Float>
    )
}
