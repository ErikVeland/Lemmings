import AppKit
import NxlvKit

/**
 * Asks before the first network count. The choice can change in Settings.
 */
@MainActor final class TelemetryConsentWindow {
    static let shared = TelemetryConsentWindow()
    private let telemetry: AnonymousTelemetry
    private var page: GameMenuPage?

    init(telemetry: AnonymousTelemetry = .shared) {
        self.telemetry = telemetry
    }

    func showIfNeeded(in window: NSWindow, completion: @escaping () -> Void) {
        guard telemetry.endpoint != nil, !telemetry.consentDecided else { completion(); return }
        let page = GameMenuPage(title: "Share play counts?", subtitle: "Your choice")
        page.backTitle = "Not now"
        let heading = GameLabel(labelWithString: "Help us find levels that need work")
        heading.role = .heading
        heading.frame = CGRect(x: 0, y: 360, width: 992, height: 34)
        page.body.addSubview(heading)
        let details = [
            "Send daily use, level results and lemmings saved.",
            "Include solo or Hot Seat and all-soundtrack download choices.",
            "No names, IDs, pack names or replays are sent.",
            "The shared saved total stays until the service resets it.",
            "The service sees your network address during delivery.",
            "Change this in Settings > Privacy.",
        ]
        for (index, line) in details.enumerated() {
            let label = GameLabel(labelWithString: line)
            label.frame = CGRect(x: 0, y: 300 - index * 36, width: 992, height: 32)
            page.body.addSubview(label)
        }
        let choose: (Bool) -> Void = { [weak self, weak page] enabled in
            guard let self else { return }
            self.telemetry.setSharing(enabled)
            if let page { GameScreen.shared.dismiss(page) }
            self.page = nil
            completion()
        }
        page.onBack = { choose(false) }
        page.addPrimaryAction("Share counts") { choose(true) }
        page.preferControllerControl(page.controllerBackButton)
        self.page = page
        GameScreen.shared.present(page, owner: window)
    }
}

/**
 * Shows local counts and, with an owner token, shared daily totals.
 */
@MainActor final class TelemetryDashboard {
    static let shared = TelemetryDashboard()
    private let telemetry: AnonymousTelemetry
    private var page: GameMenuPage?
    private var summary: AnonymousTelemetrySummary
    private var shared = false
    private var days = 30
    private var notice = "This Mac only. Shared counts need the owner access token."
    private weak var daysButton: NSButton?

    init(telemetry: AnonymousTelemetry = .shared) {
        self.telemetry = telemetry
        summary = telemetry.localSummary()
    }

    func show(owner: NSWindow?) {
        if let page, GameScreen.shared.contains(page) { GameScreen.shared.present(page, owner: owner); return }
        summary = telemetry.localSummary()
        shared = false
        days = 30
        notice = telemetry.endpoint == nil
            ? "This Mac only. No shared service is configured."
            : "This Mac only. Shared counts need the owner access token."
        let page = GameMenuPage(title: "Play insights", subtitle: "Aggregate counts")
        page.onBack = { [weak self, weak page] in
            if let page { GameScreen.shared.dismiss(page) }
            self?.page = nil
        }
        if telemetry.endpoint != nil {
            page.addPrimaryAction("Load shared") { [weak self] in self?.askForToken() }
            page.addSecondaryAction("This Mac") { [weak self] in
                guard let self else { return }
                self.summary = self.telemetry.localSummary()
                self.shared = false
                self.notice = "This Mac only. Shared counts need the owner access token."
                self.daysButton?.isEnabled = false
                self.refresh()
            }
            daysButton = page.addSecondaryAction("Last 30 days", at: 1) { [weak self] in
                guard let self else { return }
                self.days = self.days == 30 ? 7 : 30
                self.daysButton?.title = self.days == 30 ? "Last 30 days" : "Last 7 days"
                self.daysButton?.needsDisplay = true
                if self.shared { self.askForToken() }
            }
            daysButton?.isEnabled = false
        } else {
            daysButton = nil
        }
        self.page = page
        refresh()
        GameScreen.shared.present(page, owner: owner)
    }

    private func askForToken() {
        guard let owner = page?.window, telemetry.endpoint != nil else { return }
        let alert = NSAlert()
        alert.messageText = "Load shared play counts"
        alert.informativeText = "Enter the dashboard access token. The app does not save it."
        let field = NSSecureTextField(frame: CGRect(x: 0, y: 0, width: 340, height: 26))
        field.placeholderString = "Access token"
        field.setAccessibilityLabel("Dashboard access token")
        alert.accessoryView = field
        alert.addButton(withTitle: "Load")
        alert.addButton(withTitle: "Cancel")
        alert.beginSheetModal(for: owner) { [weak self] choice in
            guard choice == .alertFirstButtonReturn, let self else { return }
            let token = field.stringValue
            field.stringValue = ""
            self.loadShared(token: token)
        }
    }

