#if os(macOS)
import AppKit
import NxlvKit
import LemmingsAppCore

struct ReplaySkillStock {
    let name: String
    let count: String
}
struct ReplaySkillUse {
    let tick: Int
    let name: String
}

/// Read-only replay information leaves camera input on the playfield.
@MainActor final class ReplaySkillPanel: NSView {
    private var stocks: [ReplaySkillStock] = []
    private var uses: [ReplaySkillUse] = []
    private var tick = 0
    private var stockTitle = L10n.text("LEFT")
    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    private func textWidth(_ text: String) -> CGFloat {
        GameMenuArtwork.renderer()?.width(of: MacInterfaceRenderer.menuText(text), face: .small, scale: 1)
            ?? CGFloat(text.count * 6)
    }
    private var countWidth: CGFloat { max(24, stocks.map { textWidth($0.count) + 6 }.max() ?? 24) }
    private var tickWidth: CGFloat { max(48, uses.map { textWidth(String($0.tick)) }.max() ?? 48) }
    private var columns: Int {
        let columnWidth = (stocks.map { textWidth($0.name) }.max() ?? 0) + countWidth + 18
        return stocks.count > 8 && columnWidth * 3 + 16 <= 420 ? 3 : 2
    }
    var logicalSize: CGSize {
        let rows = max(1, (stocks.count + columns - 1) / columns)
        let stockWidth = CGFloat(columns) * ((stocks.map { textWidth($0.name) }.max() ?? 0) + countWidth + 18) + 16
        let historyWidth = (uses.map { textWidth($0.name) }.max() ?? 0) + tickWidth + 42
        return CGSize(width: max(300, stockWidth, historyWidth), height: CGFloat(58 + rows * 18 + 3 * 18))
    }
    func update(stocks: [ReplaySkillStock], uses: [ReplaySkillUse], tick: Int, title: String = L10n.text("LEFT")) {
        self.stocks = stocks; self.uses = Array(uses.suffix(3)); self.tick = tick; stockTitle = title
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel(L10n.text("Tick \(tick). \(title): \(stocks.map { "\(SkillVocabulary.title($0.name)) \($0.count)" }.joined(separator: ", ")). Skills used: \(self.uses.map { L10n.text("\(SkillVocabulary.title($0.name)) at tick \($0.tick)") }.joined(separator: ", "))"))
        needsDisplay = true
    }
    override func draw(_ dirtyRect: NSRect) {
        GameStoneButton.draw(bounds, selected: false, pixel: 1)
        let inner = bounds.insetBy(dx: 8, dy: 6)
        GameControlText.draw(stockTitle, in: CGRect(x: inner.minX, y: inner.minY, width: inner.width, height: 18), role: .heading)
        let width = inner.width / CGFloat(columns)
        let rows = max(1, (stocks.count + columns - 1) / columns)
        if stocks.isEmpty {
            GameControlText.draw(L10n.text("NONE"), in: CGRect(x: inner.minX, y: inner.minY + 18, width: inner.width, height: 18))
        }
        for (index, stock) in stocks.enumerated() {
            let row = CGRect(x: inner.minX + CGFloat(index % columns) * width,
                y: inner.minY + 18 + CGFloat(index / columns) * 18, width: width - 6, height: 18)
            GameControlText.draw(SkillVocabulary.title(stock.name), in: CGRect(x: row.minX, y: row.minY, width: row.width - countWidth - 6, height: 18), enabled: stock.count != "0")
            GameControlText.draw(stock.count, in: CGRect(x: row.maxX - countWidth, y: row.minY, width: countWidth, height: 18), alignment: .right, enabled: stock.count != "0")
        }
        let historyY = inner.minY + 24 + CGFloat(rows) * 18
        GameControlText.draw(L10n.text("USED @ TICK"), in: CGRect(x: inner.minX, y: historyY, width: inner.width, height: 18), role: .heading)
        for (index, use) in uses.enumerated() {
            let row = CGRect(x: inner.minX, y: historyY + 18 + CGFloat(index) * 18, width: inner.width, height: 18)
            let current = use.tick == tick
            GameControlText.draw(current ? ">" : "", in: CGRect(x: row.minX, y: row.minY, width: 12, height: 18), role: .heading)
            GameControlText.draw(String(use.tick), in: CGRect(x: row.minX + 14, y: row.minY, width: tickWidth, height: 18), role: current ? .heading : .body)
            GameControlText.draw(SkillVocabulary.title(use.name), in: CGRect(x: row.minX + tickWidth + 26, y: row.minY, width: row.width - tickWidth - 26, height: 18), role: current ? .heading : .body)
        }
    }
}

@MainActor enum ReplaySkillPresentation {
    static func stocks(_ state: ActionReplayState) -> [ReplaySkillStock] {
        switch state {
        case .classic(let game):
            return ClassicSkill.allCases.filter { (game.configuration.initialSkills[$0] ?? 0) > 0 }.map {
                .init(name: $0.rawValue.capitalized, count: String(game.remainingSkillCount($0)))
            }
        case .neolemmix(let game):
            return NeoLemmixSkill.allCases.filter { game.configuration.skills[$0] != nil }.map {
                .init(name: $0.rawValue.capitalized, count: game.skills[$0]?.availableCount.map { String($0) } ?? L10n.text("INF"))
            }
        case .lemmings2(let game):
            return game.configuration.skills.enumerated().map { index, skill in
                .init(name: skill.name, count: String(game.supplies[index]))
            }
        case .lemmings3(let game):
            return Lemmings3Runtime.Tool.allCases.compactMap { tool in
                let held = game.lemmings.filter { $0.active && $0.tool == tool }
                guard !held.isEmpty else { return nil }
                return .init(name: String(describing: tool).capitalized, count: String(held.reduce(0) { $0 + $1.quantity }))
            }
        }
    }
}
#endif
