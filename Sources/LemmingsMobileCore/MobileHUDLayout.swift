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
    /// Visible status banks can straddle a division without placing text under it.
    public var statusBanks: [MobileRect] {
        MobileDisplayRegions.freeFrames(in: interface.statusFrame, avoiding: reservedRegions)
            .sorted { $0.minX < $1.minX }
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
    public private(set) var showsMenuButton = true
    public private(set) var television = false

    public static let panelWidth: CGFloat = 320
    public static let panelHeight: CGFloat = 40
    public static let rowHeight: CGFloat = 44

    public static func make(container: MobileSize, safeArea: MobileInsets, hasRate: Bool, skillCount: Int,
                            reservedRegions: [MobileReservedRegion] = [], supportsRewind: Bool = false,
                            hasPlayer: Bool = false, engineIdentifier: String = "classic",
                            showsMenuButton: Bool = true, television: Bool = false,
                            topBarInsets: MobileInsets = .init(), navigationRail: MobileRect? = nil,
                            fillsDisplayWidth: Bool = false, menuLeading: Bool = false) -> MobileHUDLayout {
        let systemRegions = reservedRegions
        let reservedRegions = fillsDisplayWidth ? reservedRegions.filter { $0.kind == .division } : reservedRegions
        var layout = navigationRail.flatMap {
            navigationRailLayout(container: container, safeArea: safeArea, rail: $0,
                hasRate: hasRate, skillCount: max(0, skillCount), supportsRewind: supportsRewind,
                reservedRegions: reservedRegions)
        } ?? makeTouchLayout(container: container, safeArea: safeArea, hasRate: hasRate,
            skillCount: skillCount, reservedRegions: reservedRegions, supportsRewind: supportsRewind,
            hasPlayer: hasPlayer, engineIdentifier: engineIdentifier)
        if fillsDisplayWidth, layout.interface.controlsPlacement != .trailingRail {
            // A rotated front camera can sit at the bottom. Keep the entire fixed deck
            // above it rather than dropping the occlusion or reshaping individual skills.
            let deckFrames = Array(layout.interface.controlFrames.dropLast()) + [layout.minimapFrame].compactMap { frame in
                frame.map { MobileRect(x: $0.minX, y: $0.minY, width: $0.width, height: $0.height) }
            }
            let blocking = systemRegions.filter { region in
                region.kind == .occlusion && deckFrames.contains { $0.intersects(region.frame) }
            }
            if !blocking.isEmpty {
                let clear = MobileDisplayRegions.scrollingMenuFrame(in: layout.interface.safeFrame, avoiding: blocking)
                let clearance = MobileInsets(top: clear.minY, left: clear.minX,
                    bottom: max(0, container.height - clear.maxY), right: max(0, container.width - clear.maxX))
                layout = makeTouchLayout(container: container, safeArea: clearance, hasRate: hasRate,
                    skillCount: skillCount, reservedRegions: reservedRegions, supportsRewind: supportsRewind,
                    hasPlayer: hasPlayer, engineIdentifier: engineIdentifier)
            }
        }
        layout = topStatusLayout(layout, television: television)
        if fillsDisplayWidth {
            layout = MobileHUDLayout(portrait: layout.portrait, interface: layout.interface, panel: layout.panel,
                compactScale: layout.compactScale, speedArrows: layout.speedArrows,
                reservedRegions: systemRegions, supportsRewind: layout.supportsRewind,
                isDiorama: layout.isDiorama, showsMenuButton: layout.showsMenuButton, television: layout.television)
        }
        if fillsDisplayWidth, !television { layout = extendingPlayfield(layout, width: container.width) }
        var headerInsets = topBarInsets
        if fillsDisplayWidth {
            let safe = layout.interface.safeFrame
            let header = MobileRect(x: safe.minX, y: safe.minY, width: safe.width, height: rowHeight)
            let clear = MobileDisplayRegions.clearHorizontalFrame(header, avoiding: systemRegions)
            headerInsets = MobileInsets(left: clear.minX - header.minX, right: header.maxX - clear.maxX)
        }
        guard !showsMenuButton else { return insettingHeader(layout, by: headerInsets, menuLeading: menuLeading) }
        let original = layout.interface
        // Console navigation comes from Back or Options/Menu, with no HUD target.
        let status = original.statusFrame.minY == original.safeFrame.minY
            ? MobileRect(x: original.statusFrame.x, y: original.statusFrame.y,
                         width: original.safeFrame.width, height: original.statusFrame.height)
            : original.statusFrame
        let interface = MobileInterfaceLayout(orientation: original.orientation, safeFrame: original.safeFrame,
            playfieldFrame: original.playfieldFrame, statusFrame: status,
            controlsFrame: original.controlsFrame, controlFrames: Array(original.controlFrames.dropLast()),
            controlsPlacement: original.controlsPlacement)
        let console = MobileHUDLayout(portrait: layout.portrait, interface: interface, panel: layout.panel,
            compactScale: layout.compactScale, speedArrows: layout.speedArrows,
            reservedRegions: layout.reservedRegions, supportsRewind: layout.supportsRewind,
            isDiorama: layout.isDiorama, showsMenuButton: false, television: layout.television)
        return insettingHeader(console, by: headerInsets)
    }

    /// Scenery reaches behind the outer display's vertical system bar. Controls retain their safe targets.
    private static func extendingPlayfield(_ layout: MobileHUDLayout, width: Double) -> MobileHUDLayout {
        let original = layout.interface
        guard original.controlsPlacement != .trailingRail,
              !layout.reservedRegions.contains(where: { $0.kind == .division }),
              original.playfieldFrame.width == original.safeFrame.width else { return layout }
        let interface = MobileInterfaceLayout(orientation: original.orientation, safeFrame: original.safeFrame,
            playfieldFrame: .init(x: 0, y: original.playfieldFrame.y, width: width,
                                 height: original.playfieldFrame.height),
            statusFrame: original.statusFrame, controlsFrame: original.controlsFrame,
            controlFrames: original.controlFrames, controlsPlacement: original.controlsPlacement)
        return MobileHUDLayout(portrait: layout.portrait, interface: interface, panel: layout.panel,
            compactScale: layout.compactScale, speedArrows: layout.speedArrows,
            reservedRegions: layout.reservedRegions, supportsRewind: layout.supportsRewind,
            isDiorama: layout.isDiorama, showsMenuButton: layout.showsMenuButton, television: layout.television)
    }

    /// Move the visible header and its input/accessibility targets together, without changing gameplay.
    private static func insettingHeader(_ layout: MobileHUDLayout, by insets: MobileInsets,
                                        menuLeading: Bool = false) -> MobileHUDLayout {
        let original = layout.interface
        let safe = original.safeFrame
        guard original.statusFrame.minY == safe.minY,
              insets.left > 0 || insets.right > 0 || menuLeading else { return layout }
        let left = safe.minX + max(0, insets.left.mobileFiniteOrZero)
        let right = safe.maxX - max(0, insets.right.mobileFiniteOrZero)
        var frames = original.controlFrames
        var statusLeft = max(left, original.statusFrame.minX)
        var statusRight = min(right, original.statusFrame.maxX)
        if layout.showsMenuButton, original.controlsPlacement != .trailingRail,
           let menu = frames.last, menu.minY == safe.minY {
            if menuLeading {
                frames[frames.count - 1].x = left
                statusLeft = left + menu.width + 4
                statusRight = right
            } else {
                frames[frames.count - 1].x = right - menu.width
                statusRight = right - menu.width - 4
            }
        }
        let status = MobileRect(x: statusLeft, y: original.statusFrame.minY,
            width: max(0, statusRight - statusLeft), height: original.statusFrame.height)
        let interface = MobileInterfaceLayout(orientation: original.orientation, safeFrame: safe,
            playfieldFrame: original.playfieldFrame, statusFrame: status,
            controlsFrame: original.controlsFrame, controlFrames: frames, controlsPlacement: original.controlsPlacement)
        return MobileHUDLayout(portrait: layout.portrait, interface: interface, panel: layout.panel,
            compactScale: layout.compactScale, speedArrows: layout.speedArrows,
            reservedRegions: layout.reservedRegions, supportsRewind: layout.supportsRewind,
            isDiorama: layout.isDiorama, showsMenuButton: layout.showsMenuButton, television: layout.television)
    }

    /// One broadcast-style row above gameplay, shared by all mobile engines.
    private static func topStatusLayout(_ layout: MobileHUDLayout, television: Bool) -> MobileHUDLayout {
        let original = layout.interface
        guard !original.controlFrames.isEmpty else { return layout }
        if original.controlsPlacement == .trailingRail { return layout }
        if layout.isDiorama, layout.portrait != nil { return layout }
        let safe = original.safeFrame
        let oldStatus = original.statusFrame
        let top = MobileRect(x: safe.minX, y: safe.minY, width: safe.width, height: rowHeight)
        // Split screens and system occlusions retain their existing unobstructed bank.
        guard layout.reservedRegions.allSatisfy({ !top.intersects($0.frame) }) else { return layout }
        let menu = original.controlFrames.last
        let menuAtTop = menu.map { $0.minY == safe.minY } ?? false
        let status = MobileRect(x: top.x, y: top.y,
            width: top.width - (menuAtTop ? 48 : 0), height: top.height)
        // Reclaim the old status row only when it sat directly below the playfield.
        let bottom = oldStatus.minY == original.playfieldFrame.maxY
            ? oldStatus.maxY : original.playfieldFrame.maxY
        let interface = MobileInterfaceLayout(orientation: original.orientation, safeFrame: safe,
            playfieldFrame: MobileRect(x: original.playfieldFrame.minX, y: status.maxY,
                width: original.playfieldFrame.width, height: max(0, bottom - status.maxY)),
            statusFrame: status, controlsFrame: original.controlsFrame, controlFrames: original.controlFrames)
        return MobileHUDLayout(portrait: layout.portrait, interface: interface, panel: layout.panel,
            compactScale: layout.compactScale, speedArrows: layout.speedArrows,
            reservedRegions: layout.reservedRegions, supportsRewind: layout.supportsRewind,
            isDiorama: layout.isDiorama, television: television)
    }

    /// Use the system's vertical navigation space without narrowing the gameplay safe area.
    private static func navigationRailLayout(container: MobileSize, safeArea: MobileInsets, rail: MobileRect,
                                             hasRate: Bool, skillCount: Int, supportsRewind: Bool,
                                             reservedRegions: [MobileReservedRegion]) -> MobileHUDLayout? {
        let base = MobileLayoutEngine.make(container: container, safeArea: safeArea, controlCount: 0)
        let safe = base.safeFrame
        let bounds = MobileRect(x: 0, y: 0, width: container.width, height: container.height)
        guard rail.x.isFinite, rail.y.isFinite, rail.width.isFinite, rail.height.isFinite,
              rail.width >= 44, rail.height > 0, safe.width >= 308, safe.height >= 308,
              !rail.intersects(safe), bounds.contains(.init(x: rail.minX, y: rail.minY)),
              bounds.contains(.init(x: rail.maxX, y: rail.maxY)),
              reservedRegions.allSatisfy({ !$0.frame.intersects(rail) && !$0.frame.intersects(safe) })
        else { return nil }

        let gap = 2.0
        let height = 44.0
        let skillHeight = 80.0
        // Share the lower baseline while respecting the rail's corner clearance.
        let bottom = min(safe.maxY, rail.maxY)
        let skillY = bottom - skillHeight
        let map = CGRect(x: safe.minX, y: skillY - gap - height, width: safe.width, height: height)
        let groupGap = 12.0
        func button(_ y: Double) -> MobileRect {
            .init(x: rail.minX, y: y, width: rail.width, height: height)
        }
        let menu = button(rail.minY)
        var nextY = menu.maxY + groupGap
        var navigation: [MobileRect] = []
        for _ in 0..<(supportsRewind ? 3 : 1) {
            navigation.append(button(nextY)); nextY += height + gap
        }
        let pause = MobileRect(x: rail.minX, y: skillY, width: rail.width, height: skillHeight)
        let end = button(map.minY)
        let speed = button(end.minY - gap - height)
        var rate: [MobileRect] = []
        var rateValue: CGRect?
        var transportTop = speed.minY
        if hasRate {
            let valueHeight = 28.0
            let faster = button(speed.minY - groupGap - height)
            let slower = button(faster.minY - valueHeight - height)
            rateValue = CGRect(x: rail.minX, y: slower.maxY, width: rail.width, height: valueHeight)
            rate = [slower, faster]
            transportTop = slower.minY
        }
        guard nextY + groupGap - gap <= transportTop,
              map.minY - safe.minY - height >= 88 else { return nil }

        let skillWidth = max(44, (safe.width - 2 * Double(max(0, skillCount - 1))) / Double(max(1, skillCount)))
        let skills = (0..<skillCount).map {
            MobileRect(x: safe.minX + Double($0) * (skillWidth + 2), y: skillY, width: skillWidth, height: skillHeight)
        }
        let interface = MobileInterfaceLayout(orientation: base.orientation, safeFrame: safe,
            playfieldFrame: .init(x: safe.minX, y: safe.minY + 44, width: safe.width,
                                 height: map.minY - safe.minY - 44),
            statusFrame: .init(x: safe.minX, y: safe.minY, width: safe.width, height: 44),
            controlsFrame: rail,
            controlFrames: rate + skills + [pause, end, speed] + navigation + [menu],
            controlsPlacement: .trailingRail)
        return MobileHUDLayout(portrait: Portrait(
            skills: CGRect(x: safe.minX, y: skillY, width: safe.width, height: skillHeight),
            skillContentWidth: Double(skillCount) * (skillWidth + 2) - (skillCount > 0 ? 2 : 0),
            rateValue: rateValue, minimap: map), interface: interface, panel: nil,
            compactScale: 2, speedArrows: [], reservedRegions: reservedRegions,
            supportsRewind: supportsRewind, isDiorama: false)
    }

    private static func makeTouchLayout(container: MobileSize, safeArea: MobileInsets, hasRate: Bool, skillCount: Int,
                                       reservedRegions: [MobileReservedRegion], supportsRewind: Bool,
                                       hasPlayer: Bool, engineIdentifier: String) -> MobileHUDLayout {
        let controlCount = (hasRate ? 2 : 0) + max(0, skillCount) + (supportsRewind ? 7 : 5)
        let base = MobileLayoutEngine.make(container: container, safeArea: safeArea, controlCount: 0)
        let safe = base.safeFrame
        // Landscape screens with room for the 3× panel keep the Mac layout before the phone grids.
        // Only Classic ships the panel artwork. A hinge across the screen keeps the panel below it;
        // a hinge down the middle would split the panel, so the divided deck stays.
        let splitsPanel = reservedRegions.contains { $0.kind == .division && $0.frame.height > $0.frame.width }
        if ["classic", "classic-dos"].contains(engineIdentifier), base.orientation == .landscape, !splitsPanel,
           let panel = macPanelLayout(base: base, hasRate: hasRate, skillCount: skillCount,
                                      supportsRewind: supportsRewind, reservedRegions: reservedRegions) { return panel }
        if let divided = dividedLayout(base: base, hasRate: hasRate, skillCount: max(0, skillCount),
            supportsRewind: supportsRewind, regions: reservedRegions) { return divided }
        if engineIdentifier == "lemmings3", base.orientation == .landscape,
           let panel = lemmings3PanelLayout(base: base, reservedRegions: reservedRegions,
                                            supportsRewind: supportsRewind, skillCount: skillCount) {
            return panel
        }
        if base.orientation == .landscape, safe.width >= 400, safe.height >= 258 {
            let landscape = landscapeLayout(base: base, hasRate: hasRate, skillCount: max(0, skillCount),
                                            supportsRewind: supportsRewind, reservedRegions: reservedRegions)
            if let skills = landscape.portrait,
               (safe.height < 308 || skillCount > 8 || skills.skillContentWidth <= skills.skills.width + 0.001),
               portraitControlsFit(landscape, avoiding: reservedRegions) { return landscape }
        }
        if safe.width >= 308, safe.height >= 308 {
            let portrait = portraitLayout(base: base, hasRate: hasRate, skillCount: max(0, skillCount),
                                          supportsRewind: supportsRewind,
                                          reservedRegions: reservedRegions)
            if portraitControlsFit(portrait, avoiding: reservedRegions) { return portrait }
        }
        return macPanelLayout(base: base, hasRate: hasRate, skillCount: skillCount,
                              supportsRewind: supportsRewind, reservedRegions: reservedRegions)
            ?? compact(base: base, controlCount: controlCount, regions: reservedRegions, supportsRewind: supportsRewind, hasPlayer: hasPlayer)
    }

    /// The original panel at a whole 3× or 4× scale, as on the Mac. Wide tablets and an unfolded Duo use it.
    private static func macPanelLayout(base: MobileInterfaceLayout, hasRate: Bool, skillCount: Int,
                                       supportsRewind: Bool, reservedRegions: [MobileReservedRegion]) -> MobileHUDLayout? {
        let safe = base.safeFrame
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
              bank.height >= panelHeight * scale + rowHeight + 120 else { return nil }
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

    /// Gameplay spans the top. Controls fill the lower area, with targets clear of the division.
    private static func dividedLayout(base: MobileInterfaceLayout, hasRate: Bool, skillCount: Int,
                                      supportsRewind: Bool, regions: [MobileReservedRegion]) -> MobileHUDLayout? {
        let safe = base.safeFrame
        guard let division = regions.first(where: {
            $0.kind == .division && $0.frame.intersects(safe)
                && (($0.frame.height >= safe.height * 0.7 && $0.frame.minX > safe.minX && $0.frame.maxX < safe.maxX)
                    || ($0.frame.width >= safe.width * 0.7 && $0.frame.minY > safe.minY && $0.frame.maxY < safe.maxY))
        }) else { return nil }
        let vertical = division.frame.height > division.frame.width
        let lower = vertical
            ? MobileRect(x: safe.minX, y: safe.minY, width: safe.width, height: safe.height)
            : MobileRect(x: safe.minX, y: division.frame.maxY, width: safe.width, height: safe.maxY - division.frame.maxY)
        let paneFrames = vertical ? [
            MobileRect(x: safe.minX, y: lower.minY, width: division.frame.minX - safe.minX, height: lower.height),
            MobileRect(x: division.frame.maxX, y: lower.minY, width: safe.maxX - division.frame.maxX, height: lower.height)
        ] : [lower]
        let counts = vertical ? [(skillCount + 1) / 2, skillCount / 2] : [skillCount]
        func columns(in width: Double, count: Int) -> Int {
            // A tall lower pane is not a reason to split skills into extra rows.
            // Wrap only when the available width cannot keep every target at 44 points.
            max(1, min(count, Int((width + 2) / 46)))
        }
        let rows = zip(paneFrames, counts).map { pane, count in
            max(1, Int(ceil(Double(count) / Double(columns(in: pane.width, count: count)))))
        }.max() ?? 1
        let minimumHeight = Double(rows) * 82 + 94
        let height = vertical ? max(minimumHeight, floor(safe.height * 0.38)) : lower.height
        guard height >= minimumHeight, safe.height - height - 44 >= 88 else { return nil }
        let deck = MobileRect(x: safe.minX, y: safe.maxY - height, width: safe.width, height: height)
        var banks: [MobileRect] = []
        for pane in paneFrames {
            let area = MobileRect(x: pane.minX, y: deck.minY, width: pane.width, height: deck.height)
            // Prefer a full-height bank so the controls still reach the lower edge beside a cutout.
            let candidates = MobileDisplayRegions.freeFrames(in: area, avoiding: regions)
                .filter { $0.width >= (vertical ? 160 : 308) && $0.height >= minimumHeight }
            let fullHeight = candidates.filter { $0.minY == area.minY && $0.maxY == area.maxY }
            guard let bank = (fullHeight.isEmpty ? candidates : fullHeight)
                .max(by: { $0.width * $0.height < $1.width * $1.height }) else { return nil }
            banks.append(bank)
        }
        // All rows use the same vertical bounds, including when a cutout narrows one bank.
        let top = banks.map(\.minY).max() ?? deck.minY
        let bottom = banks.map(\.maxY).min() ?? deck.maxY
        let minimumSkills = Double(rows) * 80 + Double(rows - 1) * 2
        let transportHeight = min(80, max(48, floor((bottom - top) * 0.20)), bottom - top - minimumSkills - 48)
        let narrowestSkill = zip(banks, counts).map { bank, count in
            (bank.width - Double(max(0, columns(in: bank.width, count: count) - 1)) * 2)
                / Double(columns(in: bank.width, count: count))
        }.min() ?? 44
        let preferredSkillHeight = Double(rows) * min(144, max(80, floor(narrowestSkill * 1.25))) + Double(rows - 1) * 2
        let skillHeight = min(preferredSkillHeight, bottom - top - transportHeight - 48)
        let navigationHeight = bottom - top - skillHeight - transportHeight - 4
        let skillY = top + navigationHeight + 2
        let transportY = bottom - transportHeight
        guard skillHeight >= Double(rows) * 80 + Double(rows - 1) * 2 else { return nil }
        let skillArea = CGRect(x: safe.minX, y: skillY, width: safe.width, height: skillHeight)
        var skills: [MobileRect] = []
        for (bank, count) in zip(banks, counts) {
            let columns = columns(in: bank.width, count: count)
            let bankRows = max(1, Int(ceil(Double(count) / Double(columns))))
            let rowHeight = (skillHeight - Double(bankRows - 1) * 2) / Double(bankRows)
            for index in 0..<count {
                let row = index / columns
                let rowCount = min(columns, count - row * columns)
                let width = (bank.width - Double(rowCount - 1) * 2) / Double(rowCount)
                skills.append(MobileRect(x: bank.minX + Double(index % columns) * (width + 2),
                    y: skillY + Double(row) * (rowHeight + 2), width: width, height: rowHeight))
            }
        }
        let leading = banks[0], trailing = banks[banks.count - 1]
        let navigationCount = supportsRewind ? 3 : 1
        let navigationGaps = Double(navigationCount - 1) * 4
        let columnNavigation = !vertical && navigationHeight >= Double(navigationCount) * 44 + navigationGaps
        let minimumNavigationWidth = Double(navigationCount) * 44 + navigationGaps
        let navigationWidth = vertical ? leading.width : columnNavigation ? 64
            : min(leading.width - 48, minimumNavigationWidth)
        let navigationCell = columnNavigation ? navigationWidth
            : (navigationWidth - navigationGaps) / Double(navigationCount)
        let navigationButtonHeight = columnNavigation
            ? min(64, (navigationHeight - navigationGaps) / Double(navigationCount)) : min(64, navigationHeight)
        let navigationY = columnNavigation
            ? top + (navigationHeight - Double(navigationCount) * navigationButtonHeight - navigationGaps) / 2
            : top + navigationHeight - navigationButtonHeight
        guard navigationCell >= 44 else { return nil }
        let navigation = (0..<navigationCount).map {
            MobileRect(x: leading.minX + (columnNavigation ? 0 : Double($0) * (navigationCell + 4)),
                       y: navigationY + (columnNavigation ? Double($0) * (navigationButtonHeight + 4) : 0),
                       width: navigationCell, height: navigationButtonHeight)
        }
        let mapX = vertical ? trailing.minX : leading.minX + navigationWidth + 4
        let map = CGRect(x: mapX, y: top, width: trailing.maxX - mapX, height: navigationHeight)
        let rateWidth = hasRate ? max(116, vertical ? floor(leading.width / 2) - 2 : floor(leading.width / 4) - 3) : 0
        let speedX = leading.minX + (hasRate ? rateWidth + 4 : 0)
        let speedWidth = vertical ? leading.maxX - speedX
            : (leading.width - rateWidth - (hasRate ? 12 : 8)) / 3
        let speed = MobileRect(x: speedX, y: transportY, width: speedWidth, height: transportHeight)
        let nukeX = vertical ? trailing.minX : speed.maxX + 4
        let transportWidth = (trailing.maxX - nukeX - 4) / 2
        let nuke = MobileRect(x: nukeX, y: transportY, width: transportWidth, height: transportHeight)
        let pause = MobileRect(x: nuke.maxX + 4, y: transportY,
                              width: trailing.maxX - nuke.maxX - 4, height: transportHeight)
        var frames: [MobileRect] = []
        let value = hasRate ? CGRect(x: leading.minX + (rateWidth - 28) / 2, y: transportY,
                                    width: 28, height: transportHeight) : nil
        if let value {
            frames += [MobileRect(x: leading.minX, y: transportY, width: value.minX - leading.minX, height: transportHeight),
                       MobileRect(x: value.maxX, y: transportY, width: leading.minX + rateWidth - value.maxX, height: transportHeight)]
        }
        frames += skills + [pause, nuke, speed]
        frames += navigation
        let header = MobileRect(x: safe.minX, y: safe.minY, width: safe.width, height: 44)
        guard let menuBank = MobileDisplayRegions.freeFrames(in: header, avoiding: regions)
            .filter({ $0.width >= 44 && $0.height == 44 }).max(by: { $0.maxX < $1.maxX }) else { return nil }
        let menu = MobileRect(x: menuBank.maxX - 44, y: safe.minY, width: 44, height: 44)
        frames.append(menu)
        let status = MobileRect(x: safe.minX, y: safe.minY, width: menu.minX - safe.minX - 4, height: 44)
        guard frames.allSatisfy({ frame in
            frame.width >= 44 - 0.001 && frame.height >= 44
                && regions.allSatisfy { !frame.intersects($0.frame) }
        }) else { return nil }
        let interface = MobileInterfaceLayout(orientation: base.orientation, safeFrame: safe,
            playfieldFrame: MobileRect(x: safe.minX, y: header.maxY, width: safe.width,
                                      height: (vertical ? deck.minY : division.frame.minY) - header.maxY),
            statusFrame: status, controlsFrame: deck, controlFrames: frames)
        let artWidth = skills.map(\.width).min() ?? 44
        let artHeight = skills.map(\.height).min() ?? 80
        let scale = max(1, min(6, floor(min((artWidth - 4) / 16, (artHeight - 34) / 24))))
        return MobileHUDLayout(portrait: Portrait(skills: skillArea, skillContentWidth: safe.width,
            rateValue: value, minimap: map), interface: interface, panel: nil, compactScale: scale,
            speedArrows: [], reservedRegions: regions, supportsRewind: supportsRewind, isDiorama: true)
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
