import Foundation

/// Matches original-style source pixels before substituting Macintosh artwork.
/// Physics always uses the unmodified NeoLemmix graphics and metadata.
public struct NeoLemmixMacArtwork: Sendable {
    private static let reconstructionRevision = 2

    private struct Candidate: Sendable {
        let width: Int
        let height: Int
        let originals: [[UInt8]]
        let mac: [[UInt8]]
    }
    private let terrain: [String: [Candidate]]
    private let objects: [String: [Candidate]]
    private let reconstructionCache: ReconstructionCache
    public let lemmings: ClassicMacArtwork?

    public init(resources: URL) {
        reconstructionCache = ReconstructionCache()
        lemmings = try? ClassicMacArtwork(directory: resources.appendingPathComponent("MacArtwork/lemmings"))
        var terrain: [String: [Candidate]] = [:], objects: [String: [Candidate]] = [:]
        for (family, port, styles) in [
            ("lemmings", "lemmings_dos_1991-07-30", ["orig_dirt", "orig_fire", "orig_marble", "orig_pillar", "orig_crystal"]),
            ("ohno", "oh_no_more_lemmings_dos-1991-11-14_2232", ["ohno_brick", "ohno_rock", "ohno_snow", "ohno_bubble"]),
            ("xmas", "xmas_dos_XmasLemmingsV1.9", ["xmas"])
        ] {
            guard let art = try? ClassicMacArtwork(directory: resources.appendingPathComponent("MacArtwork/" + family)) else { continue }
            let banks = family == "xmas" ? [0, 2] : Array(styles.indices)
            for bank in banks {
                let style = family == "xmas" ? "xmas" : styles[bank]
                guard let ground = try? ClassicGroundSet.load(style: bank, from: resources.appendingPathComponent("Ports/" + port)) else { continue }
                for tile in ground.terrain.values.sorted(by: { $0.id < $1.id }) {
                    guard let mac = art.frame(1500 + bank, tile.id) else { continue }
                    let original = Self.rgba(tile.indexedPixels, palette: ground.terrainPalette)
                    let high = Self.canvas(mac, width: tile.width, height: tile.height)
                    terrain[style, default: []] += Self.variants(width: tile.width, height: tile.height, originals: [original], mac: [high])
                }
                for object in ground.objects.values.sorted(by: { $0.id < $1.id }) {
                    guard let definitions = art.objects[bank], definitions.indices.contains(object.id) else { continue }
                    let sequence = definitions[object.id]
                    guard sequence.count >= object.frames.count else { continue }
                    let frames = (0..<object.frames.count).compactMap { art.frame(1600 + bank, sequence.base + $0) }
                    guard frames.count == object.frames.count else { continue }
                    objects[style, default: []] += Self.variants(width: object.width, height: object.height,
                        originals: object.frames.map { Self.rgba($0, palette: ground.objectPalette) },
                        mac: frames.map { Self.canvas($0, width: object.width, height: object.height) })
                }
                // NeoLemmix combines the Classic exit and its separate flame animation.
                if let base = ground.objects[0], base.frames.count == 1,
                   let definitions = art.objects[bank], !definitions.isEmpty,
                   let macBase = art.frame(1600 + bank, definitions[0].base) {
                    for decoration in ground.objects.values where decoration.triggerEffect == 0 && decoration.frames.count > 1 {
                        guard definitions.indices.contains(decoration.id) else { continue }
                        let sequence = definitions[decoration.id]
                        let macFrames = (0..<decoration.frames.count).compactMap { art.frame(1600 + bank, sequence.base + $0) }
                        guard sequence.count >= decoration.frames.count, macFrames.count == decoration.frames.count else { continue }
                        let w = max(base.width, decoration.width), h = base.height + decoration.height
                        var originals: [[UInt8]] = [], high: [[UInt8]] = []
                        for i in decoration.frames.indices {
                            var low = [UInt8](repeating: 0, count: w * h * 4)
                            var hd = [UInt8](repeating: 0, count: w * h * 16)
                            Self.blit(Self.rgba(base.frames[0], palette: ground.objectPalette), width: base.width, height: base.height,
                                x: (w - base.width) / 2, y: decoration.height, into: &low, canvasWidth: w, canvasHeight: h)
                            Self.blit(Self.rgba(decoration.frames[i], palette: ground.objectPalette), width: decoration.width, height: decoration.height,
                                x: (w - decoration.width) / 2, y: 0, into: &low, canvasWidth: w, canvasHeight: h)
                            Self.blit([UInt8](macBase.rgba), width: macBase.width, height: macBase.height,
                                x: w - base.width + macBase.x, y: decoration.height * 2 + macBase.y, into: &hd, canvasWidth: w * 2, canvasHeight: h * 2)
                            let frame = macFrames[i]
                            Self.blit([UInt8](frame.rgba), width: frame.width, height: frame.height,
                                x: w - decoration.width + frame.x, y: frame.y, into: &hd, canvasWidth: w * 2, canvasHeight: h * 2)
                            originals.append(low); high.append(hd)
                        }
                        objects[style, default: []] += Self.variants(width: w, height: h, originals: originals, mac: high)
                    }
                }
            }
        }
        // Aliases remain subject to the same source-pixel check as stock pieces.
        for alias in ["orig_dirt_md", "orig_sega"] {
            terrain[alias] = terrain["orig_dirt"]
            objects[alias] = objects["orig_dirt"]
        }
        self.terrain = terrain; self.objects = objects
    }

