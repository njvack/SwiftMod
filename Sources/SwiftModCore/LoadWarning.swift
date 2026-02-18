public enum LoadWarning: Sendable {
    case loopExceedsSampleLength(
        sampleIndex: Int,
        originalStart: Int,
        originalLength: Int,
        clampedStart: Int,
        clampedLength: Int
    )
}

extension LoadWarning: CustomStringConvertible {
    public var description: String {
        switch self {
        case .loopExceedsSampleLength(let idx, let origStart, let origLen, let clampStart, let clampLen):
            return "Sample \(idx + 1): loop \(origStart)..+\(origLen) exceeds sample length, clamped to \(clampStart)..+\(clampLen)"
        }
    }
}
