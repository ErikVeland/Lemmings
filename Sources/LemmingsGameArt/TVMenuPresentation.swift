import CoreGraphics
import Foundation
import NxlvKit

/// Fixed TV viewports share the same bitmap rectangles for drawing and focus.
public enum TVMenuPresentation {
    public static let previousID = "tvPage.previous"
    public static let nextID = "tvPage.next"

    public static func homePage(_ source: GameFrontEnd.Page) -> GameFrontEnd.Page {
        var page = source
        page.subtitle = source.subtitle.components(separatedBy: "\n").filter { !$0.isEmpty }.joined(separator: "  ")
        page.subtitleRuns = []
        return page
    }

    public static func homeScale(_ preferred: CGFloat, page: GameFrontEnd.Page, width: CGFloat, height: CGFloat) -> CGFloat {
        for scale in stride(from: Int(preferred), through: 1, by: -1) {
            let value = CGFloat(scale)
            if homeLayout(page, width: width / value, height: height / value).size.height <= height / value {
                return value
            }
        }
        return 1
    }

    public static func homeLayout(_ page: GameFrontEnd.Page, width: CGFloat, height: CGFloat) -> GameFrontEnd.Layout {
        let gap: CGFloat = 6, inset: CGFloat = 16
        let boardWidth = min(1200, width - 16), x = (width - boardWidth) / 2
        let inner = boardWidth - inset * 2
        let leadingWidth = floor(inner * 0.30)
        let libraryX = x + inset + leadingWidth + 16
        let libraryWidth = inner - leadingWidth - 16
        let library = page.rows.filter { $0.id.hasPrefix("family.") || ["classic", "neolemmix", "l2", "l3"].contains($0.id) }
        let libraryIDs = Set(library.map(\.id))
        let saved = page.rows.filter { !libraryIDs.contains($0.id) }
        var heading = CGRect(x: x + inset, y: 20, width: leadingWidth, height: 56)
        var targets: [GameFrontEnd.Target] = []
        var leftY = heading.maxY + 12
        for action in saved {
            let rowHeight = max(36, GameTextLayout.height(action.title, width: leadingWidth - 48) + 8)
            targets.append(.init(action: action, frame: CGRect(x: x + inset, y: leftY, width: leadingWidth, height: rowHeight)))
            leftY += rowHeight + gap
        }
        var rightY: CGFloat = 20
        for (actions, columns, logo) in [(library.filter { $0.gameLogo == nil }, 3, false),
                                         (library.filter { $0.gameLogo != nil }, 2, true)] where !actions.isEmpty {
            let cell = (libraryWidth - CGFloat(columns - 1) * gap) / CGFloat(columns)
            let rowHeight = logo ? CGFloat(56) : max(36, actions.map {
                GameTextLayout.height($0.title, width: cell - 48) + 8
            }.max() ?? 44)
            for (index, action) in actions.enumerated() {
                let count = min(columns, actions.count - (index / columns) * columns)
                let rowCell = (libraryWidth - CGFloat(count - 1) * gap) / CGFloat(count)
                targets.append(.init(action: action, frame: CGRect(x: libraryX + CGFloat(index % columns) * (rowCell + gap),
                    y: rightY + CGFloat(index / columns) * (rowHeight + gap), width: rowCell, height: rowHeight)))
            }
            rightY += CGFloat((actions.count + columns - 1) / columns) * (rowHeight + gap) + 4
        }
        var initials = CGRect(x: x + inset, y: max(leftY, rightY), width: inner,
            height: GameTextLayout.height(page.homeInitials, width: inner))
        var subtitle = CGRect(x: x + inset, y: initials.maxY + 6, width: inner,
            height: GameTextLayout.height(page.subtitle, width: inner))
        let footer = page.orderedFooter
        let icons = footer.filter { ["settings", "whatsNew"].contains($0.id) }
        let captions = footer.filter { !["settings", "whatsNew"].contains($0.id) }
        let minimumCell = captions.flatMap { $0.title.split(whereSeparator: \.isWhitespace) }
            .map { GameTextLayout.width(of: String($0)) + 24 }.max() ?? 44
        let columns = max(1, min(footer.count, Int((inner + gap) / (max(44, minimumCell) + gap))))
        let footerGrid = GameFooterGrid(actions: captions + icons, columns: columns, alignTrailing: false)
        let cell = (inner - CGFloat(footerGrid.columns - 1) * gap) / CGFloat(footerGrid.columns)
        let footerHeight = max(44, captions.map {
            GameTextLayout.height($0.title, width: cell - 24) + 8
        }.max() ?? 44)
        let footerY = subtitle.maxY + 8
        let footerTotalHeight = CGFloat(footerGrid.rows) * footerHeight + CGFloat(max(0, footerGrid.rows - 1)) * gap
        var contentHeight = footerY + footerTotalHeight + 20
        let logoGrowth = min(max(0, rightY - leftY) + max(0, height - contentHeight),
            max(0, GameMenuLogo.preferredHeight(width: heading.width) - heading.height))
        let contentGrowth = max(0, leftY + logoGrowth - max(leftY, rightY))
        heading.size.height += logoGrowth
        targets = targets.map { target in
            .init(action: target.action, frame: target.frame.offsetBy(dx: 0,
                dy: libraryIDs.contains(target.action.id) ? 0 : logoGrowth))
        }
        initials.origin.y += contentGrowth
        subtitle.origin.y += contentGrowth
        contentHeight += contentGrowth
        let actualHeight = max(height, contentHeight)
        let offset = floor((actualHeight - contentHeight) / 2)
        targets = targets.map { .init(action: $0.action, frame: $0.frame.offsetBy(dx: 0, dy: offset)) }
        for slot in footerGrid.slots {
            targets.append(.init(action: slot.action, frame: footerGrid.frame(for: slot,
                x: x + inset, y: actualHeight - footerTotalHeight - 20, width: inner,
                height: footerHeight, gap: gap, rowGap: gap)))
        }
        return .init(size: CGSize(width: width, height: actualHeight),
            board: CGRect(x: x, y: offset + 4, width: boardWidth, height: actualHeight - offset - 8),
            heading: heading.offsetBy(dx: 0, dy: offset), subtitle: subtitle.offsetBy(dx: 0, dy: offset),
            preview: .zero, details: [], targets: targets, initials: initials.offsetBy(dx: 0, dy: offset))
    }

