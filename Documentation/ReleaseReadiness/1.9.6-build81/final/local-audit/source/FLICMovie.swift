import Foundation

public enum FLICError: Error, Equatable, CustomStringConvertible {
    case truncatedHeader(size: Int)
    case notFLIC(magic: UInt16)
    case unsupportedDepth(Int)
    case emptyFrameSize(frameIndex: Int, offset: Int)
    case truncatedChunk(frameIndex: Int, offset: Int, declared: Int, available: Int)
    case unsupportedChunk(frameIndex: Int, type: UInt16)
    case runsPastEndOfCanvas(frameIndex: Int, type: UInt16)
    case readPastEndOfChunk(frameIndex: Int, type: UInt16)

    public var description: String {
        switch self {
        case let .truncatedHeader(size):
            return "A FLIC file needs a 128 byte header, but this one is \(size) bytes."
        case let .notFLIC(magic):
            return "Expected the FLIC marker 0xAF11, but found \(String(format: "0x%04X", magic))."
        case let .unsupportedDepth(depth):
            return "This reader handles 8 bits per pixel. The file declares \(depth)."
        case let .emptyFrameSize(frameIndex, offset):
            return "Frame \(frameIndex) at byte \(offset) declares a size of zero."
        case let .truncatedChunk(frameIndex, offset, declared, available):
            return "Frame \(frameIndex) at byte \(offset) declares \(declared) bytes, but only \(available) remain."
        case let .unsupportedChunk(frameIndex, type):
            return "Frame \(frameIndex) holds chunk type \(type), which this reader does not handle."
        case let .runsPastEndOfCanvas(frameIndex, type):
            return "Chunk type \(type) in frame \(frameIndex) writes past the end of the picture."
        case let .readPastEndOfChunk(frameIndex, type):
            return "Chunk type \(type) in frame \(frameIndex) reads past its own end."
        }
    }
}

/// One frame of a FLIC animation, as 8 bit palette indexes plus the palette.
///
/// The palette is carried with every frame because a FLIC changes it partway
/// through. A caller that keeps frames must keep the palette that came with
/// each one.
public struct FLICFrame: Sendable, Equatable {
    /// One byte per pixel, `width * height` of them, in rows from the top.
    public let indexes: [UInt8]
    /// 256 colors, three bytes each, as red, green, and blue.
    public let palette: [UInt8]
    public let width: Int
    public let height: Int

    /// The frame as 32 bit pixels, in red, green, blue, alpha order.
    public func rgbaBytes() -> [UInt8] {
        var out = [UInt8](repeating: 255, count: indexes.count * 4)
        for (pixel, index) in indexes.enumerated() {
            let source = Int(index) * 3
            let target = pixel * 4
            out[target] = palette[source]
            out[target + 1] = palette[source + 1]
            out[target + 2] = palette[source + 2]
        }
        return out
    }
}

/// Reader for the Autodesk FLIC animations that shipped with Lemmings 3.
///
/// A FLIC file is a 128 byte header and then one chunk per frame. Each frame
/// chunk holds smaller chunks that either replace the picture or change the
/// part of it that moved. The reader keeps one canvas and one palette, and
/// each frame changes them, so frames must be read in order.
///
/// The five files in the game use four chunk types. `BYTE_RUN` and `LITERAL`
/// replace the whole picture. `DELTA_FLI` changes the rows that moved.
/// `COLOR_64` changes the palette. Anything else is reported rather than
/// skipped, because a skipped chunk shows as a picture that slowly falls apart.
public struct FLICMovie: Sendable {
    public let width: Int
    public let height: Int
    /// Frames the header declares. This excludes the ring frame described below.
    public let frameCount: Int
    /// How long one frame stays on screen.
    ///
    /// A FLIC counts its delay in jiffies, which are seventieths of a second.
    public let frameDuration: Double

    private let data: Data
    /// Byte offset of every frame chunk, in order.
    ///
    /// A FLIC ends with a ring frame, which is the delta from the last frame
    /// back to the first so the animation can loop without a jump. It is stored
    /// here and left out of `frameCount`.
    public let frameOffsets: [Int]

    public var hasRingFrame: Bool { frameOffsets.count > frameCount }

