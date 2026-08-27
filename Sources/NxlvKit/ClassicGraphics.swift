import Foundation

/// Expands a 6-bit VGA DAC component to full-range 8-bit RGB with nearest
/// rounding, matching modern VGA emulation.
private func classicVGAComponent(_ value: UInt8) -> UInt8 {
    let sixBitValue = UInt16(value & 0x3F)
    return UInt8((sixBitValue * 255 + 31) / 63)
}

public struct ClassicRGBColor: Codable, Equatable, Sendable {
    public let red: UInt8
    public let green: UInt8
    public let blue: UInt8

    public init(red: UInt8, green: UInt8, blue: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
    }
}

public struct ClassicTerrainGraphic: Codable, Equatable, Sendable {
    public let id: Int
    public let width: Int
    public let height: Int
    /// One byte per pixel. Bit 7 marks transparency; bits 0...3 are the
    /// palette index.
    public let indexedPixels: Data
}

public struct ClassicObjectGraphic: Codable, Equatable, Sendable {
    public let id: Int
    public let width: Int
    public let height: Int
    public let frames: [Data]
    public let animationType: ClassicObjectAnimationType
    public var animationLoops: Bool { animationType == .continuous }
    public let firstFrameIndex: Int
    public let triggerLeft: Int
    public let triggerTop: Int
    public let triggerWidth: Int
    public let triggerHeight: Int
    public let triggerEffect: Int
    public let trapSoundEffect: Int
}

public enum ClassicObjectAnimationType: Int, Codable, Equatable, Sendable {
    case none = 0
    case triggered = 1
    case continuous = 2
    case onceAtStart = 3
}

public enum ClassicGraphicsError: Error, Equatable, CustomStringConvertible {
    case invalidGroundSize(actual: Int)
    case invalidVGAGRSectionCount(actual: Int)
    case missingFile(String)
    case outOfBounds(label: String, offset: Int, required: Int, available: Int)
    case invalidGraphicSize(label: String, width: Int, height: Int)
    case invalidTerrainPiece(id: Int)
    case malformedSpecialGraphic(String)

    public var description: String {
        switch self {
        case let .invalidGroundSize(actual):
            return "GROUNDxO.DAT must be exactly 1056 bytes; found \(actual)."
        case let .invalidVGAGRSectionCount(actual):
            return "VGAGRx.DAT must contain two sections; found \(actual)."
        case let .missingFile(file):
            return "Required classic graphics file is missing: \(file)."
        case let .outOfBounds(label, offset, required, available):
            return "\(label) reads \(required) bytes at \(offset), beyond \(available) available bytes."
        case let .invalidGraphicSize(label, width, height):
            return "\(label) has invalid size \(width)×\(height)."
        case let .invalidTerrainPiece(id):
            return "The level references missing terrain piece \(id)."
        case let .malformedSpecialGraphic(message):
            return "Malformed VGASPEC data: \(message)"
        }
    }
}

public struct ClassicGroundSet: Codable, Equatable, Sendable {
    public let style: Int
    public let terrainPalette: [ClassicRGBColor]
    public let objectPalette: [ClassicRGBColor]
    public let terrain: [Int: ClassicTerrainGraphic]
    public let objects: [Int: ClassicObjectGraphic]

