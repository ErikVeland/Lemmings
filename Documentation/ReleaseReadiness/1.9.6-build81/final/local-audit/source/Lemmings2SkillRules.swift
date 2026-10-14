/// Assignment permissions from the original PROCESS RuleTable at bbe0.
/// Resource limits and skill-specific geometry are checked by the runtime.
public enum Lemmings2SkillRules {
    public static func permits(_ skill: Lemmings2Runtime.Skill, during state: Lemmings2Runtime.State) -> Bool {
        let mask: UInt64
        let ground: UInt64 = 0xfffbffffff7fe
        switch state {
        case .walking, .hopPreparing, .shrugging, .platformerShrugging: mask = ground
        case .running: mask = ground & ~(1 << 2)
        case .attracting, .dancing: mask = ground & ~(1 << 6)
        case .scooping: mask = ground & ~(1 << 8)
        case .hopping: mask = ground & ~(1 << 9)
        case .rolling: mask = ground & ~(1 << 13)
        case .clubBashing: mask = ground & ~(1 << 15)
        case .digging: mask = ground & ~(1 << 17)
        case .building: mask = ground & ~(1 << 19)
        case .bashing: mask = ground & ~(1 << 20)
        case .mining: mask = ground & ~(1 << 21)
        case .lasering: mask = ground & ~(1 << 23)
        case .magnoBooting: mask = ground & ~(1 << 25)
        case .fencing: mask = ground & ~(1 << 28)
        case .stomping: mask = ground & ~(1 << 29)
        case .skiing: mask = ground & ~(1 << 30)
        case .stacking: mask = ground & ~(1 << 31)
        case .platforming: mask = ground & ~(1 << 34)
        case .skating: mask = 0x61f2823445216
        case .slipping: mask = 0x61f2823445616
        case .swimming: mask = 0x74001440c04
        case .drowning: mask = 0x74001441c04
        case .hanging: mask = 0x170001441404
        case .climbing: mask = 0x70001401404
        case .floating: mask = 0x70001041404
        case .parachuting: mask = 0x60001441404
        case .sliding: mask = 0x50001441404
        case .rockClimbing: mask = 0x30001441404
        case .exploding: mask = 0x70000441404
        case .exiting, .saved, .dead, .trapped, .trapDying: mask = 0
        default: mask = 0x70001441404
        }
        return skill != .unused && mask & (UInt64(1) << skill.rawValue) != 0
    }
}
