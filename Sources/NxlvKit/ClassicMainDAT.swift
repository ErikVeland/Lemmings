import Foundation

private func classicMainVGAComponent(_ value: UInt8) -> UInt8 {
    let sixBitValue = UInt16(value & 0x3F)
    return UInt8((sixBitValue * 255 + 31) / 63)
}

/// The facing direction encoded for one DOS lemming animation.
public enum ClassicSpriteDirection: String, Codable, CaseIterable, Sendable {
    case right
    case left
    /// The DOS data stores one frame sequence for both directions.
    case none
}

/// A gameplay sprite sequence in decompressed `MAIN.DAT` section 0.
public enum ClassicLemmingPose: String, Codable, CaseIterable, Sendable {
    case walking
    case jumping
    case digging
    case climbing
    case postClimb
    case drowning
    case building
    case bashing
    case mining
    case falling
    case umbrellaOpening
    case floating
    case splatting
    case exiting
    case frying
    case blocking
    case shrugging
    case ohNo
    case explosion
}

public enum ClassicMainDATError: Error, Equatable, CustomStringConvertible {
    case missingFile(String)
    case insufficientSectionCount(minimum: Int, actual: Int)
    case invalidBitmapSize(label: String, width: Int, height: Int)
    case invalidBitsPerPixel(label: String, actual: Int)
    case outOfBounds(section: Int, label: String, offset: Int, required: Int, available: Int)
    case paletteTooSmall(label: String, required: Int, actual: Int)
    case invalidTerrainPaletteSize(actual: Int)

    public var description: String {
        switch self {
        case let .missingFile(file):
            return "Required classic asset file is missing: \(file)."
        case let .insufficientSectionCount(minimum, actual):
            return "MAIN.DAT must contain at least \(minimum) sections; found \(actual)."
        case let .invalidBitmapSize(label, width, height):
            return "\(label) has invalid size \(width)x\(height)."
        case let .invalidBitsPerPixel(label, actual):
            return "\(label) has unsupported \(actual)-bit planar pixels."
        case let .outOfBounds(section, label, offset, required, available):
            return "MAIN.DAT section \(section) \(label) reads \(required) bytes at \(offset), beyond \(available) available bytes."
        case let .paletteTooSmall(label, required, actual):
            return "\(label) needs \(required) palette colors; found \(actual)."
        case let .invalidTerrainPaletteSize(actual):
            return "A DOS terrain palette must contain eight colors; found \(actual)."
        }
    }
}

/// One decoded planar image. Bit 7 in `indexedPixels` marks a transparent
/// pixel. The low nibble contains the DOS palette index.
public struct ClassicIndexedBitmap: Codable, Equatable, Sendable {
    public let width: Int
    public let height: Int
    public let indexedPixels: Data

    /// One byte per pixel. A value of 1 is opaque and 0 is transparent.
    public var opaqueMask: Data {
        Data(indexedPixels.map { $0 & 0x80 == 0 ? UInt8(1) : UInt8(0) })
    }

    public func paletteIndex(x: Int, y: Int) -> Int? {
        guard x >= 0, y >= 0, x < width, y < height else { return nil }
        let value = indexedPixels[indexedPixels.startIndex + y * width + x]
        guard value & 0x80 == 0 else { return nil }
        return Int(value & 0x0F)
    }

    /// Converts the indexed image to straight-alpha RGBA without changing
    /// its original pixels. Callers can supply the current level palette so
    /// that style-dependent colors, including the frying animation, match.
    public func rgba(using palette: [ClassicRGBColor]) throws -> Data {
        var requiredColorCount = 0
        for pixel in indexedPixels where pixel & 0x80 == 0 {
            requiredColorCount = max(requiredColorCount, Int(pixel & 0x0F) + 1)
        }
        guard palette.count >= requiredColorCount else {
            throw ClassicMainDATError.paletteTooSmall(
                label: "classic sprite",
                required: requiredColorCount,
                actual: palette.count
            )
        }

        var output = [UInt8](repeating: 0, count: indexedPixels.count * 4)
        for (index, pixel) in indexedPixels.enumerated() where pixel & 0x80 == 0 {
            let color = palette[Int(pixel & 0x0F)]
            output[index * 4] = color.red
            output[index * 4 + 1] = color.green
            output[index * 4 + 2] = color.blue
            output[index * 4 + 3] = 255
        }
        return Data(output)
    }
}

