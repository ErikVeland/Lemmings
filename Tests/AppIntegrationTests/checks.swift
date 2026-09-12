// Appended to main.swift by the runner to exercise private app wiring directly.
private struct IntegrationFailure: Error { let message: String }
private func check(_ value: @autoclosure () throws -> Bool, _ message: String) throws {
  if try value() == false { throw IntegrationFailure(message: message) }
}

@MainActor private final class SpeedTestWindow: NSWindow {
  override var isKeyWindow: Bool { true }
}

extension AppDelegate {
  fileprivate func testAccessibleMenusAndHelp() async throws {
    let host = SpeedTestWindow(contentRect: CGRect(x: 0, y: 0, width: 640, height: 400), styleMask: [], backing: .buffered, defer: false)
    host.contentView = NSView(frame: CGRect(x: 0, y: 0, width: 640, height: 400))
    let keys = GameplayKeyboard(window: host)
    keys.speedControl = GameSpeedControl()
    keys.modern = { false }; keys.controllerEnabled = { false }
    try check(!keys.helpText.contains("Tab / Shift-Tab") && !keys.helpText.contains("RT") && !keys.helpText.contains("level hints"), "Help advertised disabled controls")
    keys.modern = { true }; keys.controllerEnabled = { true }; keys.hints = {}
    try check(keys.helpText.contains("Tab / Shift-Tab") && keys.helpText.contains("level hints"), "Help omitted enabled controls")
    keys.speedControl?.variableEnabled = false; keys.controllerTapSpeed = { false }
    try check(!keys.helpText.contains("ramp up") && !keys.helpText.contains("Tap: toggle"), "Help advertised disabled speed modes")
    let savedSize = GameAccessibility.interfaceSize
    defer { GameAccessibility.interfaceSize = savedSize; GameScreen.shared.dismissAll() }
    for size in ClassicInterfaceSize.allCases {
      GameAccessibility.interfaceSize = size
      let page = GameMenuPage(title: "Accessible settings")
      GameScreen.shared.present(page, owner: host)
      host.contentView?.layoutSubtreeIfNeeded()
      guard let scroll = page.enclosingScrollView else { throw IntegrationFailure(message: "Page cannot scroll at larger sizes") }
      try check(abs(page.frame.width - GamePageLayout.documentSize(in: scroll.contentSize).width) < 1, "Menu size was not applied")
      GameScreen.shared.dismiss(page)
    }
    for size in ClassicInterfaceSize.allCases {
      GameAccessibility.interfaceSize = size
      let page = GameMenuPage(title: "Settings")
      page.frame = CGRect(x: 0, y: 0, width: 2390, height: 1436)
      page.layoutSubtreeIfNeeded()
      let body = page.convert(page.body.bounds, from: page.body)
      try check(abs(body.width - 992 * size.scale) < 1,
        "A large window magnified the requested UI size")
      try check(GamePageLayout.documentSize(in: page.bounds.size) == page.bounds.size,
        "A large window added unnecessary scrolling")
      let bitmap = page.bitmapImageRepForCachingDisplay(in: page.bounds)!
      page.cacheDisplay(in: page.bounds, to: bitmap)
      let folder = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".build/ui-scale-shots")
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      try bitmap.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent("menu-\(Int(size.scale * 100)).png"))
    }
    let arcade = ArcadeView(frame: host.contentView!.bounds)
    arcade.mode = .profiles
    arcade.selectProfile(ArcadeStore.shared.records.activeProfile)
    GameScreen.shared.present(arcade, owner: host)
    host.contentView?.layoutSubtreeIfNeeded()
    let bitmap = arcade.bitmapImageRepForCachingDisplay(in: arcade.bounds)!
    arcade.cacheDisplay(in: arcade.bounds, to: bitmap)
    let output = URL(fileURLWithPath: ".build/qol-parity/profiles-large.png")
    try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
    try bitmap.representation(using: .png, properties: [:])!.write(to: output)
    let elements = arcade.accessibilityChildren()?.compactMap { $0 as? GameAccessibleElement } ?? []
    guard let initials = elements.first(where: { $0.accessibilityRole() == .textField }) else {
      throw IntegrationFailure(message: "Profiles has no accessible initials field")
    }
    initials.setAccessibilityValue("ab12")
    try check(initials.accessibilityValue() as? String == "AB1", "Accessible initials editing failed")
    try check(elements.contains(where: { $0.accessibilityRole() == .button && $0.accessibilityFrame().width > 0 }), "Profiles has no accessible buttons")
    GameScreen.shared.dismiss(arcade)
    let owner = NSView(frame: CGRect(x: 0, y: 0, width: 640, height: 400))
    host.contentView?.addSubview(owner)
    var presses = 0
    let button = GameAccessibleElement(owner: owner, label: "Retry", frame: CGRect(x: 10, y: 10, width: 80, height: 30), press: { presses += 1 })
    try check(button.accessibilityPerformPress() && presses == 1 && button.accessibilityFrame().width == 80, "Accessible action or screen frame failed")
    let backgroundPress = await Task.detached { button.accessibilityPerformPress() }.value
    try check(backgroundPress && presses == 2, "Background accessibility action failed")
    var editedValue = "Before"
    button.readValue = { editedValue }
    button.writeValue = { editedValue = $0 }
    let backgroundValue = await Task.detached {
      button.setAccessibilityValue("After")
      button.setAccessibilityFocused(true)
      return button.accessibilityValue() as? String
    }.value
    try check(backgroundValue == "After" && editedValue == "After", "Background accessibility value failed")
    owner.isHidden = true
    try check(!button.accessibilityPerformPress(), "Hidden accessibility control remained active")
    owner.isHidden = false; owner.removeFromSuperview()
    try check(!button.accessibilityPerformPress(), "Detached accessibility control remained active")
    let badge = TurnBadgeView()
    badge.show(initials: "ABC", portrait: nil)
    try check(!badge.isHidden && badge.accessibilityLabel() == "ABC's turn", "Turn badge did not identify player")
    badge.show(initials: nil, portrait: nil)
    try check(badge.isHidden, "Solo game retained turn badge")
    print("PASS context-aware help, scalable pages, accessible actions and turn badge")
  }
  fileprivate func testControllerQoL() async throws {
    GameScreen.shared.dismissAll()
    let host = SpeedTestWindow(contentRect: CGRect(x: 0, y: 0, width: 1000, height: 620), styleMask: [], backing: .buffered, defer: false)
    host.contentView = NSView(frame: CGRect(x: 0, y: 0, width: 1000, height: 620))
    host.makeKeyAndOrderFront(nil)
    defer { host.orderOut(nil) }
    let keyboard = GameplayKeyboard(window: host), speed = GameSpeedControl()
    keyboard.active = { true }; keyboard.speedControl = speed
    let driver = GameplayController(keyboard: keyboard, pollsAutomatically: false)
    var interruptions = 0
    keyboard.onInterruption = { interruptions += 1 }
    driver.disconnect()
    try check(interruptions == 0, "An unused controller paused keyboard play")
    var assigned = 0, escaped = 0, retried = 0, rewound = 0, steps: [Int] = []
    keyboard.assignSelected = { assigned += 1 }; keyboard.escape = { escaped += 1 }
    keyboard.retry = { retried += 1 }; keyboard.rewind = { rewound += 1 }; keyboard.step = { steps.append($0) }
    driver.processButtons([], at: 0, playing: true)
    for (index, rate) in [2.0, 1, 2, 1].enumerated() {
      let time = Double(index + 1)
      driver.processButtons([.rightTrigger], at: time, playing: true)
      driver.processButtons([], at: time + 0.05, playing: true)
      try check(speed.target == rate, "RT tap did not follow the F speed sequence")
    }
    driver.processButtons([.rightTrigger], at: 7, playing: true)
    for time in [7.3, 7.8, 8.3, 8.8, 9.1] { speed.update(at: time, active: true) }
    try check(speed.target == 10, "RT did not ramp to 10x")
    driver.processButtons([], at: 9.2, playing: true); speed.update(at: 9.5, active: true)
    try check(speed.multiplier == 1, "RT release did not ease back to cruising speed")
    driver.processButtons([.rightTrigger], at: 10, playing: true); driver.processButtons([], at: 10.05, playing: true)
    driver.processButtons([.rightTrigger], at: 10.2, playing: true)
    driver.processButtons([], at: 10.25, playing: true)
    try check(speed.multiplier == 1, "RT tap did not exit immediately on release")
    speed.variableEnabled = false; speed.setFast(true)
    driver.processButtons([.rightTrigger], at: 12, playing: true)
    driver.processButtons([.rightTrigger, .b], at: 12.5, playing: true)
    driver.processButtons([], at: 13, playing: true)
    try check(!speed.isFast && escaped == 0, "B's quick exit was undone on trigger release")
    driver.processButtons([.b], at: 14, playing: true); driver.processButtons([], at: 14.1, playing: true)
    try check(escaped == 1, "B at 1x did not open the pause menu")
    speed.setFast(false)
    driver.processButtons([.rightTrigger], at: 14.2, playing: true)
    driver.processButtons([.b], at: 14.6, playing: true)
    driver.processButtons([], at: 14.7, playing: true)
    try check(!speed.isFast && escaped == 1, "B opened a menu when cancelling a temporary legacy boost")
    speed.variableEnabled = true
    keyboard.controllerTapSpeed = { false }
    driver.processButtons([.rightTrigger], at: 15, playing: true); driver.processButtons([], at: 15.05, playing: true)
    try check(!speed.isFast, "The hold-only preference did not suppress taps")
    keyboard.controllerTapSpeed = { true }
    for (index, button) in [ControllerBindings.Button.menu, .b, .leftShoulder, .rightShoulder].enumerated() {
      driver.processButtons([.leftTrigger, button], at: 16 + Double(index), playing: true)
      driver.processButtons([], at: 16.1 + Double(index), playing: true)
    }
    try check(retried == 1 && rewound == 1 && steps == [-1, 1], "Controller retry/rewind/step routing failed")
    driver.processButtons([.rightTrigger], at: 21, playing: true)
    driver.disconnect()
    try check(interruptions == 1, "Disconnecting the active controller did not pause")
    try check(!speed.isFast, "Disconnect selected a speed instead of cancelling the boost")
    driver.processButtons([.a], at: 22, playing: true)
    try check(assigned == 0, "Reconnect replayed a held assign button")
    driver.processButtons([], at: 22.1, playing: true)
    driver.processButtons([.a], at: 22.2, playing: true)
    try check(assigned == 1, "Assignment did not return after button release")
    driver.processButtons([], at: 22.3, playing: true)

    let deck = LevelHintCatalogue.load()!.0.levels[30].deck
    keyboard.hints = { LevelHintWindow.shared.show(deck, owner: host) }
    driver.processButtons([.leftTrigger, .y], at: 24, playing: true)
    try check(LevelHintWindow.shared.page != nil && keyboard.controllerIsAvailable(applicationActive: true),
      "The hint page disabled its controller")
    driver.processButtons([.a, .leftTrigger], at: 24.1, playing: false)
    try check(LevelHintWindow.shared.revealedTier == 0, "A held button exposed a hint during the page transition")
    driver.processButtons([], at: 24.2, playing: false)
    driver.processButtons([.right], at: 24.3, playing: false)
    driver.processButtons([], at: 24.4, playing: false)
    driver.processButtons([.a], at: 24.5, playing: false)
    driver.processButtons([.a], at: 24.6, playing: false)
    try check(LevelHintWindow.shared.revealedTier == 1 && assigned == 1, "One controller press skipped hints or assigned behind them")
    driver.processButtons([], at: 24.7, playing: false)
    driver.processButtons([.leftTrigger, .b], at: 24.8, playing: false)
    try check(LevelHintWindow.shared.page == nil, "B did not close hints while LT was still held")

    keyboard.controllerAction(.help)
    try check(keyboard.controllerMenuRoot != nil && keyboard.controllerIsAvailable(applicationActive: true), "Controller help sheet became unreachable")
    try await Task.sleep(for: .milliseconds(500))
    keyboard.controllerMenuAction(.focusUnassigned(-1))
    let helpSelection = (keyboard.focusedControllerControl as? NSButton)?.title ?? "none"
    keyboard.controllerMenuAction(.assign)
    try await Task.sleep(for: .milliseconds(500))
    try check(LevelHintWindow.shared.page != nil, "Controller could not select the hints button in controls help; selected \(helpSelection), sheet remains \(host.attachedSheet != nil)")
    keyboard.controllerMenuAction(.cancel)

    let preferences = SettingsWindow(settings: ClassicSettings(), options: settingsOptions())
    keyboard.settings = { preferences.show() }
    keyboard.controllerAction(.settings)
    try check(keyboard.controllerMenuRoot != nil, "Controller settings command did not open Settings")
    keyboard.controllerMenuAction(.cycle(1))
    keyboard.controllerMenuAction(.rate(-1)); keyboard.controllerMenuAction(.rate(-1))
    keyboard.controllerMenuAction(.assign)
    try check(!preferences.current.controllerTapSpeed, "D-pad and A could not change the trigger setting")
    keyboard.controllerMenuAction(.rate(-1)); keyboard.controllerMenuAction(.assign)
    try check(preferences.current.controllerSwapSticks, "D-pad and A could not swap sticks")
    if let page = keyboard.controllerMenuRoot {
      page.layoutSubtreeIfNeeded()
      let bitmap = page.bitmapImageRepForCachingDisplay(in: page.bounds)!
      page.cacheDisplay(in: page.bounds, to: bitmap)
      let output = URL(fileURLWithPath: ".build/controller-qol/settings.png")
      try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
      try bitmap.representation(using: .png, properties: [:])!.write(to: output)
    }
    keyboard.controllerMenuAction(.cancel)
    try check(!GameScreen.shared.isPresented, "B did not close Settings")
    keyboard.controllerEnabled = { false }
    try check(!keyboard.controllerIsAvailable(applicationActive: true), "Disabled controller stayed active")
    keyboard.controllerEnabled = { true }; keyboard.ownsController = { false }
    try check(!keyboard.controllerIsAvailable(applicationActive: true), "An inactive engine claimed controller input")
    keyboard.ownsController = { true }
    try check(!keyboard.controllerIsAvailable(applicationActive: false), "Controller input leaked into another app")
    let navigation = ControllerMenuNavigator(), menu = NSView(frame: host.contentView!.bounds)
    let choices = NSPopUpButton(frame: CGRect(x: 10, y: 10, width: 200, height: 30))
    choices.autoenablesItems = false; choices.addItems(withTitles: ["First", "Unavailable", "Last"])
    choices.item(at: 1)?.isEnabled = false; menu.addSubview(choices)
    navigation.handle(.focusUnassigned(1), in: menu)
    try check(choices.indexOfSelectedItem == 2, "Controller navigation became stuck at an unavailable setting")
    navigation.handle(.focusUnassigned(-1), in: menu)
    try check(choices.indexOfSelectedItem == 0, "Controller navigation did not skip unavailable settings in reverse")
    print("PASS actual controller dispatch: RT tiers/hold/release, rapid and B exits, reconnect, hints, sheets, settings and ownership")
  }

  fileprivate func testHotSeatBoundaries() throws {
    GameScreen.shared.dismissAll()
    let previous = ArcadeStore.shared
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("seat-boundaries-\(UUID().uuidString)")
    let store = ArcadeStore(file: directory.appendingPathComponent("records.json"), bundledProofs: nil)
    ArcadeStore.shared = store
    defer { GameScreen.shared.dismissAll(); store.endHotSeat(); ArcadeStore.shared = previous }
    let host = store.records.activeProfileID
    let guest = store.addProfile(initials: "PAL", portrait: 2)!
    store.selectProfile(host); store.toggleSessionProfile(guest.id)
    loadContent()
    gamePicker.selectItem(at: dataSets.firstIndex(where: { $0.set.title == .lemmings })!)
    selectDataSet(); loadLevel(at: 30); phase = .playing
    installKeyboardShortcuts()
    _ = store.passSessionTurn(after: host)
    refreshTurnDisplay()
    try check(arcadeProfileID == host && playfield.turnInitials == store.records.profile(host)?.initials,
      "Classic badge displayed the queued player instead of the attempt owner")
    let sharedID = store.hotSeatID
    let runID = arcadeRunID
    let tick = session!.currentTick
    let view = ArcadeWindow.shared.arcadeView
    for screen: GamePhase in [.playing, .briefing, .results] {
      phase = screen
      view.mode = .details
      view.openSession()
      guard let confirmation = GameScreen.shared.controllerPage(in: window) as? GameMenuPage else {
        throw IntegrationFailure(message: "Info Players link skipped Hot Seat confirmation")
      }
      confirmation.onBack?()
      try check(store.hotSeatID == sharedID && arcadeRunID == runID && session?.currentTick == tick && phase == screen,
        "Cancelling player setup changed the shared run")
    }
    showProfiles()
    try check(!view.canSwitch && store.hotSeatID == sharedID && arcadeRunID == runID,
      "Profile selection could switch an active Hot Seat to solo")
    view.openSession()
    guard let profileConfirmation = GameScreen.shared.controllerPage(in: window) as? GameMenuPage else {
      throw IntegrationFailure(message: "Profiles Hot Seat action bypassed confirmation")
    }
    profileConfirmation.onBack?()
    try check(store.hotSeatID == sharedID && arcadeRunID == runID, "Profiles Hot Seat action changed the run on cancel")
    GameScreen.shared.dismissAll()
    phase = .playing
    showHotSeat()
    try check(store.hotSeatIsActive && GameScreen.shared.controllerPage(in: window) is GameMenuPage,
      "Changing players skipped the safe exit confirmation")
    func buttons(_ view: NSView) -> [NSButton] { (view as? NSButton).map { [$0] } ?? view.subviews.flatMap(buttons) }
    guard let confirm = GameScreen.shared.controllerPage(in: window),
      let leave = buttons(confirm).first(where: { $0.title == "Save and return to library" }) else {
      throw IntegrationFailure(message: "Safe Hot Seat exit has no action")
    }
    leave.performClick(nil)
    try check(view.mode == .hotSeat && view.report == nil && view.onRetry == nil, "Player setup retained an old result action")
    let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
    view.cacheDisplay(in: view.bounds, to: bitmap)
    let solo = view.accessibilityChildren()?.compactMap { $0 as? GameAccessibleElement }.first { $0.accessibilityLabel() == "Return to solo" }
    try check(solo?.accessibilityPerformPress() == true && store.hotSeatIsActive,
      "Return to solo ended Hot Seat before confirmation")
    (GameScreen.shared.controllerPage(in: window) as? GameMenuPage)?.onBack?()
    view.changeSessionPlayer(guest.id)
    try check(store.hotSeatID == sharedID, "Removing the second player ended Hot Seat before confirmation")
    guard let soloPage = GameScreen.shared.controllerPage(in: window),
      let leaveSolo = buttons(soloPage).first(where: { $0.title == "Return to solo" }) else {
      throw IntegrationFailure(message: "Leaving Hot Seat has no confirmation action")
    }
    leaveSolo.performClick(nil)
    try check(!store.hotSeatIsActive && !GameScreen.shared.isPresented,
      "Confirmed return to solo failed to leave shared play safely")
    print("PASS frozen Classic turn identity, confirmed player changes, cleared result actions and solo transition")
  }

  fileprivate func testHandoverPreviousLevel() throws {
    GameScreen.shared.dismissAll()
    let previousStore = ArcadeStore.shared
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("handover-retry-\(UUID().uuidString)")
    let store = ArcadeStore(file: directory.appendingPathComponent("records.json"), bundledProofs: nil)
    ArcadeStore.shared = store
    defer { handoverRetry = nil; store.endHotSeat(); ArcadeStore.shared = previousStore }
    let host = store.records.activeProfileID
    let guest = store.addProfile(initials: "UVA", portrait: 2)!
    store.selectProfile(host); store.toggleSessionProfile(guest.id)
    loadContent()
    gamePicker.selectItem(at: dataSets.firstIndex(where: { $0.set.title == .lemmings })!)
    selectDataSet()
    settings.display = .flat
    picker.selectItem(at: 2); levelChanged(); advancePhase()
    var completed = flow!
    completed.finishLevel(saved: 10, required: 1, total: 10)
    flow = completed; phase = .results
    _ = store.passSessionTurn(after: host)
    advancePhase()
    try check(flow?.currentLevelIndex == 3 && phase == .briefing && arcadeProfileID == guest.id,
      "Handover did not prepare the next level for UVA")
    try check(playfield.overlayTurnInitials == "UVA" && playfield.overlayHandoverRetryTitle == "Retry last level as UVA",
      "Handover omitted the highlighted player or previous-level retry")
    window.contentView?.layoutSubtreeIfNeeded()
    let bitmap = playfield.bitmapImageRepForCachingDisplay(in: playfield.bounds)!
    playfield.cacheDisplay(in: playfield.bounds, to: bitmap)
    let folder = URL(fileURLWithPath: ".build/handover-retry")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    try bitmap.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent("handover.png"))
    let controls = playfield.accessibilityChildren()?.compactMap { $0 as? GameAccessibleElement } ?? []
    guard let retry = controls.first(where: { $0.accessibilityLabel() == "Retry last level as UVA" }),
      let begin = controls.first(where: { $0.accessibilityLabel() == "Begin level" }) else {
      throw IntegrationFailure(message: "Handover actions have no accessible targets")
    }
    try check(retry.accessibilityFrame().maxX <= begin.accessibilityFrame().minX, "Begin level is not the rightmost action")
    let rect = retry.accessibilityFrame()
    let point = playfield.convert(window.convertPoint(fromScreen: CGPoint(x: rect.midX, y: rect.midY)), from: nil)
    playfield.handleClick(at: point)
    try check(flow?.currentLevelIndex == 2 && phase == .playing && session?.currentTick == 0 && arcadeProfileID == guest.id,
      "Retry last level did not start the previous level as UVA")
    try check(isPaused && panel.isPaused, "Classic incoming-player retry did not wait for the player")
    let sameOwner = arcadeProfileID
    self.retry()
    try check(isPaused && session?.currentTick == 0 && arcadeProfileID == sameOwner,
      "Classic same-player Hot Seat retry started running or changed owner")
    try check(flow?.passedCount(inRank: "Fun") == completed.passedCount(inRank: "Fun"), "Retry erased shared completion")
    completed = flow!; completed.finishLevel(saved: 10, required: 1, total: 10)
    flow = completed; phase = .results; advancePhase()
    advancePhase()
    try check(flow?.currentLevelIndex == 3 && phase == .playing && handoverRetry == nil,
      "Beginning the next level retained the old handover retry")
    completed = flow!; completed.finishLevel(saved: 0, required: 1, total: 10)
    flow = completed; phase = .results; advancePhase()
    try check(flow?.currentLevelIndex == 3 && playfield.overlayHandoverRetryTitle == nil,
      "A failed level offered two identical retry actions")
    advancePhase()
    completed = flow!; completed.finishLevel(saved: 10, required: 1, total: 10)
    flow = completed; phase = .results; advancePhase()
    let next = flow?.currentLevelIndex
    store.endHotSeat(); retryPreviousHandoverLevel()
    try check(flow?.currentLevelIndex == next && phase == .briefing, "A stale shared retry crossed into solo play")
    print("PASS green handover identity, mouse retry of the previous level as UVA, rightmost begin action, shared progress and solo boundaries")
  }

  fileprivate func testInterruptionPolicy() throws {
    if gameplayKeyboard == nil { installKeyboardShortcuts() }
    GameScreen.shared.dismissAll()
    loadContent()
    gamePicker.selectItem(at: dataSets.firstIndex(where: { $0.set.title == .lemmings })!)
    selectDataSet(); loadLevel(at: 30); phase = .playing; isPaused = false
    settings.pauseOnInterruption = true
    guard let keyboard = gameplayKeyboard, let current = session else { throw IntegrationFailure(message: "No interruption test game") }
    speedControl.setFast(true)
    let tick = current.currentTick
    NotificationCenter.default.post(name: NSWindow.didResignKeyNotification, object: window)
    step(at: 1); step(at: 2)
    try check(isPaused && !speedControl.isFast && current.currentTick == tick, "Focus loss did not pause Classic at 1x")
    NotificationCenter.default.post(name: NSWindow.didBecomeKeyNotification, object: window)
    try check(isPaused, "Returning to the game resumed without player input")
    isPaused = false; showLevelHints()
    NotificationCenter.default.post(name: NSApplication.didResignActiveNotification, object: NSApp)
    GameScreen.shared.dismissAll()
    try check(isPaused, "Closing hints resumed after the app was interrupted")
    isPaused = false
    let resume = keyboard.pauseForHelp()
    keyboard.handleInterruption(); resume()
    try check(isPaused, "Closing controls help resumed after an interruption")
    settings.pauseOnInterruption = false; isPaused = false
    NotificationCenter.default.post(name: NSWindow.didResignKeyNotification, object: window)
    try check(!isPaused, "The automatic pause opt-out was ignored")
    settings.pauseOnInterruption = true
    print("PASS Classic focus loss, manual resume, interrupted hints/help and automatic pause opt-out")
  }

  #if PERFORMANCE_TESTS
  fileprivate func testReleasePerformance() async throws {
    GameScreen.shared.dismissAll()
    settings.music = .silent; settings.pauseOnInterruption = false
    loadContent()
    launchMode = .singleTitle; activeTitle = .lemmings
    gamePicker.selectItem(at: dataSets.firstIndex { $0.set.title == .lemmings }!)
    selectDataSet()
    window.setContentSize(NSSize(width: 1280, height: 720))
    window.makeKeyAndOrderFront(nil)
    var rows: [[String: Any]] = []
    func residentBytes() -> UInt64 {
      var info = mach_task_basic_info()
      var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<integer_t>.size)
      let result = withUnsafeMutablePointer(to: &info) { pointer in
        pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
          task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
        }
      }
      return result == KERN_SUCCESS ? info.resident_size : 0
    }
    for (mode, rate) in [(ClassicDisplayMode.flat, 1), (.flat, 10), (.monitor, 10), (.television, 10)] {
      settings.display = mode; settings.hdEffectsEnabled = true; settings.fullScreenHDRFlashes = true
      settings.reduceMotion = false; settings.reduceFlashes = false
      picker.selectItem(at: 29); levelChanged()
      if phase == .briefing { advancePhase() }
      isPaused = false; panel.isPaused = false; applyDisplayMode()
      session?.adjustRate(by: 99)
      speedControl.variableEnabled = true; speedControl.reset(at: ProcessInfo.processInfo.systemUptime)
      if rate == 10 { for _ in 0..<4 { speedControl.step(1, at: ProcessInfo.processInfo.systemUptime) } }
      lastStepTime = nil; accumulator = 0
      replayCaptureSeconds = 0; playfield.sceneRenderSeconds = 0
      var samples: [Double] = [], memories: [UInt64] = []
      var completedTicks = 0, previousTick = 0, nuked = false
      let began = ProcessInfo.processInfo.systemUptime
      while ProcessInfo.processInfo.systemUptime - began < 20 {
        let start = ProcessInfo.processInfo.systemUptime
        if !nuked && start - began > 12 { session?.nuke(); nuked = true }
        step(at: start)
        window.contentView?.displayIfNeeded()
        CATransaction.flush()
        let end = ProcessInfo.processInfo.systemUptime
        samples.append((end - start) * 1000)
        memories.append(residentBytes())
        let tick = session?.currentTick ?? 0
        completedTicks += max(0, tick - previousTick); previousTick = tick
        if session?.isComplete == true { break }
        let remaining = max(0.001, 1.0 / 60 - (end - start))
        try await Task.sleep(for: .seconds(remaining))
      }
      let elapsed = ProcessInfo.processInfo.systemUptime - began
      try check(completedTicks >= 100, "Benchmark did not run the simulation: ticks \(completedTicks), phase \(phase), paused \(isPaused)")
      let sorted = samples.sorted()
      func quantile(_ fraction: Double) -> Double { sorted[min(sorted.count - 1, Int(Double(sorted.count - 1) * fraction))] }
      rows.append(["sceneRenderSeconds": playfield.sceneRenderSeconds, "replayCaptureSeconds": replayCaptureSeconds, "encoderWaitSeconds": runMovie.recorder?.admissionWaitSeconds ?? 0, "display": mode.rawValue, "requestedSpeed": rate, "seconds": elapsed, "frames": samples.count,
        "ticks": completedTicks, "observedSimulationSpeed": Double(completedTicks) / (17 * elapsed),
        "frameMS": ["p50": quantile(0.5), "p95": quantile(0.95), "p99": quantile(0.99), "max": sorted.last!],
        "residentBytes": ["first": memories.first!, "last": memories.last!, "peak": memories.max()!],
        "nukeTriggered": nuked, "windowWidth": 1280, "windowHeight": 720])
      runMovie.discard()
    }
    let report: [String: Any] = ["scenarios": rows,
      "scope": "Local 1280x720 app loop, drawing, enabled replay recording and synchronous Metal completion. Audio is silent. Short samples are not a sustained hardware certification."]
    let output = URL(fileURLWithPath: ".build/blocker-closure/performance.json")
    try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
    try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: output)
    window.orderOut(nil)
    print("PASS local frame timing and resident-memory measurements: \(output.path)")
  }
  #endif

  fileprivate func testControllerRemapping() throws {
    GameScreen.shared.dismissAll()
    let host = SpeedTestWindow(contentRect: CGRect(x: 0, y: 0, width: 1000, height: 720), styleMask: [], backing: .buffered, defer: false)
    host.contentView = NSView(frame: CGRect(x: 0, y: 0, width: 1000, height: 720))
    let keyboard = GameplayKeyboard(window: host), speed = GameSpeedControl()
    keyboard.active = { true }; keyboard.speedControl = speed
    var mapping = ControllerBindings.swapping([:], physical: .a, role: .rightTrigger)
    keyboard.controllerMappings = { mapping }
    var assignments = 0
    keyboard.assignSelected = { assignments += 1 }
    let driver = GameplayController(keyboard: keyboard, pollsAutomatically: false)
    driver.processButtons([], at: 0, playing: true)
    driver.processButtons([.a], at: 1, playing: true)
    driver.processButtons([], at: 1.05, playing: true)
    try check(speed.target == 2 && assignments == 0, "Remapped speed button did not use tap/release semantics")
    driver.processButtons([.rightTrigger], at: 2, playing: true)
    try check(assignments == 1, "Remapped assignment did not fire")
    driver.processButtons([], at: 2.1, playing: true)
    driver.processButtons([.a], at: 3, playing: true)
    mapping = [:]
    driver.processButtons([.a], at: 3.2, playing: true)
    try check(assignments == 1, "Changing mappings replayed a held button")
    driver.processButtons([], at: 3.3, playing: true)
    mapping = ControllerBindings.swapping([:], physical: .a, role: .b)
    let page = GameMenuPage(title: "Menu test")
    page.onBack = { GameScreen.shared.dismiss(page) }
    GameScreen.shared.present(page, owner: host)
    driver.processButtons([], at: 4, playing: false)
    driver.processButtons([.b], at: 4.1, playing: false)
    try check(!GameScreen.shared.isPresented, "Gameplay remapping removed standard menu Back")
    let preferences = SettingsWindow(settings: ClassicSettings(), options: settingsOptions())
    GameScreen.shared.gameWindow = host
    preferences.show()
    func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
    descendants(host.contentView!).compactMap { $0 as? NSTabView }.first?.selectTabViewItem(at: 1)
    let views = descendants(host.contentView!)
    let remap = views.compactMap { $0 as? NSButton }.first { $0.title == "Remap buttons…" }!
    remap.performClick(nil)
    let controls = descendants(host.contentView!).compactMap { $0 as? NSPopUpButton }
    let source = controls.first { $0.accessibilityLabel() == "Controller button" }!
    let role = controls.first { $0.accessibilityLabel() == "Gameplay action" }!
    source.selectItem(at: ControllerBindings.Button.allCases.firstIndex(of: .a)!)
    _ = source.sendAction(source.action, to: source.target)
    role.selectItem(at: ControllerBindings.Button.allCases.firstIndex(of: .rightTrigger)!)
    _ = role.sendAction(role.action, to: role.target)
    try check(preferences.current.controllerMappings == ControllerBindings.swapping([:], physical: .a, role: .rightTrigger),
      "The remapping screen did not swap and save the chosen action")
    let persisted = try JSONDecoder().decode(ClassicSettings.self, from: JSONEncoder().encode(preferences.current))
    try check(persisted.controllerMappings == preferences.current.controllerMappings, "Remapping did not persist")
    let reset = descendants(host.contentView!).compactMap { $0 as? NSButton }.first { $0.title == "Reset button mappings" }!
    reset.performClick(nil)
    try check(preferences.current.controllerMappings.isEmpty, "Reset did not restore default buttons")
    GameScreen.shared.dismissAll(); host.orderOut(nil)
    print("PASS remapped speed/assignment, held-input reset, standard menu escape, settings swap/reset and persistence")
  }

  fileprivate func testNeoRunRecovery() throws {
    var terrain = try NeoLemmixTerrain(width: 512, height: 96)
    for x in 0..<512 { terrain.setSolid(true, x: x, y: 48) }
    let config = try NeoLemmixConfiguration(totalLemmings: 1, requiredToSave: 0,
      spawnInterval: 4, entrances: [], preplacedLemmings: [.init(position: .init(x: 20, y: 48))],
      skills: [.walker: .infinite, .builder: .finite(5)])
    let initial = try NeoLemmixSimulation(terrain: terrain, configuration: config)
    func fresh() -> NeoLemmixSession { NeoLemmixSession(simulation: initial, width: 512, height: 96) }
    let original = fresh()
    for _ in 0..<12 { original.tick() }
    try check(original.assign(skillIndex: 1, to: 0) == nil, "Neo fixture could not assign builder")
    for _ in 0..<12 { original.tick() }
    original.nuke(); original.tick(); original.undoNuke()
    original.adjustRate(by: 1)
    original.nuke()
    var checkpoint = RunRecovery(engine: "test", profileID: "player", runID: UUID(), dataSetID: "neolemmix",
      levelIndex: 0, levelFingerprint: "test", initialStateHash: "state", tick: original.currentTick,
      events: [], stateHash: "state", usedRewind: original.usedRewind, nukeCount: original.nukeCount,
      rewindCount: original.rewindCount, undoCount: original.undoCount, selectedSkill: 1, scrollX: 0, scrollY: 0)
    checkpoint.neo = original.recovery; checkpoint.sourcePath = "/test.nxlv"
    let restored = fresh()
    try restored.restore(JSONDecoder().decode(RunRecovery.self, from: JSONEncoder().encode(checkpoint)))
    try check(restored.simulation == original.simulation && restored.skillAssignments == original.skillAssignments,
      "Neo recovery changed the simulation or skill counts")
    try check(restored.canUndoNuke && restored.undoCount == 1 && restored.nukeCount == 2,
      "Neo recovery lost nuke undo or assistance counters")
    restored.undoNuke(); original.undoNuke()
    for _ in 0..<40 { restored.tick(); original.tick() }
    try check(restored.simulation == original.simulation, "Neo recovery diverged after nuke undo and queued rate")
    let saved = checkpoint.neo!
    checkpoint.neo = NeoRunRecovery(initialState: initial, state: saved.state, inputs: [])
    let rejected = fresh()
    do { try rejected.restore(checkpoint); throw IntegrationFailure(message: "Neo recovery accepted a missing journal") }
    catch RunRecoveryError.invalid {}
    try check(rejected.simulation == initial, "Rejected Neo recovery modified live state")
    GameScreen.shared.dismissAll()
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("NeoRecovery-\(UUID())")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let oldStyles = stylesDirectory
    defer { stylesDirectory = oldStyles }
    stylesDirectory = directory
    let file = directory.appendingPathComponent("recovery.nxlv")
    try """
    TITLE Recovery test
    WIDTH 200
    HEIGHT 200
    LEMMINGS 1
    SAVE_REQUIREMENT 1
    SPAWN_INTERVAL 20
    $SKILLSET
      FLOATER 1
    $END
    $LEMMING
      X 40
      Y 20
    $END
    """.write(to: file, atomically: true, encoding: .utf8)
    loadNxlv(file)
    guard let live = session as? NeoLemmixSession else { throw IntegrationFailure(message: "Neo file did not load") }
    try check(phase == .playing && !panel.isMenuMode, "Opening a Neo file left the game in its menu")
    for _ in 0..<4 { live.tick() }
    saveRunCheckpoint(immediately: true)
    guard let disk = try recoveryStore.latest(profileID: arcadeProfileID), disk.neo != nil else {
      throw IntegrationFailure(message: "Neo file run was not saved")
    }
    let starts = ArcadeStore.shared.records.trolley.starts.count
    restoreRun(disk)
    try check((session as? NeoLemmixSession)?.simulation == live.simulation && phase == .playing && isPaused,
      "Neo file restore lost its state or playing screen")
    try check(arcadeRunID == disk.runID && ArcadeStore.shared.records.trolley.starts.count == starts,
      "Neo file restore counted a new attempt")
    GameScreen.shared.dismissAll()
    try recoveryStore.clear(disk.runID)
    print("PASS Neo checkpoint round trip, assignment, queued rate/nuke, undo, counters, continuation and transactional rejection")
  }

  fileprivate func testFanRunRecovery() throws {
    GameScreen.shared.dismissAll()
    returnToLibrary()
    settings.music = .silent; loadContent()
    gamePicker.selectItem(at: dataSets.firstIndex { $0.set.title == .lemmings }!)
    selectDataSet()
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("fan-recovery-\(UUID())")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let archive = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
      .appendingPathComponent("Content/lemming1.pc/level000.dat")
    let sections = try ClassicDATArchive.decode(Data(contentsOf: archive))
    for index in 0..<2 {
      try Data(sections[index].data.prefix(ClassicLevel.recordSize))
        .write(to: folder.appendingPathComponent("test\(index).lvl"))
    }
    var invalid = Data(sections[0].data.prefix(ClassicLevel.recordSize))
    invalid[0x1B] = 200
    try invalid.write(to: folder.appendingPathComponent("unsupported.lvl"))
    let zip = Process()
    zip.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
    zip.currentDirectoryURL = folder
    zip.arguments = ["-q", "pack.zip", "test0.lvl", "test1.lvl", "unsupported.lvl"]
    try zip.run(); zip.waitUntilExit()
    try check(zip.terminationStatus == 0, "Could not create fan fixture")
    let pack = folder.appendingPathComponent("pack.zip")
    let entries = FanLevelLibrary.entries(in: pack)
    try check(entries.count == 3, "Fan fixture has no levels")
    fanPack = pack
    startFanRun([entries[1], entries[0], entries[1]])
    fanQueueIndex = 1; loadCurrentFanLevel(); _ = advanceFanPlay()
    guard let original = session as? ClassicSession else { throw IntegrationFailure(message: "No fan recovery session") }
    for _ in 0..<100 { original.tick() }
    original.adjustRate(by: 5)
    for _ in 0..<20 { original.tick() }
    panel.selectedSkillIndex = 4
    saveRunCheckpoint(immediately: true)
    guard let checkpoint = try recoveryStore.latest(profileID: arcadeProfileID, hotSeatID: arcadeHotSeatID) else {
      throw IntegrationFailure(message: "Fan run did not save a checkpoint")
    }
    try check(checkpoint.fan?.index == 1 && checkpoint.fan?.queue.count == 3 && checkpoint.sourcePath == pack.path,
      "Fan checkpoint lost pack or queue")
    let expectedState = ClassicDOSReplayRecorder.stateHash(of: original.simulation)
    endFanRun()
    if let alternate = dataSets.firstIndex(where: { $0.set.title == .ohNoMoreLemmings }) {
      gamePicker.selectItem(at: alternate); selectDataSet()
    }
    let starts = ArcadeStore.shared.records.trolley.starts.count
    restoreRun(checkpoint)
    guard let restored = session as? ClassicSession else { throw IntegrationFailure(message: "Fan checkpoint did not restore") }
    try check(fanPlaying && phase == .playing && isPaused && panel.selectedSkillIndex == 4
      && fanQueueIndex == 1 && fanQueue.map(\.file) == [entries[1].file, entries[0].file, entries[1].file],
      "Fan restoration lost pause, skill selection or shuffled queue")
    try check(arcadeRunID == checkpoint.runID && ArcadeStore.shared.records.trolley.starts.count == starts,
      "Fan recovery counted a new attempt")
    try check(ClassicDOSReplayRecorder.stateHash(of: restored.simulation) == expectedState, "Fan recovery changed state")
    for _ in 0..<25 { original.tick(); restored.tick() }
    try check(ClassicDOSReplayRecorder.stateHash(of: restored.simulation)
      == ClassicDOSReplayRecorder.stateHash(of: original.simulation), "Fan recovery diverged on continuation")
    GameScreen.shared.dismissAll()
    let hiddenPack = folder.appendingPathComponent("missing.zip")
    try FileManager.default.moveItem(at: pack, to: hiddenPack)
    restoreRun(checkpoint)
    try check(session === restored, "Missing fan pack replaced live play")
    GameScreen.shared.dismissAll()
    try FileManager.default.moveItem(at: hiddenPack, to: pack)
    phase = .results; _ = advanceFanPlay()
    try check(fanQueueIndex == 2 && phase == .briefing, "Restored fan queue lost the next level")
    returnToLibrary()
    let previousSession = session
    fanQueue = [entries.first { $0.file == "unsupported.lvl" }!]
    fanQueueIndex = 0
    loadCurrentFanLevel()
    try check(!fanPlaying && fanScreen == .levels && session === previousSession,
      "Unsupported fan graphics opened a stale playable briefing")
    var invalidGeometry = Data(sections[0].data.prefix(ClassicLevel.recordSize))
    invalidGeometry[0x1B] = 200
    let invalidLevel = try ClassicLevel(data: invalidGeometry)
    try check(!buildLevel(.standalone(invalidLevel, rank: "Invalid")),
      "Missing campaign graphics reported a successful level build")
    returnToLibrary()
    fanPack = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
      .appendingPathComponent("Content/LevelPacks/0491-Genesis-Mayhem.zip")
    fanQueue = [FanLevelLibrary.entries(in: fanPack!)[0]]; fanQueueIndex = 0; fanScreen = .off
    fanPackGraphics = false; restoringCheckpoint = true
    loadCurrentFanLevel()
    restoringCheckpoint = false
    guard let legacySession = session as? ClassicSession, fanPlaying else {
      throw IntegrationFailure(message: "Legacy Genesis fixture failed to load")
    }
    phase = .playing
    for _ in 0..<30 { legacySession.tick() }
    saveRunCheckpoint(immediately: true)
    var legacy = try recoveryStore.latest(profileID: arcadeProfileID, hotSeatID: arcadeHotSeatID)!
    legacy.fanPackGraphics = nil
    let legacyHash = ClassicDOSReplayRecorder.stateHash(of: legacySession.simulation)
    returnToLibrary(); restoreRun(legacy)
    try check(!fanPackGraphics && isPaused && arcadeRunID == legacy.runID && (session as? ClassicSession).map {
      ClassicDOSReplayRecorder.stateHash(of: $0.simulation) == legacyHash
    } == true, "Custom graphics update broke an existing fan checkpoint")
    retry()
    try check(fanPackGraphics && fanPlaying && session?.currentTick == 0,
      "A new fan attempt retained legacy graphics after retry")
    print("PASS Classic fan checkpoint, shuffled queue, exact paused restore, identity, continuation and missing-pack rejection")
  }
  fileprivate func testEscapeToMainMenu() throws {
    GameScreen.shared.dismissAll()
    returnToLibrary(); loadContent()
    gamePicker.selectItem(at: dataSets.firstIndex { $0.set.title == .lemmings }!)
    selectDataSet(); loadLevel(at: 30); phase = .playing
    for _ in 0..<120 { session?.tick() }
    launchMode = .quest
    let run = arcadeRunID
    installKeyboardShortcuts()
    guard let mainMenu = gameplayKeyboard?.mainMenu else {
      throw IntegrationFailure(message: "Escape callback was not installed")
    }
    mainMenu()
    try check(activeTitle == nil && !sequelIsActive && !fanPlaying && window.attachedSheet == nil,
      "Escape did not return directly to the library")
    try check(try recoveryStore.latest(profileID: arcadeProfileID, hotSeatID: arcadeHotSeatID)?.runID == run,
      "Escape discarded the active run")
    try check(menuRecovery?.runID == run && playfield.overlayLines.first?.hasPrefix("RESUME - ") == true && launchChoice == 0,
      "Main screen did not prioritise the saved run")
    let image = ReplayFrameCapture.image(size: playfield.bounds.size) { ReplayFrameCapture.draw(playfield, in: playfield.bounds) }
    let output = URL(fileURLWithPath: ".build/resume-main-screen.png")
    try NSBitmapImageRep(cgImage: image!).representation(using: .png, properties: [:])!.write(to: output)
    advancePhase()
    try check(arcadeRunID == run && session?.currentTick == 120 && phase == .playing && launchMode == .quest && isPaused && !GameScreen.shared.isPresented,
      "Main screen resume did not restore the exact paused attempt in one action")
    let previous = ArcadeStore.shared
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("resume-seat-\(UUID().uuidString)")
    let store = ArcadeStore(file: directory.appendingPathComponent("records.json"), bundledProofs: nil)
    ArcadeStore.shared = store
    defer { ArcadeStore.shared = previous }
    let host = store.records.activeProfileID
    let guest = store.addProfile(initials: "UVA", portrait: 2)!
    store.selectProfile(host); store.toggleSessionProfile(guest.id)
    _ = store.passSessionTurn(after: host)
    loadLevel(at: 30); phase = .playing
    let sharedRun = arcadeRunID, sharedID = store.hotSeatID
    returnToLibrary()
    try check(menuRecovery?.runID == sharedRun && menuRecovery?.tick == 0 && playfield.overlayLines.first == "RESUME - UVA",
      "Fresh Hot Seat attempt was lost or resume showed the wrong player")
    advancePhase()
    try check(arcadeRunID == sharedRun && arcadeProfileID == guest.id && arcadeHotSeatID == sharedID && session?.currentTick == 0 && isPaused,
      "Hot Seat resume changed the owner, shared session or fresh attempt")
    returnToLibrary()
    store.endHotSeat(); renderScreen()
    try check(menuRecovery?.hotSeatID == nil && menuRecovery?.runID != sharedRun, "Solo menu offered another Hot Seat's saved attempt")
    print("PASS Escape returns directly to the main menu and saves the active run")
  }
  fileprivate func testRunRecovery() throws {
    GameScreen.shared.dismissAll()
    settings.music = .silent; loadContent()
    gamePicker.selectItem(at: dataSets.firstIndex { $0.set.title == .lemmings }!)
    selectDataSet(); loadLevel(at: 30); phase = .playing
    guard let original = session as? ClassicSession else { throw IntegrationFailure(message: "No classic recovery fixture") }
    let initialSimulation = original.simulation
    for _ in 0..<160 { original.tick() }
    original.adjustRate(by: 5)
    if let worker = original.lemmings.first {
      _ = original.assign(skillIndex: 3, to: worker.id)
    }
    for _ in 0..<30 { original.tick() }
    original.nuke(); original.tick(); original.undoNuke()
    for _ in 0..<20 { original.tick() }
    original.adjustRate(by: 3)
    _ = original.rewind(seconds: 3)
    panel.selectedSkillIndex = 4
    saveRunCheckpoint(immediately: true)
    guard let checkpoint = try recoveryStore.latest(profileID: arcadeProfileID) else {
      throw IntegrationFailure(message: "No disk checkpoint was saved")
    }
    let encoded = try JSONEncoder().encode(checkpoint)
    for (key, replacement) in [("tick", -1 as Any), ("tick", 120_001), ("initialStateHash", "wrong"),
      ("stateHash", "wrong"), ("version", 2), ("selectedSkill", 8), ("nukeCount", -1)] {
      var object = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
      object[key] = replacement
      let damaged = try JSONDecoder().decode(RunRecovery.self, from: JSONSerialization.data(withJSONObject: object))
      let target = ClassicSession(simulation: initialSimulation, width: original.levelWidth, height: original.levelHeight)
      let clean = ClassicDOSReplayRecorder.stateHash(of: target.simulation)
      do {
        try target.restore(damaged)
        throw IntegrationFailure(message: "Damaged checkpoint accepted: \(key)")
      } catch is RunRecoveryError {}
      try check(target.currentTick == 0 && ClassicDOSReplayRecorder.stateHash(of: target.simulation) == clean,
        "Rejected recovery modified the simulation")
    }
    let expected = ClassicDOSReplayRecorder.stateHash(of: original.simulation)
    let startsBefore = ArcadeStore.shared.records.trolley.starts.count
    restoreRun(checkpoint)
    try check(ArcadeStore.shared.records.trolley.starts.count == startsBefore, "Recovery counted a new attempt")
    guard let restored = session as? ClassicSession else { throw IntegrationFailure(message: "Recovery lost the session") }
    try check(ClassicDOSReplayRecorder.stateHash(of: restored.simulation) == expected && isPaused,
      "Recovery did not restore exact terrain, crowd, skills and paused tick")
    try check(arcadeRunID == checkpoint.runID && restored.usedRewind && restored.undoCount == original.undoCount
      && panel.selectedSkillIndex == 4, "Recovery lost run identity, assistance or selected skill")
    for _ in 0..<70 { original.tick(); restored.tick() }
    try check(ClassicDOSReplayRecorder.stateHash(of: restored.simulation) == ClassicDOSReplayRecorder.stateHash(of: original.simulation),
      "Recovered simulation diverged on continuation")
    GameScreen.shared.dismissAll()

    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("CheckpointTests-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("run.json")
    let file = RunRecoveryFile(url: url)
    _ = try file.load(); try file.save(checkpoint); try file.save(checkpoint)
    let stale = RunRecoveryFile(url: url); _ = try stale.load()
    var next = checkpoint; next.savedAt = checkpoint.savedAt.addingTimeInterval(1)
    try file.save(next)
    do { try stale.save(checkpoint); throw IntegrationFailure(message: "A stale checkpoint writer overwrote newer progress") }
    catch RunRecoveryError.changed {}
    try Data("broken".utf8).write(to: url)
    let backup = RunRecoveryFile(url: url)
    try check(try backup.load()?.tick == checkpoint.tick && backup.recoveredBackup, "Checkpoint backup did not recover")
    try check(try FileManager.default.contentsOfDirectory(atPath: directory.path).contains { $0.contains("unreadable-") },
      "Recovery did not preserve damaged bytes")
    try backup.save(nil)
    try check(try RunRecoveryFile(url: url).load() == nil, "Completed checkpoint returned")
    try Data("broken again".utf8).write(to: url)
    try check(try RunRecoveryFile(url: url).load() == nil, "Backup revived a completed checkpoint")
    let unknown = Data("{\"version\":2,\"checksum\":\"\"}".utf8)
    try unknown.write(to: url)
    do { _ = try RunRecoveryFile(url: url).load(); throw IntegrationFailure(message: "Unsupported checkpoint version was replaced") }
    catch RunRecoveryError.version {}
    try check(try Data(contentsOf: url) == unknown, "Unsupported checkpoint bytes changed")
    let scoped = RunRecoveryStore(directory: directory.appendingPathComponent("scoped"))
    var sharedCheckpoint = checkpoint
    sharedCheckpoint.hotSeatID = "shared-campaign"
    scoped.save(sharedCheckpoint, immediately: true) { _ in }
    try check(try scoped.latest(profileID: checkpoint.profileID) == nil, "Solo recovery exposed a shared attempt")
    try check(try scoped.latest(profileID: checkpoint.profileID, hotSeatID: "shared-campaign")?.runID == checkpoint.runID,
      "Shared recovery lost its attempt")
    let beforeScopeRestore = session
    restoreRun(sharedCheckpoint)
    try check(session === beforeScopeRestore, "A shared checkpoint replaced a solo game")
    GameScreen.shared.dismissAll()
    let mixed = RunRecoveryStore(directory: directory.appendingPathComponent("mixed"))
    mixed.save(checkpoint, immediately: true) { _ in }
    let bad = mixed.directory.appendingPathComponent(UUID().uuidString + ".json")
    try Data("damaged older run".utf8).write(to: bad)
    try check(try mixed.latest(profileID: checkpoint.profileID)?.runID == checkpoint.runID,
      "A damaged run hid another valid checkpoint")
    try check(try Data(contentsOf: bad) == Data("damaged older run".utf8), "Discovery changed damaged bytes")
    let oversized = directory.appendingPathComponent("oversized.json")
    FileManager.default.createFile(atPath: oversized.path, contents: nil)
    let handle = try FileHandle(forWritingTo: oversized)
    try handle.truncate(atOffset: 65 * 1024 * 1024); try handle.close()
    do { _ = try RunRecoveryFile(url: oversized).load(); throw IntegrationFailure(message: "Oversized checkpoint was accepted") }
    catch RunRecoveryError.invalid {}
    try recoveryStore.clear(checkpoint.runID)
    print("PASS disk checkpoint, rewind/undo journal, exact paused restoration, continuation, backups, corruption, version and stale-writer rejection")
  }

  fileprivate func testLevelHints() async throws {
    GameScreen.shared.dismissAll()
    settings.music = .silent
    loadContent()
    guard let gameIndex = dataSets.firstIndex(where: { $0.set.title == .lemmings }) else {
      throw IntegrationFailure(message: "Missing original campaign at \(Bundle.main.resourceURL?.path ?? "none"); found \(dataSets.map { $0.set.name })")
    }
    gamePicker.selectItem(at: gameIndex); selectDataSet(); loadLevel(at: 30)
    guard let current = session, let identity = arcadeLevel?.conditions?.levelFingerprint,
          let (catalogue, engine) = LevelHintCatalogue.load(), let level = catalogue.level(for: identity, engine: engine) else {
      throw IntegrationFailure(message: "Tricky 1 did not match its checked hint data")
    }
    try check(catalogue.levels.count == 120 && level.rank == "Tricky" && level.number == 1,
      "Hint coverage or live level identity is wrong")
    for row in catalogue.levels {
      try check(catalogue.level(for: row.fingerprint, engine: engine) != nil, "Invalid hints for \(row.title)")
      try check(row.deck.stages.count == 3 && row.deck.stages[0].moves.isEmpty && row.deck.stages[1].moves.isEmpty,
        "A gentle hint exposed opening markers")
    }
    try check(catalogue.level(for: identity, engine: "changed") == nil && catalogue.level(for: "other-level", engine: engine) == nil,
      "Stale or mismatched hints were accepted")
    try check(GameMenuArtwork.renderer()?.font(.small) != nil && GameMenuArtwork.renderer()?.font(.large) != nil,
      "The packaged game fonts are unavailable")
    let renderer = GameMenuArtwork.renderer()!
    for face in ClassicMacUserInterface.Face.allCases {
      let font = renderer.font(face)!
      let text = "OUT 100 HOME 10 TIME 02:45 !?<-+>"
      for scale in [1, 2] {
        let size = CGSize(width: font.width(of: text, scale: scale) + 20, height: font.height(scale: scale) + 20)
        func render(cached: Bool) -> Data? {
          ReplayFrameCapture.image(size: size) {
            NSColor.black.setFill(); CGRect(origin: .zero, size: size).fill()
            if cached { renderer.draw(text, face: face, at: CGPoint(x: 10, y: 10), scale: scale, alpha: 0.75) }
            else {
              for (index, character) in text.enumerated() {
                guard let glyph = font.glyph(for: character), let image = glyph.makeNSImage() else { continue }
                image.draw(in: CGRect(x: 10 + (index * font.cellWidth + glyph.x) * scale,
                  y: 10 + glyph.y * scale, width: glyph.width * scale, height: glyph.height * scale),
                  from: .zero, operation: .sourceOver, fraction: 0.75, respectFlipped: true,
                  hints: [.interpolation: NSImageInterpolation.none])
              }
            }
          }?.dataProvider?.data as Data?
        }
        try check(render(cached: true) == render(cached: false), "Cached game text changed pixels for \(face) at \(scale)x")
      }
    }
    try check(MacInterfaceRenderer.menuLines("First\n\n1. Builder → Basher", columns: 80)
      == ["FIRST", "", "1. BUILDER -> BASHER"], "Bitmap wrapping lost paragraphs or skill arrows")
    try check(MacInterfaceRenderer.menuLines("abcdefgh ij", columns: 3) == ["ABC", "DEF", "GH", "IJ"],
      "Bitmap wrapping dropped part of a long word")
    func hintText(in view: NSView) -> [HintBitmapText] {
      (view as? HintBitmapText).map { [$0] } ?? view.subviews.flatMap { hintText(in: $0) }
    }
    func verifyText(_ page: NSView, stage: LevelHintDeck.Stage) throws {
      page.layoutSubtreeIfNeeded()
      let labels = hintText(in: page)
      guard let body = labels.first(where: { $0.stringValue == stage.body }), let scroll = body.enclosingScrollView else {
        throw IntegrationFailure(message: "Hint prose does not use scrollable game text")
      }
      try check(body.frame.height >= body.requiredHeight(width: body.bounds.width), "Hint text is clipped")
      try check(body.accessibilityValue() as? String == stage.body, "Bitmap hints lost their accessible text")
      // AppKit rounds the clip origin to a backing pixel when the menu is scaled.
      let topOffset = scroll.contentView.convertToBacking(CGRect(x: 0, y: 0, width: 1,
        height: abs(scroll.contentView.bounds.minY))).height
      try check(topOffset <= 1, "New hint tier retained scroll position \(scroll.contentView.bounds.minY) for \(stage.title): \(stage.body.prefix(40))")
    }
    func button(_ title: String, in view: NSView) -> NSButton? {
      if let value = view as? NSButton, value.title == title { return value }
      return view.subviews.compactMap { button(title, in: $0) }.first
    }
    func capture(_ page: NSView, name: String) throws {
      page.layoutSubtreeIfNeeded()
      // A fresh bitmap also needs the unchanged parts of a previously drawn page.
      func redraw(_ view: NSView) { view.needsDisplay = true; view.subviews.forEach(redraw) }
      redraw(page)
      let bitmap = page.bitmapImageRepForCachingDisplay(in: page.bounds)!
      page.cacheDisplay(in: page.bounds, to: bitmap)
      let directory = URL(fileURLWithPath: ".build/hints")
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent(name + ".png"))
    }
    for mode in [ClassicDisplayMode.flat, .monitor] {
      settings.display = mode; phase = .playing; isPaused = false; applyDisplayMode()
      let before = current.currentTick, skills = current.skillAssignments
      showLevelHints()
      guard let page = LevelHintWindow.shared.page else { throw IntegrationFailure(message: "Hints did not open") }
      try check(isPaused && LevelHintWindow.shared.revealedTier == 0, "Hints failed to pause or started with spoilers")
      step(at: 100); step(at: 101)
      try check(current.currentTick == before && current.skillAssignments == skills, "Reading hints played the level")
      try verifyText(page, stage: level.deck.stages[0])
      try capture(page, name: "nudge-\(mode)")
      let next = button("Reveal the approach", in: page)!
      try check(next.keyEquivalent.isEmpty, "Return could accidentally reveal a spoiler")
      next.performClick(nil)
      try check(LevelHintWindow.shared.revealedTier == 1, "One click skipped a hint tier")
      try verifyText(page, stage: level.deck.stages[1])
      try capture(page, name: "approach-\(mode)")
      next.performClick(nil)
      try check(LevelHintWindow.shared.revealedTier == 2, "Opening moves were skipped")
      for _ in 0..<600 where !next.isEnabled { try await Task.sleep(for: .milliseconds(50)) }
      try check(next.isEnabled && next.title == "Show solution replay", "Verified solution was not offered after the final hint")
      let liveRun = arcadeRunID, liveOwner = arcadeProfileID, liveShared = arcadeHotSeatID
      let recordsEncoder = JSONEncoder(); recordsEncoder.outputFormatting = [.sortedKeys]
      let savedRecords = try recordsEncoder.encode(ArcadeStore.shared.records)
      let liveHash = ClassicDOSReplayRecorder.stateHash(of: (current as! ClassicSession).simulation)
      next.performClick(nil)
      guard let warning = GameScreen.shared.controllerPage(in: window) as? GameMenuPage else {
        throw IntegrationFailure(message: "Missing spoiler confirmation")
      }
      try check(warning !== page && LevelHintWindow.shared.solutionWindow == nil, "Solution played without confirmation")
      try check(window.firstResponder === warning.controllerBackButton, "Spoiler confirmation did not focus Keep trying")
      let confirm = button("Show full solution", in: warning)!
      try check(confirm.keyEquivalent.isEmpty, "Return could reveal the solution")
      try capture(warning, name: "solution-confirm-\(mode)")
      let spoilerController = ControllerMenuNavigator()
      _ = spoilerController.handle(.assign, in: warning)
      try check(GameScreen.shared.controllerPage(in: window) === page, "Cancelling solution did not return to hints")
      next.performClick(nil)
      let accepted = GameScreen.shared.controllerPage(in: window)!
      button("Show full solution", in: accepted)!.performClick(nil)
      guard let ghost = LevelHintWindow.shared.solutionWindow else { throw IntegrationFailure(message: "Confirmed solution did not open") }
      ghost.stop()
      try check(ghost.playback.session !== current && isPaused, "Ghost used or resumed the live attempt")
      let expected = ghost.playback.solution.replay.expected!
      for _ in 0..<min(338, expected.ticks) { ghost.advance() }
      try capture(ghost.page, name: "solution-playing-\(mode)")
      button("Pause", in: ghost.page)!.performClick(nil)
      button("1x", in: ghost.page)!.performClick(nil)
      try check(button("3x", in: ghost.page) != nil, "Replay speed did not increase")
      button("3x", in: ghost.page)!.performClick(nil)
      try check(button("10x", in: ghost.page) != nil, "Replay speed did not reach 10x")
      let stoppedTick = ghost.playback.session.currentTick
      ghost.advance()
      try check(ghost.playback.session.currentTick == stoppedTick, "Ghost pause did not stop playback")
      button("Play", in: ghost.page)!.performClick(nil)
      for _ in 0..<expected.ticks where !ghost.playback.session.isComplete { ghost.advance() }
      try check(ghost.playback.session.isComplete && ghost.playback.session.simulation.didWin,
        "Ghost did not complete its winning solution")
      try check(ClassicDOSReplayRecorder.stateHash(of: ghost.playback.session.simulation) == expected.stateHash,
        "Animated solution diverged from strict replay validation")
      try capture(ghost.page, name: "solution-complete-\(mode)")
      try check(ClassicDOSReplayRecorder.stateHash(of: (current as! ClassicSession).simulation) == liveHash,
        "Ghost changed the live terrain, skills or lemmings")
      try check(arcadeRunID == liveRun && arcadeProfileID == liveOwner && arcadeHotSeatID == liveShared
        && (try recordsEncoder.encode(ArcadeStore.shared.records)) == savedRecords,
        "Ghost changed run ownership, saved records or shared progress")
      ghost.page.cancelOperation(nil)
      try check(isPaused && GameScreen.shared.controllerPage(in: window) === page, "Closing ghost lost the paused hints")
      try verifyText(page, stage: level.deck.stages[2])
      try capture(page, name: "opening-\(mode)")
      page.cancelOperation(nil)
      try check(!isPaused && !GameScreen.shared.isPresented && LevelHintWindow.shared.page == nil,
        "Closing hints did not restore gameplay")
      isPaused = true; showLevelHints()
      try check(LevelHintWindow.shared.revealedTier == 0, "Reopening exposed previously revealed spoilers")
      GameScreen.shared.dismissAll()
      try check(isPaused, "Reading hints unpaused a game that was already paused")
    }
    loadLevel(at: 0)
    let fresh = (session as! ClassicSession).initialSimulation
    guard let proof = VerifiedSolution.load(initial: fresh, from: Bundle.main.resourceURL) else {
      throw IntegrationFailure(message: "Missing Fun 1 solution")
    }
    let shifted = ClassicDOSReplay(rank: proof.replay.rank, number: proof.replay.number,
      title: proof.replay.title, initialStateHash: proof.replay.initialStateHash,
      events: [.init(tick: 0, action: .releaseRate(50), afterTick: true)] + proof.replay.events.map {
        .init(tick: $0.tick, action: $0.action, afterTick: true)
      })
    let liveOutcome = try ClassicDOSReplayPlayer.run(shifted, simulation: fresh, verify: false)
    let liveReplay = ClassicDOSReplay(rank: shifted.rank, number: shifted.number, title: shifted.title,
      initialStateHash: shifted.initialStateHash, events: shifted.events, expected: liveOutcome)
    guard let liveProof = VerifiedSolution.validate(liveReplay, initial: fresh) else {
      throw IntegrationFailure(message: "Valid after-tick solution was rejected")
    }
    let livePlayback = SolutionPlayback(liveProof, width: 1600, height: 160)
    for _ in 0..<liveOutcome.ticks { livePlayback.tick() }
    try check(ClassicDOSReplayRecorder.stateHash(of: livePlayback.session.simulation) == liveOutcome.stateHash,
      "Animated after-tick input timing differs from the strict replay player")
    var changed = fresh; _ = changed.tick()
    try check(VerifiedSolution.validate(proof.replay, initial: changed) == nil,
      "Changed initial state accepted a solution")
    let incomplete = ClassicDOSReplay(rank: shifted.rank, number: shifted.number, title: shifted.title,
      initialStateHash: shifted.initialStateHash, events: shifted.events)
    try check(VerifiedSolution.validate(incomplete, initial: fresh) == nil,
      "Solution without a verified outcome was accepted")
    let broken = ClassicDOSReplay(rank: shifted.rank, number: shifted.number, title: shifted.title,
      initialStateHash: shifted.initialStateHash, events: [], expected: liveOutcome)
    try check(VerifiedSolution.validate(broken, initial: fresh) == nil,
      "Broken solution was accepted")
    // Exercise every shipped page plus an oversized imported-level coaching page.
    let longDeck = LevelHintDeck(title: "Long coaching", checked: false, stages: [
      .init(title: "A gentle nudge", body: String(repeating: "Keep a worker safe.\n", count: 100)),
      .init(title: "Make a small plan", body: "Check the exit."),
      .init(title: "Try one idea", body: "Try one skill.")])
    for deck in catalogue.levels.map(\.deck) + [longDeck] {
      LevelHintWindow.shared.show(deck, owner: window)
      let page = LevelHintWindow.shared.page!
      for tier in 0..<3 {
        try verifyText(page, stage: deck.stages[tier])
        if deck.title == longDeck.title && tier == 0 {
          let body = hintText(in: page).first { $0.stringValue == deck.stages[tier].body }!
          let scroll = body.enclosingScrollView!
          try check(body.frame.height > scroll.contentSize.height, "Long hints did not enable scrolling")
          let end = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 1,
            windowNumber: window.windowNumber, context: nil, characters: "", charactersIgnoringModifiers: "",
            isARepeat: false, keyCode: 119)!
          window.firstResponder?.keyDown(with: end)
          try check(scroll.contentView.bounds.minY > 0, "Keyboard could not scroll the hint text")
        }
        if tier < 2 {
          let title = tier == 0 ? (deck.checked ? "Reveal the approach" : "Make a small plan")
            : (deck.checked ? "Reveal opening moves" : "Show practice tips")
          button(title, in: page)!.performClick(nil)
        }
      }
      GameScreen.shared.dismissAll()
    }
    let host = SpeedTestWindow(contentRect: window.frame, styleMask: [], backing: .buffered, defer: false)
    let keyboard = GameplayKeyboard(window: host)
    keyboard.active = { true }
    var opened = 0; keyboard.hints = { opened += 1 }
    for repeated in [false, true] {
      let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 1,
        windowNumber: host.windowNumber, context: nil, characters: "", charactersIgnoringModifiers: "",
        isARepeat: repeated, keyCode: 122)!
      try check(keyboard.handle(event) == nil, "F1 leaked into gameplay")
    }
    try check(opened == 1, "Holding F1 opened hints repeatedly")
    let fallback = LevelHintDeck.practice(title: "Fan level", skills: ["Builder"])
    try check(!fallback.checked && fallback.stages.allSatisfy { $0.moves.isEmpty }, "General coaching claimed a solved route")
    print("PASS checked hints, confirmed winning ghosts, exact before/after-tick playback, unchanged live runs, flat/CRT and fallback coaching")
  }

  fileprivate func testVariableSpeedInput() throws {
    GameScreen.shared.dismissAll()
    let host = SpeedTestWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 400), styleMask: [], backing: .buffered, defer: false)
    host.contentView = NSView(frame: host.contentView!.bounds)
    let controller = GameSpeedControl(), keyboard = GameplayKeyboard(window: host)
    keyboard.speedControl = controller; keyboard.active = { true }
    func key(_ type: NSEvent.EventType, _ time: Double, text: String = "f", code: UInt16 = 3, repeatKey: Bool = false, flags: NSEvent.ModifierFlags = [], in window: NSWindow? = nil) -> NSEvent {
      NSEvent.keyEvent(with: type, location: .zero, modifierFlags: flags, timestamp: time,
        windowNumber: (window ?? host).windowNumber, context: nil, characters: text,
        charactersIgnoringModifiers: text.lowercased(), isARepeat: repeatKey, keyCode: code)!
    }
    try check(keyboard.handle(key(.keyDown, 10)) == nil, "F leaked to the skill or window handler")
    _ = keyboard.handle(key(.keyUp, 10.1))
    try check(controller.target == 2, "Tap F did not select 2x")
    _ = keyboard.handle(key(.flagsChanged, 11, text: "", code: 56, flags: .shift))
    for time in [11.3, 11.8, 12.3, 12.8, 13.1] { controller.update(at: time, active: true) }
    _ = keyboard.handle(key(.keyDown, 13.2, repeatKey: true))
    try check(controller.target == 10, "Shift did not boost or an F repeat changed speed")
    _ = keyboard.handle(key(.flagsChanged, 13.3, text: "", code: 56))
    try check(controller.multiplier == 2, "Shift release did not immediately restore cruise")
    _ = keyboard.handle(key(.keyDown, 14)); _ = keyboard.handle(key(.keyUp, 14.1))
    _ = keyboard.handle(key(.keyDown, 14.2)); _ = keyboard.handle(key(.keyUp, 14.25))
    try check(!controller.isFast, "Rapid F restarted a stopped game")
    _ = keyboard.handle(key(.keyDown, 15, text: "}", code: 30, flags: .shift))
    try check(controller.target == 3 && controller.state.cruise == 3, "Shift+] did not apply the selected tier")
    _ = keyboard.handle(key(.keyDown, 16, text: "|", code: 42, flags: .shift))
    try check(!controller.isFast, "Shift+backslash did not reset")
    controller.tap(at: 17)
    var escaped = false; keyboard.mainMenu = { escaped = true }
    _ = keyboard.handle(key(.keyDown, 18, text: "\u{1b}", code: 53))
    try check(!controller.isFast && escaped, "Escape failed to stop speed and reach the main menu in one press")
    _ = keyboard.handle(key(.keyDown, 19, text: "\u{1b}", code: 53))
    try check(escaped, "Escape at 1x failed to reach the main menu")
    escaped = false
    _ = keyboard.handle(key(.flagsChanged, 19.1, text: "", code: 56, flags: .shift))
    controller.update(at: 19.5, active: true)
    _ = keyboard.handle(key(.keyDown, 19.6, text: "\u{1b}", code: 53, flags: .shift))
    _ = keyboard.handle(key(.flagsChanged, 19.7, text: "", code: 56))
    try check(controller.multiplier == 1 && escaped, "Escape while holding Shift missed the main menu or restarted speed")
    let attached = SpeedTestWindow(contentRect: host.frame, styleMask: [], backing: .buffered, defer: false)
    keyboard.bind(to: attached)
    try check(keyboard.handle(key(.keyDown, 20)) != nil, "The detached window retained speed control")
    _ = keyboard.handle(key(.keyDown, 21, in: attached)); _ = keyboard.handle(key(.keyUp, 21.1, in: attached))
    try check(controller.target == 3, "Speed keys failed after attaching to the shared game window")
    NotificationCenter.default.post(name: NSWindow.didResignKeyNotification, object: attached)
    try check(!controller.isFast, "Focus loss left the game accelerated")
    keyboard.modern = { false }; controller.variableEnabled = false
    _ = keyboard.handle(key(.keyDown, 22, in: attached)); _ = keyboard.handle(key(.keyUp, 22.1, in: attached))
    try check(controller.multiplier == 3, "OG mode did not retain the fixed speed")
    controller.variableEnabled = true; controller.newLevel()
    let speedPanel = PanelView(frame: CGRect(x: 0, y: 0, width: 640, height: 80))
    host.contentView = speedPanel
    speedPanel.onSpeedPress = { controller.pointerDown(at: $0, clickCount: $1) }
    speedPanel.onSpeedRelease = { controller.release(.mouse, at: $0) }
    speedPanel.onSpeedStep = { controller.step($0, at: $1) }
    speedPanel.cacheDisplay(in: speedPanel.bounds, to: speedPanel.bitmapImageRepForCachingDisplay(in: speedPanel.bounds)!)
    let rect = speedPanel.speedControlBounds
    try check(rect.width > 0, "Speed control has no mouse target")
    func mouse(_ type: NSEvent.EventType, _ time: Double, fraction: Double = 0.5, clicks: Int = 1) {
      let point = speedPanel.convert(CGPoint(x: rect.minX + rect.width * fraction, y: rect.midY), to: nil)
      let event = NSEvent.mouseEvent(with: type, location: point, modifierFlags: [], timestamp: time,
        windowNumber: host.windowNumber, context: nil, eventNumber: 0, clickCount: clicks, pressure: 1)!
      if type == .leftMouseDown { speedPanel.mouseDown(with: event) } else { speedPanel.mouseUp(with: event) }
    }
    mouse(.leftMouseDown, 30); mouse(.leftMouseUp, 30.05)
    try check(controller.target == 2, "Mouse tap did not engage immediately")
    mouse(.leftMouseDown, 31, fraction: 0.9); mouse(.leftMouseUp, 31.05)
    try check(controller.target == 3, "Mouse arrow did not increase speed")
    mouse(.leftMouseDown, 32); mouse(.leftMouseUp, 32.05)
    mouse(.leftMouseDown, 32.1, clicks: 2); mouse(.leftMouseUp, 32.15, clicks: 2)
    try check(controller.multiplier == 1, "A real double-click restarted speed")
    mouse(.leftMouseDown, 33); mouse(.leftMouseUp, 33.05)
    try check(controller.target == 3, "Mouse toggle lost the chosen tier")
    mouse(.leftMouseDown, 34); controller.update(at: 36, active: true)
    try check(controller.target == 10, "Mouse hold did not boost")
    mouse(.leftMouseUp, 36.1)
    try check(controller.multiplier == 3, "Mouse release did not restore cruise immediately")
    mouse(.leftMouseDown, 37); controller.update(at: 39, active: true); controller.reset(at: 39.1)
    mouse(.leftMouseUp, 39.2)
    try check(controller.multiplier == 1, "Mouse release undid an emergency exit")
    mouse(.leftMouseDown, 40); mouse(.leftMouseUp, 40.05)
    mouse(.leftMouseDown, 40.1, clicks: 2)
    try check(controller.multiplier == 1, "Second mouse press did not stop fast-forward")
    controller.update(at: 42.1, active: true)
    try check(controller.target == 10, "Holding the second mouse press could not ramp to 10x")
    mouse(.leftMouseUp, 42.2, clicks: 2)
    try check(controller.multiplier == 1, "Second-click hold did not restore normal speed")
    controller.newLevel()
    mouse(.leftMouseDown, 50, fraction: 0.9); mouse(.leftMouseUp, 50.05)
    controller.update(at: 50.4, active: true)
    try check(controller.multiplier == 3, "Mouse speed choice from 1x did not affect the clock")
    mouse(.leftMouseDown, 51, fraction: 0.1); mouse(.leftMouseUp, 51.05)
    try check(controller.multiplier == 2, "Mouse decrease did not apply immediately")
    keyboard.bind(to: host)
    for initialSpeed in [1.0, 3.0] {
      controller.newLevel()
      if initialSpeed > 1 { controller.step(1, at: 99); controller.update(at: 99.5, active: true) }
      _ = keyboard.handle(key(.keyDown, 100))
      try check(controller.target == initialSpeed, "F press toggled before distinguishing a hold")
      for (time, tier) in [(100.26, initialSpeed == 1 ? 2.0 : 5.0),
                           (100.77, initialSpeed == 1 ? 3.0 : 10.0),
                           (101.27, initialSpeed == 1 ? 5.0 : 10.0), (101.77, 10.0), (105, 10.0)] {
        _ = keyboard.handle(key(.keyDown, time, repeatKey: true))
        controller.update(at: time, active: true)
        try check(controller.target == tier, "Held F did not ramp through the same tiers as the mouse and RT")
      }
      _ = keyboard.handle(key(.keyUp, 105.1))
      try check(controller.multiplier == 10 && controller.state.cruise == 10, "F release did not retain the reached speed")
    }
    controller.newLevel()
    _ = keyboard.handle(key(.keyDown, 110)); controller.update(at: 112, active: true)
    _ = keyboard.handle(key(.keyDown, 112.1, text: "\u{1b}", code: 53))
    _ = keyboard.handle(key(.keyUp, 112.2))
    try check(controller.multiplier == 1, "F release restarted speed after Escape")
    try check(keyboard.helpText.contains("Hold F"), "Keyboard help omitted the F hold")
    print("PASS native mouse toggle, arrows, complete double-click sequence, hold and emergency release")
    print("PASS real key events: tap/hold/release, repeats, rapid exits, shortcut routing, window attachment and OG mode")
  }

  fileprivate func testHintsFromControlsHelp() async throws {
    GameScreen.shared.dismissAll()
    launchMode = .singleTitle; activeTitle = .lemmings
    gamePicker.selectItem(at: dataSets.firstIndex { $0.set.title == .lemmings }!)
    selectDataSet()
    settings.display = .flat
    window.setContentSize(NSSize(width: 1280, height: 800))
    picker.selectItem(at: 30); levelChanged()
    if phase == .briefing { advancePhase() }
    phase = .playing; isPaused = false
    applyDisplayMode()
    installKeyboardShortcuts()
    gameplayKeyboard?.controllerAction(.help)
    guard let overlay = gameplayKeyboard?.overlay else { throw IntegrationFailure(message: "Visual controls overlay did not open") }
    try check(isPaused && GameScreen.shared.contains(overlay), "Visual help did not freeze the level")
    try check(overlay.anchors().count >= 8, "Overlay did not attach key badges to the skill bar")
    let frozenSpeed = speedControl.target
    let speedEvent = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 1, windowNumber: window.windowNumber, context: nil, characters: "f", charactersIgnoringModifiers: "f", isARepeat: false, keyCode: 3)!
    overlay.keyDown(with: speedEvent)
    try check(speedControl.target == frozenSpeed, "A speed key acted through visual help")
    let frozenTick = session?.currentTick
    step(at: ProcessInfo.processInfo.systemUptime + 10)
    try check(session?.currentTick == frozenTick, "The level advanced under visual help")
    window.contentView?.layoutSubtreeIfNeeded()
    if let content = window.contentView, let bitmap = content.bitmapImageRepForCachingDisplay(in: content.bounds) {
      content.cacheDisplay(in: content.bounds, to: bitmap)
      try bitmap.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: ".build/keyboard-overlay.png"))
    }
    let escapeEvent = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 1, windowNumber: window.windowNumber, context: nil, characters: "\u{1b}", charactersIgnoringModifiers: "\u{1b}", isARepeat: false, keyCode: 53)!
    overlay.keyDown(with: escapeEvent)
    try check(!isPaused && gameplayKeyboard?.overlay == nil, "Closing visual help failed to restore play")
    isPaused = true
    gameplayKeyboard?.showHelp()
    gameplayKeyboard?.controllerMenuAction(.cancel)
    try check(isPaused, "Visual help resumed a previously paused level")
    isPaused = false
    gameplayKeyboard?.showHelp()
    gameplayKeyboard?.overlay?.onCommands()
    guard let sheet = window.attachedSheet else { throw IntegrationFailure(message: "Controls help did not open") }
    func findGuide(_ view: NSView) -> KeyboardCommandsView? {
      if let guide = view as? KeyboardCommandsView { return guide }
      return view.subviews.compactMap(findGuide).first
    }
    guard let guide = sheet.contentView.flatMap(findGuide) else { throw IntegrationFailure(message: "Missing command reference") }
    try check(guide.commands.contains { $0.keys == "Escape" } && guide.commands.contains { $0.keys == "N" }, "Guide omitted navigation bindings")
    guide.search.stringValue = "rewind"; guide.refresh()
    try check(!guide.filtered.isEmpty && guide.filtered.allSatisfy { $0.action.localizedCaseInsensitiveContains("rewind") }, "Command search did not filter")
    guide.search.stringValue = "no-command-matches-this"; guide.refresh()
    try check(guide.filtered.isEmpty, "Command search did not show an empty result")
    guide.search.stringValue = ""; guide.refresh()
    sheet.contentView?.layoutSubtreeIfNeeded()
    if let content = sheet.contentView, let bitmap = content.bitmapImageRepForCachingDisplay(in: content.bounds) {
      content.cacheDisplay(in: content.bounds, to: bitmap)
      let url = URL(fileURLWithPath: ".build/keyboard-guide.png")
      try bitmap.representation(using: .png, properties: [:])?.write(to: url)
    }
    func find(_ view: NSView) -> NSButton? {
      if let button = view as? NSButton, button.title == "Level hints" { return button }
      return view.subviews.compactMap(find).first
    }
    guard let hints = sheet.contentView.flatMap(find) else { throw IntegrationFailure(message: "Controls help omitted hints") }
    let helpInterruption = gameplayKeyboard?.interruptionCount
    hints.performClick(nil)
    try await Task.sleep(for: .milliseconds(500))
    try check(LevelHintWindow.shared.page != nil && isPaused, "Controls help failed to hand off to hints; sheet: \(window.attachedSheet != nil)")
    GameScreen.shared.dismissAll()
    try check(isPaused == (gameplayKeyboard?.interruptionCount != helpInterruption), "Closing hints after controls help restored the wrong pause state")
    isPaused = false
    gameplayKeyboard?.escape()
    guard let pause = window.attachedSheet, let hints = pause.contentView.flatMap(find) else {
      throw IntegrationFailure(message: "Pause menu omitted hints")
    }
    let pauseInterruption = gameplayKeyboard?.interruptionCount
    hints.performClick(nil)
    try await Task.sleep(for: .milliseconds(500))
    try check(LevelHintWindow.shared.page != nil && isPaused, "Pause menu failed to open hints")
    GameScreen.shared.dismissAll()
    try check(isPaused == (gameplayKeyboard?.interruptionCount != pauseInterruption), "Closing hints after pause menu restored the wrong pause state")
    isPaused = false
    print("PASS controls-help and pause-menu buttons open hints and restore play")
  }

  fileprivate func testVariableSimulationClock() throws {
    GameScreen.shared.dismissAll()
    // A synthetic clock check must not record the preceding level's scene.
    runMovie.discard()
    let game = FinalTickSession(win: false, finalTick: 10000)
    session = game; phase = .playing; isPaused = false
    settings.modernControlsEnabled = true; settings.variableSpeedEnabled = true
    speedControl.variableEnabled = true; speedControl.reset(at: 100)
    lastStepTime = 100; accumulator = 0
    for (index, rate) in [2, 3, 5, 10].enumerated() {
      let time = 101 + Double(index) * 2
      if index == 0 { speedControl.newLevel(); speedControl.tap(at: time) }
      else { speedControl.step(1, at: time) }
      step(at: time + 0.25)
      let before = game.currentTick
      for frame in 1...10 { step(at: time + 0.25 + Double(frame) / 10) }
      try check(abs(game.currentTick - before - rate * 17) <= 1, "The game clock did not run at \(rate)x: ticks \(game.currentTick-before), speed \(speedControl.multiplier), paused \(isPaused), pages \(GameScreen.shared.isPresented), sequel \(sequelIsActive), phase \(phase)")
    }
    speedControl.reset(at: 110); lastStepTime = 110; accumulator = 0
    let before = game.currentTick
    for frame in 1...10 { step(at: 110 + Double(frame) / 10) }
    try check(abs(game.currentTick - before - 17) <= 1, "Quick exit failed to restore the 1x simulation clock")
    print("PASS actual Classic simulation clock at 2x, 3x, 5x, 10x and quick return to 1x")
  }
}

