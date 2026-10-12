import CoreGraphics
import Foundation

/// Where the Classic panel sits. The panel keeps the Mac app's proportions and whole-number scale.
public struct MobilePanelMetrics: Equatable, Sendable {
    /// The original 320×40 bar, drawn at a whole-number scale.
    public let frame: CGRect
    public let scale: CGFloat
    public let speedArrows: [CGRect]
    /// The map beside the speed control, positioned as in the Mac panel.
    public let minimap: CGRect

    public var bevel: CGFloat { max(1, scale / 2) }
}

public struct MobileHUDLayout: Equatable, Sendable {
    public let interface: MobileInterfaceLayout
    public let panel: MobilePanelMetrics?
    /// Whole-number scale of the panel art inside the touch grid used on narrow screens. Zero beside a panel.
    public let compactScale: CGFloat
    /// The slower and faster arrows over the speed control.
    public let speedArrows: [CGRect]

    /// The panel keeps its Mac layout on wide screens. A narrow screen keeps touch-sized cells.
    public var canPlay: Bool { !interface.controlFrames.isEmpty && interface.playfieldFrame.height >= 88 }
    public let reservedRegions: [MobileReservedRegion]
    public let supportsRewind: Bool
    public let isDiorama: Bool

    public static let panelWidth: CGFloat = 320
    public static let panelHeight: CGFloat = 40
    public static let rowHeight: CGFloat = 44

    public static func make(container: MobileSize, safeArea: MobileInsets, hasRate: Bool, skillCount: Int,
                            reservedRegions: [MobileReservedRegion] = [], supportsRewind: Bool = false) -> MobileHUDLayout {
        let controlCount = (hasRate ? 2 : 0) + max(0, skillCount) + (supportsRewind ? 7 : 5)
        let base = MobileLayoutEngine.make(container: container, safeArea: safeArea, controlCount: 0)
        let safe = base.safeFrame
        let horizontal = horizontalDivision(in: safe, regions: reservedRegions)
        let deck = horizontal.map {
            MobileRect(x: safe.x, y: $0.frame.maxY, width: safe.width, height: safe.maxY - $0.frame.maxY)
        } ?? safe
        let bank = MobileDisplayRegions.freeFrames(in: deck, avoiding: reservedRegions)
            .filter { $0.width >= 960 && $0.height >= 284 }
            .max { $0.width * $0.height < $1.width * $1.height }
        let scale = min(4, floor((bank?.width ?? 0) / panelWidth))
        // At 3×, the original sockets also meet the 44-point touch minimum.
        guard hasRate, skillCount == 8, let bank, scale >= 3,
              bank.height >= panelHeight * scale + rowHeight + 120 else {
            return compact(base: base, controlCount: controlCount, regions: reservedRegions, supportsRewind: supportsRewind)
        }
        let row = MobileRect(x: bank.minX, y: bank.maxY - rowHeight, width: bank.width, height: rowHeight)
        let panelFrame = CGRect(
            x: bank.minX + floor((bank.width - panelWidth * scale) / 2),
            y: row.y - panelHeight * scale,
            width: panelWidth * scale,
            height: panelHeight * scale
        )
        let cell = 16 * scale
        func cellFrame(_ index: Int, units: CGFloat = 1) -> MobileRect {
            MobileRect(x: panelFrame.minX + cell * CGFloat(index), y: panelFrame.minY + 16 * scale,
                       width: cell * units, height: 24 * scale)
        }
        let buttonWidth = supportsRewind ? CGFloat(44) : min(120, row.width / 4)
        let gap: CGFloat = 4
        let menu = MobileRect(x: row.maxX - buttonWidth - gap, y: row.y, width: buttonWidth, height: row.height)
        let step = MobileRect(x: menu.x - buttonWidth - gap, y: menu.y, width: buttonWidth, height: menu.height)
        var frames = (0..<12).map { cellFrame($0) }
        let speed = cellFrame(12, units: 3)
        frames.append(speed)
        if supportsRewind {
            frames.append(MobileRect(x: step.x - 2 * (buttonWidth + gap), y: step.y, width: buttonWidth, height: step.height))
            frames.append(MobileRect(x: step.x - buttonWidth - gap, y: step.y, width: buttonWidth, height: step.height))
        }
        frames.append(step)
        frames.append(menu)

        let arrowWidth = max(44, speed.width * 0.22)
        let arrows = [
            CGRect(x: speed.x, y: speed.y, width: arrowWidth, height: speed.height),
            CGRect(x: speed.x + speed.width - arrowWidth, y: speed.y, width: arrowWidth, height: speed.height),
        ]
        let layout = MobileInterfaceLayout(
            orientation: base.orientation,
            safeFrame: safe,
            playfieldFrame: MobileRect(x: safe.minX, y: safe.minY, width: safe.width,
                                       height: max(0, (horizontal?.frame.minY ?? panelFrame.minY) - safe.minY)),
            statusFrame: row,
            controlsFrame: MobileRect(x: panelFrame.minX, y: panelFrame.minY,
                                      width: panelFrame.width, height: panelFrame.height + row.height),
            controlFrames: frames
        )
        return MobileHUDLayout(interface: layout,
                               panel: MobilePanelMetrics(
                                   frame: panelFrame, scale: scale, speedArrows: arrows,
                                   minimap: CGRect(x: panelFrame.minX + 256 * scale, y: panelFrame.minY + 18 * scale,
                                                   width: 60 * scale, height: 20 * scale)),
                               compactScale: 0, speedArrows: arrows, reservedRegions: reservedRegions, supportsRewind: supportsRewind, isDiorama: horizontal != nil)
    }

