import Foundation
import NxlvKit

/**
 * Composites native L2 terrain, object and lemming pixels for the mobile view.
 */
public struct Lemmings2MobileSceneRenderer: Sendable {
    private let terrainCache = MobileIndexedTerrainCache()
    private let ghostCache = MobileGhostSpriteCache()
    private let objects: Lemmings2Objects
    private let animations: [String: [Lemmings2SpriteFrame]]
    private let walker: Lemmings2Walker?
    private let explosion: Lemmings2Explosion?

    /**
     * Creates a renderer for one decoded native level and its art banks.
     */
    public init(level: Lemmings2Level, style: Lemmings2Style,
                sprites: Lemmings2Sprites, intern: Lemmings2SpecialGraphics? = nil,
                walker: Lemmings2Walker? = nil, explosion: Lemmings2Explosion? = nil) throws {
        objects = try Lemmings2Objects(level: level, style: style)
        var animations = sprites.animations
        if let intern {
            for (name, index) in [("LASER", 16), ("FLAME", 17), ("ROCKET", 8), ("JET", 22),
                                  ("STONE", 7), ("SPEAR", 6), ("ARROW", 2), ("CHAIN", 5),
                                  ("HOOK", 11), ("SMOKE", 21), ("EXPLOSION", 10),
                                  ("COUNTDOWN", 15), ("BALLOON", 0), ("PARACHUTE", 19)] {
                animations[name] = try intern.animation(index)
            }
        }
        self.animations = animations
        self.walker = walker
        self.explosion = explosion
    }