private final class FinalTickSession: GameSession {
  let levelWidth = 320, levelHeight = 160, ticksPerSecond = 17
  let lemmings: [SessionLemming] = []
  let entranceX: Int? = nil
  let released = 1, total = 1, required = 1, rate = 50
  let rateLabel = "Rate"
  let remainingSeconds: Int? = 1
  let isNuking = false, supportsRewind = true
  let skills: [SessionSkill] = []
  let lastCues: [ClassicSoundEffect] = []
  private(set) var currentTick = 0
  let saved: Int
  let finalTick: Int
  init(win: Bool, finalTick: Int = 1) { saved = win ? 1 : 0; self.finalTick = finalTick }
  var isComplete: Bool { currentTick >= finalTick }
  var didWin: Bool { isComplete && saved == 1 }
  func tick() { currentTick += 1 }
  func assign(skillIndex: Int, to lemmingID: Int) -> String? { nil }
  func assignmentState(skillIndex: Int, to lemmingID: Int) -> AssignmentState { .unavailable }
  func adjustRate(by delta: Int) {}
  func nuke() {}
  let canUndoNuke = false
  func undoNuke() {}
  func rewind(seconds: Double) -> Bool { false }
  func stepBackward() -> Bool { false }
  func stepForward() -> Bool { tick(); return true }
}

