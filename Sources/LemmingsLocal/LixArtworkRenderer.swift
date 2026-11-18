#if os(macOS)
import AppKit
import NxlvKit
import LemmingsGameArt

/**
 * Shares the Lix artwork choice across engines without changing their rules.
 */
@MainActor enum CharacterArtworkPreference {
    static let key = GameArtworkSkin.key
    static let changed = GameArtworkSkin.changed
    static var lixEnabled: Bool { GameArtworkSkin.lixEnabled }
    @discardableResult static func setLixEnabled(_ enabled: Bool) -> Bool { GameArtworkSkin.setLixEnabled(enabled) }
}

/**
 * Presents Lix pixels at half their authored scale, anchored to engine feet.
 */
@MainActor final class LixArtworkRenderer {
    struct Frame {
        let image: NSImage
        let footX: CGFloat
        let footY: CGFloat
        let cacheKey: String
        let isApproximation: Bool
    }
    struct Mapping {
        let activity: LixArtwork.Activity
        let isApproximation: Bool
    }
    static let shared = LixArtworkRenderer()
    private let artwork: LixArtwork?
    private let images = NSCache<NSString, NSImage>()
    let loadError: String?
    var isAvailable: Bool { artwork != nil }

    init(directory: URL? = nil) {
        if let directory { artwork = try? LixArtwork(directory: directory) }
        else { artwork = GameArtworkResources.lixArtwork }
        loadError = artwork == nil ? "Lix artwork could not be loaded. Reinstall this build." : nil
        images.totalCostLimit = 16 * 1024 * 1024
    }

    func frame(activity: LixArtwork.Activity, animationFrame: Int, facingLeft: Bool) -> Frame? {
        guard let artwork else { return nil }
        let chosen = artwork.frameCount(for: activity) > 0 ? activity : .stunner
        let count = artwork.frameCount(for: chosen)
        let index = ((animationFrame % count) + count) % count
        let key = "lix-\(chosen.rawValue)-\(index)-\(facingLeft)"
        let image: NSImage
        if let cached = images.object(forKey: key as NSString) {
            image = cached
        } else {
            guard let frame = artwork.frame(activity: chosen, animationFrame: index, facingLeft: facingLeft),
                  let provider = CGDataProvider(data: Data(frame.rgba) as CFData),
                  let cg = CGImage(width: frame.width, height: frame.height, bitsPerComponent: 8,
                    bitsPerPixel: 32, bytesPerRow: frame.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue), provider: provider,
                    decode: nil, shouldInterpolate: false, intent: .defaultIntent) else { return nil }
            image = NSImage(cgImage: cg, size: NSSize(width: CGFloat(frame.width) / 2, height: CGFloat(frame.height) / 2))
            images.setObject(image, forKey: key as NSString, cost: frame.rgba.count)
        }
        return Frame(image: image, footX: 8, footY: 13, cacheKey: key, isApproximation: chosen != activity)
    }

    func sceneFrame(_ level: ClassicRenderedLevel, simulation: ClassicDOSSimulation,
                    theme: LixSceneArtwork.Theme) -> LixSceneArtwork.Frame? {
        artwork?.sceneArtwork?.frame(level, simulation: simulation, theme: theme)
    }

    func frame(pose: ClassicLemmingPose, animationFrame: Int, facingLeft: Bool,
               backpack: ClassicSkillBackpack.Kind? = nil) -> Frame? {
        let mapping = Self.classicMapping(pose)
        guard let frame = frame(activity: mapping.activity, animationFrame: animationFrame, facingLeft: facingLeft) else { return nil }
        guard let backpack, let artwork else { return frame }
        let key = frame.cacheKey + "-pack-" + backpack.rawValue
        let image: NSImage
        if let cached = images.object(forKey: key as NSString) {
            image = cached
        } else {
            guard let pixels = artwork.frame(activity: mapping.activity, animationFrame: animationFrame, facingLeft: facingLeft),
                  let made = ClassicSkillBackpack.image(rgba: Data(pixels.rgba), width: pixels.width,
                    height: pixels.height, pixelScale: 2, pose: pose, left: facingLeft, kind: backpack) else { return frame }
            made.size = NSSize(width: made.size.width / 2, height: made.size.height / 2)
            image = made
            images.setObject(image, forKey: key as NSString, cost: Int(image.size.width * image.size.height * 16))
        }
        return Frame(image: image, footX: frame.footX + 2, footY: frame.footY,
                     cacheKey: key, isApproximation: mapping.isApproximation)
    }

    static func classicMapping(_ pose: ClassicLemmingPose) -> Mapping {
        let activity: LixArtwork.Activity
        switch pose {
        case .walking: activity = .walker
        case .jumping: activity = .jumper
        case .digging: activity = .digger
        case .climbing: activity = .climber
        case .postClimb: activity = .ascender
        case .drowning: activity = .drowner
        case .building: activity = .builder
        case .bashing: activity = .basher
        case .mining: activity = .miner
        case .falling: activity = .faller
        case .umbrellaOpening, .floating: activity = .floater
        case .splatting: activity = .splatter
        case .exiting: activity = .exiter
        case .frying: activity = .burner
        case .blocking: activity = .blocker
        case .shrugging: activity = .shrugger
        case .ohNo, .explosion: activity = .imploder
        }
        return Mapping(activity: activity, isApproximation: [.umbrellaOpening, .ohNo, .explosion].contains(pose))
    }

    static func l2Mapping(_ state: Lemmings2Runtime.State) -> Mapping {
        let activity: LixArtwork.Activity
        switch state {
        case .walking: activity = .walker
        case .running: activity = .runner
        case .falling: activity = .faller
        case .floating: activity = .floater
        case .climbing: activity = .climber
        case .building: activity = .builder
        case .bashing: activity = .basher
        case .mining: activity = .miner
        case .digging: activity = .digger
        case .blocking: activity = .blocker
        case .platforming: activity = .platformer
        case .platformerShrugging: activity = .shrugger2
        case .shrugging: activity = .shrugger
        case .jumping: activity = .jumper
        case .tumbling: activity = .tumbler
        case .stunned: activity = .stunner
        case .drowning: activity = .drowner
        case .exiting: activity = .exiter
        case .exploding, .blastBombing:
            return Mapping(activity: .imploder, isApproximation: true)
        default:
            return Mapping(activity: .stunner, isApproximation: true)
        }
        return Mapping(activity: activity, isApproximation: false)
    }

    static func l3Mapping(_ state: Lemmings3Runtime.State) -> Mapping {
        switch state {
        case .walking: Mapping(activity: .walker, isApproximation: false)
        case .falling: Mapping(activity: .faller, isApproximation: false)
        case .floating: Mapping(activity: .floater, isApproximation: false)
        case .jumping: Mapping(activity: .jumper, isApproximation: false)
        case .climbing: Mapping(activity: .climber, isApproximation: false)
        case .blocking: Mapping(activity: .blocker, isApproximation: false)
        case .building: Mapping(activity: .builder, isApproximation: false)
        case .digging: Mapping(activity: .digger, isApproximation: false)
        case .drowning: Mapping(activity: .drowner, isApproximation: false)
        case .exiting: Mapping(activity: .exiter, isApproximation: false)
        case .swimming, .shimmying, .trapped, .saved, .dead:
            Mapping(activity: .stunner, isApproximation: true)
        }
    }
}

#endif
