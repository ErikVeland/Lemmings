@MainActor private final class ExtraSkillTestWindow: NSWindow {
  var pointer = CGPoint.zero
  override var isKeyWindow: Bool { true }
  override var mouseLocationOutsideOfEventStream: NSPoint { pointer }
}

@MainActor private final class ExtraSkillBadgeFixture: NSView {
  override var isFlipped: Bool { true }
  var opacity: CGFloat = 1 { didSet { needsDisplay = true } }
  override func draw(_ dirtyRect: NSRect) {
    PrecisionZoomStatus(superzoom: 3, skips: 3, extraSkills: 1, bonusSkillUsed: true, active: .superzoom, isEmpty: false)
      .draw(at: .zero, scale: 2, opacity: opacity)
  }
  override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

@MainActor private func extraSkillShot(_ view: NSView, _ name: String) throws {
  let folder = URL(fileURLWithPath: ".build/extra-skill-renders")
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  view.layoutSubtreeIfNeeded()
  if view is ArcadeView {
    let image = ReplayFrameCapture.image(size: view.bounds.size) { ReplayFrameCapture.draw(view, in: view.bounds) }!
    try NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
      .write(to: folder.appendingPathComponent(name + ".png"))
    return
  }
  func invalidate(_ view: NSView) { view.needsDisplay = true; view.subviews.forEach(invalidate) }
  invalidate(view)
  let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
  view.displayIgnoringOpacity(view.bounds, in: NSGraphicsContext(bitmapImageRep: bitmap)!)
  try bitmap.representation(using: .png, properties: [:])!
    .write(to: folder.appendingPathComponent(name + ".png"))
}

@MainActor private func extraSkillButtons(_ view: NSView) -> [NSButton] {
  (view as? NSButton).map { [$0] } ?? view.subviews.flatMap(extraSkillButtons)
}

@MainActor private func extraSkillKey(_ key: String, code: UInt16, window: NSWindow,
  flags: NSEvent.ModifierFlags = [], repeated: Bool = false) -> NSEvent {
  NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 1,
    windowNumber: window.windowNumber, context: nil, characters: key,
    charactersIgnoringModifiers: key, isARepeat: repeated, keyCode: code)!
}

