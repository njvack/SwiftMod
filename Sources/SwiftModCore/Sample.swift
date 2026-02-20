public enum SampleData: Sendable {
    case int8([Int8])
    case int16([Int16])

    public var frameCount: Int {
        switch self {
        case .int8(let data): return data.count
        case .int16(let data): return data.count
        }
    }
}

public struct Sample: Sendable {
    public let name: String
    public let data: SampleData
    public let sampleRate: Int
    public let volume: Int
    public let panning: Int?
    public let loop: Loop?
    public let sustainLoop: Loop?
    public let finetune: Int
    public let relativeTone: Int
    public let vibratoType: WaveformType
    public let vibratoSpeed: Int
    public let vibratoDepth: Int
    public let vibratoSweep: Int

    public init(
        name: String,
        data: SampleData = .int8([]),
        sampleRate: Int = 8363,
        volume: Int = 64,
        panning: Int? = nil,
        loop: Loop? = nil,
        sustainLoop: Loop? = nil,
        finetune: Int = 0,
        relativeTone: Int = 0,
        vibratoType: WaveformType = .sine,
        vibratoSpeed: Int = 0,
        vibratoDepth: Int = 0,
        vibratoSweep: Int = 0
    ) {
        self.name = name
        self.data = data
        self.sampleRate = sampleRate
        self.volume = volume
        self.panning = panning
        self.loop = loop
        self.sustainLoop = sustainLoop
        self.finetune = finetune
        self.relativeTone = relativeTone
        self.vibratoType = vibratoType
        self.vibratoSpeed = vibratoSpeed
        self.vibratoDepth = vibratoDepth
        self.vibratoSweep = vibratoSweep
    }
}

public struct Loop: Sendable {
    public let start: Int
    public let length: Int
    public let type: LoopType

    public init(start: Int, length: Int, type: LoopType = .forward) {
        self.start = start
        self.length = length
        self.type = type
    }
}

public enum LoopType: Sendable {
    case forward
    case pingPong
    case backward
}

/// Waveform shape for vibrato and tremolo oscillators.
/// Corresponds to the low 2 bits of the E4x/E7x MOD effect parameter.
public enum WaveformType: Int, Sendable {
    case sine     = 0
    case rampDown = 1
    case square   = 2
    case random   = 3
}
