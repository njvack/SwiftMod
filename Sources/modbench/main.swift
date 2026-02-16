import Foundation
import SwiftModFormats

let iterations = 20

guard CommandLine.arguments.count >= 2 else {
    print("Usage: modbench <directory-of-mod-files>")
    exit(1)
}

let dirPath = CommandLine.arguments[1]
let fm = FileManager.default

// Discover MOD files
let files = try fm.contentsOfDirectory(atPath: dirPath)
    .filter { $0.uppercased().hasSuffix(".MOD") }
    .sorted()

// Pre-load all file data into memory so we're not benchmarking I/O
var fileData: [(name: String, data: Data)] = []
for file in files {
    let url = URL(fileURLWithPath: dirPath).appendingPathComponent(file)
    let data = try Data(contentsOf: url)
    guard MODLoader.identify(data) > 0 else { continue }
    fileData.append((name: file, data: data))
}

let totalBytes = fileData.reduce(0) { $0 + $1.data.count }
print("Loaded \(fileData.count) MOD files (\(totalBytes / 1024) KB) into memory")
print("Running \(iterations) iterations...")

let start = CFAbsoluteTimeGetCurrent()
var parseCount = 0

for _ in 0..<iterations {
    for (_, data) in fileData {
        let _ = try MODLoader.load(data)
        parseCount += 1
    }
}

let ms = (CFAbsoluteTimeGetCurrent() - start) * 1000
let perFile = ms / Double(parseCount)

print("Parsed \(parseCount) files in \(String(format: "%.1f", ms)) ms")
print("Average: \(String(format: "%.3f", perFile)) ms per file")
print("Throughput: \(String(format: "%.1f", Double(totalBytes * iterations) / ms / 1024.0)) MB/s")
