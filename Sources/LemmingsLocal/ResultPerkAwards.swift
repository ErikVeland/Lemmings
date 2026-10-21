#if os(macOS)
import AppKit
import LemmingsAppCore
import NxlvKit

@MainActor extension ArcadeView {
    struct EarnedPerk {
        enum Kind: Hashable { case superzoom, skip, extraSkill }
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
        guard let report, let c = celebration, report.run.earnsConsumableRewards,
              !savedEarnedRewards.isEmpty else { return [] }
        var perks: [EarnedPerk] = []
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
        if report.earnedExtraSkill {
            perks.append(.init(kind: .extraSkill, name: L10n.text("BONUS SKILL"), quantity: 1,
                milestone: milestone, criterion: L10n.text("Every 10 distinct levels · Rare"), star: 3))
        }
        return perks
    }

    func perkIsRevealed(_ perk: EarnedPerk) -> Bool { !celebratesNewRewards || revealedStars >= perk.star }
    struct PerkCounter {
        let kind: EarnedPerk.Kind
        let name: String
        let value: Int
        var label: String { name + " " + String(value) }
    }

    var perkCounters: [PerkCounter] {
        let wallet = PrecisionZoomController.shared
        let balances: [(EarnedPerk.Kind, String, Int)] = [
            (.superzoom, L10n.text("Superzoom"), wallet.remainingSuperzoom(profileID: player.id)),
            (.skip, L10n.text("Level Skips"), ArcadeStore.shared.records.levelSkips(profileID: player.id).available),
            (.extraSkill, L10n.text("Bonus skills"), ArcadeStore.shared.records.extraSkills(profileID: player.id).available)
        ]
        let earned = earnedPerks
        return balances.map { kind, name, balance in
            let pending = earned.first { $0.kind == kind && !perkIsRevealed($0) }?.quantity ?? 0
            return .init(kind: kind, name: name, value: max(0, balance - pending))
        }
    }

    func glowPerkCounters(at star: Int) {
        guard celebratesNewRewards else { return }
        let kinds = earnedPerks.filter { $0.star == star }.map(\.kind)
        guard !kinds.isEmpty else { return }
        perkGlowTask?.cancel()
        glowingPerks.formUnion(kinds); perkGlowAmount = 1
        perkGlowTask = Task { @MainActor [weak self] in
            for step in 1...18 {
                do { try await Task.sleep(nanoseconds: 33_000_000) } catch { return }
                guard let self, self.mode == .result else { return }
                self.perkGlowAmount = 1 - CGFloat(step) / 18
                self.needsDisplay = true
            }
            self?.glowingPerks = []; self?.perkGlowTask = nil
        }
    }

    func drawPerkCounters(in rect: CGRect) {
        let counters = perkCounters
        let width = (rect.width - 12 * CGFloat(max(0, counters.count - 1))) / CGFloat(max(1, counters.count))
        for (index, counter) in counters.enumerated() {
            let frame = CGRect(x: rect.minX + CGFloat(index) * (width + 12), y: rect.minY, width: width, height: rect.height)
            let digits = String(counter.value)
            let numberWidth = max(14, (font?.width(of: digits, face: .small, scale: 1) ?? CGFloat(digits.count * 12)) + 6)
            let number = CGRect(x: frame.maxX - numberWidth, y: frame.minY, width: numberWidth, height: frame.height)
            let glowing = glowingPerks.contains(counter.kind) && perkGlowAmount > 0
            if glowing {
                GameStyle.fill(number.insetBy(dx: -4, dy: -3), GameStyle.gold.withAlphaComponent(0.10 * perkGlowAmount))
                GameStyle.fill(number.insetBy(dx: -2, dy: -1), GameStyle.gold.withAlphaComponent(0.25 * perkGlowAmount))
            }
            let name = counter.kind == .skip ? L10n.text("Skips") : counter.name
            let label = CGRect(x: frame.minX, y: frame.minY, width: frame.width - numberWidth - 4, height: frame.height)
            if let font {
                font.menuLine(name, in: label, alignment: .right)
                font.menuLine(digits, in: number, alignment: .right, palette: glowing ? .green : .blue)
            } else {
                GamePixelText.draw(name, in: label)
                GamePixelText.draw(digits, in: number, palette: glowing ? .green : .blue)
            }
            registerAchievementText(counter.label, rect: frame)
        }
    }
}
#endif
