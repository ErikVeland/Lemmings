import NxlvKit
import CoreGraphics
import Foundation
import ImageIO

/**
 * Decodes CC0 Lix artwork without changing an engine's rules or geometry.
 */
public struct LixArtwork: Sendable {
    public let sceneArtwork: LixSceneArtwork?
    public enum Activity: String, Codable, CaseIterable, Sendable {
        case nothing, faller, tumbler, stunner, lander, splatter, burner, drowner, exiter
        case walker, runner, climber, ascender, floater, imploder, exploder, blocker, builder
        case shrugger, platformer, shrugger2, basher, miner, digger, jumper, batter, cuber
    }

    public struct Frame: Sendable {
        public let activity: Activity
        public let index: Int
        public let width: Int
        public let height: Int
        public let footX: Int
        public let footY: Int
        public let rgba: [UInt8]
    }

    public enum DecodeError: Error, LocalizedError {
        case invalidImage, invalidMetadata
        public var errorDescription: String? {
            switch self {
            case .invalidImage: "The Lix character images are invalid."
            case .invalidMetadata: "The Lix character frame metadata is invalid."
            }
        }
    }

    private struct Rectangle: Decodable {
        let x: Int, y: Int, width: Int, height: Int
    }
    private struct Row: Decodable {
        let activity: Activity
        let row: Int
        let frames: [Rectangle]
    }
    private struct Metadata: Decodable {
        let frameWidth: Int, frameHeight: Int
        let upstreamRightFacingFootAnchor: [Int]
        let rows: [Row]
    }
    private struct Pixels {
        let width: Int, height: Int
        let rgba: [UInt8]
    }
    private let frames: [Activity: [Frame]]

    public init(directory: URL) throws {
        let imageRoot = directory.appendingPathComponent("assets/data/images", isDirectory: true)
        try self.init(spritePNG: Self.read(imageRoot.appendingPathComponent("lixsprites.png"), limit: 2_000_000),
                      recolourPNG: Self.read(imageRoot.appendingPathComponent("lixrecol.png"), limit: 100_000),
                      metadata: Self.read(directory.appendingPathComponent("sprite-metadata.json"), limit: 1_000_000),
                      sceneArtwork: LixSceneArtwork(directory: directory))
    }

    public init(spritePNG: Data, recolourPNG: Data, metadata: Data,
                sceneArtwork: LixSceneArtwork? = nil) throws {
        self.sceneArtwork = sceneArtwork
        guard metadata.count <= 1_000_000 else { throw DecodeError.invalidMetadata }
        let model = try JSONDecoder().decode(Metadata.self, from: metadata)
        let sheet = try Self.decode(spritePNG), recolour = try Self.decode(recolourPNG)
        guard model.frameWidth == 34, model.frameHeight == 34,
              sheet.width == 913, sheet.height == 946,
              recolour.width == 15, recolour.height >= 2, recolour.height <= 32,
              model.upstreamRightFacingFootAnchor == [16, 26],
              model.rows.count == Activity.allCases.count,
              Set(model.rows.map(\.activity)).count == Activity.allCases.count else {
            throw DecodeError.invalidMetadata
        }
        var palette: [UInt32: [UInt8]] = [:]
        for column in 0..<recolour.width {
            palette[Self.colour(recolour.rgba, at: column * 4)] =
                Array(recolour.rgba[((recolour.width + column) * 4)..<((recolour.width + column + 1) * 4)])
        }
        var decoded: [Activity: [Frame]] = [:]
        for row in model.rows {
            guard Activity.allCases.indices.contains(row.row), Activity.allCases[row.row] == row.activity,
                  row.frames.count <= 26 else { throw DecodeError.invalidMetadata }
            var rectangles = Set<Int>()
            decoded[row.activity] = try row.frames.enumerated().map { index, rectangle in
                guard rectangle.width == 34, rectangle.height == 34,
                      rectangle.x >= 1, rectangle.y == 1 + row.row * 35,
                      (rectangle.x - 1).isMultiple(of: 35),
                      rectangle.x <= sheet.width - rectangle.width,
                      rectangle.y <= sheet.height - rectangle.height,
                      rectangles.insert(rectangle.x).inserted else { throw DecodeError.invalidMetadata }
                var bytes = [UInt8]()
                bytes.reserveCapacity(34 * 34 * 4)
                for y in rectangle.y..<(rectangle.y + 34) {
                    for x in rectangle.x..<(rectangle.x + 34) {
                        let offset = (y * sheet.width + x) * 4
                        let colour = Self.colour(sheet.rgba, at: offset)
                        bytes.append(contentsOf: palette[colour] ?? Array(sheet.rgba[offset..<(offset + 4)]))
                    }
                }
                return Frame(activity: row.activity, index: index, width: 34, height: 34,
                             footX: 16, footY: 26, rgba: bytes)
            }
        }
        guard decoded[.walker]?.isEmpty == false, decoded[.stunner]?.isEmpty == false else {
            throw DecodeError.invalidMetadata
        }
        frames = decoded
    }

    public func frameCount(for activity: Activity) -> Int { frames[activity]?.count ?? 0 }

    public func frame(activity: Activity, animationFrame: Int, facingLeft: Bool) -> Frame? {
        guard let sequence = frames[activity], !sequence.isEmpty else { return nil }
        let index = ((animationFrame % sequence.count) + sequence.count) % sequence.count
        let frame = sequence[index]
        guard facingLeft else { return frame }
        var rgba = frame.rgba
        for y in 0..<frame.height {
            for x in 0..<frame.width {
                let source = (y * frame.width + frame.width - 1 - x) * 4
                let target = (y * frame.width + x) * 4
                rgba.replaceSubrange(target..<(target + 4), with: frame.rgba[source..<(source + 4)])
            }
        }
        return Frame(activity: activity, index: index, width: frame.width, height: frame.height,
                     footX: frame.width - frame.footX - 2, footY: frame.footY, rgba: rgba)
    }

    private static func read(_ url: URL, limit: Int) throws -> Data {
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true,
              let size = values.fileSize, size > 0, size <= limit else { throw DecodeError.invalidImage }
        return try Data(contentsOf: url)
    }

    private static func colour(_ rgba: [UInt8], at offset: Int) -> UInt32 {
        UInt32(rgba[offset]) << 24 | UInt32(rgba[offset + 1]) << 16
            | UInt32(rgba[offset + 2]) << 8 | UInt32(rgba[offset + 3])
    }

    private static func decode(_ data: Data) throws -> Pixels {
        guard data.count <= 2_000_000,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) == 1,
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              image.width > 0, image.height > 0, image.width <= 1024, image.height <= 1024 else {
            throw DecodeError.invalidImage
        }
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        guard let context = CGContext(data: &bytes, width: image.width, height: image.height,
            bitsPerComponent: 8, bytesPerRow: image.width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw DecodeError.invalidImage
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        for offset in stride(from: 0, to: bytes.count, by: 4) {
            let alpha = Int(bytes[offset + 3])
            if alpha > 0 && alpha < 255 {
                for channel in 0..<3 {
                    bytes[offset + channel] = UInt8(min(255, (Int(bytes[offset + channel]) * 255 + alpha / 2) / alpha))
                }
            }
        }
        return Pixels(width: image.width, height: image.height, rgba: bytes)
    }
}