    public static func settingsScale(_ preferred: CGFloat, page: GameFrontEnd.Page, width: CGFloat, height: CGFloat) -> CGFloat {
        for value in stride(from: Int(preferred), through: 1, by: -1) {
            let scale = CGFloat(value)
            var index = 0, fits = true
            while true {
                let sample = settingsPage(page, index: index, width: width / scale, height: height / scale)
                if settingsLayout(sample, width: width / scale, height: height / scale).size.height > height / scale { fits = false; break }
                if !sample.footer.contains(where: { $0.id == nextID && $0.enabled }) { break }
                index += 1
            }
            if fits { return scale }
        }
        return 1
    }

    /// Pack complete rows into pages. No setting or reset action is discarded.
    public static func settingsPage(_ source: GameFrontEnd.Page, index: Int, width: CGFloat, height: CGFloat) -> GameFrontEnd.Page {
        let inner = min(1100, width - 16) - 32
        var header = source
        header.subtitle = [source.subtitle, "99/99"].filter { !$0.isEmpty }.joined(separator: "  ")
        let top = headerBottom(header, inner: inner)
        let footerHeight = max(44, GameTextLayout.height(L10n.text("Previous"), width: (inner - 16) / 3 - 24) + 8)
        let available = height - top - footerHeight - 32
        var pages: [[GameFrontEnd.Action]] = [], current: [GameFrontEnd.Action] = []
        func list(_ actions: [GameFrontEnd.Action]) -> GameListGrid {
            GameListGrid(actions: actions, width: inner, columnsEnabled: !source.singleColumnRows,
                gap: 8, minimumHeight: 44, captionInset: 24, rowHeadings: source.rowHeadings)
        }
        for row in list(source.rows).rows {
            let actions = Array(source.rows[row.indices])
            let candidate = current + actions
            let rowHeight = list(candidate).height
            if !current.isEmpty && rowHeight > available { pages.append(current); current = actions }
            else { current = candidate }
        }
        if !current.isEmpty || pages.isEmpty { pages.append(current) }
        let selected = min(pages.count - 1, max(0, index))
        var page = source
        page.rows = pages[selected]
        page.televisionPageIndex = selected
        if pages.count > 1 {
            page.subtitle = [source.subtitle, "\(selected + 1)/\(pages.count)"].filter { !$0.isEmpty }.joined(separator: "  ")
            if !source.subtitleRuns.isEmpty { page.subtitleRuns = source.subtitleRuns + [.init("  \(selected + 1)/\(pages.count)", .blue)] }
            page.footer += [.init(previousID, L10n.text("Previous"), enabled: selected > 0),
                            .init(nextID, L10n.text("Next"), enabled: selected + 1 < pages.count)]
        }
        return page
    }

