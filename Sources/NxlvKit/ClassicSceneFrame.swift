import Foundation

/// Combines the current terrain mask with the original animated objects.
/// Collision triggers are independent from this visual composition.
public enum ClassicSceneFrame {
    public static func rgba(_ level: ClassicRenderedLevel, simulation: ClassicDOSSimulation) -> Data {
        let solid = [UInt8](simulation.terrain.solidMask)
        let original = [UInt8](level.solidMask)
        var pixels = [UInt8](level.rgba)
        guard solid.count == original.count, pixels.count == solid.count * 4 else { return level.rgba }
        for index in solid.indices {
            let offset = index * 4
            if solid[index] == 0 && original[index] != 0 {
                pixels[offset] = 0; pixels[offset + 1] = 0; pixels[offset + 2] = 0; pixels[offset + 3] = 0
            } else if solid[index] != 0 && original[index] == 0 {
                // Construction pixels have no source texture.
                pixels[offset] = 240; pixels[offset + 1] = 208; pixels[offset + 2] = 96; pixels[offset + 3] = 255
            }
        }
        var triggerIndex = 0
        for object in level.objects {
            let graphic = object.graphic
            let placement = object.placement
            let interactive = placement.slot < 16 && graphic.triggerEffect != 0
            let cooldown = interactive ? simulation.objectCooldown(at: triggerIndex) : 0
            if interactive { triggerIndex += 1 }
            guard !object.rgbaFrames.isEmpty else { continue }
            let first = min(max(0, graphic.firstFrameIndex), object.rgbaFrames.count - 1)
            let frame: Int
            switch graphic.animationType {
            case .none: frame = first
            case .continuous: frame = (first + simulation.tickCount) % object.rgbaFrames.count
            case .onceAtStart:
                let elapsed = max(0, simulation.tickCount - ClassicDOSRules.entranceOpenTick)
                frame = min(first + elapsed, object.rgbaFrames.count - 1)
            case .triggered:
                frame = cooldown > 0 ? min(object.rgbaFrames.count - cooldown, object.rgbaFrames.count - 1) : first
            }
            let source = [UInt8](object.rgbaFrames[max(0, frame)])
            if graphic.triggerEffect == ClassicDOSObjectEffect.water.rawValue,
               !placement.draw.isUpsideDown, !placement.draw.onlyOverwrite {
                ClassicLiquidFill.draw(source: source, sourceWidth: graphic.width,
                    sourceHeight: graphic.height, x: placement.x, y: placement.y,
                    into: &pixels, width: level.width, height: level.height,
                    solid: solid, scale: 1)
            }
            for y in 0..<graphic.height {
                let targetY = placement.y + y
                guard (0..<level.height).contains(targetY) else { continue }
                let sourceY = placement.draw.isUpsideDown ? graphic.height - 1 - y : y
                for x in 0..<graphic.width {
                    let targetX = placement.x + x
                    guard (0..<level.width).contains(targetX) else { continue }
                    let src = (sourceY * graphic.width + x) * 4
                    guard source[src + 3] != 0 else { continue }
                    let index = targetY * level.width + targetX
                    if placement.draw.noOverwrite && solid[index] != 0 { continue }
                    if placement.draw.onlyOverwrite && solid[index] == 0 { continue }
                    let dst = index * 4
                    pixels[dst] = source[src]; pixels[dst + 1] = source[src + 1]
                    pixels[dst + 2] = source[src + 2]; pixels[dst + 3] = source[src + 3]
                }
            }
        }
        return Data(pixels)
    }
}

/// Extends the liquid body behind terrain without changing collision masks.
enum ClassicLiquidFill {
    static func draw(source: [UInt8], sourceWidth: Int, sourceHeight: Int,
        x: Int, y: Int, into pixels: inout [UInt8], width: Int, height: Int,
        solid: [UInt8], scale: Int) {
        guard sourceWidth > 0, sourceHeight > 0,
              source.count == sourceWidth * sourceHeight * 4 else { return }
        // Use the dominant colour in the lowest opaque row, below the wave highlights.
        var bottom = sourceHeight - 1
        var colours: [UInt32: Int] = [:]
        while bottom >= 0 {
            for column in 0..<sourceWidth {
                let p = (bottom * sourceWidth + column) * 4
                guard source[p + 3] == 255 else { continue }
                let colour = UInt32(source[p]) << 16 | UInt32(source[p + 1]) << 8 | UInt32(source[p + 2])
                colours[colour, default: 0] += 1
            }
            if !colours.isEmpty { break }
            bottom -= 1
        }
        guard let colour = colours.keys.sorted().max(by: { colours[$0]! < colours[$1]! }) else { return }
        let left = max(0, x), right = min(width, x + sourceWidth)
        let top = max(0, y + bottom + 1)
        guard left < right, top < height else { return }
        for column in left..<right {
            for row in max(0, y)..<height {
                let p = (row * width + column) * 4
                // A pool ends at its floor, including newly built terrain.
                if solid[(row / scale) * (width / scale) + column / scale] != 0 { break }
                guard row >= top, pixels[p + 3] == 0 else { continue }
                pixels[p] = UInt8((colour >> 16) & 255)
                pixels[p + 1] = UInt8((colour >> 8) & 255)
                pixels[p + 2] = UInt8(colour & 255)
                pixels[p + 3] = 255
            }
        }
    }
}
