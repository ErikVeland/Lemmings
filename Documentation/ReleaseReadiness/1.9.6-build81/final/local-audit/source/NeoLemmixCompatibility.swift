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
                 .animationOnce, .splatPad, .antiSplatPad, .pickupSkill,
                 .lockedExit, .unlockButton, .paint:
                break
            case .teleporter, .receiver: break
            case .updraft: break
            case .splitter, .forceLeft, .forceRight: break
            case .neutralizer, .deneutralizer, .addSkill, .removeSkills: break
            case .portal: break
            case let .unknown(name): features.insert("object effect \(name)")
            }
        }
        return features.sorted()
    }
}
