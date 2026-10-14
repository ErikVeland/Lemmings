import Foundation

/// A decompressed section from the container format used by DOS Lemmings
/// `*.DAT` files.
public struct ClassicDATSection: Sendable {
    public let data: Data
    public let archiveOffset: Int
    public let compressedSize: Int
    public let decompressedSize: Int
    public let checksumIsValid: Bool
}

public enum ClassicDATError: Error, Equatable, CustomStringConvertible {
    case truncatedHeader(offset: Int)
    case invalidHeader(offset: Int, compressedSize: Int, decompressedSize: Int)
    case truncatedSection(offset: Int, expectedEnd: Int, fileSize: Int)
    case invalidBitCount(offset: Int, value: Int)
    case corruptBitstream(offset: Int)
    case invalidBackReference(offset: Int, source: Int, outputSize: Int)
    case outputOverflow(offset: Int)
    case checksumMismatch(offset: Int)

    public var description: String {
        switch self {
        case let .truncatedHeader(offset):
            return "Truncated DAT section header at byte \(offset)."
        case let .invalidHeader(offset, compressedSize, decompressedSize):
            return "Invalid DAT section header at byte \(offset) (compressed: \(compressedSize), decompressed: \(decompressedSize))."
        case let .truncatedSection(offset, expectedEnd, fileSize):
            return "DAT section at byte \(offset) ends at \(expectedEnd), beyond file size \(fileSize)."
        case let .invalidBitCount(offset, value):
            return "DAT section at byte \(offset) has invalid initial bit count \(value)."
        case let .corruptBitstream(offset):
            return "DAT section at byte \(offset) has a truncated bitstream."
        case let .invalidBackReference(offset, source, outputSize):
            return "DAT section at byte \(offset) has invalid back-reference \(source) for output size \(outputSize)."
        case let .outputOverflow(offset):
            return "DAT section at byte \(offset) writes beyond its declared output size."
        case let .checksumMismatch(offset):
            return "DAT section at byte \(offset) failed its XOR checksum."
        }
    }
}

/// Decoder for the backwards bitstream/LZ container used by the classic DOS
/// games. Each archive is a concatenation of independently compressed parts.
public enum ClassicDATArchive {
    private static let headerSize = 10

    public static func decode(_ data: Data, verifyChecksum: Bool = true) throws -> [ClassicDATSection] {
        let bytes = [UInt8](data)
        guard !bytes.isEmpty else { return [] }

        var result: [ClassicDATSection] = []
        var offset = 0
        while offset < bytes.count {
            guard bytes.count - offset >= headerSize else {
                throw ClassicDATError.truncatedHeader(offset: offset)
            }

            let decompressedSize = bigEndianWord(bytes, at: offset + 4)
            let compressedSize = bigEndianWord(bytes, at: offset + 8)
            guard compressedSize > headerSize, decompressedSize > 0 else {
                throw ClassicDATError.invalidHeader(
                    offset: offset,
                    compressedSize: compressedSize,
                    decompressedSize: decompressedSize
                )
            }
            let end = offset + compressedSize
            guard end <= bytes.count else {
                throw ClassicDATError.truncatedSection(offset: offset, expectedEnd: end, fileSize: bytes.count)
            }

            let decoded = try decodeSection(
                bytes,
                offset: offset,
                compressedSize: compressedSize,
                decompressedSize: decompressedSize
            )
            if verifyChecksum && !decoded.checksumIsValid {
                throw ClassicDATError.checksumMismatch(offset: offset)
            }
            result.append(decoded)
            offset = end
        }
        return result
    }

    private static func decodeSection(
        _ bytes: [UInt8],
        offset: Int,
        compressedSize: Int,
        decompressedSize: Int
    ) throws -> ClassicDATSection {
        let initialBitCount = Int(bytes[offset])
        guard (0...8).contains(initialBitCount) else {
            throw ClassicDATError.invalidBitCount(offset: offset, value: initialBitCount)
        }

        var readPosition = offset + compressedSize - 1
        var currentByte = bytes[readPosition]
        var bitsRemaining = initialBitCount
        var output = [UInt8](repeating: 0, count: decompressedSize)
        var outputPosition = decompressedSize

        let checksum = bytes[(offset + headerSize)..<(offset + compressedSize)]
            .reduce(bytes[offset + 1], ^)

        func getBits(_ count: Int) throws -> Int {
            var value = 0
            for _ in 0..<count {
                if bitsRemaining == 0 {
                    readPosition -= 1
                    guard readPosition >= offset + headerSize else {
                        throw ClassicDATError.corruptBitstream(offset: offset)
                    }
                    currentByte = bytes[readPosition]
                    bitsRemaining = 8
                }
                let bit = currentByte & 1
                currentByte >>= 1
                bitsRemaining -= 1
                value = (value << 1) | Int(bit)
            }
            return value
        }

        func writeLiteral(_ byte: UInt8) throws {
            guard outputPosition > 0 else {
                throw ClassicDATError.outputOverflow(offset: offset)
            }
            outputPosition -= 1
            output[outputPosition] = byte
        }

        func copyMatch(length: Int, distance: Int) throws {
            guard length <= outputPosition else {
                throw ClassicDATError.outputOverflow(offset: offset)
            }
            for _ in 0..<length {
                guard outputPosition > 0 else {
                    throw ClassicDATError.outputOverflow(offset: offset)
                }
                let destination = outputPosition - 1
                let source = destination + distance
                guard source >= 0, source < output.count else {
                    throw ClassicDATError.invalidBackReference(
                        offset: offset,
                        source: source,
                        outputSize: output.count
                    )
                }
                output[destination] = output[source]
                outputPosition = destination
            }
        }

        while outputPosition > 0 {
            if try getBits(1) == 1 {
                let code = try getBits(2)
                switch code {
                case 0, 1:
                    try copyMatch(length: code + 3, distance: try getBits(code + 9) + 1)
                case 2:
                    let length = try getBits(8) + 1
                    try copyMatch(length: length, distance: try getBits(12) + 1)
                default:
                    let count = try getBits(8) + 9
                    guard count <= outputPosition else {
                        throw ClassicDATError.outputOverflow(offset: offset)
                    }
                    for _ in 0..<count {
                        try writeLiteral(UInt8(try getBits(8)))
                    }
                }
            } else if try getBits(1) == 1 {
                try copyMatch(length: 2, distance: try getBits(8) + 1)
            } else {
                let count = try getBits(3) + 1
                guard count <= outputPosition else {
                    throw ClassicDATError.outputOverflow(offset: offset)
                }
                for _ in 0..<count {
                    try writeLiteral(UInt8(try getBits(8)))
                }
            }
        }

        return ClassicDATSection(
            data: Data(output),
            archiveOffset: offset,
            compressedSize: compressedSize,
            decompressedSize: decompressedSize,
            checksumIsValid: checksum == 0
        )
    }

    private static func bigEndianWord(_ bytes: [UInt8], at offset: Int) -> Int {
        (Int(bytes[offset]) << 8) | Int(bytes[offset + 1])
    }
}
