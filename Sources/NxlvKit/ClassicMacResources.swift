import Foundation

/// Reads a classic Mac HFS disk image, its resource forks, and the sampled
/// sounds inside them.
///
/// This matters because the Mac release names its sounds. A bank of numbered
/// samples has to be identified by ear, but a resource fork carries `OhNo`,
/// `Splat` and `LetsGo` as names, and each sound records its own sample rate.
/// Nothing has to be guessed.

public enum ClassicMacError: Error, Equatable, CustomStringConvertible {
    case notHFS
    case truncated(String)
    case noResourceFork(String)
    case fileNotFound(String)

    public var description: String {
        switch self {
        case .notHFS: return "the image does not begin with an HFS volume"
        case let .truncated(what): return "the image ends part way through \(what)"
        case let .noResourceFork(name): return "\(name) has no resource fork"
        case let .fileNotFound(name): return "no file named \(name) on the volume"
        }
    }
}

/// One file in the volume catalog.
public struct ClassicMacFile: Sendable {
    public let name: String
    public let type: String
    public let creator: String
    public let resourceForkLength: Int
    /// Up to three extents, each a starting allocation block and a count.
    public let resourceExtents: [(start: Int, count: Int)]
}

/// A read-only view of an HFS volume.
public struct ClassicHFSVolume: Sendable {
    private let image: Data
    private let allocationBlockSize: Int
    private let firstAllocationSector: Int
    public let volumeName: String
    public let files: [ClassicMacFile]

    private static let masterDirectoryBlock = 1024
    private static let sectorSize = 512

    public init(image: Data) throws {
        self.image = image
        let mdb = Self.masterDirectoryBlock
        guard image.count > mdb + 162 else { throw ClassicMacError.truncated("the volume header") }

        func u16(_ offset: Int) -> Int {
            Int(image[offset]) << 8 | Int(image[offset + 1])
        }
        func u32(_ offset: Int) -> Int {
            (0..<4).reduce(0) { $0 << 8 | Int(image[offset + $1]) }
        }

        guard u16(mdb) == 0x4244 else { throw ClassicMacError.notHFS }
        // Held as locals too, because the helpers below run before every
        // stored property is initialized and so cannot capture self.
        let blockSize = u32(mdb + 20)
        let firstSector = u16(mdb + 28)
        allocationBlockSize = blockSize
        firstAllocationSector = firstSector
        let nameLength = Int(image[mdb + 36])
        volumeName = String(
            decoding: image[(mdb + 37)..<(mdb + 37 + min(nameLength, 27))], as: UTF8.self)

        // The catalog and extents fields sit after the Finder info block.
        let catalogSize = u32(mdb + 146)
        var catalogExtents: [(Int, Int)] = []
        for index in 0..<3 {
            catalogExtents.append((u16(mdb + 150 + index * 4), u16(mdb + 152 + index * 4)))
        }

        func offset(ofAllocationBlock block: Int) -> Int {
            firstSector * Self.sectorSize + block * blockSize
        }
        func read(extents: [(Int, Int)], length: Int) -> Data {
            var out = Data()
            for (start, count) in extents where count > 0 {
                let from = offset(ofAllocationBlock: start)
                let to = min(image.count, from + count * blockSize)
                guard from < to else { continue }
                out.append(image[from..<to])
            }
            return out.prefix(length)
        }

        let catalog = read(extents: catalogExtents, length: catalogSize)
        files = Self.parseCatalog(catalog)
    }

