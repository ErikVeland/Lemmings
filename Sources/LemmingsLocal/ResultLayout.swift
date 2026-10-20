#if os(macOS)
import AppKit
import LemmingsAppCore
import NxlvKit

@MainActor extension ArcadeView {
    struct ResultAction {
        let title: String
        var primary = false
        var enabled = true
        let action: () -> Void
    }

    func resultActionFrames(count: Int, y: CGFloat, height: CGFloat = 48) -> [CGRect] {
        guard count > 0 else { return [] }
        let gap: CGFloat = 16
        let width = (992 - gap * CGFloat(count - 1)) / CGFloat(count)
        return (0..<count).map { index in
            let left = (64 + CGFloat(index) * (width + gap)).rounded()
            let right = (64 + CGFloat(index) * (width + gap) + width).rounded()
            return CGRect(x: left, y: y, width: right - left, height: height)
        }
    }

    func resultActionRow(_ actions: [ResultAction], y: CGFloat, links: Bool = false) {
        let frames = resultActionFrames(count: actions.count, y: y, height: links ? 36 : 48)
        for (action, frame) in zip(actions, frames) {
            if links {
                GameStyle.fill(frame, GameStyle.accent.withAlphaComponent(0.045))
                link(action.title, frame, alpha: 0.8, action: action.action)
            } else {
                button(action.title, frame, primary: action.primary, enabled: action.enabled, action: action.action)
            }
        }
    }

    var resultIdentity: String {
        "\(player.initials)'s attempt - " + (report?.run.level.title ?? "")
            + (report?.run.assisted == true ? L10n.text(" - Rewinds used") : "")
            + (report?.run.usedBonusSkill == true ? L10n.text(" - Bonus skill used") : "")
    }
    var resultIdentityHeight: CGFloat { achievementTextHeight(resultIdentity, width: 960) }
    var resultSummaryOffset: CGFloat { max(0, resultIdentityHeight - 36) }
    var resultCardsY: CGFloat {
        247 + resultSummaryOffset + (resultStatus != nil ? 38 : 0)
    }
    var resultActionsY: CGFloat {
        let hasReviewRow = cleared || onLater == nil || nextSessionPlayer != nil || offersSkip
        return resultCardsY + (hasReviewRow ? 220 : 168)
    }
    var pageContentHeight: CGFloat {
        switch mode {
        case .result: return resultActionsY + 86
        case .earnedRewards: return earnedRewardsFooterY + 86
        case .achievement: return achievementFooterY + 86
        default: return 720
        }
    }

    func resultActions(y: CGFloat) {
        let back = ResultAction(title: L10n.text("Back")) { [weak self] in self?.onClose?() }
        let retry = ResultAction(title: nextSessionPlayer == nil ? L10n.text("Retry") : L10n.text("Retry as \(player.initials)")) { [weak self] in self?.onRetry?() }
        let primary = ResultAction(title: primaryResultTitle, primary: true) { [weak self] in self?.performDefaultResultAction() }
        let skip = ResultAction(title: skipTitle, enabled: canSpendSkip) { [weak self] in self?.skipLevel() }
        if !cleared, onLater != nil {
            let later = ResultAction(title: L10n.text("Try later")) { [weak self] in self?.onLater?() }
            var review: [ResultAction] = []
            if nextSessionPlayer != nil { review.append(retry) }
            if offersSkip { review.append(later) }
            resultActionRow(review, y: y - 52, links: true)
            let hints = ResultAction(title: L10n.text("Hints")) { [weak self] in self?.onHints?() }
            resultActionRow([back, hints, offersSkip ? skip : later, primary], y: y)
            return
        }
        resultActionRow([
            ResultAction(title: L10n.text("Replay")) { [weak self] in self?.onReplay?(false) },
            ResultAction(title: L10n.text("Records")) { [weak self] in self?.page(.records) },
            ResultAction(title: L10n.text("Details")) { [weak self] in self?.page(.details) },
            ResultAction(title: L10n.text("Hot Seat")) { [weak self] in self?.openSession() },
            ResultAction(title: L10n.text("Worldwide")) { [weak self] in self?.openWorldwideBoard() }
        ], y: y - 52, links: true)
        if let next = nextSessionPlayer {
            let canHandOver = ArcadeStore.shared.profilesAreWritable && ArcadeStore.shared.storageError == nil
            let library = ResultAction(title: L10n.text("Back to library")) { [weak self] in
                if let prepare = ArcadeWindow.shared.prepareSession { _ = prepare() } else { self?.onClose?() }
            }
            let nextRetry = ResultAction(title: L10n.text("Retry as \(next.initials)"), primary: !cleared, enabled: canHandOver) { [weak self] in self?.retryAsNextProfile() }
            if cleared {
                let owner = handsOverAfterClear ?? player
                let forward = ResultAction(title: "\(continueTitle): \(owner.initials)", primary: true,
                    enabled: handsOverAfterClear == nil || canHandOver) { [weak self] in self?.continueAsNextProfile() }
                resultActionRow([library, retry, nextRetry, forward], y: y)
            } else {
                resultActionRow(offersSkip ? [library, retry, skip, nextRetry] : [library, retry, nextRetry], y: y)
            }
        } else {
            var actions = [back]
            if cleared { actions.append(retry) }
            if offersSkip { actions.append(skip) }
            actions.append(primary)
            resultActionRow(actions, y: y)
        }
    }
}
#endif
