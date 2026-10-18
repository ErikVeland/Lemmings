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
        public var backpackGuide: ClassicMonochromeBackpack.Guide? = nil
    }
    public struct ObjectSequence: Codable, Sendable {
        public let first: Int
        public let count: Int
        public let base: Int
    }
    private struct FrameRecord: Decodable {
        let x: Int, y: Int, width: Int, height: Int
        let file: String
        let backpackGuide: ClassicMonochromeBackpack.Guide?
    }
    private struct Manifest: Decodable {
        let version: Int
        let monochrome: Bool?
        let banks: [String: [FrameRecord?]]
        let objects: [String: [ObjectSequence]]
        let names: [String: String]?
    }
    public let version: Int
    public let monochrome: Bool
    public let banks: [Int: [Frame?]]
    public let objects: [Int: [ObjectSequence]]
    let family: String
    /// The name the release gives each bank, such as "Charset2" or "Logo2".
    /// The front end asks for banks by name, because the numbers move between
    /// releases.
    public let names: [Int: String]

    public init(directory: URL) throws {
        let manifest = try JSONDecoder().decode(Manifest.self,
            from: Data(contentsOf: directory.appendingPathComponent("manifest.json")))
        var banks: [Int: [Frame?]] = [:]
        for (key, records) in manifest.banks {
            guard let id = Int(key) else { throw SequelDataError.invalid(L10n.text("Invalid Mac graphics bank.")) }
            banks[id] = try records.map { record in
                guard let record else { return nil }
                guard record.width > 0, record.height > 0, record.width <= 4096, record.height <= 4096,
                      !record.file.contains("/"), !record.file.contains("..") else {
                    throw SequelDataError.invalid(L10n.text("Invalid Mac graphics frame."))
                }
                let data = try Data(contentsOf: directory.appendingPathComponent(record.file))
                guard data.count == record.width * record.height * 4 else {
                    throw SequelDataError.invalid(L10n.text("Truncated Mac graphics frame."))
                }
                if let guide = record.backpackGuide {
                    guard (0..<record.height).contains(guide.top),
                        (-record.width...record.width).contains(guide.left),
                        (guide.left...record.width * 2).contains(guide.right),
                        guide.foreground.count <= record.width * record.height,
                        guide.foreground.allSatisfy({ (0..<record.width * record.height).contains($0) }) else {
                        throw SequelDataError.invalid(L10n.text("Invalid Mac backpack guide."))
                    }
                }
                return Frame(x: record.x, y: record.y, width: record.width,
                    height: record.height, rgba: data, backpackGuide: record.backpackGuide)
            }
        }
        self.monochrome = manifest.monochrome ?? false
        self.version = manifest.version
        self.family = directory.lastPathComponent.lowercased()
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
        frame(1400, Self.lemmingFrameIndex(pose: pose, left: left, tick: tick))
    }
    public static func lemmingFrameIndex(pose: ClassicLemmingPose, left: Bool, tick: Int) -> Int {
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
        return start + abs(tick % count)
    }
}

/// Which pieces of a fan level's ground set still look like the release's own.
///
/// Mac and Amiga banks are indexed by DOS piece number. A pack that redraws one
/// piece keeps its number, so the number alone cannot say whether the bank's
/// picture is the one the author meant. Each piece is therefore compared with
/// the stock set, and only identical pieces take the alternate artwork.
public struct ClassicMacPieceMatch: Sendable, Equatable {
    public let terrain: Set<Int>
    public let objects: Set<Int>
    /// Whether the level's full-screen special picture is the stock one.
    public var special: Bool

    public init(terrain: Set<Int>, objects: Set<Int>, special: Bool = false) {
        self.terrain = terrain
        self.objects = objects
        self.special = special
    }

