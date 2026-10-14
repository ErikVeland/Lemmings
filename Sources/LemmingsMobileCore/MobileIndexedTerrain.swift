import Foundation

/// Retains one immutable terrain frame. Actor compositing gets its own copy on write.
final class MobileIndexedTerrainCache: @unchecked Sendable {
    private let lock = NSLock()
    private var pixels: [UInt8] = []
    private var palette: [UInt8] = []
    private var rgba: [UInt8] = []
    private var builds = 0

    var buildCount: Int { lock.withLock { builds } }

    func frame(pixels: [UInt8], palette: [UInt8]) -> [UInt8] {
        lock.withLock {
            // Compare content as well as revisions: rewind can revisit a different terrain branch.
            if self.pixels != pixels || self.palette != palette || rgba.isEmpty {
                self.pixels = pixels
                self.palette = palette
                rgba = Self.expand(pixels, palette: palette)
                builds += 1
            }
            return rgba
        }
    }

    static func expand(_ pixels: [UInt8], palette: [UInt8]) -> [UInt8] {
        var result = [UInt8](repeating: 255, count: pixels.count * 4)
        for (index, colour) in pixels.enumerated() {
            let source = Int(colour) * 4, target = index * 4
            result[target] = palette[source]
            result[target + 1] = palette[source + 1]
            result[target + 2] = palette[source + 2]
        }
        return result
    }
}

/// Chronicles changes a sparse set of pixels over an immutable authored scene.
struct MobileEditedTerrain: Sendable {
    private let base: [UInt8]
    private let background: [UInt8]
    private let palette: [UInt8]
    private let bricks: [UInt8]
    private let width: Int

    init(pixels: [UInt8], background: [UInt8], palette: [UInt8], bricks: [UInt8], width: Int) {
        self.base = MobileIndexedTerrainCache.expand(pixels, palette: palette)
        self.background = background
        self.palette = palette
        self.bricks = bricks
        self.width = width
    }

    func frame(edits: [Int: Bool]) -> [UInt8] {
        var rgba = base
        for (index, filled) in edits where background.indices.contains(index) {
            let colour = filled ? bricks[(index / width % 8) * 8 + index % width % 8] : background[index]
            let source = Int(colour) * 4, target = index * 4
            rgba[target] = palette[source]
            rgba[target + 1] = palette[source + 1]
            rgba[target + 2] = palette[source + 2]
            rgba[target + 3] = 255
        }
        return rgba
    }
}
