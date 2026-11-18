import Foundation
import LemmingsAppCore
import LemmingsMobileCore
import NxlvKit

/**
 * Supplies Lix pixels through the current mobile session presentation contracts.
 */
public enum MobileLixArtwork {
    private final class WeakSession { weak var value: (any MobileGameSession)?; init(_ value: any MobileGameSession) { self.value = value } }
    private final class Installed: @unchecked Sendable {
        private let lock = NSLock()
        private var values: [ObjectIdentifier: WeakSession] = [:]
        func insert(_ session: any MobileGameSession) -> Bool {
            lock.lock(); defer { lock.unlock() }
            let key = ObjectIdentifier(session)
            guard values[key]?.value == nil else { return false }
            values = values.filter { $0.value.value != nil }
            values[key] = WeakSession(session)
            return true
        }
    }
    private struct Installer: MobileArtworkInstalling {
        var revision: String { MobileLixArtwork.revision }
        func install(on session: any MobileGameSession) { MobileLixArtwork.install(on: session) }
    }
    private static let installed = Installed()
    private static let frames = GameAssetCache<MobilePixelFrame>(capacity: 768)
    private static let ghostFrames = MobileGhostSpriteCache()
    public static var revision: String { GameArtworkResources.revision + ":" + String(GameArtworkSkin.lixEnabled) }
    public static var isEnabled: Bool { GameArtworkSkin.lixEnabled && GameArtworkResources.lixArtwork != nil }
    public static func activate() { MobileArtworkInstallation.activate(Installer()) }

    public static func install(on session: any MobileGameSession) {
        guard installed.insert(session) else { return }
        if let classic = session as? ClassicMobileSession {
            let starter = classic.levelIdentifier.hasPrefix(GameStarterContent.identifier)
            let themes: [LixSceneArtwork.Theme] = [.brick, .earth, .wood]
            classic.artworkProvider = ClassicProvider(force: classic.needsArtworkProvider,
                theme: starter ? themes[min(2, max(0, classic.levelIndex))] : .brick)
        } else if let sequel = session as? Lemmings2MobileSession, let original = sequel.artworkRenderer {
            let originalSprite = sequel.spriteProvider
            sequel.artworkRenderer = { runtime, highlight, ghosts, mac in
                guard isEnabled else { return try original(runtime, highlight, ghosts, mac) }
                let drawsActors = SceneRasterContext.drawActors.wrappedValue
                let base = try MobileArtworkInstallation.nativeActorBodies.withValue(false) { try original(runtime, nil, [], mac) }
                guard drawsActors else { return base }
                let scale = mac ? 2 : 1
                let live = runtime.lemmings.filter { $0.active && $0.state != .trapped }.compactMap { l2Sprite($0, tick: runtime.tick, scale: scale) }
                let earlier = ghosts.flatMap { ghost in ghost.state.lemmings.filter { $0.active && $0.state != .trapped }.compactMap {
                    l2Sprite($0, tick: ghost.state.tick, scale: scale).map { ($0, ghost.colour) }
                } }
                return try composite(base: base, width: runtime.configuration.width * scale,
                    height: runtime.configuration.height * scale, scale: scale, sprites: live, ghosts: earlier)
            }
            sequel.spriteProvider = { runtime, actor in
                guard isEnabled else { return originalSprite?(runtime, actor) }
                return runtime.lemmings.first { $0.id == actor && $0.active && $0.state != .trapped && $0.state != .exploding }
                    .flatMap { l2Sprite($0, tick: runtime.tick, scale: 2) }
            }
        } else if let sequel = session as? Lemmings3MobileSession, let original = sequel.artworkRenderer {
            let originalSprite = sequel.spriteProvider
            sequel.artworkRenderer = { runtime, highlight, ghosts, mac in
                guard isEnabled else { return try original(runtime, highlight, ghosts, mac) }
                let drawsActors = SceneRasterContext.drawActors.wrappedValue
                let base = try SceneRasterContext.drawActors.withValue(false) { try original(runtime, nil, [], mac) }
                guard drawsActors else { return base }
                let scale = mac ? 2 : 1
                let live = runtime.lemmings.filter(\.active).compactMap { l3Sprite($0, tick: runtime.tick, scale: scale) }
                let earlier = ghosts.flatMap { ghost in ghost.state.lemmings.filter(\.active).compactMap {
                    l3Sprite($0, tick: ghost.state.tick, scale: scale).map { ($0, ghost.colour) }
                } }
                return try composite(base: base, width: runtime.configuration.width * scale,
                    height: runtime.configuration.height * scale, scale: scale, sprites: live, ghosts: earlier)
            }
            sequel.spriteProvider = { runtime, actor in
                guard isEnabled else { return originalSprite?(runtime, actor) }
                return runtime.lemmings.first { $0.id == actor && $0.active }
                    .flatMap { l3Sprite($0, tick: runtime.tick, scale: 2) }
            }
        }
    }

