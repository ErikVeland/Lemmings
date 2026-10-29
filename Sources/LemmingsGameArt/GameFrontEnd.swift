import CoreGraphics
import Foundation
import NxlvKit
import LemmingsMobileCore

/// Shared bitmap pages. UIKit supplies input over these exact drawing rectangles.
public struct GameFrontEnd {
    public enum GameLogo: String, Equatable, Sendable { case lemmings2, lemmings3 }
    public struct TextRun: Equatable, Sendable {
        public var text: String
        public var palette: GameMenuTypography.Palette
        public init(_ text: String, _ palette: GameMenuTypography.Palette) { self.text = text; self.palette = palette }
    }
    public struct Action: Equatable, Sendable {
        public enum Icon: Equatable, Sendable { case favourite }
        public enum Group: Int, CaseIterable, Sendable { case level, playback, inspection, preferences }
        /// Related tools share a section across pause and replay pages.
        public var group: Group = .level
        public var id: String
        public var title: String
        public var enabled: Bool
        public var primary: Bool
        public var selected: Bool
        public var toggleValue: Bool?
        public var busy = false
        public var portrait: Int?
        public var backNavigation: Bool?
        public var gameLogo: GameLogo?
        public var icon: Icon?
        public var titleRuns: [TextRun] = []
        var visibleTitle: String { icon == nil ? title : "" }
        public var isBackNavigation: Bool {
            if let backNavigation { return backNavigation }
            if ["back", "cancel", "library", "close", "home"].contains(id) { return true }
            let label = title.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            return [L10n.text("Back"), L10n.text("BACK"), L10n.text("Cancel"), L10n.text("CANCEL"), L10n.text("Library"), L10n.text("LIBRARY"), L10n.text("Close"), L10n.text("CLOSE")].map { $0.uppercased() }.contains(label) || label.hasPrefix(L10n.text("Back ").uppercased())
        }
        public init(_ id: String, _ title: String, enabled: Bool = true,
                    primary: Bool = false, selected: Bool = false, portrait: Int? = nil, backNavigation: Bool? = nil,
                    gameLogo: GameLogo? = nil, icon: Icon? = nil) {
            self.id = id; self.title = title; self.enabled = enabled
            self.primary = primary; self.selected = selected
            self.portrait = portrait
            self.backNavigation = backNavigation
            self.gameLogo = gameLogo
            self.icon = icon
        }
    }
    public struct Page: Equatable, Sendable {
        public var title: String
        public var subtitle: String
        public var home: Bool
        public var homeInitials: String
        public var homeNextPlayerIndex: Int? = nil
        public var homeNextPlayerName: String? {
            guard let homeNextPlayerIndex else { return nil }
            let names = homeInitials.replacingOccurrences(of: " vs ", with: " v ", options: .caseInsensitive)
                .components(separatedBy: " v ")
            return names.indices.contains(homeNextPlayerIndex) ? names[homeNextPlayerIndex] : nil
        }
        public var subtitleRuns: [TextRun] = []
        public var titleRuns: [TextRun] = []
        public var rows: [Action]
        /**
         * Settings use fixed tabs and bottom navigation in horizontal layouts.
         */
        public var settingsTabs: [Action]? = nil
        public var settingsIndex = false
        /// Search and list-wide actions belong to a separate, fixed toolbar.
        public var listTools: [Action] = []
        public var details: [String]
        public var footer: [Action]
        /// Hardware Back can choose a safe, visible action on a required-choice page.
        public var backActionID: String?
        public var backAction: Action? {
            let actions = rows + footer
            if let backActionID { return actions.first { $0.id == backActionID && $0.enabled } }
            return footer.last { $0.enabled && $0.isBackNavigation }
        }
        public var detailHeadings: Set<Int> = []
        public var detailTitles: Set<Int> = []
        /// Paragraph pages set body details flush left in their authored case.
        public var reading = false
        /// Reading lists, such as control help, keep their items close together.
        public var listDetails = false
        /// Space after each detail. Reading paragraphs take a blank-line gap.
        public var detailGap: CGFloat { reading && !listDetails ? 18 : 6 }
        public func readsDetail(_ index: Int) -> Bool {
            reading && !detailHeadings.contains(index) && !detailTitles.contains(index)
        }
        /// Forward actions finish the footer, including when the grid wraps.
        /// A confirmation's safe default stays in its leading position.
        public var orderedFooter: [Action] {
            func forward(_ action: Action) -> Bool {
                action.primary && !action.isBackNavigation
            }
            return footer.filter(\.isBackNavigation)
                + footer.filter { !$0.isBackNavigation && !forward($0) } + footer.filter(forward)
        }
        public var preview: Bool
        /// Codes and other complete images fit inside the pane; level scenery fills it.
        public var previewFitsImage = false
        public var pause: MobilePauseSummary? = nil
        public var televisionGrid = false
        public var televisionPageIndex = 0
        public var result = false
        public var achievementItems: [MobileResultAchievementsArt.Item]?
        /// Earned rescue stars, 0 to 3, drawn as filled or outlined stars below the subtitle.
        public var stars: Int?
        public var footerColumns: Int?
        /// Short peer lists can also use the adaptive columns applied to longer lists.
        public var pairsRows = false
        /// Keep ordered steps or another deliberately linear list in one column.
        public var singleColumnRows = false
        public var rowHeadings: [String: String] = [:]
        public init(title: String, subtitle: String = "", home: Bool = false,
                    rows: [Action] = [], details: [String] = [], footer: [Action] = [], preview: Bool = false,
                    footerColumns: Int? = nil, homeInitials: String = "") {
            self.title = title; self.subtitle = subtitle; self.home = home
            self.rows = rows; self.details = details; self.footer = footer; self.preview = preview
            self.footerColumns = footerColumns
            self.homeInitials = homeInitials
        }
    }
    public struct Target: Equatable {
        public let action: Action
        public let frame: CGRect
    }
    public struct Layout {
        public let size: CGSize
        public let board: CGRect
        public let heading: CGRect
        public let subtitle: CGRect
        public let preview: CGRect
        public let details: [CGRect]
        public let targets: [Target]
        public var initials: CGRect = .zero
        public var stars: CGRect = .zero
        public var secondaryBoard: CGRect? = nil
        public var libraryHeading: CGRect? = nil
        public var rowHeadings: [(String, CGRect)] = []
        public func action(at point: CGPoint) -> String? {
            targets.first { $0.action.enabled && $0.frame.contains(point) }?.action.id
        }
    }