extension AppDelegate {
  fileprivate func testFirstLaunchEffects() throws {
    GameScreen.shared.dismissAll()
    settings.music = .silent
    let suite = "hd-effects-tests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    var choices: [Bool] = []
    func choose(_ enabled: Bool) { choices.append(enabled); setExperiencePreset(enabled) }
    func button(_ title: String, in view: NSView) -> NSButton? {
      if let button = view as? NSButton, button.title == title { return button }
      return view.subviews.compactMap { button(title, in: $0) }.first
    }
    let welcome = EffectsWelcome(defaults: defaults)
    welcome.showIfNeeded(in: window, onChoose: choose)
    let root = window.contentView!
    guard let page = GameScreen.shared.controllerPage(in: window) as? GameMenuPage,
          let oldSchool = button("Old school", in: page), let hd = button("Play with modern defaults", in: page) else {
      throw IntegrationFailure(message: "First launch did not offer both effects choices")
    }
    try check(hd.keyEquivalent == "\r", "HD effects are not the default keyboard choice")
    page.layoutSubtreeIfNeeded()
    let bitmap = page.bitmapImageRepForCachingDisplay(in: page.bounds)!
    page.cacheDisplay(in: page.bounds, to: bitmap)
    let output = URL(fileURLWithPath: ".build/hd-defaults-tests/welcome.png")
    try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
    try bitmap.representation(using: .png, properties: [:])!.write(to: output)
    oldSchool.performClick(nil)
    try check(choices == [false] && !settings.hdEffectsEnabled && !playfield.hdEffectsEnabled,
      "Old school did not disable and apply HD effects")
    let saved = try JSONDecoder().decode(ClassicSettings.self, from: UserDefaults.standard.data(forKey: settingsKey)!)
    try check(!saved.hdEffectsEnabled && !GameScreen.shared.isPresented, "The first-launch choice was not saved and dismissed")
    let restarted = EffectsWelcome(defaults: defaults)
    restarted.showIfNeeded(in: window, onChoose: choose)
    try check(!GameScreen.shared.isPresented && choices.count == 1, "The effects choice returned on a later launch")
    defaults.removeObject(forKey: EffectsWelcome.choiceKey)
    restarted.showIfNeeded(in: window, onChoose: choose)
    button("Play with modern defaults", in: root)!.performClick(nil)
    try check(choices == [false, true] && settings.hdEffectsEnabled && settings.fullScreenHDRFlashes,
      "The default HD choice failed to enable the effects")
    print("PASS first-launch HD/old-school choices, default action, live application, persistence and one-time presentation")
  }

