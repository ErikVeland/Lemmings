func checkGameplayQuickControl(_ value: Bool, _ message: String) throws {
  if !value { throw NSError(domain: "GameplayQuickControls", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
}

@MainActor func validateGameplayQuickControls(_ keyboard: GameplayKeyboard, owner: NSWindow, name: String) throws {
  GameScreen.shared.dismissAll()
  let oldFade = keyboard.fadeMenuButton, oldAvailable = keyboard.graphicsAvailable
  defer {
    GameScreen.shared.dismissAll(); keyboard.bind(to: owner)
    keyboard.fadeMenuButton = oldFade; keyboard.graphicsAvailable = oldAvailable
    keyboard.refreshNavigationControl()
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
    let expected = 3 + (keyboard.inspectionAvailable() && keyboard.inspectLemmings != nil ? 1 : 0)
      + (keyboard.extraSkill != nil && keyboard.modern() ? 1 : 0) + (ArcadeStore.shared.hotSeatIsActive ? 1 : 0)
    try check(buttons.count == expected, name + " omitted gameplay quick controls")
    let navigation = keyboard.navigationFrame(in: root)!
    for button in buttons {
      try check(root.bounds.contains(button.frame) && button.frame.width >= 44 && button.frame.height >= 44,
        name + " clipped a quick control")
      let top = root.isFlipped ? button.frame.minY : root.bounds.maxY - button.frame.maxY
      try check(top >= 64, name + " quick controls covered the top status text")
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
    buttons.forEach { $0.resetAppearance() }
    keyboard.refreshNavigationControl(at: 100); keyboard.refreshNavigationControl(at: 104)
    try shot(root, "faded-\(width)")
    for button in buttons {
      try check(button.artworkOpacity == (button.title == L10n.text("Inspect") ? 1 : 0), name + " quick control failed to follow its fade policy")
      let point = CGPoint(x: button.frame.midX, y: button.frame.midY)
      try check(root.hitTest(root.convert(point, to: root.superview)) === button, name + " faded quick control lost input")
      let hover = NSEvent.enterExitEvent(with: .mouseEntered, location: point, modifierFlags: [], timestamp: 104,
        windowNumber: owner.windowNumber, context: nil, eventNumber: 0, trackingNumber: 0, userData: nil)!
      button.mouseEntered(with: hover)
      try check(button.artworkOpacity == 1, name + " hover did not reveal a quick control")
      owner.makeFirstResponder(button)
      try check(button.artworkOpacity == 1, name + " focus did not reveal a quick control")
      try shot(root, "focused-\(button.title)-\(width)")
      owner.makeFirstResponder(nil); button.resetAppearance()
    }
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
  }
}
