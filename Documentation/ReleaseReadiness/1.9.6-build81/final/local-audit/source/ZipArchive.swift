import Compression
import Foundation

public enum ZipArchiveError: Error, Equatable, CustomStringConvertible {
    case notAnArchive
    case unsupported(String)
    case corrupt(String)
    case missing(String)
    case ambiguous(String)
    case tooLarge(String)

    public var description: String {
        switch self {
        case .notAnArchive: return "The file is not a ZIP archive."
        case let .unsupported(reason): return "Unsupported ZIP feature: \(reason)."
        case let .corrupt(reason): return "The ZIP archive is damaged: \(reason)."
        case let .missing(name): return "The archive has no member named \(name)."
        case let .ambiguous(name): return "The archive has more than one member named \(name)."
        case let .tooLarge(name): return "The archive member \(name) is too large."
        }
    }
}

/// A read-only ZIP reader that never writes member paths to disk.
///
/// Fan level packs are small, so the archive is mapped and each member is
/// decoded on request. Member names are only labels: nothing here resolves a
/// name against the file system.
public struct ZipArchive: Sendable {
    public struct Member: Equatable, Sendable {
        public let name: String
        public let compressedSize: Int
        public let uncompressedSize: Int
        let method: UInt16
        let crc32: UInt32
        let localHeaderOffset: Int
        /// The Unix file type and permission bits, or 0 when the archive was not made on Unix.
        public let unixMode: UInt16
        public var isSymbolicLink: Bool { unixMode & 0xF000 == 0xA000 }
    }

    /// The largest member this reader will decode.
    public static let maximumMemberSize = 4 * 1024 * 1024

    public let members: [Member]
    private let data: Data

    public init(data: Data) throws {
        self.data = data
        guard data.count >= 22 else { throw ZipArchiveError.notAnArchive }
        // The end record sits in the last 22 + 65,535 bytes.
        let lowest = max(0, data.count - 22 - 65_535)
        var end: Int?
        var offset = data.count - 22
        while offset >= lowest {
            if Self.u32(data, offset) == 0x0605_4B50 { end = offset; break }
            offset -= 1
        }
        guard let end else { throw ZipArchiveError.notAnArchive }
        let count = Int(Self.u16(data, end + 10))
        let directorySize = Int(Self.u32(data, end + 12))
        let directoryOffset = Int(Self.u32(data, end + 16))
        guard count != 0xFFFF, directorySize != 0xFFFF_FFFF, directoryOffset != 0xFFFF_FFFF else {
            throw ZipArchiveError.unsupported("ZIP64")
        }
        guard directoryOffset >= 0, directoryOffset + directorySize <= end else {
            throw ZipArchiveError.corrupt("central directory")
        }
        var cursor = directoryOffset
        var found: [Member] = []
        found.reserveCapacity(count)
        for _ in 0..<count {
            guard cursor + 46 <= data.count, Self.u32(data, cursor) == 0x0201_4B50 else {
                throw ZipArchiveError.corrupt("central directory entry")
            }
            let flags = Self.u16(data, cursor + 8)
            guard flags & 1 == 0 else { throw ZipArchiveError.unsupported("encryption") }
            let method = Self.u16(data, cursor + 10)
            let crc = Self.u32(data, cursor + 16)
            let compressed = Int(Self.u32(data, cursor + 20))
            let uncompressed = Int(Self.u32(data, cursor + 24))
            let nameLength = Int(Self.u16(data, cursor + 28))
            let extraLength = Int(Self.u16(data, cursor + 30))
            let commentLength = Int(Self.u16(data, cursor + 32))
            let local = Int(Self.u32(data, cursor + 42))
            let madeBy = Self.u16(data, cursor + 4) >> 8
            let mode = madeBy == 3 ? UInt16(truncatingIfNeeded: Self.u32(data, cursor + 38) >> 16) : 0
            guard cursor + 46 + nameLength + extraLength + commentLength <= data.count else {
                throw ZipArchiveError.corrupt("central directory entry")
            }
            let rawName = data.subdata(in: (cursor + 46)..<(cursor + 46 + nameLength))
            let name = flags & 0x800 != 0
                ? String(decoding: rawName, as: UTF8.self)
                : (String(data: rawName, encoding: .utf8) ?? String(data: rawName, encoding: .isoLatin1) ?? "")
            // Directory entries carry no data.
            if !name.hasSuffix("/") {
                found.append(Member(name: name, compressedSize: compressed, uncompressedSize: uncompressed,
                                    method: method, crc32: crc, localHeaderOffset: local, unixMode: mode))
            }
            cursor += 46 + nameLength + extraLength + commentLength
        }
        members = found
    }

