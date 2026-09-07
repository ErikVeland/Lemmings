import Foundation

/// Original Macintosh pixels decoded at build time, with their authored origins.
/// Coordinates here are twice the classic simulation's pixel coordinates.
public struct ClassicMacArtwork: Sendable {
    public struct Frame: Sendable {
        public let x: Int
        public let y: Int
        public let width: Int
        public let height: Int
        public let rgba: Data
    }
    public struct ObjectSequence: Codable, Sendable {
        public let first: Int
        public let count: Int
        public let base: Int
    }
    private struct FrameRecord: Decodable {
        let x: Int, y: Int, width: Int, height: Int
        let file: String
    }
    private struct Manifest: Decodable {
        let version: Int
        let banks: [String: [FrameRecord?]]
        let objects: [String: [ObjectSequence]]
        let names: [String: String]?
    }
    public let version: Int
    public let banks: [Int: [Frame?]]
    public let objects: [Int: [ObjectSequence]]
    /// The name the release gives each bank, such as "Charset2" or "Logo2".
    /// The front end asks for banks by name, because the numbers move between
    /// releases.
    public let names: [Int: String]

    public init(directory: URL) throws {
        let manifest = try JSONDecoder().decode(Manifest.self,
            from: Data(contentsOf: directory.appendingPathComponent("manifest.json")))
        var banks: [Int: [Frame?]] = [:]
        for (key, records) in manifest.banks {
            guard let id = Int(key) else { throw SequelDataError.invalid("Invalid Mac graphics bank.") }
            banks[id] = try records.map { record in
                guard let record else { return nil }
                guard record.width > 0, record.height > 0, record.width <= 4096, record.height <= 4096,
                      !record.file.contains("/"), !record.file.contains("..") else {
                    throw SequelDataError.invalid("Invalid Mac graphics frame.")
                }
                let data = try Data(contentsOf: directory.appendingPathComponent(record.file))
                guard data.count == record.width * record.height * 4 else {
                    throw SequelDataError.invalid("Truncated Mac graphics frame.")
                }
                return Frame(x: record.x, y: record.y, width: record.width,
                    height: record.height, rgba: data)
            }
        }
        self.version = manifest.version
        self.banks = banks
        self.objects = Dictionary(uniqueKeysWithValues: manifest.objects.compactMap { key, value in
            Int(key).map { ($0, value) }
        })
        self.names = Dictionary(uniqueKeysWithValues: (manifest.names ?? [:]).compactMap { key, value in
            Int(key).map { ($0, value) }
        })
    }

    /// The identifier of the bank with this name, if the release carries it.
    public func bank(named name: String) -> Int? {
        names.first { $0.value == name }?.key
    }

    public func frame(_ bank: Int, _ index: Int = 0) -> Frame? {
        guard let frames = banks[bank], frames.indices.contains(index) else { return nil }
        return frames[index]
    }

    /// SHPD includes masks and construction pixels between animation runs.
    /// Explicit ranges avoid treating those images as animation frames.
    public func lemming(pose: ClassicLemmingPose, left: Bool, tick: Int) -> Frame? {
        let start: Int, count: Int
        switch pose {
        case .walking: start = left ? 9 : 0; count = 8
        case .jumping: start = left ? 17 : 8; count = 1
        case .falling: start = left ? 22 : 18; count = 4
        case .digging: start = 26; count = 16
        case .climbing: start = left ? 51 : 43; count = 8
        case .postClimb: start = left ? 67 : 59; count = 8
        case .explosion: start = 75; count = 1
        case .building: start = left ? 94 : 77; count = 16
        case .splatting: start = 111; count = 16
        case .blocking: start = 127; count = 16
        case .bashing: start = left ? 179 : 143; count = 32
        case .umbrellaOpening: start = left ? 223 : 215; count = 4
        case .floating: start = left ? 227 : 219; count = 4
        case .mining: start = left ? 257 : 231; count = 24
        case .drowning: start = 283; count = 16
        case .exiting: start = 299; count = 8
        case .frying: start = 307; count = 14
        case .shrugging: start = left ? 329 : 321; count = 8
        case .ohNo: start = 337; count = 16
        }
        return frame(1400, start + abs(tick % count))
    }
}

/// Macintosh terrain and object artwork over the unchanged classic simulation.
public struct ClassicMacScene: Sendable {
    public let width: Int
    public let height: Int
    public let terrainRGBA: Data
    private let artwork: ClassicMacArtwork
    private let level: ClassicRenderedLevel
    private let style: Int