    public static func layout(_ page: Page, width: CGFloat, minimumHeight: CGFloat, boxedHome: Bool = false,
                              bookHomePanes: [CGRect] = [], fillsResultPane: Bool = false) -> Layout {
        if page.televisionGrid { return TVMenuPresentation.settingsLayout(page, width: width, height: minimumHeight) }
        if page.pause != nil { return MobilePauseArt.layout(page, width: width, minimumHeight: minimumHeight) }
        if page.achievementItems != nil { return MobileResultAchievementsArt.layout(page, width: width, minimumHeight: minimumHeight) }
        if page.result { return resultLayout(page, width: width, minimumHeight: minimumHeight, fillsPane: fillsResultPane) }
        if page.home {
            if bookHomePanes.count == 2 {
                return MobileBookHomeArt.layout(page, width: width, height: minimumHeight, panes: bookHomePanes)
            }
            if boxedHome { return boxedHomeLayout(page, width: width, minimumHeight: minimumHeight) }
            return homeLayout(page, width: width, minimumHeight: minimumHeight)
        }
        let width = max(280, width)
        let inset: CGFloat = width < 600 ? 14 : 32
        let boardWidth = min(1032, width - inset * 2)
        let x = (width - boardWidth) / 2
        let requestedColumns = page.footerColumns ?? (boardWidth >= 620 ? 3 : 2)
        let minimumCaptionWidth = page.footer.map { action in
            action.icon != nil ? 44 : (action.title.split(whereSeparator: \.isWhitespace).map {
                GameTextLayout.width(of: String($0))
            }.max() ?? 0) + (action.primary ? 48 : 24)
        }.max() ?? 44
        let fittingColumns = max(1, Int((boardWidth - 40 + 12) / (minimumCaptionWidth + 12)))
        let footerGrid = GameFooterGrid(actions: page.orderedFooter,
            columns: min(requestedColumns, fittingColumns), spanSingleAction: true)
        // A short, wide screen puts the preview beside its details so the actions stay in view.
        let compact = page.preview && minimumHeight < 520 && width > minimumHeight * 1.3
        let titleScale = boardWidth >= 620 ? 2 : 1
        let headingHeight = max(compact ? 40 : 52, GameTextLayout.height(page.title, width: boardWidth - 40, face: .large, scale: titleScale))
        let heading = CGRect(x: x + 20, y: compact ? 28 : 32, width: boardWidth - 40, height: headingHeight)
        let subtitle = CGRect(x: x + 20, y: heading.maxY + (compact ? 2 : 8), width: boardWidth - 40, height: GameTextLayout.height(page.subtitle, width: boardWidth - 40))
        var y = subtitle.maxY + (compact ? 8 : 16)
        var stars = CGRect.zero
        if page.stars != nil {
            stars = CGRect(x: x + (boardWidth - 123) / 2, y: y - 4, width: 123, height: 27)
            y = stars.maxY + 12
        }
        var targets: [Target] = []
        let grid = GameListGrid(actions: page.rows, width: boardWidth - 40,
            columnsEnabled: !page.singleColumnRows && (page.pairsRows || page.rows.count >= 2), rowHeadings: page.rowHeadings)
        targets += grid.targets.map { Target(action: $0.action, frame: $0.frame.offsetBy(dx: x + 20, dy: y)) }
        let rowHeadings = grid.headings.map { ($0.0, $0.1.offsetBy(dx: x + 20, dy: y)) }
        if !page.rows.isEmpty { y += grid.height + 8 }
        var preview = CGRect.zero
        var details: [CGRect] = []
        let readingWidth = page.reading ? min(720, boardWidth - 40) : boardWidth - 40
        let readingX = x + (boardWidth - readingWidth) / 2
        if compact {
            let footerRows = footerGrid.rows
            let room = max(80, minimumHeight - y - CGFloat(footerRows) * 60 - 36 - 12)
            let previewWidth = min((boardWidth - 40) * 0.55, room * 2)
            preview = CGRect(x: x + 20, y: y, width: previewWidth, height: previewWidth / 2)
            let side = boardWidth - 40 - previewWidth - 16
            var detailY = y
            for (index, value) in page.details.enumerated() {
                let height = GameTextLayout.height(value, width: side, face: page.detailTitles.contains(index) ? .large : .small)
                if page.detailHeadings.contains(index) || page.detailTitles.contains(index) { detailY += 8 }
                details.append(CGRect(x: preview.maxX + 16, y: detailY, width: side, height: height))
                detailY += height + (page.readsDetail(index) ? 24 : 6)
            }
            y = max(preview.maxY, detailY) + 12
        } else {
            if page.preview {
                let previewWidth = boardWidth - 40
                let detailHeight = page.details.enumerated().reduce(CGFloat.zero) { total, entry in
                    total + GameTextLayout.height(entry.element, width: previewWidth,
                        face: page.detailTitles.contains(entry.offset) ? .large : .small) + page.detailGap
                        + (page.detailHeadings.contains(entry.offset) || page.detailTitles.contains(entry.offset) ? 12 : 0)
                }
                let footerCell = (boardWidth - 40 - CGFloat(footerGrid.columns - 1) * 12) / CGFloat(footerGrid.columns)
                let actionHeight = max(48, page.footer.map {
                    GameTextLayout.height($0.visibleTitle, width: footerCell - ($0.primary ? 48 : 24)) + 8
                }.max() ?? 48)
                let room = minimumHeight - y - 16 - detailHeight - CGFloat(footerGrid.rows) * (actionHeight + 12) - 36
                preview = CGRect(x: x + 20, y: y, width: previewWidth,
                                 height: min(360, previewWidth / 2, max(80, room)))
                y = preview.maxY + 16
            }
            for (index, value) in page.details.enumerated() {
                let height = GameTextLayout.height(value, width: readingWidth, face: page.detailTitles.contains(index) ? .large : .small)
                if page.detailHeadings.contains(index) || page.detailTitles.contains(index) { y += 12 }
                details.append(CGRect(x: readingX, y: y, width: readingWidth, height: height))
                y += height + (page.readsDetail(index) ? 24 : 6)
            }
        }
        let columns = footerGrid.columns
        let rows = footerGrid.rows
        let cell = (boardWidth - 40 - CGFloat(columns - 1) * 12) / CGFloat(columns)
        let footerHeight = max(48, page.footer.map { GameTextLayout.height($0.visibleTitle, width: cell - ($0.primary ? 48 : 24)) + 8 }.max() ?? 48)
        let footerPitch = footerHeight + 12
        let height = max(minimumHeight, y + CGFloat(rows) * footerPitch + 36)
        y = max(y + 12, height - CGFloat(rows) * footerPitch - 24)
        for slot in footerGrid.slots {
            targets.append(Target(action: slot.action, frame: footerGrid.frame(for: slot, x: x + 20, y: y, width: boardWidth - 40,
                height: footerHeight, gap: 12, rowGap: 12)))
        }
        var layout = Layout(size: CGSize(width: width, height: height),
                      board: CGRect(x: x, y: 16, width: boardWidth, height: height - 32),
                      heading: heading, subtitle: subtitle, preview: preview,
                      details: details, targets: targets)
        layout.stars = stars
        layout.rowHeadings = rowHeadings
        return layout
    }

