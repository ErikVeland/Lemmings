import CoreGraphics
import Foundation
import LemmingsGameArt
import LemmingsMobileCore

extension MenuAudit {
    static func hudTargetFits(_ target: MobileHUDRenderer.Item, layout: MobileHUDLayout) -> Bool {
        if case .skill = target.action, let portrait = layout.portrait {
            let content = CGRect(x: portrait.skills.minX, y: portrait.skills.minY,
                                 width: portrait.skillContentWidth, height: portrait.skills.height)
            return content.insetBy(dx: -0.001, dy: 0).contains(target.inputFrame)
        }
        let bank = layout.interface.controlsPlacement == .trailingRail
            ? layout.interface.controlsFrame : layout.interface.safeFrame
        return cg(bank).insetBy(dx: -0.001, dy: 0).contains(target.inputFrame)
    }

    static func hudVisibleInputFrame(_ target: MobileHUDRenderer.Item, layout: MobileHUDLayout) -> CGRect {
        if case .skill = target.action, let deck = layout.portrait {
            return target.inputFrame.intersection(deck.skills)
        }
        return target.inputFrame
    }

    static func hudScrollTargetIsReachable(_ target: MobileHUDRenderer.Item, layout: MobileHUDLayout) -> Bool {
        guard case .skill = target.action, let deck = layout.portrait else { return true }
        let offset = min(max(0, target.inputFrame.minX - deck.skills.minX), max(0, deck.skillContentWidth - deck.skills.width))
        let visible = target.inputFrame.offsetBy(dx: -offset, dy: 0).intersection(deck.skills)
        return visible.width >= 44 - 0.001 && visible.height >= 44
    }
}
