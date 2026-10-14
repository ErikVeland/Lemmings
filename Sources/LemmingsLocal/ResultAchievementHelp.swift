#if os(macOS)
import AppKit
import NxlvKit

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
        let cellWidth = font?.font(face)?.cellWidth ?? 12
        let bitmap = font?.font(face)
        let lineHeight = max((bitmap?.cellHeight ?? 16) + 6,
                             (bitmap?.height(of: MacInterfaceRenderer.menuText(value)) ?? 16) + 2)
        return CGFloat(MacInterfaceRenderer.menuLines(value, columns: max(1, Int(width) / cellWidth)).count * lineHeight)
    }

    func drawAchievementExplanation() {
        guard !achievementDetails.isEmpty else { page(.result); return }
        let award = achievementDetails[achievementDetailIndex % achievementDetails.count]
        let width: CGFloat = 928
        let headingHeight = achievementTextHeight(award.title, width: width, face: .large)
        let heading = CGRect(x: 96, y: 68, width: width, height: headingHeight)
        let body = CGRect(x: 96, y: heading.maxY + 36, width: width,
                          height: achievementTextHeight(award.detail, width: width))
        if let font {
            font.menuParagraph(award.title, in: heading, alignment: .left, face: .large, palette: .green)
        } else { GamePixelText.draw(award.title, in: heading) }
        paragraph(award.detail, body)
        pageFooter()
        if achievementDetails.count > 1 {
            button(L10n.text("Next award") + " \(achievementDetailIndex + 1)/\(achievementDetails.count) >",
                   CGRect(x: 712, y: 634, width: 344, height: 48)) { [weak self] in
                guard let self else { return }
                self.achievementDetailIndex = (self.achievementDetailIndex + 1) % self.achievementDetails.count
                self.needsDisplay = true
            }
        }
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