    /**
     * Recreates a display asset at Macintosh scale when no verified Mac piece matches.
     * Each source cell keeps its original alpha and logical position.
     */
    public func recreated(asset: NxlvResolvedStyleAsset, width: Int, height: Int, rgba: [UInt8]) -> [UInt8] {
        guard width > 0, height > 0, width <= 4096, height <= 4096,
              width * height <= 4 * 1024 * 1024, rgba.count == width * height * 4 else { return [] }
        let category = Self.category(for: asset)
        let reference = asset.resolvedReference
        let reduceBeachFlecks = category == .organic && reference.kind == .terrain
            && reference.style.lowercased() == "l2_beach"
            && (reference.piece ?? "").lowercased().hasPrefix("sand_")
        let key = ReconstructionCache.Key(
            revision: SequelMacArtwork.revision * 100 + Self.reconstructionRevision,
            category: category,
            reduceBeachFlecks: reduceBeachFlecks,
            width: width,
            height: height,
            sourceHash: Self.fingerprint(rgba)
        )
        return reconstructionCache.value(for: key, source: rgba) {
            var opaque = rgba
            for i in stride(from: 0, to: opaque.count, by: 4) {
                opaque[i + 3] = rgba[i + 3] == 0 ? 0 : 255
            }
            let high: [UInt8]
            if let frame = try? SequelMacFrame(width: width, height: height, rgba: opaque),
               let reconstructed = try? SequelMacArtwork.reconstruct(frame, category: category) {
                high = reconstructed.rgba
            } else {
                high = Self.doubled(rgba, width: width, height: height)
            }
            var result = high
            if reduceBeachFlecks {
                Self.removeIsolatedBeachFlecks(from: &result, source: rgba, width: width, height: height)
            }
            for y in 0..<height { for x in 0..<width {
                let source = (y * width + x) * 4
                let alpha = rgba[source + 3]
                for dy in 0..<2 { for dx in 0..<2 {
                    let target = ((y * 2 + dy) * width * 2 + x * 2 + dx) * 4
                    result[target + 3] = alpha
                    if alpha == 0 { result[target..<target + 3] = [0, 0, 0] }
                } }
            } }
            return result
        }
    }

    /**
     * Removes lone 2× colour marks inside Beach sand without changing source pixels or edges.
     */
    private static func removeIsolatedBeachFlecks(from high: inout [UInt8], source: [UInt8],
                                                   width: Int, height: Int) {
        guard width > 2, height > 2 else { return }
        let original = high
        let highWidth = width * 2
        for y in 1..<(height - 1) { for x in 1..<(width - 1) {
            let sourceOffset = (y * width + x) * 4
            guard source[sourceOffset + 3] == 255,
                  source[sourceOffset - 4 + 3] == 255,
                  source[sourceOffset + 4 + 3] == 255,
                  source[sourceOffset - width * 4 + 3] == 255,
                  source[sourceOffset + width * 4 + 3] == 255 else { continue }
            var changed: (offset: Int, x: Int, y: Int)?
            var changedCount = 0
            for dy in 0..<2 { for dx in 0..<2 {
                let px = x * 2 + dx, py = y * 2 + dy
                let offset = (py * highWidth + px) * 4
                if original[offset] != source[sourceOffset]
                    || original[offset + 1] != source[sourceOffset + 1]
                    || original[offset + 2] != source[sourceOffset + 2] {
                    changedCount += 1
                    changed = (offset, px, py)
                }
            } }
            guard changedCount == 1, let mark = changed else { continue }
            var hasNeighbour = false
            for dy in -1...1 { for dx in -1...1 where dx != 0 || dy != 0 {
                let neighbour = ((mark.y + dy) * highWidth + mark.x + dx) * 4
                if original[neighbour + 3] > 0
                    && original[neighbour] == original[mark.offset]
                    && original[neighbour + 1] == original[mark.offset + 1]
                    && original[neighbour + 2] == original[mark.offset + 2] {
                    hasNeighbour = true
                }
            } }
            guard !hasNeighbour else { continue }
            high[mark.offset..<mark.offset + 3] = source[sourceOffset..<sourceOffset + 3]
        } }
    }