    public static func load(style: Int, from directory: URL) throws -> ClassicGroundSet {
        let files = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        let byName = Dictionary(
            files.map { ($0.lastPathComponent.lowercased(), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let groundName = "ground\(style)o.dat"
        let graphicsName = "vgagr\(style).dat"
        guard let groundURL = byName[groundName] else { throw ClassicGraphicsError.missingFile(groundName) }
        guard let graphicsURL = byName[graphicsName] else { throw ClassicGraphicsError.missingFile(graphicsName) }
        return try ClassicGroundSet(
            style: style,
            groundData: Data(contentsOf: groundURL, options: .mappedIfSafe),
            graphicsArchiveData: Data(contentsOf: graphicsURL, options: .mappedIfSafe)
        )
    }

    public init(style: Int, groundData: Data, graphicsArchiveData: Data) throws {
        let ground = [UInt8](groundData)
        guard ground.count == 1_056 else {
            throw ClassicGraphicsError.invalidGroundSize(actual: ground.count)
        }
        let graphicsSections = try ClassicDATArchive.decode(graphicsArchiveData)
        guard graphicsSections.count == 2 else {
            throw ClassicGraphicsError.invalidVGAGRSectionCount(actual: graphicsSections.count)
        }
        let terrainGraphics = [UInt8](graphicsSections[0].data)
        let objectGraphics = [UInt8](graphicsSections[1].data)

        self.style = style
        terrainPalette = Self.readPalette(ground, at: 984, count: 8)
        // The first seven DOS object colours are fixed gameplay colours.
        // They do not exactly match the VGA standard palette in GROUNDxO.
        let gameplayPalette = [
            ClassicRGBColor(red: 0, green: 0, blue: 0),
            ClassicRGBColor(red: classicVGAComponent(16), green: classicVGAComponent(16), blue: classicVGAComponent(56)),
            ClassicRGBColor(red: 0, green: classicVGAComponent(44), blue: 0),
            ClassicRGBColor(red: classicVGAComponent(60), green: classicVGAComponent(52), blue: classicVGAComponent(52)),
            ClassicRGBColor(red: classicVGAComponent(60), green: classicVGAComponent(60), blue: 0),
            ClassicRGBColor(red: classicVGAComponent(60), green: classicVGAComponent(8), blue: classicVGAComponent(8)),
            ClassicRGBColor(red: classicVGAComponent(32), green: classicVGAComponent(32), blue: classicVGAComponent(32)),
        ]
        objectPalette = gameplayPalette
            + [terrainPalette[0]]
            + terrainPalette

        var decodedTerrain: [Int: ClassicTerrainGraphic] = [:]
        for id in 0..<64 {
            let offset = 448 + id * 8
            let width = Int(ground[offset])
            let height = Int(ground[offset + 1])
            guard width > 0, height > 0 else { continue }
            let imageOffset = Self.littleEndianWord(ground, at: offset + 2)
            let maskOffset = Self.littleEndianWord(ground, at: offset + 4)
            let pixels = try Self.decodePlanarImage(
                terrainGraphics,
                label: "terrain piece \(id)",
                width: width,
                height: height,
                imageOffset: imageOffset,
                maskOffset: maskOffset,
                bitsPerPixel: 4
            )
            decodedTerrain[id] = ClassicTerrainGraphic(
                id: id,
                width: width,
                height: height,
                indexedPixels: Data(pixels)
            )
        }
        terrain = decodedTerrain

        var decodedObjects: [Int: ClassicObjectGraphic] = [:]
        for id in 0..<16 {
            let offset = id * 28
            let flags = Self.littleEndianWord(ground, at: offset)
            let firstFrameIndex = Int(ground[offset + 2])
            let frameCount = Int(ground[offset + 3])
            let width = Int(ground[offset + 4])
            let height = Int(ground[offset + 5])
            guard width > 0, height > 0, frameCount > 0 else { continue }
            let frameDataSize = Self.littleEndianWord(ground, at: offset + 6)
            let maskDelta = Self.littleEndianWord(ground, at: offset + 8)
            let triggerLeft = Self.littleEndianWord(ground, at: offset + 14) * 4
            let triggerTop = Self.littleEndianWord(ground, at: offset + 16) * 4 - 4
            let rawTriggerWidth = Int(ground[offset + 18])
            let rawTriggerHeight = Int(ground[offset + 19])
            let triggerWidth = (rawTriggerWidth == 0 ? 256 : rawTriggerWidth) * 4
            let triggerHeight = (rawTriggerHeight == 0 ? 256 : rawTriggerHeight) * 4
            let triggerEffect = Int(ground[offset + 20])
            let imageOffset = Self.littleEndianWord(ground, at: offset + 21)
            let trapSoundEffect = Int(ground[offset + 27])

            var frames: [Data] = []
            frames.reserveCapacity(frameCount)
            for frame in 0..<frameCount {
                let frameOffset = imageOffset + frame * frameDataSize
                let pixels = try Self.decodePlanarImage(
                    objectGraphics,
                    label: "object \(id) frame \(frame)",
                    width: width,
                    height: height,
                    imageOffset: frameOffset,
                    maskOffset: frameOffset + maskDelta,
                    bitsPerPixel: 4
                )
                frames.append(Data(pixels))
            }
            decodedObjects[id] = ClassicObjectGraphic(
                id: id,
                width: width,
                height: height,
                frames: frames,
                animationType: ClassicObjectAnimationType(rawValue: flags & 0x0003) ?? .none,
                firstFrameIndex: firstFrameIndex,
                triggerLeft: triggerLeft,
                triggerTop: triggerTop,
                triggerWidth: triggerWidth,
                triggerHeight: triggerHeight,
                triggerEffect: triggerEffect,
                trapSoundEffect: trapSoundEffect
            )
        }
        objects = decodedObjects
    }

    private static func readPalette(_ data: [UInt8], at offset: Int, count: Int) -> [ClassicRGBColor] {
        (0..<count).map { index in
            let position = offset + index * 3
            return ClassicRGBColor(
                red: classicVGAComponent(data[position]),
                green: classicVGAComponent(data[position + 1]),
                blue: classicVGAComponent(data[position + 2])
            )
        }
    }

    private static func decodePlanarImage(
        _ data: [UInt8],
        label: String,
        width: Int,
        height: Int,
        imageOffset: Int,
        maskOffset: Int,
        bitsPerPixel: Int
    ) throws -> [UInt8] {
        guard width > 0, height > 0, width <= Int.max / height else {
            throw ClassicGraphicsError.invalidGraphicSize(label: label, width: width, height: height)
        }
        let pixelCount = width * height
        let bytesPerPlane = (pixelCount + 7) / 8
        let imageByteCount = bytesPerPlane * bitsPerPixel
        try requireRange(data, label: "\(label) pixels", offset: imageOffset, count: imageByteCount)
        try requireRange(data, label: "\(label) mask", offset: maskOffset, count: bytesPerPlane)

        var pixels = [UInt8](repeating: 0, count: pixelCount)
        for plane in 0..<bitsPerPixel {
            let planeOffset = imageOffset + plane * bytesPerPlane
            for pixel in 0..<pixelCount {
                let byte = data[planeOffset + pixel / 8]
                let bit = (byte >> UInt8(7 - pixel % 8)) & 1
                pixels[pixel] |= bit << UInt8(plane)
            }
        }
        for pixel in 0..<pixelCount {
            let byte = data[maskOffset + pixel / 8]
            let isOpaque = (byte >> UInt8(7 - pixel % 8)) & 1 != 0
            if !isOpaque { pixels[pixel] |= 0x80 }
        }
        return pixels
    }

    private static func requireRange(_ data: [UInt8], label: String, offset: Int, count: Int) throws {
        guard offset >= 0, count >= 0, offset <= data.count, count <= data.count - offset else {
            throw ClassicGraphicsError.outOfBounds(
                label: label,
                offset: offset,
                required: count,
                available: data.count
            )
        }
    }

    private static func littleEndianWord(_ data: [UInt8], at offset: Int) -> Int {
        Int(data[offset]) | (Int(data[offset + 1]) << 8)
    }
}

public struct ClassicSpecialGraphic: Codable, Equatable, Sendable {
    public let palette: [ClassicRGBColor]
    public let width: Int
    public let height: Int
    public let rgba: Data
    public let solidMask: Data

    public static func load(index: Int, from directory: URL) throws -> ClassicSpecialGraphic {
        let files = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        let filename = "vgaspec\(index).dat"
        guard let url = files.first(where: { $0.lastPathComponent.lowercased() == filename }) else {
            throw ClassicGraphicsError.missingFile(filename)
        }
        return try ClassicSpecialGraphic(archiveData: Data(contentsOf: url, options: .mappedIfSafe))
    }

    public init(archiveData: Data) throws {
        let sections = try ClassicDATArchive.decode(archiveData)
        guard sections.count == 1 else {
            throw ClassicGraphicsError.malformedSpecialGraphic("expected one compressed section, found \(sections.count)")
        }
        try self.init(uncompressedData: sections[0].data)
    }

    /// Decodes one unpacked VGASPEC payload. This entry point supports
    /// validation tools and malformed-data regression tests.
    public init(uncompressedData: Data) throws {
        let bytes = [UInt8](uncompressedData)
        guard bytes.count >= 40 else {
            throw ClassicGraphicsError.malformedSpecialGraphic("section is shorter than the 40-byte header")
        }
        palette = (0..<8).map { index in
            let offset = index * 3
            return ClassicRGBColor(
                red: classicVGAComponent(bytes[offset]),
                green: classicVGAComponent(bytes[offset + 1]),
                blue: classicVGAComponent(bytes[offset + 2])
            )
        }
        width = ClassicLevel.width
        height = ClassicLevel.height
        var outputRGBA = [UInt8](repeating: 0, count: width * height * 4)
        var outputSolid = [UInt8](repeating: 0, count: width * height)
        var position = 40
        var scanline = 0

        while position < bytes.count, scanline < height {
            var packedPlanes: [UInt8] = []
            var reachedEndMarker = false
            while position < bytes.count {
                let command = bytes[position]
                position += 1
                if command == 128 {
                    reachedEndMarker = true
                    break
                } else if command <= 127 {
                    let count = Int(command) + 1
                    guard position + count <= bytes.count else {
                        throw ClassicGraphicsError.malformedSpecialGraphic("literal PackBits run exceeds the section")
                    }
                    packedPlanes.append(contentsOf: bytes[position..<(position + count)])
                    position += count
                } else {
                    guard position < bytes.count else {
                        throw ClassicGraphicsError.malformedSpecialGraphic("repeat PackBits run has no value")
                    }
                    let count = 257 - Int(command)
                    packedPlanes.append(contentsOf: repeatElement(bytes[position], count: count))
                    position += 1
                }
            }
            guard reachedEndMarker else {
                throw ClassicGraphicsError.malformedSpecialGraphic("missing strip end marker")
            }

            let stripWidth = 960
            let stripHeight = 40
            let pixelCount = stripWidth * stripHeight
            let bytesPerPlane = pixelCount / 8
            guard packedPlanes.count == bytesPerPlane * 3 else {
                throw ClassicGraphicsError.malformedSpecialGraphic(
                    "decoded strip has \(packedPlanes.count) bytes; expected \(bytesPerPlane * 3)"
                )
            }
            var indexed = [UInt8](repeating: 0, count: pixelCount)
            for plane in 0..<3 {
                for pixel in 0..<pixelCount {
                    let byte = packedPlanes[plane * bytesPerPlane + pixel / 8]
                    indexed[pixel] |= ((byte >> UInt8(7 - pixel % 8)) & 1) << UInt8(plane)
                }
            }
            for y in 0..<min(stripHeight, height - scanline) {
                for x in 0..<stripWidth {
                    let colorIndex = Int(indexed[y * stripWidth + x])
                    guard colorIndex != 0 else { continue }
                    let destinationX = x + 304
                    let destinationY = y + scanline
                    let destination = destinationY * width + destinationX
                    let color = palette[colorIndex]
                    outputRGBA[destination * 4] = color.red
                    outputRGBA[destination * 4 + 1] = color.green
                    outputRGBA[destination * 4 + 2] = color.blue
                    outputRGBA[destination * 4 + 3] = 255
                    outputSolid[destination] = 1
                }
            }
            scanline += stripHeight
        }
        guard scanline == height else {
            throw ClassicGraphicsError.malformedSpecialGraphic("decoded \(scanline) of \(height) scanlines")
        }
        guard position == bytes.count else {
            throw ClassicGraphicsError.malformedSpecialGraphic(
                "section has \(bytes.count - position) trailing bytes after four strips"
            )
        }
        rgba = Data(outputRGBA)
        solidMask = Data(outputSolid)
    }
}

public struct ClassicPoint: Codable, Equatable, Sendable {
    public let x: Int
    public let y: Int

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }
}

public struct ClassicTriggerZone: Codable, Equatable, Sendable {
    public let effect: Int
    public let x1: Int
    public let y1: Int
    public let x2: Int
    public let y2: Int
}

public struct ClassicRenderedObject: Codable, Equatable, Sendable {
    public let placement: ClassicObjectPlacement
    public let graphic: ClassicObjectGraphic
    /// RGBA data for every animation frame, in the same order as `graphic.frames`.
    public let rgbaFrames: [Data]
}

public struct ClassicRenderedLevel: Codable, Equatable, Sendable {
    public let width: Int
    public let height: Int
    public let rgba: Data
    public let solidMask: Data
    /// Full DOS steel-protection regions. Empty protected pixels stay empty,
    /// but terrain built there becomes resistant to destructive skills.
    public let steelMask: Data
    /// Top-left spawn positions for the original 16×10 lemming sprite.
    /// Add (8, 8) to obtain the DOS gameplay foot point.
    public let entrances: [ClassicPoint]
    public let triggers: [ClassicTriggerZone]
    public let objects: [ClassicRenderedObject]
}

public enum ClassicLevelRenderer {
    public static func render(
        _ level: ClassicLevel,
        groundSet: ClassicGroundSet,
        specialGraphic: ClassicSpecialGraphic? = nil
    ) throws -> ClassicRenderedLevel {
        let width = ClassicLevel.width
        let height = ClassicLevel.height
        var rgba: [UInt8]
        var solid: [UInt8]

        if level.specialStyle != 0 {
            guard let specialGraphic else {
                throw ClassicGraphicsError.missingFile("VGASPEC\(level.specialStyle - 1).DAT")
            }
            rgba = [UInt8](specialGraphic.rgba)
            solid = [UInt8](specialGraphic.solidMask)
        } else {
            rgba = [UInt8](repeating: 0, count: width * height * 4)
            solid = [UInt8](repeating: 0, count: width * height)
            for placement in level.terrain {
                guard let graphic = groundSet.terrain[placement.id] else {
                    throw ClassicGraphicsError.invalidTerrainPiece(id: placement.id)
                }
                let pixels = [UInt8](graphic.indexedPixels)
                for sourceY in 0..<graphic.height {
                    let sampledY = placement.draw.isUpsideDown ? graphic.height - sourceY - 1 : sourceY
                    let destinationY = placement.y + sourceY
                    guard destinationY >= 0, destinationY < height else { continue }
                    for sourceX in 0..<graphic.width {
                        let pixel = pixels[sampledY * graphic.width + sourceX]
                        guard pixel & 0x80 == 0 else { continue }
                        let destinationX = placement.x + sourceX
                        guard destinationX >= 0, destinationX < width else { continue }
                        let destination = destinationY * width + destinationX
                        if placement.draw.isErase {
                            solid[destination] = 0
                            rgba[destination * 4] = 0
                            rgba[destination * 4 + 1] = 0
                            rgba[destination * 4 + 2] = 0
                            rgba[destination * 4 + 3] = 0
                        } else {
                            if placement.draw.noOverwrite, solid[destination] != 0 { continue }
                            if placement.draw.onlyOverwrite, solid[destination] == 0 { continue }
                            let color = groundSet.objectPalette[Int(pixel & 0x0F)]
                            rgba[destination * 4] = color.red
                            rgba[destination * 4 + 1] = color.green
                            rgba[destination * 4 + 2] = color.blue
                            rgba[destination * 4 + 3] = 255
                            solid[destination] = 1
                        }
                    }
                }
            }
        }

        var steel = [UInt8](repeating: 0, count: width * height)
        for area in level.steel {
            for y in area.y..<(area.y + area.height) where y >= 0 && y < height {
                for x in area.x..<(area.x + area.width) where x >= 0 && x < width {
                    let index = y * width + x
                    steel[index] = 1
                }
            }
        }

        var entrances: [ClassicPoint] = []
        var triggers: [ClassicTriggerZone] = []
        var renderedObjects: [ClassicRenderedObject] = []
        let objectPalette: [ClassicRGBColor]
        if let specialGraphic {
            objectPalette = Array(groundSet.objectPalette.prefix(7))
                + [specialGraphic.palette[0]]
                + specialGraphic.palette
        } else {
            objectPalette = groundSet.objectPalette
        }
        for placement in level.objects {
            guard let graphic = groundSet.objects[placement.id] else { continue }
            if placement.id == 1 {
                entrances.append(ClassicPoint(x: placement.x + 16, y: placement.y + 6))
            }
            // DOS renders all 32 slots, but only the first 16 populate the
            // interactive object map. Later placements are visual fakes.
            if placement.slot < 16, graphic.triggerEffect != 0 {
                let triggerBaseX = placement.x & ~3
                let triggerBaseY = placement.y & ~3
                triggers.append(ClassicTriggerZone(
                    effect: graphic.triggerEffect,
                    x1: triggerBaseX + graphic.triggerLeft,
                    y1: triggerBaseY + graphic.triggerTop,
                    x2: triggerBaseX + graphic.triggerLeft + graphic.triggerWidth,
                    y2: triggerBaseY + graphic.triggerTop + graphic.triggerHeight
                ))
            }
            let rgbaFrames = graphic.frames.map { frame in
                indexedToRGBA(frame, palette: objectPalette)
            }
            renderedObjects.append(ClassicRenderedObject(
                placement: placement,
                graphic: graphic,
                rgbaFrames: rgbaFrames
            ))
        }

        return ClassicRenderedLevel(
            width: width,
            height: height,
            rgba: Data(rgba),
            solidMask: Data(solid),
            steelMask: Data(steel),
            entrances: entrances,
            triggers: triggers,
            objects: renderedObjects
        )
    }

    private static func indexedToRGBA(_ data: Data, palette: [ClassicRGBColor]) -> Data {
        let pixels = [UInt8](data)
        var rgba = [UInt8](repeating: 0, count: pixels.count * 4)
        for (index, pixel) in pixels.enumerated() where pixel & 0x80 == 0 {
            let paletteIndex = Int(pixel & 0x0F)
            guard palette.indices.contains(paletteIndex) else { continue }
            let color = palette[paletteIndex]
            rgba[index * 4] = color.red
            rgba[index * 4 + 1] = color.green
            rgba[index * 4 + 2] = color.blue
            rgba[index * 4 + 3] = 255
        }
        return Data(rgba)
    }
}
