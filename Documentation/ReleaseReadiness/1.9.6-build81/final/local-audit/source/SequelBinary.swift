import Foundation

public enum SequelDataError: Error, Equatable, CustomStringConvertible {
    case invalid(String)
    public var description: String {
        switch self { case let .invalid(message): return message }
    }
}

/// Bounds-checked reads shared by the sequel data interpreters.
struct SequelBinary {
    let bytes: [UInt8]
    init(_ data: Data) { bytes = Array(data) }
    var count: Int { bytes.count }

    func slice(_ offset: Int, _ count: Int) throws -> [UInt8] {
        guard offset >= 0, count >= 0, offset <= bytes.count,
            count <= bytes.count - offset else {
            throw SequelDataError.invalid("Truncated sequel data at byte \(offset).")
        }
        return Array(bytes[offset..<(offset + count)])
    }

    func u16(_ offset: Int) throws -> Int {
        let b = try slice(offset, 2)
        return Int(b[0]) | Int(b[1]) << 8
    }

    func u32(_ offset: Int, bigEndian: Bool = false) throws -> Int {
        let b = try slice(offset, 4)
        let ordered = bigEndian ? Array(b.reversed()) : b
        return ordered.enumerated().reduce(0) { $0 | Int($1.element) << ($1.offset * 8) }
    }

    func tag(_ offset: Int) throws -> String {
        String(decoding: try slice(offset, 4), as: UTF8.self)
    }
}

/// GSCM byte-pair decompression used by Lemmings 2. This reads data, not DOS code.
public enum Lemmings2Compression {
    public static func decode(_ data: Data, maximumOutputSize: Int = 64 * 1024 * 1024) throws -> Data {
        guard maximumOutputSize >= 0 else {
            throw SequelDataError.invalid("The decompression limit must not be negative.")
        }
        let reader = SequelBinary(data)
        guard data.starts(with: Array("GSCM".utf8)) else {
            guard data.count <= maximumOutputSize else {
                throw SequelDataError.invalid("Uncompressed data exceeds the size limit.")
            }
            return data
        }
        let size = try reader.u32(4)
        guard size <= maximumOutputSize else {
            throw SequelDataError.invalid("GSCM output exceeds the size limit.")
        }
        var output: [UInt8] = []
        var cursor = 8
        var finished = false
        while !finished {
            let last = try reader.slice(cursor, 1)[0]
            let count = try reader.u16(cursor + 1)
            cursor += 3
            let symbols = try reader.slice(cursor, count)
            let first = try reader.slice(cursor + count, count)
            let second = try reader.slice(cursor + count * 2, count)
            cursor += count * 3

            // Immutable nodes preserve the previous meaning of a symbol when
            // a dictionary entry refers to itself or is redefined later.
            var pairs: [(Int, Int)] = []
            var lengths = Array(repeating: 1, count: 256)
            var dictionary = Array(0..<256)
            for index in 0..<count {
                let a = dictionary[Int(first[index])]
                let b = dictionary[Int(second[index])]
                guard lengths[a] <= maximumOutputSize - lengths[b] else {
                    throw SequelDataError.invalid("GSCM symbol exceeds the size limit.")
                }
                dictionary[Int(symbols[index])] = lengths.count
                pairs.append((a, b))
                lengths.append(lengths[a] + lengths[b])
            }
            let encodedCount = try reader.u16(cursor)
            cursor += 2
            let encoded = try reader.slice(cursor, encodedCount)
            cursor += encodedCount
            for byte in encoded {
                let node = dictionary[Int(byte)]
                guard lengths[node] <= size - output.count else {
                    throw SequelDataError.invalid("GSCM output exceeds its declared size.")
                }
                var stack = [node]
                while let next = stack.popLast() {
                    if next < 256 { output.append(UInt8(next)) }
                    else {
                        let pair = pairs[next - 256]
                        stack.append(pair.1)
                        stack.append(pair.0)
                    }
                }
            }
            finished = last != 0
        }
        guard output.count == size, cursor == reader.count else {
            throw SequelDataError.invalid("GSCM size or end-of-file mismatch.")
        }
        return Data(output)
    }
}

/// Lemmings 2 uses big-endian FORM lengths and little-endian section fields.
public struct Lemmings2Form: Sendable {
    public struct Section: Sendable {
        public let identifier: String
        public let data: Data
    }
    public let type: String
    public let sections: [Section]

    public init(data: Data) throws {
        let reader = SequelBinary(try Lemmings2Compression.decode(data))
        guard try reader.tag(0) == "FORM",
            try reader.u32(4, bigEndian: true) == reader.count - 8 else {
            throw SequelDataError.invalid("Invalid Lemmings 2 FORM header or length.")
        }
        type = try reader.tag(8)
        var result: [Section] = []
        var cursor = 12
        while cursor < reader.count {
            let identifier = try reader.tag(cursor)
            let size = try reader.u32(cursor + 4, bigEndian: true)
            result.append(Section(identifier: identifier, data: Data(try reader.slice(cursor + 8, size))))
            cursor += 8 + size
        }
        sections = result
    }

    public func requiredSection(_ identifier: String) throws -> Data {
        let matches = sections.filter { $0.identifier == identifier }
        guard matches.count == 1 else {
            throw SequelDataError.invalid("Expected one \(identifier) section, found \(matches.count).")
        }
        return matches[0].data
    }
}
