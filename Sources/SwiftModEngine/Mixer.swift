import SwiftModCore

public protocol Mixer {
    var sampleRate: Int { get }

    /// Pre-process sample data into whatever format the mixer needs for
    /// efficient rendering. Called once at setup time.
    mutating func prepare(module: Module)

    /// Render `frameCount` stereo frames into separate left/right buffers,
    /// using current channel states from the sequencer.
    /// If `channelCapture` is provided it must contain one buffer per channel;
    /// each receives the pre-panning mono signal for that channel (silence if not playing).
    mutating func render(
        channels: inout [ChannelState],
        frameCount: Int,
        left: UnsafeMutableBufferPointer<Float>,
        right: UnsafeMutableBufferPointer<Float>,
        channelCapture: [UnsafeMutableBufferPointer<Float>]?
    )
}

extension Mixer {
    /// Convenience overload — renders without per-channel capture.
    public mutating func render(
        channels: inout [ChannelState],
        frameCount: Int,
        left: UnsafeMutableBufferPointer<Float>,
        right: UnsafeMutableBufferPointer<Float>
    ) {
        render(channels: &channels, frameCount: frameCount, left: left, right: right, channelCapture: nil)
    }
}