    private static func boxedHomeLayout(_ page: Page, width: CGFloat, minimumHeight: CGFloat) -> Layout {
        let content = homeLayout(page, width: min(1100, width),
            minimumHeight: max(0, minimumHeight - 48), compact: true)
        let offset = CGPoint(x: floor((width - content.size.width) / 2),
            y: max(0, floor((minimumHeight - content.size.height) / 2)))
        func move(_ rect: CGRect) -> CGRect { rect.offsetBy(dx: offset.x, dy: offset.y) }
        return Layout(size: CGSize(width: width, height: max(minimumHeight, content.size.height)),
            board: move(content.board), heading: move(content.heading), subtitle: move(content.subtitle),
            preview: .zero, details: [], targets: content.targets.map { Target(action: $0.action, frame: move($0.frame)) },
            initials: move(content.initials))
    }

    private static func homeLayout(_ page: Page, width: CGFloat, minimumHeight: CGFloat, compact: Bool = false) -> Layout {
        let width = max(280, width)
        let boardWidth = min(1100, width - 24), x = (width - boardWidth) / 2
        let inner = boardWidth - 24
        let portraitPhone = width < 600 && width < minimumHeight
        let columns = portraitPhone ? 1 : 2
        let gap: CGFloat = portraitPhone || compact ? 8 : 12
        let groupGap: CGFloat = compact ? 12 : 24
        let headerIDs: Set<String> = ["settings", "whatsNew"]
        let footer = page.orderedFooter.filter { !headerIDs.contains($0.id) }
        let requestedFooterColumns = portraitPhone ? 1 : 3
        let minimumCaptionWidth = footer.map { action in
            action.icon != nil ? 44 : (action.title.split(whereSeparator: \.isWhitespace).map {
                GameTextLayout.width(of: String($0))
            }.max() ?? 0) + (action.primary ? 48 : 24)
        }.max() ?? 44
        let fittingFooterColumns = max(1, Int((inner + gap) / (minimumCaptionWidth + gap)))
        let footerGrid = GameFooterGrid(actions: footer, columns: min(requestedFooterColumns, fittingFooterColumns),
            spanSingleAction: true, alignTrailing: false)
        let footerCell = (inner - CGFloat(footerGrid.columns - 1) * gap) / CGFloat(footerGrid.columns)
        // A short status such as Loading... sits in a fixed header slot beside Settings,
        // so it never moves the logo or the actions when it appears.
        let statusSlot = GameTextLayout.width(of: L10n.text("Loading...")) + 8
        let statusWidth = GameTextLayout.width(of: page.subtitle)
        let headerStatus = !page.subtitle.contains("\n") && statusWidth <= statusSlot
        let heading = CGRect(x: x + 62 + statusSlot / 2, y: 22,
                            width: boardWidth - 124 - statusSlot, height: 44)
        let statusHeight = GameTextLayout.height(page.subtitle, width: inner)
        let subtitle = headerStatus
            ? CGRect(x: x + boardWidth - 62 - statusWidth, y: 22 + floor((44 - statusHeight) / 2),
                     width: statusWidth, height: statusHeight)
            : CGRect(x: x + 12, y: 70, width: inner, height: statusHeight)
        let showsTurnAtTop = page.homeNextPlayerIndex != nil
        let turnInitials = CGRect(x: x + 12, y: (headerStatus ? 70 : subtitle.maxY) + 4, width: inner,
            height: showsTurnAtTop ? 22 : 0)
        let gameStart = page.rows.firstIndex {
            $0.id.hasPrefix("family.") || ["classic", "neolemmix", "l2", "l3"].contains($0.id)
        } ?? page.rows.count
        let library = Array(page.rows.dropFirst(gameStart))
        let sections = [Array(page.rows.prefix(gameStart)), library.filter { $0.gameLogo == nil },
                        library.filter { $0.gameLogo != nil }].filter { !$0.isEmpty }
        var targets: [Target] = []
        var y = (showsTurnAtTop ? turnInitials.maxY : headerStatus ? 70 : subtitle.maxY) + 16
        for (section, actions) in sections.enumerated() {
            if section > 0 { y += groupGap }
            // Game logos pair up side by side even in one-column portrait, so each logo stays large.
            let sectionColumns = compact && section > 0 && actions.allSatisfy({ $0.gameLogo == nil }) && width >= 800 ? 3 : actions.count == 3 && section == 0 && gameStart > 0 && width >= 600 ? 3
                : actions.count > 1 && actions.allSatisfy({ $0.gameLogo != nil }) ? 2 : columns
            let cell = (inner - CGFloat(sectionColumns - 1) * gap) / CGFloat(sectionColumns)
            let logos = actions.allSatisfy { $0.gameLogo != nil }
            let rowHeight = logos ? CGFloat(compact ? 64 : 112) : max(44, actions.map {
                GameTextLayout.height($0.visibleTitle, width: (actions.count == 1 ? inner : cell) - 48) + 8
            }.max() ?? 44)
            for start in stride(from: 0, to: actions.count, by: sectionColumns) {
                let group = actions[start..<min(start + sectionColumns, actions.count)]
                let rowCell = (inner - CGFloat(group.count - 1) * gap) / CGFloat(group.count)
                for (column, action) in group.enumerated() {
                    let frame = CGRect(x: x + 12 + CGFloat(column) * (rowCell + gap), y: y,
                        width: rowCell, height: rowHeight)
                    targets.append(Target(action: action, frame: frame))
                }
                y += rowHeight + gap
            }
            y -= gap
        }
        y += groupGap
        let initials = showsTurnAtTop ? turnInitials
            : CGRect(x: x + 12, y: y, width: inner, height: page.homeInitials.isEmpty ? 0 : 22)
        if !showsTurnAtTop { y = initials.maxY + 8 }
        let footerHeight = max(44, footer.map { GameTextLayout.height($0.visibleTitle, width: footerCell - 24) + 8 }.max() ?? 44)
        for slot in footerGrid.slots {
            targets.append(Target(action: slot.action, frame: footerGrid.frame(for: slot, x: x + 12, y: y, width: inner,
                height: footerHeight, gap: gap, rowGap: gap)))
        }
        let contentHeight = y + CGFloat(footerGrid.rows) * (footerHeight + gap) + 12
        let height = max(minimumHeight, contentHeight)
        for action in page.orderedFooter where headerIDs.contains(action.id) {
            targets.append(Target(action: action, frame: CGRect(x: action.id == "settings" ? x + boardWidth - 56 : x + 12,
                y: 22, width: 44, height: 44)))
        }
        let logoGrowth = min(height - contentHeight,
            max(0, GameMenuLogo.preferredHeight(width: heading.width) - heading.height))
        let offset = floor(max(0, (height - contentHeight - logoGrowth) / 2))
        return Layout(size: CGSize(width: width, height: height),
            board: CGRect(x: x, y: 12 + offset, width: boardWidth, height: contentHeight + logoGrowth - 24),
            heading: CGRect(x: heading.minX, y: heading.minY + offset,
                width: heading.width, height: heading.height + logoGrowth),
            subtitle: subtitle.offsetBy(dx: 0, dy: offset + (headerStatus ? 0 : logoGrowth)),
            preview: .zero, details: [], targets: targets.map {
                Target(action: $0.action, frame: $0.frame.offsetBy(dx: 0,
                    dy: offset + (headerIDs.contains($0.action.id) ? 0 : logoGrowth)))
            }, initials: initials.offsetBy(dx: 0, dy: offset + logoGrowth))
    }