    /**
     * Returns the current native playfield as an unscaled RGBA frame.
     */
    public func render(_ runtime: Lemmings2Runtime,
                       highlight: MobileTargetSelection? = nil,
                       ghosts: [MobileReplayGhost<Lemmings2Runtime>] = []) throws -> MobilePixelFrame {
        let width = runtime.configuration.width
        let height = runtime.configuration.height
        guard width > 0, height > 0, width <= Int.max / height,
              runtime.pixels.count == width * height,
              runtime.configuration.palette.count >= 128 * 4 else {
            throw MobileSessionError.invalidFrame
        }

        var rgba = terrainCache.frame(pixels: runtime.pixels, palette: runtime.configuration.palette)
        for part in objects.parts where !part.frames.isEmpty {
            let machine = runtime.machines.first(where: { $0.id == part.objectIndex })
            let movement = machine?.displacement ?? 0
            let frameIndex = machine?.frame ?? runtime.objectFrames[part.objectIndex]
                ?? (part.type == 2 ? min(part.frames.count - 1, max(0, runtime.tick - 20))
                    : part.component.graphicsFlags & 0x10 != 0 ? runtime.tick / 2 : 0)
            let frame = part.frames[(frameIndex % part.frames.count + part.frames.count) % part.frames.count]
            Self.composite(frame, palette: runtime.configuration.palette,
                           atX: part.x + movement, y: part.y, width: width, height: height, into: &rgba)
        }

        if let flash = animations["EXPLOSION"]?.first {
            for point in runtime.blastFlashes {
                Self.composite(flash, palette: runtime.configuration.palette,
                               atX: point.x + flash.x, y: point.y + flash.y,
                               width: width, height: height, into: &rgba)
            }
        }

        for projectile in runtime.projectiles {
            let name: String
            let offset: Int
            switch projectile.kind {
            case .arrow: name = "ARROW"; offset = 7
            case .stone: name = "STONE"; offset = 0
            case .spear: name = "SPEAR"; offset = 7
            case .bazooka, .mortar: name = "ROCKET"; offset = 1
            }
            if let frames = animations[name], frames.indices.contains(projectile.frame) {
                let frame = frames[projectile.frame]
                Self.composite(frame, palette: runtime.configuration.palette,
                               atX: projectile.x - offset + frame.x,
                               y: projectile.y - offset + frame.y,
                               width: width, height: height, into: &rgba)
            }
        }

        drawGhosts(ghosts, palette: runtime.configuration.palette, width: width, height: height, into: &rgba)

        for lemming in runtime.lemmings where lemming.active && lemming.state != .trapped {
            if lemming.state == .exploding, lemming.age >= 17,
               let frames = explosion?.frames, frames.indices.contains(lemming.age - 17) {
                for point in frames[lemming.age - 17] {
                    Self.draw(point.colour, palette: runtime.configuration.palette,
                              atX: lemming.x + point.x, y: lemming.y + point.y,
                              width: width, height: height, into: &rgba)
                }
                continue
            }
            if lemming.state == .walking, let walker {
                let phase = Lemmings2Walker.phase(x: lemming.x, direction: lemming.direction)
                let frame = walker.frames[phase]
                Self.composite(frame, palette: runtime.configuration.palette,
                               atX: lemming.x - 2 + frame.x, y: lemming.y - 10 + frame.y,
                               width: width, height: height, into: &rgba)
                if let ticks = lemming.bombTicks,
                   let numbers = animations["COUNTDOWN"], numbers.indices.contains(ticks >> 4) {
                    let number = numbers[ticks >> 4]
                    Self.composite(number, palette: runtime.configuration.palette,
                                   atX: lemming.x - 8 + number.x,
                                   y: lemming.y - 17 + number.y,
                                   width: width, height: height, into: &rgba)
                }
                if highlight?.id == lemming.id {
                    Self.drawSelection(aroundX: lemming.x, y: lemming.y,
                                       width: width, height: height, into: &rgba)
                }
                continue
            }
            guard let pose = sprite(for: lemming, tribe: runtime.configuration.tribe),
                  let frames = animations[pose.name], !frames.isEmpty else { continue }
            let frame = frames[pose.phase % frames.count]
            Self.composite(frame, palette: runtime.configuration.palette,
                           atX: lemming.x + pose.offsetX + frame.x,
                           y: lemming.y + pose.offsetY + frame.y,
                           width: width, height: height, mirrored: pose.mirrored, into: &rgba)

            if let held = lemming.heldProjectile,
               let frames = animations[held.kind == .spear ? "SPEAR" : "STONE"],
               frames.indices.contains(held.frame) {
                let projectile = frames[held.frame]
                let offset = held.kind == .spear ? 7 : 0
                Self.composite(projectile, palette: runtime.configuration.palette,
                               atX: held.x - offset + projectile.x,
                               y: held.y - offset + projectile.y,
                               width: width, height: height, into: &rgba)
            }
            drawEquipment(for: lemming, width: width, height: height, palette: runtime.configuration.palette,
                          into: &rgba)
            if let ticks = lemming.bombTicks,
               let frames = animations["COUNTDOWN"], frames.indices.contains(ticks >> 4) {
                let number = frames[ticks >> 4]
                Self.composite(number, palette: runtime.configuration.palette,
                               atX: lemming.x - 8 + number.x,
                               y: lemming.y + pose.offsetY - 7 + number.y,
                               width: width, height: height, into: &rgba)
            }
            if highlight?.id == lemming.id {
                Self.drawSelection(aroundX: lemming.x, y: lemming.y, width: width, height: height, into: &rgba)
            }
        }
        return try MobilePixelFrame(width: width, height: height, rgba: Data(rgba))
    }

    private func drawEquipment(for lemming: Lemmings2Runtime.Lemming,
                               width: Int, height: Int, palette: [UInt8], into rgba: inout [UInt8]) {
        let name: String
        let x: Int
        let y: Int
        let phase: Int
        switch lemming.state {
        case .jetPacking:
            name = "JET"; x = lemming.x - 7; y = lemming.y - 2; phase = lemming.age
        case .parachuting:
            name = "PARACHUTE"; x = lemming.x - 8; y = lemming.y - 17; phase = lemming.age
        case .ballooning:
            name = "BALLOON"; x = lemming.x - 7; y = lemming.y - min(32, 25 + lemming.age); phase = lemming.age
        case .lasering where lemming.work >= 0:
            name = "LASER"; x = lemming.x - 8; y = lemming.y - 17; phase = lemming.age
        case .flaming:
            name = "FLAME"; x = lemming.x - (lemming.direction < 0 ? 32 : 0); y = lemming.y - 12
            phase = lemming.age % 4 + (lemming.direction < 0 ? 4 : 0)
        default: return
        }
        guard let frames = animations[name], !frames.isEmpty else { return }
        let frame = frames[phase % frames.count]
        if name == "LASER" {
            for segment in 0...lemming.work {
                Self.composite(frame, palette: palette, atX: x + frame.x,
                               y: y - segment * 8 + frame.y,
                               width: width, height: height, into: &rgba)
            }
        } else {
            Self.composite(frame, palette: palette, atX: x + frame.x, y: y + frame.y,
                           width: width, height: height, into: &rgba)
        }
    }