    public init(contentsOf url: URL) throws {
        try self.init(data: Data(contentsOf: url, options: .mappedIfSafe))
    }

    /// Member names in archive order.
    public var names: [String] { members.map(\.name) }

    /// Decodes the one member with exactly this name.
    public func contents(of name: String) throws -> Data {
        let matches = members.filter { $0.name == name }
        guard !matches.isEmpty else { throw ZipArchiveError.missing(name) }
        guard matches.count == 1 else { throw ZipArchiveError.ambiguous(name) }
        return try contents(of: matches[0])
    }

    public func contents(of member: Member) throws -> Data {
        guard member.uncompressedSize <= Self.maximumMemberSize else { throw ZipArchiveError.tooLarge(member.name) }
        let local = member.localHeaderOffset
        guard local >= 0, local + 30 <= data.count, Self.u32(data, local) == 0x0403_4B50 else {
            throw ZipArchiveError.corrupt("local header of \(member.name)")
        }
        let start = local + 30 + Int(Self.u16(data, local + 26)) + Int(Self.u16(data, local + 28))
        guard start >= 0, start + member.compressedSize <= data.count else {
            throw ZipArchiveError.corrupt("data of \(member.name)")
        }
        let packed = data.subdata(in: start..<(start + member.compressedSize))
        let result: Data
        switch member.method {
        case 0:
            result = packed
        case 8:
            result = try Self.inflate(packed, size: member.uncompressedSize, name: member.name)
        default:
            throw ZipArchiveError.unsupported("compression method \(member.method)")
        }
        guard result.count == member.uncompressedSize else { throw ZipArchiveError.corrupt("size of \(member.name)") }
        guard Self.crc32(result) == member.crc32 else { throw ZipArchiveError.corrupt("checksum of \(member.name)") }
        return result
    }

