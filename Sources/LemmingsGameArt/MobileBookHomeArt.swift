import CoreGraphics

/// Home uses two vertical lists with the same bitmap lettering and original action identifiers.
public enum MobileBookHomeArt {
    public static func layout(_ page: GameFrontEnd.Page, width: CGFloat, height: CGFloat,
                              panes: [CGRect]) -> GameFrontEnd.Layout {
        let left = panes[0].insetBy(dx: 12, dy: 0), right = panes[1].insetBy(dx: 12, dy: 0)
        let gap: CGFloat = 6, padding: CGFloat = 12, groupGap: CGFloat = 8, bottomPadding: CGFloat = 20
        let leftWidth = left.width - padding * 2, rightWidth = right.width - padding * 2
        var heading = CGRect(x: left.minX + 62, y: 22, width: left.width - 74, height: 56)
        let libraryHeading = CGRect(x: right.minX + padding, y: 22, width: rightWidth - 52, height: 56)
        var subtitle = CGRect(x: left.minX + padding, y: heading.maxY + 6, width: leftWidth,
                              height: GameTextLayout.height(page.subtitle, width: leftWidth))
        let showsTurnAtTop = page.homeNextPlayerIndex != nil
        var turnInitials = CGRect(x: left.minX + padding, y: subtitle.maxY + 4,
            width: leftWidth, height: showsTurnAtTop ? 22 : 0)
        var start = max(showsTurnAtTop ? turnInitials.maxY : subtitle.maxY, libraryHeading.maxY) + 12
        let headerIDs: Set<String> = ["settings", "whatsNew"]
        let footer = page.orderedFooter.filter { !headerIDs.contains($0.id) }
        let footerHeight = max(44, footer.map { GameTextLayout.height($0.title, width: leftWidth - 24) + 8 }.max() ?? 44)
        func isLibrary(_ action: GameFrontEnd.Action) -> Bool {
            action.id.hasPrefix("family.") || ["classic", "neolemmix", "l2", "l3"].contains(action.id)
        }
        let rowHeight = max(52, page.rows.filter { $0.gameLogo == nil }.map {
            GameTextLayout.height($0.title, width: min(leftWidth, rightWidth) - 48) + 8
        }.max() ?? 52)
        func rows(_ actions: [GameFrontEnd.Action], in pane: CGRect) -> (targets: [GameFrontEnd.Target], bottom: CGFloat) {
            let inner = pane.width - padding * 2
            var y = start
            var targets: [GameFrontEnd.Target] = []
            for (index, action) in actions.enumerated() {
                if index > 0, isLibrary(action) != isLibrary(actions[index - 1])
                    || (action.gameLogo != nil && actions[index - 1].gameLogo == nil) { y += groupGap }
                let extent = action.gameLogo == nil ? rowHeight : max(80, rowHeight)
                targets.append(.init(action: action, frame: CGRect(x: pane.minX + padding, y: y, width: inner, height: extent)))
                y += extent + gap
            }
            return (targets, y - (actions.isEmpty ? 0 : gap))
        }
        let initialsHeight: CGFloat = page.homeInitials.isEmpty || showsTurnAtTop ? 0 : 22
        let initialsSpace = initialsHeight == 0 ? 0 : initialsHeight + gap
        let footerRowsHeight = max(0, CGFloat(footer.count) * (footerHeight + gap) - gap)
        let footerSpace = groupGap + initialsSpace + footerRowsHeight
        // Balance measured content, including saved games, wrapped captions and the footer list.
        let splits = page.rows.count > 1 ? Array(1..<page.rows.count) : [page.rows.count]
        let split = splits.min { a, b in
            func score(_ index: Int) -> CGFloat {
                abs(rows(Array(page.rows.prefix(index)), in: left).bottom + footerSpace
                    - rows(Array(page.rows.dropFirst(index)), in: right).bottom)
            }
            return score(a) < score(b)
        } ?? 0
        let measuredLeft = rows(Array(page.rows.prefix(split)), in: left).bottom + footerSpace
        let measuredRight = rows(Array(page.rows.dropFirst(split)), in: right).bottom + 24
        let logoGrowth = min(max(0, height - max(measuredLeft, measuredRight)),
            max(0, GameMenuLogo.preferredHeight(width: heading.width) - heading.height))
        heading.size.height += logoGrowth
        subtitle.origin.y += logoGrowth
        turnInitials.origin.y += logoGrowth
        start += logoGrowth
        let leading = rows(Array(page.rows.prefix(split)), in: left)
        let trailing = rows(Array(page.rows.dropFirst(split)), in: right)
        let contentHeight = max(height, max(leading.bottom + footerSpace, trailing.bottom) + bottomPadding)
        // Reserve actual footer bounds, without adding a trailing row gap to the scroll extent.
        var footerY = contentHeight - bottomPadding - footerRowsHeight
        let initials = showsTurnAtTop ? turnInitials : CGRect(x: left.minX + padding,
            y: footerY - initialsSpace, width: leftWidth, height: initialsHeight)
        var footerTargets: [GameFrontEnd.Target] = []
        for action in footer {
            footerTargets.append(.init(action: action, frame: CGRect(x: left.minX + padding, y: footerY,
                width: leftWidth, height: footerHeight)))
            footerY += footerHeight + gap
        }
        let header = page.orderedFooter.filter { headerIDs.contains($0.id) }.map { action in
            GameFrontEnd.Target(action: action, frame: CGRect(x: action.id == "settings" ? right.maxX - 56 : left.minX + padding,
                y: 22, width: 44, height: 44))
        }
        let targets = (leading.targets + footerTargets + trailing.targets + header).sorted {
            let a = $0.frame.midX >= right.minX ? 1 : 0
            let b = $1.frame.midX >= right.minX ? 1 : 0
            return a == b ? $0.frame.minY < $1.frame.minY : a < b
        }
        return GameFrontEnd.Layout(size: CGSize(width: width, height: contentHeight),
            board: CGRect(x: left.minX, y: 12, width: left.width, height: contentHeight - 24),
            heading: heading, subtitle: subtitle, preview: .zero, details: [],
            targets: targets,
            initials: initials,
            secondaryBoard: CGRect(x: right.minX, y: 12, width: right.width, height: contentHeight - 24),
            libraryHeading: libraryHeading)
    }
}
