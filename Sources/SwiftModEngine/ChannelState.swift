import SwiftModCore

/// Per-channel playback state, updated by the sequencer and read by the mixer.
///
/// Effect-related fields (slide speeds, oscillator positions, etc.) are stored
/// directly on ChannelState rather than on Effect instances. This is because
/// tracker effect state is fundamentally per-channel, not per-effect:
///
/// - **Shared state**: volume slide speed is shared by effects A, 5, and 6.
///   Tone portamento speed is shared by effects 3 and 5. State persists across
///   rows until changed, and effects may use state left by previous effects.
/// - **Persistent memory**: effects remember their last non-zero parameter
///   indefinitely. `vibrato 4,8` followed by `vibrato 0,0` means "continue
///   with speed 4, depth 8."
/// - **State outlives effects**: vibrato waveform set by E4x persists even when
///   vibrato isn't active, and vibrato position carries forward across rows.
///
/// The flat struct is organized into groups below, but it accurately reflects
/// that a channel is a single shared context that all effects read and write.
public struct ChannelState: Sendable {

    // MARK: - Instrument

    public var instrumentIndex: Int = 0
    public var sampleIndex: Int = 0

    // MARK: - Playback position

    /// Fractional index into the sample data. This is a Double because samples
    /// play back at non-integer rates (e.g. advancing 0.188 samples per output
    /// frame at middle C). The fractional part drives linear interpolation.
    public var samplePosition: Double = 0.0
    public var playing: Bool = false

    // MARK: - Pitch

    public var period: Int = 0
    public var targetPeriod: Int = 0       // tone portamento destination

    // MARK: - Volume and panning

    public var volume: Int = 0             // 0-64
    public var panning: Int = 128          // 0=left, 128=center, 255=right

    // MARK: - Active effect

    public var currentEffect: Effect? = nil

    // MARK: - Pitch slide state (effects 1, 2, 3, 5)

    public var slideUpSpeed: Int = 0       // effect 1
    public var slideDownSpeed: Int = 0     // effect 2
    public var tonePortaSpeed: Int = 0     // effects 3, 5

    // MARK: - Vibrato state (effects 4, 6)

    public var vibratoSpeed: Int = 0
    public var vibratoDepth: Int = 0
    public var vibratoPosition: Int = 0    // oscillator phase (0-63)
    public var vibratoWaveform: Int = 0    // 0=sine, 1=ramp, 2=square, 3=random; +4=no retrigger
    public var vibratoOffset: Int = 0      // per-tick period adjustment, read by mixer

    // MARK: - Tremolo state (effect 7)

    public var tremoloSpeed: Int = 0
    public var tremoloDepth: Int = 0
    public var tremoloPosition: Int = 0
    public var tremoloWaveform: Int = 0
    public var tremoloOffset: Int = 0      // per-tick volume adjustment, read by mixer

    // MARK: - Volume slide state (effects A, 5, 6)

    public var volumeSlideSpeed: Int = 0   // shared by effects A, 5, and 6

    // MARK: - Arpeggio state (effect 0)

    public var arpeggioX: Int = 0
    public var arpeggioY: Int = 0
    public var arpeggioBasePeriod: Int = 0

    // MARK: - Other effect memory

    public var sampleOffsetMemory: Int = 0 // effect 9
    public var retrigInterval: Int = 0     // effect E9x

    // MARK: - Note delay (effect EDx)

    public var delayedInstrument: Int? = nil
    public var delayedPeriod: Int? = nil

    // MARK: - Pattern flow (effects E6x, EEx)

    public var patternLoopRow: Int = 0
    public var patternLoopCount: Int = 0

    // MARK: - LiveSequencer support

    public var channelTick: Int = 0        // per-channel tick counter
    public var channelRow: Int = 0         // per-channel row counter

    public init() {}
}
