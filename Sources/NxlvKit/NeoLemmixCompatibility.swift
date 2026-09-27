import Foundation

extension NeoLemmixRules {
    /// Reject mechanics the renderer can display but the simulation cannot apply.
    public static func unsupportedFeatures(level: NxlvLevel, renderedLevel: NxlvRenderedLevel) -> [String] {
        var features = Set<String>()
        for (skill, supply) in level.skills where unsupportedSkills.contains(NeoLemmixSkill(skill)) {
            if supply.legacyCount > 0 { features.insert(skill.rawValue.capitalized) }
        }
        for gadget in renderedLevel.gadgets {
            switch gadget.effect {
            case .none, .background, .entrance, .exit, .trap, .trapOnce, .fire, .water,
                 .oneWayLeft, .oneWayRight, .oneWayUp, .oneWayDown, .animation,
                 .animationOnce:
                break
            case .lockedExit: features.insert("locked exits")
            case .unlockButton: features.insert("exit buttons")
            case .pickupSkill: features.insert("skill pickups")
            case .teleporter, .receiver: features.insert("teleporters")
            case .updraft: features.insert("updrafts")
            case .splatPad, .antiSplatPad: features.insert("splat pads")
            case .splitter: features.insert("splitters")
            case .forceLeft, .forceRight: features.insert("force fields")
            case .paint: features.insert("paint effects")
            case .neutralizer, .deneutralizer: features.insert("neutral state changers")
            case .addSkill, .removeSkills: features.insert("skill state changers")
            case .portal: features.insert("portals")
            case let .unknown(name): features.insert("object effect \(name)")
            }
        }
        if level.preplacedLemmings.contains(where: { $0.traits.contains(.zombie) })
            || level.gadgets.contains(where: { $0.lemmingTraits.contains(.zombie) }) {
            features.insert("zombie infection")
        }
        if level.document.hasLine("superlemming") { features.insert("Superlemming") }
        return features.sorted()
    }
}