    /// Streams one member to a file handle without holding it in memory.
    ///
    /// Soundtrack tracks run to tens of megabytes, so they cannot go through
    /// `contents(of:)`. The decoder checks the size and checksum as it goes and
    /// throws before returning if either is wrong. The caller owns the handle.
    public func extract(_ member: Member, to output: FileHandle, limit: Int = 512 * 1024 * 1024) throws {
        guard member.uncompressedSize <= limit else { throw ZipArchiveError.tooLarge(member.name) }
        let local = member.localHeaderOffset
        guard local >= 0, local + 30 <= data.count, Self.u32(data, local) == 0x0403_4B50 else {
            throw ZipArchiveError.corrupt("local header of \(member.name)")
        }
        let start = local + 30 + Int(Self.u16(data, local + 26)) + Int(Self.u16(data, local + 28))
        guard start >= 0, start + member.compressedSize <= data.count else {
            throw ZipArchiveError.corrupt("data of \(member.name)")
        }
        guard member.method == 0 || member.method == 8 else {
            throw ZipArchiveError.unsupported("compression method \(member.method)")
        }
        var crc: UInt32 = 0xFFFF_FFFF
        var written = 0
        func emit(_ bytes: UnsafeRawBufferPointer) throws {
            guard written + bytes.count <= member.uncompressedSize else { throw ZipArchiveError.corrupt("size of \(member.name)") }
            for byte in bytes { crc = Self.crcTable[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8) }
            try output.write(contentsOf: Data(bytes))
            written += bytes.count
        }
        try data.withUnsafeBytes { whole in
            let packed = UnsafeRawBufferPointer(rebasing: whole[(whole.startIndex + start)..<(whole.startIndex + start + member.compressedSize)])
            if member.method == 0 {
                var offset = 0
                while offset < packed.count {
                    let count = min(1 << 20, packed.count - offset)
                    try emit(UnsafeRawBufferPointer(rebasing: packed[offset..<(offset + count)]))
                    offset += count
                }
                return
            }
            let chunk = 1 << 20
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: chunk)
            defer { buffer.deallocate() }
            let state = UnsafeMutablePointer<compression_stream>.allocate(capacity: 1)
            defer { state.deallocate() }
            guard compression_stream_init(state, COMPRESSION_STREAM_DECODE, COMPRESSION_ZLIB) == COMPRESSION_STATUS_OK else {
                throw ZipArchiveError.corrupt("decoder for \(member.name)")
            }
            defer { compression_stream_destroy(state) }
            guard let base = packed.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                if member.uncompressedSize == 0 { return }
                throw ZipArchiveError.corrupt("data of \(member.name)")
            }
            state.pointee.src_ptr = base
            state.pointee.src_size = packed.count
            state.pointee.dst_ptr = buffer
            state.pointee.dst_size = chunk
            while true {
                let status = compression_stream_process(state, Int32(COMPRESSION_STREAM_FINALIZE.rawValue))
                let produced = chunk - state.pointee.dst_size
                if produced > 0 { try emit(UnsafeRawBufferPointer(start: buffer, count: produced)) }
                state.pointee.dst_ptr = buffer
                state.pointee.dst_size = chunk
                if status == COMPRESSION_STATUS_END { break }
                guard status == COMPRESSION_STATUS_OK else { throw ZipArchiveError.corrupt("data of \(member.name)") }
            }
        }
        guard written == member.uncompressedSize else { throw ZipArchiveError.corrupt("size of \(member.name)") }
        guard crc ^ 0xFFFF_FFFF == member.crc32 else { throw ZipArchiveError.corrupt("checksum of \(member.name)") }
    }

    // MARK: - Decoding

    private static func inflate(_ packed: Data, size: Int, name: String) throws -> Data {
        if size == 0 { return Data() }
        var output = Data(count: size)
        let written = output.withUnsafeMutableBytes { destination -> Int in
            packed.withUnsafeBytes { source -> Int in
                guard let destinationBase = destination.bindMemory(to: UInt8.self).baseAddress,
                      let sourceBase = source.bindMemory(to: UInt8.self).baseAddress else { return 0 }
                // Apple's ZLIB algorithm decodes a raw DEFLATE stream, which is what ZIP stores.
                return compression_decode_buffer(destinationBase, size, sourceBase, packed.count, nil, COMPRESSION_ZLIB)
            }
        }
        guard written == size else { throw ZipArchiveError.corrupt("data of \(name)") }
        return output
    }

    private static let crcTable: [UInt32] = (0..<256).map { index in
        var value = UInt32(index)
        for _ in 0..<8 { value = value & 1 == 1 ? 0xEDB8_8320 ^ (value >> 1) : value >> 1 }
        return value
    }

    static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data { crc = crcTable[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8) }
        return crc ^ 0xFFFF_FFFF
    }

    private static func u16(_ data: Data, _ offset: Int) -> UInt16 {
        let base = data.startIndex + offset
        return UInt16(data[base]) | UInt16(data[base + 1]) << 8
    }

    private static func u32(_ data: Data, _ offset: Int) -> UInt32 {
        let base = data.startIndex + offset
        return UInt32(data[base]) | UInt32(data[base + 1]) << 8 | UInt32(data[base + 2]) << 16 | UInt32(data[base + 3]) << 24
    }
}
