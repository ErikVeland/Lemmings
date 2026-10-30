import Foundation
import NxlvKit

/// Retains one immutable terrain frame. Actor compositing gets its own copy on write.
final class MobileIndexedTerrainCache: @unchecked Sendable {
    private let lock = NSLock()
    private let lease = RuntimePixelCacheLease()
    private var pixels: [UInt8] = []
    private var palette: [UInt8] = []
    private var rgba: [UInt8] = []
    private var builds = 0

    var buildCount: Int { lock.withLock { builds } }

    func frame(pixels: [UInt8], palette: [UInt8]) -> [UInt8] {
        lock.withLock {
            let retains = lease.reserve(bytes: pixels.count * 4)
            // Compare content as well as revisions: rewind can revisit a different terrain branch.
            if self.pixels != pixels || self.palette != palette || rgba.isEmpty {
                builds += 1
                if self.palette == palette, self.pixels.count == pixels.count, rgba.count == pixels.count * 4 {
                    // Actor composition uses a cropped copy. Update the retained
                    // terrain in place and convert only pixels changed by play
                    // or rewind; palette changes still rebuild every colour.
                    for index in pixels.indices where self.pixels[index] != pixels[index] {
                        let source = Int(pixels[index]) * 4, target = index * 4
                        rgba[target] = palette[source]
                        rgba[target + 1] = palette[source + 1]
                        rgba[target + 2] = palette[source + 2]
                    }
                } else { rgba = Self.expand(pixels, palette: palette) }
                if !retains {
                    let result = rgba
                    self.pixels = []; self.palette = []; rgba = []
                    return result
                }
                self.pixels = pixels; self.palette = palette
            } else if !retains {
                let result = rgba
                self.pixels = []; self.palette = []; rgba = []
                return result
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
final class MobileEditedTerrain: @unchecked Sendable {
    private let lock = NSLock()
    private let lease = RuntimePixelCacheLease()
    private var lastEdits: [Int: Bool] = [:]
    private var cached: [UInt8]?
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
        lock.lock()
        defer { lock.unlock() }
        let retains = lease.reserve(bytes: base.count)
        if let cached, edits == lastEdits, retains { return cached }
        var rgba = cached ?? base
        // Apply only changed pixels, including edits removed by rewind or a new branch.
        for index in lastEdits.keys where edits[index] == nil && background.indices.contains(index) {
            let target = index * 4
            rgba[target] = base[target]; rgba[target + 1] = base[target + 1]
            rgba[target + 2] = base[target + 2]; rgba[target + 3] = base[target + 3]
        }
        for (index, filled) in edits where background.indices.contains(index) && (cached == nil || lastEdits[index] != filled) {
            let colour = filled ? bricks[(index / width % 8) * 8 + index % width % 8] : background[index]
            let source = Int(colour) * 4, target = index * 4
            rgba[target] = palette[source]
            rgba[target + 1] = palette[source + 1]
            rgba[target + 2] = palette[source + 2]
            rgba[target + 3] = 255
        }
        lastEdits = edits
        cached = retains ? rgba : nil
        return rgba
    }
}
