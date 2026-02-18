import Foundation

/// Parsed command-line arguments common to all mod* tools.
///
/// Supports: --start-order N  --end-order N  --start-row N  --end-row N
/// The input file path is the sole positional argument.
public struct CLIArgs {
    public let inputPath: String
    public let startOrder: Int
    public let endOrder: Int
    public let startRow: Int
    public let endRow: Int

    public static func parse(usage: String) -> CLIArgs {
        var inputPath: String?
        var startOrder = 0
        var endOrder   = Int.max
        var startRow   = 0
        var endRow     = Int.max

        let args = Array(CommandLine.arguments.dropFirst())
        var i = 0
        while i < args.count {
            switch args[i] {
            case "--start-order":
                i += 1
                guard i < args.count, let n = Int(args[i]), n >= 0 else {
                    fail("--start-order requires a non-negative integer", usage: usage)
                }
                startOrder = n
            case "--end-order":
                i += 1
                guard i < args.count, let n = Int(args[i]), n >= 0 else {
                    fail("--end-order requires a non-negative integer", usage: usage)
                }
                endOrder = n
            case "--start-row":
                i += 1
                guard i < args.count, let n = Int(args[i]), n >= 0 else {
                    fail("--start-row requires a non-negative integer", usage: usage)
                }
                startRow = n
            case "--end-row":
                i += 1
                guard i < args.count, let n = Int(args[i]), n >= 0 else {
                    fail("--end-row requires a non-negative integer", usage: usage)
                }
                endRow = n
            default:
                if inputPath == nil {
                    inputPath = args[i]
                } else {
                    fail("unexpected argument '\(args[i])'", usage: usage)
                }
            }
            i += 1
        }

        guard let path = inputPath else {
            fputs(usage + "\n", stderr)
            exit(1)
        }
        return CLIArgs(
            inputPath: path,
            startOrder: startOrder, endOrder: endOrder,
            startRow: startRow, endRow: endRow
        )
    }

    private static func fail(_ message: String, usage: String) -> Never {
        fputs("Error: \(message)\n\(usage)\n", stderr)
        exit(1)
    }
}