    /// Results reserve room for actions first; the snapshot fills the remaining space.
    private static func resultLayout(_ page: Page, width: CGFloat, minimumHeight: CGFloat, fillsPane: Bool) -> Layout {
        let width = max(280, width), inset: CGFloat = 20
        let boardWidth = min(1032, width - 24), x = (width - boardWidth) / 2
        let inner = boardWidth - inset * 2, gap: CGFloat = 8
        let headingHeight = GameTextLayout.height(page.title, width: inner, face: .large)
        let heading = CGRect(x: x + inset, y: 24, width: inner, height: max(32, headingHeight))
        let subtitle = CGRect(x: x + inset, y: heading.maxY + 4, width: inner,
                              height: GameTextLayout.height(page.subtitle, width: inner))
        let footerGrid = GameFooterGrid(actions: page.orderedFooter, columns: width >= 600 ? 3 : 2, spanSingleAction: true)
        let columns = footerGrid.columns
        let cell = (inner - CGFloat(columns - 1) * gap) / CGFloat(columns)
        let footerHeight = max(44, page.footer.map { GameTextLayout.height($0.visibleTitle, width: cell - 48) + 8 }.max() ?? 44)
        let footerRows = footerGrid.rows
        let actionsHeight = CGFloat(footerRows) * (footerHeight + gap)
        let sideBySide = width >= 600
        let detailWidth = sideBySide ? (inner - gap) * 0.52 : inner
        var y = subtitle.maxY + 8
        let contentTop = y
        var details: [CGRect] = []
        for value in page.details {
            let height = GameTextLayout.height(value, width: detailWidth)
            details.append(CGRect(x: sideBySide ? x + inset + inner - detailWidth : x + inset,
                                  y: y, width: detailWidth, height: height))
            y += height + page.detailGap
        }
        var targets: [Target] = []
        for action in page.rows {
            let height = max(44, GameTextLayout.height(action.visibleTitle, width: detailWidth - 24) + 8)
            targets.append(Target(action: action, frame: CGRect(x: sideBySide ? x + inset + inner - detailWidth : x + inset,
                                                               y: y, width: detailWidth, height: height)))
            y += height + gap
        }
        let available = minimumHeight - contentTop - actionsHeight - 36
        let previewWidth = sideBySide ? inner - detailWidth - gap : inner
        let previewHeight = sideBySide ? max(64, fillsPane ? available : min(220, available))
            : max(48, fillsPane ? minimumHeight - y - actionsHeight - 36 : min(140, minimumHeight - y - actionsHeight - 36))
        let preview = CGRect(x: x + inset, y: sideBySide ? contentTop : y, width: previewWidth, height: previewHeight)
        y = max(y, preview.maxY) + 8
        let contentHeight = y + actionsHeight + 24
        let height = max(minimumHeight, contentHeight)
        let offset = fillsPane ? 0 : max(0, (height - contentHeight) / 2)
        let footerY = y
        for slot in footerGrid.slots {
            targets.append(Target(action: slot.action, frame: footerGrid.frame(for: slot, x: x + inset, y: footerY, width: inner,
                height: footerHeight, gap: gap, rowGap: gap)))
        }
        return Layout(size: CGSize(width: width, height: height),
                      board: CGRect(x: x, y: 12 + offset, width: boardWidth, height: contentHeight - 24),
                      heading: heading.offsetBy(dx: 0, dy: offset), subtitle: subtitle.offsetBy(dx: 0, dy: offset),
                      preview: preview.offsetBy(dx: 0, dy: offset), details: details.map { $0.offsetBy(dx: 0, dy: offset) },
                      targets: targets.map { Target(action: $0.action, frame: $0.frame.offsetBy(dx: 0, dy: offset)) })
    }