    private static func category(for asset: NxlvResolvedStyleAsset) -> SequelMacCategory {
        let reference = asset.resolvedReference
        let style = reference.style.lowercased()
        let piece = (reference.piece ?? "").lowercased()
        let name = style + " " + piece
        if ["water", "liquid", "lava", "acid", "pool", "fall"].contains(where: name.contains) {
            return .liquid
        }
        if ["plant", "tree", "flower", "weed", "lizard", "frog", "dragon", "bee", "spider",
            "cannibal", "cloud", "smoke", "steam", "moon", "face", "eyes", "clam"].contains(where: piece.contains) {
            return .organic
        }
        if ["snowman", "flag"].contains(where: piece.contains) { return .architectural }
        if reference.kind == .object { return .mechanical }
        if asset.terrainMetadata?.isSteel == true { return .mechanical }
        if ["snow", "ice", "brick", "steel", "metal", "marble", "pillar", "tile", "wall", "glass", "crystal", "beam", "column", "sign", "bridge", "egypt", "space", "biolab", "shadow", "circus", "sports", "sega"].contains(where: name.contains) {
            return .architectural
        }
        if reference.kind == .background { return .architectural }
        return .organic
    }

    private static func fingerprint(_ bytes: [UInt8]) -> UInt64 {
        var value: UInt64 = 0xcbf29ce484222325
        for byte in bytes {
            value = (value ^ UInt64(byte)) &* 0x100000001b3
        }
        return value
    }

    /// Returns a 2× sheet only when every source frame has a verified equivalent.
    public func replacement(asset: NxlvResolvedStyleAsset, url: URL, width: Int, height: Int, rgba: [UInt8]) -> [UInt8]? {
        let reference = asset.resolvedReference
        let candidates: [Candidate]
        let count: Int
        switch reference.kind {
        case .terrain:
            candidates = terrain[reference.style.lowercased()] ?? []; count = 1
        case .object:
            guard url.deletingPathExtension().lastPathComponent == reference.piece,
                  let animation = asset.objectMetadata?.animations.first(where: \.isPrimary),
                  !animation.usesHorizontalStrip else { return nil }
            candidates = objects[reference.style.lowercased()] ?? []; count = animation.frames ?? 1
        default: return nil
        }
        guard count > 0, height.isMultiple(of: count), rgba.count == width * height * 4 else { return nil }
        let frameHeight = height / count, bytes = width * frameHeight * 4
        for candidate in candidates where candidate.width == width && candidate.height == frameHeight {
            var matched: [[UInt8]] = []
            for frame in 0..<count {
                let offset = frame * bytes
                // VGA and NeoLemmix expand the original palette to 8-bit RGB differently.
                guard let index = candidate.originals.firstIndex(where: { original in
                    for p in stride(from: 0, to: bytes, by: 4) {
                        if original[p + 3] != rgba[offset + p + 3] { return false }
                        if original[p + 3] == 0 { continue }
                        // CE uses dark yellow for the original shared yellow flame colour.
                        let yellow = original[p] == 243 && original[p + 1] == 243 && original[p + 2] == 0
                            && rgba[offset + p] == 176 && rgba[offset + p + 1] == 176 && rgba[offset + p + 2] == 0
                        if !yellow {
                            for c in 0..<3 where abs(Int(original[p + c]) - Int(rgba[offset + p + c])) > 12 { return false }
                        }
                    }
                    return true
                }) else { break }
                matched.append(candidate.mac[index])
            }
            if matched.count == count {
                var result = matched.flatMap { $0 }
                if reference.kind == .terrain {
                    // Keep every solid logical cell visible even when the Mac silhouette differs.
                    for y in 0..<height { for x in 0..<width {
                        let original = (y * width + x) * 4
                        guard rgba[original + 3] > 0 else { continue }
                        let offsets = [0, 1, width * 2, width * 2 + 1].map { ((y * 2) * width * 2 + x * 2 + $0) * 4 }
                        if offsets.allSatisfy({ result[$0 + 3] == 0 }) {
                            for offset in offsets { result[offset..<offset + 4] = rgba[original..<original + 4] }
                        }
                    } }
                }
                return result
            }
        }
        return nil
    }

