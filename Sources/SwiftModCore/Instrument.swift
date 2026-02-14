public struct Instrument: Sendable {
    public let name: String
    public let samples: [Sample]
    public let keyToSampleMap: [Int]
    public let volumeEnvelope: Envelope?
    public let panningEnvelope: Envelope?
    public let pitchEnvelope: Envelope?
    public let pitchEnvelopeIsFilter: Bool
    public let newNoteAction: NoteAction
    public let duplicateCheckType: DuplicateCheck
    public let duplicateCheckAction: NoteAction
    public let fadeOut: Int
    public let initialFilterCutoff: Int?
    public let initialFilterResonance: Int?

    public init(
        name: String,
        samples: [Sample],
        keyToSampleMap: [Int] = [],
        volumeEnvelope: Envelope? = nil,
        panningEnvelope: Envelope? = nil,
        pitchEnvelope: Envelope? = nil,
        pitchEnvelopeIsFilter: Bool = false,
        newNoteAction: NoteAction = .cut,
        duplicateCheckType: DuplicateCheck = .none,
        duplicateCheckAction: NoteAction = .cut,
        fadeOut: Int = 0,
        initialFilterCutoff: Int? = nil,
        initialFilterResonance: Int? = nil
    ) {
        self.name = name
        self.samples = samples
        self.keyToSampleMap = keyToSampleMap
        self.volumeEnvelope = volumeEnvelope
        self.panningEnvelope = panningEnvelope
        self.pitchEnvelope = pitchEnvelope
        self.pitchEnvelopeIsFilter = pitchEnvelopeIsFilter
        self.newNoteAction = newNoteAction
        self.duplicateCheckType = duplicateCheckType
        self.duplicateCheckAction = duplicateCheckAction
        self.fadeOut = fadeOut
        self.initialFilterCutoff = initialFilterCutoff
        self.initialFilterResonance = initialFilterResonance
    }
}
