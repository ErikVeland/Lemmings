import AppKit
import NxlvKit

@MainActor final class ArcadeWindow {
    static let shared = ArcadeWindow()
    let arcadeView = ArcadeView()
    var prepareSession: (() -> NSWindow?)?
    var finishSession: (() -> Void)?
    private init() { arcadeView.onClose = { [weak self] in self?.close() } }
    static func captureScene(_ view: NSView) -> CGImage? {
        let size = CGSize(width: max(1, view.bounds.width), height: max(1, view.bounds.height))
        return ReplayFrameCapture.image(size: size) { ReplayFrameCapture.draw(view, in: CGRect(origin: .zero, size: size)) }
    }
    func close() { if arcadeView.mode == .hotSeat { finishSession?() }; arcadeView.finishCelebration(); arcadeView.affinityPopover?.close(); GameScreen.shared.dismiss(arcadeView) }
    private func present(owner: NSWindow? = nil) {
        arcadeView.needsDisplay = true
        GameScreen.shared.present(arcadeView, owner: owner)
    }
    func showResult(_ report: ArcadeReport, owner: NSWindow? = nil, retry: @escaping () -> Void,
                    next: @escaping () -> Void, replay: @escaping (Bool) -> Void, continueTitle: String = "Next level", background: CGImage? = nil, rewardVolume: Double = 0) {
        arcadeView.rewardVolume = rewardVolume
        arcadeView.mode = .result; arcadeView.report = report; arcadeView.level = report.run.level
        arcadeView.assisted = report.run.assisted; arcadeView.board = .rescue; arcadeView.trolleyBoard = .mostSaved
        arcadeView.boardScope = .level
        arcadeView.continueTitle = continueTitle; arcadeView.background = background
        arcadeView.onRetry = { [weak self] in self?.close(); retry() }
        arcadeView.onContinue = { [weak self] in self?.close(); next() }
        arcadeView.onReplay = replay
        present(owner: owner)
        arcadeView.startCelebration()
        GameCenterScores.shared.onChange = { [weak self] in self?.arcadeView.needsDisplay = true }
    }
    func showRecords(level: ArcadeLevel?, owner: NSWindow? = nil, background: CGImage? = nil) {
        arcadeView.background = background
        arcadeView.mode = .records; arcadeView.report = nil
        arcadeView.level = level ?? ArcadeStore.shared.records.runs.last?.level
        arcadeView.assisted = false; arcadeView.board = .rescue
        arcadeView.boardScope = .level
        arcadeView.onRetry = nil; arcadeView.onContinue = nil; arcadeView.onReplay = nil
        present(owner: owner)
    }
    func showSession(owner: NSWindow? = nil) {
        let owner = prepareSession?() ?? owner
        arcadeView.sessionReturnMode = nil
        arcadeView.report = nil; arcadeView.onRetry = nil; arcadeView.onContinue = nil
        ArcadeStore.shared.prepareHotSeat()
        arcadeView.mode = .hotSeat
        present(owner: owner)
    }
    func showProfiles(canSwitch: Bool, owner: NSWindow? = nil, beforeSwitch: @escaping () -> Void, afterSwitch: @escaping () -> Void, background: CGImage? = nil) {
        arcadeView.background = background
        arcadeView.highlightedAwards = []; arcadeView.focusedNewAward = nil
        arcadeView.mode = .profiles; arcadeView.canSwitch = canSwitch
        arcadeView.beforeSwitch = beforeSwitch; arcadeView.afterSwitch = afterSwitch
        arcadeView.selectProfile(ArcadeStore.shared.records.activeProfile)
        present(owner: owner)
    }
}