  fileprivate func testSuperSpeedPresentation() throws {
    GameScreen.shared.dismissAll()
    settings.music = .silent
    session = FinalTickSession(win:false,finalTick:1000)
    phase = .playing; isPaused = false; isFastForward = false
    accumulator = 0; lastStepTime = nil
    for mode in [ClassicDisplayMode.flat,.monitor,.television] {
      settings.display = mode
      step(at:1)
      speedControl.setFast(!isFastForward)
      step(at:1.01)
      try check(playfield.isFastForward && screenFlash.isSuperSpeedActive,
        "3x did not engage the sprite wakes and screen effects in \(mode)")
      var updated = settings
      updated.fullScreenHDRFlashes = false
      apply(updated)
      try check(screenFlash.isSuperSpeedActive, "the explosion setting disabled super speed")
      updated.hdEffectsEnabled = false; apply(updated)
      step(at: 1.011)
      try check(isFastForward && panel.isFastForward && !playfield.isFastForward && !screenFlash.isSuperSpeedActive,
        "Old-school mode failed to remove effects while retaining 3x gameplay")
      updated.hdEffectsEnabled = true; apply(updated); step(at: 1.012)
      try check(screenFlash.isSuperSpeedActive, "The HD effects switch failed to restore super speed")
      updated.reduceMotion = true; apply(updated); step(at: 1.013)
      try check(isFastForward && !screenFlash.isSuperSpeedActive && playfield.reduceMotion,
        "Reduced motion changed gameplay speed or left speed effects active")
      updated.reduceMotion = false; updated.reduceFlashes = true; apply(updated); step(at: 1.014)
      try check(screenFlash.isSuperSpeedActive && playfield.reduceFlashes && !settings.cinematicExplosionsEnabled,
        "Reduced flashes disabled speed effects or left cinematic explosions enabled")
      updated.reduceFlashes = false; apply(updated)
      updated.reduceFlashes = true; apply(updated)
      try check(screenFlash.isSuperSpeedActive, "Changing flash reduction cleared the active speed overlay")
      updated.reduceFlashes = false; apply(updated)
      isPaused = true; step(at:1.02)
      try check(!playfield.isFastForward && !screenFlash.isSuperSpeedActive,
        "pause left the speed effects running")
      isPaused = false; step(at:1.03)
      try check(screenFlash.isSuperSpeedActive, "unpausing did not resume super speed")
      speedControl.setFast(!isFastForward); step(at:1.04)
      try check(!screenFlash.isSuperSpeedActive, "returning to 1x retained super speed")
    }
    speedControl.setFast(!isFastForward); step(at:2)
    let page = GameMenuPage(title:"Speed test")
    GameScreen.shared.present(page,owner:window)
    step(at:2.1)
    try check(!screenFlash.isSuperSpeedActive, "speed effects continued behind a game menu")
    GameScreen.shared.dismiss(page)
    step(at:2.2)
    try check(screenFlash.isSuperSpeedActive, "closing the menu failed to restore super speed")
    phase = .results
    try check(!screenFlash.isSuperSpeedActive, "results retained the speed effect")
    isFastForward = false; panel.isFastForward = false
    print("PASS super speed controls: flat/CRT, pause, resume, 1x, menus, results and independent explosion settings")
  }
  fileprivate func testPortArtworkSwitching() throws {
    settings.music = .silent
    loadContent()
    guard let index = dataSets.firstIndex(where: { $0.set.title == .ohYesMoreLemmings }) else {
      throw IntegrationFailure(message: "Missing bundled Oh Yes! campaign")
    }
    gamePicker.selectItem(at: index); selectDataSet()
    for levelIndex in [0, 20, 30, 59, 20, 0] {
      session = nil
      loadLevel(at: levelIndex)
      guard let game = session as? ClassicSession else { throw IntegrationFailure(message: "Oh Yes! level \(levelIndex) failed to start") }
      let expected = dataSets[index].set.campaign.levels[levelIndex]
      let directory = PortExclusivePack.artworkDirectory(for: expected, portsRoot: dataSets[index].directory)
      try check(loadedArtworkDirectory == directory, "Switching Oh Yes! ranks kept the previous artwork")
      for _ in 0..<110 { game.tick() }
      try check(game.released > 0 && playfield.classicScene != nil, "Oh Yes! did not render and release lemmings")
    }
    print("PASS live Oh Yes! rank changes load the original, Oh No and Sunsoft artwork")
  }
  fileprivate func testRestartSelection() throws {
    settings.music = .silent
    loadContent()
    guard let index = dataSets.firstIndex(where: { $0.set.title == .lemmings }) else {
      throw IntegrationFailure(message: "Missing bundled Lemmings campaign")
    }
    gamePicker.selectItem(at: index); selectDataSet()
    picker.selectItem(at: 0); levelChanged(); advancePhase()
    guard let original = session, original.skills.count > 1 else {
      throw IntegrationFailure(message: "Restart test could not load the first level")
    }
    let defaultSkill = panel.selectedSkillIndex
    // Include an empty skill slot: retry must preserve the choice, not pick an available skill.
    for selected in [original.skills.count - 1, 0] {
      handle(.skill(selected))
      let name = session!.skills[selected].name
      session?.tick()
      playfield.onRetry?()
      try check(phase == .playing && session?.currentTick == 0 && session !== original,
        "Retry did not immediately start a fresh level")
      try check(session?.skills[panel.selectedSkillIndex].name == name,
        "Retry changed the selected skill")
    }
    handle(.skill(3))
    for _ in 0..<110 { session?.tick() }
    session?.nuke()
    for _ in 0..<2000 where session?.isComplete == false { session?.tick() }
    finishSessionIfNeeded()
    try check(phase == .results, "Restart test did not reach results")
    arcadeAutoPresent = true; presentArcadeResult(); arcadeAutoPresent = false
    let store = ArcadeStore.shared
    let host = store.records.activeProfileID
    let guest = store.addProfile(initials: "PAL", portrait: 2)!
    store.selectProfile(host)
    store.toggleSessionProfile(guest.id)
    let previousRun = arcadeRunID
    let previousLevel = arcadeLevel?.conditions
    let progressNamespace = store.progressKey(progressKey)
    ArcadeWindow.shared.arcadeView.retryAsNextProfile()
    try check(arcadeProfileID == guest.id && arcadeRunID != previousRun && arcadeLevel?.conditions == previousLevel,
      "Hot-seat retry changed the level or failed to assign a new guest attempt")
    try check(store.records.activeProfileID == host && store.progressKey(progressKey) == progressNamespace,
      "Hot-seat retry moved shared campaign progress to the guest")
    try check(store.records.runs.first(where: { $0.id == previousRun })?.profileID == host,
      "Hot-seat retry reassigned the completed host run")
    store.endHotSeat()
    try check(phase == .playing && session?.currentTick == 0 && panel.selectedSkillIndex == 3,
      "Results Retry changed the selected skill")
    levelChanged()
    try check(panel.selectedSkillIndex == defaultSkill,
      "An explicit level selection inherited the previous run's skill")
    print("PASS restart preserves selected skills, including empty slots, while level selection uses its default")
  }
  fileprivate func testBundledRescueTarget() throws {
    settings.music = .silent
    loadContent()
    guard let index = dataSets.firstIndex(where: { $0.set.title == .lemmings }) else {
      throw IntegrationFailure(message: "Missing bundled Lemmings campaign")
    }
    gamePicker.selectItem(at: index); selectDataSet(); loadLevel(at: 0)
    try check(arcadeLevel?.conditions?.packID == dataSets[index].set.identifierKey,
      "Returning to a bundled campaign kept the previous fan pack's identity")
    guard let conditions = arcadeLevel?.conditions, let classic = session as? ClassicSession,
          let proofs = TrolleyBundledProofs.load(), let proof = proofs.maximum(for: conditions),
          let entry = proofs.catalogue.levels.first(where: { $0.conditions == conditions }), let witness = entry.witness else {
      throw IntegrationFailure(message: "Live Classic conditions do not match the bundled proof")
    }
    let replayURL = Bundle.main.resourceURL!.appendingPathComponent("Trolley").appendingPathComponent(witness.path)
    let replay = try JSONDecoder().decode(ClassicDOSReplay.self, from: Data(contentsOf: replayURL))
    let result = try ClassicDOSReplayPlayer.run(replay, simulation: classic.simulation)
    try check(result.saved == classic.total && proof.value == result.saved && result.didWin,
      "Bundled witness did not rescue the full live Classic population")
    try check(ArcadeStore.shared.records.trolley.maximum(conditions: conditions, assisted: false) == proof,
      "The live level start did not install its verified target")
    print("PASS bundled proof matches live Classic conditions and replays to a full rescue")
  }
  fileprivate func prepareArcadeTests() {
    arcadeAutoPresent = false
    ArcadeStore.shared = ArcadeStore(file: FileManager.default.temporaryDirectory.appendingPathComponent("arcade-integration-\(UUID().uuidString).json"))
  }
  fileprivate func testGamePages() throws {
    let running = FinalTickSession(win: false, finalTick: 1000)
    session = running; phase = .playing; isPaused = false; lastStepTime = 1; accumulator = 0
    let count = NSApp.windows.count
    let page = GameMenuPage(title: "Settings")
    GameScreen.shared.present(page, owner: window)
    step(at: 3)
    try check(running.currentTick == 0, "The level clock ran behind a game page")
    settings.display = tubeIsActive ? .flat : .monitor
    applyDisplayMode()
    try check(page.window === window && window.firstResponder === page, "Changing display mode lost the menu")
    try check(NSApp.windows.count == count, "A game page opened another window")
    GameScreen.shared.dismiss(page)
    step(at: 3.1)
    try check(running.currentTick > 0 && running.currentTick <= 2, "Closing a page lost play or caught up its paused time")
    var confirmed = 0
    GameScreen.shared.confirm("End this run?", detail: "The lemmings you have rescued will count. You can review this attempt, then retry when you are ready.",
      actionTitle: "End run", owner: window) { confirmed += 1 }
    let confirmation = window!.contentView!.subviews.last!
    confirmation.layoutSubtreeIfNeeded()
    let bitmap = confirmation.bitmapImageRepForCachingDisplay(in: confirmation.bounds)!
    confirmation.cacheDisplay(in: confirmation.bounds, to: bitmap)
    let output = URL(fileURLWithPath: ".build/trolley/confirmation.png")
    try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
    try bitmap.representation(using: .png, properties: [:])!.write(to: output)
    func actionButton(in view: NSView) -> NSButton? {
      if let button = view as? NSButton, button.title == "End run" { return button }
      return view.subviews.compactMap { actionButton(in: $0) }.first
    }
    guard let endRun = actionButton(in: confirmation) else { throw IntegrationFailure(message: "Native confirmation lost its action") }
    endRun.performClick(nil)
    try check(confirmed == 1 && !GameScreen.shared.isPresented && NSApp.windows.count == count,
      "Native confirmation failed to invoke its action and return to the game")
    print("PASS same-window pages, paused clock, display changes, focus and resuming play")
  }
  fileprivate func testElapsedTimeAndAudioRecovery() async throws {
    phase = .playing
    isPaused = false
    lastStepTime = nil
    accumulator = 0
    let running = FinalTickSession(win: false, finalTick: 1000)
    session = running
    step(at: 1)
    step(at: 1.1)
    step(at: 1.2)
    try check(running.currentTick == 3, "missed display callbacks slowed the simulation")
    step(at: 1000)
    try check(running.currentTick <= 8, "wake caused an unbounded simulation catch-up")
    var updated = settings
    updated.music = .amigaModules
    apply(updated)
    suspendAudioOutput()
    try check(!music.isOutputRunning, "sleep did not suspend module output")
    wakeAudioOutput()
    try await Task.sleep(for: .milliseconds(100))
    try check(music.isOutputRunning, "wake did not restore module output")
    for source in [ClassicMusicSource.adaptiveDJ, .remix(name: soundtrackLibrary.keys.sorted()[0])] {
      updated.music = source
      apply(updated)
      suspendAudioOutput()
      try check(!dj.isPlaying && !soundtrack.isPlaying, "sleep left a recording playing")
      wakeAudioOutput()
      try await Task.sleep(for: .milliseconds(100))
      try check(dj.isPlaying || soundtrack.isPlaying, "wake did not restore recorded audio")
    }
    suspendCurrentEngine()
    resumeAudioOutput()
    try await Task.sleep(for: .milliseconds(100))
    try check(!music.isRunning && !dj.isPlaying && !soundtrack.isPlaying, "wake resurrected a stopped source")
    print("PASS elapsed-time catch-up and audio interruption recovery")
  }
  fileprivate func testMusicTransitions() throws {
    settings.music = .silent
    music.loadLibrary(at: URL(fileURLWithPath: "Sources/Music/lemmings_music_mod"))
    soundtrackLibrary = SoundtrackPlayer.soundtracks(at: URL(fileURLWithPath: "Sources/Music"))
    dj.load(soundtracks: soundtrackLibrary)
    try check(!music.library.isEmpty && !soundtrackLibrary.isEmpty, "missing audio fixtures")
    let recording = ClassicMusicSource.remix(name: soundtrackLibrary.keys.sorted()[0])
    let sources: [ClassicMusicSource] = [.amigaModules, recording, .adaptiveDJ, .silent]
    for from in sources {
      for to in sources {
        for source in [from, to] {
          var updated = settings
          updated.music = source
          updated.musicVolume = 0
          updated.soundVolume = 0
          apply(updated)
        }
        try check(music.isRunning == (to == .amigaModules), "module engine wrong after \(from) -> \(to)")
        try check(soundtrack.isPlaying == (to == recording), "recording wrong after \(from) -> \(to)")
        try check(dj.isPlaying == (to == .adaptiveDJ), "DJ wrong after \(from) -> \(to)")
      }
    }
    settings.music = .amigaModules
    for shuffled in [ClassicMusicSource.adaptiveDJ, recording] {
      levelMusic = shuffled
      playMusicForCurrentLevel()
      apply(settings)
      try check(shuffled == .adaptiveDJ ? dj.isPlaying : soundtrack.isPlaying,
        "applying settings stopped the shuffled source")
    }
    levelMusic = nil
    suspendCurrentEngine()
    print("PASS all 16 music source transitions and settings applied during shuffled playback")
  }