    private static func rgba(_ data: Data, palette: [ClassicRGBColor]) -> [UInt8] {
        data.flatMap { value -> [UInt8] in
            guard value & 0x80 == 0 else { return [0, 0, 0, 0] }
            let color = palette[Int(value & UInt8(palette.count - 1))]
            return [color.red, color.green, color.blue, 255]
        }
    }

    private static func canvas(_ frame: ClassicMacArtwork.Frame, width: Int, height: Int) -> [UInt8] {
        var output = [UInt8](repeating: 0, count: width * height * 16)
        blit([UInt8](frame.rgba), width: frame.width, height: frame.height, x: frame.x, y: frame.y,
            into: &output, canvasWidth: width * 2, canvasHeight: height * 2)
        return output
    }

    private static func variants(width: Int, height: Int, originals: [[UInt8]], mac: [[UInt8]]) -> [Candidate] {
        var left = width, top = height, right = -1, bottom = -1
        for frame in originals { for y in 0..<height { for x in 0..<width where frame[(y * width + x) * 4 + 3] > 0 {
            left = min(left, x); right = max(right, x); top = min(top, y); bottom = max(bottom, y)
        } } }
        guard right >= left, bottom >= top else { return [] }
        let rects = [[0, 0, width, height], [left, top, right - left + 1, bottom - top + 1]]
        return rects.map { rect in
            func crop(_ source: [UInt8], scale: Int) -> [UInt8] {
                var result: [UInt8] = []
                for y in rect[1] * scale..<(rect[1] + rect[3]) * scale {
                    let start = (y * width * scale + rect[0] * scale) * 4
                    result.append(contentsOf: source[start..<start + rect[2] * scale * 4])
                }
                return result
            }
            return Candidate(width: rect[2], height: rect[3], originals: originals.map { crop($0, scale: 1) }, mac: mac.map { crop($0, scale: 2) })
        }
    }

    private static func blit(_ source: [UInt8], width: Int, height: Int, x: Int, y: Int,
                            into target: inout [UInt8], canvasWidth: Int, canvasHeight: Int) {
        for sy in 0..<height where (0..<canvasHeight).contains(y + sy) {
            for sx in 0..<width where (0..<canvasWidth).contains(x + sx) {
                let s = (sy * width + sx) * 4
                guard source[s + 3] > 0 else { continue }
                let d = ((y + sy) * canvasWidth + x + sx) * 4
                target[d..<d + 4] = source[s..<s + 4]
            }
        }
    }
}

extension NeoLemmixMacArtwork {
    public static func doubled(_ pixels: [UInt8], width: Int, height: Int) -> [UInt8] {
        guard width > 0, height > 0, pixels.count == width * height * 4 else { return [] }
        var result = [UInt8](repeating: 0, count: pixels.count * 4)
        for y in 0..<height { for x in 0..<width {
            let s = (y * width + x) * 4
            for dy in 0..<2 { for dx in 0..<2 {
                let d = ((y * 2 + dy) * width * 2 + x * 2 + dx) * 4
                result[d..<d + 4] = pixels[s..<s + 4]
            } }
        } }
        return result
    }
}

private final class ReconstructionCache: @unchecked Sendable {
    struct Key: Hashable {
        let revision: Int
        let category: SequelMacCategory
        let reduceBeachFlecks: Bool
        let width: Int
        let height: Int
        let sourceHash: UInt64
    }

    private struct Entry {
        let source: [UInt8]
        let result: [UInt8]

        var byteCount: Int { source.count + result.count }
    }

    private let lock = NSLock()
    private let byteLimit = 64 * 1024 * 1024
    private var entries: [Key: Entry] = [:]
    private var insertionOrder: [Key] = []
    private var storedBytes = 0

    func value(for key: Key, source: [UInt8], make: () -> [UInt8]) -> [UInt8] {
        lock.lock()
        if let entry = entries[key], entry.source == source {
            lock.unlock()
            return entry.result
        }
        lock.unlock()

        let result = make()
        let newEntry = Entry(source: source, result: result)
        guard newEntry.byteCount <= byteLimit else { return result }
        lock.lock()
        defer { lock.unlock() }
        if let entry = entries[key], entry.source == source { return entry.result }
        if let previous = entries.removeValue(forKey: key) {
            storedBytes -= previous.byteCount
            insertionOrder.removeAll { $0 == key }
        }
        while storedBytes + newEntry.byteCount > byteLimit, !insertionOrder.isEmpty {
            let oldest = insertionOrder.removeFirst()
            if let evicted = entries.removeValue(forKey: oldest) {
                storedBytes -= evicted.byteCount
            }
        }
        entries[key] = newEntry
        insertionOrder.append(key)
        storedBytes += newEntry.byteCount
        return result
    }
}
