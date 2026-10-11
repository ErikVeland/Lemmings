#if os(iOS)
import LemmingsMobileCore
import UIKit

/// Where the Classic panel sits. The panel keeps the Mac app's proportions and whole-number scale.
struct MobilePanelMetrics: Equatable {
    /// The original 320×40 bar, drawn at a whole-number scale.
    let frame: CGRect
    let scale: CGFloat
    let speedArrows: [CGRect]
    /// The map beside the speed control, positioned as in the Mac panel.
    let minimap: CGRect

    var bevel: CGFloat { max(1, scale / 2) }
}

struct MobileHUDLayout: Equatable {
    let interface: MobileInterfaceLayout
    let panel: MobilePanelMetrics?

    /// The panel keeps its Mac layout on wide screens. A narrow screen keeps touch-sized cells.
    static let panelWidth: CGFloat = 320
    static let panelHeight: CGFloat = 40
    static let rowHeight: CGFloat = 44

    static func make(container: MobileSize, safeArea: MobileInsets, hasRate: Bool, skillCount: Int) -> MobileHUDLayout {
        let controlCount = (hasRate ? 2 : 0) + skillCount + 5
        let base = MobileLayoutEngine.make(container: container, safeArea: safeArea, controlCount: controlCount)
        let safe = base.safeFrame
        let scale = floor(safe.width / panelWidth)
        guard hasRate, skillCount == 8, scale >= 2,
              safe.height >= panelHeight * scale + rowHeight + 120 else {
            return MobileHUDLayout(interface: base, panel: nil)
        }

        let row = MobileRect(x: safe.minX, y: safe.maxY - rowHeight, width: safe.width, height: rowHeight)
        let panelFrame = CGRect(
            x: safe.minX + floor((safe.width - panelWidth * scale) / 2),
            y: row.y - panelHeight * scale,
            width: panelWidth * scale,
            height: panelHeight * scale
        )
        let cell = 16 * scale
        func cellFrame(_ index: Int, units: CGFloat = 1) -> MobileRect {
            MobileRect(x: panelFrame.minX + cell * CGFloat(index), y: panelFrame.minY + 16 * scale,
                       width: cell * units, height: 24 * scale)
        }
        let buttonWidth = min(120, row.width / 4)
        let gap: CGFloat = 4
        let menu = MobileRect(x: row.maxX - buttonWidth - gap, y: row.y + 4, width: buttonWidth, height: row.height - 8)
        let step = MobileRect(x: menu.x - buttonWidth - gap, y: menu.y, width: buttonWidth, height: menu.height)
        var frames = (0..<12).map { cellFrame($0) }
        let speed = cellFrame(12, units: 3)
        frames.append(speed)
        frames.append(step)
        frames.append(menu)

        let arrowWidth = speed.width * 0.22
        let arrows = [
            CGRect(x: speed.x, y: speed.y, width: arrowWidth, height: speed.height),
            CGRect(x: speed.x + speed.width - arrowWidth, y: speed.y, width: arrowWidth, height: speed.height),
        ]
        let layout = MobileInterfaceLayout(
            orientation: base.orientation,
            safeFrame: safe,
            playfieldFrame: MobileRect(x: safe.minX, y: safe.minY, width: safe.width,
                                       height: max(0, panelFrame.minY - safe.minY)),
            statusFrame: row,
            controlsFrame: MobileRect(x: panelFrame.minX, y: panelFrame.minY,
                                      width: panelFrame.width, height: panelFrame.height + row.height),
            controlFrames: frames
        )
        return MobileHUDLayout(interface: layout,
                               panel: MobilePanelMetrics(
                                   frame: panelFrame, scale: scale, speedArrows: arrows,
                                   minimap: CGRect(x: panelFrame.minX + 256 * scale, y: panelFrame.minY + 18 * scale,
                                                   width: 60 * scale, height: 20 * scale)))
    }
}
#endif
