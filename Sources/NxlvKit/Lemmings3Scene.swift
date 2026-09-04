import Foundation

/// Static native scene assembly. Animation, collision semantics and gameplay
/// are separate from the graphics pipeline.
public struct Lemmings3Scene: Sendable {
    public let image: SequelIndexedImage
    public let background: SequelIndexedImage
    public let backgroundAttributes: [UInt16]
    /// Native 8x2-cell tags expanded to pixel coordinates. These are independent
    /// of palette colours and include background, terrain, and object events.
    public let attributes: [UInt16]

    public init(level: Lemmings3Level, style: Lemmings3Style,
                permanent: Lemmings3Objects, temporary: Lemmings3Objects) throws {
        guard level.width * level.height <= 4 * 1024 * 1024 else {
            throw SequelDataError.invalid("Chronicles scene exceeds the pixel limit.")
        }
        // Egyptian scenery includes opaque blue sky around its artwork. Use
        // the same native palette colour in gaps and behind removed terrain.
        let skyIndex: UInt8 = level.style == 3 ? 144 : 32
        var pixels = Array(repeating: skyIndex, count: level.width * level.height)
        var attributes = [UInt16](repeating: 0x1000, count: pixels.count)
        var backgroundPixels = pixels
        var backgroundAttributes = attributes
        for (layer, pair) in [(permanent, style.permanent), (temporary, style.temporary)].enumerated() {
            let (placements, bank) = pair
            for placed in placements.placements {
                if layer == 0 && placed.identifier >= 5000 { continue }
                let frame = try bank.image(object: placed.identifier, palette: style.palette)
                let tags = try bank.attributes(object: placed.identifier)
                let columns = frame.width / 8
                for y in 0..<frame.height {
                    let py = placed.y + y
                    guard py >= 0 && py < level.height else { continue }
                    for x in 0..<frame.width {
                        let px = placed.x + x
                        guard px >= 0 && px < level.width else { continue }
                        attributes[py * level.width + px] = tags[y / 2 * columns + x / 8]
                        let colour = frame.pixels[y * frame.width + x]
                        if colour != 255 { pixels[py * level.width + px] = colour }
                    }
                }
            }
            if layer == 0 { backgroundPixels = pixels; backgroundAttributes = attributes }
        }
        image = SequelIndexedImage(width: level.width, height: level.height, pixels: pixels, palette: style.palette)
        self.attributes = attributes
        background = SequelIndexedImage(width: level.width, height: level.height, pixels: backgroundPixels, palette: style.palette)
        self.backgroundAttributes = backgroundAttributes
    }
}
