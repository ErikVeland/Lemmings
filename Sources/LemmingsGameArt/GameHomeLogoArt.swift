import CoreGraphics
import Foundation
import LemmingsAppCore
import NxlvKit

/// Original sequel title artwork, decoded once from the bundled game data.
public final class GameHomeLogoArt: @unchecked Sendable {
    private static let generations = GameAssetCache<GameHomeLogoArt>(capacity: 2)
    private static let lemmings2ResolutionScale = 2
    public static var bundled: GameHomeLogoArt {
        let key = GameResources.revision
        if let cached = generations.value(for: key) { return cached }
        let artwork = GameHomeLogoArt(resources: GameResources.resourceURL)
        generations.insert(artwork, for: key)
        return artwork
    }
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
        guard !GamePresentationText.usesLemmixNames else { return nil }
        if game == .lemmings3, (brand ?? .current) == .chronicles { return chronicles }
        return images[game]
    }

    static func resolutionScale(for game: GameFrontEnd.GameLogo) -> CGFloat {
        game == .lemmings2 ? CGFloat(lemmings2ResolutionScale) : 1
    }

    private static func bitmap(width: Int, height: Int, pixels: [UInt8], palette: [UInt8],
                               transparent: UInt8, doubleResolution: Bool = false) -> CGImage? {
        guard pixels.count == width * height, palette.count == 1024 else { return nil }
        var rgba: [UInt8] = []
        rgba.reserveCapacity(pixels.count * 4)
        for pixel in pixels {
            if pixel == transparent { rgba.append(contentsOf: [0, 0, 0, 0]) }
            else { let index = Int(pixel) * 4; rgba.append(contentsOf: palette[index..<index + 4]) }
        }
        if doubleResolution {
            rgba = antialiased2x(rgba, width: width, height: height)
            drawTribesOutline(in: &rgba, pixels: pixels, palette: palette, width: width, height: height)
        }
        guard let provider = CGDataProvider(data: Data(rgba) as CFData) else { return nil }
        let scale = doubleResolution ? lemmings2ResolutionScale : 1
        let pixelWidth = width * scale
        return CGImage(width: pixelWidth, height: height * scale, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: pixelWidth * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue), provider: provider,
            decode: nil, shouldInterpolate: doubleResolution, intent: .defaultIntent)
    }

    private static func lemmings2(_ root: URL) throws -> CGImage? {
        let bank = try Lemmings2FrontEnd.Bank(data: Data(contentsOf: root.appendingPathComponent("FRONTEND/GFXIFFS/MENU.IFF")))
        let decoded = try Lemmings2Compression.decode(Data(contentsOf: root.appendingPathComponent("FRONTEND/SCREENS/MENU.DAT")))
        guard decoded.count == 64000, bank.palettes.count > 1 else { return nil }
        let left = 74, width = 215, height = 107
        let planeStride = 320 / 4, planeSize = decoded.count / 4
        var pixels: [UInt8] = []
        pixels.reserveCapacity(width * height)
        for y in 0..<height {
            let rowOffset = y * planeStride
            for x in left..<(left + width) {
                let planeOffset = (x % 4) * planeSize
                let columnOffset = x / 4
                pixels.append(decoded[planeOffset + rowOffset + columnOffset])
            }
        }
        let isolated = lemmings2LogoPixels(pixels, width: width, height: height)
        return bitmap(width: width, height: height, pixels: isolated, palette: lemmings2LogoPalette(bank.palettes[1]),
            transparent: 0, doubleResolution: true)
    }

    private static func lemmings2LogoPalette(_ source: [UInt8]) -> [UInt8] {
        var palette = source
        let red = source[(173 * 4)..<(173 * 4 + 3)]
        // The green channel records the white in both red ramps. Move it into transparency.
        for index in 128...135 {
            let offset = index * 4
            palette.replaceSubrange(offset..<(offset + 3), with: red)
            palette[offset + 3] = 255 - source[offset + 1]
        }
        for index in 144...150 {
            let offset = index * 4
            let white = Int(source[offset + 1])
            let alpha = 255 - white
            guard alpha > 0 else {
                palette[offset + 3] = 0
                continue
            }
            for channel in offset..<(offset + 3) {
                palette[channel] = UInt8(clamping: (Int(source[channel]) - white) * 255 / alpha)
            }
            palette[offset + 3] = UInt8(alpha)
        }
        return palette
    }

    private static func antialiased2x(_ rgba: [UInt8], width: Int, height: Int) -> [UInt8] {
        var result = [UInt8](repeating: 0, count: rgba.count * 4)
        let row = width * 4
        let outputRow = row * 2
        // Coverage of a quarter-pixel triangle, from the near corner to the far corner.
        let coverage = [211, 22, 22, 0]
        for y in 0..<height {
            for x in 0..<width {
                let centre = y * row + x * 4
                let origin = y * 2 * outputRow + x * 8
                let destinations = [origin, origin + 4, origin + outputRow, origin + outputRow + 4]
                let alpha = Int(rgba[centre + 3])
                if alpha > 0 {
                    let ink = rgba[centre..<(centre + 4)]
                    for destination in destinations {
                        result.replaceSubrange(destination..<(destination + 4), with: ink)
                    }
                }
                guard x > 0, x < width - 1, y > 0, y < height - 1 else { continue }

                let left = centre - 4, right = centre + 4, top = centre - row, bottom = centre + row
                let hasLeft = rgba[left + 3] > 0, hasTop = rgba[top + 3] > 0
                guard hasLeft != (rgba[right + 3] > 0), hasTop != (rgba[bottom + 3] > 0) else { continue }

                // The diagonal crosses the corner where both neighbours differ from the centre.
                let filled = alpha > 0
                let corner = (hasLeft == filled ? 1 : 0) + (hasTop == filled ? 2 : 0)
                if alpha > 0 {
                    for (index, destination) in destinations.enumerated() {
                        let kept = 255 - coverage[index ^ corner]
                        result[destination + 3] = UInt8((alpha * kept + 127) / 255)
                    }
                } else {
                    let side = hasLeft ? left : right, vertical = hasTop ? top : bottom
                    let sideAlpha = Int(rgba[side + 3]), verticalAlpha = Int(rgba[vertical + 3])
                    let total = sideAlpha + verticalAlpha
                    let ink = (0..<3).map { channel in
                        let ink = Int(rgba[side + channel]) * sideAlpha + Int(rgba[vertical + channel]) * verticalAlpha
                        return UInt8((ink + total / 2) / total)
                    }
                    for (index, destination) in destinations.enumerated() {
                        let covered = (total * coverage[index ^ corner] + 255) / 510
                        guard covered > 0 else { continue }
                        result.replaceSubrange(destination..<(destination + 3), with: ink)
                        result[destination + 3] = UInt8(covered)
                    }
                }
            }
        }
        return result
    }

    private static func drawTribesOutline(in rgba: inout [UInt8], pixels: [UInt8], palette: [UInt8],
                                         width: Int, height: Int) {
        // The subtitle sits below the green title and ends where the red brush stroke starts.
        let subtitleColumns = 1..<150
        let subtitleRows = 43..<104
        let shadows: Set<UInt8> = [2, 13, 22, 49]
        let neighbors = (-1...1).flatMap { y in (-1...1).map { y * width + $0 } }
        var subtitle = [Bool](repeating: false, count: pixels.count)
        var expanded = subtitle
        for y in subtitleRows {
            for x in subtitleColumns {
                let index = y * width + x
                let color = pixels[index]
                guard (152...159).contains(color) || (168...173).contains(color) || shadows.contains(color) else { continue }
                subtitle[index] = true
                for offset in neighbors { expanded[index + offset] = true }
            }
        }

        // Join short breaks in the subtitle before tracing its inner and outer contours.
        var stencil = [UInt8](repeating: 0, count: pixels.count * 4)
        for y in subtitleRows {
            for x in subtitleColumns {
                let index = y * width + x
                if subtitle[index] || (pixels[index] == 0 && neighbors.allSatisfy({ expanded[index + $0] })) {
                    stencil[index * 4 + 3] = 255
                }
            }
        }
        let mask = antialiased2x(stencil, width: width, height: height)
        let outputWidth = width * 2
        let nearOffsets = [-outputWidth, -1, 1, outputWidth]
        let farOffsets = [-outputWidth * 2, -outputWidth - 1, -outputWidth + 1, -2,
                          2, outputWidth - 1, outputWidth + 1, outputWidth * 2]
        let copper = 154 * 4
        let shadow = 13 * 4
        func opacity(_ index: Int) -> Int {
            guard index >= 0, index < mask.count / 4 else { return 0 }
            return Int(mask[index * 4 + 3])
        }

        for y in (subtitleRows.lowerBound * 2 - 1)...(subtitleRows.upperBound * 2) {
            for x in 1...(subtitleColumns.upperBound * 2) {
                let index = y * outputWidth + x
                let alpha = opacity(index)
                guard alpha > 0 else { continue }
                let near = nearOffsets.map { opacity(index + $0) }.min() ?? 0
                let far = farOffsets.map { opacity(index + $0) }.min() ?? 0
                let stroke = max(0, alpha - (near + min(near, far) + 1) / 2)
                let start = index * 4
                let originalAlpha = Int(rgba[start + 3])
                let source = y / 2 * width + x / 2
                let combinedAlpha = subtitle[source] ? alpha : max(originalAlpha, alpha)
                for channel in 0..<3 {
                    let base = originalAlpha == 0 ? palette[shadow + channel] : rgba[start + channel]
                    let ink = Int(base) * (combinedAlpha - stroke) + Int(palette[copper + channel]) * stroke
                    rgba[start + channel] = UInt8((ink + combinedAlpha / 2) / combinedAlpha)
                }
                rgba[start + 3] = UInt8(combinedAlpha)
            }
        }
    }

    private static func lemmings2LogoPixels(_ pixels: [UInt8], width: Int, height: Int) -> [UInt8] {
        // The jungle reuses some logo colours. Keep those pixels only where they join the logo.
        let logoColors: ClosedRange<UInt8> = 128...173
        let sharedColors: Set<UInt8> = [142, 143, 156, 157, 158, 159, 165, 167, 169]
        let copper: ClosedRange<UInt8> = 152...159
        let red: ClosedRange<UInt8> = 168...173
        let tribesInk = pixels.map { copper.contains($0) || red.contains($0) }
        let greenInk = pixels.map { (137...143).contains($0) || (160...167).contains($0) }
        var opaque = pixels.map { logoColors.contains($0) && !sharedColors.contains($0) }
        var pending = pixels.indices.filter { opaque[$0] }
        while let index = pending.popLast() {
            let x = index % width
            let neighbors = [index - width, index + width,
                             x > 0 ? index - 1 : index, x < width - 1 ? index + 1 : index]
            for neighbor in neighbors where pixels.indices.contains(neighbor) && !opaque[neighbor]
                && sharedColors.contains(pixels[neighbor]) {
                let continuesGreen = greenInk[index] && greenInk[neighbor]
                let continuesTribes = tribesInk[index] && tribesInk[neighbor]
                guard continuesGreen || continuesTribes else { continue }
                opaque[neighbor] = true
                pending.append(neighbor)
            }
        }

        // Close one-pixel breaks in the copper outlines. The letter openings and the brush strokes of the 2 stay open.
        let offsets = [-width - 1, -width, -width + 1, -1, 0, 1, width - 1, width, width + 1]
        var expanded = opaque
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) where opaque[y * width + x] {
                for offset in offsets { expanded[y * width + x + offset] = true }
            }
        }
        let copperShadow: UInt8 = 13
        let shadows: Set<UInt8> = [2, copperShadow, 22, 49]
        var result = pixels.indices.map { opaque[$0] ? pixels[$0] : 0 }
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let index = y * width + x
                guard !opaque[index], expanded[index] else { continue }
                let neighbors = offsets.map { index + $0 }
                guard neighbors.allSatisfy({ expanded[$0] }),
                      neighbors.contains(where: { opaque[$0] && copper.contains(pixels[$0]) }) else { continue }
                if shadows.contains(pixels[index]) {
                    result[index] = pixels[index]
                } else if neighbors.count(where: { opaque[$0] && tribesInk[$0] }) >= 5 {
                    result[index] = copperShadow
                }
            }
        }
        return result
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