    /// Walks the catalog leaf nodes and collects file records.
    ///
    /// Only leaves are read. Index nodes describe the tree shape, which is not
    /// needed to list every file.
    private static func parseCatalog(_ catalog: Data) -> [ClassicMacFile] {
        let nodeSize = 512
        var result: [ClassicMacFile] = []
        let bytes = [UInt8](catalog)

        func u16(_ base: Int, _ offset: Int) -> Int {
            guard base + offset + 1 < bytes.count else { return 0 }
            return Int(bytes[base + offset]) << 8 | Int(bytes[base + offset + 1])
        }
        func u32(_ base: Int, _ offset: Int) -> Int {
            guard base + offset + 3 < bytes.count else { return 0 }
            return (0..<4).reduce(0) { $0 << 8 | Int(bytes[base + offset + $1]) }
        }

        for node in 0..<(bytes.count / nodeSize) {
            let base = node * nodeSize
            let kind = Int8(bitPattern: bytes[base + 8])
            let records = u16(base, 10)
            guard kind == -1, records > 0 else { continue }

            // Record offsets are stored backwards from the end of the node.
            var offsets: [Int] = []
            for index in 0...records {
                offsets.append(u16(base, nodeSize - 2 * (index + 1)))
            }
            for index in 0..<records {
                let start = offsets[index]
                let end = offsets[index + 1]
                guard start > 0, start < end, end <= nodeSize else { continue }

                let keyLength = Int(bytes[base + start])
                guard keyLength >= 6 else { continue }
                let nameLength = Int(bytes[base + start + 6])
                let nameStart = base + start + 7
                guard nameStart + nameLength <= base + end else { continue }
                let name = String(
                    decoding: bytes[nameStart..<(nameStart + nameLength)], as: UTF8.self)

                var dataStart = start + 1 + keyLength
                if dataStart % 2 != 0 { dataStart += 1 }
                let data = base + dataStart
                guard data + 98 <= base + end else { continue }
                guard bytes[data] == 2 else { continue }  // file record

                let type = String(decoding: bytes[(data + 4)..<(data + 8)], as: UTF8.self)
                let creator = String(decoding: bytes[(data + 8)..<(data + 12)], as: UTF8.self)
                let resourceLength = u32(data, 36)
                var extents: [(Int, Int)] = []
                for slot in 0..<3 {
                    extents.append((u16(data, 86 + slot * 4), u16(data, 88 + slot * 4)))
                }
                result.append(ClassicMacFile(
                    name: name, type: type, creator: creator,
                    resourceForkLength: resourceLength, resourceExtents: extents))
            }
        }
        return result
    }

    /// Reads a named file's resource fork.
    public func resourceFork(named name: String) throws -> Data {
        guard let file = files.first(where: { $0.name == name }) else {
            throw ClassicMacError.fileNotFound(name)
        }
        guard file.resourceForkLength > 0 else {
            throw ClassicMacError.noResourceFork(name)
        }
        var out = Data()
        for (start, count) in file.resourceExtents where count > 0 {
            let from = firstAllocationSector * Self.sectorSize + start * allocationBlockSize
            let to = min(image.count, from + count * allocationBlockSize)
            guard from < to else { continue }
            out.append(image[from..<to])
        }
        return out.prefix(file.resourceForkLength)
    }
}

/// One resource, with the name the author gave it.
public struct ClassicMacResource: Sendable {
    public let type: String
    public let id: Int
    public let name: String?
    public let data: Data
}