    private static let headerSize = 128
    private static let frameChunkHeaderSize = 16
    private static let subChunkHeaderSize = 6

    private enum ChunkType: UInt16 {
        case color64 = 11
        case deltaFLI = 12
        case byteRun = 15
        case literal = 16
    }

    public init(data: Data) throws {
        guard data.count >= Self.headerSize else {
            throw FLICError.truncatedHeader(size: data.count)
        }
        self.data = data

        let magic = data.readUInt16(at: 4)
        guard magic == 0xAF11 else { throw FLICError.notFLIC(magic: magic) }

        let depth = Int(data.readUInt16(at: 12))
        guard depth == 8 else { throw FLICError.unsupportedDepth(depth) }

        frameCount = Int(data.readUInt16(at: 6))
        width = Int(data.readUInt16(at: 8))
        height = Int(data.readUInt16(at: 10))
        // A speed of zero means as fast as the machine manages. Treat it as one
        // jiffy so a caller always has a usable number.
        let jiffies = max(1, Int(data.readUInt16(at: 16)))
        frameDuration = Double(jiffies) / 70.0

        // Walk the frame chunks once so any frame can be found later without
        // reading the whole file again.
        var offsets: [Int] = []
        var offset = Self.headerSize
        while offset + Self.frameChunkHeaderSize <= data.count {
            let size = Int(data.readUInt32(at: offset))
            let type = data.readUInt16(at: offset + 4)
            // 0xF100 is an optional prefix chunk holding editor data. It is not
            // a frame, so it is stepped over.
            if type == 0xF1FA {
                offsets.append(offset)
            } else if type != 0xF100 {
                break
            }
            guard size > 0 else { break }
            offset += size
        }
        frameOffsets = offsets
    }

    public init(contentsOf url: URL) throws {
        try self.init(data: Data(contentsOf: url))
    }

    /// Holds the picture and palette while frames are read in order.
    public struct Decoder: Sendable {
        private let movie: FLICMovie
        private var canvas: [UInt8]
        private var palette: [UInt8]
        private(set) public var frameIndex = 0

        init(movie: FLICMovie) {
            self.movie = movie
            canvas = [UInt8](repeating: 0, count: movie.width * movie.height)
            palette = [UInt8](repeating: 0, count: 256 * 3)
        }

        public var hasMoreFrames: Bool { frameIndex < movie.frameOffsets.count }

        /// Applies the next frame and returns the picture it produces.
        ///
        /// A frame that holds no chunks repeats the frame before it, which is
        /// how a FLIC stores a still moment. That returns the same picture
        /// rather than nothing.
        public mutating func nextFrame() throws -> FLICFrame? {
            guard hasMoreFrames else { return nil }
            try movie.apply(
                frameAt: movie.frameOffsets[frameIndex], index: frameIndex,
                canvas: &canvas, palette: &palette)
            frameIndex += 1
            return FLICFrame(
                indexes: canvas, palette: palette,
                width: movie.width, height: movie.height)
        }
    }

    public func makeDecoder() -> Decoder { Decoder(movie: self) }

    /// Reads every frame in order.
    ///
    /// This holds the whole animation in memory. The longest file in the game
    /// is 1282 frames of 320 by 200, which is about 82 MB of indexes. Prefer
    /// `makeDecoder()` for playback, and use this for testing.
    public func decodeAllFrames() throws -> [FLICFrame] {
        var decoder = makeDecoder()
        var frames: [FLICFrame] = []
        frames.reserveCapacity(frameOffsets.count)
        while let frame = try decoder.nextFrame() { frames.append(frame) }
        return frames
    }

    // MARK: - Frame chunks

