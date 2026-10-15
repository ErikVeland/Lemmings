#if os(macOS)
import AppKit
import LemmingsAppCore
import NxlvKit

@MainActor extension ArcadeView {
    struct EarnedPerk {
        enum Kind { case zoom, superzoom, skip }
        let kind: Kind
        let name: String
        let quantity: Int
        let milestone: String
        let criterion: String
        let star: Int
        var title: String { "+\(quantity) \(name)" }
        var detail: String { title + ". " + milestone + ". " + criterion + "." }
    }

    var earnedPerks: [EarnedPerk] {
        guard let report, let c = celebration, !report.run.assisted, report.run.qualifies,
              !savedEarnedRewards.isEmpty else { return [] }
        var perks: [EarnedPerk] = []
        if c.precisionRewards.zoomUses > 0 {
            let star = (1...max(1, c.goals.stars)).first {
                (c.careerBefore.stars + max(0, $0 - c.previousStars)) / 3 > c.careerBefore.stars / 3
            } ?? c.goals.stars
            perks.append(.init(kind: .zoom, name: L10n.text("ZOOM"), quantity: c.precisionRewards.zoomUses,
                milestone: L10n.text("Career stars \(c.careerBefore.stars) > \(c.career.stars)"),
                criterion: L10n.text("Every 3 career stars"), star: star))
        }
        let milestone = L10n.text("Three-star levels \(c.careerBefore.threeStarLevels) > \(c.career.threeStarLevels)")
        let criterion = L10n.text("Every 3 distinct levels")
        if c.precisionRewards.superzoomUses > 0 {
            perks.append(.init(kind: .superzoom, name: L10n.text("SUPERZOOM"), quantity: c.precisionRewards.superzoomUses,
                milestone: milestone, criterion: criterion, star: 3))
        }
        if report.earnedLevelSkip {
            perks.append(.init(kind: .skip, name: L10n.text("LEVEL SKIP"), quantity: 1,
                milestone: milestone, criterion: criterion, star: 3))
        }
        return perks
    }

    func perkIsRevealed(_ perk: EarnedPerk) -> Bool { !celebratesNewRewards || revealedStars >= perk.star }
    var perkSectionY: CGFloat { 247 + resultSummaryOffset + (resultStatus == nil ? 0 : 38) }

    func drawEarnedPerks() {
        let perks = earnedPerks
        guard !perks.isEmpty else { return }
        text(L10n.text("NEW PERKS"), 80, perkSectionY, 620, height: 22, palette: .green)
        link(L10n.text("Rewards earned (\(savedEarnedRewards.count)) >"),
             CGRect(x: 720, y: perkSectionY - 2, width: 320, height: 28), alignment: .right) { [weak self] in self?.showEarnedRewards() }
        let frames = resultActionFrames(count: perks.count, y: perkSectionY + 32, height: 98)
        for (perk, frame) in zip(perks, frames) {
            let earned = perkIsRevealed(perk)
            let stamped = celebratesNewRewards && stampedStar == perk.star
            GameStoneButton.draw(frame, selected: earned, pixel: 1)
            GameStyle.fill(frame.insetBy(dx: 4, dy: 4), earned ? GameStyle.gold.withAlphaComponent(0.09) : .black)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current?.cgContext.setAlpha(earned ? 1 : 0.28)
            drawPerkIcon(perk.kind, at: CGPoint(x: frame.minX + 16, y: frame.minY + 12))
            let quantity = CGRect(x: frame.minX + 53, y: frame.minY + 10, width: 52, height: 28)
            title("+\(perk.quantity)", x: quantity.minX, y: quantity.minY, width: quantity.width, height: quantity.height)
            text(perk.name, frame.minX + 112, frame.minY + 16, frame.width - 124, height: 22, palette: .green)
            text(perk.milestone, frame.minX + 16, frame.minY + 48, frame.width - 32, height: 22)
            text(perk.criterion, frame.minX + 16, frame.minY + 71, frame.width - 32, height: 22, alpha: 0.8)
            NSGraphicsContext.restoreGraphicsState()
            if earned {
                GameStyle.fill(CGRect(x: frame.minX + 8, y: frame.maxY - 5, width: frame.width - 16, height: 2), GameStyle.gold)
            }
            if stamped {
                GameStyle.gold.setStroke()
                let edge = NSBezierPath(rect: frame.insetBy(dx: 2, dy: 2)); edge.lineWidth = 2; edge.stroke()
            }
            achievementTarget(perk.title, detail: perk.detail, in: frame) { [weak self] in self?.showEarnedRewards() }
        }
    }

    private func drawPerkIcon(_ kind: EarnedPerk.Kind, at origin: CGPoint) {
        let rows: [String]
        switch kind {
        case .zoom, .superzoom:
            rows = ["  ######    ", " ##    ##   ", "##      ##  ", "##      ##  ",
                    "##      ##  ", "##      ##  ", " ##    ##   ", "  ######    ",
                    "       ###  ", "        ### ", "         ###", "          ##"]
        case .skip:
            rows = ["##        ##", "####      ##", "######    ##", "########  ##",
                    "########  ##", "######    ##", "####      ##", "##        ##",
                    "            ", "            ", "            ", "            "]
        }
        for (y, row) in rows.enumerated() {
            for (x, pixel) in row.enumerated() where pixel == "#" {
                GameStyle.fill(CGRect(x: origin.x + CGFloat(x * 2), y: origin.y + CGFloat(y * 2), width: 2, height: 2), GameStyle.gold)
            }
        }
        if kind == .superzoom {
            GameStyle.fill(CGRect(x: origin.x + 8, y: origin.y + 4, width: 2, height: 8), GameStyle.accent)
            GameStyle.fill(CGRect(x: origin.x + 5, y: origin.y + 7, width: 8, height: 2), GameStyle.accent)
        }
    }
}
#endif