    public init(level source: ClassicLevel, rendered: ClassicRenderedLevel, artwork: ClassicMacArtwork, groundSet: ClassicGroundSet? = nil) throws {
        width = rendered.width * 2; height = rendered.height * 2
        level = rendered; self.artwork = artwork; style = source.groundStyle
        guard artwork.banks[1500 + style] != nil else {
            throw SequelDataError.invalid("No Mac terrain for this style.")
        }
        for object in rendered.objects {
            guard let definitions = artwork.objects[style], definitions.indices.contains(object.placement.id) else {
                throw SequelDataError.invalid("Missing Mac object definition.")
            }
            let seq = definitions[object.placement.id]
            guard seq.count > 0, (0..<seq.count).allSatisfy({ artwork.frame(1600 + source.groundStyle, seq.base + $0) != nil }) else {
                throw SequelDataError.invalid("Missing Mac object animation.")
            }
        }
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        if source.specialStyle > 0 {
            guard let frame = artwork.frame(1699 + source.specialStyle) else {
                throw SequelDataError.invalid("No Mac artwork for this special level.")
            }
            Self.blit(frame, into: &pixels, width: width, height: height,
                x: 304 * 2, y: 0)
        }
        for tile in source.terrain where source.specialStyle == 0 {
            let frame: ClassicMacArtwork.Frame
            if let mac = artwork.frame(1500 + style, tile.id) { frame = mac }
            else if let groundSet, let dos = groundSet.terrain[tile.id] {
                // Some Mac banks leave a DOS piece empty (for example fire 44).
                // Keep that individual piece visible rather than replacing the whole scene.
                var fallback = [UInt8](repeating: 0, count: dos.width * dos.height * 16)
                let indexed = [UInt8](dos.indexedPixels)
                for py in 0..<dos.height { for px in 0..<dos.width {
                    let value = indexed[py * dos.width + px]
                    guard value & 0x80 == 0 else { continue }
                    let color = groundSet.objectPalette[Int(value & 15)]
                    for dy in 0..<2 { for dx in 0..<2 {
                        let offset = ((py * 2 + dy) * dos.width * 2 + px * 2 + dx) * 4
                        fallback[offset] = color.red; fallback[offset+1] = color.green
                        fallback[offset+2] = color.blue; fallback[offset+3] = 255
                    } }
                } }
                frame = ClassicMacArtwork.Frame(x: 0, y: 0, width: dos.width * 2, height: dos.height * 2, rgba: Data(fallback))
            } else { throw SequelDataError.invalid("Missing Mac terrain piece \(tile.id).") }
            Self.blit(frame, into: &pixels, width: width, height: height,
                x: tile.x * 2 + frame.x,
                y: tile.y * 2 + ((artwork.version == 1 && tile.draw.isUpsideDown) ? 0 : frame.y),
                flipped: tile.draw.isUpsideDown, erase: tile.draw.isErase, behind: tile.draw.noOverwrite)
        }
        terrainRGBA = Data(pixels)
    }

    public func rgba(simulation: ClassicDOSSimulation) -> Data {
        var pixels = [UInt8](terrainRGBA)
        let original = [UInt8](level.solidMask), solid = [UInt8](simulation.terrain.solidMask)
        guard original.count == solid.count else { return terrainRGBA }
        for i in solid.indices where solid[i] != original[i] {
            let x = (i % level.width) * 2, y = (i / level.width) * 2
            for dy in 0..<2 { for dx in 0..<2 {
                let p = ((y + dy) * width + x + dx) * 4
                if solid[i] == 0 { pixels[p + 3] = 0 }
                else { pixels[p] = 240; pixels[p+1] = 208; pixels[p+2] = 96; pixels[p+3] = 255 }
            } }
        }
        var triggerIndex = 0
        for object in level.objects {
            let placement = object.placement, graphic = object.graphic
            let interactive = placement.slot < 16 && graphic.triggerEffect != 0
            let cooldown = interactive ? simulation.objectCooldown(at: triggerIndex) : 0
            if interactive { triggerIndex += 1 }
            guard let definitions = artwork.objects[style], definitions.indices.contains(placement.id) else { continue }
            let seq = definitions[placement.id]
            guard seq.count > 0 else { continue }
            let index: Int
            switch graphic.animationType {
            case .none: index = seq.first
            case .continuous: index = (seq.first + simulation.tickCount) % seq.count
            case .onceAtStart:
                let elapsed = max(0, simulation.tickCount - ClassicDOSRules.entranceOpenTick)
                // The Mac hatch starts at frame 1 and rests at frame 0 after opening.
                index = elapsed >= seq.count - seq.first ? 0 : seq.first + elapsed
            case .triggered:
                index = cooldown > 0 ? min(max(0, seq.count - cooldown), seq.count - 1) : seq.first
            }
            guard let frame = artwork.frame(1600 + style, seq.base + index) else { continue }
            if graphic.triggerEffect == ClassicDOSObjectEffect.water.rawValue,
               !placement.draw.isUpsideDown, !placement.draw.onlyOverwrite {
                ClassicLiquidFill.draw(source: [UInt8](frame.rgba), sourceWidth: frame.width,
                    sourceHeight: frame.height, x: placement.x * 2 + frame.x,
                    y: placement.y * 2 + frame.y, into: &pixels, width: width,
                    height: height, solid: solid, scale: 2)
            }
            Self.blit(frame, into: &pixels, width: width, height: height,
                x: placement.x * 2 + frame.x, y: placement.y * 2 + frame.y,
                flipped: placement.draw.isUpsideDown, behind: placement.draw.noOverwrite,
                onlyTerrain: placement.draw.onlyOverwrite, solid: solid)
        }
        return Data(pixels)
    }

    private static func blit(_ frame: ClassicMacArtwork.Frame, into pixels: inout [UInt8],
        width: Int, height: Int, x: Int, y: Int, flipped: Bool = false, erase: Bool = false,
        behind: Bool = false, onlyTerrain: Bool = false, solid: [UInt8]? = nil) {
        let source = [UInt8](frame.rgba)
        let x0 = max(0, -x), y0 = max(0, -y)
        let x1 = min(frame.width, width - x), y1 = min(frame.height, height - y)
        guard x0 < x1, y0 < y1 else { return }
        for row in y0..<y1 {
            let sy = flipped ? frame.height - 1 - row : row
            for col in x0..<x1 {
                let s = (sy * frame.width + col) * 4
                guard source[s+3] != 0 else { continue }
                let d = ((y + row) * width + x + col) * 4
                let occupied = solid.map { $0[((y + row) / 2) * (width / 2) + (x + col) / 2] != 0 }
                    ?? (pixels[d+3] != 0)
                if behind && occupied { continue }
                if onlyTerrain && !occupied { continue }
                if erase { pixels[d+3] = 0 }
                else { pixels[d] = source[s]; pixels[d+1] = source[s+1]; pixels[d+2] = source[s+2]; pixels[d+3] = source[s+3] }
            }
        }
    }
}
