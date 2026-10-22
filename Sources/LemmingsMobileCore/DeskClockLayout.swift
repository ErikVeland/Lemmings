import Foundation

/// Where the Desk Clock puts its scene and close control. UIKit and the headless menu audit share it.
public struct DeskClockLayout: Equatable, Sendable {
    /// The scene fills this frame at the largest whole scale that fits. It shows the next event itself.
    public var scene: MobileRect
    /// The lower pane in Stacked pose, which holds only the close control. Nil in every other pose.
    public var pane: MobileRect?
    /// Always visible in Stacked pose. Elsewhere it shows for a few seconds after a touch.
    public var close: MobileRect

    public static let closeSize = (width: 160.0, height: 52.0)
    static let margin = 16.0

    public var stacked: Bool { pane != nil }

    public static func make(safe: MobileRect, regions: [MobileReservedRegion]) -> DeskClockLayout {
        let panes = MobileDisplayRegions.tablePanes(in: safe, avoiding: regions)
        // Book pose keeps the scene on one side of the hinge, as the menus do.
        let scene = panes.count == 2 ? panes[0] : MobileDisplayRegions.menuFrame(in: safe, avoiding: regions)
        let host = panes.count == 2 ? panes[1] : scene
        let close = MobileRect(x: host.minX + margin, y: host.maxY - margin - closeSize.height,
                               width: min(closeSize.width, host.width - 2 * margin), height: closeSize.height)
        return DeskClockLayout(scene: scene, pane: panes.count == 2 ? panes[1] : nil, close: close)
    }
}
