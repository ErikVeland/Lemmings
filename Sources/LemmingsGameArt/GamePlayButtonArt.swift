import CoreGraphics
import Foundation
import NxlvKit

/// Distinct gameplay faces, based on the Macintosh panel rather than the quiet menu texture.
public enum GamePlayButtonArt {
    public enum Face: Hashable, Sendable {
        case skill(Int), rateDown, rateUp, rate, pause, endRun, speed
        case rewind, stepBackward, stepForward, hints

        var seed: UInt64 {
            switch self {
            case .rateDown: 1
            case .rateUp: 2
            case .skill(let index): UInt64(max(0, index)) &+ 0x1_0000
            case .pause: 128
            case .endRun: 129
            case .rate: 130
            case .speed: 131
            case .rewind: 132
            case .stepBackward: 133
            case .stepForward: 134
            case .hints: 135
            }
        }
        var panelCell: Int? {
            switch self {
            case .rateDown: 0
            case .rateUp: 1
            case .skill(let index): (0..<8).contains(index) ? index + 2 : nil
            case .pause: 10
            case .endRun: 11
            default: nil
            }
        }
    }

    private struct Frame: Decodable {
        let width: Int, height: Int
        let file: String
    }
    private struct Manifest: Decodable {
        let names: [String: String]
        let banks: [String: [Frame?]]
    }
    private struct Pixels: Sendable {
        let width: Int, height: Int
        let rgba: [UInt8]
    }
    private struct Sources: Sendable {
        let panel: Pixels
        let patches: [[UInt8]]
    }
    private struct Raster: @unchecked Sendable { let image: CGImage }
    private static let cache = GameAssetCache<Raster>(capacity: 96)
    private static let patchSize = 20, strideSize = 16
    // These are the six rock colours in the original Macintosh panel, darkest first.
    private static let palette: [UInt32] = [0x220000, 0x442222, 0x662222, 0x884444, 0xaa4444, 0xcc6666]

    private static let sources: Sources? = {
        guard let root = Bundle.main.resourceURL?.appendingPathComponent("MacArtwork/lemmings"),
              let data = try? Data(contentsOf: root.appendingPathComponent("manifest.json")),
              let manifest = try? JSONDecoder().decode(Manifest.self, from: data),
              let panelBank = manifest.names.first(where: { $0.value == "Charset2" })?.key,
              let terrainBank = manifest.names.first(where: { $0.value == "Grounds2" })?.key else { return nil }
        func load(_ bank: String, _ index: Int) -> Pixels? {
            guard let frames = manifest.banks[bank], frames.indices.contains(index), let frame = frames[index],
                  frame.width > 0, frame.height > 0, frame.width <= 4096, frame.height <= 4096,
                  !frame.file.contains("/"), !frame.file.contains(".."),
                  let data = try? Data(contentsOf: root.appendingPathComponent(frame.file)),
                  data.count == frame.width * frame.height * 4 else { return nil }
            return Pixels(width: frame.width, height: frame.height, rgba: Array(data))
        }
        guard let panel = load(panelBank, 107), panel.width == 640, panel.height == 48 else { return nil }
        var patches: [[UInt8]] = []
        // Only opaque rock interiors qualify. Lava, shaped outlines and empty pixels are excluded.
        let tones: [UInt32: UInt8] = [0x442222: 2, 0x554444: 3, 0x665555: 4, 0x887777: 5]
        for index in [16, 17, 18] {
            guard let terrain = load(terrainBank, index) else { continue }
            var ranks = [UInt8](repeating: 255, count: terrain.width * terrain.height)
            for p in ranks.indices where terrain.rgba[p * 4 + 3] == 255 {
                ranks[p] = tones[rgb(terrain.rgba, p * 4)] ?? 255
            }
            for y in stride(from: 0, through: terrain.height - patchSize, by: 4) {
                for x in stride(from: 0, through: terrain.width - patchSize, by: 4) {
                    var patch: [UInt8] = []
                    for row in 0..<patchSize {
                        patch += ranks[((y + row) * terrain.width + x)..<((y + row) * terrain.width + x + patchSize)]
                    }
                    if !patch.contains(255) { patches.append(patch) }
                }
            }
        }
        return patches.isEmpty ? nil : Sources(panel: panel, patches: patches)
    }()

