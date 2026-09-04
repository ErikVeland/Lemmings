import Foundation

/// Resolves native component positions and trigger bitfields before simulation.
public struct Lemmings2Objects: Sendable {
    public struct Part: Sendable {
        public let objectIndex: Int
        public let type: Int
        public let x: Int
        public let y: Int
        public let component: Lemmings2Style.Component
        public let frames: [Lemmings2SpriteFrame]
        public let trigger: Lemmings2Runtime.Rect?
    }
    public let parts: [Part]

    public static func trigger(flags: Int, interaction: Int, x: Int, y: Int) -> Lemmings2Runtime.Rect? {
        let mode = flags & 0x18
        guard flags & 0xc000 != 0xc000,
              mode == 0x10 || (mode == 8 && (6...12).contains(interaction)) else { return nil }
        let size = (flags >> 12) & 3
        if size == 0 { return .init(x: x, y: y, width: 16, height: 8) }
        let cx = (flags >> 5) & 15, cy = (flags >> 9) & 7
        let radius = [0, 0, 2, 4][size]
        let left = max(0, cx - radius), top = max(0, cy - radius)
        return .init(x: x + left, y: y + top,
                     width: min(15, cx + radius) - left + 1,
                     height: min(7, cy + radius) - top + 1)
    }

    public init(level: Lemmings2Level, style: Lemmings2Style) throws {
        var result: [Part] = []
        var animations: [Int: [Lemmings2SpriteFrame]] = [:]
        for (index, placed) in level.objects.enumerated() where placed.identifier != 65535 {
            guard style.objects.indices.contains(placed.identifier) else {
                throw SequelDataError.invalid("Unknown native L2 object.")
            }
            let object = style.objects[placed.identifier]
            // Terrain decoding removes one 16-pixel column and two 8-pixel rows.
            // Native object coordinates include that same border.
            let originX = placed.x - 16, originY = placed.y - 16
            var previousX = originX, previousY = originY
            for (partIndex, c) in object.components.enumerated() {
                let relativeX = c.positioningFlags & 0x40 != 0
                let relativeY = c.positioningFlags & 0x80 != 0
                let x = relativeX ? previousX + (partIndex == 0 ? 0 : c.x) : originX + c.x
                let y = relativeY ? previousY + (partIndex == 0 ? 0 : c.y) : originY + c.y
                let columns = c.positioningFlags & 0x20 != 0 ? placed.parameter1 + 1 : 1
                let rows = c.positioningFlags & 0x10 != 0 ? placed.parameter2 + 1 : 1
                guard columns <= 256, rows <= 256, columns * rows <= 4096, result.count + columns * rows <= 16384 else {
                    throw SequelDataError.invalid("Native L2 object extension exceeds the safety limit.")
                }
                let frames: [Lemmings2SpriteFrame]
                if c.graphicsFlags & 0x80 != 0 { frames = [] }
                else {
                    let special = c.graphicsFlags & 0x20 != 0
                    let key = c.graphics + (special ? 256 : 0)
                    if animations[key] == nil {
                        animations[key] = try special ? style.specialAnimation(c.graphics) : style.animation(c.graphics).map {
                            Lemmings2SpriteFrame(x: 0, y: 0, width: $0.width, height: $0.height,
                                pixels: $0.pixels, opaque: $0.pixels.map { $0 != 0 })
                        }
                    }
                    frames = animations[key]!
                }
                let dx = frames.first?.width ?? 16, dy = frames.first?.height ?? 8
                for row in 0..<rows { for column in 0..<columns {
                    let px = x + column * dx, py = y + row * dy
                    result.append(Part(objectIndex: index, type: object.type, x: px, y: py,
                        component: c, frames: frames,
                        trigger: Self.trigger(flags: c.triggerFlags, interaction: c.interaction, x: px, y: py)))
                } }
                previousX = x + (columns - 1) * dx
                previousY = y + (rows - 1) * dy
            }
        }
        parts = result
    }
}
