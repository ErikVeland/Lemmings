import Foundation

/// Where the Desk Clock puts its scene, event lines and close control. UIKit and the headless menu audit share it.
public struct DeskClockLayout: Equatable, Sendable {
    /// The scene fills this frame at the largest whole scale that fits.
    public var scene: MobileRect
    /// The lower pane in Stacked pose. Nil in every other pose.
    public var pane: MobileRect?
    /// The event lines in the lower pane: the title line, then the countdown.
    public var lines: [MobileRect]
    /// Always visible in Stacked pose. Elsewhere it shows for a few seconds after a touch.
    public var close: MobileRect

    public static let closeSize = (width: 160.0, height: 52.0)
    static let margin = 16.0

    public var stacked: Bool { pane != nil }

    public static func make(safe: MobileRect, regions: [MobileReservedRegion]) -> DeskClockLayout {
        let panes = MobileDisplayRegions.tablePanes(in: safe, avoiding: regions)
        if panes.count == 2 {
            let pane = panes[1]
            let close = MobileRect(x: pane.minX + margin, y: pane.maxY - margin - closeSize.height,
                                   width: min(closeSize.width, pane.width - 2 * margin), height: closeSize.height)
            let text = MobileRect(x: pane.minX + margin, y: pane.minY + margin,
                                  width: pane.width - 2 * margin, height: max(0, close.minY - margin - pane.minY - margin))
            let lineHeight = min(60, text.height / 2)
            let top = text.minY + max(0, (text.height - 2 * lineHeight) / 2)
            let lines = (0..<2).map {
                MobileRect(x: text.minX, y: top + Double($0) * lineHeight, width: text.width, height: lineHeight)
            }
            return DeskClockLayout(scene: panes[0], pane: pane, lines: lines, close: close)
        }
        // Book pose keeps the scene on one side of the hinge, as the menus do.
        let scene = MobileDisplayRegions.menuFrame(in: safe, avoiding: regions)
        let close = MobileRect(x: scene.minX + margin, y: scene.maxY - margin - closeSize.height,
                               width: min(closeSize.width, scene.width - 2 * margin), height: closeSize.height)
        return DeskClockLayout(scene: scene, pane: nil, lines: [], close: close)
    }
}