    /** Returns nil for actions without an authored Lix equivalent. */
    public static func activity(named name: String) -> LixArtwork.Activity? {
        switch name.lowercased() {
        case "walking", "walker": .walker
        case "running", "runner": .runner
        case "falling", "faller": .faller
        case "jumping", "jumper": .jumper
        case "climbing", "climber": .climber
        case "hoisting", "postclimb", "ascending": .ascender
        case "floating", "floater", "umbrellaopening": .floater
        case "drowning", "drowner": .drowner
        case "splatting", "splatter": .splatter
        case "exiting", "exiter": .exiter
        case "vaporizing", "frying", "burning": .burner
        case "blocking", "blocker": .blocker
        case "building", "builder": .builder
        case "platforming", "platformer": .platformer
        case "shrugging", "platformershrugging": .shrugger
        case "bashing", "basher": .basher
        case "mining", "miner": .miner
        case "digging", "digger": .digger
        case "ohno", "exploding", "explosion", "blastbombing", "bomber": .imploder
        case "tumbling": .tumbler
        case "stunned": .stunner
        default: nil
        }
    }

    public static func sprite(activity: LixArtwork.Activity, foot: MobilePoint, animationFrame: Int,
                              facingLeft: Bool, scale: Int = 2, time: Double? = nil) -> MobileSpriteHighlight? {
        guard let artwork = GameArtworkResources.lixArtwork else { return nil }
        let chosen = artwork.frameCount(for: activity) > 0 ? activity : .stunner
        let count = artwork.frameCount(for: chosen)
        guard count > 0 else { return nil }
        let phase = (animationFrame % count + count) % count
        let scale = scale == 1 ? 1 : 2
        let key = "lix/\(chosen.rawValue)/\(phase)/\(facingLeft)/\(scale)"
        let frame: MobilePixelFrame
        if let cached = frames.value(for: key) { frame = cached }
        else {
            guard let pixels = artwork.frame(activity: chosen, animationFrame: phase, facingLeft: facingLeft) else { return nil }
            let stride = 2 / scale, width = pixels.width / stride, height = pixels.height / stride
            var rgba = Data(capacity: width * height * 4)
            for y in 0..<height { for x in 0..<width {
                let source = ((y * stride) * pixels.width + x * stride) * 4
                rgba.append(contentsOf: pixels.rgba[source..<(source + 4)])
            } }
            guard let result = try? MobilePixelFrame(width: width, height: height, rgba: rgba) else { return nil }
            frame = result; frames.insert(result, for: key)
        }
        return .init(frame: frame,
            rect: .init(x: foot.x - 8, y: foot.y - 13, width: Double(frame.width) / Double(scale), height: Double(frame.height) / Double(scale)),
            cacheKey: key, time: time, direction: facingLeft ? -1 : 1)
    }

    private static func l2Sprite(_ lemming: Lemmings2Runtime.Lemming, tick: Int, scale: Int) -> MobileSpriteHighlight? {
        sprite(activity: activity(named: lemming.state.rawValue) ?? .stunner,
            foot: .init(x: Double(lemming.x), y: Double(lemming.y)), animationFrame: lemming.age,
            facingLeft: lemming.direction < 0, scale: scale, time: Double(tick) / Lemmings2Runtime.ticksPerSecond)
    }
    private static func l3Sprite(_ lemming: Lemmings3Runtime.Lemming, tick: Int, scale: Int) -> MobileSpriteHighlight? {
        sprite(activity: activity(named: lemming.state.rawValue) ?? .stunner,
            foot: .init(x: Double(lemming.x), y: Double(lemming.y)), animationFrame: lemming.age,
            facingLeft: lemming.direction < 0, scale: scale, time: Double(tick) / Lemmings3Runtime.ticksPerSecond)
    }