    /// Compares two ground sets piece by piece.
    ///
    /// A changed palette recolours every piece, so it matches nothing. Object
    /// triggers are ignored: they steer the simulation, not the picture.
    public static func compare(_ ground: ClassicGroundSet, with stock: ClassicGroundSet) -> Self? {
        guard ground.style == stock.style,
              ground.terrainPalette == stock.terrainPalette,
              ground.objectPalette == stock.objectPalette else { return nil }
        let terrain = ground.terrain.filter { stock.terrain[$0.key] == $0.value }.keys
        let objects = ground.objects.filter { id, graphic in
            guard let original = stock.objects[id] else { return false }
            return graphic.width == original.width && graphic.height == original.height
                && graphic.frames == original.frames
                && graphic.animationType == original.animationType
                && graphic.firstFrameIndex == original.firstFrameIndex
        }.keys
        return Self(terrain: Set(terrain), objects: Set(objects))
    }

    /// How many of the pieces a level uses still look like the stock set's.
    /// Returns nil when no piece is in use.
    public func share(of level: ClassicLevel) -> Double? {
        // A special level draws one picture instead of terrain pieces.
        let pieces = level.specialStyle > 0 ? [] : Set(level.terrain.map(\.id))
        let used = pieces.map { terrain.contains($0) }
            + Set(level.objects.map(\.id)).map { objects.contains($0) }
        guard !used.isEmpty else { return nil }
        return Double(used.filter { $0 }.count) / Double(used.count)
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
    private let match: ClassicMacPieceMatch?
    /// Reconstructed frames for objects the pack changed, by position in `level.objects`.
    private let reconstructedObjects: [Int: [ClassicMacArtwork.Frame]]
    /// Exit triggers drawn with Mac artwork, with the drawn door's centre.
    private struct ExitDoor: Sendable {
        let x1: Int, y1: Int, x2: Int, y2: Int
        /// Twice the door's centre in scene pixels, so half pixels stay exact.
        let doubledCentre: Int
    }
    private let exitDoors: [ExitDoor]
    private let arrowGlintBounds: (x: Int, y: Int, width: Int, height: Int)?

    /// `match` lists the pieces allowed to use the artwork. Without it every piece does.
    /// Pieces left out use their source geometry with inferred Macintosh detail.
    public init(level source: ClassicLevel, rendered: ClassicRenderedLevel, artwork: ClassicMacArtwork,
        groundSet: ClassicGroundSet? = nil, match: ClassicMacPieceMatch? = nil,
        reconstructUnmatched: Bool = true) throws {
        width = rendered.width * 2; height = rendered.height * 2
        let style = groundSet?.style ?? source.groundStyle
        level = rendered; self.artwork = artwork; self.style = style; self.match = match
        var reconstructedObjects: [Int: [ClassicMacArtwork.Frame]] = [:]
        var objectFrames: [Int: [ClassicMacArtwork.Frame]] = [:]
        for (position, object) in rendered.objects.enumerated() {
            let id = object.placement.id
            let sequence = artwork.objects[style].flatMap { $0.indices.contains(id) ? $0[id] : nil }
            let macAvailable = (match?.objects.contains(id) ?? true) && sequence.map { seq in
                seq.count > 0 && (0..<seq.count).allSatisfy {
                    artwork.frame(1600 + style, seq.base + $0) != nil
                }
            } == true
            if !macAvailable {
                if objectFrames[object.placement.id] == nil {
                    objectFrames[object.placement.id] = try object.rgbaFrames.map {
                        let frame = reconstructUnmatched
                            ? try Self.reconstructedObject($0, graphic: object.graphic)
                            : Self.doubled($0, width: object.graphic.width, height: object.graphic.height)
                        return artwork.monochrome ? ClassicMacArtwork.Frame(x: frame.x, y: frame.y,
                            width: frame.width, height: frame.height,
                            rgba: Self.monochromeRGBA(frame.rgba, width: frame.width)) : frame
                    }
                }
                reconstructedObjects[position] = objectFrames[object.placement.id]
                continue
            }
        }
        self.reconstructedObjects = reconstructedObjects
        var exitDoors: [ExitDoor] = []
        for (position, object) in rendered.objects.enumerated() where reconstructedObjects[position] == nil {
            let placement = object.placement, graphic = object.graphic
            guard placement.slot < rendered.interactiveObjectSlotLimit,
                  graphic.triggerEffect == ClassicDOSObjectEffect.exit.rawValue,
                  let definitions = artwork.objects[style], definitions.indices.contains(placement.id),
                  definitions[placement.id].count > 0,
                  let frame = artwork.frame(1600 + style, definitions[placement.id].base + definitions[placement.id].first),
                  let span = Self.opaqueColumns(frame) else { continue }
            let x = (placement.x & ~3) + graphic.triggerLeft, y = (placement.y & ~3) + graphic.triggerTop
            exitDoors.append(ExitDoor(x1: x, y1: y, x2: x + graphic.triggerWidth, y2: y + graphic.triggerHeight,
                doubledCentre: (placement.x * 2 + frame.x) * 2 + span.lowerBound + span.upperBound))
        }
        self.exitDoors = exitDoors
        arrowGlintBounds = Self.arrowGlintBounds(level: rendered, artwork: artwork, style: style,
            reconstructed: reconstructedObjects, width: width, height: height)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        if source.specialStyle > 0 {
            if (match?.special ?? true), let frame = artwork.frame(1699 + source.specialStyle) {
                Self.blit(frame, into: &pixels, width: width, height: height,
                    x: 304 * 2, y: 0)
            } else {
                let frame = try reconstructUnmatched
                    ? Self.reconstructed(rendered.rgba, width: rendered.width,
                        height: rendered.height, category: .architectural)
                    : Self.doubled(rendered.rgba, width: rendered.width, height: rendered.height)
                Self.blit(frame, into: &pixels, width: width, height: height, x: 0, y: 0)
            }
        }
        var terrainFrames: [Int: ClassicMacArtwork.Frame] = [:]
        for tile in source.terrain where source.specialStyle == 0 {
            let frame: ClassicMacArtwork.Frame
            // The Macintosh snowman leans left; the DOS collision piece leans right.
            // Reconstruct its source geometry so its head cannot become invisible ground.
            // Version 3 contains Amiga artwork and keeps its native piece.
            let sourceSnowman = style == 2 && tile.id == 12
                && ["holiday", "xmas"].contains(artwork.family)
                && artwork.version <= 2
                && groundSet?.terrain[tile.id] != nil
            if !sourceSnowman, match?.terrain.contains(tile.id) ?? true,
                let mac = artwork.frame(1500 + style, tile.id) { frame = mac }
            else if let groundSet, let dos = groundSet.terrain[tile.id] {
                if terrainFrames[tile.id] == nil {
                    if reconstructUnmatched {
                        terrainFrames[tile.id] = try Self.reconstructedTerrain(dos,
                            palette: groundSet.objectPalette, family: artwork.family, style: style)
                    } else {
                        var rgba = [UInt8](repeating: 0, count: dos.width * dos.height * 4)
                        for (i, value) in dos.indexedPixels.enumerated() where value & 0x80 == 0 {
                            let colour = groundSet.objectPalette[Int(value & 15)]
                            rgba[i * 4] = colour.red; rgba[i * 4 + 1] = colour.green
                            rgba[i * 4 + 2] = colour.blue; rgba[i * 4 + 3] = 255
                        }
                        terrainFrames[tile.id] = Self.doubled(Data(rgba),
                            width: dos.width, height: dos.height)
                    }
                }
                frame = terrainFrames[tile.id]!
            } else { throw SequelDataError.invalid(L10n.text("Missing Mac terrain piece \(tile.id).")) }
            Self.blit(frame, into: &pixels, width: width, height: height,
                x: tile.x * 2 + frame.x,
                y: tile.y * 2 + ((artwork.version == 1 && tile.draw.isUpsideDown) ? 0 : frame.y),
                flipped: tile.draw.isUpsideDown, erase: tile.draw.isErase, behind: tile.draw.noOverwrite)
        }
        terrainRGBA = artwork.monochrome ? Self.monochromeRGBA(Data(pixels), width: width) : Data(pixels)
    }

    /// Returns the scene pixels to move an exiting lemming onto the drawn door.
    ///
    /// The simulation keeps the DOS exit trigger. Some Mac exits put the door
    /// up to four pixels to one side of it, so the jump missed the opening.
    /// `spriteOffsetX` is the DOS exiting animation's horizontal offset.
    public func exitingShift(footX: Int, footY: Int, spriteOffsetX: Int) -> Int {
        guard let door = exitDoors.last(where: {
                  $0.x1 <= footX && footX < $0.x2 && $0.y1 <= footY && footY < $0.y2 }),
              let sprite = artwork.lemming(pose: .exiting, left: false, tick: 0),
              let span = Self.opaqueColumns(sprite) else { return 0 }
        let doubledSprite = ((footX + spriteOffsetX) * 2 + sprite.x) * 2 + span.lowerBound + span.upperBound
        return Int(((Double(door.doubledCentre - doubledSprite)) / 2).rounded())
    }

    /// The first and one-past-last columns that hold a visible pixel.
    private static func opaqueColumns(_ frame: ClassicMacArtwork.Frame) -> Range<Int>? {
        let rgba = [UInt8](frame.rgba)
        let columns = (0..<frame.width).filter { x in
            (0..<frame.height).contains { rgba[($0 * frame.width + x) * 4 + 3] != 0 }
        }
        guard let first = columns.first, let last = columns.last else { return nil }
        return first..<(last + 1)
    }

    public func terrainFrame(terrain: ClassicDOSTerrain) -> Data {
        Data(terrainPixels(solid: [UInt8](terrain.solidMask)))
    }

    private func terrainPixels(solid: [UInt8]) -> [UInt8] {
        var pixels = [UInt8](terrainRGBA)
        let original = [UInt8](level.solidMask)
        guard original.count == solid.count else { return pixels }
        for i in solid.indices where solid[i] != original[i] {
            let x = (i % level.width) * 2, y = (i / level.width) * 2
            for dy in 0..<2 { for dx in 0..<2 {
                let p = ((y + dy) * width + x + dx) * 4
                if solid[i] == 0 { pixels[p + 3] = 0 }
                else {
                    let colour: (UInt8, UInt8, UInt8) = artwork.monochrome ? (255, 255, 255) : (240, 208, 96)
                    pixels[p] = colour.0; pixels[p+1] = colour.1; pixels[p+2] = colour.2; pixels[p+3] = 255
                }
            } }
        }
        return pixels
    }

    /// Light above SDR white on the lit arrow edges, by scene pixel.
    ///
    /// `strength` covers one byte per pixel of the rectangle at `x`, `y`.
    /// 255 means the glint adds up to the full HDR peak. The SDR frame
    /// already holds the glint up to white; this is only the light it clips.
    public struct ArrowGlints: Equatable, Sendable {
        public let x: Int, y: Int, width: Int, height: Int
        public let strength: Data
    }

    public func rgba(simulation: ClassicDOSSimulation, terrain: Data? = nil) -> Data {
        render(simulation: simulation, terrain: terrain, glints: false).rgba
    }

    /// The frame from `rgba(simulation:terrain:)`, with the arrow glints for
    /// HDR displays. `glints` is nil when no arrow edge catches the light.
    public func rgbaWithArrowGlints(simulation: ClassicDOSSimulation,
        terrain: Data? = nil) -> (rgba: Data, glints: ArrowGlints?) {
        render(simulation: simulation, terrain: terrain, glints: !artwork.monochrome)
    }

    private func render(simulation: ClassicDOSSimulation, terrain: Data?,
        glints wantsGlints: Bool) -> (rgba: Data, glints: ArrowGlints?) {
        let solid = [UInt8](simulation.terrain.solidMask)
        guard solid.count == level.solidMask.count else { return (terrainRGBA, nil) }
        let visualTerrain = terrain ?? Data(terrainPixels(solid: solid))
        var pixels = [UInt8](visualTerrain)
        var glints: GlintCanvas? = wantsGlints ? arrowGlintCanvas() : nil
        var triggerIndex = 0
        for (position, object) in level.objects.enumerated() {
            let placement = object.placement, graphic = object.graphic
            let interactive = placement.slot < level.interactiveObjectSlotLimit && graphic.triggerEffect != 0
            let cooldown = interactive ? simulation.objectCooldown(at: triggerIndex) : 0
            if interactive { triggerIndex += 1 }
            let frame: ClassicMacArtwork.Frame
            if let own = reconstructedObjects[position] {
                let index = ClassicSceneFrame.frameIndex(of: object, cooldown: cooldown, tick: simulation.tickCount)
                guard own.indices.contains(index) else { continue }
                frame = own[index]
            } else {
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
                guard let mac = artwork.frame(1600 + style, seq.base + index) else { continue }
                frame = mac
            }
            let isLiquid = graphic.triggerEffect == ClassicDOSObjectEffect.water.rawValue
            if isLiquid, !placement.draw.isUpsideDown, !placement.draw.onlyOverwrite {
                ClassicLiquidFill.draw(source: [UInt8](frame.rgba), sourceWidth: frame.width,
                    sourceHeight: frame.height, x: placement.x * 2 + frame.x,
                    y: placement.y * 2 + frame.y, into: &pixels, width: width,
                    height: height, solid: solid, scale: 2,
                    minimumBottom: (placement.y + graphic.height) * 2, visualTerrain: visualTerrain)
            }
            let isArrow = graphic.triggerEffect == ClassicDOSObjectEffect.oneWayLeft.rawValue
                || graphic.triggerEffect == ClassicDOSObjectEffect.oneWayRight.rawValue
            if isArrow, placement.draw.onlyOverwrite, !placement.draw.noOverwrite {
                // Clip arrows to the drawn Mac terrain, not the DOS collision cells.
                Self.wrapArrows(frame, into: &pixels, width: width, height: height,
                    x: placement.x * 2 + frame.x, y: placement.y * 2 + frame.y,
                    flipped: placement.draw.isUpsideDown, visualTerrain: [UInt8](visualTerrain),
                    shaded: !artwork.monochrome, glints: &glints)
                continue
            }
            Self.blit(frame, into: &pixels, width: width, height: height,
                x: placement.x * 2 + frame.x, y: placement.y * 2 + frame.y,
                flipped: placement.draw.isUpsideDown, behind: placement.draw.noOverwrite,
                onlyTerrain: placement.draw.onlyOverwrite, solid: solid,
                visualTerrain: isLiquid ? visualTerrain : nil)
        }
        return (Data(pixels), glints.flatMap { $0.lit ? ArrowGlints(x: $0.x, y: $0.y,
            width: $0.width, height: $0.height, strength: Data($0.strength)) : nil })
    }

    /// The glint buffer, sized to the drawn arrows rather than the scene.
    private struct GlintCanvas {
        let x: Int, y: Int, width: Int, height: Int
        var strength: [UInt8]
        var lit = false
    }

    private func arrowGlintCanvas() -> GlintCanvas? {
        arrowGlintBounds.map { GlintCanvas(x: $0.x, y: $0.y, width: $0.width, height: $0.height,
            strength: [UInt8](repeating: 0, count: $0.width * $0.height)) }
    }

    /// The scene rectangle that every frame of every wrapped arrow can cover.
    private static func arrowGlintBounds(level: ClassicRenderedLevel, artwork: ClassicMacArtwork,
        style: Int, reconstructed: [Int: [ClassicMacArtwork.Frame]], width: Int, height: Int)
        -> (x: Int, y: Int, width: Int, height: Int)? {
        guard !artwork.monochrome else { return nil }
        var x0 = Int.max, y0 = Int.max, x1 = Int.min, y1 = Int.min
        for (position, object) in level.objects.enumerated() {
            let placement = object.placement, graphic = object.graphic
            guard graphic.triggerEffect == ClassicDOSObjectEffect.oneWayLeft.rawValue
                || graphic.triggerEffect == ClassicDOSObjectEffect.oneWayRight.rawValue,
                placement.draw.onlyOverwrite, !placement.draw.noOverwrite else { continue }
            let frames: [ClassicMacArtwork.Frame]
            if let own = reconstructed[position] { frames = own }
            else if let definitions = artwork.objects[style], definitions.indices.contains(placement.id) {
                let seq = definitions[placement.id]
                frames = (0..<seq.count).compactMap { artwork.frame(1600 + style, seq.base + $0) }
            } else { continue }
            for frame in frames {
                let x = placement.x * 2 + frame.x, y = placement.y * 2 + frame.y
                x0 = min(x0, x); y0 = min(y0, y)
                x1 = max(x1, x + frame.width); y1 = max(y1, y + frame.height)
            }
        }
        let left = max(0, x0), top = max(0, y0), right = min(width, x1), bottom = min(height, y1)
        guard left < right, top < bottom else { return nil }
        return (left, top, right - left, bottom - top)
    }

    /// Dithers fallback pixels while retaining every source alpha value.
    public static func monochromeRGBA(_ rgba: Data, width: Int) -> Data {
        guard width > 0 else { return rgba }
        var pixels = [UInt8](rgba)
        let thresholds = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
        for i in 0..<(pixels.count / 4) where pixels[i * 4 + 3] != 0 {
            let p = i * 4
            let luminance = (Int(pixels[p]) * 299 + Int(pixels[p + 1]) * 587 + Int(pixels[p + 2]) * 114) / 1000
            let threshold = thresholds[((i / width) % 4) * 4 + i % width % 4] * 16 + 8
            let value: UInt8 = luminance > threshold ? 255 : 0
            pixels[p] = value; pixels[p + 1] = value; pixels[p + 2] = value
        }
        return Data(pixels)
    }

    /**
     * Reconstructs a Classic terrain piece with its gameplay palette and material treatment.
     */
    public static func reconstructedTerrain(_ graphic: ClassicTerrainGraphic,
        palette: [ClassicRGBColor], family: String, style: Int) throws -> ClassicMacArtwork.Frame {
        var rgba = [UInt8](repeating: 0, count: graphic.width * graphic.height * 4)
        for (i, value) in graphic.indexedPixels.enumerated() where value & 0x80 == 0 {
            let colour = palette[Int(value & 15)]
            rgba[i * 4] = colour.red; rgba[i * 4 + 1] = colour.green
            rgba[i * 4 + 2] = colour.blue; rgba[i * 4 + 3] = 255
        }
        // Unused style colours can belong to another material, such as green
        // foliage beside brown rock. Texture this piece with its own pigments.
        return try reconstructed(Data(rgba), width: graphic.width, height: graphic.height,
            category: terrainCategory(family: family, style: style))
    }

    /**
     * Reconstructs one object frame without changing its source transparency.
     */
    public static func reconstructedObject(_ rgba: Data,
        graphic: ClassicObjectGraphic) throws -> ClassicMacArtwork.Frame {
        let category: SequelMacCategory = graphic.triggerEffect == ClassicDOSObjectEffect.water.rawValue
            ? .liquid : .mechanical
        return try reconstructed(rgba, width: graphic.width, height: graphic.height,
            category: category)
    }

    /**
     * Applies measured Macintosh colour-boundary rules without moving an opaque source cell.
     */
    public static func reconstructed(_ rgba: Data, width: Int, height: Int,
        category: SequelMacCategory, palette: [ClassicRGBColor]? = nil) throws -> ClassicMacArtwork.Frame {
        let source = try SequelMacFrame(width: width, height: height, rgba: [UInt8](rgba),
            sourcePalette: palette.map(Self.paletteBytes))
        let result = try SequelMacArtwork.reconstruct(source, category: category)
        var output = result.rgba
        if category == .liquid {
            // The sequel liquid treatment fills transparent tails. Classic liquid
            // bodies are handled by ClassicLiquidFill, so retain the source mask.
            for i in 0..<(width * height) where rgba[i * 4 + 3] == 0 {
                for dy in 0..<2 { for dx in 0..<2 {
                    let p = (((i / width) * 2 + dy) * width * 2 + (i % width) * 2 + dx) * 4
                    output[p] = 0; output[p + 1] = 0; output[p + 2] = 0; output[p + 3] = 0
                } }
            }
        }
        return ClassicMacArtwork.Frame(x: 0, y: 0, width: result.width,
            height: result.height, rgba: Data(output))
    }

    public static func terrainCategory(family: String, style: Int) -> SequelMacCategory {
        if family == "xmas" || family == "holiday" { return .organic }
        if family == "lemmings" && [0, 1, 4].contains(style) { return .organic }
        if family == "ohno" && [1, 2].contains(style) { return .organic }
        return .architectural
    }

    private static func paletteBytes(_ palette: [ClassicRGBColor]) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 256 * 4)
        for (index, colour) in palette.prefix(256).enumerated() {
            bytes[index * 4] = colour.red
            bytes[index * 4 + 1] = colour.green
            bytes[index * 4 + 2] = colour.blue
            bytes[index * 4 + 3] = 255
        }
        return bytes
    }

    private static func doubled(_ rgba: Data, width: Int, height: Int) -> ClassicMacArtwork.Frame {
        let source = [UInt8](rgba)
        var output = [UInt8](repeating: 0, count: width * height * 16)
        for y in 0..<height { for x in 0..<width {
            let s = (y * width + x) * 4
            for dy in 0..<2 { for dx in 0..<2 {
                let d = ((y * 2 + dy) * width * 2 + x * 2 + dx) * 4
                output[d] = source[s]; output[d + 1] = source[s + 1]
                output[d + 2] = source[s + 2]; output[d + 3] = source[s + 3]
            } }
        } }
        return ClassicMacArtwork.Frame(x: 0, y: 0, width: width * 2,
            height: height * 2, rgba: Data(output))
    }

    private static func blit(_ frame: ClassicMacArtwork.Frame, into pixels: inout [UInt8],
        width: Int, height: Int, x: Int, y: Int, flipped: Bool = false, erase: Bool = false,
        behind: Bool = false, onlyTerrain: Bool = false, solid: [UInt8]? = nil,
        visualTerrain: Data? = nil) {
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
                let occupied: Bool
                if let visualTerrain {
                    occupied = visualTerrain[d + 3] != 0
                } else if let solid {
                    occupied = solid[((y + row) / 2) * (width / 2) + (x + col) / 2] != 0
                } else {
                    occupied = pixels[d + 3] != 0
                }
                if behind && occupied { continue }
                if onlyTerrain && !occupied { continue }
                if erase { pixels[d+3] = 0 }
                else { pixels[d] = source[s]; pixels[d+1] = source[s+1]; pixels[d+2] = source[s+2]; pixels[d+3] = source[s+3] }
            }
        }
    }

    /// Mac pixels over which arrows curve away from the terrain edge.
    private static let arrowBevel = 7
    /// How much terrain shows through the arrows.
    private static let arrowOpacity = 0.68

    /**
     * Draws one-way arrows as a decal wrapped over the drawn terrain.
     *
     * The arrows stop one pixel short of each terrain edge. Near the edge they
     * darken as the surface turns away and catch light on edges that face up
     * and left. `shaded` is false for monochrome art, which keeps plain clipping.
     * `glints` collects the edge light for HDR displays, without changing `pixels`.
     */
    private static func wrapArrows(_ frame: ClassicMacArtwork.Frame, into pixels: inout [UInt8],
        width: Int, height: Int, x: Int, y: Int, flipped: Bool,
        visualTerrain: [UInt8], shaded: Bool, glints: inout GlintCanvas?) {
        let source = [UInt8](frame.rgba)
        let x0 = max(0, -x), y0 = max(0, -y)
        let x1 = min(frame.width, width - x), y1 = min(frame.height, height - y)
        guard x0 < x1, y0 < y1 else { return }

        // Chamfer distance to the nearest empty terrain pixel, in half pixels
        // (2 straight, 3 diagonal). The field extends past the frame so edges
        // just outside it still shape the arrows.
        let margin = arrowBevel + 1
        let fx = x + x0 - margin, fy = y + y0 - margin
        let fw = x1 - x0 + margin * 2, fh = y1 - y0 + margin * 2
        let far = (arrowBevel + 2) * 2
        var distance = [Int](repeating: far, count: fw * fh)
        for row in 0..<fh {
            let ly = fy + row
            for col in 0..<fw {
                let lx = fx + col
                // The level border is not a terrain edge.
                guard (0..<width).contains(lx), (0..<height).contains(ly) else { continue }
                if visualTerrain[(ly * width + lx) * 4 + 3] == 0 { distance[row * fw + col] = 0 }
            }
        }
        for row in 0..<fh {
            for col in 0..<fw {
                let i = row * fw + col
                var d = distance[i]
                if col > 0 { d = min(d, distance[i - 1] + 2) }
                if row > 0 {
                    d = min(d, distance[i - fw] + 2)
                    if col > 0 { d = min(d, distance[i - fw - 1] + 3) }
                    if col < fw - 1 { d = min(d, distance[i - fw + 1] + 3) }
                }
                distance[i] = d
            }
        }
        for row in stride(from: fh - 1, through: 0, by: -1) {
            for col in stride(from: fw - 1, through: 0, by: -1) {
                let i = row * fw + col
                var d = distance[i]
                if col < fw - 1 { d = min(d, distance[i + 1] + 2) }
                if row < fh - 1 {
                    d = min(d, distance[i + fw] + 2)
                    if col < fw - 1 { d = min(d, distance[i + fw + 1] + 3) }
                    if col > 0 { d = min(d, distance[i + fw - 1] + 3) }
                }
                distance[i] = d
            }
        }

        for row in y0..<y1 {
            let sy = flipped ? frame.height - 1 - row : row
            for col in x0..<x1 {
                let s = (sy * frame.width + col) * 4
                guard source[s + 3] != 0 else { continue }
                let fi = (row - y0 + margin) * fw + (col - x0 + margin)
                let d = distance[fi]
                // Bevel in: leave the outermost terrain pixel bare.
                guard d > 2 else { continue }
                let p = ((y + row) * width + x + col) * 4
                guard shaded else {
                    pixels[p] = source[s]; pixels[p + 1] = source[s + 1]; pixels[p + 2] = source[s + 2]
                    continue
                }
                var light = 1.0, glint = 0.0
                let edge = 1 - Double(d - 2) / Double(arrowBevel * 2)
                if edge > 0 {
                    // The distance gradient points into the terrain. Its reverse is
                    // the outward surface normal; light comes from the upper left.
                    let gx = Double(distance[fi + 1] - distance[fi - 1])
                    let gy = Double(distance[fi + fw] - distance[fi - fw])
                    let length = (gx * gx + gy * gy).squareRoot()
                    let facing = length > 0 ? (gx + gy) / (length * 2.0.squareRoot()) : 0
                    let curve = edge * edge
                    light = 1 - 0.65 * curve + 0.3 * min(0, facing) * curve
                    glint = max(0, facing) * curve * 150
                }
                if glint > 0, glints != nil {
                    let gx = x + col - glints!.x, gy = y + row - glints!.y
                    if (0..<glints!.width).contains(gx), (0..<glints!.height).contains(gy) {
                        let value = UInt8((glint / 150 * arrowOpacity * 255).rounded())
                        let g = gy * glints!.width + gx
                        if value > glints!.strength[g] { glints!.strength[g] = value; glints!.lit = true }
                    }
                }
                for c in 0..<3 {
                    let arrow = min(255, Double(source[s + c]) * light + glint)
                    let ground = Double(pixels[p + c])
                    pixels[p + c] = UInt8(ground + (arrow - ground) * arrowOpacity)
                }
            }
        }
    }
}
