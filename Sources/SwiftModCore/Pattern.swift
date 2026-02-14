public struct Pattern: Sendable {
    public let rowCount: Int
    public let rows: [[Note]]

    public init(rowCount: Int, rows: [[Note]]) {
        self.rowCount = rowCount
        self.rows = rows
    }
}

public struct Note: Sendable {
    public let noteValue: NoteValue?
    public let period: Int?
    public let instrument: Int?
    public let volume: Int?
    public let volumeEffect: VolumeEffect?
    public let effect: Effect?

    public init(
        noteValue: NoteValue? = nil,
        period: Int? = nil,
        instrument: Int? = nil,
        volume: Int? = nil,
        volumeEffect: VolumeEffect? = nil,
        effect: Effect? = nil
    ) {
        self.noteValue = noteValue
        self.period = period
        self.instrument = instrument
        self.volume = volume
        self.volumeEffect = volumeEffect
        self.effect = effect
    }
}

public enum NoteValue: Sendable, Equatable {
    case note(Int)
    case noteOff
    case noteCut
    case noteFade
}
