import Foundation

/// Reads an Amiga disk image.
///
/// An ADF is a plain dump of the sectors on an Amiga floppy, so the filesystem
/// can be read directly. This is why an ADF is worth far more than a flux
/// level preservation image such as IPF, which stores the magnetic signal and
/// has to be decoded into sectors before any file can be seen.
///
/// Both Amiga filesystems are handled. The older one puts a header on every
/// data block, and the faster one fills the whole block with file content.

public enum ClassicADFError: Error, Equatable, CustomStringConvertible {
    case notAmigaDisk
    case wrongSize(Int)
    case fileNotFound(String)
    case corruptChain(String)

    public var description: String {
        switch self {
        case .notAmigaDisk: return "the image does not start with an Amiga filesystem"
        case let .wrongSize(count): return "the image is \(count) bytes, which is not a floppy"
        case let .fileNotFound(name): return "no file named \(name) on the disk"
        case let .corruptChain(name): return "the block chain for \(name) does not hold together"
        }
    }
}

/// One file on an Amiga disk.
public struct ClassicADFFile: Sendable {
    /// Path from the root, using a slash between directories.
    public let path: String
    public let name: String
    public let sizeInBytes: Int
    /// Block holding this file's header.
    public let headerBlock: Int
}

public struct ClassicADFVolume: Sendable {
    /// The Amiga filesystem in use.
    public enum Filesystem: String, Sendable {
        /// Every data block carries a header, leaving 488 bytes of content.
        case oldFileSystem
        /// Data blocks are entirely content.
        case fastFileSystem
    }

    private let image: Data
    public let filesystem: Filesystem
    public let volumeName: String
    public let files: [ClassicADFFile]

    private static let blockSize = 512
    /// Entries in a directory hash table.
    private static let hashTableSize = 72
    /// The root sits in the middle of a double density disk.
    private static let rootBlock = 880
    private static let doubleDensitySize = 901_120

    public init(image: Data) throws {
        guard image.count >= Self.doubleDensitySize else {
            throw ClassicADFError.wrongSize(image.count)
        }
        self.image = image

        // The boot block names the filesystem. Bit 0 of the fourth byte tells
        // the two apart, and the higher bits mark variants that read the same.
        let bytes = [UInt8](image.prefix(4))
        guard bytes.count == 4, bytes[0] == 0x44, bytes[1] == 0x4F, bytes[2] == 0x53 else {
            throw ClassicADFError.notAmigaDisk
        }
        filesystem = bytes[3] & 1 == 1 ? .fastFileSystem : .oldFileSystem

        func word(_ block: Int, _ offset: Int) -> Int {
            let base = block * Self.blockSize + offset
            guard base + 3 < image.count else { return 0 }
            return (0..<4).reduce(0) { $0 << 8 | Int(image[base + $1]) }
        }
        func name(_ block: Int) -> String {
            // Names sit near the end of the block as a length byte then text.
            let base = block * Self.blockSize + Self.blockSize - 80
            guard base < image.count else { return "" }
            let length = Int(image[base])
            guard length > 0, length <= 30, base + length < image.count else { return "" }
            return String(decoding: image[(base + 1)...(base + length)], as: UTF8.self)
        }

        volumeName = name(Self.rootBlock)

        // Walk the directory tree. Entries that collide in the hash table are
        // chained, so each bucket is followed to its end.
        var found: [ClassicADFFile] = []
        var visited = Set<Int>()

        func walk(_ directory: Int, prefix: String) {
            guard visited.insert(directory).inserted else { return }
            for bucket in 0..<Self.hashTableSize {
                var entry = word(directory, 24 + bucket * 4)
                var guardCount = 0
                while entry != 0, guardCount < 4_000 {
                    guardCount += 1
                    let secondaryType = Int(Int32(truncatingIfNeeded: word(entry, Self.blockSize - 4)))
                    let entryName = name(entry)
                    if secondaryType == -3 {
                        found.append(ClassicADFFile(
                            path: prefix + entryName,
                            name: entryName,
                            sizeInBytes: word(entry, Self.blockSize - 188),
                            headerBlock: entry))
                    } else if secondaryType == 2 {
                        walk(entry, prefix: prefix + entryName + "/")
                    }
                    entry = word(entry, Self.blockSize - 16)
                }
            }
        }
        walk(Self.rootBlock, prefix: "")
        files = found.sorted { $0.path < $1.path }
    }

    // MARK: - Reading files

    /// Reads a file by path, matching without regard to case.
    public func contents(of path: String) throws -> Data {
        guard let file = files.first(where: {
            $0.path.caseInsensitiveCompare(path) == .orderedSame
                || $0.name.caseInsensitiveCompare(path) == .orderedSame
        }) else {
            throw ClassicADFError.fileNotFound(path)
        }
        return try contents(of: file)
    }

    /// Reads a file by following its data blocks.
    ///
    /// A header holds only so many block pointers, so long files continue in
    /// extension blocks. The pointers are stored last to first, which is why
    /// they are read in reverse.
    public func contents(of file: ClassicADFFile) throws -> Data {
        func word(_ block: Int, _ offset: Int) -> Int {
            let base = block * Self.blockSize + offset
            guard base + 3 < image.count else { return 0 }
            return (0..<4).reduce(0) { $0 << 8 | Int(image[base + $1]) }
        }

        var output = Data(capacity: file.sizeInBytes)
        var header = file.headerBlock
        var visited = Set<Int>()
        let payload = filesystem == .oldFileSystem ? Self.blockSize - 24 : Self.blockSize
        let dataOffset = filesystem == .oldFileSystem ? 24 : 0

        while header != 0, output.count < file.sizeInBytes {
            guard visited.insert(header).inserted else {
                throw ClassicADFError.corruptChain(file.name)
            }
            let pointerCount = word(header, 8)
            guard pointerCount >= 0, pointerCount <= Self.hashTableSize else {
                throw ClassicADFError.corruptChain(file.name)
            }

            // The pointer array fills from its last slot backward, so the
            // first data block sits at the end. Reading from slot zero finds
            // only the unused slots, which are all empty.
            for step in 0..<pointerCount {
                let slot = Self.hashTableSize - 1 - step
                guard slot >= 0 else { break }
                let block = word(header, 24 + slot * 4)
                guard block > 0 else { continue }
                let start = block * Self.blockSize + dataOffset
                let remaining = file.sizeInBytes - output.count
                guard remaining > 0, start < image.count else { break }
                let take = min(payload, remaining, image.count - start)
                output.append(image[start..<(start + take)])
            }
            header = word(header, Self.blockSize - 8)  // extension block
        }
        return output
    }

    /// Every file whose name begins with a prefix, ignoring case.
    public func files(startingWith prefix: String) -> [ClassicADFFile] {
        files.filter { $0.name.lowercased().hasPrefix(prefix.lowercased()) }
    }
}
