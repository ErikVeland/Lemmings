public struct LemmingSkillTargetingHistory: Codable, Equatable, Sendable {
    public private(set) var isFavoured = false

    public init() {}

    public mutating func transition(wasPerformingSkill: Bool, isPerformingSkill: Bool, resets: Bool) {
        if resets {
            isFavoured = false
        } else if wasPerformingSkill || isPerformingSkill {
            isFavoured = true
        }
    }

    public init(from decoder: any Decoder) throws {
        isFavoured = try decoder.singleValueContainer().decode(Bool.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(isFavoured)
    }

    /// Targeting history does not change physics or invalidate older replay states.
    public static func == (lhs: Self, rhs: Self) -> Bool { true }
}

public extension KeyedDecodingContainer {
    func decode(_ type: LemmingSkillTargetingHistory.Type, forKey key: Key) throws -> LemmingSkillTargetingHistory {
        try decodeIfPresent(type, forKey: key) ?? .init()
    }
}

public extension ClassicDOSAction {
    var isPerformingSkill: Bool {
        switch self {
        case .climbing, .hoisting, .floating, .blocking, .building, .shrugging,
             .bashing, .mining, .digging:
            return true
        default:
            return false
        }
    }

    var resetsSkillTargetPriority: Bool {
        switch self {
        case .falling, .splatting, .exiting, .drowning, .vaporizing, .ohNo, .exploding:
            return true
        default:
            return false
        }
    }
}

public extension ClassicLemmingPose {
    var isPerformingSkill: Bool {
        switch self {
        case .digging, .climbing, .postClimb, .building, .bashing, .mining,
             .umbrellaOpening, .floating, .blocking, .shrugging:
            return true
        default:
            return false
        }
    }
}

public extension NeoLemmixAction {
    var isPerformingSkill: Bool {
        switch self {
        case .climbing, .hoisting, .floating, .gliding, .dehoisting, .sliding,
             .swimming, .blocking, .building, .platforming, .stacking, .bashing,
             .fencing, .lasering, .mining, .digging, .jumping, .reaching,
             .shimmying, .disarming, .shrugging:
            return true
        default:
            return false
        }
    }

    var resetsSkillTargetPriority: Bool {
        switch self {
        case .falling, .ohNo, .stoning, .exploding, .stoneFinish, .splatting,
             .exiting, .drowning, .vaporizing, .removed:
            return true
        default:
            return false
        }
    }
}

public extension Lemmings2Runtime.State {
    var isPerformingSkill: Bool {
        switch self {
        case .floating, .climbing, .building, .bashing, .mining, .digging,
             .blocking, .stacking, .platforming, .platformerShrugging, .stomping,
             .shrugging, .superFlying, .arching, .skiing, .skiingAir,
             .poleVaulting, .poleShrugging, .magnoBooting, .throwing, .spearing,
             .carpetFlying, .surfing, .sliding, .hanging, .climbingTransfer,
             .skating, .twisting, .hopping, .hopPreparing, .blastBombing,
             .swimming, .leavingWater, .parachuting, .attracting, .jetPacking,
             .rolling, .rollingAir, .shimmyJump, .shimming, .diving, .kayaking,
             .kayakPacking, .flyingIcarus, .hangGliding, .roping, .firingBazooka,
             .firingMortar, .rockClimbing, .hoisting, .planting, .ballooning,
             .filling, .sandPouring, .gluePouring, .jumping, .running, .scooping,
             .fencing, .clubBashing, .lasering, .flaming:
            return true
        default:
            return false
        }
    }

    var resetsSkillTargetPriority: Bool {
        switch self {
        case .falling, .exploding, .exiting, .saved, .dead, .trapDying, .trapped, .drowning:
            return true
        default:
            return false
        }
    }
}

public extension Lemmings3Runtime.State {
    var isPerformingSkill: Bool {
        switch self {
        case .floating, .swimming, .jumping, .climbing, .shimmying, .blocking,
             .building, .digging:
            return true
        default:
            return false
        }
    }

    var resetsSkillTargetPriority: Bool {
        switch self {
        case .falling, .drowning, .trapped, .exiting, .saved, .dead:
            return true
        default:
            return false
        }
    }
}