    /// A grid of touch-sized sockets. Each holds the panel art at a whole-number scale,
    /// with its count above and its name below.
    private static func horizontalDivision(in safe: MobileRect, regions: [MobileReservedRegion]) -> MobileReservedRegion? {
        regions.filter {
            $0.kind == .division && $0.frame.width >= safe.width * 0.7 && $0.frame.height < $0.frame.width
                && $0.frame.minY > safe.minY && $0.frame.maxY < safe.maxY
        }.sorted { $0.frame.minY < $1.frame.minY }.first
    }

    private static func compact(base: MobileInterfaceLayout, controlCount: Int,
                                regions: [MobileReservedRegion], supportsRewind: Bool) -> MobileHUDLayout {
        let safe = base.safeFrame
        let horizontal = horizontalDivision(in: safe, regions: regions)
        let deckSafe = horizontal.map {
            MobileRect(x: safe.x, y: $0.frame.maxY, width: safe.width, height: safe.maxY - $0.frame.maxY)
        } ?? safe
        let artScale: CGFloat = safe.height < 440 ? 1 : 2
        let cellHeight: CGFloat = artScale == 1 ? 54 : 80
        let gap: CGFloat = 2
        var candidates: [MobileInterfaceLayout] = []
        for available in MobileDisplayRegions.freeFrames(in: deckSafe, avoiding: regions) {
            let width = min(available.width, 494)
            let x = regions.isEmpty ? available.midX - width / 2 : available.maxX - width
            let bank = MobileRect(x: x, y: available.y, width: width, height: available.height)
            let columns = min(8, Int((bank.width + gap) / (44 + gap)))
            guard columns >= 3 else { continue }
            let cellWidth = (bank.width - gap * CGFloat(columns - 1)) / CGFloat(columns)
            var slots: [(row: Int, column: Int, span: Int)] = []
            var column = 0, row = 0
            for index in 0..<controlCount {
                // Skills and transport form separate groups, as in the Mac panel.
                if index == controlCount - (supportsRewind ? 7 : 5), column > 0 { column = 0; row += 1 }
                // Slower, speed and faster each have a separate 44-point target.
                let span = index == controlCount - (supportsRewind ? 5 : 3) ? 3 : index == controlCount - 1 ? 2 : 1
                if column + span > columns { column = 0; row += 1 }
                slots.append((row, column, span))
                column += span
            }
            let rows = (slots.last?.row ?? 0) + 1
            let controlsHeight = CGFloat(rows) * cellHeight + CGFloat(rows - 1) * gap
            let top = bank.maxY - controlsHeight
            guard top - 26 >= bank.minY else { continue }
            let playBottom = horizontal?.frame.minY ?? (top - 26)
            guard playBottom - safe.minY >= 88 else { continue }
            let frames = slots.map { slot in
                MobileRect(x: bank.minX + CGFloat(slot.column) * (cellWidth + gap),
                           y: top + CGFloat(slot.row) * (cellHeight + gap),
                           width: cellWidth * CGFloat(slot.span) + gap * CGFloat(slot.span - 1), height: cellHeight)
            }
            candidates.append(MobileInterfaceLayout(
                orientation: base.orientation, safeFrame: safe,
                playfieldFrame: MobileRect(x: safe.minX, y: safe.minY, width: safe.width, height: playBottom - safe.minY),
                statusFrame: MobileRect(x: bank.minX, y: top - 26, width: bank.width, height: 26),
                controlsFrame: MobileRect(x: bank.minX, y: top, width: bank.width, height: controlsHeight),
                controlFrames: frames))
        }
        // Keep the deck along the outer bottom edge. Prefer a wider deck when both fit.
        let chosen = candidates.max { lhs, rhs in
            let a = lhs.controlsFrame, b = rhs.controlsFrame
            if a.maxY != b.maxY { return a.maxY < b.maxY }
            if a.width != b.width { return a.width < b.width }
            return a.minX < b.minX
        }
        guard let chosen else {
            let empty = MobileRect(x: safe.minX, y: safe.maxY, width: 0, height: 0)
            return MobileHUDLayout(interface: MobileInterfaceLayout(
                orientation: base.orientation, safeFrame: safe, playfieldFrame: safe,
                statusFrame: empty, controlsFrame: empty, controlFrames: []),
                panel: nil, compactScale: artScale, speedArrows: [], reservedRegions: regions, supportsRewind: supportsRewind, isDiorama: horizontal != nil)
        }
        let speed = chosen.controlFrames[controlCount - (supportsRewind ? 5 : 3)]
        let side = max(44, speed.width / 3)
        let arrows = [CGRect(x: speed.x, y: speed.y, width: side, height: speed.height),
                      CGRect(x: speed.maxX - side, y: speed.y, width: side, height: speed.height)]
        return MobileHUDLayout(interface: chosen, panel: nil, compactScale: artScale,
                               speedArrows: arrows, reservedRegions: regions, supportsRewind: supportsRewind, isDiorama: horizontal != nil)
    }
}
