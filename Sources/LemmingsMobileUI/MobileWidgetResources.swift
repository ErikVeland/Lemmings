#if os(iOS) || os(tvOS)
import Foundation
import LemmingsAppCore
import LemmingsGameArt
import LemmingsMobileCore
#if os(iOS)
import WidgetKit
import os
#endif

/**
 * Shares selected clock artwork without changing the game's resource tree.
 */
@MainActor enum MobileWidgetResources {
    static func publish() {
        #if os(iOS)
        guard MobileResourceAccess.isStore else { return }
        do {
            let changed = try GameDeskClockResources.publish(
                resourceURL: GameArtworkSkin.usesLixInterface ? nil : GameResources.resourceURL,
                containerURL: GameDeskClockResources.sharedContainerURL)
            if changed { WidgetCenter.shared.reloadTimelines(ofKind: "DeskClock") }
        } catch {
            Logger(subsystem: "academy.glasscode.ultimatelemmix", category: "resources")
                .error("Could not share Desk Clock artwork: \(error.localizedDescription)")
        }
        #endif
    }
}
#endif