public enum ClassicResourceFork {
    /// Lists every resource of one type.
    public static func resources(ofType wanted: String, in fork: Data) -> [ClassicMacResource] {
        let bytes = [UInt8](fork)
        func u16(_ offset: Int) -> Int {
            guard offset + 1 < bytes.count else { return 0 }
            return Int(bytes[offset]) << 8 | Int(bytes[offset + 1])
        }
        func u32(_ offset: Int) -> Int {
            guard offset + 3 < bytes.count else { return 0 }
            return (0..<4).reduce(0) { $0 << 8 | Int(bytes[offset + $1]) }
        }

        guard bytes.count > 16 else { return [] }
        let dataOffset = u32(0)
        let mapOffset = u32(4)
        guard mapOffset + 30 < bytes.count else { return [] }
        let typeListOffset = mapOffset + u16(mapOffset + 24)
        let nameListOffset = mapOffset + u16(mapOffset + 26)
        let typeCount = u16(typeListOffset) + 1

        var result: [ClassicMacResource] = []
        for index in 0..<typeCount {
            let entry = typeListOffset + 2 + index * 8
            guard entry + 8 <= bytes.count else { break }
            let type = String(decoding: bytes[entry..<(entry + 4)], as: UTF8.self)
            guard type == wanted else { continue }

            let count = u16(entry + 4) + 1
            let referenceList = typeListOffset + u16(entry + 6)
            for slot in 0..<count {
                let reference = referenceList + slot * 12
                guard reference + 12 <= bytes.count else { break }
                let id = Int(Int16(bitPattern: UInt16(u16(reference))))
                let nameOffset = Int(Int16(bitPattern: UInt16(u16(reference + 2))))
                let payload = dataOffset + (u32(reference + 4) & 0x00FF_FFFF)
                guard payload + 4 <= bytes.count else { continue }
                let length = u32(payload)
                let from = payload + 4
                let to = min(bytes.count, from + length)
                guard from <= to else { continue }

                var name: String?
                if nameOffset >= 0 {
                    let position = nameListOffset + nameOffset
                    if position < bytes.count {
                        let nameLength = Int(bytes[position])
                        let start = position + 1
                        if start + nameLength <= bytes.count {
                            name = String(
                                decoding: bytes[start..<(start + nameLength)], as: UTF8.self)
                        }
                    }
                }
                result.append(ClassicMacResource(
                    type: type, id: id, name: name, data: Data(bytes[from..<to])))
            }
        }
        return result.sorted { $0.id < $1.id }
    }
}

/// A sampled sound taken from a `snd ` resource.
public struct ClassicMacSound: Sendable {
    public let id: Int
    public let name: String?
    /// Unsigned 8-bit PCM, silence at 128.
    public let pcm: [UInt8]
    /// The rate the resource itself records, so nothing is guessed.
    public let sampleRate: Double

    public var duration: Double { sampleRate > 0 ? Double(pcm.count) / sampleRate : 0 }

    public func floatSamples() -> [Float] {
        pcm.map { (Float($0) - 128.0) / 128.0 }
    }
}

public enum ClassicMacSoundDecoder {
    /// Decodes a `snd ` resource holding uncompressed samples.
    ///
    /// Format 1 lists synthesizers then commands. The command that carries a
    /// buffer points at a sound header, which holds the rate and the samples.
    /// Compressed encodings are skipped rather than guessed at.
    public static func decode(_ resource: ClassicMacResource) -> ClassicMacSound? {
        let bytes = [UInt8](resource.data)
        func u16(_ offset: Int) -> Int? {
            guard offset + 1 < bytes.count else { return nil }
            return Int(bytes[offset]) << 8 | Int(bytes[offset + 1])
        }
        func u32(_ offset: Int) -> Int? {
            guard offset + 3 < bytes.count else { return nil }
            return (0..<4).reduce(0) { $0 << 8 | Int(bytes[offset + $1]) }
        }

        guard let format = u16(0) else { return nil }
        var cursor = 2
        switch format {
        case 1:
            guard let synths = u16(cursor) else { return nil }
            cursor += 2 + synths * 6
        case 2:
            cursor += 2
        default:
            return nil
        }

        guard let commands = u16(cursor) else { return nil }
        cursor += 2
        var headerOffset: Int?
        for _ in 0..<commands {
            guard let command = u16(cursor), let parameter = u32(cursor + 4) else { break }
            // soundCmd and bufferCmd both point at a header.
            if command & 0x7FFF == 80 || command & 0x7FFF == 81 { headerOffset = parameter }
            cursor += 8
        }

        guard let header = headerOffset, header + 22 <= bytes.count,
            let length = u32(header + 4), let rateFixed = u32(header + 8)
        else { return nil }
        let encoding = bytes[header + 20]
        guard encoding == 0 else { return nil }  // standard header only

        let start = header + 22
        let end = min(bytes.count, start + length)
        guard start < end else { return nil }
        return ClassicMacSound(
            id: resource.id,
            name: resource.name,
            pcm: Array(bytes[start..<end]),
            sampleRate: Double(rateFixed) / 65_536.0)
    }

    /// Decodes every sound in a resource fork.
    public static func sounds(in fork: Data) -> [ClassicMacSound] {
        ClassicResourceFork.resources(ofType: "snd ", in: fork).compactMap(decode)
    }
}