/// One animation and its draw offset relative to the lemming gameplay point.
public struct ClassicLemmingAnimation: Codable, Equatable, Sendable {
    public let pose: ClassicLemmingPose
    public let direction: ClassicSpriteDirection
    public let offsetX: Int
    public let offsetY: Int
    public let sourceOffset: Int
    public let bitsPerPixel: Int
    public let frames: [ClassicIndexedBitmap]
}

/// A decoded one-bit bitmap from `MAIN.DAT` section 1.
public struct ClassicMonochromeBitmap: Codable, Equatable, Sendable {
    public let width: Int
    public let height: Int
    /// The draw offset relative to the lemming gameplay point.
    public let offsetX: Int
    public let offsetY: Int
    /// One byte per pixel. A value of 1 means that the source bit is set.
    public let bits: Data

    public func isSet(x: Int, y: Int) -> Bool {
        guard x >= 0, y >= 0, x < width, y < height else { return false }
        return bits[bits.startIndex + y * width + x] != 0
    }
}

/// The terrain-removal masks used by classic bashers, miners, and bombers.
public struct ClassicDestructionMasks: Codable, Equatable, Sendable {
    public let bashRight: [ClassicMonochromeBitmap]
    public let bashLeft: [ClassicMonochromeBitmap]
    public let mineRight: [ClassicMonochromeBitmap]
    public let mineLeft: [ClassicMonochromeBitmap]
    public let explosion: ClassicMonochromeBitmap
}

public struct ClassicCountdownGlyph: Codable, Equatable, Sendable {
    public let digit: Int
    public let bitmap: ClassicMonochromeBitmap
}

/// Constructs the in-level palette that DOS `MAIN.DAT` sprites use. The
/// first seven colors are fixed. The selected ground style supplies the
/// remaining colors.
public enum ClassicLemmingPalette {
    public static let fixedVGAColors: [ClassicRGBColor] = [
        ClassicRGBColor(red: 0, green: 0, blue: 0),
        ClassicRGBColor(red: classicMainVGAComponent(16), green: classicMainVGAComponent(16), blue: classicMainVGAComponent(56)),
        ClassicRGBColor(red: 0, green: classicMainVGAComponent(44), blue: 0),
        ClassicRGBColor(red: classicMainVGAComponent(60), green: classicMainVGAComponent(52), blue: classicMainVGAComponent(52)),
        ClassicRGBColor(red: classicMainVGAComponent(60), green: classicMainVGAComponent(60), blue: 0),
        ClassicRGBColor(red: classicMainVGAComponent(60), green: classicMainVGAComponent(8), blue: classicMainVGAComponent(8)),
        ClassicRGBColor(red: classicMainVGAComponent(32), green: classicMainVGAComponent(32), blue: classicMainVGAComponent(32)),
    ]

    /// Returns palette indices 0...15 for the selected DOS ground style.
    public static func inLevelVGA(terrainPalette: [ClassicRGBColor]) throws -> [ClassicRGBColor] {
        guard terrainPalette.count == 8 else {
            throw ClassicMainDATError.invalidTerrainPaletteSize(actual: terrainPalette.count)
        }
        return fixedVGAColors + [terrainPalette[0]] + terrainPalette
    }
}

/// Imported gameplay assets from the user's DOS `MAIN.DAT`. This decoder
/// does not include or write any original game data.
public struct ClassicMainDATAssets: Codable, Equatable, Sendable {
    public let animations: [ClassicLemmingAnimation]
    public let destructionMasks: ClassicDestructionMasks
    /// The source stores these glyphs in descending order from 9 to 0.
    public let countdownGlyphs: [ClassicCountdownGlyph]
    public let sectionSizes: [Int]

