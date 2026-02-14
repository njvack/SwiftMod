import Foundation

struct BinaryReader {
    let data: Data
    private(set) var offset: Int

    init(data: Data) {
        self.data = data
        self.offset = 0
    }

    var remaining: Int { data.count - offset }

    mutating func seek(to position: Int) {
        offset = position
    }

    mutating func skip(_ count: Int) {
        offset += count
    }

    mutating func readUInt8() throws -> UInt8 {
        guard offset < data.count else { throw BinaryReaderError.endOfData }
        let value = data[offset]
        offset += 1
        return value
    }

    mutating func readInt8() throws -> Int8 {
        return Int8(bitPattern: try readUInt8())
    }

    mutating func readUInt16BE() throws -> UInt16 {
        guard offset + 2 <= data.count else { throw BinaryReaderError.endOfData }
        let value = UInt16(data[offset]) << 8 | UInt16(data[offset + 1])
        offset += 2
        return value
    }

    mutating func readBytes(_ count: Int) throws -> Data {
        guard offset + count <= data.count else { throw BinaryReaderError.endOfData }
        let result = data[offset..<offset + count]
        offset += count
        return result
    }

    mutating func readASCII(_ count: Int) throws -> String {
        let bytes = try readBytes(count)
        // Strip trailing nulls and non-printable characters
        let cleaned = bytes.prefix(while: { $0 >= 0x20 && $0 < 0x7F || $0 == 0 })
        return String(bytes: cleaned, encoding: .ascii)?
            .trimmingCharacters(in: CharacterSet(charactersIn: "\0")) ?? ""
    }

    mutating func readInt8Array(_ count: Int) throws -> [Int8] {
        guard offset + count <= data.count else { throw BinaryReaderError.endOfData }
        var result = [Int8](repeating: 0, count: count)
        for i in 0..<count {
            result[i] = Int8(bitPattern: data[offset + i])
        }
        offset += count
        return result
    }
}

enum BinaryReaderError: Error {
    case endOfData
}
