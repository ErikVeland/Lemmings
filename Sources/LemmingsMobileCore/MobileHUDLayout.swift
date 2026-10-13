import CoreGraphics
import Foundation

/// The native panel appearance used by a mobile layout.
public enum MobilePanelStyle: Equatable, Sendable {
    case classic
    case lemmings3
}

public struct MobilePanelMetrics: Equatable, Sendable {
    /// The original 320×40 bar, drawn at a whole-number scale.
    public let frame: CGRect
    public let scale: CGFloat
    public let speedArrows: [CGRect]
    /// The map beside the speed control, positioned as in the Mac panel.
    public let minimap: CGRect
    public let style: MobilePanelStyle

    public var bevel: CGFloat { max(1, scale / 2) }

    public init(frame: CGRect, scale: CGFloat, speedArrows: [CGRect], minimap: CGRect,
                style: MobilePanelStyle = .classic) {
        self.frame = frame
        self.scale = scale
        self.speedArrows = speedArrows
        self.minimap = minimap
        self.style = style
    }
}

public struct MobileHUDLayout: Equatable, Sendable {
    public struct Portrait: Equatable, Sendable {
        public let skills: CGRect
        public let skillContentWidth: CGFloat
        public let rateValue: CGRect?
        public let minimap: CGRect
    }
    public var portrait: Portrait? = nil
    public var minimapFrame: CGRect? {
        if let portrait { return portrait.minimap }
        guard panel?.style != .lemmings3 else { return nil }
        return panel?.minimap
    }
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
                            reservedRegions: [MobileReservedRegion] = [], supportsRewind: Bool = false,
                            hasPlayer: Bool = false, engineIdentifier: String = "classic") -> MobileHUDLayout {
        let controlCount = (hasRate ? 2 : 0) + max(0, skillCount) + (supportsRewind ? 7 : 5)
        let base = MobileLayoutEngine.make(container: container, safeArea: safeArea, controlCount: 0)
        let safe = base.safeFrame
        if engineIdentifier == "lemmings3", base.orientation == .landscape,
           let panel = lemmings3PanelLayout(base: base, reservedRegions: reservedRegions,
                                            supportsRewind: supportsRewind, skillCount: skillCount) {
            return panel
        }
        if base.orientation == .landscape, safe.width >= 400, safe.height >= 258 {
            let landscape = landscapeLayout(base: base, hasRate: hasRate, skillCount: max(0, skillCount),
                                            supportsRewind: supportsRewind, reservedRegions: reservedRegions)
            if portraitControlsFit(landscape, avoiding: reservedRegions) { return landscape }
        }
        if safe.width >= 308, safe.height >= 308 {
            let portrait = portraitLayout(base: base, hasRate: hasRate, skillCount: max(0, skillCount),
                                          supportsRewind: supportsRewind,
                                          reservedRegions: reservedRegions)
            if portraitControlsFit(portrait, avoiding: reservedRegions) { return portrait }
        }
        let horizontal = horizontalDivision(in: safe, regions: reservedRegions)
        let deck = horizontal.map {
            MobileRect(x: safe.x, y: $0.frame.maxY, width: safe.width, height: safe.maxY - $0.frame.maxY)
        } ?? safe
        let bank = MobileDisplayRegions.freeFrames(in: deck, avoiding: reservedRegions)
            .filter { $0.width >= 960 && $0.height >= 284 }
            .max { $0.width * $0.height < $1.width * $1.height }
        let scale: CGFloat = min(4, floor((bank?.width ?? 0) / panelWidth))
        // At 3×, the original sockets also meet the 44-point touch minimum.
        guard hasRate, skillCount == 8, let bank, scale >= 3,
              bank.height >= panelHeight * scale + rowHeight + 120 else {
            return compact(base: base, controlCount: controlCount, regions: reservedRegions, supportsRewind: supportsRewind, hasPlayer: hasPlayer)
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

    private static func lemmings3PanelLayout(base: MobileInterfaceLayout,
                                             reservedRegions: [MobileReservedRegion],
                                             supportsRewind: Bool, skillCount: Int) -> MobileHUDLayout? {
        guard skillCount == 5 else { return nil }
        let safe = base.safeFrame
        let candidates = MobileDisplayRegions.freeFrames(in: safe, avoiding: reservedRegions)
            .filter { $0.width >= 640 && $0.height >= 260 }
        guard let bank = candidates.max(by: { $0.width * $0.height < $1.width * $1.height }) else { return nil }
        let scale = min(4.0, floor(bank.width / Double(Self.panelWidth)))
        guard scale >= 2 else { return nil }

        let scaledPanelWidth = Double(Self.panelWidth) * scale
        let scaledPanelHeight = Double(Self.panelHeight) * scale
        let panelFrame = MobileRect(x: floor(bank.midX - scaledPanelWidth / 2), y: bank.maxY - scaledPanelHeight,
                                    width: scaledPanelWidth, height: scaledPanelHeight)
        let navigationHeight = 44.0
        let statusHeight = 44.0
        let navigation = MobileRect(x: bank.minX, y: panelFrame.minY - navigationHeight,
                                    width: bank.width, height: navigationHeight)
        let status = MobileRect(x: bank.minX, y: navigation.minY - statusHeight,
                               width: bank.width, height: statusHeight)
        let playfieldBottom = status.minY
        guard playfieldBottom - safe.minY >= 88 else { return nil }

        let edges: [Double] = [0, 35, 70, 105, 140, 175, 214, 249, 284, 320]
        func slot(_ index: Int) -> MobileRect {
            MobileRect(x: panelFrame.minX + edges[index] * scale, y: panelFrame.minY,
                       width: (edges[index + 1] - edges[index]) * scale, height: scaledPanelHeight)
        }
        let navigationCount = supportsRewind ? 4 : 2
        let buttonWidth = 44.0
        let gap = 4.0
        let groupWidth = Double(navigationCount) * buttonWidth + Double(navigationCount - 1) * gap
        let startX = navigation.minX + floor((navigation.width - groupWidth) / 2)
        let navFrames = (0..<navigationCount).map { index in
            MobileRect(x: startX + Double(index) * (buttonWidth + gap), y: navigation.minY,
                       width: buttonWidth, height: navigationHeight)
        }
        var controls = (0..<5).map { slot($0) }
        controls += [slot(7), slot(8), slot(6)]
        if supportsRewind { controls += [navFrames[0], navFrames[1]] }
        controls += supportsRewind ? [navFrames[2], navFrames[3]] : navFrames

        guard controls.allSatisfy({ frame in
            safe.contains(.init(x: frame.minX, y: frame.minY))
                && safe.contains(.init(x: frame.maxX, y: frame.maxY))
                && reservedRegions.allSatisfy { !frame.intersects($0.frame) }
        }) else { return nil }

        let interface = MobileInterfaceLayout(
            orientation: base.orientation,
            safeFrame: safe,
            playfieldFrame: MobileRect(x: safe.minX, y: safe.minY, width: safe.width,
                                       height: playfieldBottom - safe.minY),
            statusFrame: status,
            controlsFrame: MobileRect(x: bank.minX, y: navigation.minY, width: bank.width,
                                      height: bank.maxY - navigation.minY),
            controlFrames: controls
        )
        let panel = MobilePanelMetrics(frame: CGRect(x: CGFloat(panelFrame.x), y: CGFloat(panelFrame.y),
                                                    width: CGFloat(panelFrame.width), height: CGFloat(panelFrame.height)),
                                       scale: CGFloat(scale), speedArrows: [],
                                       minimap: .zero, style: .lemmings3)
        return MobileHUDLayout(interface: interface, panel: panel, compactScale: 0,
                               speedArrows: [], reservedRegions: reservedRegions,
                               supportsRewind: supportsRewind, isDiorama: false)
    }

    private static func portraitLayout(base: MobileInterfaceLayout, hasRate: Bool, skillCount: Int,
                                       supportsRewind: Bool,
                                       reservedRegions: [MobileReservedRegion]) -> MobileHUDLayout {
        let safe = base.safeFrame
        let gap: CGFloat = 2, skillHeight: CGFloat = 80, transportHeight: CGFloat = 48
        let skillY = safe.maxY - transportHeight - gap - skillHeight
        let navigationY = skillY - gap - 44
        let skillWidth = max(44, (safe.width - gap * CGFloat(max(0, skillCount - 1))) / CGFloat(max(1, skillCount)))
        let skills = (0..<skillCount).map { index in
            MobileRect(x: safe.minX + CGFloat(index) * (skillWidth + gap), y: skillY,
                       width: skillWidth, height: skillHeight)
        }
        let transportY = skillY + skillHeight + gap
        let rateWidth: CGFloat = hasRate ? 116 : 0
        let groupGap: CGFloat = 4
        let buttonWidth = (safe.width - rateWidth - groupGap * CGFloat(hasRate ? 3 : 2)) / 3
        let start = safe.minX + rateWidth + (hasRate ? groupGap : 0)
        func transport(_ index: Int) -> MobileRect {
            let x = start + CGFloat(index) * (buttonWidth + groupGap)
            return MobileRect(x: x, y: transportY,
                              width: index == 2 ? safe.maxX - x : buttonWidth, height: transportHeight)
        }
        let menu = MobileRect(x: safe.maxX - 44, y: safe.minY, width: 44, height: 44)
        let navigationCount = supportsRewind ? 3 : 1
        func navigation(_ index: Int) -> MobileRect {
            MobileRect(x: safe.minX + CGFloat(index) * 46, y: navigationY, width: 44, height: 44)
        }
        let navigationWidth = CGFloat(navigationCount) * 46 - gap
        let map = CGRect(x: safe.minX + navigationWidth + groupGap, y: navigationY,
                         width: safe.width - navigationWidth - groupGap, height: 44)
        var frames: [MobileRect] = []
        if hasRate {
            frames += [MobileRect(x: safe.minX, y: transportY, width: 44, height: transportHeight),
                       MobileRect(x: safe.minX + 72, y: transportY, width: 44, height: transportHeight)]
        }
        frames += skills + [transport(2), transport(1), transport(0)]
        if supportsRewind { frames += [navigation(0), navigation(1)] }
        frames += [navigation(navigationCount - 1), menu]
        let interface = MobileInterfaceLayout(orientation: base.orientation, safeFrame: safe,
            playfieldFrame: MobileRect(x: safe.minX, y: safe.minY + 44, width: safe.width,
                                      height: navigationY - safe.minY - 44),
            statusFrame: MobileRect(x: safe.minX, y: safe.minY, width: safe.width - 48, height: 44),
            controlsFrame: MobileRect(x: safe.minX, y: navigationY, width: safe.width, height: safe.maxY - navigationY),
            controlFrames: frames)
        return MobileHUDLayout(portrait: Portrait(
            skills: CGRect(x: safe.minX, y: skillY, width: safe.width, height: skillHeight),
            skillContentWidth: CGFloat(skillCount) * (skillWidth + gap) - (skillCount > 0 ? gap : 0),
            rateValue: hasRate ? CGRect(x: safe.minX + 44, y: transportY, width: 28, height: transportHeight) : nil,
            minimap: map),
            interface: interface, panel: nil, compactScale: 2, speedArrows: [],
            reservedRegions: reservedRegions, supportsRewind: supportsRewind, isDiorama: false)
    }

    /// Landscape puts skills and the main controls in one row to preserve playfield height.
    private static func landscapeLayout(base: MobileInterfaceLayout, hasRate: Bool, skillCount: Int,
                                        supportsRewind: Bool, reservedRegions: [MobileReservedRegion]) -> MobileHUDLayout {
        let safe = base.safeFrame
        let height: CGFloat = 80, gap: CGFloat = 2, groupGap: CGFloat = 4
        let rowY = safe.maxY - height
        let navigationY = rowY - gap - 44
        let buttonWidth = min(64, max(44, floor(safe.width * 0.08)))
        let speedWidth = max(72, buttonWidth + 20)
        let rateWidth: CGFloat = hasRate ? 116 : 0
        let transportWidth = rateWidth + speedWidth + 2 * buttonWidth + groupGap * CGFloat(hasRate ? 3 : 2)
        let transportX = safe.maxX - transportWidth
        let skillBankWidth = transportX - safe.minX - groupGap
        let skillWidth = max(44, (skillBankWidth - gap * CGFloat(max(0, skillCount - 1))) / CGFloat(max(1, skillCount)))
        let skills = (0..<skillCount).map { index in
            MobileRect(x: safe.minX + CGFloat(index) * (skillWidth + gap), y: rowY,
                       width: skillWidth, height: height)
        }
        let speedX = transportX + rateWidth + (hasRate ? groupGap : 0)
        let speed = MobileRect(x: speedX, y: rowY, width: speedWidth, height: height)
        let nuke = MobileRect(x: speed.maxX + groupGap, y: rowY, width: buttonWidth, height: height)
        let pause = MobileRect(x: nuke.maxX + groupGap, y: rowY, width: safe.maxX - nuke.maxX - groupGap, height: height)
        let navigationCount = supportsRewind ? 3 : 1
        func navigation(_ index: Int) -> MobileRect {
            MobileRect(x: safe.minX + CGFloat(index) * 46, y: navigationY, width: 44, height: 44)
        }
        let navigationWidth = CGFloat(navigationCount) * 46 - gap
        let map = CGRect(x: safe.minX + navigationWidth + groupGap, y: navigationY,
                         width: safe.width - navigationWidth - groupGap, height: 44)
        let menu = MobileRect(x: safe.maxX - 44, y: safe.minY, width: 44, height: 44)
        var frames: [MobileRect] = []
        if hasRate {
            frames += [MobileRect(x: transportX, y: rowY, width: 44, height: height),
                       MobileRect(x: transportX + 72, y: rowY, width: 44, height: height)]
        }
        frames += skills + [pause, nuke, speed]
        if supportsRewind { frames += [navigation(0), navigation(1)] }
        frames += [navigation(navigationCount - 1), menu]
        let interface = MobileInterfaceLayout(orientation: base.orientation, safeFrame: safe,
            playfieldFrame: MobileRect(x: safe.minX, y: safe.minY + 44, width: safe.width,
                                      height: navigationY - safe.minY - 44),
            statusFrame: MobileRect(x: safe.minX, y: safe.minY, width: safe.width - 48, height: 44),
            controlsFrame: MobileRect(x: safe.minX, y: navigationY, width: safe.width, height: safe.maxY - navigationY),
            controlFrames: frames)
        return MobileHUDLayout(portrait: Portrait(
            skills: CGRect(x: safe.minX, y: rowY, width: skillBankWidth, height: height),
            skillContentWidth: CGFloat(skillCount) * (skillWidth + gap) - (skillCount > 0 ? gap : 0),
            rateValue: hasRate ? CGRect(x: transportX + 44, y: rowY, width: 28, height: height) : nil,
            minimap: map), interface: interface, panel: nil, compactScale: 2, speedArrows: [],
            reservedRegions: reservedRegions, supportsRewind: supportsRewind, isDiorama: false)
    }

    private static func portraitControlsFit(_ layout: MobileHUDLayout,
                                            avoiding regions: [MobileReservedRegion]) -> Bool {
        guard let portrait = layout.portrait, let menu = layout.interface.controlFrames.last else { return false }
        func rect(_ frame: CGRect) -> MobileRect {
            MobileRect(x: frame.minX, y: frame.minY, width: frame.width, height: frame.height)
        }
        // Check the visible scroll bank and navigation row before placing fixed controls.
        let occupied = [layout.interface.controlsFrame, layout.interface.statusFrame, menu,
                        rect(portrait.minimap)]
            + layout.interface.controlFrames.suffix(layout.supportsRewind ? 3 : 2)
        return !regions.contains { region in
            let frame = region.frame
            guard frame.x.isFinite, frame.y.isFinite, frame.width.isFinite, frame.height.isFinite,
                  frame.width > 0, frame.height > 0,
                  frame.intersects(layout.interface.safeFrame) else { return false }
            return region.kind == .division || occupied.contains { $0.intersects(frame) }
        }
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
                                regions: [MobileReservedRegion], supportsRewind: Bool, hasPlayer: Bool) -> MobileHUDLayout {
        let safe = base.safeFrame
        let statusHeight: CGFloat = hasPlayer ? 44 : 26
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
            guard top - statusHeight >= bank.minY else { continue }
            let playBottom = horizontal?.frame.minY ?? (top - statusHeight)
            guard playBottom - safe.minY >= 88 else { continue }
            let frames = slots.map { slot in
                MobileRect(x: bank.minX + CGFloat(slot.column) * (cellWidth + gap),
                           y: top + CGFloat(slot.row) * (cellHeight + gap),
                           width: cellWidth * CGFloat(slot.span) + gap * CGFloat(slot.span - 1), height: cellHeight)
            }
            candidates.append(MobileInterfaceLayout(
                orientation: base.orientation, safeFrame: safe,
                playfieldFrame: MobileRect(x: safe.minX, y: safe.minY, width: safe.width, height: playBottom - safe.minY),
                statusFrame: MobileRect(x: bank.minX, y: top - statusHeight, width: bank.width, height: statusHeight),
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