    public static func draw(_ page: Page, layout: Layout, typography: GameMenuTypography,
                            preview: CGImage? = nil, previewSource: CGRect? = nil,
                            highlighted: String? = nil, portraits: GamePortraitArt? = nil, fillsCanvas: Bool = true, shape: GameControlShape = .square, drawsBackdrop: Bool = true, in context: CGContext) {
        context.saveGState()
        defer { context.restoreGState() }
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        let boards = [layout.board] + (layout.secondaryBoard.map { [$0] } ?? [])
        if drawsBackdrop && fillsCanvas { context.fill(CGRect(origin: .zero, size: layout.size)) }
        // Spanned home controls float on the moving scenery, with no panel behind them.
        let floating = page.home && layout.secondaryBoard != nil && !fillsCanvas
        for board in boards where drawsBackdrop && !floating {
            if !fillsCanvas { shape.fill(board, in: context) }
            // A drawn frame cannot match a rounded display's hardware corner radius,
            // so the display edge frames full-screen boards and the home menu.
            if shape == .rounded && (fillsCanvas || page.home) { continue }
            GameMenuFrameArt.draw(in: context, board: board, shape: shape)
        }
        if let heading = layout.libraryHeading {
            GameTextLayout.draw(L10n.text("Levels"), in: heading, typography: typography, face: .large,
                               palette: .green, context: context)
        }
        if page.home, let image = typography.menuLogo {
            let size = GameMenuLogo.logicalSize(of: image)
            let frame = GameMenuLogo.frame(canvasSize: size,
                originalWidth: typography.interface.logo.map { CGFloat($0.width) } ?? size.width,
                in: layout.heading, wholeNumberScale: false)
            GameStoneArt.drawImage(image, in: frame, context: context)
        } else if !page.titleRuns.isEmpty {
            GameSemanticText.draw(page.titleRuns, in: layout.heading, typography: typography, face: .large,
                scale: layout.heading.width >= 580 && layout.heading.height >= 52 ? 2 : 1, context: context)
        } else {
            heading(page.title, box: layout.heading, typography: typography, context: context)
        }
        if page.pause == nil {
            if !page.subtitleRuns.isEmpty {
                GameSemanticText.draw(page.subtitleRuns, in: layout.subtitle, typography: typography, context: context)
            } else { GameTextLayout.draw(page.subtitle, in: layout.subtitle, typography: typography, context: context) }
        }
        if page.home, !page.homeInitials.isEmpty {
            GameSemanticText.draw(GameSemanticText.players(page.homeInitials, nextPlayerIndex: page.homeNextPlayerIndex),
                in: layout.initials, typography: typography, context: context)
        }
        if page.pause != nil {
            MobilePauseArt.draw(page, layout: layout, typography: typography, preview: preview, previewSource: previewSource, shape: shape, in: context)
        } else if page.preview {
            let image = preview.flatMap { preview in previewSource.flatMap { preview.cropping(to: $0.integral) } ?? preview }
            if page.previewFitsImage {
                GameDisplayArt.draw(in: context, frame: layout.preview, pixel: 2, shape: shape)
                if let image {
                    drawImage(image, fittedIn: GameStoneArt.well(layout.preview, pixel: 2).insetBy(dx: 4, dy: 4), context: context)
                }
            } else {
                GameDisplayArt.drawPreview(in: context, frame: layout.preview, image: image, shape: shape)
            }
        }
        if let earned = page.stars, layout.stars != .zero {
            for index in 0..<3 {
                GameStarArt.draw(at: CGPoint(x: layout.stars.minX + CGFloat(index) * 45, y: layout.stars.minY),
                                 earned: index < earned, size: 3, context: context)
            }
        }
        if page.achievementItems != nil {
            MobileResultAchievementsArt.draw(page, layout: layout, typography: typography, in: context)
        } else if page.pause == nil {
            for (index, pair) in zip(page.details, layout.details).enumerated() {
                GameTextLayout.draw(pair.0, in: pair.1, typography: typography,
                    face: page.detailTitles.contains(index) ? .large : .small,
                    palette: page.detailHeadings.contains(index) || page.detailTitles.contains(index) ? .green : .blue,
                    alignment: page.readsDetail(index) ? .left : .center, preservesCase: page.readsDetail(index), context: context)
            }
        }
        let footerIDs = Set(page.footer.map(\.id))
        let footerTargets = layout.targets.filter { footerIDs.contains($0.action.id) }
        let shelfTop = page.pause == nil ? nil : footerTargets.first.map { $0.frame.minY - 8 }
        if page.pause != nil, let first = footerTargets.first, let last = footerTargets.last {
            context.setFillColor(CGColor(gray: 0, alpha: 1))
            context.fill(CGRect(x: layout.board.minX + 1, y: first.frame.minY - 8,
                width: layout.board.width - 2, height: max(layout.size.height, last.frame.maxY + 24) - first.frame.minY + 8))
        }
        for (title, frame) in layout.rowHeadings where shelfTop.map({ frame.maxY <= $0 }) ?? true {
            GameTextLayout.draw(title, in: frame, typography: typography, palette: .green, alignment: .left, context: context)
        }
        let rowIDs = Set(page.rows.map(\.id))
        for target in layout.targets where !target.frame.isEmpty {
            context.saveGState()
            defer { context.restoreGState() }
            if let shelfTop, !footerIDs.contains(target.action.id) {
                guard target.frame.minY < shelfTop else { continue }
                context.clip(to: CGRect(x: 0, y: 0, width: layout.size.width, height: max(0, shelfTop)))
            }
            let action = target.action
            let chosen = action.enabled && (action.primary || action.selected)
            let focused = action.enabled && highlighted == action.id
            if page.home, rowIDs.contains(action.id) {
                // The home screen uses the same dark rows and green selection as the Mac title overlay.
                context.setFillColor(chosen ? CGColor(srgbRed: 0.18, green: 0.27, blue: 0.12, alpha: 1)
                    : CGColor(gray: 0.07, alpha: 1))
                shape.fill(target.frame, in: context)
                context.setStrokeColor(chosen ? CGColor(srgbRed: 0.70, green: 0.84, blue: 0.29, alpha: 1)
                    : CGColor(gray: 0.29, alpha: 1))
                context.setLineWidth(chosen ? 2 : 1)
                shape.stroke(target.frame, inset: 1, in: context)
            } else if page.home, ["settings", "whatsNew"].contains(action.id) {
                GameStoneArt.draw(in: context, frame: target.frame, selected: chosen, pixel: 1, shape: shape)
                let glyph: PanelGlyphArt = action.id == "settings" ? .settings : action.busy ? .hourglass : .download
                let well = GameStoneArt.well(target.frame, pixel: 1).insetBy(dx: 2, dy: 2)
                let scale = glyph.scale(fitting: well.size)
                if let image = glyph.cgImage(scale: scale) {
                    drawImage(image, fittedIn: well, context: context)
                }
                if focused { drawFocus(target.frame, shape: shape, in: context) }
                continue
            } else if page.home {
                context.setFillColor(chosen ? CGColor(srgbRed: 0.06, green: 0.16, blue: 0.035, alpha: 1) : CGColor(gray: 0.025, alpha: 1))
                shape.fill(target.frame, in: context)
                context.setStrokeColor(chosen ? CGColor(srgbRed: 0.48, green: 0.80, blue: 0.24, alpha: 1) : CGColor(gray: 0.35, alpha: 1))
                context.setLineWidth(1)
                shape.stroke(target.frame, inset: 0.5, in: context)
            } else {
                GameStoneArt.draw(in: context, frame: target.frame, selected: chosen, pixel: 1, shape: shape)
            }
            if action.selected {
                context.setFillColor(CGColor(srgbRed: 0.48, green: 0.80, blue: 0.24, alpha: action.enabled ? 1 : 0.45))
                context.fill(CGRect(x: target.frame.minX + 8, y: target.frame.maxY - 6,
                                    width: target.frame.width - 16, height: 3))
            }
            if focused { drawFocus(target.frame, shape: shape, in: context) }
            if action.icon == .favourite {
                context.saveGState()
                context.setAlpha(action.enabled ? 1 : 0.45)
                GameStarArt.draw(in: target.frame, earned: action.selected, context: context)
                context.restoreGState()
                continue
            }
            if action.primary, action.enabled {
                context.setFillColor(CGColor(srgbRed: 0.48, green: 0.80, blue: 0.24, alpha: 1))
                context.beginPath()
                context.move(to: CGPoint(x: target.frame.minX + 10, y: target.frame.midY - 5))
                context.addLine(to: CGPoint(x: target.frame.minX + 17, y: target.frame.midY))
                context.addLine(to: CGPoint(x: target.frame.minX + 10, y: target.frame.midY + 5))
                context.closePath(); context.fillPath()
            }
            if page.home, let game = action.gameLogo, let image = typography.homeLogos.image(game) {
                context.saveGState()
                context.setAlpha(action.enabled ? 1 : 0.45)
                drawImage(image, fittedIn: target.frame.insetBy(dx: 24, dy: 8), context: context)
                context.restoreGState()
                continue
            }
            if let portrait = action.portrait {
                portraits?.draw(portrait, in: CGRect(x: target.frame.minX + 12,
                    y: target.frame.minY + 7, width: 30, height: 36), context: context)
            }
            var caption = target.frame.insetBy(dx: action.primary ? 24 : 12, dy: 2)
            if action.portrait != nil { caption.origin.x += 36; caption.size.width -= 36 }
            if let checked = action.toggleValue {
                let box = CGRect(x: target.frame.minX + 12, y: target.frame.midY - 10, width: 20, height: 20)
                GameStoneArt.draw(in: context, frame: box, selected: checked, pixel: 1)
                if checked {
                    GamePixelTypography.draw("X", in: box.insetBy(dx: 4, dy: 4), context: context,
                        typography: nil, maximumScale: 1, bitmapOnly: true)
                }
                caption.origin.x += 28
                caption.size.width -= 28
            }
            if page.home {
                let runs = action.titleRuns.isEmpty ? [TextRun(action.title, rowIDs.contains(action.id) ? .green : .blue)] : action.titleRuns
                GameSemanticText.draw(runs, in: caption, typography: typography, alpha: action.enabled ? 1 : 0.45, context: context)
            } else if !action.titleRuns.isEmpty {
                GameSemanticText.draw(action.titleRuns, in: caption, typography: typography,
                    alpha: action.enabled ? 1 : 0.45, context: context)
            } else {
                actionLabel(action.title, box: caption, typography: typography,
                    palette: action.portrait == nil ? .blue : .green, alpha: action.enabled ? 1 : 0.45, context: context)
            }
        }
    }