    private func loadShared(token: String) {
        notice = "Loading shared counts…"
        summary = .init(days: days, counts: [])
        shared = false
        daysButton?.isEnabled = false
        refresh()
        Task { [weak self] in
            guard let self else { return }
            do {
                let loaded = try await telemetry.sharedSummary(token: token, days: days)
                guard page != nil else { return }
                summary = loaded
                shared = true
                daysButton?.isEnabled = true
                notice = "Opted-in installations, not unique people. Last \(days) days."
            } catch {
                notice = "Could not load shared counts. Check the token and service."
            }
            refresh()
        }
    }

    private func refresh() {
        guard let page else { return }
        page.body.subviews.forEach { $0.removeFromSuperview() }
        let counts = summary.counts
        let starts = summary.total(.levelStart)
        let wins = summary.total(.levelWin)
        let fails = summary.total(.levelFail)
        let solo = summary.total(.levelStart, mode: "solo")
        let hotSeat = summary.total(.levelStart, mode: "hot_seat")
        let today = Self.utcDay()
        let activeToday = counts.filter { $0.event == AnonymousTelemetryEvent.Kind.activeDay.rawValue && $0.day == today }
            .reduce(0) { $0 + $1.count }
        card("INSTALLS TODAY", shared ? String(activeToday) : "N/A", x: 0, y: 338, in: page.body)
        card("LEVEL STARTS", String(starts), x: 252, y: 338, in: page.body)
        card("WINS / FAILS", "\(wins) / \(fails)", x: 504, y: 338, in: page.body)
        card("ALL MUSIC CHOSEN", String(summary.total(.allSoundtracksSelected)), x: 756, y: 338, in: page.body)
        label("SOLO  \(solo)       HOT SEAT  \(hotSeat)       MUSIC FINISHED  \(summary.total(.allSoundtracksDownloaded))",
              x: 0, y: 287, width: 992, role: .heading, in: page.body)
        label("LEVELS WITH THE MOST FAILED OR UNFINISHED STARTS", x: 0, y: 240,
              width: 992, role: .heading, in: page.body)
        let grouped = Dictionary(grouping: counts.filter { $0.game != nil && $0.level != nil },
                                 by: { ($0.game ?? "") + "|" + ($0.level ?? "") })
        let levels = grouped.map { key, rows -> (String, Int, Int, Int) in
            func sum(_ kind: AnonymousTelemetryEvent.Kind) -> Int {
                rows.filter { $0.event == kind.rawValue }.reduce(0) { $0 + $1.count }
            }
            return (key, sum(.levelStart), sum(.levelWin), sum(.levelFail))
        }.filter { $0.1 > 0 }
            .sorted { lhs, rhs in
                let a = max(lhs.3, lhs.1 - lhs.2), b = max(rhs.3, rhs.1 - rhs.2)
                return a == b ? lhs.1 > rhs.1 : a > b
            }
        if levels.isEmpty {
            label("No level starts yet", x: 0, y: 202, width: 992, in: page.body)
        }
        for (index, level) in levels.prefix(5).enumerated() {
            let y = CGFloat(202 - index * 39)
            label(Self.levelName(level.0), x: 0, y: y, width: 590, in: page.body)
            label("\(level.1) starts   \(level.2) wins   \(level.3) fails", x: 594, y: y,
                  width: 398, in: page.body)
        }
        label(notice, x: 0, y: 0, width: 992, in: page.body)
        page.needsDisplay = true
    }

    private func card(_ title: String, _ value: String, x: CGFloat, y: CGFloat, in view: NSView) {
        let card = TelemetryCard(frame: CGRect(x: x, y: y, width: 236, height: 100))
        let heading = label(title, x: 12, y: 58, width: 212, role: .heading, in: card)
        heading.setAccessibilityLabel(title)
        let number = label(value, x: 12, y: 13, width: 212, role: .title, in: card)
        number.setAccessibilityLabel("\(title): \(value)")
        view.addSubview(card)
    }

    @discardableResult private func label(_ value: String, x: CGFloat, y: CGFloat, width: CGFloat,
                                          role: GameTypography.Role = .body, in view: NSView) -> GameLabel {
        let label = GameLabel(labelWithString: value)
        label.role = role
        label.frame = CGRect(x: x, y: y, width: width, height: 32)
        view.addSubview(label)
        return label
    }

    private static func levelName(_ key: String) -> String {
        let parts = key.split(separator: "|", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return "Level" }
        let game = parts[0], level = parts[1]
        if game == "fan" { return "Fan levels" }
        if game == "lemmings2" { return "Lemmings 2 · \(level)" }
        if game == "lemmings3" { return "Lemmings 3 · \(level)" }
        return "\(ClassicTitle(rawValue: game)?.displayName ?? "Classic") · \(level)"
    }

    private static func utcDay() -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let parts = calendar.dateComponents([.year, .month, .day], from: Date())
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}

@MainActor private final class TelemetryCard: NSView {
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        GameStoneButton.draw(bounds, selected: false, pixel: 1)
    }
}
