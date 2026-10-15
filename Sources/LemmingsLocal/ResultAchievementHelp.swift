#if os(macOS)
import AppKit
import NxlvKit
import LemmingsGameArt

@MainActor extension ArcadeView {
    func achievementLink(_ label: String, in rect: CGRect, title: String, detail: String,
                         action: @escaping () -> Void) {
        link(label, rect, alignment: .left, action: action)
        achievementHints.append((label, rect, title, detail))
    }

    func achievementTarget(_ title: String, detail: String, in rect: CGRect, action: @escaping () -> Void) {
        // The whole star is a target, including its empty corners.
        achievementHints.append((title, rect, title, detail))
        registerAchievementTarget(title, rect: rect, action: action)
    }

    func showResultAchievement(_ details: [(title: String, detail: String)]) {
        guard !details.isEmpty else { return }
        achievementDetails = details
        achievementDetailIndex = 0
        page(.achievement)
    }

    func achievementTextHeight(_ value: String, width: CGFloat, face: ClassicMacUserInterface.Face = .small) -> CGFloat {
        let bitmap = font?.font(face)
        let lines = GameTextLayout.lines(value, width: width, face: face, font: bitmap)
        return CGFloat(lines.count) * GameTextLayout.linePitch(value, face: face, font: bitmap)
    }

    var achievementHeadingRect: CGRect {
        guard !achievementDetails.isEmpty else { return .zero }
        let award = achievementDetails[achievementDetailIndex % achievementDetails.count]
        return CGRect(x: 96, y: 68, width: 928,
                      height: achievementTextHeight(award.title, width: 928, face: .large))
    }
    var achievementBodyRect: CGRect {
        guard !achievementDetails.isEmpty else { return .zero }
        let award = achievementDetails[achievementDetailIndex % achievementDetails.count]
        return CGRect(x: 96, y: achievementHeadingRect.maxY + 24, width: 928,
                      height: achievementTextHeight(award.detail, width: 928))
    }
    var achievementFooterY: CGFloat { achievementBodyRect.maxY + 32 }

    func drawAchievementExplanation() {
        guard !achievementDetails.isEmpty else { page(.result); return }
        let award = achievementDetails[achievementDetailIndex % achievementDetails.count]
        let heading = achievementHeadingRect, body = achievementBodyRect
        if let font {
            font.menuParagraph(award.title, in: heading, alignment: .left, face: .large, palette: .green)
        } else { GamePixelText.draw(award.title, in: heading) }
        paragraph(award.detail, body)
        var actions = [ResultAction(title: report == nil ? L10n.text("Back") : L10n.text("Back to result"), primary: achievementDetails.count == 1) { [weak self] in self?.back() }]
        if achievementDetails.count > 1 {
            actions.append(ResultAction(title: L10n.text("Next award") + " \(achievementDetailIndex + 1)/\(achievementDetails.count) >", primary: true) { [weak self] in
                guard let self else { return }
                self.achievementDetailIndex = (self.achievementDetailIndex + 1) % self.achievementDetails.count
                self.needsDisplay = true
            })
        }
        resultActionRow(actions, y: achievementFooterY)
        setAccessibilityLabel(award.title + ". " + award.detail)
        registerAchievementText(award.title, rect: heading)
        registerAchievementText(award.detail, rect: body)
    }

    func drawAchievementHover() {
        guard mode == .result, let hint = achievementHints.first(where: { $0.label == hover }) else { return }
        let width: CGFloat = 720, padding: CGFloat = 24
        let headingHeight = achievementTextHeight(hint.title, width: width - 2 * padding)
        let bodyHeight = achievementTextHeight(hint.detail, width: width - 2 * padding)
        let height = 2 * padding + headingHeight + 12 + bodyHeight
        let x = min(1056 - width, max(64, hint.rect.midX - width / 2)).rounded()
        let y = hint.rect.minY - height - 12 >= 32 ? hint.rect.minY - height - 12 : hint.rect.maxY + 12
        let card = CGRect(x: x, y: y, width: width, height: height)
        GameStoneButton.draw(card, selected: false, pixel: 2)
        GameStyle.fill(card.insetBy(dx: 8, dy: 8), .black)
        let heading = CGRect(x: x + padding, y: y + padding, width: width - 2 * padding, height: headingHeight)
        let body = CGRect(x: heading.minX, y: heading.maxY + 12, width: heading.width, height: bodyHeight)
        if let font { font.menuParagraph(hint.title, in: heading, alignment: .left, palette: .green) }
        else { GamePixelText.draw(hint.title, in: heading) }
        paragraph(hint.detail, body)
    }
}
#endif