    /// Ghosts show the primary lemming sprite only, as on Mac. Equipment and particles stay live-only.
    private func drawGhosts(_ ghosts: [MobileReplayGhost<Lemmings2Runtime>], palette: [UInt8],
                            width: Int, height: Int, into rgba: inout [UInt8]) {
        for ghost in ghosts {
            for lemming in ghost.state.lemmings where lemming.active && lemming.state != .trapped
                && !(lemming.state == .exploding && lemming.age >= 17) {
                let frame: Lemmings2SpriteFrame, x: Int, y: Int, mirrored: Bool, key: String
                if lemming.state == .walking, let walker {
                    let phase = Lemmings2Walker.phase(x: lemming.x, direction: lemming.direction)
                    frame = walker.frames[phase]
                    x = lemming.x - 2 + frame.x; y = lemming.y - 10 + frame.y
                    mirrored = false; key = "walker-\(phase)"
                } else {
                    guard let pose = sprite(for: lemming, tribe: ghost.state.configuration.tribe),
                          let frames = animations[pose.name], !frames.isEmpty else { continue }
                    let index = pose.phase % frames.count
                    frame = frames[index]
                    x = lemming.x + pose.offsetX + frame.x; y = lemming.y + pose.offsetY + frame.y
                    mirrored = pose.mirrored; key = "\(pose.name)-\(index)-\(mirrored)"
                }
                guard let pixels = ghostCache.ghost(key: key, colour: ghost.colour, sprite: {
                    var sprite = [UInt8](repeating: 0, count: frame.width * frame.height * 4)
                    Self.composite(frame, palette: palette, atX: 0, y: 0, width: frame.width, height: frame.height,
                                   mirrored: mirrored, into: &sprite)
                    return (sprite, frame.width, frame.height)
                }) else { continue }
                MobileGhostSpriteCache.blend(pixels, atX: x, y: y, into: &rgba, width: width, height: height)
            }
        }
    }

    public func makeSession(runtime: Lemmings2Runtime, engineFingerprint: String,
                            levelIdentifier: String, levelIndex: Int,
                            levelFingerprint: String,
                            soundBank: Lemmings2SoundBank? = nil,
                            onCompletion: ((Lemmings2Runtime) -> Void)? = nil) -> Lemmings2MobileSession {
        Lemmings2MobileSession(runtime: runtime, engineFingerprint: engineFingerprint,
                              levelIdentifier: levelIdentifier, levelIndex: levelIndex,
                              levelFingerprint: levelFingerprint,
                              renderer: { [self] runtime, highlight in
            try render(runtime, highlight: highlight)
        }, ghostRenderer: { [self] runtime, highlight, ghosts in
            try render(runtime, highlight: highlight, ghosts: ghosts)
        }, soundBank: soundBank, onCompletion: onCompletion)
    }

    private struct Pose {
        let name: String
        let phase: Int
        let offsetX: Int
        let offsetY: Int
        let mirrored: Bool
    }