    public var totalSpriteFrameCount: Int {
        animations.reduce(0) { $0 + $1.frames.count }
    }

    /// Sections 2...6 contain panels, fonts, menu graphics, or unknown data.
    /// Their indices are reported so clients do not mistake this gameplay
    /// decoder for a complete menu-asset decoder.
    public var unsupportedSectionIndices: [Int] {
        Array(sectionSizes.indices.dropFirst(2))
    }

    public func animation(
        for pose: ClassicLemmingPose,
        direction: ClassicSpriteDirection
    ) -> ClassicLemmingAnimation? {
        animations.first { $0.pose == pose && $0.direction == direction }
    }

    /// Loads `MAIN.DAT` case-insensitively from a user-selected DOS data
    /// directory. The method never copies the source file.
    public static func load(from directory: URL) throws -> ClassicMainDATAssets {
        let files = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        guard let url = files.first(where: { $0.lastPathComponent.lowercased() == "main.dat" }) else {
            throw ClassicMainDATError.missingFile("MAIN.DAT")
        }
        return try ClassicMainDATAssets(
            archiveData: Data(contentsOf: url, options: .mappedIfSafe)
        )
    }

    public init(archiveData: Data) throws {
        let sections = try ClassicDATArchive.decode(archiveData)
        try self.init(decompressedSections: sections.map(\.data))
    }

    /// Decodes already-unpacked sections. This entry point supports format
    /// diagnostics and malformed-data regression tests.
    public init(decompressedSections: [Data]) throws {
        guard decompressedSections.count >= 2 else {
            throw ClassicMainDATError.insufficientSectionCount(
                minimum: 2,
                actual: decompressedSections.count
            )
        }

        sectionSizes = decompressedSections.map(\.count)
        let section0 = [UInt8](decompressedSections[0])
        let section1 = [UInt8](decompressedSections[1])

        animations = try Self.animationDescriptors.map { descriptor in
            ClassicLemmingAnimation(
                pose: descriptor.pose,
                direction: descriptor.direction,
                offsetX: descriptor.offsetX,
                offsetY: descriptor.offsetY,
                sourceOffset: descriptor.sourceOffset,
                bitsPerPixel: descriptor.bitsPerPixel,
                frames: try Self.decodePlanarFrames(
                    section0,
                    section: 0,
                    label: "\(descriptor.pose.rawValue) \(descriptor.direction.rawValue)",
                    sourceOffset: descriptor.sourceOffset,
                    frameCount: descriptor.frameCount,
                    width: descriptor.width,
                    height: descriptor.height,
                    bitsPerPixel: descriptor.bitsPerPixel
                )
            )
        }

        let bashRight = try Self.decodeMonochromeFrames(
            section1, section: 1, label: "right bash masks", sourceOffset: 0x0000,
            frameCount: 4, width: 16, height: 10, offsetX: -8, offsetY: -10
        )
        let bashLeft = try Self.decodeMonochromeFrames(
            section1, section: 1, label: "left bash masks", sourceOffset: 0x0050,
            frameCount: 4, width: 16, height: 10, offsetX: -8, offsetY: -10
        )
        let mineRight = try Self.decodeMonochromeFrames(
            section1, section: 1, label: "right mine masks", sourceOffset: 0x00A0,
            frameCount: 2, width: 16, height: 13, offsetX: -8, offsetY: -12
        )
        let mineLeft = try Self.decodeMonochromeFrames(
            section1, section: 1, label: "left mine masks", sourceOffset: 0x00D4,
            frameCount: 2, width: 16, height: 13, offsetX: -8, offsetY: -12
        )
        let explosion = try Self.decodeMonochromeFrames(
            section1, section: 1, label: "explosion mask", sourceOffset: 0x0108,
            frameCount: 1, width: 16, height: 22, offsetX: -8, offsetY: -14
        )[0]
        destructionMasks = ClassicDestructionMasks(
            bashRight: bashRight,
            bashLeft: bashLeft,
            mineRight: mineRight,
            mineLeft: mineLeft,
            explosion: explosion
        )

        let storedGlyphs = try Self.decodeMonochromeFrames(
            section1, section: 1, label: "countdown glyphs", sourceOffset: 0x0134,
            frameCount: 10, width: 8, height: 8, offsetX: -1, offsetY: -19
        )
        countdownGlyphs = storedGlyphs.enumerated().map { index, bitmap in
            ClassicCountdownGlyph(digit: 9 - index, bitmap: bitmap)
        }
    }