    private static func composite(base: MobilePixelFrame, width: Int, height: Int, scale: Int,
                                  sprites: [MobileSpriteHighlight], ghosts: [(MobileSpriteHighlight, ReplayGhostColour)]) throws -> MobilePixelFrame {
        var pixels = [UInt8](base.rgba)
        for (sprite, colour) in ghosts {
            guard let ghost = ghostFrames.ghost(key: sprite.cacheKey, colour: colour, pixelScale: scale,
                sprite: { ([UInt8](sprite.frame.rgba), sprite.frame.width, sprite.frame.height) }) else { continue }
            MobileGhostSpriteCache.blend(ghost, atX: Int(sprite.rect.x * Double(scale)), y: Int(sprite.rect.y * Double(scale)),
                into: &pixels, width: width, height: height)
        }
        var crowd = MobileCrowdShadow()
        let region = SceneRasterContext.region(width: width, height: height)
        for sprite in sprites {
            let x = Int(sprite.rect.x * Double(scale)), y = Int(sprite.rect.y * Double(scale))
            let source = [UInt8](sprite.frame.rgba)
            pixels.withUnsafeMutableBytes { destination in
                crowd.cast(spriteWidth: sprite.frame.width, spriteHeight: sprite.frame.height,
                    x: x, y: y, width: width, height: height, pixels: destination,
                    opaque: { sx, sy in source[(sy * sprite.frame.width + sx) * 4 + 3] >= 128 })
            }
            for sy in 0..<sprite.frame.height { for sx in 0..<sprite.frame.width {
                let from = (sy * sprite.frame.width + sx) * 4, alpha = Int(source[from + 3])
                guard alpha > 0, let to = region.offset(x: x + sx, y: y + sy) else { continue }
                for channel in 0..<3 {
                    pixels[to + channel] = UInt8((Int(source[from + channel]) * alpha + Int(pixels[to + channel]) * (255 - alpha) + 127) / 255)
                }
                pixels[to + 3] = 255
            } }
        }
        return try MobilePixelFrame(width: width, height: height, rgba: Data(pixels), arrowGlints: base.arrowGlints)
    }

    private final class ClassicProvider: ClassicMobileArtworkProvider {
        let force: Bool
        let theme: LixSceneArtwork.Theme
        init(force: Bool, theme: LixSceneArtwork.Theme) { self.force = force; self.theme = theme }
        var revision: String { MobileLixArtwork.revision + ":" + String(force) + ":" + theme.rawValue }
        var isEnabled: Bool { (force || GameArtworkSkin.lixEnabled) && GameArtworkResources.lixArtwork != nil }
        let renderScale = 2
        func scene(_ level: ClassicRenderedLevel, simulation: ClassicDOSSimulation) -> MobilePixelFrame? {
            guard let frame = ClassicLixSceneFrame.build(level, simulation: simulation, theme: theme) else { return nil }
            return try? MobilePixelFrame(width: frame.width, height: frame.height,
                rgba: SceneRasterContext.crop(frame.rgba, width: frame.width, height: frame.height))
        }
        func sprite(_ lemming: ClassicDOSLemming, simulation: ClassicDOSSimulation) -> MobileSpriteHighlight? {
            MobileLixArtwork.sprite(activity: MobileLixArtwork.activity(named: lemming.action.rawValue) ?? .stunner,
                foot: .init(x: Double(lemming.foot.x), y: Double(lemming.foot.y)), animationFrame: lemming.animationFrame,
                facingLeft: lemming.direction == .left, scale: 2,
                time: Double(simulation.tickCount) / Double(ClassicDOSRules.ticksPerSecond))
        }
        func skill(control: Int) -> MobilePixelFrame? {
            let activities: [LixArtwork.Activity] = [.climber, .floater, .imploder, .blocker, .builder, .basher, .miner, .digger]
            guard activities.indices.contains(control), let frame = GameArtworkResources.lixInterface?.skill(activities[control]) else { return nil }
            return try? MobilePixelFrame(width: frame.width, height: frame.height, rgba: frame.rgba)
        }
    }
}
