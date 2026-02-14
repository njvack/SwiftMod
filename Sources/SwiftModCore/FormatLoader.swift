import Foundation

public protocol FormatLoader {
    static func identify(_ data: Data) -> Int
    static func load(_ data: Data) throws -> Module
}

public struct FormatRegistry: Sendable {
    private nonisolated(unsafe) var loaders: [FormatLoader.Type] = []

    public init() {}

    public mutating func register(_ loader: FormatLoader.Type) {
        loaders.append(loader)
    }

    public func load(_ data: Data) throws -> Module {
        var bestLoader: FormatLoader.Type?
        var bestScore = 0

        for loader in loaders {
            let score = loader.identify(data)
            if score > bestScore {
                bestScore = score
                bestLoader = loader
            }
        }

        guard let loader = bestLoader, bestScore > 0 else {
            throw FormatError.unrecognizedFormat
        }

        return try loader.load(data)
    }
}

public enum FormatError: Error {
    case unrecognizedFormat
    case invalidData(String)
    case truncatedFile
}