    private struct AnimationDescriptor {
        let pose: ClassicLemmingPose
        let direction: ClassicSpriteDirection
        let sourceOffset: Int
        let frameCount: Int
        let width: Int
        let height: Int
        let bitsPerPixel: Int
        let offsetX: Int
        let offsetY: Int
    }

    /// The byte order and geometry follow the original DOS loader layout.
    private static let animationDescriptors: [AnimationDescriptor] = [
        AnimationDescriptor(pose: .walking, direction: .right, sourceOffset: 0x0000, frameCount: 8, width: 16, height: 10, bitsPerPixel: 2, offsetX: -8, offsetY: -10),
        AnimationDescriptor(pose: .jumping, direction: .right, sourceOffset: 0x0140, frameCount: 1, width: 16, height: 10, bitsPerPixel: 2, offsetX: -8, offsetY: -10),
        AnimationDescriptor(pose: .walking, direction: .left, sourceOffset: 0x0168, frameCount: 8, width: 16, height: 10, bitsPerPixel: 2, offsetX: -8, offsetY: -10),
        AnimationDescriptor(pose: .jumping, direction: .left, sourceOffset: 0x02A8, frameCount: 1, width: 16, height: 10, bitsPerPixel: 2, offsetX: -8, offsetY: -10),
        AnimationDescriptor(pose: .digging, direction: .none, sourceOffset: 0x02D0, frameCount: 16, width: 16, height: 14, bitsPerPixel: 3, offsetX: -8, offsetY: -12),
        AnimationDescriptor(pose: .climbing, direction: .right, sourceOffset: 0x0810, frameCount: 8, width: 16, height: 12, bitsPerPixel: 2, offsetX: -8, offsetY: -12),
        AnimationDescriptor(pose: .climbing, direction: .left, sourceOffset: 0x0990, frameCount: 8, width: 16, height: 12, bitsPerPixel: 2, offsetX: -8, offsetY: -12),
        AnimationDescriptor(pose: .drowning, direction: .none, sourceOffset: 0x0B10, frameCount: 16, width: 16, height: 10, bitsPerPixel: 2, offsetX: -8, offsetY: -10),
        AnimationDescriptor(pose: .postClimb, direction: .right, sourceOffset: 0x0D90, frameCount: 8, width: 16, height: 12, bitsPerPixel: 2, offsetX: -8, offsetY: -12),
        AnimationDescriptor(pose: .postClimb, direction: .left, sourceOffset: 0x0F10, frameCount: 8, width: 16, height: 12, bitsPerPixel: 2, offsetX: -8, offsetY: -12),
        AnimationDescriptor(pose: .building, direction: .right, sourceOffset: 0x1090, frameCount: 16, width: 16, height: 13, bitsPerPixel: 3, offsetX: -8, offsetY: -13),
        AnimationDescriptor(pose: .building, direction: .left, sourceOffset: 0x1570, frameCount: 16, width: 16, height: 13, bitsPerPixel: 3, offsetX: -8, offsetY: -13),
        AnimationDescriptor(pose: .bashing, direction: .right, sourceOffset: 0x1A50, frameCount: 32, width: 16, height: 10, bitsPerPixel: 3, offsetX: -8, offsetY: -10),
        AnimationDescriptor(pose: .bashing, direction: .left, sourceOffset: 0x21D0, frameCount: 32, width: 16, height: 10, bitsPerPixel: 3, offsetX: -8, offsetY: -10),
        AnimationDescriptor(pose: .mining, direction: .right, sourceOffset: 0x2950, frameCount: 24, width: 16, height: 13, bitsPerPixel: 3, offsetX: -8, offsetY: -12),
        AnimationDescriptor(pose: .mining, direction: .left, sourceOffset: 0x30A0, frameCount: 24, width: 16, height: 13, bitsPerPixel: 3, offsetX: -8, offsetY: -12),
        AnimationDescriptor(pose: .falling, direction: .right, sourceOffset: 0x37F0, frameCount: 4, width: 16, height: 10, bitsPerPixel: 2, offsetX: -8, offsetY: -10),
        AnimationDescriptor(pose: .falling, direction: .left, sourceOffset: 0x3890, frameCount: 4, width: 16, height: 10, bitsPerPixel: 2, offsetX: -8, offsetY: -10),
        AnimationDescriptor(pose: .umbrellaOpening, direction: .right, sourceOffset: 0x3930, frameCount: 4, width: 16, height: 16, bitsPerPixel: 3, offsetX: -8, offsetY: -16),
        AnimationDescriptor(pose: .floating, direction: .right, sourceOffset: 0x3AB0, frameCount: 4, width: 16, height: 16, bitsPerPixel: 3, offsetX: -8, offsetY: -16),
        AnimationDescriptor(pose: .umbrellaOpening, direction: .left, sourceOffset: 0x3C30, frameCount: 4, width: 16, height: 16, bitsPerPixel: 3, offsetX: -8, offsetY: -16),
        AnimationDescriptor(pose: .floating, direction: .left, sourceOffset: 0x3DB0, frameCount: 4, width: 16, height: 16, bitsPerPixel: 3, offsetX: -8, offsetY: -16),
        AnimationDescriptor(pose: .splatting, direction: .none, sourceOffset: 0x3F30, frameCount: 16, width: 16, height: 10, bitsPerPixel: 2, offsetX: -8, offsetY: -10),
        AnimationDescriptor(pose: .exiting, direction: .none, sourceOffset: 0x41B0, frameCount: 8, width: 16, height: 13, bitsPerPixel: 2, offsetX: -8, offsetY: -13),
        AnimationDescriptor(pose: .frying, direction: .none, sourceOffset: 0x4350, frameCount: 14, width: 16, height: 14, bitsPerPixel: 4, offsetX: -8, offsetY: -10),
        AnimationDescriptor(pose: .blocking, direction: .none, sourceOffset: 0x4970, frameCount: 16, width: 16, height: 10, bitsPerPixel: 2, offsetX: -8, offsetY: -10),
        AnimationDescriptor(pose: .shrugging, direction: .right, sourceOffset: 0x4BF0, frameCount: 8, width: 16, height: 10, bitsPerPixel: 2, offsetX: -8, offsetY: -10),
        AnimationDescriptor(pose: .shrugging, direction: .left, sourceOffset: 0x4D30, frameCount: 8, width: 16, height: 10, bitsPerPixel: 2, offsetX: -8, offsetY: -10),
        AnimationDescriptor(pose: .ohNo, direction: .none, sourceOffset: 0x4E70, frameCount: 16, width: 16, height: 10, bitsPerPixel: 2, offsetX: -8, offsetY: -10),
        AnimationDescriptor(pose: .explosion, direction: .none, sourceOffset: 0x50F0, frameCount: 1, width: 32, height: 32, bitsPerPixel: 3, offsetX: -8, offsetY: -10),
    ]