    private func sprite(for lemming: Lemmings2Runtime.Lemming, tribe: Int) -> Pose? {
        let name: String
        let phase: Int
        let offsetX: Int
        let offsetY: Int
        let directional: Bool
        switch lemming.state {
        case .walking, .cannonLoading, .cannonFlying:
            name = "LM5C"; phase = lemming.state == .walking ? 6 + lemming.age % 8 : lemming.pose
            offsetX = -9; offsetY = -10; directional = false
        case .falling:
            name = "LM40"; phase = lemming.age % 4; offsetX = -8; offsetY = -10; directional = true
        case .floating:
            name = "LM16"; phase = lemming.age % 16; offsetX = -7; offsetY = -16; directional = true
        case .climbing:
            name = "LM12"; phase = lemming.age % 8; offsetX = -8; offsetY = -13; directional = true
        case .building:
            name = "LM13"; phase = lemming.age % 16; offsetX = -8; offsetY = -13; directional = true
        case .bashing:
            name = "LM14"; phase = lemming.age % 32; offsetX = -7; offsetY = -10; directional = true
        case .mining:
            name = "LM15"; phase = lemming.age % 24; offsetX = -7; offsetY = -13; directional = true
        case .digging:
            name = "LM11"; phase = lemming.age % 16; offsetX = -8; offsetY = -12; directional = false
        case .blocking:
            name = "LM33"; phase = lemming.age % 16; offsetX = -7; offsetY = -10; directional = false
        case .stacking:
            name = "LM1F"; phase = lemming.age % 32; offsetX = -8; offsetY = -11; directional = false
        case .platforming:
            name = "LM22"; phase = lemming.age % 24; offsetX = -8; offsetY = -13; directional = true
        case .platformerShrugging:
            name = "LM7C"; phase = lemming.age % 10; offsetX = -8; offsetY = -13; directional = true
        case .skiing, .skiingAir:
            name = "LM1E"; phase = lemming.pose; offsetX = -8; offsetY = -10; directional = true
        case .poleVaulting:
            name = "LM20"; phase = lemming.pose; offsetX = -7; offsetY = -11; directional = true
        case .poleShrugging:
            name = "LM6C"; phase = lemming.age; offsetX = -7; offsetY = -9; directional = false
        case .magnoBooting:
            name = "LM19"; phase = lemming.pose; offsetX = -7; offsetY = -16; directional = false
        case .throwing:
            name = "LM10"; phase = lemming.pose; offsetX = -7; offsetY = -10; directional = true
        case .spearing:
            name = "LM1B"; phase = lemming.pose; offsetX = -7; offsetY = -9; directional = true
        case .carpetFlying:
            name = "LM0E"; phase = lemming.age % 28; offsetX = -8; offsetY = -10; directional = true
        case .surfing:
            name = "LM26"; phase = lemming.pose; offsetX = -8; offsetY = -14; directional = true
        case .sliding:
            name = "LM29"; phase = lemming.pose; offsetX = -8; offsetY = -10; directional = true
        case .hanging:
            name = "LM84"; phase = lemming.age; offsetX = -8; offsetY = -9; directional = true
        case .climbingTransfer:
            name = "LM85"; phase = lemming.age; offsetX = -8; offsetY = -11; directional = true
        case .skating:
            name = "LM0A"; phase = lemming.pose; offsetX = -7; offsetY = -9; directional = true
        case .slipping:
            name = "LM6F"; phase = lemming.age % 8; offsetX = -8; offsetY = -10; directional = true
        case .iceRecovering:
            name = "LM6D"; phase = lemming.pose; offsetX = -7; offsetY = -10; directional = false
        case .twisting:
            name = "LM2E"; phase = lemming.age % 16; offsetX = -8; offsetY = -11; directional = false
        case .shimmyJump, .shimming:
            name = "LM2C"; phase = lemming.age % 5; offsetX = -8; offsetY = -9; directional = true
        case .diving:
            name = "LM23"; phase = lemming.age % 9; offsetX = -8; offsetY = -10; directional = true
        case .kayaking, .kayakPacking:
            name = "LM0B"; phase = lemming.age % 40; offsetX = -8; offsetY = -11; directional = true
        case .flyingIcarus:
            name = "LM31"; phase = lemming.age % 16; offsetX = -8; offsetY = -13; directional = false
        case .hangGliding:
            name = "LM32"; phase = 0; offsetX = -8; offsetY = -7; directional = true
        case .roping:
            name = "LM2D"; phase = lemming.age % 53; offsetX = -8; offsetY = -10; directional = false
        case .firingBazooka:
            name = "LM1A"; phase = lemming.age; offsetX = -7; offsetY = -12; directional = false
        case .firingMortar:
            name = "LM21"; phase = lemming.age % 23; offsetX = -7; offsetY = -9; directional = false
        case .rockClimbing:
            name = "LM2A"; phase = lemming.pose * 16 + lemming.age % 16; offsetX = -8; offsetY = -12; directional = true
        case .hoisting:
            name = "LM7D"; phase = lemming.age; offsetX = -8; offsetY = -9; directional = false
        case .planting:
            name = "LM27"; phase = lemming.age; offsetX = -8; offsetY = -10; directional = false
        case .filling:
            name = "LM03"; phase = lemming.age; offsetX = -8; offsetY = -15; directional = false
        case .sandPouring:
            name = "LM2F"; phase = lemming.age; offsetX = -8; offsetY = -15; directional = false
        case .gluePouring:
            name = "LM30"; phase = lemming.age; offsetX = -8; offsetY = -15; directional = false
        case .attracting:
            name = String(format: "LM%02X", 95 + tribe)
            phase = lemming.age; offsetX = -7; offsetY = -10; directional = false
        case .dancing:
            name = String(format: "LM%02X", 66 + tribe)
            phase = lemming.age; offsetX = -7; offsetY = -10; directional = false
        case .trapDying:
            name = String(format: "LM%02X", lemming.deathSprite)
            phase = lemming.age; offsetX = -8; offsetY = -10; directional = false
        case .catapultLoading:
            name = "LM6E"; phase = lemming.pose; offsetX = -7; offsetY = -12; directional = false
        case .chainRiding:
            name = "LM4F"; phase = lemming.pose; offsetX = -7; offsetY = -12; directional = true
        case .superFlying:
            name = "LM25"; phase = lemming.pose; offsetX = -8; offsetY = -12; directional = false
        case .arching:
            name = "LM05"; phase = lemming.pose; offsetX = -8; offsetY = -16; directional = true
        case .hopping, .hopPreparing:
            name = lemming.state == .hopPreparing ? "LM09" : "LM86"
            phase = lemming.age; offsetX = -8; offsetY = -11; directional = true
        case .blastBombing:
            name = "LM07"; phase = lemming.age; offsetX = -7; offsetY = -10; directional = false
        case .lasering:
            name = "LM17"; phase = lemming.age % 2; offsetX = -8; offsetY = -16; directional = false
        case .flaming:
            name = "LM24"; phase = lemming.age % 2; offsetX = -8; offsetY = -16; directional = false
        case .shrugging:
            name = "LM7B"; phase = lemming.age % 8; offsetX = -8; offsetY = -13; directional = true
        case .exploding:
            name = "LM18"; phase = lemming.age; offsetX = -7; offsetY = -10; directional = false
        case .exiting:
            name = String(format: "LM%02X", 0x50 + (tribe == 9 ? 8 : tribe))
            phase = lemming.age; offsetX = -7; offsetY = -13; directional = false
        case .teleporting:
            name = "LM81"; phase = min(26, lemming.pose); offsetX = -8; offsetY = -12; directional = false
        case .switchingValve:
            name = "LM82"; phase = lemming.age; offsetX = -8; offsetY = -9; directional = false
        case .running:
            name = "LM02"; phase = lemming.age % 8; offsetX = -7; offsetY = -11; directional = true
        case .jumping:
            name = "LM01"; phase = lemming.age % 12; offsetX = -8; offsetY = -9; directional = true
        case .stunned:
            name = "LM42"; phase = lemming.age; offsetX = -8; offsetY = -10; directional = false
        case .tumbling:
            name = "LM41"; phase = lemming.age % 8; offsetX = -8; offsetY = -10; directional = true
        case .drowning:
            name = "LM5D"; phase = lemming.age; offsetX = -7; offsetY = -11; directional = false
        case .leavingWater:
            name = "LM83"; phase = min(12, lemming.age); offsetX = -8; offsetY = -8; directional = true
        case .swimming:
            name = "LM0C"; phase = lemming.age % 16; offsetX = -8; offsetY = -6; directional = true
        case .parachuting:
            name = "LM28"; phase = lemming.age % 16; offsetX = -8; offsetY = -12; directional = false
        case .jetPacking:
            name = "LM2B"; phase = lemming.pose; offsetX = -7; offsetY = -10; directional = false
        case .rolling, .rollingAir:
            name = "LM0D"; phase = lemming.pose; offsetX = -8; offsetY = -10; directional = true
        case .scooping:
            name = "LM08"; phase = lemming.age % 20; offsetX = -8; offsetY = -12; directional = true
        case .fencing:
            name = "LM1C"; phase = lemming.age % 16; offsetX = -8; offsetY = -11; directional = true
        case .clubBashing:
            name = "LM0F"; phase = lemming.age % 32; offsetX = -7; offsetY = -10; directional = true
        case .stomping:
            name = "LM1D"; phase = lemming.age % 8; offsetX = -7; offsetY = -9; directional = false
        case .terrainRising:
            name = "LM40"; phase = lemming.age % 4; offsetX = -8; offsetY = -10; directional = true
        default:
            name = "LM5C"; phase = 6 + lemming.age % 8; offsetX = -9; offsetY = -10; directional = false
        }

        guard let frames = animations[name], !frames.isEmpty else { return nil }
        let frameCount = frames.count
        let sidedPhase = directional && frameCount >= 2
            ? (phase % max(1, frameCount / 2)) + (lemming.direction < 0 ? frameCount / 2 : 0)
            : phase % frameCount
        return Pose(name: name, phase: sidedPhase, offsetX: offsetX, offsetY: offsetY,
                    mirrored: lemming.state == .walking && lemming.direction < 0)
    }

