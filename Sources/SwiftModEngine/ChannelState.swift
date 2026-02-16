import SwiftModCore

public struct ChannelState: Sendable {
    // Current instrument/sample
    public var instrumentIndex: Int = 0
    public var sampleIndex: Int = 0

    // Pitch
    public var period: Int = 0
    public var targetPeriod: Int = 0
    public var vibratoOffset: Int = 0   // temporary period offset from vibrato
    public var arpeggioBasePeriod: Int = 0  // base period for arpeggio cycling

    // Volume
    public var volume: Int = 0
    public var tremoloOffset: Int = 0   // temporary volume offset from tremolo

    // Panning (0=left, 128=center, 255=right)
    public var panning: Int = 128

    // Sample playback
    public var samplePosition: Double = 0.0
    public var playing: Bool = false

    // Effect memory
    public var slideUpSpeed: Int = 0
    public var slideDownSpeed: Int = 0
    public var tonePortaSpeed: Int = 0
    public var vibratoSpeed: Int = 0
    public var vibratoDepth: Int = 0
    public var vibratoPosition: Int = 0
    public var tremoloSpeed: Int = 0
    public var tremoloDepth: Int = 0
    public var tremoloPosition: Int = 0
    public var volumeSlideSpeed: Int = 0
    public var arpeggioX: Int = 0
    public var arpeggioY: Int = 0
    public var sampleOffsetMemory: Int = 0
    public var retrigInterval: Int = 0
    public var currentEffect: Effect? = nil
    public var channelTick: Int = 0  // per-channel tick counter (used by LiveSequencer)
    public var channelRow: Int = 0   // per-channel row counter (used by LiveSequencer)

    // Note delay pending data
    public var delayedInstrument: Int? = nil
    public var delayedPeriod: Int? = nil

    // Pattern loop
    public var patternLoopRow: Int = 0
    public var patternLoopCount: Int = 0

    // Waveform controls
    public var vibratoWaveform: Int = 0
    public var tremoloWaveform: Int = 0

    public init() {}
}