  fileprivate func testSeasonalMusic() throws {
    let recording = ClassicMusicSource.remix(name: soundtrackLibrary.keys.sorted()[0])
    levelMusic = nil
    let root = URL(fileURLWithPath: "Sources/Music")
    for includeOthers in [false, true] {
      let regular = SoundtrackPlayer.djSoundtracks(at: root, includeOtherSoundtracks: includeOthers)
      let seasonal = SoundtrackPlayer.djSoundtracks(at: root, includeOtherSoundtracks: includeOthers, seasonal: true)
      try check(!regular.isEmpty && !seasonal.isEmpty, "missing regular or seasonal DJ pool")
      try check(regular.values.flatMap { $0 }.allSatisfy { !SoundtrackPlayer.isSeasonal($0.path) }, "regular DJ includes Christmas tracks")
      try check(seasonal.values.flatMap { $0 }.allSatisfy { SoundtrackPlayer.isSeasonal($0.path) }, "Christmas DJ includes regular tracks")
    }
    loadContent()
    let selected = gamePicker.indexOfSelectedItem
    let oldFan = fanPlaying
    let oldURL = currentNxlvURL
    defer {
      gamePicker.selectItem(at: selected)
      fanPlaying = oldFan
      currentNxlvURL = oldURL
      settings.music = .amigaModules
      levelMusic = nil
      suspendCurrentEngine()
    }
    fanPlaying = false
    currentNxlvURL = nil
    for title in [ClassicTitle.holidayLemmings1994, .lemmings, .xmasLemmings1991, .ohNoMoreLemmings, .xmasLemmings1992, .holidayLemmings1993] {
      guard let index = dataSets.firstIndex(where: { $0.set.title == title }) else {
        throw NSError(domain: "MusicTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing campaign \(title)"])
      }
      gamePicker.selectItem(at: index)
      for source in [ClassicMusicSource.amigaModules, recording, .adaptiveDJ] {
        settings.music = source
        playMusicForCurrentLevel()
        let url = dj.isPlaying ? dj.currentURL : soundtrack.isPlaying ? soundtrack.currentURL : music.currentURL
        try check(url != nil && SoundtrackPlayer.isSeasonal(url!.path) == SoundtrackPlayer.isSeasonal(title), "wrong seasonal music for \(title), \(source)")
      }
    }
    fanPlaying = true
    settings.music = .amigaModules
    playMusicForCurrentLevel()
    try check(music.currentURL.map { !SoundtrackPlayer.isSeasonal($0.path) } == true, "fan level retained Christmas modules")
    print("PASS all 16 music source transitions, seasonal DJ pools and campaign music boundaries")
  }

  fileprivate func testSavedAudioAndBanks() throws {
    UserDefaults.standard.set(false, forKey: "AudioMuted")
    UserDefaults.standard.set(true, forKey: musicPresetKey)
    for silent in [false, true] {
      let saved = ClassicSettings(music: silent ? .silent : .amigaModules,
        musicStyle: .faithful, musicVolume: 0.12,
        sound: silent ? .silent : .macintoshResources, soundVolume: 0.23)
      UserDefaults.standard.set(try JSONEncoder().encode(saved), forKey: settingsKey)
      restoreSettings()
      applyAudioSettings()
      try check(music.muted == silent && soundtrack.muted == silent && dj.isMuted == silent,
        "saved music silence was not applied")
      try check(effects.muted == silent, "saved sound silence was not applied")
      try check(abs(music.volume - 0.12) < 0.001 && abs(effects.volume - 0.23) < 0.001
        && abs(soundtrack.volume - 0.12) < 0.001 && abs(dj.masterVolume - 0.12) < 0.001,
        "saved volumes were not applied to every player")
      try check(!music.usesModernPreset, "legacy preset overrode current settings")
    }
    var updated = settings
    updated.musicVolume = 0
    updated.soundVolume = 0
    updated.sound = .macintoshResources
    apply(updated)
    let macEffects = effects.loadedEffects
    try check(!macEffects.isEmpty, "bundled Macintosh bank did not load")
    updated.sound = .amigaVoices
    apply(updated)
    let amigaEffects = effects.loadedEffects
    try check(!amigaEffects.isEmpty && amigaEffects != macEffects, "Amiga bank did not replace Macintosh")
    updated.sound = .macintoshResources
    apply(updated)
    try check(effects.loadedEffects == macEffects, "Macintosh bank did not return")
    print("PASS saved silence, volume and preset; live Macintosh/Amiga bank replacement")
  }

  fileprivate func testGlobalMuteAndStop() throws {
    for source in [ClassicMusicSource.adaptiveDJ, .remix(name: soundtrackLibrary.keys.sorted()[0])] {
      var updated = settings
      updated.music = source
      apply(updated)
      audioMuted = false
      toggleMute()
      try check(music.muted && soundtrack.muted && dj.isMuted && effects.muted,
        "global mute omitted a player")
      restoreSettings()
      try check(audioMuted, "global mute did not persist")
      toggleMute()
      try check(!soundtrack.muted && !dj.isMuted, "recordings did not unmute")
      suspendCurrentEngine()
      try check(!music.isRunning && !effects.isRunning && !soundtrack.isPlaying && !dj.isPlaying,
        "title suspension left audio playing")
    }
    print("PASS global mute persists and title suspension stops all players")
  }

  fileprivate func testMenuDisplayTransition() throws {
    if window == nil { buildInterface(); window.orderOut(nil) }
    GameScreen.shared.dismissAll()
    settings.display = .monitor
    phase = .playing
    playfield.phase = .playing
    panel.isMenuMode = false
    applyDisplayMode()
    try check(tubeIsActive && playfield.bounds.width == 640, "CRT fixture did not enter native gameplay")

    // A menu can replace the playfield before the controller phase settles.
    playfield.phase = .briefing
    panel.isMenuMode = true
    playfield.overlayTitle = "LEMMINGS"
    playfield.overlayLines = ["FULL QUEST", "LEMMINGS", "XMAS LEMMINGS 1991"]
    applyDisplayMode()
    window.contentView?.layoutSubtreeIfNeeded()
    try check(!tubeIsActive && window.contentView === plainRoot,
      "A visible menu was sent to the fixed-resolution CRT texture")
    try check(playfield.bounds.width >= 900 && playfield.bounds.height >= 500,
      "Menu retained native gameplay dimensions after restoring the plain view")
    for size in [CGSize(width: 1920, height: 1080), CGSize(width: 1000, height: 620)] {
      window.setContentSize(size)
      fitClassicDisplay()
      try check(abs(playfield.bounds.width - size.width) < 1,
        "Menu width disagrees with the window after resize")
      let rep = playfield.bitmapImageRepForCachingDisplay(in: playfield.bounds)!
      playfield.cacheDisplay(in: playfield.bounds, to: rep)
    }
    phase = .briefing
    print("PASS CRT-to-menu transition, mismatched phase, native menu resolution and full-screen resize")
  }

  fileprivate func testCRTInput() async throws {
    phase = .playing
    playfield.phase = .playing
    settings.display = .monitor
    panel.panelImage = nil
    panel.macArtwork = nil
    panel.session = FinalTickSession(win: false)
    panel.isMenuMode = false
    applyDisplayMode()
    guard let frame = composeNativeFrame() else { throw IntegrationFailure(message: "no CRT frame") }
    try check(frame.width == 640 && frame.height == 400, "CRT source inherited Retina scale")
    crtView.setSource(frame)
    crtView.settings.curvature = 0
    let mapped = crtView.sourcePoint(from: CGPoint(x: crtView.bounds.midX, y: crtView.bounds.height * 0.1))
    try check(abs((mapped?.y ?? 0) - 360) < 0.01, "bottom panel did not map to source row 360")
    crtView.settings.curvature = 10
    let edge = crtView.sourcePoint(from: CGPoint(x: crtView.bounds.width * 0.9, y: crtView.bounds.height * 0.2))
    try check(abs((edge?.x ?? 0) - 576.9216) < 0.01, "CRT input disagrees with shader sampling")
    let speedClick = panel.onSpeedPress
    var forwardedSpeedClick: (TimeInterval, Int)?
    panel.onSpeedPress = { forwardedSpeedClick = ($0, $1) }
    let speedPoint = crtView.viewPoint(fromSource: CGPoint(x: 450, y: 360))!
    let doubleClick = NSEvent.mouseEvent(with: .leftMouseDown,
      location: crtView.convert(speedPoint, to: nil), modifierFlags: [], timestamp: 42,
      windowNumber: window.windowNumber, context: nil, eventNumber: 1, clickCount: 2, pressure: 1)!
    crtView.mouseDown(with: doubleClick)
    panel.handlePointerUp()
    panel.onSpeedPress = speedClick
    try check(forwardedSpeedClick?.0 == 42 && forwardedSpeedClick?.1 == 2,
      "CRT speed button lost the native double-click count or timestamp")
    var presses = 0
    panel.onButton = { if $0 == .rateDown { presses += 1 } }
    tubeClick(CGPoint(x: 40, y: 340))
    try await Task.sleep(for: .milliseconds(450))
    try check(presses >= 3, "detached CRT panel did not repeat a held rate button")
    crtView.onMouseUp?()
    let released = presses
    try await Task.sleep(for: .milliseconds(100))
    try check(presses == released, "CRT release did not stop repetition")
    var scrolled: Double?
    panel.levelSize = CGSize(width: 1600, height: 160)
    panel.onMinimapScroll = { scrolled = $0 }
    crtView.onMouseDragged?(CGPoint(x: 550, y: 340))
    try check(scrolled != nil, "CRT minimap drag did not scroll")
    settings.display = .flat
    applyDisplayMode()
    print("PASS CRT dimensions, shader coordinates, held rate, release and minimap drag")
  }

  fileprivate func testInterruptedFade() async throws {
    dj.setVolume(0)
    dj.start()
    dj.resetLevel()
    var telemetry = AdaptiveDJEngine.Telemetry(releasedCount: 10, totalCount: 10,
      savedCount: 5, requiredCount: 5, releaseRate: 50, dangerCount: 0, remainingSeconds: 300)
    dj.updateTelemetry(telemetry)
    try await Task.sleep(for: .milliseconds(80))
    dj.resetLevel()
    telemetry.isNuking = true
    dj.updateTelemetry(telemetry)
    try await Task.sleep(for: .milliseconds(80))
    try check(dj.isCrossfading && dj.playingDeckCount == 2, "cancelled fade finished the new transition")
    try await Task.sleep(for: .milliseconds(2800))
    try check(!dj.isCrossfading && dj.playingDeckCount == 1, "fade did not retire its outgoing deck")
    dj.resetLevel()
    dj.updateTelemetry(telemetry)
    try await Task.sleep(for: .milliseconds(80))
    dj.suspendOutput()
    try await Task.sleep(for: .milliseconds(2800))
    try check(dj.isCrossfading && dj.playingDeckCount == 0, "Suspended fade consumed its remaining duration")
    dj.resumeOutput()
    try await Task.sleep(for: .milliseconds(80))
    try check(dj.isCrossfading && dj.playingDeckCount == 2, "Resuming skipped the suspended fade")
    // Simulate a long frame. Fade duration must not depend on timer callback count.
    usleep(2_800_000)
    try await Task.sleep(for: .milliseconds(100))
    try check(!dj.isCrossfading && dj.playingDeckCount == 1, "A delayed main actor stretched the fade")
    dj.resetLevel()
    dj.updateTelemetry(telemetry)
    dj.stop()
    dj.start()
    try await Task.sleep(for: .milliseconds(100))
    try check(dj.isPlaying && dj.playingDeckCount == 1, "cancelled fade damaged restarted playback")
    dj.stop()
    print("PASS overlapping DJ cues, fade completion and stop/start cancellation")
  }

  fileprivate func testSteppedCompletion() throws {
    buildInterface()
    autoreleasepool { window.close() }
    window.title = "Window ownership check"
    renderScreen()
    try check(window.title == "Window ownership check", "Closing the main window invalidated the app-owned window")
    window.orderOut(nil)
    print("PASS closing the main window preserves ownership for delayed screen refreshes")
    for fan in [false, true] {
      for win in [false, true] {
        let label = "step-\(fan)-\(win)-\(UUID())"
        var gameFlow = ClassicGameFlow(ranks: [ClassicRank(name: "Test", levelIndices: [0, 1])])
        gameFlow.startGame()
        gameFlow.selectRank(0)
        gameFlow.beginPlaying()
        flow = gameFlow
        phase = .playing
        session = FinalTickSession(win: win)
        arcadeRunID = UUID(); arcadeProfileID = ArcadeStore.shared.records.activeProfileID
        let trolleyConditions = TrolleyConditions(gameID: "integration", packID: fan ? "fan" : "classic", levelID: label,
          levelFingerprint: label, rulesetVersion: "test-v1", physicsMode: "test", population: 1, rescueRequirement: 1,
          startingSkills: [:], timeLimitSeconds: 1)
        arcadeLevel = ArcadeLevel(id: label, title: label, game: "Test", rules: "Test rules", total: 1, required: 1,
          conditions: trolleyConditions)
        fanPlaying = fan
        fanPack = URL(fileURLWithPath: "/test-pack.zip")
        fanQueue = [FanLevelLibrary.Entry(file: "test.lvl", section: nil, label: label)]
        stepForward()
        try check(phase == .results, "single-step did not show results (fan=\(fan), win=\(win))")
        try check(arcadeReport?.run.saved == (win ? 1 : 0), "Completion did not record the actual rescue result")
        try check(arcadeReport?.trolley?.attempt.run.didWin == win,
          "Trolley did not preserve the original pass/fail outcome")
        try check(arcadeReport?.trolley?.attempt.metrics.lost == (win ? 0 : 1),
          "Trolley did not capture released population on final tick")
        try check(arcadeReport?.trolley?.attempt.maximum.status == .observed,
          "Game completion fabricated verified metadata")
        try check(playfield.overlayRetryLine != nil, "Results omitted the clickable retry action")
        if fan {
          try check(FanLevelLibrary.Progress.hasPassed(pack: fanPack!, label: label) == win,
            "single-step recorded the wrong fan result")
        } else {
          try check(flow?.hasPassed(rank: "Test", position: 0) == win,
            "single-step recorded the wrong campaign result")
        }
        let trolleyCount = ArcadeStore.shared.records.trolley.attempts.count
        finishSessionIfNeeded()
        try check(ArcadeStore.shared.records.trolley.attempts.count == trolleyCount, "Repeated completion changed Trolley history")
        try check(phase == .results, "completion was not idempotent")
        try check(ArcadeStore.shared.records.stats(level: arcadeLevel!, profileID: arcadeProfileID, assisted: false).attempts == 1,
          "One completed level counted as several arcade attempts")
      }
    }
    fanPlaying = false
    print("PASS final single-step handles wins, losses, campaign and fan progress")
  }
}