    private func apply(
        frameAt offset: Int, index: Int,
        canvas: inout [UInt8], palette: inout [UInt8]
    ) throws {
        let size = Int(data.readUInt32(at: offset))
        guard size > 0 else { throw FLICError.emptyFrameSize(frameIndex: index, offset: offset) }
        guard offset + size <= data.count else {
            throw FLICError.truncatedChunk(
                frameIndex: index, offset: offset, declared: size,
                available: data.count - offset)
        }

        let subChunkCount = Int(data.readUInt16(at: offset + 6))
        var cursor = offset + Self.frameChunkHeaderSize
        let frameEnd = offset + size

        for _ in 0..<subChunkCount {
            guard cursor + Self.subChunkHeaderSize <= frameEnd else { break }
            let subSize = Int(data.readUInt32(at: cursor))
            let rawType = data.readUInt16(at: cursor + 4)
            guard let type = ChunkType(rawValue: rawType) else {
                throw FLICError.unsupportedChunk(frameIndex: index, type: rawType)
            }
            let bodyStart = cursor + Self.subChunkHeaderSize
            // A sub-chunk that declares nothing would loop forever. Stop instead.
            guard subSize > Self.subChunkHeaderSize else { break }
            // Read up to the end of the frame rather than the end the sub-chunk
            // declares. The size field is not reliable: every `LITERAL` chunk in
            // these files declares 64004 bytes for a 64000 pixel picture, which
            // is two bytes short of its own contents. The frame chunk size is
            // correct, so it is the boundary that is enforced.
            let bodyEnd = frameEnd

            var reader = ByteReader(data: data, offset: bodyStart, end: bodyEnd)
            switch type {
            case .color64:
                try applyColor64(&reader, palette: &palette, index: index)
            case .byteRun:
                try applyByteRun(&reader, canvas: &canvas, index: index)
            case .literal:
                try applyLiteral(&reader, canvas: &canvas, index: index)
            case .deltaFLI:
                try applyDeltaFLI(&reader, canvas: &canvas, index: index)
            }
            // Advance by what the sub-chunk claims, but never by less than a
            // whole picture after a `LITERAL`, so a short size cannot leave the
            // cursor inside the pixels it just read.
            let consumed = type == .literal
                ? max(subSize, Self.subChunkHeaderSize + width * height)
                : subSize
            cursor += consumed
        }
    }

    /// Replaces palette entries. Components are 0 to 63, as the VGA hardware used.
    private func applyColor64(
        _ reader: inout ByteReader, palette: inout [UInt8], index: Int
    ) throws {
        let type = ChunkType.color64.rawValue
        guard let packets = reader.readUInt16() else {
            throw FLICError.readPastEndOfChunk(frameIndex: index, type: type)
        }
        var entry = 0
        for _ in 0..<Int(packets) {
            guard let skip = reader.readByte(), let rawCount = reader.readByte() else {
                throw FLICError.readPastEndOfChunk(frameIndex: index, type: type)
            }
            entry += Int(skip)
            // A count of zero means all 256 entries, because the field is one byte.
            let count = rawCount == 0 ? 256 : Int(rawCount)
            for _ in 0..<count {
                guard entry < 256 else {
                    throw FLICError.runsPastEndOfCanvas(frameIndex: index, type: type)
                }
                guard let r = reader.readByte(), let g = reader.readByte(),
                    let b = reader.readByte()
                else { throw FLICError.readPastEndOfChunk(frameIndex: index, type: type) }
                // Six bits to eight, so that 63 becomes 255 rather than 252.
                palette[entry * 3] = (r << 2) | (r >> 4)
                palette[entry * 3 + 1] = (g << 2) | (g >> 4)
                palette[entry * 3 + 2] = (b << 2) | (b >> 4)
                entry += 1
            }
        }
    }

    /// Replaces the whole picture, one run-length coded row at a time.
    ///
    /// A positive count is a run of one repeated byte. A negative count is that
    /// many bytes copied as they are. `DELTA_FLI` uses the opposite meaning.
    private func applyByteRun(
        _ reader: inout ByteReader, canvas: inout [UInt8], index: Int
    ) throws {
        let type = ChunkType.byteRun.rawValue
        for row in 0..<height {
            // The row starts with a packet count that the format itself does not
            // keep accurate. Every reader ignores it and fills a row instead.
            guard reader.readByte() != nil else {
                throw FLICError.readPastEndOfChunk(frameIndex: index, type: type)
            }
            var column = 0
            let rowStart = row * width
            while column < width {
                guard let raw = reader.readByte() else {
                    throw FLICError.readPastEndOfChunk(frameIndex: index, type: type)
                }
                let count = Int(Int8(bitPattern: raw))
                if count >= 0 {
                    guard let value = reader.readByte() else {
                        throw FLICError.readPastEndOfChunk(frameIndex: index, type: type)
                    }
                    guard column + count <= width else {
                        throw FLICError.runsPastEndOfCanvas(frameIndex: index, type: type)
                    }
                    for offset in 0..<count { canvas[rowStart + column + offset] = value }
                    column += count
                } else {
                    let literal = -count
                    guard column + literal <= width else {
                        throw FLICError.runsPastEndOfCanvas(frameIndex: index, type: type)
                    }
                    for offset in 0..<literal {
                        guard let value = reader.readByte() else {
                            throw FLICError.readPastEndOfChunk(frameIndex: index, type: type)
                        }
                        canvas[rowStart + column + offset] = value
                    }
                    column += literal
                }
            }
        }
    }