    private static func drawFocus(_ frame: CGRect, shape: GameControlShape, in context: CGContext) {
        context.setStrokeColor(CGColor(gray: 1, alpha: 1))
        context.setLineWidth(1)
        shape.stroke(frame, inset: 2.5, in: context)
    }

    private static func actionLabel(_ text: String, box: CGRect, typography: GameMenuTypography,
                                    palette: GameMenuTypography.Palette, alpha: CGFloat, context: CGContext) {
        let lines = wrapped(GameMenuTypography.menuText(text), face: .small, width: box.width, typography: typography)
        let height = max(1, typography.height(of: text, face: .small, scale: 1))
        let count = min(lines.count, Int(box.height / height))
        let top = box.midY - CGFloat(count) * height / 2
        for (index, value) in lines.prefix(count).enumerated() {
            line(value, box: CGRect(x: box.minX, y: top + CGFloat(index) * height, width: box.width, height: height),
                 typography: typography, palette: palette, alpha: alpha, context: context)
        }
    }

    private static func heading(_ text: String, box: CGRect, typography: GameMenuTypography, context: CGContext) {
        GameTextLayout.draw(text, in: box, typography: typography, face: .large,
                            scale: box.width >= 580 && box.height >= 52 ? 2 : 1, palette: .green, context: context)
    }

