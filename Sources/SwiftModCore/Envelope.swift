public struct Envelope: Sendable {
    public let points: [EnvelopePoint]
    public let sustainStart: Int?
    public let sustainEnd: Int?
    public let loopStart: Int?
    public let loopEnd: Int?
    public let enabled: Bool

    public init(
        points: [EnvelopePoint] = [],
        sustainStart: Int? = nil,
        sustainEnd: Int? = nil,
        loopStart: Int? = nil,
        loopEnd: Int? = nil,
        enabled: Bool = false
    ) {
        self.points = points
        self.sustainStart = sustainStart
        self.sustainEnd = sustainEnd
        self.loopStart = loopStart
        self.loopEnd = loopEnd
        self.enabled = enabled
    }
}

public struct EnvelopePoint: Sendable {
    public let tick: Int
    public let value: Int

    public init(tick: Int, value: Int) {
        self.tick = tick
        self.value = value
    }
}

public enum NoteAction: Sendable {
    case cut
    case `continue`
    case noteOff
    case fade
}

public enum DuplicateCheck: Sendable {
    case none
    case note
    case sample
    case instrument
}