    /// A persistent face at native grain density. Larger faces extend the synthesis, never tile it.
    public static func image(for face: Face, width: Int, height: Int) -> CGImage? {
        guard width > 0, height > 0, width <= 2048, height <= 2048, let sources else { return nil }
        let key = "\(face.seed):\(width):\(height)"
        if let hit = cache.value(for: key) { return hit.image }
        // Padding makes synthesis independent of the visible crop when a button is resized.
        let columns = (width + strideSize - 1) / strideSize + 1
        let rows = (height + strideSize - 1) / strideSize + 1
        let workWidth = columns * strideSize + patchSize - strideSize
        let workHeight = rows * strideSize + patchSize - strideSize
        var field = [UInt8](repeating: 255, count: workWidth * workHeight)
        var choices = [Int](repeating: -1, count: columns * rows)
        for row in 0..<rows {
            for column in 0..<columns {
                let x = column * strideSize, y = row * strideSize
                let seed = mix(face.seed &* 0x9e3779b97f4a7c15 ^ UInt64(column) &* 0xbf58476d1ce4e5b9
                    ^ UInt64(row) &* 0x94d049bb133111eb)
                var best = Int(seed % UInt64(sources.patches.count)), bestCost = Int.max
                for trial in 0..<12 {
                    let candidate = Int(mix(seed &+ UInt64(trial)) % UInt64(sources.patches.count))
                    if column > 0 && choices[row * columns + column - 1] == candidate { continue }
                    if row > 0 && choices[(row - 1) * columns + column] == candidate { continue }
                    let patch = sources.patches[candidate]
                    var cost = 0
                    for py in 0..<patchSize {
                        // Top matching uses this patch's owned columns, not the next patch's
                        // overlap. Otherwise a wider row can change already visible pixels.
                        for px in 0..<patchSize where (py < 4 && px < strideSize) || px < 4 {
                            let old = field[(y + py) * workWidth + x + px]
                            if old != 255 { cost += abs(Int(old) - Int(patch[py * patchSize + px])) }
                        }
                    }
                    if cost < bestCost { best = candidate; bestCost = cost }
                }
                choices[row * columns + column] = best
                let patch = sources.patches[best]
                for py in 0..<patchSize {
                    for px in 0..<patchSize { field[(y + py) * workWidth + x + px] = patch[py * patchSize + px] }
                }
            }
        }
        var rgba = [UInt8](repeating: 255, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let colour = originalRock(in: sources.panel, face: face, x: x, y: y)
                    ?? palette[Int(field[y * workWidth + x])]
                let p = (y * width + x) * 4
                rgba[p] = UInt8((colour >> 16) & 255)
                rgba[p + 1] = UInt8((colour >> 8) & 255)
                rgba[p + 2] = UInt8(colour & 255)
            }
        }
        guard let provider = CGDataProvider(data: Data(rgba) as CFData),
              let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue), provider: provider,
                decode: nil, shouldInterpolate: false, intent: .defaultIntent) else { return nil }
        cache.insert(Raster(image: image), for: key)
        return image
    }

    /// Paint inside the existing socket before its selection marker and glyphs.
    public static func draw(in context: CGContext, frame: CGRect, selected: Bool,
                            pixel: CGFloat, face: Face) {
        GameStoneArt.drawSocket(in: context, frame: frame, selected: selected, pixel: pixel)
        drawFace(in: context, frame: frame, selected: selected, pixel: pixel, face: face)
        GameStoneArt.drawAccent(in: context, frame: frame, selected: selected, pixel: pixel)
    }

    /// Paint inside the existing socket before its selection marker and glyphs.
    public static func drawFace(in context: CGContext, frame: CGRect, selected: Bool,
                                pixel: CGFloat, face: Face) {
        let well = GameStoneArt.well(frame, pixel: pixel)
        guard well.width.isFinite, well.height.isFinite, well.width > 0, well.height > 0,
              well.width <= 2048, well.height <= 2048,
              let image = image(for: face, width: Int(ceil(well.width)), height: Int(ceil(well.height))) else { return }
        context.saveGState()
        defer { context.restoreGState() }
        context.clip(to: well)
        context.setShouldAntialias(false)
        context.interpolationQuality = .none
        GameStoneArt.drawImage(image, in: CGRect(x: well.minX, y: well.minY,
            width: CGFloat(image.width), height: CGFloat(image.height)), context: context)
        // Keep the original warm rock legible behind bitmap counts and sprites.
        context.setFillColor(CGColor(gray: 0, alpha: 0.18)); context.fill(well)
        if selected {
            context.setFillColor(CGColor(srgbRed: 0.18, green: 0.32, blue: 0.06, alpha: 0.22))
            context.fill(well)
        }
    }

    private static func originalRock(in panel: Pixels, face: Face, x: Int, y: Int) -> UInt32? {
        guard let cell = face.panelCell, x < 28, y < 44 else { return nil }
        let sx = x + 2, sy = y + 2
        // The counter socket and its edge are baked into the original image.
        if cell < 10 && sx >= 3 && sx < 30 && sy < 21 { return nil }
        let p = (sy * panel.width + 32 + cell * 32 + sx) * 4
        let colour = rgb(panel.rgba, p)
        return panel.rgba[p + 3] == 255 && palette.contains(colour) ? colour : nil
    }

    private static func rgb(_ bytes: [UInt8], _ offset: Int) -> UInt32 {
        UInt32(bytes[offset]) << 16 | UInt32(bytes[offset + 1]) << 8 | UInt32(bytes[offset + 2])
    }
    private static func mix(_ value: UInt64) -> UInt64 {
        var n = value
        n = (n ^ (n >> 30)) &* 0xbf58476d1ce4e5b9
        n = (n ^ (n >> 27)) &* 0x94d049bb133111eb
        return n ^ (n >> 31)
    }
}
