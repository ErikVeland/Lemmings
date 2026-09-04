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
