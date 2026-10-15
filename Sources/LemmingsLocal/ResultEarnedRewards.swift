#if os(macOS)
import AppKit
import LemmingsAppCore
import NxlvKit

@MainActor extension ArcadeView {
    func showEarnedRewards() {
        guard !savedEarnedRewards.isEmpty else { return }
        earnedRewardPage = 0
        page(.earnedRewards)
    }

    func returnFromEarnedRewards() {
        page(.result)
        startCelebration()
    }

    private func rewardHeight(_ reward: ResultAwards.EarnedReward) -> CGFloat {
        achievementTextHeight(reward.title, width: 886)
            + achievementTextHeight(reward.reason, width: 886) + 28
    }

    var earnedRewardPages: [[ResultAwards.EarnedReward]] {
        var pages: [[ResultAwards.EarnedReward]] = []
        var rows: [ResultAwards.EarnedReward] = []
        var height: CGFloat = 0
        for reward in savedEarnedRewards {
            let next = rewardHeight(reward) + 12
            if !rows.isEmpty, height + next > 394 {
                pages.append(rows); rows = []; height = 0
            }
            rows.append(reward); height += next
        }
        if !rows.isEmpty { pages.append(rows) }
        return pages
    }

    func advanceEarnedRewards() {
        if earnedRewardPage + 1 < earnedRewardPages.count {
            earnedRewardPage += 1
            needsDisplay = true
        } else { returnFromEarnedRewards() }
    }

    func drawEarnedRewards() {
        let pages = earnedRewardPages
        guard !pages.isEmpty else { returnFromEarnedRewards(); return }
        earnedRewardPage = min(earnedRewardPage, pages.count - 1)
        title(L10n.text("REWARDS EARNED"), x: 80, y: 48, width: 960, height: 40)
        text(L10n.text("\(player.initials)'s attempt"), 80, 100, 720, height: 26, palette: .green)
        text("\(earnedRewardPage + 1)/\(pages.count)", 840, 100, 200, alignment: .right, height: 26)
        text(report?.run.level.title ?? "", 80, 134, 960, height: 26, alpha: 0.8)
        var y: CGFloat = 178
        for reward in pages[earnedRewardPage] {
            let height = rewardHeight(reward)
            let card = CGRect(x: 64, y: y, width: 992, height: height)
            GameStoneButton.draw(card, selected: false, pixel: 1)
            GameStyle.fill(card.insetBy(dx: 4, dy: 4), .black)
            GameStar.draw(at: CGPoint(x: 82, y: y + 16), earned: true, size: 2)
            let heading = CGRect(x: 130, y: y + 12, width: 886,
                                 height: achievementTextHeight(reward.title, width: 886))
            let reason = CGRect(x: 130, y: heading.maxY + 4, width: 886,
                                height: achievementTextHeight(reward.reason, width: 886))
            if let font { font.menuParagraph(reward.title, in: heading, alignment: .left, palette: .green) }
            else { GamePixelText.draw(reward.title, in: heading) }
            paragraph(reward.reason, reason)
            registerAchievementText(reward.title, rect: heading)
            registerAchievementText(reward.reason, rect: reason)
            y += height + 12
        }
        text(resultBalanceText, 80, 584, 960, height: 26)
        if earnedRewardPage > 0 {
            button(L10n.text("Previous rewards"), CGRect(x: 64, y: 634, width: 330, height: 48)) { [weak self] in
                guard let self else { return }
                self.earnedRewardPage -= 1; self.needsDisplay = true
            }
        } else if pages.count > 1 {
            button(L10n.text("Back to result"), CGRect(x: 64, y: 634, width: 330, height: 48)) { [weak self] in
                self?.returnFromEarnedRewards()
            }
        }
        button(earnedRewardPage + 1 < pages.count ? L10n.text("Next rewards") : L10n.text("View result"),
               CGRect(x: 688, y: 634, width: 368, height: 48), primary: true) { [weak self] in
            self?.advanceEarnedRewards()
        }
        let reasons = savedEarnedRewards.map { $0.title + ". " + $0.reason }.joined(separator: " ")
        setAccessibilityLabel(L10n.text("Rewards earned by \(player.initials). \(reasons) \(resultBalanceText). Page \(earnedRewardPage + 1) of \(pages.count). Escape returns to the result."))
    }
}
#endif
