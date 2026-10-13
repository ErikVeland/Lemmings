import Foundation
import NxlvKit

/**
 * Defines the NeoLemmix actor animations required by the mobile renderer.
 */
public enum NeoLemmixMobileSupport {
    public static var requiredAnimationNames: Set<String> {
        Set(NeoLemmixAction.allCases.compactMap(animationName(for:)))
    }

    public static func animationName(for action: NeoLemmixAction) -> String? {
        switch action {
        case .walking: "walker"
        case .ascending: "ascender"
        case .falling: "faller"
        case .climbing: "climber"
        case .hoisting: "hoister"
        case .floating: "floater"
        case .gliding: "glider"
        case .dehoisting: "dehoister"
        case .sliding: "slider"
        case .swimming: "swimmer"
        case .blocking: "blocker"
        case .building: "builder"
        case .platforming: "platformer"
        case .stacking: "stacker"
        case .bashing: "basher"
        case .fencing: "fencer"
        case .lasering: "laserer"
        case .teleporting, .removed: nil
        case .mining: "miner"
        case .digging: "digger"
        case .jumping: "jumper"
        case .reaching: "reacher"
        case .shimmying: "shimmier"
        case .disarming: "disarmer"
        case .shrugging: "shrugger"
        case .ohNo, .stoning: "ohnoer"
        case .exploding: "bomber"
        case .stoneFinish: "stoner"
        case .splatting: "splatter"
        case .exiting: "exiter"
        case .drowning: "drowner"
        case .vaporizing: "burner"
        }
    }
}