    /// Replaces the whole picture with plain bytes.
    private func applyLiteral(
        _ reader: inout ByteReader, canvas: inout [UInt8], index: Int
    ) throws {
        for pixel in 0..<(width * height) {
            guard let value = reader.readByte() else {
                throw FLICError.readPastEndOfChunk(
                    frameIndex: index, type: ChunkType.literal.rawValue)
            }
            canvas[pixel] = value
        }
    }

    /// Changes only the rows that moved since the frame before.
    ///
    /// A positive count copies that many bytes as they are. A negative count is
    /// a run of one repeated byte. This is the opposite of `BYTE_RUN`, and
    /// getting it the wrong way round is the usual reason a FLIC decodes to
    /// noise.
    private func applyDeltaFLI(
        _ reader: inout ByteReader, canvas: inout [UInt8], index: Int
    ) throws {
        let type = ChunkType.deltaFLI.rawValue
        guard let startLine = reader.readUInt16(), let lineCount = reader.readUInt16() else {
            throw FLICError.readPastEndOfChunk(frameIndex: index, type: type)
        }
        var row = Int(startLine)
        for _ in 0..<Int(lineCount) {
            guard let packets = reader.readByte() else {
                throw FLICError.readPastEndOfChunk(frameIndex: index, type: type)
            }
            guard row < height else {
                throw FLICError.runsPastEndOfCanvas(frameIndex: index, type: type)
            }
            let rowStart = row * width
            var column = 0
            for _ in 0..<Int(packets) {
                guard let skip = reader.readByte(), let raw = reader.readByte() else {
                    throw FLICError.readPastEndOfChunk(frameIndex: index, type: type)
                }
                column += Int(skip)
                let count = Int(Int8(bitPattern: raw))
                if count >= 0 {
                    guard column + count <= width else {
                        throw FLICError.runsPastEndOfCanvas(frameIndex: index, type: type)
                    }
                    for offset in 0..<count {
                        guard let value = reader.readByte() else {
                            throw FLICError.readPastEndOfChunk(frameIndex: index, type: type)
                        }
                        canvas[rowStart + column + offset] = value
                    }
                    column += count
                } else {
                    let run = -count
                    guard let value = reader.readByte() else {
                        throw FLICError.readPastEndOfChunk(frameIndex: index, type: type)
                    }
                    guard column + run <= width else {
                        throw FLICError.runsPastEndOfCanvas(frameIndex: index, type: type)
                    }
                    for offset in 0..<run { canvas[rowStart + column + offset] = value }
                    column += run
                }
            }
            row += 1
        }
    }
}

/// Reads little-endian values forwards through a range of bytes.
private struct ByteReader {
    let data: Data
    var offset: Int
    let end: Int

    mutating func readByte() -> UInt8? {
        guard offset < end else { return nil }
        defer { offset += 1 }
        return data[data.startIndex + offset]
    }

    mutating func readUInt16() -> UInt16? {
        guard offset + 2 <= end else { return nil }
        defer { offset += 2 }
        return data.readUInt16(at: offset)
    }
}

extension Data {
    fileprivate func readUInt16(at offset: Int) -> UInt16 {
        let base = startIndex + offset
        return UInt16(self[base]) | (UInt16(self[base + 1]) << 8)
    }

    fileprivate func readUInt32(at offset: Int) -> UInt32 {
        let base = startIndex + offset
        return UInt32(self[base]) | (UInt32(self[base + 1]) << 8)
            | (UInt32(self[base + 2]) << 16) | (UInt32(self[base + 3]) << 24)
    }
}