@MainActor private func testExtraSkillChooserAndKeyboard() throws {
  let host = ExtraSkillTestWindow(contentRect: CGRect(x: 0, y: 0, width: 900, height: 620),
    styleMask: [], backing: .buffered, defer: false)
  let root = NSView(frame: host.contentView!.bounds)
  host.contentView = root
  defer { GameScreen.shared.dismissAll() }
  var applied: [Int] = [], dismissed = 0
  let choices = [ExtraSkillMac.Choice(id: 0, title: "Builder"), .init(id: 1, title: "Digger"), .init(id: 2, title: "Miner")]
  for width in [640, 900, 1600] {
    host.setContentSize(CGSize(width: width, height: width == 900 ? 620 : 1000))
    guard let page = ExtraSkillMac.choose(choices, selected: 2, owner: host,
      onDismiss: { dismissed += 1 }, apply: { applied.append($0) }) else {
      throw IntegrationFailure(message: "Extra-skill chooser did not open")
    }
    host.contentView!.layoutSubtreeIfNeeded(); page.layoutSubtreeIfNeeded()
    let buttons = extraSkillButtons(page).filter {
      $0.title.hasPrefix("+1 ") || $0 === page.controllerBackButton || $0.title == "Use extra skill"
    }
    let rows = buttons.filter { $0.title.hasPrefix("+1 ") }
    try check(buttons.count == 5 && rows.count == 3 && rows.filter { $0.state == .on }.map(\.title) == ["+1 Miner"],
      "Extra-skill chooser lost its initial selection")
    try check(host.firstResponder === page.controllerBackButton, "Extra-skill chooser did not focus Back")
    for button in buttons {
      let frame = button.convert(button.bounds, to: page)
      let point = CGPoint(x: frame.midX, y: frame.midY)
      let hit = page.hitTest(point)
      try check(page.bounds.contains(frame) && frame.height > 20 && (hit === button || hit?.isDescendant(of: button) == true),
        "Extra-skill chooser clipped a visible input target")
      let role = button.accessibilityRole()
      let correctRole = button.title.hasPrefix("+1 ") ? role == .radioButton : role == .button
      try check(correctRole && !(button.accessibilityLabel() ?? button.title).isEmpty,
        "Extra-skill chooser action has no accessible name or role: \(button.title), \(role?.rawValue ?? "nil")")
      try check(button.frame.height >= 44, "Extra-skill chooser reduced its logical input height")
    }
    let first = rows.first { $0.title == "+1 Builder" }!
    let location = first.convert(CGPoint(x: first.bounds.midX, y: first.bounds.midY), to: nil)
    let down = NSEvent.mouseEvent(with: .leftMouseDown, location: location, modifierFlags: [], timestamp: 1,
      windowNumber: host.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
    let up = NSEvent.mouseEvent(with: .leftMouseUp, location: location, modifierFlags: [], timestamp: 1.1,
      windowNumber: host.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 0)!
    NSApp.postEvent(up, atStart: true); host.sendEvent(down)
    if let release = NSApp.nextEvent(matching: .leftMouseUp, until: .distantPast, inMode: .default, dequeue: true) {
      NSApp.sendEvent(release)
    }
    if first.state != .on {
      print("SKIP native NSWindow mouse delivery in offscreen mode; verify the target's action directly")
      first.performClick(nil)
    }
    let stateDetails = rows.map { "\($0.title):\($0.state.rawValue)" }.joined(separator: ", ")
    try check(first.state == .on && (first.accessibilityValue() as? Int) == 1
      && rows.filter { $0.state == .on }.count == 1 && applied.isEmpty,
      "Extra-skill selection lost its state or charged before confirmation: \(stateDetails); applied \(applied.count)")
    let second = rows.first { $0.title == "+1 Digger" }!
    host.makeFirstResponder(second)
    try check(GameScreen.shared.handleDialogKey(extraSkillKey(" ", code: 49, window: host)) && second.state == .on,
      "Keyboard selection did not select an extra skill")
    try check((second.accessibilityValue() as? Int) == 1 && rows.filter { $0.state == .on }.count == 1,
      "Extra-skill selection state disagreed with accessibility")
    try extraSkillShot(host.contentView!, "chooser-\(width)")
    try check(GameScreen.shared.handleDialogKey(extraSkillKey("\u{1b}", code: 53, window: host))
      && !GameScreen.shared.isPresented && applied.isEmpty,
      "Cancelling an extra-skill chooser spent a reward")
  }
  try check(dismissed == 3, "Extra-skill cancellation lost its resume callback")
  let confirmed = ExtraSkillMac.choose(choices, selected: 1, owner: host, apply: { applied.append($0) })!
  let use = extraSkillButtons(confirmed).first { $0.title == "Use extra skill" }!
  try check(use.accessibilityPerformPress() && applied == [1] && !GameScreen.shared.isPresented,
    "Extra-skill confirmation did not apply exactly the selected reward")

  let keyboard = GameplayKeyboard(window: host)
  keyboard.active = { true }; keyboard.modern = { true }; keyboard.ownsController = { true }
  keyboard.mainMenu = {}; keyboard.settings = {}; keyboard.nextGraphics = {}
  keyboard.inspectionAvailable = { true }; keyboard.inspectLemmings = {}
  keyboard.fadeMenuButton = { true }; keyboard.navigationReduceMotion = { false }
  var uses = 0
  keyboard.extraSkill = { uses += 1 }; keyboard.extraSkillAvailable = { true }
  let badge = ExtraSkillBadgeFixture(frame: CGRect(x: 16, y: 16, width: 290, height: 100))
  if badge.superview !== root { badge.removeFromSuperview(); root.addSubview(badge) }
  keyboard.rewardDisplayArea = { badge.frame }
  keyboard.navigationArtworkOpacityChanged = { badge.opacity = $0 }
  for width in [640, 900, 1600] {
    host.setContentSize(CGSize(width: width, height: width == 900 ? 620 : 1000))
    host.pointer = CGPoint(x: root.bounds.midX, y: root.bounds.midY)
    host.makeFirstResponder(nil)
    keyboard.removeNavigationControl()
    keyboard.refreshNavigationControl(at: 100); keyboard.refreshNavigationControl(at: 104)
    let buttons = root.subviews.compactMap { $0 as? GameplayMenuButton }.filter { !$0.isHidden }
    let inspect = buttons.first { $0.title == "Inspect" }!
    let extra = buttons.first { $0.title == "Extra skill" }!
    try check(inspect.artworkOpacity == 1 && badge.opacity == 0,
      "Paused Inspect pinned reward badges on screen")
    try check(root.bounds.contains(extra.frame) && extra.frame.height >= 44 && extra.artworkOpacity == 0,
      "Extra-skill action did not fit or fade with the menu")
    try extraSkillShot(root, "faded-\(width)")
    host.pointer = CGPoint(x: badge.frame.midX, y: badge.frame.midY)
    keyboard.refreshNavigationControl(at: 105)
    try check(badge.opacity == 1, "Hovering a faded reward badge did not reveal it")
    try extraSkillShot(root, "badge-hover-\(width)")
    host.pointer = CGPoint(x: root.bounds.midX, y: root.bounds.midY)
    keyboard.refreshNavigationControl(at: 109)
    try check(badge.opacity == 0, "Reward badges did not fade after hover")
    let hover = NSEvent.enterExitEvent(with: .mouseEntered, location: .zero, modifierFlags: [], timestamp: 109,
      windowNumber: host.windowNumber, context: nil, eventNumber: 0, trackingNumber: 0, userData: nil)!
    extra.mouseEntered(with: hover); keyboard.refreshNavigationControl(at: 109)
    try check(extra.artworkOpacity == 1 && badge.opacity == 1, "Extra-skill hover did not reveal the reward balances")
    try check(root.hitTest(CGPoint(x: extra.frame.midX, y: extra.frame.midY)) === extra,
      "Faded extra-skill button lost its input target")
    let before = uses
    try check(extra.accessibilityPerformPress() && uses == before + 1 && badge.opacity == 1,
      "Extra-skill accessible action did not reveal its used reward")
    keyboard.removeNavigationControl()
  }
  let before = uses
  try check(keyboard.handle(extraSkillKey("e", code: 14, window: host, flags: .command)) == nil && uses == before + 1,
    "Command-E did not use an extra skill")
  _ = keyboard.handle(extraSkillKey("e", code: 14, window: host, flags: .command, repeated: true))
  try check(uses == before + 1 && badge.opacity == 1, "Command-E repeated or failed to reveal rewards")
  keyboard.extraSkillAvailable = { false }
  _ = keyboard.handle(extraSkillKey("e", code: 14, window: host, flags: .command))
  try check(uses == before + 1, "An unavailable extra skill was used")
  host.makeFirstResponder(nil)
  keyboard.revealRewards(at: 200); keyboard.refreshNavigationControl(at: 200); keyboard.refreshNavigationControl(at: 204)
  try check(badge.opacity == 0, "Used rewards did not resume fading")
  keyboard.removeNavigationControl()
  print("PASS extra-skill chooser selection, cancel/confirm, accessible targets and keyboard; paused Inspect, badge/button hover, use and fading at three sizes")
}

@MainActor private func testExtraSkillNativeReceipts() throws {
  let previous = ArcadeStore.shared
  let host = SpeedTestWindow(contentRect: CGRect(x: 0, y: 0, width: 900, height: 620),
    styleMask: [], backing: .buffered, defer: false)
  defer { GameScreen.shared.dismissAll(); ArcadeStore.shared = previous }
  for engine in ["lemmings", "lemmings2", "lemmings3"] {
    let storage = try AppStorage.temporary(named: "extra-skill-native")
    defer { storage.removeTemporaryFiles() }
    let store = ArcadeStore(storage: storage, bundledProofs: nil)
    ArcadeStore.shared = store
    let owner = store.records.activeProfileID
    func level(_ number: Int) -> ArcadeLevel {
      let conditions = TrolleyConditions(gameID: engine, packID: "extra-skill-native", levelID: String(number),
        levelFingerprint: "fixture", rulesetVersion: "fixture", physicsMode: "fixture", population: 1,
        rescueRequirement: 1, startingSkills: engine == "lemmings3" ? [:] : ["digger": 1], timeLimitSeconds: 60)
      return .init(id: String(number), title: "Rare reward fixture", game: engine, rules: "fixture", total: 1, required: 1, conditions: conditions)
    }
    var report: ArcadeReport!
    for index in 0..<10 {
      report = store.record(.init(profileID: owner, level: level(index), saved: 1, didWin: true,
        skills: [:], seconds: 10, telemetry: .init(released: 1)))
      try check(report != nil && report.earnedExtraSkill == (index == 9), engine + " rare reward milestone was wrong")
    }
    let rare = "RARE: +1 EXTRA SKILL"
    let receipts = ResultAwards.earnedRewards(report: report, celebration: .init(report: report, history: store.records.trolley))
    try check(receipts.contains { $0.isConsumable && $0.title == rare } && store.records.extraSkills(profileID: owner).available == 1,
      engine + " rare receipt or saved balance was missing")
    ArcadeWindow.shared.showResult(report, owner: host, retry: {}, next: {}, replay: { _ in })
    let result = ArcadeWindow.shared.arcadeView
    result.finishCelebration()
    try check(result.savedEarnedRewards.contains { $0.title == rare } && result.earnedPerks.contains { $0.kind == .extraSkill },
      engine + " native result hid its extra-skill reward")
    for width in [640, 900, 1600] {
      host.setContentSize(CGSize(width: width, height: width == 900 ? 620 : 1000))
      host.contentView!.layoutSubtreeIfNeeded()
      try extraSkillShot(result, engine + "-rare-\(width)")
      try checkCompactResultActions(result)
      let accessible = (result.accessibilityChildren() ?? []).compactMap { $0 as? GameAccessibleElement }
      try check(accessible.contains { $0.accessibilityLabel()?.contains(rare) == true }, engine + " rare receipt lacked accessible text")
    }
    GameScreen.shared.dismissAll()
    let id = UUID(), original = level(99), skill = engine == "lemmings3" ? "spade" : "digger"
    let palette: Set<String> = engine == "lemmings3" ? ["spade"] : []
    try check(store.spendExtraSkill(attemptID: id, profileID: owner, skill: skill,
      conditions: original.conditions!, existingLevelSkills: palette), engine + " could not spend its earned reward")
    let conditions = store.records.extraSkillUse(attemptID: id, profileID: owner)!.conditions!
    let bonus = ArcadeLevel(id: original.id, title: original.title, game: original.game, rules: original.rules,
      total: original.total, required: original.required, conditions: conditions)
    guard let used = store.record(.init(id: id, profileID: owner, level: bonus, saved: 1, didWin: true,
      skills: [:], seconds: 10, telemetry: .init(released: 1))) else { throw IntegrationFailure(message: "Bonus result was rejected") }
    let usedRewards = ResultAwards.earnedRewards(report: used, celebration: .init(report: used, history: store.records.trolley))
    try check(used.run.usedBonusSkill && !used.maximumIsProven && !usedRewards.contains(where: \.isConsumable),
      engine + " bonus clear earned a replacement reward or proven maximum")
    ArcadeWindow.shared.showResult(used, owner: host, retry: {}, next: {}, replay: { _ in })
    result.finishCelebration()
    try extraSkillShot(result, engine + "-bonus-used")
    let labels = (result.accessibilityChildren() ?? []).compactMap { ($0 as? GameAccessibleElement)?.accessibilityLabel() }
    try check(labels.contains { $0.contains("Bonus skill used") }, engine + " result hid the bonus-skill marker")
    GameScreen.shared.dismissAll()
  }
  print("PASS Classic/L2/L3 saved rare rewards, receipt labels, result renders, spend limits and bonus-result marker")
}

extension AppDelegate {
  fileprivate func testNativeExtraSkillGrants() throws {
    if window == nil { buildInterface() }
    GameScreen.shared.dismissAll()
    let storage = try AppStorage.temporary(named: "native-extra-skill-grants")
    let previous = ArcadeStore.shared, oldSettings = settings
    let store = ArcadeStore(storage: storage, bundledProofs: nil)
    ArcadeStore.shared = store
    defer {
      GameScreen.shared.dismissAll(); returnToLibrary(); apply(oldSettings)
      ArcadeStore.shared = previous; storage.removeTemporaryFiles()
    }
    func earnReward(_ offset: Int) throws {
      for index in offset..<(offset + 10) {
        let conditions = TrolleyConditions(gameID: "lemmings", packID: "native-extra-skill-wallet", levelID: String(index),
          levelFingerprint: "fixture", rulesetVersion: "fixture", physicsMode: "fixture", population: 1,
          rescueRequirement: 1, startingSkills: [:], timeLimitSeconds: 60)
        let level = ArcadeLevel(id: String(index), title: "Wallet fixture", game: "Classic", rules: "fixture",
          total: 1, required: 1, conditions: conditions)
        try check(store.record(.init(profileID: store.records.activeProfileID, level: level, saved: 1, didWin: true,
          skills: [:], seconds: 10, telemetry: .init(released: 1))) != nil, "Native reward wallet did not save")
      }
      try check(store.records.extraSkills(profileID: store.records.activeProfileID).available == 1,
        "Native reward wallet did not receive exactly one use")
    }
    try earnReward(0)
    loadContent(); settings.applyExperiencePreset(modern: true); settings.music = .silent; settings.sound = .silent
    guard let source = dataSets.firstIndex(where: { $0.set.title == .lemmings }) else {
      throw IntegrationFailure(message: "Missing Classic bonus test content")
    }
    gamePicker.selectItem(at: source); selectDataSet(); loadLevel(at: 0)
    flow?.selectLevel(rank: 0, position: 0); flow?.beginPlaying(); phase = .playing; isPaused = true
    renderScreen(); installKeyboardShortcuts(); syncPrecisionZoom()
    guard let classic = session as? ClassicSession,
          let slot = classic.skills.indices.first(where: { classic.canGrantExtraSkill(at: $0) }) else {
      throw IntegrationFailure(message: "Classic fixture has no existing finite skill")
    }
    panel.selectedSkillIndex = slot
    for _ in 0..<8 { classic.tick() }
    let before = classic.skills[slot].count, attemptID = arcadeRunID
    useExtraSkill()
    guard let chooser = GameScreen.shared.controllerPage(in: window) as? GameMenuPage,
          let use = extraSkillButtons(chooser).first(where: { $0.title == "Use extra skill" }) else {
      throw IntegrationFailure(message: "Classic extra-skill command did not open its chooser")
    }
    try extraSkillShot(window.contentView!, "classic-live-chooser")
    try check(use.accessibilityPerformPress(), "Classic extra-skill confirmation was not accessible")
    try check(classic.skills[slot].count == before + 1 && classic.simulation.bonusSkillUsed
      && store.records.extraSkills(profileID: arcadeProfileID).available == 0 && !extraSkillAvailable,
      "Classic confirmation did not add exactly one use and debit the wallet")
    try check(arcadeLevel?.conditions?.bonusSkillID != nil && playfield.precisionStatus.bonusSkillUsed,
      "Classic confirmation did not mark its result conditions and badge")
    try extraSkillShot(window.contentView!, "classic-live-bonus")
    useExtraSkill()
    try check(!GameScreen.shared.isPresented && classic.skills[slot].count == before + 1,
      "Classic permitted a second bonus skill in one attempt")
    saveRunCheckpoint(immediately: true)
    guard let checkpoint = try recoveryStore.latest(profileID: arcadeProfileID), checkpoint.runID == attemptID else {
      throw IntegrationFailure(message: "Classic bonus checkpoint was missing")
    }
    try check(checkpoint.extraSkillUse == store.records.extraSkillUse(attemptID: attemptID, profileID: arcadeProfileID)
      && checkpoint.events.contains(where: { if case .bonusSkill = $0.action { return true }; return false }),
      "Classic checkpoint omitted its immutable charge or input event")
    let restored = ClassicSession(simulation: classic.initialSimulation, width: classic.levelWidth, height: classic.levelHeight)
    try restored.restore(checkpoint)
    try check(restored.simulation.bonusSkillUsed && restored.skills[slot].count == before + 1,
      "Classic checkpoint did not restore the granted use")
    _ = classic.rewind(seconds: 1)
    syncPrecisionZoom()
    try check(arcadeLevel?.conditions?.bonusSkillID != nil && !classic.canGrantExtraSkill(at: slot),
      "Classic rewind before the grant cleared its attempt limit or record marker")
    retry()
    try check(arcadeRunID != attemptID && (session as? ClassicSession)?.simulation.bonusSkillUsed == false
      && session?.skills[slot].count == before && store.records.extraSkills(profileID: arcadeProfileID).available == 0,
      "Classic retry retained the bonus or returned its spent reward")
    try? recoveryStore.clear(attemptID)
    returnToLibrary()
    try earnReward(10)
    let second = try Lemmings2PlayWindow(root: BundledGameResources.lemmings2(), recordsCampaignProgress: false)
    defer { second.stop(); second.close() }
    try second.testExtraSkillGrant()
    GameScreen.shared.dismissAll()
    try earnReward(20)
    let third = try Lemmings3PlayWindow(root: BundledGameResources.lemmings3(), recordsCampaignProgress: false)
    defer { third.stop(); third.close() }
    try third.testExtraSkillGrant()
    print("PASS actual Classic/L2/L3 chooser grants, once-per-attempt limits, checkpoint/replay provenance, rewind and retry")
  }
}
