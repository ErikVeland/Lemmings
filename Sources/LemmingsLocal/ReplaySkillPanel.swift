#if os(macOS)
import AppKit
import NxlvKit
import LemmingsAppCore
import LemmingsGameArt

struct ReplaySkillStock: Equatable {
    let name: String
    let count: String
}
struct ReplaySkillUse: Equatable {
    let tick: Int
    let name: String
}

/// Read-only replay information leaves camera input on the playfield.
@MainActor final class ReplaySkillPanel: NSView {
    private var stocks: [ReplaySkillStock] = []
    private var uses: [ReplaySkillUse] = []
    private var tick = 0
    private var rate = 0.0
    private var stockTitle = L10n.text("LEFT")
    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    private func textWidth(_ text: String) -> CGFloat {
        let plain = MacInterfaceRenderer.menuText(text)
        return GameMenuArtwork.renderer()?.width(of: plain, face: .small, scale: 1)
            ?? CGFloat(GamePixelTypography.width(of: plain) + 1)
    }
    private var rowHeight: CGFloat {
        let captions = [stockTitle, L10n.text("NONE"), L10n.text("Skills used").uppercased()]
            + stocks.flatMap { [SkillVocabulary.title($0.name), $0.count] }
            + uses.flatMap { [SkillVocabulary.title($0.name), ReplayGameTime.clock(tick: $0.tick, rate: rate)] }
        let renderer = GameMenuArtwork.renderer()
        return captions.reduce(CGFloat(18)) { current, text in
            let plain = MacInterfaceRenderer.menuText(text)
            let bounds = GamePixelTypography.verticalBounds(of: plain)
            let height = renderer?.height(of: plain, face: .small, scale: 1) ?? CGFloat(bounds.bottom - bounds.top)
            let tamil = BitmapTamilGlyphs.sequences(in: plain).contains(where: BitmapTamilGlyphs.supports)
            return max(current, tamil || height > 18 ? height + 2 : 18)
        }
    }
    private var countWidth: CGFloat { max(24, stocks.map { textWidth($0.count) + 6 }.max() ?? 24) }
    private var timeWidth: CGFloat {
        max(textWidth("88:88.88"), uses.map { textWidth(ReplayGameTime.clock(tick: $0.tick, rate: rate)) }.max() ?? 0)
    }
    private var columns: Int {
        let columnWidth = (stocks.map { textWidth(SkillVocabulary.title($0.name)) }.max() ?? 0) + countWidth + 18
        return stocks.count > 8 && columnWidth * 3 + 16 <= 420 ? 3 : 2
    }
    var logicalSize: CGSize {
        let rows = max(1, (stocks.count + columns - 1) / columns)
        let stockWidth = CGFloat(columns) * ((stocks.map { textWidth(SkillVocabulary.title($0.name)) }.max() ?? 0) + countWidth + 18) + 16
        let historyWidth = (uses.map { textWidth(SkillVocabulary.title($0.name)) }.max() ?? 0) + timeWidth + 42
        return CGSize(width: max(300, stockWidth, historyWidth), height: 22 + CGFloat(rows + 5) * rowHeight)
    }
    func update(stocks: [ReplaySkillStock], uses: [ReplaySkillUse], tick: Int, rate: Double, title: String = L10n.text("LEFT")) {
        let recent = Array(uses.suffix(3))
        let historyChanged = self.stocks != stocks || self.uses != recent || self.rate != rate || stockTitle != title
        let highlightChanged = self.tick != tick && recent.contains { $0.tick == self.tick || $0.tick == tick }
        self.tick = tick
        if historyChanged {
            self.stocks = stocks; self.uses = recent; self.rate = rate; stockTitle = title
            let stock = stocks.map { "\(SkillVocabulary.title($0.name)) \($0.count)" }.joined(separator: ", ")
            let history = recent.map { ReplayGameTime.skillUse($0.name, tick: $0.tick, rate: rate) }.joined(separator: ", ")
            setAccessibilityElement(true)
            setAccessibilityRole(.group)
            setAccessibilityLabel(L10n.text("\(title): \(stock.isEmpty ? L10n.text("None") : stock).")
                + (history.isEmpty ? "" : " " + L10n.text("Skills used: \(history)")))
        }
        if historyChanged || highlightChanged { needsDisplay = true }
    }
    override func draw(_ dirtyRect: NSRect) {
        GameDisplayPanel.draw(bounds)
        let inner = bounds.insetBy(dx: 8, dy: 6)
        let height = rowHeight
        GameControlText.draw(stockTitle, in: CGRect(x: inner.minX, y: inner.minY, width: inner.width, height: height), role: .heading)
        let width = inner.width / CGFloat(columns)
        let rows = max(1, (stocks.count + columns - 1) / columns)
        if stocks.isEmpty {
            GameControlText.draw(L10n.text("NONE"), in: CGRect(x: inner.minX, y: inner.minY + height, width: inner.width, height: height))
        }
        for (index, stock) in stocks.enumerated() {
            let row = CGRect(x: inner.minX + CGFloat(index % columns) * width,
                y: inner.minY + height + CGFloat(index / columns) * height, width: width - 6, height: height)
            GameControlText.draw(SkillVocabulary.title(stock.name), in: CGRect(x: row.minX, y: row.minY, width: row.width - countWidth - 6, height: height), enabled: stock.count != "0")
            GameControlText.draw(stock.count, in: CGRect(x: row.maxX - countWidth, y: row.minY, width: countWidth, height: height), alignment: .right, enabled: stock.count != "0")
        }
        let historyY = inner.minY + height + 6 + CGFloat(rows) * height
        GameControlText.draw(L10n.text("Skills used").uppercased(), in: CGRect(x: inner.minX, y: historyY, width: inner.width, height: height), role: .heading)
        let timeWidth = timeWidth
        for (index, use) in uses.enumerated() {
            let row = CGRect(x: inner.minX, y: historyY + height + CGFloat(index) * height, width: inner.width, height: height)
            let current = use.tick == tick
            GameControlText.draw(current ? ">" : "", in: CGRect(x: row.minX, y: row.minY, width: 12, height: height), role: .heading)
            GameControlText.draw(ReplayGameTime.clock(tick: use.tick, rate: rate), in: CGRect(x: row.minX + 14, y: row.minY, width: timeWidth, height: height), role: current ? .heading : .body)
            GameControlText.draw(SkillVocabulary.title(use.name), in: CGRect(x: row.minX + timeWidth + 26, y: row.minY, width: row.width - timeWidth - 26, height: height), role: current ? .heading : .body)
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