    private static func headerBottom(_ page: GameFrontEnd.Page, inner: CGFloat) -> CGFloat {
        16 + max(32, GameTextLayout.height(page.title, width: inner, face: .large))
            + max(24, GameTextLayout.height(page.subtitle, width: inner)) + 12
    }

    public static func settingsLayout(_ page: GameFrontEnd.Page, width: CGFloat, height: CGFloat) -> GameFrontEnd.Layout {
        let boardWidth = min(1100, width - 16), x = (width - boardWidth) / 2, inner = boardWidth - 32
        let heading = CGRect(x: x + 16, y: 16, width: inner,
            height: max(32, GameTextLayout.height(page.title, width: inner, face: .large)))
        let subtitle = CGRect(x: x + 16, y: heading.maxY, width: inner,
            height: max(24, GameTextLayout.height(page.subtitle, width: inner)))
        var targets: [GameFrontEnd.Target] = []
        var y = subtitle.maxY + 12
        let grid = GameListGrid(actions: page.rows, width: inner, columnsEnabled: !page.singleColumnRows,
            gap: 8, minimumHeight: 44, captionInset: 24, rowHeadings: page.rowHeadings)
        targets += grid.targets.map { .init(action: $0.action, frame: $0.frame.offsetBy(dx: x + 16, dy: y)) }
        let headings = grid.headings.map { ($0.0, $0.1.offsetBy(dx: x + 16, dy: y)) }
        if !page.rows.isEmpty { y += grid.height + 8 }
        let footer = page.orderedFooter
        let footerColumns = max(1, footer.count)
        let footerCell = (inner - CGFloat(footerColumns - 1) * 8) / CGFloat(footerColumns)
        let footerHeight = max(44, footer.map { GameTextLayout.height($0.title, width: footerCell - 24) + 8 }.max() ?? 44)
        let footerY = max(y + 8, height - footerHeight - 16)
        for (column, action) in footer.enumerated() {
            targets.append(.init(action: action, frame: CGRect(x: x + 16 + CGFloat(column) * (footerCell + 8), y: footerY, width: footerCell, height: footerHeight)))
        }
        let actualHeight = max(height, footerY + footerHeight + 16)
        return .init(size: CGSize(width: width, height: actualHeight), board: CGRect(x: x, y: 4, width: boardWidth, height: actualHeight - 8),
            heading: heading, subtitle: subtitle, preview: .zero, details: [], targets: targets, rowHeadings: headings)
    }
}
