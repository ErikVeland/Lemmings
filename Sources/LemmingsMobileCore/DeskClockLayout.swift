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

    public static func make(safe: MobileRect, regions: [MobileReservedRegion], bounds: MobileRect? = nil) -> DeskClockLayout {
        let panes = MobileDisplayRegions.tablePanes(in: safe, avoiding: regions)
        // Book pose keeps the scene on one side of the hinge, as the menus do.
        let content = MobileDisplayRegions.menuFrame(in: safe, avoiding: regions)
        let canvas = bounds ?? safe
        let scene: MobileRect
        if panes.count == 2 {
            scene = MobileRect(x: canvas.minX, y: canvas.minY, width: canvas.width,
                               height: panes[0].maxY - canvas.minY)
        } else if regions.contains(where: { $0.kind == .division }) {
            scene = content
        } else {
            scene = canvas
        }
        let host = panes.count == 2 ? panes[1]
            : regions.contains(where: { $0.kind == .division }) ? content : safe
        let close = MobileRect(x: host.minX + margin, y: host.maxY - margin - closeSize.height,
                               width: min(closeSize.width, host.width - 2 * margin), height: closeSize.height)
        return DeskClockLayout(scene: scene, pane: panes.count == 2 ? panes[1] : nil, close: close)
    }
}