/// Results lead with the rescue. Records and details are separate game pages.
@MainActor final class ArcadeView: NSView {
    enum Mode { case result, profiles, records, awards, details, goals, career, hotSeat }
    enum BoardScope { case level, career, worldwide }
    var mode = Mode.records { didSet { if mode != oldValue { keyboardButton = nil } } }
    var report: ArcadeReport? {
        didSet {
            finishCelebration()
            highlightedAwards = []; focusedNewAward = nil; featuredAwardIndex = 0; careerPage = 0
            celebration = report.map { TrolleyCelebration(report: $0, history: ArcadeStore.shared.records.trolley) }
        }
    }
    var celebration: TrolleyCelebration?
    var celebrationTask: Task<Void, Never>?
    var celebrationGeneration = UUID()
    let rewardChimes = ResultChimes()
    var rewardVolume: Double = 0
    var revealedStars = 3
    var stampedStar: Int?
    var featuredAwardIndex = 0
    var careerPage = 0
    var boardScope = BoardScope.level
    var level: ArcadeLevel?
    var assisted = false
    var board = ArcadeBoard.rescue
    var trolleyBoard = TrolleyBoard.mostSaved
    var awardGroup = TrolleyAchievementGroup.rescue
    var awardPage = 0
    var highlightedAwards: Set<TrolleyAchievement> = []
    var focusedNewAward: TrolleyAchievement?
    var affinityPopover: NSPopover?
    var awardsPerPage: Int { 4 }
    var awardPageCount: Int {
        let count = level?.conditions == nil ? careerAwards.count
            : (awardGroup == .rescue ? careerAwards.count : 0) + offeredAwards.count
        return max(1, (count + awardsPerPage - 1) / awardsPerPage)
    }
    var careerAwards: [ArcadeLevelAchievement] {
        let earned = ArcadeStore.shared.records.careerAchievements(profileID: player.id)
        // A completed hands-free clear establishes that this challenge is possible.
        return ArcadeLevelAchievement.allCases.filter { $0 != .noSkills || earned.contains($0) }
    }
    var offeredAwards: [TrolleyAchievement] {
        let earned = Set(ArcadeStore.shared.records.trolley.attempts.filter { $0.run.profileID == player.id }.flatMap(\.achievements))
        return TrolleyAchievement.allCases.filter { $0.group == awardGroup && ($0.isOffered || earned.contains($0)) }
    }
    var sessionReturnMode: Mode?
    var canSwitch = true
    var beforeSwitch: (() -> Void)?
    var afterSwitch: (() -> Void)?
    var onRetry: (() -> Void)?
    var onContinue: (() -> Void)?
    var onReplay: ((Bool) -> Void)?
    var onClose: (() -> Void)?
    var continueTitle = "Next level"
    var cleared: Bool { report?.run.qualifies == true }
    var nextSessionPlayer: ArcadeProfile? { ArcadeStore.shared.nextSessionProfile(after: player.id) }
    /// Every level hands over after a clear too. At first fail keeps the winner in.
    var passesTurnOnClear: Bool { ArcadeStore.shared.turnPolicy == .everyLevel }
    var handsOverAfterClear: ArcadeProfile? { passesTurnOnClear ? nextSessionPlayer : nil }
    /// A win keeps the seat: retrying is how a player improves their own score.
    /// A loss gives it up, so retrying hands the Mac to the next player.
    var retryOwner: ArcadeProfile? { cleared ? player : nextSessionPlayer }
    var primaryResultTitle: String {
        if cleared { return handsOverAfterClear.map { "\(continueTitle): \($0.initials)" } ?? continueTitle }
        return nextSessionPlayer.map { "Retry as \($0.initials)" } ?? "Try again"
    }
    private func showHandover(_ next: ArcadeProfile, owner: NSWindow?) {
        guard let owner else { return }
        let page = GameMenuPage(title: "\(next.initials)'s turn", subtitle: "PASS THE CONTROLS")
        page.controllerBackButton.isHidden = true
        page.setDetail("The game will wait. Give the controls to \(next.initials), then choose Ready.")
        page.addPrimaryAction("Ready, \(next.initials)") { [weak page] in
            if let page { GameScreen.shared.dismiss(page) }
        }
        GameScreen.shared.present(page, owner: owner)
    }
    func retryAsNextProfile() {
        guard let next = nextSessionPlayer else { return }
        let owner = window
        guard ArcadeStore.shared.passSessionTurn(after: player.id) else { needsDisplay = true; return }
        onRetry?()
        showHandover(next, owner: owner)
    }
    func continueAsNextProfile() {
        let next = handsOverAfterClear, owner = window
        if next != nil, !ArcadeStore.shared.passSessionTurn(after: player.id) { needsDisplay = true; return }
        onContinue?()
        if let next { showHandover(next, owner: owner) }
    }
    func performDefaultResultAction() { if cleared { continueAsNextProfile() } else if nextSessionPlayer != nil { retryAsNextProfile() } else { onRetry?() } }
    private(set) var selectedProfileID: String?
    private(set) var initials = "LEM"
    private(set) var portrait = 0
    private var replaceInitials = true
    private var artwork: ClassicMacArtwork?
    var font: MacInterfaceRenderer?
    var background: CGImage?
    private var portraits: [Int: NSImage] = [:]
    private var buttons: [(String, CGRect, () -> Void)] = []
    private let accessibleElements = GameAccessibleElements()
    private var accessibleText: [(String, CGRect)] = []
    private var keyboardButton: Int?
    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .group }
    override func accessibilityChildren() -> [Any]? {
        func mapped(_ rect: CGRect) -> CGRect { CGRect(x: offset.x + rect.minX * scale, y: offset.y + rect.minY * scale, width: rect.width * scale, height: rect.height * scale) }
        var result: [Any] = accessibleText.enumerated().map { index, item in
            accessibleElements.element(id: "text-\(index)", owner: self, label: item.0, frame: mapped(item.1))
        }
        result += buttons.enumerated().map { index, item in
            var name = item.0
            if name.hasPrefix("player-"), let profile = ArcadeStore.shared.records.profile(String(name.dropFirst(7))) { name = "Select player " + profile.initials }
            if name.hasPrefix("portrait-"), let index = Int(name.dropFirst(9)), ArcadeProfile.portraitNames.indices.contains(index) { name = "Portrait: " + ArcadeProfile.portraitNames[index] }
            return accessibleElements.element(id: "button-\(index)", owner: self, label: name, frame: mapped(item.1), press: item.2)
        }
        if mode == .profiles {
            let field = accessibleElements.element(id: "initials", owner: self, label: "Player initials", frame: mapped(CGRect(x: 564, y: 204, width: 430, height: 60)))
            field.setAccessibilityRole(.textField)
            field.readValue = { [weak self] in self?.initials ?? "" }
            field.writeValue = { [weak self] value in
                self?.initials = String(value.uppercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) }.prefix(3))
                self?.replaceInitials = false; self?.needsDisplay = true
            }
            result.insert(field, at: 0)
        }
        return result
    }
    private var hover: String?
    private var tracking: NSTrackingArea?
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override init(frame: NSRect) {
        super.init(frame: frame)
        if let url = Bundle.main.resourceURL?.appendingPathComponent("MacArtwork/lemmings") {
            useArtwork(try? ClassicMacArtwork(directory: url))
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    func useArtwork(_ artwork: ClassicMacArtwork?) {
        self.artwork = artwork
        font = artwork.flatMap(ClassicMacUserInterface.init(artwork:)).map(MacInterfaceRenderer.init(interface:))
        portraits.removeAll(); needsDisplay = true
    }
    func selectProfile(_ profile: ArcadeProfile) {
        selectedProfileID = profile.id; initials = profile.initials; portrait = profile.portrait
        replaceInitials = true; needsDisplay = true
    }
    private var scale: CGFloat { max(0.01, min(bounds.width / 1120, bounds.height / 720)) }
    private var offset: CGPoint { CGPoint(x: (bounds.width - 1120 * scale) / 2, y: (bounds.height - 720 * scale) / 2) }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill(); bounds.fill(); buttons = []; accessibleText = []
        if let background {
            let image = NSImage(cgImage: background, size: CGSize(width: background.width, height: background.height))
            let fit = max(bounds.width / image.size.width, bounds.height / image.size.height)
            let size = CGSize(width: image.size.width * fit, height: image.size.height * fit)
            image.draw(in: CGRect(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2, width: size.width, height: size.height),
                from: .zero, operation: .sourceOver, fraction: 0.6, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.none])
        }
        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform(); transform.translateX(by: offset.x, yBy: offset.y)
        transform.scale(by: scale); transform.concat()
        let panel = CGRect(x: 44, y: 20, width: 1032, height: 676)
        GameStyle.fill(panel, NSColor.black.withAlphaComponent(0.94))
        GameMenuFrame.draw(panel)
        switch mode {
        case .result: drawResult()
        case .profiles: drawProfiles()
        case .hotSeat: drawSession()
        case .records: drawRecords()
        case .awards: drawAwards()
        case .details: drawDetails()
        case .goals: drawLevelGoals()
        case .career: drawCareerProgress()
        }
        if let error = ArcadeStore.shared.storageError {
            text(error, 64, 695, 814, height: 20)
            if ArcadeStore.shared.profilesAreWritable {
                button("Retry save", CGRect(x: 886, y: 688, width: 170, height: 30)) { [weak self] in
                    guard let self else { return }
                    if self.mode == .profiles { self.saveProfile() }
                    else { ArcadeStore.shared.save() }
                    self.needsDisplay = true
                }
            }
        } else if let notice = ArcadeStore.shared.storageNotice {
            text(notice, 64, 695, 980, height: 20)
        }
        setAccessibilityHelp(ArcadeStore.shared.storageError ?? ArcadeStore.shared.storageNotice)
        if let keyboardButton, buttons.indices.contains(keyboardButton) {
            NSColor.systemYellow.setStroke()
            let outline = NSBezierPath(rect: buttons[keyboardButton].1.insetBy(dx: -2, dy: -2))
            outline.lineWidth = 2; outline.stroke()
        }
        NSGraphicsContext.restoreGraphicsState()
    }
    func text(_ value: String, _ x: CGFloat, _ y: CGFloat, _ width: CGFloat,
        alignment: NSTextAlignment = .left, height: CGFloat = 36, alpha: CGFloat = 1, palette: MacInterfaceRenderer.Palette = .blue) {
        let rect = CGRect(x: x, y: y, width: width, height: height)
        accessibleText.append((value, rect))
        if let font { font.menuLine(value, in: rect, alignment: alignment, alpha: alpha, palette: palette) }
        else {
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current?.cgContext.setAlpha(alpha)
            GamePixelText.draw(value, in: rect)
            NSGraphicsContext.restoreGraphicsState()
        }
    }
    func rowText(_ value: String, x: CGFloat, width: CGFloat, row: CGRect,
                 alignment: NSTextAlignment = .left) {
        let lineHeight = font?.height(face: .small, scale: 1) ?? 18
        text(value, x, row.midY - lineHeight / 2, width, alignment: alignment, height: lineHeight)
    }
    func title(_ value: String, x: CGFloat = 64, y: CGFloat, width: CGFloat = 992, height: CGFloat = 36) {
        let rect = CGRect(x: x, y: y, width: width, height: height)
        accessibleText.append((value, rect))
        if let font {
            let scale = max(1, min(Int(height / 20), Int(width / max(1, font.width(of: MacInterfaceRenderer.menuText(value), face: .large, scale: 1)))))
            font.menuLine(value, in: rect, face: .large, scale: scale, palette: .green)
        } else { GamePixelText.draw(value, in: rect) }
    }
    func button(_ label: String, _ rect: CGRect, primary: Bool = false, selected: Bool = false,
        enabled: Bool = true, action: @escaping () -> Void) {
        let chosen = enabled && (primary || selected || hover == label)
        GameStyle.fill(rect, chosen ? NSColor(calibratedRed: 0.06, green: 0.16, blue: 0.035, alpha: 1) : NSColor(calibratedWhite: 0.025, alpha: 1))
        (chosen ? NSColor(calibratedRed: 0.48, green: 0.80, blue: 0.24, alpha: 1) : NSColor(calibratedWhite: 0.29, alpha: 1)).setStroke()
        NSBezierPath(rect: rect.insetBy(dx: 0.5, dy: 0.5)).stroke()
        let caption = CGRect(x: rect.minX + 12, y: rect.midY - 10, width: rect.width - 24, height: 20)
        if let font {
            let face: ClassicMacUserInterface.Face = font.width(of: MacInterfaceRenderer.menuText(label), face: .large, scale: 1) <= caption.width ? .large : .small
            font.menuLine(label, in: caption, face: face, alpha: enabled ? 1 : 0.45, palette: chosen ? .green : .blue)
        } else { GamePixelText.draw(label, in: caption) }
        if enabled { buttons.append((label, rect, action)) }
    }
    func link(_ label: String, _ rect: CGRect, alpha: CGFloat = 1, alignment: NSTextAlignment = .center, palette: MacInterfaceRenderer.Palette = .blue, action: @escaping () -> Void) {
        text(label, rect.minX, rect.midY - 9, rect.width, alignment: alignment, alpha: hover == label ? 1 : alpha, palette: hover == label ? .green : palette)
        if hover == label {
            NSColor(calibratedWhite: 0.6, alpha: 1).setFill()
            CGRect(x: rect.minX + 8, y: rect.maxY - 3, width: rect.width - 16, height: 1).fill()
        }
        buttons.append((label, rect, action))
    }
    func rewindFilter(y: CGFloat = 212) {
        text("Rewinds", 786, y - 21, 270, alignment: .center, alpha: 0.7)
        button("Unused", CGRect(x: 786, y: y, width: 135, height: 44), selected: !assisted) { [weak self] in
            self?.assisted = false; self?.needsDisplay = true
        }
        button("Used", CGRect(x: 921, y: y, width: 135, height: 44), selected: assisted) { [weak self] in
            self?.assisted = true; self?.needsDisplay = true
        }
    }
    func affinityLink(_ id: String, in rect: CGRect, forRun: Bool = true, alignment: NSTextAlignment = .center) {
        let affinity = TrolleyAnalyser.archetype(id)
        link(affinity.name, rect, alpha: 0.8, alignment: alignment) { [weak self] in
            self?.showAffinity(id, at: rect, forRun: forRun)
        }
    }
    func showAffinity(_ id: String, at rect: CGRect, forRun: Bool = true) {
        guard window != nil else { return }
        affinityPopover?.close()
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = false
        popover.appearance = NSAppearance(named: .darkAqua)
        let controller = NSViewController()
        controller.view = AffinityPopoverView(affinity: TrolleyAnalyser.archetype(id), font: font, forRun: forRun)
        popover.contentViewController = controller
        popover.contentSize = controller.view.frame.size
        affinityPopover = popover
        let anchor = CGRect(x: offset.x + rect.minX * scale, y: offset.y + rect.minY * scale,
                            width: rect.width * scale, height: rect.height * scale)
        popover.show(relativeTo: anchor, of: self, preferredEdge: .maxY)
    }
    func resultActions() {
        if let next = nextSessionPlayer {
            let canHandOver = ArcadeStore.shared.profilesAreWritable && ArcadeStore.shared.storageError == nil
            button("Retry as \(player.initials)", CGRect(x: 64, y: 573, width: 330, height: 48)) { [weak self] in self?.onRetry?() }
            if cleared {
                let owner = handsOverAfterClear ?? player
                button("\(continueTitle): \(owner.initials)", CGRect(x: 412, y: 573, width: 330, height: 48), primary: true,
                       enabled: handsOverAfterClear == nil || canHandOver) { [weak self] in self?.continueAsNextProfile() }
                button("Retry as \(next.initials)", CGRect(x: 760, y: 573, width: 296, height: 48), enabled: canHandOver) { [weak self] in self?.retryAsNextProfile() }
            } else {
                button("Retry as \(next.initials)", CGRect(x: 412, y: 573, width: 330, height: 48), primary: true,
                       enabled: canHandOver) { [weak self] in self?.retryAsNextProfile() }
                button("Back to library", CGRect(x: 760, y: 573, width: 296, height: 48)) { [weak self] in
                    if let prepare = ArcadeWindow.shared.prepareSession { _ = prepare() } else { self?.onClose?() }
                }
            }
        } else {
        button(primaryResultTitle, CGRect(x: cleared ? 592 : 248, y: 573, width: 360, height: 48), primary: true) { [weak self] in self?.performDefaultResultAction() }
        button(cleared ? "Retry" : "Back", CGRect(x: cleared ? 168 : 688, y: 573, width: 256, height: 48)) { [weak self] in
            guard let self else { return }
            if self.cleared { self.onRetry?() } else { self.onClose?() }
        }
        }
        link("Replay", CGRect(x: 64, y: 640, width: 110, height: 36), alpha: 0.8) { [weak self] in self?.onReplay?(false) }
        link("Records", CGRect(x: 190, y: 640, width: 140, height: 36), alpha: 0.8) { [weak self] in self?.page(.records) }
        link("Details", CGRect(x: 350, y: 640, width: 140, height: 36), alpha: 0.8) { [weak self] in self?.page(.details) }
        link("Players", CGRect(x: 510, y: 640, width: 140, height: 36), alpha: 0.8) { [weak self] in self?.openSession() }
        if let id = report?.trolley?.attempt.philosophy.primaryID {
            affinityLink(id, in: CGRect(x: 680, y: 640, width: 350, height: 36))
        }
    }
    var player: ArcadeProfile {
        let records = ArcadeStore.shared.records
        return records.profile(report?.run.profileID ?? records.activeProfileID) ?? records.activeProfile
    }
    func header(_ heading: String, subtitle: String? = nil) {
        title(heading, x: 96, y: 48, width: 928, height: 40)
        text(subtitle ?? level?.game ?? "Ultimate Lemmings", 96, 106, 928, alignment: .center)
    }
    func page(_ next: Mode) { finishCelebration(); affinityPopover?.close(); mode = next; hover = nil; needsDisplay = true }
    private func back() {
        if mode == .hotSeat { closeSession(); return }
        if mode != .result && mode != .profiles && report != nil { page(.result) }
        else { onClose?() }
    }
    func pageFooter() {
        button(report == nil ? "Back" : "Back to result", CGRect(x: 64, y: 634, width: 240, height: 48)) { [weak self] in self?.back() }
        if report == nil && mode == .records && boardScope == .level {
            link("< Previous level", CGRect(x: 614, y: 634, width: 244, height: 48)) { [weak self] in self?.changeLevel(-1) }
            link("Next level >", CGRect(x: 890, y: 634, width: 166, height: 48)) { [weak self] in self?.changeLevel(1) }
        }
    }
    func tabs() {
        let items: [(Mode, String)] = [(.records, "Leaderboards"), (.awards, "Achievements"), (.details, "Run details")]
        let gap: CGFloat = 16
        let width = (1056 - 64 - gap * CGFloat(items.count - 1)) / CGFloat(items.count)
        for (index, item) in items.enumerated() {
            button(item.1, CGRect(x: 64 + CGFloat(index) * (width + gap), y: 141, width: width, height: 46), selected: mode == item.0) { [weak self] in self?.page(item.0) }
        }
    }
    private func drawResult() {
        guard let report else { page(.records); return }
        drawGameResult(report)
    }
    func portraitImage(_ index: Int) -> NSImage? {
        if let cached = portraits[index] { return cached }
        let poses: [ClassicLemmingPose] = [.walking, .climbing, .floating, .building, .bashing, .mining, .digging, .blocking]
        guard poses.indices.contains(index), let frame = artwork?.lemming(pose: poses[index], left: false, tick: 3),
              let provider = CGDataProvider(data: frame.rgba as CFData),
              let cg = CGImage(width: frame.width, height: frame.height, bitsPerComponent: 8, bitsPerPixel: 32,
                bytesPerRow: frame.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue), provider: provider,
                decode: nil, shouldInterpolate: false, intent: .defaultIntent) else { return nil }
        let image = NSImage(cgImage: cg, size: NSSize(width: frame.width, height: frame.height))
        portraits[index] = image; return image
    }
    func drawPortrait(_ index: Int, in rect: CGRect) {
        guard let image = portraitImage(index) else {
            text(ArcadeProfile.portraitNames[max(0, min(7, index))], rect.minX, rect.midY - 10, rect.width); return
        }
        let scale = max(1, floor(min(rect.width / image.size.width, rect.height / image.size.height)))
        let size = NSSize(width: image.size.width * scale, height: image.size.height * scale)
        image.draw(in: CGRect(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2, width: size.width, height: size.height),
                   from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true,
                   hints: [.interpolation: NSImageInterpolation.none])
    }
    private func saveProfile() {
        let store = ArcadeStore.shared
        guard store.profilesAreWritable else { return }
        guard canSwitch || selectedProfileID == store.records.activeProfileID else { return }
        if canSwitch { beforeSwitch?() }
        guard store.saveProfile(id: selectedProfileID, initials: initials, portrait: portrait, select: canSwitch) != nil else {
            needsDisplay = true
            return
        }
        if canSwitch { afterSwitch?() }
        onClose?()
    }
    func openSession() {
        guard mode != .profiles || canSwitch else { return }
        if ArcadeWindow.shared.prepareSession != nil { ArcadeWindow.shared.showSession(owner: window); return }
        ArcadeStore.shared.prepareHotSeat(); sessionReturnMode = mode; page(.hotSeat)
    }
    func closeSession() { if let previous = sessionReturnMode { page(previous) } else { onClose?() } }
    private func drawSession() {
        let store = ArcadeStore.shared
        header("Take turns", subtitle: "HOT SEAT")
        text("A hot seat needs at least two players. Press 1-8 to join or leave.", 64, 142, 992)
        for (index, profile) in store.records.profiles.enumerated() {
            let chosen = store.sessionProfiles.contains { $0.id == profile.id }
            let position = store.sessionProfiles.firstIndex { $0.id == profile.id }.map { String($0 + 1) } ?? "-"
            let rect = CGRect(x: 64 + (index % 2) * 506, y: 195 + (index / 2) * 75, width: 486, height: 60)
            button("\(index + 1). \(profile.initials)\(chosen ? " - Turn " + position : "")\(profile.id == store.records.activeProfileID ? " (host)" : "")", rect, selected: chosen) { [weak self] in
                store.toggleSessionProfile(profile.id); self?.needsDisplay = true
            }
        }
        // The roster grid is as tall as the profiles need, so two players do not
        // leave a hole in the middle and eight do not push the buttons off screen.
        let rows = min(4, (store.records.profiles.count + 1) / 2)
        var y = 195 + CGFloat(rows) * 75 + 14
        text("Pass the turn", 64, y + 6, 300, palette: .green)
        for (index, policy) in ArcadeStore.TurnPolicy.allCases.enumerated() {
            button(policy.title, CGRect(x: 370 + CGFloat(index) * 348, y: y, width: 336, height: 44),
                   selected: store.turnPolicy == policy) { [weak self] in
                store.turnPolicy = policy; self?.needsDisplay = true
            }
        }
        y += 54
        text(store.turnPolicy.detail, 64, y, 992, alpha: 0.8); y += 30
        text("Current turn: \(store.records.profile(store.playingProfileID)?.initials ?? "LEM")", 64, y, 992); y += 30
        // The last lines are dropped rather than drawn over the buttons.
        // A hot seat needs a second player. Saying so beats a silent no-op when
        // only the host is selected, which looks identical to a started session.
        let chosen = store.hotSeatIsActive ? store.sessionProfiles.count : 0
        let guidance: (String, MacInterfaceRenderer.Palette)? = store.records.profiles.count < 2
            ? ("Add another player in Player Profiles to take turns.", .blue)
            : chosen < 2
            ? ("Press a number to add a second player. A hot seat needs at least two.", .green)
            : ("\(chosen) players ready. Your shared campaign is saved.", .green)
        let footerTop: CGFloat = 620
        let reserved: CGFloat = guidance == nil ? 0 : 30
        if y + 30 + reserved <= footerTop {
            text("Shared campaign saved separately from solo play", 64, y, 992); y += 30
        }
        if y + 30 + reserved <= footerTop {
            text("Each turn keeps its own scores, records and achievements.", 64, y, 992); y += 30
        }
        if let guidance { text(guidance.0, 64, min(y, footerTop - 30), 992, palette: guidance.1) }
        button("Return to solo", CGRect(x: 64, y: 634, width: 270, height: 48)) { [weak self] in store.endHotSeat(); self?.closeSession() }
        button("Done", CGRect(x: 736, y: 634, width: 320, height: 48), primary: true) { [weak self] in self?.closeSession() }
        setAccessibilityLabel("Hot seat. " + store.sessionProfiles.map(\.initials).joined(separator: ", ")
            + ". Pass the turn \(store.turnPolicy.title). \(store.turnPolicy.detail)"
            + " Number keys choose players. Return to the start menu to begin. Enter returns to the game.")
    }
    private func drawProfiles() {
        header("Choose your lemming", subtitle: "PLAYER SELECT")
        let records = ArcadeStore.shared.records
        text("Players", 64, 150, 250)
        for (index, profile) in records.profiles.enumerated() {
            let rect = CGRect(x: 64, y: 185 + index * 43, width: 264, height: 38)
            let selected = profile.id == selectedProfileID
            GameStyle.fill(rect, selected ? NSColor(calibratedWhite: 0.22, alpha: 1) : .clear)
            drawPortrait(profile.portrait, in: CGRect(x: 73, y: rect.minY + 2, width: 30, height: 34))
            rowText(profile.initials, x: 119, width: 94, row: rect)
            if profile.id == ArcadeStore.shared.playingProfileID { rowText("Playing", x: 216, width: 100, row: rect) }
            else if profile.id == records.activeProfileID { rowText("Host", x: 216, width: 100, row: rect) }
            buttons.append(("player-" + profile.id, rect, { [weak self] in self?.selectProfile(profile) }))
        }
        if records.profiles.count < 8 && canSwitch {
            link("+ New player", CGRect(x: 78, y: 190 + records.profiles.count * 43, width: 235, height: 38)) { [weak self] in
                self?.selectedProfileID = nil; self?.initials = ""; self?.portrait = 0; self?.replaceInitials = true; self?.needsDisplay = true
            }
        }
        GameStyle.fill(CGRect(x: 364, y: 158, width: 1, height: 404), GameStyle.muted.withAlphaComponent(0.2))
        drawPortrait(portrait, in: CGRect(x: 417, y: 153, width: 108, height: 136))
        text("YOUR INITIALS", 564, 167, 440)
        title(initials.padding(toLength: 3, withPad: "_", startingAt: 0), x: 564, y: 204, width: 430, height: 60)
        text("Type up to three letters or numbers", 564, 268, 450)
        text("Choose a portrait", 418, 318, 600)
        for index in 0..<8 {
            let rect = CGRect(x: 418 + index % 4 * 160, y: 356 + index / 4 * 102, width: 144, height: 90)
            GameStyle.fill(rect, index == portrait ? NSColor(calibratedWhite: 0.22, alpha: 1) : NSColor.clear)
            if index == portrait { GameStyle.fill(CGRect(x: rect.minX, y: rect.maxY - 3, width: rect.width, height: 3), NSColor.lightGray) }
            drawPortrait(index, in: CGRect(x: rect.midX - 26, y: rect.minY + 6, width: 52, height: 55))
            text(ArcadeProfile.portraitNames[index], rect.minX, rect.minY + 66, rect.width, alignment: .center)
            buttons.append(("portrait-\(index)", rect, { [weak self] in self?.portrait = index; self?.needsDisplay = true }))
        }
        text(canSwitch ? "Each player keeps their own progress and records." : "Finish this run before changing players.", 64, 575, 992)
        button(canSwitch ? "Play as \(initials.isEmpty ? "LEM" : initials)" : "Save portrait", CGRect(x: 418, y: 627, width: 336, height: 55), primary: true, enabled: canSwitch || selectedProfileID == records.activeProfileID) { [weak self] in self?.saveProfile() }
        button("Hot seat", CGRect(x: 774, y: 627, width: 282, height: 55), enabled: canSwitch) { [weak self] in self?.openSession() }
        button("Back", CGRect(x: 64, y: 627, width: 220, height: 55)) { [weak self] in self?.onClose?() }
        setAccessibilityLabel("Choose your lemming. \(records.profiles.map(\.initials).joined(separator: ", ")). Type initials. Arrow keys choose portraits. Enter saves. Escape goes back.")
    }
    private func drawRecords() {
        if boardScope == .career { drawCareerBoard(); return }
        if boardScope == .worldwide { drawWorldwideBoard(); return }
        if let conditions = level?.conditions { drawTrolleyRecords(conditions); return }
        header(level?.title ?? "Level records"); tabs()
        guard let level else {
            text("Your first rescue starts the story.", 64, 293, 992)
            text("Play a level to set a record.", 64, 346, 992)
            pageFooter(); return
        }
        for (index, category) in ArcadeBoard.allCases.enumerated() {
            let names = ["Most saved", "Fewest skills", "100% club"]
            button(names[index], CGRect(x: 64 + index * 226, y: 213, width: 210, height: 43), selected: board == category) { [weak self] in self?.board = category; self?.needsDisplay = true }
        }
        rewindFilter()
        text("PLAYER", 113, 276, 295)
        text("RESCUED", 493, 276, 240)
        text("SKILLS", 793, 276, 95)
        text("TIME", 918, 276, 140)
        let entries = ArcadeStore.shared.records.leaderboard(level: level, board: board, assisted: assisted)
        if entries.isEmpty {
            text("No records", 64, 368, 992, alignment: .center)
        }
        for (index, run) in entries.prefix(5).enumerated() {
            let y = CGFloat(307 + index * 53)
            let current = run.profileID == player.id
            GameStyle.fill(CGRect(x: 64, y: y, width: 992, height: 47), current ? NSColor(calibratedWhite: 0.22, alpha: 1) : NSColor.clear)
            let row = CGRect(x: 64, y: y, width: 992, height: 47)
            rowText("\(index + 1)", x: 78, width: 40, row: row)
            let owner = ArcadeStore.shared.records.profile(run.profileID)
            drawPortrait(owner?.portrait ?? 0, in: CGRect(x: 132, y: y + 4, width: 32, height: 39))
            rowText(owner?.initials ?? "???", x: 187, width: 290, row: row)
            rowText("\(run.saved)", x: 493, width: 240, row: row)
            rowText("\(run.skillCount)", x: 800, width: 90, row: row)
            rowText(Self.time(run.seconds), x: 918, width: 132, row: row)
        }
        pageFooter()
        setAccessibilityLabel("\(level.title). \(board.title). Rewinds: \(assisted ? "used" : "unused"). W switches the rewind filter. \(entries.count) local records. Escape returns. A opens achievements. D opens run details.")
    }
    private func drawAwards() {
        if level?.conditions != nil { drawTrolleyAwards(); return }
        header("Achievements", subtitle: "All levels"); tabs()
        let earned = ArcadeStore.shared.records.careerAchievements(profileID: player.id)
        text("\(careerAwards.filter(earned.contains).count) / \(careerAwards.count) earned", 64, 216, 768)
        drawAwardEntries(careerAwards.map { ($0.title, $0.detail, earned.contains($0)) })
        pageFooter()
        setAccessibilityLabel("Achievements across all levels. " + careerAwards.map {
            "\(earned.contains($0) ? "Earned" : "Locked"): \($0.title). \($0.detail)"
        }.joined(separator: " "))
    }
    private func drawDetails() {
        if let conditions = level?.conditions { drawTrolleyDetails(conditions); return }
        header(level?.title ?? "Run details"); tabs()
        guard let level else { pageFooter(); return }
        let records = ArcadeStore.shared.records
        let run = report?.run ?? records.runs.last { $0.level.boardID == level.boardID && $0.profileID == player.id && $0.assisted == assisted }
        let stats = records.stats(level: level, profileID: player.id, assisted: assisted)
        let best = records.leaderboard(level: level, board: .rescue, assisted: assisted).first
        text("This run", 64, 221, 480, palette: .green)
        let rows: [(String, String)] = [("Rescued", run.map { String($0.saved) } ?? "-"),
                    ("Not rescued", run.map { String($0.population - $0.saved) } ?? "-"),
                    ("Skills used", run.map { String($0.skillCount) } ?? "-"),
                    ("Time", run.map { Self.time($0.seconds) } ?? "-")]
        for (index, row) in rows.enumerated() {
            let y = CGFloat(270 + index * 34)
            text(row.0, 64, y, 245, palette: .green)
            text(row.1, 344, y, 248)
        }
        text("This level", 654, 221, 402, palette: .green)
        let levelRows = [("Required", String(level.required)),
                         ("Best known", best.map { String($0.saved) } ?? "Unknown"),
                         ("Attempts", String(stats.attempts)), ("Clears", String(stats.clears))]
        for (index, row) in levelRows.enumerated() {
            let y = CGFloat(270 + index * 34)
            text(row.0, 654, y, 248, palette: .green)
            text(row.1, 910, y, 146, alignment: .right)
        }
        pageFooter()
    }
    private func changeLevel(_ direction: Int) {
        guard report == nil else { return }
        let levels = Dictionary(grouping: ArcadeStore.shared.records.runs.map(\.level), by: \.boardID).values.compactMap(\.first)
            .sorted { ($0.game, $0.title, $0.boardID) < ($1.game, $1.title, $1.boardID) }
        guard !levels.isEmpty else { return }
        let index = levels.firstIndex { $0.boardID == level?.boardID } ?? 0
        level = levels[(index + direction + levels.count) % levels.count]; needsDisplay = true
    }
    static func time(_ seconds: Double) -> String { String(format: "%d:%05.2f", Int(seconds) / 60, seconds.truncatingRemainder(dividingBy: 60)) }
    private func localPoint(_ event: NSEvent) -> CGPoint {
        let p = convert(event.locationInWindow, from: nil)
        return CGPoint(x: (p.x - offset.x) / scale, y: (p.y - offset.y) / scale)
    }
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        buttons.first { $0.1.contains(localPoint(event)) }?.2()
    }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self)
        addTrackingArea(area); tracking = area
    }
    override func mouseMoved(with event: NSEvent) {
        let next = buttons.first { $0.1.contains(localPoint(event)) }?.0
        if next != hover { hover = next; needsDisplay = true }
        if next != nil { NSCursor.pointingHand.set() } else { NSCursor.arrow.set() }
    }
    override func mouseExited(with event: NSEvent) { hover = nil; needsDisplay = true; NSCursor.arrow.set() }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 48, !buttons.isEmpty {
            let direction = event.modifierFlags.contains(.shift) ? -1 : 1
            keyboardButton = ((keyboardButton ?? (direction > 0 ? -1 : 0)) + direction + buttons.count) % buttons.count
            let item = buttons[keyboardButton!]
            scrollToVisible(CGRect(x: offset.x + item.1.minX * scale, y: offset.y + item.1.minY * scale, width: item.1.width * scale, height: item.1.height * scale))
            needsDisplay = true; return
        }
        if [36, 76, 49].contains(event.keyCode), !event.isARepeat, let keyboardButton, buttons.indices.contains(keyboardButton) {
            buttons[keyboardButton].2(); return
        }

        if event.keyCode == 53, affinityPopover?.isShown == true { affinityPopover?.close(); return }
        guard event.modifierFlags.intersection([.command, .control, .option]).isEmpty else { super.keyDown(with: event); return }
        if event.isARepeat && [36, 76, 49].contains(event.keyCode) { return }
        if event.keyCode == 53 { back(); return }
        let key = event.charactersIgnoringModifiers?.uppercased() ?? ""
        if mode == .hotSeat {
            if [36, 76].contains(event.keyCode) { closeSession(); return }
            if let number = Int(key), (1...ArcadeStore.shared.records.profiles.count).contains(number) {
                ArcadeStore.shared.toggleSessionProfile(ArcadeStore.shared.records.profiles[number - 1].id)
                needsDisplay = true
            }
            return
        }
        if mode == .profiles {
            if event.keyCode == 36 { saveProfile(); return }
            if event.keyCode == 123 || event.keyCode == 124 { portrait = (portrait + (event.keyCode == 123 ? 7 : 1)) % 8 }
            else if event.keyCode == 51 { if !initials.isEmpty { initials.removeLast() }; replaceInitials = false }
            else if !key.isEmpty, key.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) {
                if replaceInitials { initials = ""; replaceInitials = false }
                initials = String((initials + key).prefix(3))
            }
            needsDisplay = true; return
        }
        if mode == .awards, level?.conditions != nil {
            if let number = Int(key), (1...TrolleyAchievementGroup.allCases.count).contains(number) {
                awardGroup = TrolleyAchievementGroup.allCases[number - 1]; awardPage = 0; needsDisplay = true; return
            }
            if [125, 126].contains(event.keyCode) {
                let groups = TrolleyAchievementGroup.allCases, index = groups.firstIndex(of: awardGroup)!
                awardGroup = groups[(index + (event.keyCode == 126 ? groups.count - 1 : 1)) % groups.count]
                awardPage = 0; needsDisplay = true; return
            }
        }
        if mode == .awards && [123, 124].contains(event.keyCode) {
            awardPage = (awardPage + (event.keyCode == 123 ? awardPageCount - 1 : 1)) % awardPageCount
            needsDisplay = true; return
        }
        if mode == .career && [123, 124].contains(event.keyCode) {
            let count = max(1, ((celebration?.awards.filter { $0.after.goal > 1 }.count ?? 0) + 3) / 4)
            careerPage = (careerPage + (event.keyCode == 123 ? count - 1 : 1)) % count
            needsDisplay = true; return
        }
        if event.keyCode == 36 || event.keyCode == 76 || (event.keyCode == 49 && mode == .result) {
            if mode == .result { performDefaultResultAction() } else if report != nil { page(.result) }
            return
        }
        if let number = Int(key), (1...TrolleyBoard.allCases.count).contains(number), level?.conditions != nil {
            trolleyBoard = TrolleyBoard.allCases[number - 1]; needsDisplay = true; return
        }
        switch key {
        case "W": if mode == .records { assisted.toggle() }
        case "N": if mode == .result { retryAsNextProfile() }
        case "P": if mode == .result { openSession() }
        case "R": onRetry?()
        case "V": onReplay?(false)
        case "S": onReplay?(true)
        case "B": page(.records)
        case "A": if mode == .result { showNewAwards() } else { page(.awards) }
        case "D": page(.details)
        case "G": page(.goals)
        case "C": page(.career)
        case "1": board = .rescue
        case "2": board = .efficiency
        case "3": board = .allSaved
        default:
            if event.keyCode == 123 { changeLevel(-1) }
            if event.keyCode == 124 { changeLevel(1) }
        }
        needsDisplay = true
    }
}
