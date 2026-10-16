import CoreGraphics
import NxlvKit

/// A second screen keeps every goal and earned reward available together.
public enum MobileResultAchievementsArt {
    public struct Item: Equatable, Sendable {
        public let title: String
        public let detail: String
        /// nil is an award receipt; 0/1 are outlined/filled stars; 2 is an unknown target.
        public let star: Int?
        public init(_ title: String, detail: String, star: Int? = nil) {
            self.title = title; self.detail = detail; self.star = star
        }
    }

    public static func resultScale(_ preferred: CGFloat, page: GameFrontEnd.Page, width: CGFloat, height: CGFloat) -> CGFloat {
        var scale = preferred
        while scale > 1 {
            if GameFrontEnd.layout(page, width: width / scale, minimumHeight: height / scale, fillsResultPane: true).size.height * scale <= height + 0.5 { return scale }
            scale = max(1, scale - 0.05)
        }
        return 1
    }

    public static func goals(_ goals: TrolleyRescueGoals) -> [Item] {
        [Item(L10n.text("Target met"), detail: L10n.plural("count.rescueGoal", count: goals.requiredSaved,
            one: "Rescue %ld lemming and clear the level.", other: "Rescue %ld lemmings and clear the level."), star: goals.stars >= 1 ? 1 : 0),
         Item(L10n.text("Extra rescue"), detail: L10n.plural("count.secondStarGoal", count: goals.extraSaved,
            one: "Save %ld lemming and clear the level to earn the second star.", other: "Save %ld lemmings and clear the level to earn the second star."), star: goals.stars >= 2 ? 1 : 0),
         Item(L10n.text("Three-star rescue"), detail: goals.fullSaved.map { L10n.plural("count.thirdStarGoal", count: $0,
            one: "Save %ld lemming and clear the level to earn the third star.", other: "Save %ld lemmings and clear the level to earn the third star.") }
            ?? L10n.text("The maximum rescue target for this level is not established yet."), star: goals.fullSaved == nil ? 2 : goals.stars >= 3 ? 1 : 0)]
    }

    public static func page(_ items: [Item]) -> GameFrontEnd.Page {
        var page = GameFrontEnd.Page(title: L10n.text("Achievements"), details: items.flatMap { [$0.title, $0.detail] })
        page.achievementItems = items
        return page
    }

    public static func layout(_ page: GameFrontEnd.Page, width: CGFloat, minimumHeight: CGFloat) -> GameFrontEnd.Layout {
        let width = max(280, width), inset: CGFloat = 28, gap: CGFloat = 12
        let inner = width - inset * 2
        let heading = CGRect(x: inset, y: 28, width: inner, height: 36)
        let items = page.achievementItems ?? []
        let columns = inner >= 640 ? 3 : inner >= 430 ? 2 : 1
        let cell = floor((inner - CGFloat(columns - 1) * gap) / CGFloat(columns))
        var details: [CGRect] = [], y = heading.maxY + 16
        let goalCount = items.prefix { $0.star != nil }.count
        let groups = goalCount > 0 ? [0..<goalCount, goalCount..<items.count] : [0..<items.count]
        for group in groups where !group.isEmpty {
            if group.lowerBound > 0 { y += 12 }
            for start in stride(from: group.lowerBound, to: group.upperBound, by: columns) {
                let end = min(start + columns, group.upperBound)
                let rowCell = end - start == 1 ? inner : cell
                var heights: [(CGFloat, CGFloat)] = []
                for index in start..<end {
                    heights.append((GameTextLayout.height(items[index].title, width: rowCell - 32),
                        GameTextLayout.height(items[index].detail, width: rowCell - 32)))
                }
                let rowHeight = heights.map { $0.0 + $0.1 + 60 }.max() ?? 0
                for (offset, heights) in heights.enumerated() {
                    let x = inset + CGFloat(offset) * (rowCell + gap)
                    details.append(CGRect(x: x + 16, y: y + 36, width: rowCell - 32, height: heights.0))
                    details.append(CGRect(x: x + 16, y: y + 44 + heights.0, width: rowCell - 32, height: heights.1))
                }
                y += rowHeight + gap
            }
        }
        let height = max(minimumHeight, y + 28)
        return .init(size: .init(width: width, height: height), board: .init(x: 14, y: 14, width: width - 28, height: height - 28),
            heading: heading, subtitle: .zero, preview: .zero, details: details, targets: [])
    }

    public static func draw(_ page: GameFrontEnd.Page, layout: GameFrontEnd.Layout,
                            typography: GameMenuTypography, in context: CGContext) {
        for (index, item) in (page.achievementItems ?? []).enumerated() {
            let title = layout.details[index * 2], detail = layout.details[index * 2 + 1]
            let rowBottom = stride(from: 0, to: layout.details.count, by: 2).filter {
                layout.details[$0].minY == title.minY
            }.map { layout.details[$0 + 1].maxY }.max() ?? detail.maxY
            let card = CGRect(x: title.minX - 16, y: title.minY - 36, width: title.width + 32, height: rowBottom - title.minY + 52)
            context.setFillColor(CGColor(srgbRed: 0.055, green: 0.075, blue: 0.04, alpha: 1)); context.fill(card)
            context.setStrokeColor(CGColor(gray: 0.35, alpha: 1)); context.setLineWidth(1); context.stroke(card.insetBy(dx: 0.5, dy: 0.5))
            if let star = item.star {
                if star == 2 {
                    GameTextLayout.draw("?", in: CGRect(x: card.midX - 12, y: card.minY + 8, width: 24, height: 20), typography: typography, context: context)
                } else { GameStarArt.draw(at: CGPoint(x: card.midX - 11, y: card.minY + 8), earned: star == 1, size: 2, context: context) }
            }
            GameTextLayout.draw(item.title, in: title, typography: typography, palette: .green, context: context)
            GameTextLayout.draw(item.detail, in: detail, typography: typography, context: context)
        }
    }
}
