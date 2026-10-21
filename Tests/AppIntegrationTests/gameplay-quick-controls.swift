func checkGameplayQuickControl(_ value: Bool, _ message: String) throws {
  if !value { throw NSError(domain: "GameplayQuickControls", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
}

@MainActor private final class QuickControlTestWindow: NSWindow {
  var pointer = CGPoint.zero
  override var isKeyWindow: Bool { true }
  override var mouseLocationOutsideOfEventStream: NSPoint { pointer }
}

@MainActor private final class QuickControlTestCanvas: NSView {
  var usesFlippedCoordinates = false
  var rewards: PrecisionZoomStatus?
  override var isFlipped: Bool { usesFlippedCoordinates }
  override func draw(_ dirtyRect: NSRect) {
    NSColor.black.setFill(); bounds.fill()
    rewards?.draw(at: CGPoint(x: 12, y: 12), scale: bounds.width >= 960 ? 2 : 1)
  }
}

@MainActor private func testQuickControlGroupHover() throws {
  let previous = ArcadeStore.shared
  let storage = try AppStorage.temporary(named: "quick-control-group")
  let store = ArcadeStore(storage: storage, bundledProofs: nil)
  ArcadeStore.shared = store
  defer { ArcadeStore.shared = previous; storage.removeTemporaryFiles() }
  _ = store.addProfile(initials: "TWO", portrait: 1, select: false)
  store.prepareHotSeat()
  let host = QuickControlTestWindow(contentRect: CGRect(x: 0, y: 0, width: 640, height: 620),
    styleMask: [], backing: .buffered, defer: false)
  let root = QuickControlTestCanvas(frame: host.contentView!.bounds)
  host.contentView = root
  let keyboard = GameplayKeyboard(window: host)
  defer { keyboard.removeNavigationControl() }
  keyboard.active = { true }; keyboard.modern = { true }; keyboard.ownsController = { true }
  keyboard.mainMenu = {}; keyboard.settings = {}; keyboard.nextGraphics = {}
  keyboard.navigationReduceMotion = { false }; keyboard.fadeMenuButton = { true }
  var uses = 0, balance: CGFloat = 1
  keyboard.extraSkill = { uses += 1 }; keyboard.extraSkillAvailable = { true }
  keyboard.extraSkillHelp = { "Bonus skill (⌘E)" }
  keyboard.navigationArtworkOpacityChanged = { balance = $0 }
  for flipped in [false, true] {
    root.usesFlippedCoordinates = flipped; host.pointer = root.convert(CGPoint(x: 20, y: 20), to: nil)
    keyboard.removeNavigationControl()
    keyboard.refreshNavigationControl(at: 100); keyboard.refreshNavigationControl(at: 104)
    let buttons = root.subviews.compactMap { $0 as? GameplayMenuButton }.filter { !$0.isHidden }
    try check(buttons.count == 5 && buttons.allSatisfy { $0.artworkOpacity == 0 } && balance == 0,
      "Five-control row and reward badges did not fade together")
    let sorted = buttons.sorted { $0.frame.minX < $1.frame.minX }
    let menu = sorted.last!
    try check(root.bounds.maxX - menu.frame.maxX == 12
      && (flipped ? menu.frame.minY - root.bounds.minY : root.bounds.maxY - menu.frame.maxY) == 12,
      "Control row did not anchor to the top-right corner")
    for (left, right) in zip(sorted, sorted.dropFirst()) {
      let gap = CGPoint(x: (left.frame.maxX + right.frame.minX) / 2, y: left.frame.midY)
      try check(keyboard.navigationFrame(in: root)!.contains(gap), "Control gap escaped playfield input exclusion")
      try check(root.hitTest(root.convert(gap, to: root.superview)) is GameplayMenuHitArea,
        "Control gap passed clicks through to the playfield")
      host.pointer = root.convert(gap, to: nil)
      keyboard.refreshNavigationControl(at: 105); keyboard.refreshNavigationControl(at: 105.09)
      try check(buttons.allSatisfy { abs($0.artworkOpacity - 0.5) < 0.01 } && abs(balance - 0.5) < 0.01,
        "Control gap did not fade in the row and badges together")
      keyboard.refreshNavigationControl(at: 110)
      try check(buttons.allSatisfy { $0.artworkOpacity == 1 } && balance == 1,
        "Control gap did not keep the whole group visible")
      host.pointer = root.convert(CGPoint(x: 20, y: 20), to: nil)
      keyboard.refreshNavigationControl(at: 114)
      try check(buttons.allSatisfy { $0.artworkOpacity == 0 } && balance == 0,
        "Control gap kept the group visible after exit")
    }
    let bonus = buttons.first { $0.glyph == .bonusSkill }!
    try check(bonus.accessibilityPerformPress() && uses == (flipped ? 2 : 1),
      "Faded Bonus skill icon did not perform its action")
    keyboard.extraSkillAvailable = { false }; keyboard.refreshNavigationControl()
    try check(!bonus.isEnabled && !bonus.accessibilityPerformPress(), "Spent Bonus skill remained actionable")
    keyboard.extraSkillAvailable = { true }
    keyboard.modern = { false }; keyboard.refreshNavigationControl()
    try check(bonus.isHidden, "Classic mode retained a Bonus skill input target")
    keyboard.modern = { true }
  }
  print("PASS five-icon group, every gap, shared badge fade, both coordinate systems and Bonus skill availability")
}

@MainActor func validateGameplayQuickControls(_ keyboard: GameplayKeyboard, owner: NSWindow, name: String,
  statusFrames: () -> [CGRect] = { [] }) throws {
  GameScreen.shared.dismissAll()
  let oldFade = keyboard.fadeMenuButton, oldAvailable = keyboard.graphicsAvailable
  let oldReduction = keyboard.navigationReduceMotion
  defer {
    GameScreen.shared.dismissAll(); keyboard.bind(to: owner)
    keyboard.fadeMenuButton = oldFade; keyboard.graphicsAvailable = oldAvailable
    keyboard.navigationReduceMotion = oldReduction
    keyboard.refreshNavigationControl()
  }
  func checkRow(_ buttons: [GameplayMenuButton], in root: NSView) throws {
    let sorted = buttons.sorted { $0.frame.minX < $1.frame.minX }
    try check(sorted.last?.title == L10n.text("Menu"), name + " Menu was not rightmost")
    let menu = sorted.last!
    try check(root.bounds.maxX - menu.frame.maxX == 12
      && (root.isFlipped ? menu.frame.minY - root.bounds.minY : root.bounds.maxY - menu.frame.maxY) == 12,
      name + " quick controls did not follow the top-right corner")
    let navigation = sorted.reduce(CGRect.null) { $0.union($1.frame) }
    for frame in statusFrames() {
      try check(root.bounds.contains(frame) && !navigation.intersects(frame),
        name + " status text or game-menu target was covered by the icon row")
    }
    for button in sorted {
      try check(root.bounds.contains(button.frame) && button.frame.size == CGSize(width: 44, height: 44)
        && button.frame.minY == sorted[0].frame.minY && button.glyph != nil,
        name + " quick controls did not form one row of icon tiles")
      try check(!(button.accessibilityLabel() ?? "").isEmpty && !button.helpText.isEmpty
        && button.accessibilityHelp() == button.helpText && button.toolTip == nil,
        name + " icon lost its accessible name or popover explanation")
    }
    for (left, right) in zip(sorted, sorted.dropFirst()) {
      let startsMenuGroup = right.glyph == .settings || (right.glyph == .menu && left.glyph != .settings)
      try check(right.frame.minX - left.frame.maxX == (startsMenuGroup ? 24 : 8),
        name + " quick controls lost their action/menu grouping")
    }
  }
  let folder = URL(fileURLWithPath: ".build/gameplay-quick-controls")
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  func shot(_ root: NSView, _ state: String) throws {
    root.layoutSubtreeIfNeeded()
    func invalidate(_ view: NSView) { view.needsDisplay = true; view.subviews.forEach(invalidate) }
    invalidate(root)
    let bitmap = root.bitmapImageRepForCachingDisplay(in: root.bounds)!
    root.displayIgnoringOpacity(root.bounds, in: NSGraphicsContext(bitmapImageRep: bitmap)!)
    try bitmap.representation(using: .png, properties: [:])!.write(
      to: folder.appendingPathComponent(name + "-" + state + ".png"))
  }
  for width in [640, 900, 1600] {
    owner.setContentSize(CGSize(width: width, height: width == 900 ? 620 : 1000))
    owner.contentView!.layoutSubtreeIfNeeded()
    keyboard.fadeMenuButton = { false }; keyboard.refreshNavigationControl(at: 100)
    let root = owner.contentView!
    let buttons = root.subviews.compactMap { $0 as? GameplayMenuButton }.filter { !$0.isHidden }
    let expected = 3
      + (keyboard.extraSkill != nil && keyboard.modern() ? 1 : 0) + (ArcadeStore.shared.hotSeatIsActive ? 1 : 0)
    try check(buttons.count == expected, name + " omitted gameplay quick controls")
    try checkRow(buttons, in: root)
    let navigation = keyboard.navigationFrame(in: root)!
    for button in buttons {
      try check(root.bounds.contains(button.frame) && button.frame.width >= 44 && button.frame.height >= 44,
        name + " clipped a quick control")
      let top = root.isFlipped ? button.frame.minY : root.bounds.maxY - button.frame.maxY
      try check(top == 12, name + " quick controls retained the old top offset")
      try check(navigation.contains(button.frame), name + " cursor exclusion omitted a quick control")
      for point in [CGPoint(x: button.frame.midX, y: button.frame.midY),
                    CGPoint(x: button.frame.minX + 1, y: button.frame.minY + 1)] {
        try check(root.hitTest(root.convert(point, to: root.superview)) === button, name + " lost a quick control target")
      }
      try check(!buttons.contains { $0 !== button && $0.frame.intersects(button.frame) }, name + " overlapped quick controls")
    }
    try shot(root, "visible-\(width)")
    let graphics = buttons.first { $0.title == L10n.text("Graphics") }!
    let settings = buttons.first { $0.title == L10n.text("Settings") }!
    let first = keyboard.graphicsName()
    graphics.performClick(nil)
    try check(keyboard.graphicsName() != first && graphics.accessibilityValue() as? String == keyboard.graphicsName(),
      name + " graphics button did not update artwork and accessibility")
    try shot(root, "cycled-\(width)")
    settings.performClick(nil)
    try check(GameScreen.shared.isPresented, name + " Settings button did not open settings")
    keyboard.refreshNavigationControl()
    try check(keyboard.navigationFrame(in: root) == nil, name + " quick controls remained active through settings")
    try shot(root, "settings-\(width)")
    GameScreen.shared.dismissAll(); keyboard.refreshNavigationControl(at: 100)
    keyboard.graphicsAvailable = { false }; keyboard.refreshNavigationControl(at: 100)
    let current = keyboard.graphicsName()
    graphics.performClick(nil)
    try check(!graphics.isEnabled && keyboard.graphicsName() == current, name + " unavailable graphics still changed")
    try shot(root, "unavailable-\(width)")
    keyboard.graphicsAvailable = oldAvailable
    keyboard.fadeMenuButton = { true }
    keyboard.navigationReduceMotion = { false }
    buttons.forEach { $0.resetAppearance() }
    keyboard.refreshNavigationControl(at: 100); keyboard.refreshNavigationControl(at: 103.3)
    try check(buttons.allSatisfy { abs($0.artworkOpacity - 0.5) < 0.01 }, name + " row did not fade together")
    try shot(root, "fading-\(width)")
    keyboard.refreshNavigationControl(at: 104)
    try shot(root, "faded-\(width)")
    for button in buttons {
      try check(buttons.allSatisfy { $0.artworkOpacity == 0 }, name + " quick controls did not fade together")
      let point = CGPoint(x: button.frame.midX, y: button.frame.midY)
      try check(root.hitTest(root.convert(point, to: root.superview)) === button, name + " faded quick control lost input")
      let hover = NSEvent.enterExitEvent(with: .mouseEntered, location: point, modifierFlags: [], timestamp: 104,
        windowNumber: owner.windowNumber, context: nil, eventNumber: 0, trackingNumber: 0, userData: nil)!
      button.mouseEntered(with: hover)
      keyboard.refreshNavigationControl(at: 104.09)
      try check(buttons.allSatisfy { abs($0.artworkOpacity - 0.5) < 0.01 }, name + " row did not fade in together")
      keyboard.refreshNavigationControl(at: 104.2)
      try check(buttons.allSatisfy { $0.artworkOpacity == 1 }, name + " hover did not reveal the whole row")
      let exit = NSEvent.enterExitEvent(with: .mouseExited, location: point, modifierFlags: [], timestamp: 105,
        windowNumber: owner.windowNumber, context: nil, eventNumber: 0, trackingNumber: 0, userData: nil)!
      button.mouseExited(with: exit); keyboard.refreshNavigationControl(at: 109)
      try check(buttons.allSatisfy { $0.artworkOpacity == 0 }, name + " row stayed visible after hover")
      if button.isEnabled {
        try check(owner.makeFirstResponder(button), name + " enabled icon rejected keyboard focus")
        keyboard.refreshNavigationControl(at: ProcessInfo.processInfo.systemUptime + 0.2)
        try check(buttons.allSatisfy { $0.artworkOpacity == 1 }, name + " focus did not reveal the whole row")
      }
      try shot(root, "focused-\(button.title)-\(width)")
      owner.makeFirstResponder(nil); buttons.forEach { $0.resetAppearance() }
      keyboard.refreshNavigationControl(at: 100); keyboard.refreshNavigationControl(at: 104)
    }
    keyboard.navigationReduceMotion = { true }
    buttons.forEach { $0.resetAppearance() }
    keyboard.refreshNavigationControl(at: 200); keyboard.refreshNavigationControl(at: 203)
    try check(buttons.allSatisfy { $0.artworkOpacity == 0 }, name + " reduced motion did not hide the row together")
    keyboard.revealRewards(at: 204); keyboard.refreshNavigationControl(at: 204)
    try check(buttons.allSatisfy { $0.artworkOpacity == 1 }, name + " reduced motion animated the row reveal")
    keyboard.navigationReduceMotion = oldReduction

    let store = ArcadeStore.shared
    if store.records.profiles.count < 2 { _ = store.addProfile(initials: "TWO", portrait: 1, select: false) }
    store.prepareHotSeat()
    keyboard.fadeMenuButton = { false }; keyboard.refreshNavigationControl()
    let hotSeatButtons = root.subviews.compactMap { $0 as? GameplayMenuButton }.filter { !$0.isHidden }
    try checkRow(hotSeatButtons, in: root)
    let ghosts = hotSeatButtons.first { $0.glyph == .ghosts || $0.glyph == .ghostsHidden }!
    for visible in [true, false] {
      store.hotSeatGhostsVisible = visible; keyboard.refreshNavigationControl()
      try check(ghosts.glyph == (visible ? .ghosts : .ghostsHidden)
        && ghosts.state == (visible ? .on : .off) && ghosts.accessibilityValue() as? Int == (visible ? 1 : 0),
        name + " ghost icon and accessible state disagreed")
      try check(root.hitTest(root.convert(CGPoint(x: ghosts.frame.midX, y: ghosts.frame.midY), to: root.superview)) === ghosts,
        name + " ghost icon lost its input target")
      try shot(root, "ghosts-\(visible)-\(width)")
      try check(ghosts.accessibilityPerformPress() && store.hotSeatGhostsVisible != visible,
        name + " accessible ghost icon did not toggle")
    }
    store.endHotSeat(); keyboard.refreshNavigationControl()
  }
  let host = SpeedTestWindow(contentRect: CGRect(x: 0, y: 0, width: 900, height: 620), styleMask: [], backing: .buffered, defer: false)
  keyboard.bind(to: host)
  func event(_ key: String, code: UInt16, modifiers: NSEvent.ModifierFlags = [], repeated: Bool = false) -> NSEvent {
    NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: 1,
      windowNumber: host.windowNumber, context: nil, characters: key, charactersIgnoringModifiers: key,
      isARepeat: repeated, keyCode: code)!
  }
  let first = keyboard.graphicsName()
  let f2 = "\u{f705}"
  try check(keyboard.handle(event(f2, code: 120)) == nil && keyboard.graphicsName() != first, name + " F2 failed")
  let current = keyboard.graphicsName()
  _ = keyboard.handle(event(f2, code: 120, repeated: true))
  try check(keyboard.graphicsName() == current, name + " repeated F2 cycled graphics")
  try check(keyboard.handle(event(f2, code: 120, modifiers: [.command])) != nil && keyboard.graphicsName() == current,
    name + " stole a modified F2 shortcut")
  keyboard.graphicsAvailable = { false }
  _ = keyboard.handle(event(f2, code: 120))
  try check(keyboard.graphicsName() == current, name + " unavailable F2 changed graphics")
  keyboard.graphicsAvailable = oldAvailable
  try check(keyboard.handle(event(",", code: 43, modifiers: [.command])) == nil && GameScreen.shared.isPresented,
    name + " Command-comma failed to open Settings")
  try check(keyboard.handle(event(f2, code: 120)) != nil && keyboard.graphicsName() == current,
    name + " F2 passed through Settings")
  GameScreen.shared.dismissAll()
  let text = NSTextView(frame: host.contentView!.bounds); host.contentView!.addSubview(text); host.makeFirstResponder(text)
  try check(keyboard.handle(event(f2, code: 120)) != nil, name + " stole text input")
  host.makeFirstResponder(nil)
  let oldOwnership = keyboard.ownsController
  keyboard.ownsController = { false }
  try check(keyboard.handle(event(f2, code: 120)) != nil && keyboard.handle(event(",", code: 43, modifiers: [.command])) != nil,
    name + " inactive engine consumed shortcuts")
  keyboard.ownsController = oldOwnership
  try check(keyboard.commandRows.contains { $0.keys == "F2" } && keyboard.commandRows.contains { $0.keys == "⌘," },
    name + " omitted shortcut help")
  print("PASS " + name + " Settings/graphics buttons, F2/Command-comma, renders, targets, fade/hover/focus, unavailable/text/menu/ownership guards")
}

extension AppDelegate {
  fileprivate func testGameplayQuickControls() throws {
    try testQuickControlGroupHover()
    if window == nil { buildInterface() }
    GameScreen.shared.dismissAll(); loadContent()
    settings.music = .silent; settings.sound = .silent
    guard let index = dataSets.firstIndex(where: { $0.set.title == .lemmings }) else {
      throw IntegrationFailure(message: "Missing Classic test content")
    }
    gamePicker.selectItem(at: index); selectDataSet(); loadLevel(at: 0)
    flow?.selectLevel(rank: 0, position: 0); flow?.beginPlaying(); renderScreen(); installKeyboardShortcuts()
    isPaused = true
    let priorSettings = settings, priorLevelGraphics = levelGraphics
    let priorSequelArtwork = SequelArtworkPreference.enabled
    defer {
      GameScreen.shared.dismissAll(); returnToLibrary()
      apply(priorSettings); levelGraphics = priorLevelGraphics
      SequelArtworkPreference.setEnabled(priorSequelArtwork)
    }
    let before = session!.currentTick
    try validateGameplayQuickControls(gameplayKeyboard!, owner: window, name: "classic")
    try check(session!.currentTick == before && isPaused, "Classic quick controls advanced or resumed the run")
    // A shuffled source can differ from the stored preference. Cycle from the visible source.
    let choices = gameplayGraphics
    try check(choices.count >= 3, "Classic cycle fixture needs three installed artwork sources")
    settings.graphics = choices[1]; settings.shuffleGraphics = true; levelGraphics = choices[0]
    cycleGameplayGraphics()
    try check(activeGraphics == choices[1] && levelGraphics == nil && settings.shuffleGraphics,
      "Cycling shuffled artwork did not apply the next visible source")
    for _ in choices { cycleGameplayGraphics() }
    try check(activeGraphics == choices[1], "Classic graphics cycle did not wrap")
    try check(openNativeL2(selection: .init(tribe: 0, level: 0)), "L2 quick controls fixture did not open")
    try nativeL2Window!.testGameplayQuickControls()
    returnToLibrary()
    try check(openNativeL3(selection: .init(tribe: .classic, level: 0)), "L3 quick controls fixture did not open")
    try nativeL3Window!.testGameplayQuickControls()
    try testGameplayIconHelp()
  }
}

@MainActor private func testGameplayIconHelp() throws {
  let previous = ArcadeStore.shared
  let storage = try AppStorage.temporary(named: "gameplay-icon-help")
  ArcadeStore.shared = ArcadeStore(storage: storage, bundledProofs: nil)
  defer { ArcadeStore.shared = previous; storage.removeTemporaryFiles() }
  _ = ArcadeStore.shared.addProfile(initials: "TWO", portrait: 1, select: false)
  ArcadeStore.shared.prepareHotSeat()
  let host = QuickControlTestWindow(contentRect: CGRect(x: 0, y: 0, width: 640, height: 620),
    styleMask: [], backing: .buffered, defer: false)
  let root = QuickControlTestCanvas(frame: host.contentView!.bounds)
  root.usesFlippedCoordinates = true; host.contentView = root
  let keyboard = GameplayKeyboard(window: host)
  defer { keyboard.removeNavigationControl() }
  keyboard.active = { true }; keyboard.modern = { true }; keyboard.ownsController = { true }
  keyboard.mainMenu = {}; keyboard.settings = {}; keyboard.nextGraphics = {}
  keyboard.graphicsName = { "Original PC" }; keyboard.navigationReduceMotion = { false }
  var status = PrecisionZoomStatus(superzoom: 12, skips: 4, extraSkills: 2, active: .superzoom, isEmpty: false)
  keyboard.extraSkill = {}; keyboard.extraSkillAvailable = { status.extraSkills > 0 && !status.bonusSkillUsed }
  keyboard.extraSkillTitle = { L10n.text("Bonus skill (\(status.extraSkills))") }
  keyboard.extraSkillHelp = { L10n.text("Choose one extra use of a level skill. One per attempt. (⌘E)") }
  keyboard.rewardStatus = { status }
  keyboard.rewardDisplayArea = {
    CGRect(origin: CGPoint(x: 12, y: 12), size: status.size(scale: root.bounds.width >= 960 ? 2 : 1))
  }
  let folder = URL(fileURLWithPath: ".build/gameplay-icon-help")
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  func shot(_ name: String) throws {
    root.rewards = status; root.needsDisplay = true; root.layoutSubtreeIfNeeded()
    let bitmap = root.bitmapImageRepForCachingDisplay(in: root.bounds)!
    root.displayIgnoringOpacity(root.bounds, in: NSGraphicsContext(bitmapImageRep: bitmap)!)
    try bitmap.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent(name + ".png"))
  }
  func panel() -> GameSettingsHelpPanel? { root.subviews.compactMap { $0 as? GameSettingsHelpPanel }.first }
  for width in [640, 900, 1600] {
    host.setContentSize(CGSize(width: width, height: width == 900 ? 620 : 1000))
    status = .init(superzoom: 12, skips: 4, extraSkills: 2, active: .superzoom, isEmpty: false)
    host.pointer = root.convert(CGPoint(x: 2, y: 2), to: nil)
    keyboard.removeNavigationControl(); keyboard.refreshNavigationControl(at: 100)
    let buttons = root.subviews.compactMap { $0 as? GameplayMenuButton }.filter { !$0.isHidden }
    var items = buttons.map { ($0.glyph!.rawValue, $0.title, $0.frame) }
    let area = keyboard.rewardDisplayArea()!
    for item in status.badgeFrames(scale: width >= 960 ? 2 : 1) {
      items.append(("counter-" + item.badge.rawValue, item.badge.title,
        item.frame.offsetBy(dx: area.minX, dy: area.minY)))
    }
    for (index, item) in items.enumerated() {
      let now = 110 + Double(index) * 4
      let point = CGPoint(x: item.2.midX, y: item.2.midY)
      host.pointer = root.convert(point, to: nil)
      let responder = host.firstResponder
      keyboard.refreshNavigationControl(at: now)
      try check(panel() == nil, "Icon popover appeared before its hover delay")
      keyboard.refreshNavigationControl(at: now + 0.81)
      guard let help = panel() else { throw IntegrationFailure(message: "Missing popover for " + item.0) }
      try check(help.accessibilityLabel() == item.1 && !(help.accessibilityHelp() ?? "").isEmpty
        && root.bounds.contains(help.frame) && host.firstResponder === responder,
        "Icon popover lost its name, explanation, bounds or keyboard focus")
      if help.accessibilityHelp()?.contains("⌘") == true {
        let text = help.subviews.compactMap { ($0 as? GameLabel)?.stringValue }.joined(separator: " ")
        try check(text.contains("Cmd-") && !text.contains("⌘"), "Popover shortcut cannot be drawn by the bitmap font")
      }
      let helpPoint = root.convert(CGPoint(x: help.frame.midX, y: help.frame.midY), to: root.superview)
      let hit = root.hitTest(helpPoint)
      try check(hit !== help && hit?.isDescendant(of: help) != true, "Icon popover intercepted gameplay input")
      try shot(item.0 + "-" + String(width))
      if item.0 == "graphics" {
        let graphics = buttons.first { $0.glyph == .graphics }!
        try check(graphics.accessibilityPerformPress(), "Explained Graphics icon lost its action")
        keyboard.refreshNavigationControl(at: now + 0.9)
        try check(panel() == nil, "Icon explanation survived an accessible action")
      }
      host.pointer = root.convert(CGPoint(x: 2, y: 2), to: nil)
      keyboard.refreshNavigationControl(at: now + 1)
      try check(panel() == nil, "Icon popover survived hover exit")
    }
    let settings = buttons.first { $0.glyph == .settings }!
    host.makeFirstResponder(settings); keyboard.refreshNavigationControl(at: 200)
    try check(panel()?.accessibilityLabel() == settings.title && host.firstResponder === settings,
      "Keyboard focus did not explain the icon without moving focus")
    try shot("keyboard-focus-" + String(width))
    NotificationCenter.default.post(name: NSWindow.didResignKeyNotification, object: host)
    try check(panel() == nil, "Icon explanation survived focus loss")
    host.makeFirstResponder(nil)
    keyboard.playingTrack = { PlayingTrack(url: URL(fileURLWithPath: "/fixture/song.mod"),
      title: "Test song", soundtrack: "Lemmings - Amiga") }
    keyboard.refreshNavigationControl(at: 205); keyboard.refreshNavigationControl(at: 205.35)
    let notice = root.subviews.compactMap { $0 as? NowPlayingNotice }.first!
    try check(!notice.isHidden && !notice.frame.intersects(keyboard.rewardDisplayArea()!),
      "The reward icon row covered the song notice")
    try shot("song-notice-" + String(width))
    keyboard.playingTrack = { nil }
    status.extraSkills = 0; status.bonusSkillUsed = true
    let bonus = buttons.first { $0.glyph == .bonusSkill }!
    host.pointer = root.convert(CGPoint(x: bonus.frame.midX, y: bonus.frame.midY), to: nil)
    keyboard.refreshNavigationControl(at: 210); keyboard.refreshNavigationControl(at: 211)
    try check(!bonus.isEnabled && panel()?.accessibilityHelp() == bonus.helpText,
      "Disabled Bonus skill lost its explanation")
    try shot("bonus-used-" + String(width))
    keyboard.navigationAvailable = { false }; keyboard.refreshNavigationControl(at: 212)
    try check(panel() == nil, "Leaving gameplay retained an icon popover")
    keyboard.navigationAvailable = { true }
    for count in [0, 4, 123, 9999] {
      status = .init(superzoom: count, skips: count, extraSkills: count, isEmpty: false)
      try check(status.size(scale: width >= 960 ? 2 : 1).width < CGFloat(width) - 24,
        "Reward icon counts escaped the game canvas")
      keyboard.refreshNavigationControl(at: 220)
      try shot("counts-\(count)-\(width)")
    }
  }
  print("PASS all five control and three reward popovers, hover delay/exit, keyboard focus, disabled help, passive input, counts 0–9999 and three sizes")
}