    private static func decodePlanarFrames(
        _ data: [UInt8],
        section: Int,
        label: String,
        sourceOffset: Int,
        frameCount: Int,
        width: Int,
        height: Int,
        bitsPerPixel: Int
    ) throws -> [ClassicIndexedBitmap] {
        let pixelCount = try checkedPixelCount(label: label, width: width, height: height)
        guard (1...4).contains(bitsPerPixel) else {
            throw ClassicMainDATError.invalidBitsPerPixel(label: label, actual: bitsPerPixel)
        }
        let bytesPerPlane = (pixelCount + 7) / 8
        let (bytesPerFrame, frameOverflow) = bytesPerPlane.multipliedReportingOverflow(by: bitsPerPixel)
        let (required, countOverflow) = bytesPerFrame.multipliedReportingOverflow(by: frameCount)
        guard !frameOverflow, !countOverflow else {
            throw ClassicMainDATError.invalidBitmapSize(label: label, width: width, height: height)
        }
        try requireRange(
            data,
            section: section,
            label: label,
            offset: sourceOffset,
            count: required
        )

        return (0..<frameCount).map { frameIndex in
            let frameOffset = sourceOffset + frameIndex * bytesPerFrame
            var pixels = [UInt8](repeating: 0, count: pixelCount)
            for plane in 0..<bitsPerPixel {
                let planeOffset = frameOffset + plane * bytesPerPlane
                for pixel in 0..<pixelCount {
                    let byte = data[planeOffset + pixel / 8]
                    let bit = (byte >> UInt8(7 - pixel % 8)) & 1
                    pixels[pixel] |= bit << UInt8(plane)
                }
            }
            for pixel in pixels.indices where pixels[pixel] == 0 {
                pixels[pixel] |= 0x80
            }
            return ClassicIndexedBitmap(
                width: width,
                height: height,
                indexedPixels: Data(pixels)
            )
        }
    }

