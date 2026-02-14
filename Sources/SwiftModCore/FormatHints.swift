public struct FormatHints: Sendable {
    public let sourceFormat: SourceFormat
    public let frequencyModel: FrequencyModel
    public let amigaLimits: Bool
    public let zeroVolumeOptimization: Bool

    public init(
        sourceFormat: SourceFormat,
        frequencyModel: FrequencyModel = .amigaPeriods,
        amigaLimits: Bool = false,
        zeroVolumeOptimization: Bool = false
    ) {
        self.sourceFormat = sourceFormat
        self.frequencyModel = frequencyModel
        self.amigaLimits = amigaLimits
        self.zeroVolumeOptimization = zeroVolumeOptimization
    }
}

public enum SourceFormat: Sendable {
    case mod, s3m, xm, it
}

public enum FrequencyModel: Sendable {
    case amigaPeriods
    case linearFrequencies
}