    static func expand(_ indexed: [UInt8], palette: [UInt8]) -> [UInt8] {
        var result = [UInt8](repeating: 255, count: indexed.count * 4)
        for (pixel, value) in indexed.enumerated() {
            let source = Int(value) * 4
            let target = pixel * 4
            result[target] = palette[source]
            result[target + 1] = palette[source + 1]
            result[target + 2] = palette[source + 2]
            result[target + 3] = 255
        }
        return result
    }

    static func composite(_ frame: Lemmings2SpriteFrame, palette: [UInt8],
                                  atX x: Int, y: Int, width: Int, height: Int,
                                  mirrored: Bool = false, into rgba: inout [UInt8]) {
        guard frame.width > 0, frame.height > 0,
              frame.pixels.count == frame.width * frame.height,
              frame.opaque.count == frame.pixels.count else { return }
        for sy in 0..<frame.height {
            let dy = y + sy
            guard (0..<height).contains(dy) else { continue }
            for sx in 0..<frame.width {
                let dx = x + (mirrored ? frame.width - sx - 1 : sx)
                guard (0..<width).contains(dx) else { continue }
                let source = sy * frame.width + sx
                guard frame.opaque[source] else { continue }
                let paletteOffset = Int(frame.pixels[source]) * 4
                let destination = (dy * width + dx) * 4
                rgba[destination] = palette[paletteOffset]
                rgba[destination + 1] = palette[paletteOffset + 1]
                rgba[destination + 2] = palette[paletteOffset + 2]
                rgba[destination + 3] = 255
            }
        }
    }

    private static func draw(_ colour: Int, palette: [UInt8], atX x: Int, y: Int,
                             width: Int, height: Int, into rgba: inout [UInt8]) {
        guard (0..<width).contains(x), (0..<height).contains(y), (0..<128).contains(colour) else { return }
        let source = colour * 4
        let destination = (y * width + x) * 4
        rgba[destination] = palette[source]
        rgba[destination + 1] = palette[source + 1]
        rgba[destination + 2] = palette[source + 2]
        rgba[destination + 3] = 255
    }

    private static func drawSelection(aroundX x: Int, y: Int, width: Int, height: Int,
                                      into rgba: inout [UInt8]) {
        let colour: (UInt8, UInt8, UInt8) = (255, 255, 0)
        for (px, py) in [(x - 8, y - 12), (x + 7, y - 12), (x - 8, y + 1), (x + 7, y + 1)] {
            guard (0..<width).contains(px), (0..<height).contains(py) else { continue }
            let offset = (py * width + px) * 4
            rgba[offset] = colour.0; rgba[offset + 1] = colour.1; rgba[offset + 2] = colour.2
        }
    }
}
