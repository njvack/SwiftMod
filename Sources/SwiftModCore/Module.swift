import Foundation

public struct Module: Sendable {
    public let title: String
    public let formatDescription: String
    public let channelCount: Int
    public let patternOrder: [Int]
    public let restartPosition: Int
    public let patterns: [Pattern]
    public let instruments: [Instrument]
    public let initialSpeed: Int
    public let initialTempo: Int
    public let initialGlobalVolume: Int
    public let defaultPanning: [Int]
    public let formatHints: FormatHints
    public let warnings: [LoadWarning]

    public init(
        title: String,
        formatDescription: String,
        channelCount: Int,
        patternOrder: [Int],
        restartPosition: Int,
        patterns: [Pattern],
        instruments: [Instrument],
        initialSpeed: Int = 6,
        initialTempo: Int = 125,
        initialGlobalVolume: Int = 64,
        defaultPanning: [Int] = [],
        formatHints: FormatHints,
        warnings: [LoadWarning] = []
    ) {
        self.title = title
        self.formatDescription = formatDescription
        self.channelCount = channelCount
        self.patternOrder = patternOrder
        self.restartPosition = restartPosition
        self.patterns = patterns
        self.instruments = instruments
        self.initialSpeed = initialSpeed
        self.initialTempo = initialTempo
        self.initialGlobalVolume = initialGlobalVolume
        self.defaultPanning = defaultPanning
        self.formatHints = formatHints
        self.warnings = warnings
    }
}