@MainActor private func testPointerAssignment() throws {
    var terrain = try NeoLemmixTerrain(width: 128, height: 96)
    for x in 0..<128 { terrain.setSolid(true, x: x, y: 48) }
    let config = try NeoLemmixConfiguration(totalLemmings: 2, requiredToSave: 1,
        spawnInterval: 4, entrances: [], preplacedLemmings: [
            .init(position: .init(x: 40, y: 48)), .init(position: .init(x: 44, y: 48))],
        skills: [.climber: .finite(2), .builder: .finite(1)])
    let simulation = try NeoLemmixSimulation(terrain: terrain, configuration: config)
    let session = NeoLemmixSession(simulation: simulation, width: 128, height: 96)
    let skill = session.skills.firstIndex { $0.name.lowercased() == "climber" }!
    let ids = session.lemmings.map(\.id)
    let view = PlayfieldView(frame: CGRect(x: 0, y: 0, width: 384, height: 288))
    view.levelImage = CGContext(data: nil, width: 128, height: 96, bitsPerComponent: 8,
        bytesPerRow: 128 * 4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!.makeImage()
    view.session = session; view.phase = .playing; view.selectedSkill = { skill }
    view.viewport.levelSize = CGSize(width: 128, height: 96)
    view.viewport.viewSize = view.bounds.size
    var feedback = ReticleFeedback()
    try check(feedback.state(eligible: false, duplicate: nil, now: 1) == .unavailable, "Empty reticle was not grey")
    try check(feedback.state(eligible: true, duplicate: nil, now: 1) == .eligible, "Eligible reticle was not green")
    feedback.assigned(now: 2)
    try check(feedback.state(eligible: false, duplicate: "1:climber", now: 2.05) == .assigned, "Successful assignment did not pulse")
    try check(feedback.state(eligible: false, duplicate: "1:climber", now: 2.11) == .alreadyAssigned, "Already assigned target did not show orange")
    try check(feedback.state(eligible: false, duplicate: "1:climber", now: 2.20) == .unavailable, "Orange cue lingered")
    try check(feedback.state(eligible: true, duplicate: "1:climber", now: 2.21) == .eligible, "Orange cue obscured an eligible neighbour")
    let point = CGPoint(x: 40, y: 43)
    let before = session.simulation.snapshot()
    try check(view.lemming(at: point)?.id == ids[0], "Pointer did not choose the nearest eligible lemming")
    try check(session.simulation.snapshot() == before && session.recovery.inputs.isEmpty,
        "Hover eligibility mutated simulation or replay history")
    try check(session.assign(skillIndex: skill, to: ids[0]) == nil, "Target fixture could not assign the first climber")
    try check(session.assignmentState(skillIndex: skill, to: ids[0]) == .alreadyAssigned,
        "An existing permanent skill was not distinguished from an invalid assignment")
    try check(view.lemming(at: point)?.id == ids[1], "An ineligible overlapping lemming blocked an eligible neighbour")
    try check(view.lemming(at: CGPoint(x: 50, y: 43))?.id == ids[1], "Sprite-edge allowance was not applied")
    try check(view.lemming(at: CGPoint(x: 65, y: 43)) == nil, "Pointer reached a distant lemming")
    var assigned: Int?
    view.onAssign = { id in
        if session.assign(skillIndex: skill, to: id) == nil { assigned = id }
    }
    view.handleClick(at: view.viewport.viewPoint(fromLevel: point))
    try check(assigned == ids[1] && view.lemming(at: point) == nil,
        "Green target did not assign, or empty supply still offered a target")

    let moving = NeoLemmixSession(simulation: simulation, width: 128, height: 96)
    view.session = moving
    view.onAssign = { id in
        if moving.assign(skillIndex: skill, to: id) == nil { assigned = id }
    }
    view.handleMove(to: view.viewport.viewPoint(fromLevel: point))
    let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
    view.cacheDisplay(in: view.bounds, to: bitmap)
    for _ in 0..<8 { moving.tick() }
    try check(view.clickTarget(at: point)?.id == ids[0], "Click lost the recently displayed green target while it moved")
    assigned = nil
    view.handleClick(at: view.viewport.viewPoint(fromLevel: point))
    try check(assigned == ids[0], "Moving green target was not assigned on click")
    view.didAssign(to: ids[0])
    view.cacheDisplay(in: view.bounds, to: bitmap)
    try check(view.hdrFlashes.contains { $0.tint == .green }, "Assignment pulse did not reach the HDR compositor")
    view.reduceFlashes = true
    view.cacheDisplay(in: view.bounds, to: bitmap)
    try check(view.hdrFlashes.allSatisfy { $0.tint != .green }, "Reduced flashes still emitted an HDR assignment pulse")

    try check(GameMenuArtwork.renderer() != nil, "Bundled menu artwork font is missing")
    let menu = PlayfieldView(frame: CGRect(x: 0, y: 0, width: 1000, height: 720))
    menu.interfaceArtwork = nil
    menu.phase = .briefing
    menu.overlayTitle = "LEMMINGS"
    menu.overlayLines = ["LEMMINGS 1/120", "FULL QUEST"]
    menu.overlayHighlight = 0
    let menuBitmap = menu.bitmapImageRepForCachingDisplay(in: menu.bounds)!
    menu.cacheDisplay(in: menu.bounds, to: menuBitmap)
    var bluePixels = 0
    for y in stride(from: 0, to: menuBitmap.pixelsHigh, by: 4) {
      for x in stride(from: 0, to: menuBitmap.pixelsWide, by: 4) {
        if let color = menuBitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
           color.blueComponent > 0.25, color.blueComponent > color.greenComponent * 1.3,
           color.blueComponent > color.redComponent * 1.3 { bluePixels += 1 }
      }
    }
    try check(bluePixels > 30, "Game selection menu fell back to plain lettering without level artwork")
    let captures = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent(".build/ui-font-check")
    try FileManager.default.createDirectory(at: captures, withIntermediateDirectories: true)
    try menuBitmap.representation(using: .png, properties: [:])!.write(
        to: captures.appendingPathComponent("menu-without-level-artwork.png"))


    let floor = Data((0..<(128 * 96)).map { UInt8($0 / 128 >= 48 ? 1 : 0) })
    let classicTerrain = try ClassicDOSTerrain(width: 128, height: 96, solidMask: floor, steelMask: Data(repeating: 0, count: 128 * 96))
    let classicConfig = ClassicDOSConfiguration(totalLemmings: 1, requiredToSave: 1, timeLimitTicks: nil,
        initialReleaseRate: 99, entrances: [.init(x: 40, y: 20)], initialSkills: [.climber: 1], maximumX: 127, maximumY: 95)
    let classic = ClassicSession(simulation: try ClassicDOSSimulation(terrain: classicTerrain, configuration: classicConfig), width: 128, height: 96)
    for _ in 0..<100 where classic.lemmings.isEmpty { classic.tick() }
    let climber = ClassicSkill.allCases.firstIndex(of: .climber)!
    let id = classic.lemmings.first!.id
    let hash = ClassicDOSReplayRecorder.stateHash(of: classic.simulation)
    try check(classic.canAssign(skillIndex: climber, to: id), "Classic eligibility rejected a valid climber")
    try check(ClassicDOSReplayRecorder.stateHash(of: classic.simulation) == hash && classic.recoveryEvents.isEmpty,
        "Classic hover eligibility changed the run")
    try check(classic.assign(skillIndex: climber, to: id) == nil && !classic.canAssign(skillIndex: climber, to: id),
        "Classic hover eligibility did not follow actual assignment rules")
    print("PASS nearest eligible targeting, overlap, edge allowance, moving green target, exhausted skills and mutation-free Classic/fan probes")
}

let testApp = NSApplication.shared
guard let testDomain = Bundle.main.bundleIdentifier,
  testDomain.hasPrefix("academy.glasscode.lemmings.integration-tests") else { exit(2) }
UserDefaults.standard.removePersistentDomain(forName: testDomain)
testApp.setActivationPolicy(.accessory)
Task { @MainActor in
  do {
    let subject = AppDelegate()
    subject.prepareArcadeTests()
    try subject.testSteppedCompletion()
    try subject.testFirstLaunchEffects()
    try await subject.testAccessibleMenusAndHelp()
    try testPointerAssignment()
    #if PERFORMANCE_TESTS
    try await subject.testReleasePerformance()
    #elseif HOT_SEAT_TESTS
    try subject.testHotSeatBoundaries()
    try subject.testHandoverPreviousLevel()
    try subject.testRunRecovery()
    try subject.testFanRunRecovery()
    try subject.testEscapeToMainMenu()
    print("Hot Seat boundary integration tests passed.")
    #elseif CONTROLLER_QOL_TESTS
    try await subject.testControllerQoL()
    try subject.testVariableSpeedInput()
    try await subject.testLevelHints()
    try subject.testControllerRemapping()
    try subject.testNeoRunRecovery()
    try subject.testRunRecovery()
    try subject.testFanRunRecovery()
    try subject.testEscapeToMainMenu()
    try subject.testInterruptionPolicy()
    print("Controller QoL integration tests passed.")
    #elseif RELEASE_BLOCKER_TESTS
    try subject.testControllerRemapping()
    try subject.testNeoRunRecovery()
    try subject.testRunRecovery()
    try subject.testFanRunRecovery()
    try subject.testEscapeToMainMenu()
    print("Release blocker integration tests passed.")
    #elseif HINT_TESTS
    try await subject.testLevelHints()
    try await subject.testHintsFromControlsHelp()
    print("Level hints integration tests passed.")
    #elseif VARIABLE_SPEED_TESTS
    try subject.testVariableSpeedInput()
    try subject.testVariableSimulationClock()
    try subject.testSuperSpeedPresentation()
    try subject.testMenuDisplayTransition()
    try await subject.testCRTInput()
    print("Variable speed integration tests passed.")
    #elseif HD_EFFECTS_TESTS
    try subject.testSuperSpeedPresentation()
    print("HD effects integration tests passed.")
    #else
    try subject.testMusicTransitions()
    try subject.testSavedAudioAndBanks()
    try subject.testGlobalMuteAndStop()
    try subject.testMenuDisplayTransition()
    try await subject.testCRTInput()
    try await subject.testInterruptedFade()
    try await subject.testElapsedTimeAndAudioRecovery()
    try subject.testGamePages()
    try subject.testRestartSelection()
    try subject.testBundledRescueTarget()
    try subject.testPortArtworkSwitching()
    try subject.testSuperSpeedPresentation()
    try await subject.testControllerQoL()
    try subject.testVariableSpeedInput()
    try subject.testVariableSimulationClock()
    try await subject.testLevelHints()
    try await subject.testHintsFromControlsHelp()
    try subject.testControllerRemapping()
    try subject.testNeoRunRecovery()
    try subject.testRunRecovery()
    try subject.testFanRunRecovery()
    try subject.testEscapeToMainMenu()
    try subject.testInterruptionPolicy()
    try subject.testHotSeatBoundaries()
    try subject.testHandoverPreviousLevel()
    try subject.testSeasonalMusic()
    print("App integration tests passed.")
    #endif
    exit(0)
  } catch {
    print("FAIL \(error)")
    exit(1)
  }
}
testApp.run()
