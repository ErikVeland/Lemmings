import CoreGraphics
import Foundation
import NxlvKit

/// Original sequel title artwork, decoded once from the bundled game data.
public final class GameHomeLogoArt: @unchecked Sendable {
    public static let bundled = GameHomeLogoArt(resources: Bundle.main.resourceURL)
    private let images: [GameFrontEnd.GameLogo: CGImage]
    private let chronicles: CGImage?
    private let brand: Lemmings3Brand?

    public init(resources: URL?, brand: Lemmings3Brand? = nil) {
        var images: [GameFrontEnd.GameLogo: CGImage] = [:]
        var chronicles: CGImage?
        if let resources {
            images[.lemmings2] = try? Self.lemmings2(resources.appendingPathComponent("Ports/Lemm2"))
            images[.lemmings3] = try? Self.lemmings3(resources.appendingPathComponent("Ports/LEM3CD/FRONT/LOGO.PCX"),
                crop: CGRect(x: 16, y: 34, width: 288, height: 154))
            chronicles = try? Self.lemmings3(resources.appendingPathComponent("MenuArtwork/lemmings-chronicles.pcx"),
                crop: CGRect(x: 55, y: 61, width: 222, height: 144))
        }
        self.images = images
        self.chronicles = chronicles
        self.brand = brand
    }

    public func image(_ game: GameFrontEnd.GameLogo) -> CGImage? {
        if game == .lemmings3, (brand ?? .current) == .chronicles { return chronicles }
        return images[game]
    }

    private static func bitmap(width: Int, height: Int, pixels: [UInt8], palette: [UInt8], transparent: UInt8? = nil) -> CGImage? {
        guard pixels.count == width * height, palette.count == 1024 else { return nil }
        var rgba = Data(capacity: pixels.count * 4)
        for pixel in pixels {
            if pixel == transparent { rgba.append(contentsOf: [0, 0, 0, 0]) }
            else { let index = Int(pixel) * 4; rgba.append(contentsOf: palette[index..<index + 4]) }
        }
        guard let provider = CGDataProvider(data: rgba as CFData) else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue), provider: provider,
            decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }

    private static func lemmings2(_ root: URL) throws -> CGImage? {
        let bank = try Lemmings2FrontEnd.Bank(data: Data(contentsOf: root.appendingPathComponent("FRONTEND/GFXIFFS/MENU.IFF")))
        let decoded = try Lemmings2Compression.decode(Data(contentsOf: root.appendingPathComponent("FRONTEND/SCREENS/MENU.DAT")))
        guard decoded.count == 64000, bank.palettes.count > 1 else { return nil }
        var pixels = [UInt8](repeating: 0, count: decoded.count)
        for i in decoded.indices { pixels[(i % 16000) * 4 + i / 16000] = decoded[i] }
        return bitmap(width: 320, height: 200, pixels: pixels, palette: bank.palettes[1])?
            .cropping(to: CGRect(x: 74, y: 0, width: 215, height: 107))
    }

    private static func lemmings3(_ url: URL, crop: CGRect) throws -> CGImage? {
        let bytes = [UInt8](try Data(contentsOf: url))
        guard bytes.count > 897, bytes[0] == 10, bytes[2] == 1, bytes[3] == 8, bytes[65] == 1,
              bytes[bytes.count - 769] == 12 else { return nil }
        func word(_ offset: Int) -> Int { Int(bytes[offset]) | Int(bytes[offset + 1]) << 8 }
        let width = word(8) - word(4) + 1, height = word(10) - word(6) + 1, stride = word(66)
        guard width > 0, height > 0, width <= 1024, height <= 1024, stride >= width, stride <= 2048 else { return nil }
        let end = bytes.count - 769
        var decoded: [UInt8] = [], cursor = 128
        decoded.reserveCapacity(stride * height)
        while decoded.count < stride * height, cursor < end {
            let byte = bytes[cursor]; cursor += 1
            let count = byte & 0xC0 == 0xC0 ? Int(byte & 0x3F) : 1
            let value: UInt8
            if byte & 0xC0 == 0xC0 {
                guard cursor < end else { return nil }
                value = bytes[cursor]; cursor += 1
            } else { value = byte }
            guard count > 0, decoded.count + count <= stride * height else { return nil }
            decoded.append(contentsOf: repeatElement(value, count: count))
        }
        guard decoded.count == stride * height else { return nil }
        let pixels = (0..<height).flatMap { Array(decoded[$0 * stride..<$0 * stride + width]) }
        let palette = (0..<256).flatMap { index -> [UInt8] in
            let offset = bytes.count - 768 + index * 3
            return [bytes[offset], bytes[offset + 1], bytes[offset + 2], 255]
        }
        return bitmap(width: width, height: height, pixels: pixels, palette: palette, transparent: 0)?
            .cropping(to: crop)
    }
}