    private static func decodeMonochromeFrames(
        _ data: [UInt8],
        section: Int,
        label: String,
        sourceOffset: Int,
        frameCount: Int,
        width: Int,
        height: Int,
        offsetX: Int,
        offsetY: Int
    ) throws -> [ClassicMonochromeBitmap] {
        let pixelCount = try checkedPixelCount(label: label, width: width, height: height)
        let bytesPerFrame = (pixelCount + 7) / 8
        let (required, overflow) = bytesPerFrame.multipliedReportingOverflow(by: frameCount)
        guard !overflow else {
            throw ClassicMainDATError.invalidBitmapSize(label: label, width: width, height: height)
        }
        try requireRange(
            data,
            section: section,
            label: label,
            offset: sourceOffset,
            count: required
        )

        return (0..<frameCount).map { frameIndex in
            let frameOffset = sourceOffset + frameIndex * bytesPerFrame
            var bits = [UInt8](repeating: 0, count: pixelCount)
            for pixel in 0..<pixelCount {
                let byte = data[frameOffset + pixel / 8]
                bits[pixel] = (byte >> UInt8(7 - pixel % 8)) & 1
            }
            return ClassicMonochromeBitmap(
                width: width,
                height: height,
                offsetX: offsetX,
                offsetY: offsetY,
                bits: Data(bits)
            )
        }
    }

    private static func checkedPixelCount(label: String, width: Int, height: Int) throws -> Int {
        guard width > 0, height > 0 else {
            throw ClassicMainDATError.invalidBitmapSize(label: label, width: width, height: height)
        }
        let (pixelCount, overflow) = width.multipliedReportingOverflow(by: height)
        guard !overflow else {
            throw ClassicMainDATError.invalidBitmapSize(label: label, width: width, height: height)
        }
        return pixelCount
    }

    private static func requireRange(
        _ data: [UInt8],
        section: Int,
        label: String,
        offset: Int,
        count: Int
    ) throws {
        guard offset >= 0, count >= 0, offset <= data.count, count <= data.count - offset else {
            throw ClassicMainDATError.outOfBounds(
                section: section,
                label: label,
                offset: offset,
                required: count,
                available: data.count
            )
        }
    }
}