    private static func wrapped(_ text: String, face: GameMenuTypography.Face, width: CGFloat,
                                typography: GameMenuTypography) -> [String] {
        GameTextLayout.lines(text, width: width, face: face, font: typography.font(face))
    }

    private static func line(_ text: String, box: CGRect, typography: GameMenuTypography,
                             face: GameMenuTypography.Face = .small, palette: GameMenuTypography.Palette = .blue,
                             alpha: CGFloat = 1, scale fixed: Int? = nil, context: CGContext) {
        let scale = fixed ?? (face == .large && typography.width(of: GameMenuTypography.menuText(text), face: face, scale: 2) <= box.width ? 2 : 1)
        let height = typography.height(of: text, face: face, scale: scale)
        typography.menuLine(text, in: CGRect(x: box.minX, y: box.midY - height / 2, width: box.width, height: height),
                            context: context, face: face, scale: scale, alpha: alpha, palette: palette)
    }
    private static func image(_ frame: ClassicMacArtwork.Frame) -> CGImage? {
        guard let provider = CGDataProvider(data: frame.rgba as CFData) else { return nil }
        return CGImage(width: frame.width, height: frame.height, bitsPerComponent: 8,
                       bitsPerPixel: 32, bytesPerRow: frame.width * 4,
                       space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }

    private static func drawImage(_ image: CGImage, fittedIn box: CGRect, context: CGContext) {
        let fit = min(box.width / CGFloat(image.width), box.height / CGFloat(image.height))
        let factor = fit >= 1 ? floor(fit) : fit
        let size = CGSize(width: CGFloat(image.width) * factor, height: CGFloat(image.height) * factor)
        let frame = CGRect(x: floor(box.midX - size.width / 2), y: floor(box.midY - size.height / 2), width: size.width, height: size.height)
        GameStoneArt.drawImage(image, in: frame, context: context)
    }
}
