#if os(macOS)
import AppKit
import LemmingsAppCore
import NxlvKit

/// Settings stay inside the game. Language choices preview without changing the active game.
@MainActor final class SettingsWindow: NSObject {
  private var page: GameMenuPage?
  private let help = GameSettingsHelp()
  private var options: ClassicSettingsOptions
  private var settings: ClassicSettings
  private let telemetry: AnonymousTelemetry

  /// Called when profile settings change, so the game can follow immediately.
  var onChange: ((ClassicSettings) -> Void)?

  private var presetPopUp: NSPopUpButton?
  private var experiencePopUp: NSPopUpButton?
  private var graphicsPopUp: NSPopUpButton?
  private var counterStylePopUp: NSPopUpButton?
  private var depthPopUp: NSPopUpButton?
  private var displayPopUp: NSPopUpButton?
  private var intensitySlider: NSSlider?
  private var aspectSlider: NSSlider?
  private var tubeCaptions: [GameLabel] = []
  private var integerCheck: NSButton?
  private var musicPopUp: NSPopUpButton?
  private var stylePopUp: NSPopUpButton?
  private var musicSlider: NSSlider?
  private var soundPopUp: NSPopUpButton?
  private var soundSlider: NSSlider?
  private var graphicsShuffleCheck: NSButton?
  private var musicShuffleCheck: NSButton?
  private var pauseBeatCheck: NSButton?
  private var menuMusicCheck: NSButton?
  private var sequelArtworkCheck: NSButton?
  private var pointerCaptureCheck: NSButton?
  private var modernControlsCheck: NSButton?
  private var variableSpeedCheck: NSButton?
  private var ridiculousSpeedCheck: NSButton?
  private var interruptionCheck: NSButton?
  private var cursorStylePopUp: NSPopUpButton?
  private var skillBackpacksCheck: NSButton?
  private var reticleCountCheck: NSButton?
  private var skillCursorSizePopUp: NSPopUpButton?
  private var selectionStylePopUp: NSPopUpButton?
  private var favorApproachingCheck: NSButton?
  private var favorBombBlockersCheck: NSButton?
  private var favorBuildersCheck: NSButton?
  private var levelSelectionPopUp: NSPopUpButton?
  private var controllerCheck: NSButton?
  private var djShuffleScopePopUp: NSPopUpButton?
  private var controllerTapCheck: NSButton?
  private var controllerSwapCheck: NSButton?
  private var controllerRemapButton: NSButton?
  private var controllerHelpText: NSTextView?
  private var remapSource: NSPopUpButton?
  private var remapRole: NSPopUpButton?
  private var interfaceSizePopUp: NSPopUpButton?
  private var languagePopUp: NSPopUpButton?
  private var languagePage: GameMenuPage?
  private var languageEntryPreference: InterfaceLanguage?
  private var reduceMotionCheck: NSButton?
  private var staticHomeScreenCheck: NSButton?
  private var reduceFlashesCheck: NSButton?
  private var showSongInfoCheck: NSButton?
  private var fadeMenuButtonCheck: NSButton?
  private var hdEffectsCheck: NSButton?
  private var hdrFlashCheck: NSButton?
  private var djSoundtracksCheck: NSButton?
  private var telemetryCheck: NSButton?
  private var restoreCountsButton: NSButton?

  /// Whether the tube simulation is in the live drawing path.
  var videoIsConnected = true { didSet { refreshVideoControls() } }

  init(settings: ClassicSettings, options: ClassicSettingsOptions,
       telemetry: AnonymousTelemetry = .shared) {
    self.settings = options.correcting(settings)
    self.options = options
    self.telemetry = telemetry
    super.init()
    NotificationCenter.default.addObserver(self, selector: #selector(refreshSequelArtwork),
                                          name: SequelArtworkPreference.changed, object: nil)
  }

  /// Replaces the options after a game is added or removed.
  func update(options newOptions: ClassicSettingsOptions, settings latest: ClassicSettings? = nil) {
    options = newOptions
    settings = newOptions.correcting(latest ?? settings)
    guard page != nil else { return }
    rebuildSources()
    onChange?(settings)
  }

  var current: ClassicSettings { settings }

  // MARK: - Presenting

  func show() {
    if let page, GameScreen.shared.contains(page) { GameScreen.shared.present(page); return }
    let page = makeSettingsPage()
    self.page = page
    rebuildSources()
    GameScreen.shared.present(page, onDismiss: { [weak self] in self?.help.dismiss() })
  }

  private func makeSettingsPage() -> GameMenuPage {
    help.reset()
    let page = GameMenuPage(title: L10n.text("Settings"))
    page.onBack = { [weak self, weak page] in
      self?.help.dismiss()
      if let page { GameScreen.shared.dismiss(page) }
    }
    let tabs = GameTabs()
    tabs.onSelectionChanged = { [weak self] in self?.help.dismiss() }
    tabs.addTabViewItem(tab(L10n.text("Gameplay"), gameplayPane()))
    tabs.addTabViewItem(tab(L10n.text("Controller"), controllerPane()))
    tabs.addTabViewItem(tab(L10n.text("Graphics"), graphicsPane()))
    tabs.addTabViewItem(tab(L10n.text("Video"), videoPane()))
    tabs.addTabViewItem(tab(L10n.text("Audio"), audioPane()))
    tabs.addTabViewItem(tab(L10n.text("Accessibility"), accessibilityPane()))
    tabs.addTabViewItem(tab(L10n.text("Privacy"), privacyPane()))
    tabs.translatesAutoresizingMaskIntoConstraints = false
    page.body.addSubview(tabs)
    NSLayoutConstraint.activate([
      tabs.topAnchor.constraint(equalTo: page.body.topAnchor),
      tabs.bottomAnchor.constraint(equalTo: page.body.bottomAnchor),
      tabs.leadingAnchor.constraint(equalTo: page.body.leadingAnchor),
      tabs.trailingAnchor.constraint(equalTo: page.body.trailingAnchor)
    ])
    return page
  }

  private func tab(_ label: String, _ view: NSView) -> NSTabViewItem {
    let item = NSTabViewItem(identifier: label)
    item.label = label
    item.view = view
    return item
  }

  // MARK: - Building panes

  /// Lays out labelled rows down a pane.
  private func groupedPane(_ sections: [(String, [(String, NSView)])]) -> NSView {
    pane(sections.flatMap { title, rows -> [(String, NSView)] in
      if title.isEmpty { return rows }
      let heading = GameLabel(labelWithString: title)
      heading.role = .heading
      heading.alignment = .left
      heading.setAccessibilityLabel(title)
      return [("", heading as NSView)] + rows
    }, spacing: 4, topInset: 12)
  }

  private func pane(_ rows: [(String, NSView)], spacing: CGFloat = 8, topInset: CGFloat = 16) -> NSView {
    let scroll = GameSettingsScrollView()
    scroll.hasVerticalScroller = true
    scroll.scrollerStyle = .overlay
    scroll.drawsBackground = false
    scroll.onScroll = { [weak self] in self?.help.dismiss() }
    let container = GameSettingsDocument()
    container.frame = CGRect(x: 0, y: 0, width: 992, height: 438)
    scroll.documentView = container
    var previous: NSView?
    for (label, control) in rows {
      let caption = GameLabel(labelWithString: label)
      if control === intensitySlider || control === aspectSlider { tubeCaptions.append(caption) }
      if control.accessibilityLabel() == nil {
        control.setAccessibilityLabel((control as? NSButton).map { label + ": " + $0.title } ?? label)
      }
      caption.alignment = .right
      caption.translatesAutoresizingMaskIntoConstraints = false
      control.translatesAutoresizingMaskIntoConstraints = false
      container.addSubview(caption)
      container.addSubview(control)
      installHelp(for: control, caption: caption)
      let heading = (control as? GameLabel)?.role == .heading
      if heading { control.heightAnchor.constraint(equalToConstant: 20).isActive = true }
      else { control.heightAnchor.constraint(greaterThanOrEqualToConstant: 28).isActive = true }

      NSLayoutConstraint.activate([
        caption.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 18),
        caption.widthAnchor.constraint(equalToConstant: 180),
        caption.centerYAnchor.constraint(equalTo: (control as? GameControlGroup)?.arrangedSubviews.first?.centerYAnchor ?? control.centerYAnchor),
        control.leadingAnchor.constraint(equalTo: caption.trailingAnchor, constant: 12),
        control.trailingAnchor.constraint(
          equalTo: container.trailingAnchor, constant: -18),
        control.topAnchor.constraint(
          equalTo: previous?.bottomAnchor ?? container.topAnchor,
          constant: previous == nil ? topInset : heading || (control is GameButton && !(control is GameCheckButton)) ? 12 : spacing),
      ])
      previous = control
    }
    previous?.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -8).isActive = true
    return scroll
  }

  private func installHelp(for view: NSView, caption: GameLabel? = nil) {
    if let group = view as? GameControlGroup {
      group.arrangedSubviews.forEach { installHelp(for: $0) }
    }
    guard let control = view as? NSControl, let action = control.action,
          let text = settingHelp[NSStringFromSelector(action)] else { return }
    let title = control.accessibilityLabel() ?? (control as? NSButton)?.title ?? caption?.stringValue ?? L10n.text("Settings")
    help.attach(text, to: control, title: title)
    if let caption, !caption.stringValue.isEmpty { help.attach(text, to: caption, title: title) }
  }

  private var settingHelp: [String: String] { [
    "experienceChanged:": L10n.text("Original restores the original controls and presentation. Modern enables gameplay aids. Individual changes select Custom."),
    "modernControlsChanged:": L10n.text("Use modern keyboard shortcuts for skills, pause, speed, camera movement and hints in all three games."),
    "variableSpeedChanged:": SpeedPanelControls.help,
    "interruptionChanged:": L10n.text("Pause when you switch apps or disconnect a controller. Resume when you are ready."),
    "pointerCaptureChanged:": L10n.text("Keep the pointer inside the game window, including paused screens and menus. Hold Option or switch apps to release it."),
    "favorApproachingChanged:": L10n.text("When lemmings overlap, favour an eligible lemming still approaching rather than one that has turned away."),
    "favorBombBlockersChanged:": L10n.text("Prefer eligible blockers for bomb skills. L2 Exploder supports blockers, but Bomber does not. L3 uses carried bombs."),
    "favorBuildersChanged:": L10n.text("Prefer the current builder when assigning Build again. Native skill rules still apply. L3 uses carried bricks."),
    "cursorStyleChanged:": L10n.text("Original uses the Amiga crosshair. Modern uses thin corner brackets that show skill eligibility. Applies to all three games."),
    "selectionStyleChanged:": L10n.text("None hides selection effects. Obvious adds a green diamond and halo. Modern adds the diamond, white outline and green glow in all three games."),
    "skillBackpacksChanged:": L10n.text("Show Climber and Floater backpacks on Classic lemmings. L2 and L3 keep their own skill artwork."),
    "skillCursorSizeChanged:": L10n.text("Show the selected skill beside the pointer at 1× or 2×, or hide it with None. L3 Use shows carried tool uses."),
    "reticleCountChanged:": L10n.text("Show the number of live lemmings inside the reticule. This also works when the skill icon is hidden."),
    "levelSelectionChanged:": L10n.text("Choose unlocked levels or all levels for direct Classic selection. L2 and L3 keep their campaign selection rules."),
    "controllerChanged:": L10n.text("Enable gamepad gameplay and menu controls in Classic, L2 and L3."),
    "controllerTapChanged:": L10n.text("Tap the right trigger to toggle fast-forward. Hold it for a temporary speed boost."),
    "controllerSwapChanged:": L10n.text("Use the right stick to aim and the left stick to move the camera."),
    "showControllerRemapping": L10n.text("Choose the gameplay action for each controller button. Menu navigation keeps the standard bindings."),
    "remapSourceChanged:": L10n.text("Choose the physical controller button to change."),
    "remapRoleChanged:": L10n.text("Choose its gameplay action. If another button uses that action, their bindings swap."),
    "resetControllerMapping": L10n.text("Restore the default gameplay actions for every controller button."),
    "presetChanged:": L10n.text("Apply a machine's artwork, music and sound choices together. Further changes select Custom."),
    "graphicsChanged:": L10n.text("Choose the Classic artwork source. Available sources depend on installed game data."),
    "depthChanged:": L10n.text("Choose the colour palette for Classic artwork."),
    "graphicsShuffleChanged:": L10n.text("Choose a different available Classic artwork source for each level."),
    "counterStyleChanged:": L10n.text("Choose the style of Classic skill counters, including the original Macintosh bitmap digits."),
    "sequelArtworkChanged:": L10n.text("Use recreated Macintosh-style artwork in Lemmings 2 and Lemmings 3."),
    "displayChanged:": L10n.text("Choose Flat Panel, Monitor or Television. Classic uses the tube simulation. L2 and L3 keep their bitmap renderers."),
    "intensityChanged:": L10n.text("Adjust the Classic tube effect. Available with Monitor or Television. Flat Panel keeps the saved value."),
    "aspectChanged:": L10n.text("Adjust Classic pixel width with Monitor or Television. Flat Panel keeps the saved value."),
    "integerChanged:": L10n.text("Scale the playfield in whole pixel steps to keep pixel edges crisp."),
    "hdEffectsChanged:": L10n.text("Enable added explosions, flashes, speed streaks and ghost trails. Motion and flash reductions still apply."),
    "hdrFlashesChanged:": L10n.text("Add a fireball, shockwave, smoke and flash to nuclear explosions. HDR displays add brightness. Requires HD effects."),
    "interfaceSizeChanged:": L10n.text("Enlarge menu pages and controls help. Scroll to reach controls when the enlarged page exceeds the window."),
    "reduceMotionChanged:": L10n.text("Disable speed trails and cinematic explosions. Keep gameplay speed and controls."),
    "showSongInfoChanged:": L10n.text("Show the song title and soundtrack briefly when the music changes."),
    "fadeMenuButtonChanged:": L10n.text("Fade Menu, Settings and Graphics during play. Turn this off to keep the buttons visible."),
    "reduceFlashesChanged:": L10n.text("Disable added bright explosion cores, HDR flashes and cinematic explosions. Original game sprites remain."),
    "musicChanged:": L10n.text("Choose a soundtrack or Adaptive DJ Mix. Available soundtracks depend on installed music libraries."),
    "styleChanged:": L10n.text("Faithful keeps the source's original sound. Modern applies the enhanced music treatment."),
    "musicVolumeChanged:": L10n.text("Adjust music volume independently of sound effects."),
    "soundChanged:": L10n.text("Choose the sound-effects source. Available choices depend on installed game data."),
    "soundVolumeChanged:": L10n.text("Adjust sound-effects volume independently of music."),
    "musicShuffleChanged:": L10n.text("Change the soundtrack source each level. Adaptive DJ Mix selects tracks during play."),
    "djSoundtracksChanged:": L10n.text("Let Adaptive DJ Mix include music from L2, L3 and other ports, when installed."),
    "pauseBeatChanged:": L10n.text("On pause, play only isolated percussion. Tracks without a rhythm part stop. Applies to all three games."),
    "bottomFallSoundsChanged:": L10n.text("Play a death sound when a lemming falls out of the bottom of the level in any of the three games."),
    "openMusicLibraries": L10n.text("Download or remove optional soundtrack libraries. Installed libraries become available in the music choices."),
    "telemetryChanged:": privacyHelp,
    "showPrivacyInfo:": privacyHelp,
    "openPlayInsights": L10n.text("View play counts and music use for this Mac, and shared totals when the service is available."),
    "clearPlayInsights:": L10n.text("Clear this Mac's play counts. This does not reset the service's shared saved total.")
  ] }

  private var privacyHelp: String {
    telemetry.endpoint == nil
      ? L10n.text("This build has no shared counts service. Play insights show this Mac only.")
      : L10n.text("Shares daily use, results, lemmings saved, solo or Hot Seat play, and music use. No names, IDs, pack names or replays are sent.\n\nThe shared saved total remains until the service owner resets it. The service sees your network address during delivery.")
  }

  private func popUp(_ action: Selector) -> NSPopUpButton {
    let button = GamePopUpButton()
    button.controlSize = .large
    button.target = self
    button.action = action
    return button
  }

  private func slider(_ action: Selector, value: Double, min: Double = 0, max: Double = 1)
    -> NSSlider
  {
    let control = GameSlider(value: value, minValue: min, maxValue: max, target: self, action: action)
    control.isContinuous = true
    return control
  }

  private func gameplayPane() -> NSView {
    let language = GamePopUpButton()
    language.onShowChoices = { [weak self] in self?.showLanguagePicker() }
    language.addItems(withTitles: L10n.languageOptions.map(\.title))
    language.setAccessibilityLabel(L10n.text("Language"))
    languagePopUp = language
    let experience = popUp(#selector(experienceChanged))
    experience.addItems(withTitles: ClassicExperiencePreset.allCases.map(\.title))
    experience.setAccessibilityLabel(L10n.text("Presentation preset"))
    experiencePopUp = experience
    let backpacks = GameCheckButton(title: L10n.text("Show skill backpacks"), target: self, action: #selector(skillBackpacksChanged))
    backpacks.state = settings.showClassicSkillBackpacks ? .on : .off
    skillBackpacksCheck = backpacks
    let count = GameCheckButton(title: L10n.text("Show lemming count"), target: self, action: #selector(reticleCountChanged))
    count.state = settings.showReticleCount ? .on : .off
    reticleCountCheck = count
    let iconSize = popUp(#selector(skillCursorSizeChanged))
    iconSize.addItems(withTitles: SkillCursorIconSize.allCases.map(\.title))
    iconSize.selectItem(at: SkillCursorIconSize.allCases.firstIndex(of: settings.skillCursorIconSize) ?? 1)
    iconSize.setAccessibilityLabel(L10n.text("Skill icon size"))
    skillCursorSizePopUp = iconSize
    let cursor = popUp(#selector(cursorStyleChanged))
    cursor.addItems(withTitles: GameplayCursorStyle.allCases.map(\.title))
    cursor.setAccessibilityLabel(L10n.text("Cursor style"))
    cursorStylePopUp = cursor
    let selection = popUp(#selector(selectionStyleChanged))
    selection.addItems(withTitles: LemmingSelectionStyle.allCases.map(\.title))
    selection.setAccessibilityLabel(L10n.text("Selection effect"))
    selectionStylePopUp = selection
    let modern = GameCheckButton(title: L10n.text("Modern keyboard controls"), target: self, action: #selector(modernControlsChanged))
    modernControlsCheck = modern
    let variable = GameCheckButton(title: L10n.text("Variable speed: 2×, 3×, 5×, 10×"), target: self, action: #selector(variableSpeedChanged))
    variableSpeedCheck = variable
    let ridiculous = GameCheckButton(title: L10n.text("Ridiculous speed (25×)"), target: self, action: #selector(ridiculousSpeedChanged))
    ridiculous.state = settings.ridiculousSpeedEnabled ? .on : .off
    ridiculous.isEnabled = settings.modernControlsEnabled && settings.variableSpeedEnabled
    ridiculousSpeedCheck = ridiculous
    let interruption = GameCheckButton(title: L10n.text("Pause on interruption"), target: self, action: #selector(interruptionChanged))
    interruption.state = settings.pauseOnInterruption ? .on : .off
    interruptionCheck = interruption
    let favorApproaching = GameCheckButton(title: L10n.text("Favor lemmings still approaching"), target: self, action: #selector(favorApproachingChanged))
    favorApproaching.state = settings.favorApproachingLemmings ? .on : .off
    favorApproachingCheck = favorApproaching
    let bombBlockers = GameCheckButton(title: L10n.text("Favor blockers for bombs"), target: self, action: #selector(favorBombBlockersChanged))
    bombBlockers.state = settings.favorBombBlockers ? .on : .off
    favorBombBlockersCheck = bombBlockers
    let builders = GameCheckButton(title: L10n.text("Favor current builders for Build"), target: self, action: #selector(favorBuildersChanged))
    builders.state = settings.favorBuilders ? .on : .off
    favorBuildersCheck = builders
    let targeting = GameControlGroup(controls: [favorApproaching, bombBlockers, builders], label: L10n.text("Targeting"))
    let levelSelection = popUp(#selector(levelSelectionChanged))
    levelSelection.addItems(withTitles: [L10n.text("Player Unlocked"), L10n.text("All")])
    levelSelection.setAccessibilityLabel(L10n.text("Level selection"))
    levelSelection.selectItem(at: settings.unlockAllClassicLevels ? 1 : 0)
    levelSelectionPopUp = levelSelection
    modern.state = settings.modernControlsEnabled ? .on : .off
    variable.state = settings.variableSpeedEnabled ? .on : .off
    variable.isEnabled = settings.modernControlsEnabled
    let pointer = GameCheckButton(title: L10n.text("Keep pointer inside the game"), target: self, action: #selector(pointerCaptureChanged))
    pointer.state = settings.confinePointer ? .on : .off
    pointerCaptureCheck = pointer
    return groupedPane([
      (L10n.text("Presentation"), [(L10n.text("Language"), language), (L10n.text("Style"), experience)]),
      (L10n.text("Controls and assistance"), [(L10n.text("Controls"), modern), (L10n.text("Speed"), GameControlGroup(controls: [variable, ridiculous], label: L10n.text("Speed"))), (L10n.text("Pause"), interruption), (L10n.text("Pointer"), pointer)]),
      (L10n.text("Skill targeting"), [("", targeting)]),
      (L10n.text("Pointer and selection"), [(L10n.text("Cursor"), cursor), (L10n.text("Skill icon"), iconSize), (L10n.text("Reticule"), count), (L10n.text("Selection"), selection), (L10n.text("Classic"), backpacks)]),
      (L10n.text("Level access"), [(L10n.text("Level Select"), levelSelection)]),
    ])
  }

  @objc private func cursorStyleChanged(_ sender: NSPopUpButton) {
    guard GameplayCursorStyle.allCases.indices.contains(sender.indexOfSelectedItem) else { return }
    settings.gameplayCursorStyle = GameplayCursorStyle.allCases[sender.indexOfSelectedItem]
    changed()
  }
  @objc private func skillBackpacksChanged(_ sender: NSButton) {
    settings.showClassicSkillBackpacks = sender.state == .on
    changed()
  }
  @objc private func reticleCountChanged(_ sender: NSButton) {
    settings.showReticleCount = sender.state == .on
    changed()
  }
  @objc private func skillCursorSizeChanged(_ sender: NSPopUpButton) {
    settings.skillCursorIconSize = SkillCursorIconSize.allCases[sender.indexOfSelectedItem]
    changed()
  }
  @objc private func selectionStyleChanged(_ sender: NSPopUpButton) {
    guard LemmingSelectionStyle.allCases.indices.contains(sender.indexOfSelectedItem) else { return }
    settings.lemmingSelectionStyle = LemmingSelectionStyle.allCases[sender.indexOfSelectedItem]
    changed()
  }
  @objc private func modernControlsChanged(_ sender: NSButton) {
    settings.modernControlsEnabled = sender.state == .on
    variableSpeedCheck?.isEnabled = settings.modernControlsEnabled
    ridiculousSpeedCheck?.isEnabled = settings.modernControlsEnabled && settings.variableSpeedEnabled
    changed()
  }
  @objc private func interruptionChanged(_ sender: NSButton) { settings.pauseOnInterruption = sender.state == .on; changed() }
  @objc private func variableSpeedChanged(_ sender: NSButton) {
    settings.variableSpeedEnabled = sender.state == .on
    ridiculousSpeedCheck?.isEnabled = settings.modernControlsEnabled && settings.variableSpeedEnabled
    changed()
  }
  @objc private func ridiculousSpeedChanged(_ sender: NSButton) {
    settings.ridiculousSpeedEnabled = sender.state == .on; changed()
  }
  @objc private func favorApproachingChanged(_ sender: NSButton) {
    settings.favorApproachingLemmings = sender.state == .on
    changed()
  }
  @objc private func levelSelectionChanged(_ sender: NSPopUpButton) {
    guard (0...1).contains(sender.indexOfSelectedItem) else { return }
    settings.unlockAllClassicLevels = sender.indexOfSelectedItem == 1
    changed()
  }
  @objc private func favorBombBlockersChanged(_ sender: NSButton) {
    settings.favorBombBlockers = sender.state == .on; changed()
  }
  @objc private func favorBuildersChanged(_ sender: NSButton) {
    settings.favorBuilders = sender.state == .on; changed()
  }
  @objc private func experienceChanged(_ sender: NSPopUpButton) {
    guard ClassicExperiencePreset.allCases.indices.contains(sender.indexOfSelectedItem) else { return }
    switch ClassicExperiencePreset.allCases[sender.indexOfSelectedItem] {
    case .original: applyExperiencePreset(modern: false)
    case .modern: applyExperiencePreset(modern: true)
    case .custom: settings.experiencePreset = .custom; changed(customizeExperience: false)
    }
  }
  private func controllerPane() -> NSView {
    let enabled = GameCheckButton(title: L10n.text("Enable gamepad controls"), target: self, action: #selector(controllerChanged))
    let tap = GameCheckButton(title: L10n.text("Tap RT to toggle fast-forward"), target: self, action: #selector(controllerTapChanged))
    let swap = GameCheckButton(title: L10n.text("Swap sticks"), target: self, action: #selector(controllerSwapChanged))
    controllerCheck = enabled; controllerTapCheck = tap; controllerSwapCheck = swap
    enabled.state = settings.controllerEnabled ? .on : .off
    tap.state = settings.controllerTapSpeed ? .on : .off
    swap.state = settings.controllerSwapSticks ? .on : .off
    tap.isEnabled = settings.controllerEnabled; swap.isEnabled = settings.controllerEnabled
    let scroll = NSScrollView()
    scroll.hasVerticalScroller = true; scroll.drawsBackground = false
    scroll.heightAnchor.constraint(equalToConstant: 184).isActive = true
    let text = GameReadOnlyText(frame: CGRect(x: 0, y: 0, width: 730, height: 420))
    text.string = ControllerDevicePresentation.help(mapping: settings.controllerMappings)
    controllerHelpText = text
    text.isEditable = false; text.isSelectable = true; text.drawsBackground = false
    text.isVerticallyResizable = true; text.isHorizontallyResizable = false
    text.autoresizingMask = [.width]; text.textContainer?.widthTracksTextView = true
    scroll.documentView = text
    let remap = GameButton(title: L10n.text("Remap buttons…"), target: self, action: #selector(showControllerRemapping))
    remap.isEnabled = settings.controllerEnabled; controllerRemapButton = remap
    return groupedPane([
      (L10n.text("Gamepad"), [(L10n.text("Controls"), enabled), (L10n.text("Speed"), tap), (L10n.text("Sticks"), swap)]),
      (L10n.text("Button mapping"), [(L10n.text("Buttons"), remap), (L10n.text("Bindings"), scroll)]),
    ])
  }
  @objc private func showControllerRemapping() {
    help.dismiss()
    let page = GameMenuPage(title: L10n.text("Controller buttons"), subtitle: L10n.text("Choose a button, then choose what it does during play."))
    let source = GamePopUpButton(), role = GamePopUpButton()
    source.target = self; source.action = #selector(remapSourceChanged)
    role.target = self; role.action = #selector(remapRoleChanged)
    for button in ControllerBindings.Button.allCases {
      source.addItem(withTitle: ControllerDevicePresentation.name(button))

      role.addItem(withTitle: ControllerBindings.roleName(button))
    }
    remapSource = source; remapRole = role
    source.setAccessibilityLabel(L10n.text("Controller button"))
    role.setAccessibilityLabel(L10n.text("Gameplay action"))
    let reset = GameButton(title: L10n.text("Reset button mappings"), target: self, action: #selector(resetControllerMapping))
    let note = GameLabel(wrappingLabelWithString: L10n.text("If another button has that action, the two bindings swap. Modifier combinations follow the new buttons. Menu navigation always uses the standard controls. Sticks can be swapped in Controller settings."))
    let content = pane([(L10n.text("Button"), source), (L10n.text("Action"), role), (L10n.text("Defaults"), reset), (L10n.text("How it works"), note)])
    content.frame = page.body.bounds; content.autoresizingMask = [.width, .height]
    page.body.addSubview(content)
    page.onBack = { [weak page] in if let page { GameScreen.shared.dismiss(page) } }
    remapSourceChanged(source)
    GameScreen.shared.present(page, onDismiss: { [weak self] in self?.help.dismiss() })
  }
  @objc private func remapSourceChanged(_ sender: NSPopUpButton) {
    guard ControllerBindings.Button.allCases.indices.contains(sender.indexOfSelectedItem) else { return }
    let source = ControllerBindings.Button.allCases[sender.indexOfSelectedItem]
    let role = settings.controllerMappings[source.rawValue].flatMap(ControllerBindings.Button.init(rawValue:)) ?? source
    remapRole?.selectItem(at: ControllerBindings.Button.allCases.firstIndex(of: role)!)
  }
  @objc private func remapRoleChanged(_ sender: NSPopUpButton) {
    guard let source = remapSource,
      ControllerBindings.Button.allCases.indices.contains(source.indexOfSelectedItem),
      ControllerBindings.Button.allCases.indices.contains(sender.indexOfSelectedItem) else { return }
    settings.controllerMappings = ControllerBindings.swapping(settings.controllerMappings,
      physical: ControllerBindings.Button.allCases[source.indexOfSelectedItem], role: ControllerBindings.Button.allCases[sender.indexOfSelectedItem])
    controllerHelpText?.string = ControllerDevicePresentation.help(mapping: settings.controllerMappings)
    changed()
  }
  @objc private func resetControllerMapping() {
    settings.controllerMappings = [:]
    if let source = remapSource { remapSourceChanged(source) }
    controllerHelpText?.string = ControllerDevicePresentation.help(mapping: settings.controllerMappings)
    changed()
  }
  @objc private func controllerChanged(_ sender: NSButton) {
    settings.controllerEnabled = sender.state == .on
    controllerTapCheck?.isEnabled = settings.controllerEnabled
    controllerSwapCheck?.isEnabled = settings.controllerEnabled
    controllerRemapButton?.isEnabled = settings.controllerEnabled; changed()
  }
  @objc private func controllerTapChanged(_ sender: NSButton) { settings.controllerTapSpeed = sender.state == .on; changed() }
  @objc private func djShuffleScopeChanged(_ sender: NSPopUpButton) {
    guard SoundtrackCatalogue.ShuffleScope.allCases.indices.contains(sender.indexOfSelectedItem) else { return }
    settings.djShuffleScope = SoundtrackCatalogue.ShuffleScope.allCases[sender.indexOfSelectedItem]
    changed()
  }
  @objc private func controllerSwapChanged(_ sender: NSButton) { settings.controllerSwapSticks = sender.state == .on; changed() }
  private func applyExperiencePreset(modern: Bool) {
    settings.applyExperiencePreset(modern: modern)
    rebuildSources(); changed(customizeExperience: false)
  }

  private func graphicsPane() -> NSView {
    // A preset sets every choice at once, the way one machine sounded and
    // looked. Anything changed afterwards moves the list back to Custom.
    let preset = popUp(#selector(presetChanged))
    preset.addItem(withTitle: L10n.text("Custom"))
    for profile in PlatformProfile.all { preset.addItem(withTitle: profile.name) }
    presetPopUp = preset

    let graphics = popUp(#selector(graphicsChanged))
    let depth = popUp(#selector(depthChanged))
    for option in ClassicColorDepth.allCases { depth.addItem(withTitle: option.displayName) }
    let shuffle = GameCheckButton(
      title: L10n.text("Change artwork every level"), target: self,
      action: #selector(graphicsShuffleChanged))
    shuffle.state = settings.shuffleGraphics ? .on : .off
    graphicsPopUp = graphics
    depthPopUp = depth
    graphicsShuffleCheck = shuffle
    let counters = popUp(#selector(counterStyleChanged))
    for style in ClassicCounterStyle.allCases { counters.addItem(withTitle: style.title) }
    counters.setAccessibilityLabel(L10n.text("Classic skill counters"))
    counterStylePopUp = counters
    let sequel = GameCheckButton(title: L10n.text("Macintosh-style 2× artwork"), target: self,
                          action: #selector(sequelArtworkChanged))
    sequelArtworkCheck = sequel
    sequel.state = SequelArtworkPreference.enabled ? .on : .off
    return groupedPane([
      (L10n.text("Machine preset"), [(L10n.text("Machine"), preset)]),
      (L10n.text("Classic artwork"), [(L10n.text("Artwork"), graphics), (L10n.text("Colour Depth"), depth), (L10n.text("Shuffle"), shuffle), (L10n.text("Counters"), counters)]),
      (L10n.text("Sequel artwork"), [(L10n.text("Lemmings 2 + 3"), sequel)]),
    ])
  }

  @objc private func sequelArtworkChanged(_ sender: NSButton) {
    SequelArtworkPreference.setEnabled(sender.state == .on)
    changed()
  }

  @objc private func counterStyleChanged(_ sender: NSPopUpButton) {
    guard ClassicCounterStyle.allCases.indices.contains(sender.indexOfSelectedItem) else { return }
    settings.counterStyle = ClassicCounterStyle.allCases[sender.indexOfSelectedItem]
    changed()
  }

  @objc private func refreshSequelArtwork() {
    sequelArtworkCheck?.state = SequelArtworkPreference.enabled ? .on : .off
  }

  private func videoPane() -> NSView {
    let display = popUp(#selector(displayChanged))
    for option in ClassicDisplayMode.allCases { display.addItem(withTitle: option.displayName) }
    display.setAccessibilityLabel(L10n.text("Screen"))
    let intensity = slider(#selector(intensityChanged), value: settings.displayIntensity)
    intensity.setAccessibilityLabel(L10n.text("Tube Strength"))
    let aspect = slider(
      #selector(aspectChanged), value: settings.pixelAspect, min: 0.8, max: 1.5)
    aspect.setAccessibilityLabel(L10n.text("Pixel Width"))
    let integer = GameCheckButton(
      title: L10n.text("Whole pixels only"), target: self,
      action: #selector(integerChanged))
    integer.state = settings.integerScaling ? .on : .off

    displayPopUp = display
    intensitySlider = intensity
    aspectSlider = aspect
    integerCheck = integer

    let note = GameLabel(
      labelWithString: videoIsConnected
        ? "" : L10n.text("The tube simulation is not in the drawing path yet."))

    let hdEffects = GameCheckButton(title: L10n.text("Enable HD effects"), target: self, action: #selector(hdEffectsChanged))
    hdEffects.state = settings.hdEffectsEnabled ? .on : .off
    hdEffectsCheck = hdEffects
    let flashes = GameCheckButton(title: L10n.text("Cinematic nuclear explosions"), target: self, action: #selector(hdrFlashesChanged))
    flashes.state = settings.fullScreenHDRFlashes ? .on : .off
    flashes.isEnabled = settings.hdEffectsEnabled
    hdrFlashCheck = flashes
    tubeCaptions.removeAll()
    var sections: [(String, [(String, NSView)])] = [
      (L10n.text("Display"), [(L10n.text("Screen"), display), (L10n.text("Tube Strength"), intensity), (L10n.text("Pixel Width"), aspect), (L10n.text("Scaling"), integer)]),
      (L10n.text("Added effects"), [(L10n.text("Effects"), hdEffects), (L10n.text("Explosions"), flashes)]),
    ]
    if !videoIsConnected { sections.append((L10n.text("Availability"), [("", note)])) }
    let content = groupedPane(sections)
    refreshVideoControls()
    return content
  }

  private func refreshVideoControls() {
    displayPopUp?.isEnabled = videoIsConnected
    integerCheck?.isEnabled = videoIsConnected
    let tubeEnabled = videoIsConnected && settings.display != .flat
    for control in [intensitySlider, aspectSlider].compactMap({ $0 }) {
      control.isEnabled = tubeEnabled
      control.needsDisplay = true
    }
    for caption in tubeCaptions {
      caption.isEnabled = tubeEnabled
      caption.needsDisplay = true
    }
  }

  private func accessibilityPane() -> NSView {
    let songInfo = GameCheckButton(title: L10n.text("Show song info"), target: self, action: #selector(showSongInfoChanged))
    songInfo.setAccessibilityLabel(L10n.text("Show song info"))
    songInfo.state = settings.showSongInfo ? .on : .off
    showSongInfoCheck = songInfo
    let fadeMenu = GameCheckButton(title: L10n.text("Fade gameplay buttons"), target: self, action: #selector(fadeMenuButtonChanged))
    fadeMenu.setAccessibilityLabel(L10n.text("Fade gameplay buttons"))
    fadeMenu.state = settings.fadeMenuButton ? .on : .off
    fadeMenuButtonCheck = fadeMenu
    let staticHome = GameCheckButton(title: L10n.text("Static home screen"), target: self, action: #selector(staticHomeScreenChanged))
    staticHome.setAccessibilityLabel(L10n.text("Static home screen"))
    staticHome.state = settings.staticHomeScreen ? .on : .off
    staticHomeScreenCheck = staticHome
    let motion = GameCheckButton(title: L10n.text("Reduce added motion"), target: self, action: #selector(reduceMotionChanged))
    motion.state = settings.reduceMotion ? .on : .off
    reduceMotionCheck = motion
    let reducedFlashes = GameCheckButton(title: L10n.text("Reduce added flashes"), target: self, action: #selector(reduceFlashesChanged))
    reducedFlashes.state = settings.reduceFlashes ? .on : .off
    reduceFlashesCheck = reducedFlashes
    let size = popUp(#selector(interfaceSizeChanged))
    size.addItems(withTitles: ClassicInterfaceSize.allCases.map(\.title))
    size.selectItem(at: ClassicInterfaceSize.allCases.firstIndex(of: settings.interfaceSize) ?? 0)
    interfaceSizePopUp = size
    return groupedPane([
      (L10n.text("Interface"), [(L10n.text("UI size"), size), ("", songInfo), ("", fadeMenu), ("", staticHome)]),
      (L10n.text("Added effects"), [(L10n.text("Motion"), motion), (L10n.text("Flashes"), reducedFlashes)]),
    ])
  }

  private func audioPane() -> NSView {
    let music = popUp(#selector(musicChanged))
    let style = popUp(#selector(styleChanged))
    for option in ClassicMusicStyle.allCases { style.addItem(withTitle: option.displayName) }
    let musicLevel = slider(#selector(musicVolumeChanged), value: settings.musicVolume)
    let sound = popUp(#selector(soundChanged))
    let soundLevel = slider(#selector(soundVolumeChanged), value: settings.soundVolume)
    musicLevel.setAccessibilityLabel(L10n.text("Music volume"))
    soundLevel.setAccessibilityLabel(L10n.text("Effects volume"))
    let falls = GameCheckButton(title: L10n.text("Play death sound"), target: self, action: #selector(bottomFallSoundsChanged))
    falls.state = settings.bottomFallSounds ? .on : .off

    musicPopUp = music
    stylePopUp = style
    musicSlider = musicLevel
    soundPopUp = sound
    soundSlider = soundLevel
    let shuffle = GameCheckButton(
      title: L10n.text("Change soundtrack every level"), target: self,
      action: #selector(musicShuffleChanged))
    shuffle.state = settings.shuffleMusic ? .on : .off
    musicShuffleCheck = shuffle
    let mixes = GameCheckButton(title: L10n.text("Include L2, L3 and other ports"), target: self, action: #selector(djSoundtracksChanged))
    mixes.state = settings.djIncludesOtherSoundtracks ? .on : .off
    djSoundtracksCheck = mixes
    let shuffleScope = popUp(#selector(djShuffleScopeChanged))
    shuffleScope.addItems(withTitles: SoundtrackCatalogue.ShuffleScope.allCases.map(\.title))
    shuffleScope.selectItem(at: SoundtrackCatalogue.ShuffleScope.allCases.firstIndex(of: settings.djShuffleScope) ?? 0)
    djShuffleScopePopUp = shuffleScope
    let folders = GameButton(title: L10n.text("Download soundtracks"), target: self, action: #selector(openMusicLibraries))
    let beat = GameCheckButton(title: L10n.text("Keep the rhythm"), target: self, action: #selector(pauseBeatChanged))
    beat.setAccessibilityLabel(L10n.text("Pause: Keep the rhythm"))
    beat.state = settings.pauseMusicBeatOnly ? .on : .off
    pauseBeatCheck = beat
    let menuTheme = GameCheckButton(title: L10n.text("Play main theme"), target: self, action: #selector(menuMusicChanged))
    menuTheme.setAccessibilityLabel(L10n.text("Main menu: Play main theme"))
    menuTheme.state = settings.menuMusic ? .on : .off
    menuMusicCheck = menuTheme
    return groupedPane([
      (L10n.text("Music"), [(L10n.text("Soundtrack"), music), (L10n.text("Style"), style), (L10n.text("Volume"), musicLevel), (L10n.text("Shuffle"), shuffle), (L10n.text("DJ Mix"), mixes), (L10n.text("DJ shuffle"), shuffleScope)]),
      (L10n.text("Sound effects"), [(L10n.text("Source"), sound), (L10n.text("Volume"), soundLevel)]),
      (L10n.text("Playback behaviour"), [(L10n.text("Main menu"), menuTheme), (L10n.text("Pause"), beat), (L10n.text("Bottom Falls"), falls)]),
      ("", [("", folders)]),
    ])
  }

  private func privacyPane() -> NSView {
    let share = GameCheckButton(title: L10n.text("Share play counts"), target: self,
                                action: #selector(telemetryChanged(_:)))
    share.state = telemetry.sharesCounts ? .on : .off
    share.isEnabled = telemetry.endpoint != nil
    share.setAccessibilityLabel(L10n.text("Share play counts"))
    telemetryCheck = share
    let info = GameButton(title: L10n.text("Privacy info"), target: self, action: #selector(showPrivacyInfo(_:)))
    let insights = GameButton(title: L10n.text("View play insights"), target: self, action: #selector(openPlayInsights))
    let clear = GameButton(title: L10n.text("Clear this Mac's counts"), target: self, action: #selector(clearPlayInsights))
    let restore = GameButton(title: L10n.text("Restore previous counts"), target: self, action: #selector(restorePlayInsights))
    restore.isEnabled = telemetry.hasLocalCountsBackup
    restoreCountsButton = restore
    return groupedPane([
      (L10n.text("Sharing"), [(L10n.text("Counts"), share), (L10n.text("Details"), info)]),
      (L10n.text("This Mac"), [(L10n.text("Insights"), insights), (L10n.text("Reset"), clear), (L10n.text("Recovery"), restore)]),
    ])
  }

  @objc private func showPrivacyInfo(_ sender: NSButton) {
    help.show(privacyHelp, title: L10n.text("Privacy"), relativeTo: sender, pinned: true)
  }

  @objc private func telemetryChanged(_ sender: NSButton) {
    help.dismiss()
    telemetry.setSharing(sender.state == .on)
    telemetryCheck?.state = telemetry.sharesCounts ? .on : .off
  }

  @objc private func openPlayInsights() {
    help.dismiss()
    TelemetryDashboard.shared.show(owner: page?.window)
  }

  @objc private func clearPlayInsights(_ sender: NSButton) {
    help.dismiss()
    GameScreen.shared.confirm(L10n.text("ARE YOU SURE?"),
      detail: L10n.text("Clear this Mac's play counts and local saved total? The shared total stays unchanged."),
      actionTitle: L10n.text("Clear counts"), owner: page?.window) { [weak self] in
        guard let self else { return }
        self.telemetry.clearLocalCounts()
        self.restoreCountsButton?.isEnabled = self.telemetry.hasLocalCountsBackup
      }
  }

  @objc private func restorePlayInsights(_ sender: NSButton) {
    help.dismiss()
    telemetry.restoreLocalCounts()
    sender.isEnabled = telemetry.hasLocalCountsBackup
  }

  /// Refills the source lists and reselects what is chosen.
  private func rebuildSources() {
    refreshLanguageControls()
    experiencePopUp?.selectItem(at: ClassicExperiencePreset.allCases.firstIndex(of: settings.experiencePreset) ?? 2)
    graphicsPopUp?.removeAllItems()
    counterStylePopUp?.selectItem(at: ClassicCounterStyle.allCases.firstIndex(of: settings.counterStyle) ?? 0)
    for option in options.graphics { graphicsPopUp?.addItem(withTitle: option.displayName) }
    if let index = options.graphics.firstIndex(of: settings.graphics) {
      graphicsPopUp?.selectItem(at: index)
    }

    musicPopUp?.removeAllItems()
    for option in options.music { musicPopUp?.addItem(withTitle: option.displayName) }
    if let index = options.music.firstIndex(of: settings.music) {
      musicPopUp?.selectItem(at: index)
    }

    soundPopUp?.removeAllItems()
    for option in options.sound { soundPopUp?.addItem(withTitle: option.displayName) }
    if let index = options.sound.firstIndex(of: settings.sound) {
      soundPopUp?.selectItem(at: index)
    }

    depthPopUp?.selectItem(
      at: ClassicColorDepth.allCases.firstIndex(of: settings.colorDepth) ?? 0)
    displayPopUp?.selectItem(
      at: ClassicDisplayMode.allCases.firstIndex(of: settings.display) ?? 0)
    intensitySlider?.doubleValue = settings.displayIntensity
    aspectSlider?.doubleValue = settings.pixelAspect
    refreshVideoControls()
    stylePopUp?.selectItem(
      at: ClassicMusicStyle.allCases.firstIndex(of: settings.musicStyle) ?? 0)
    graphicsShuffleCheck?.state = settings.shuffleGraphics ? .on : .off
    musicShuffleCheck?.state = settings.shuffleMusic ? .on : .off
    pauseBeatCheck?.state = settings.pauseMusicBeatOnly ? .on : .off
    menuMusicCheck?.state = settings.menuMusic ? .on : .off
    pointerCaptureCheck?.state = settings.confinePointer ? .on : .off
    modernControlsCheck?.state = settings.modernControlsEnabled ? .on : .off
    variableSpeedCheck?.state = settings.variableSpeedEnabled ? .on : .off
    ridiculousSpeedCheck?.state = settings.ridiculousSpeedEnabled ? .on : .off
    variableSpeedCheck?.isEnabled = settings.modernControlsEnabled
    ridiculousSpeedCheck?.isEnabled = settings.modernControlsEnabled && settings.variableSpeedEnabled
    interruptionCheck?.state = settings.pauseOnInterruption ? .on : .off
    cursorStylePopUp?.selectItem(at: GameplayCursorStyle.allCases.firstIndex(of: settings.gameplayCursorStyle) ?? 1)
    skillBackpacksCheck?.state = settings.showClassicSkillBackpacks ? .on : .off
    reticleCountCheck?.state = settings.showReticleCount ? .on : .off
    skillCursorSizePopUp?.selectItem(at: SkillCursorIconSize.allCases.firstIndex(of: settings.skillCursorIconSize) ?? 1)
    selectionStylePopUp?.selectItem(at: LemmingSelectionStyle.allCases.firstIndex(of: settings.lemmingSelectionStyle) ?? 2)
    favorApproachingCheck?.state = settings.favorApproachingLemmings ? .on : .off
    favorBombBlockersCheck?.state = settings.favorBombBlockers ? .on : .off
    favorBuildersCheck?.state = settings.favorBuilders ? .on : .off
    levelSelectionPopUp?.selectItem(at: settings.unlockAllClassicLevels ? 1 : 0)
    controllerCheck?.state = settings.controllerEnabled ? .on : .off
    djShuffleScopePopUp?.selectItem(at: SoundtrackCatalogue.ShuffleScope.allCases.firstIndex(of: settings.djShuffleScope) ?? 0)
    controllerTapCheck?.state = settings.controllerTapSpeed ? .on : .off
    controllerSwapCheck?.state = settings.controllerSwapSticks ? .on : .off
    controllerRemapButton?.isEnabled = settings.controllerEnabled
    controllerHelpText?.string = ControllerDevicePresentation.help(mapping: settings.controllerMappings)
    controllerTapCheck?.isEnabled = settings.controllerEnabled
    controllerSwapCheck?.isEnabled = settings.controllerEnabled
    reduceMotionCheck?.state = settings.reduceMotion ? .on : .off
    staticHomeScreenCheck?.state = settings.staticHomeScreen ? .on : .off
    reduceFlashesCheck?.state = settings.reduceFlashes ? .on : .off
    showSongInfoCheck?.state = settings.showSongInfo ? .on : .off
    fadeMenuButtonCheck?.state = settings.fadeMenuButton ? .on : .off
    hdEffectsCheck?.state = settings.hdEffectsEnabled ? .on : .off
    hdrFlashCheck?.isEnabled = settings.hdEffectsEnabled
    hdrFlashCheck?.state = settings.fullScreenHDRFlashes ? .on : .off
    djSoundtracksCheck?.state = settings.djIncludesOtherSoundtracks ? .on : .off
    telemetryCheck?.state = telemetry.sharesCounts ? .on : .off
    // Shuffling needs something to choose between.
    graphicsShuffleCheck?.isEnabled = options.graphics.count > 1
    musicShuffleCheck?.isEnabled = options.music.count > 2
  }

  // MARK: - Changes

  private func refreshLanguageControls() {
    let selected = L10n.currentLanguagePreference
    languagePopUp?.selectItem(at: L10n.languageOptions.firstIndex(of: selected) ?? 0)
  }

  private func rebuildSettingsLanguage() {
    guard let previous = page, GameScreen.shared.contains(previous) else { return }
    let replacement = makeSettingsPage()
    page = replacement
    rebuildSources()
    GameScreen.shared.replace(previous, with: replacement, focus: languagePopUp,
                              onDismiss: { [weak self] in self?.help.dismiss() })
  }

  private func showLanguagePicker() {
    if let languagePage, GameScreen.shared.contains(languagePage) {
      GameScreen.shared.present(languagePage)
      return
    }
    help.dismiss()
    languageEntryPreference = L10n.currentLanguagePreference
    let picker = makeLanguagePage()
    languagePage = picker
    GameScreen.shared.present(picker, onDismiss: { [weak self, weak picker] in
      guard let self, self.languagePage === picker else { return }
      self.finishLanguageSelection(apply: false)
    })
  }

  private func makeLanguagePage() -> GameMenuPage {
    let picker = GameMenuPage(title: L10n.text("Language"))
    picker.onBack = { [weak self] in self?.finishLanguageSelection(apply: false) }
    picker.addPrimaryAction(L10n.text("Apply")) { [weak self] in self?.finishLanguageSelection(apply: true) }
    let scroll = NSScrollView(frame: picker.body.bounds)
    scroll.autoresizingMask = [.width, .height]
    scroll.hasVerticalScroller = true
    scroll.drawsBackground = false
    let list = NSView(frame: CGRect(x: 0, y: 0, width: 940, height: max(440, L10n.languageOptions.count * 44)))
    for (index, option) in L10n.languageOptions.enumerated() {
      let button = GameButton(title: option.title, target: self, action: #selector(previewLanguage))
      button.tag = index
      button.setButtonType(.momentaryPushIn) // Track the full stone face. Keep radio semantics below.
      let selected = option == L10n.currentLanguagePreference
      button.state = selected ? .on : .off
      button.setAccessibilityRole(.radioButton)
      button.setAccessibilityValue(selected ? 1 : 0)
      button.frame = CGRect(x: 6, y: list.bounds.height - CGFloat(index + 1) * 44, width: 920, height: 38)
      list.addSubview(button)
      if selected { picker.preferControllerControl(button) }
    }
    scroll.documentView = list
    picker.body.addSubview(scroll)
    scroll.contentView.scroll(to: CGPoint(x: 0, y: max(0, list.bounds.height - scroll.contentSize.height)))
    return picker
  }

  @objc private func previewLanguage(_ sender: NSButton) {
    guard languageEntryPreference != nil, let previous = languagePage,
          L10n.languageOptions.indices.contains(sender.tag) else { return }
    L10n.setLanguage(L10n.languageOptions[sender.tag])
    rebuildSettingsLanguage()
    let replacement = makeLanguagePage()
    languagePage = replacement
    GameScreen.shared.replace(previous, with: replacement, onDismiss: { [weak self, weak replacement] in
      guard let self, self.languagePage === replacement else { return }
      self.finishLanguageSelection(apply: false)
    })
  }

  private func finishLanguageSelection(apply: Bool) {
    guard let original = languageEntryPreference else { return }
    if apply { InterfaceLanguagePreference.save(L10n.currentLanguagePreference, to: .standard) }
    else { L10n.setLanguage(original) }
    languageEntryPreference = nil
    let picker = languagePage
    languagePage = nil
    rebuildSettingsLanguage()
    if let picker { GameScreen.shared.dismiss(picker) }
  }

  private func changed(customizeExperience: Bool = true) {
    help.dismiss()
    if customizeExperience { settings.refreshExperiencePreset() }
    experiencePopUp?.selectItem(at: ClassicExperiencePreset.allCases.firstIndex(of: settings.experiencePreset) ?? 2)
    experiencePopUp?.needsDisplay = true
    GameAccessibility.interfaceSize = settings.interfaceSize
    GameScreen.shared.reattach()
    onChange?(settings)
  }
  @objc private func interfaceSizeChanged(_ sender: NSPopUpButton) {
    guard ClassicInterfaceSize.allCases.indices.contains(sender.indexOfSelectedItem) else { return }
    settings.interfaceSize = ClassicInterfaceSize.allCases[sender.indexOfSelectedItem]
    changed()
  }

  /// Marks the preset list as Custom after a single control is changed.
  private func markCustom() { presetPopUp?.selectItem(at: 0) }

  /// Applies a machine's look and sound in one move.
  ///
  /// The preset is corrected against what is installed, so choosing a machine
  /// whose data is missing lands on something that works rather than failing.
  @objc private func presetChanged(_ sender: NSPopUpButton) {
    let index = sender.indexOfSelectedItem - 1
    guard PlatformProfile.all.indices.contains(index) else { return }
    let wanted = ClassicSettings.matching(PlatformProfile.all[index])
    var applied = options.correcting(wanted)
    // A preset describes a machine, not a session, so shuffling stays as set.
    applied.shuffleGraphics = settings.shuffleGraphics
    applied.shuffleMusic = settings.shuffleMusic
    applied.modernControlsEnabled = settings.modernControlsEnabled
    applied.counterStyle = settings.counterStyle
    applied.variableSpeedEnabled = settings.variableSpeedEnabled
    applied.ridiculousSpeedEnabled = settings.ridiculousSpeedEnabled
    applied.gameplayCursorStyle = settings.gameplayCursorStyle
    applied.showClassicSkillBackpacks = settings.showClassicSkillBackpacks
    applied.showReticleCount = settings.showReticleCount
    applied.skillCursorIconSize = settings.skillCursorIconSize
    applied.lemmingSelectionStyle = settings.lemmingSelectionStyle
    applied.favorApproachingLemmings = settings.favorApproachingLemmings
    applied.favorBombBlockers = settings.favorBombBlockers
    applied.favorBuilders = settings.favorBuilders
    applied.experiencePreset = settings.experiencePreset
    applied.musicStyle = settings.musicStyle
    applied.pauseMusicBeatOnly = settings.pauseMusicBeatOnly
    applied.menuMusic = settings.menuMusic
    applied.pauseOnInterruption = settings.pauseOnInterruption
    applied.unlockAllClassicLevels = settings.unlockAllClassicLevels
    applied.controllerEnabled = settings.controllerEnabled
    applied.controllerTapSpeed = settings.controllerTapSpeed
    applied.controllerSwapSticks = settings.controllerSwapSticks
    applied.controllerMappings = settings.controllerMappings
    applied.interfaceSize = settings.interfaceSize
    applied.reduceMotion = settings.reduceMotion
    applied.staticHomeScreen = settings.staticHomeScreen
    applied.reduceFlashes = settings.reduceFlashes
    applied.showSongInfo = settings.showSongInfo
    applied.fadeMenuButton = settings.fadeMenuButton
    applied.hdEffectsEnabled = settings.hdEffectsEnabled
    applied.confinePointer = settings.confinePointer
    applied.fullScreenHDRFlashes = settings.fullScreenHDRFlashes
    applied.djIncludesOtherSoundtracks = settings.djIncludesOtherSoundtracks
    applied.djShuffleScope = settings.djShuffleScope
    settings = applied
    rebuildSources()
    presetPopUp?.selectItem(at: index + 1)
    changed(customizeExperience: false)
  }

  @objc private func graphicsChanged(_ sender: NSPopUpButton) {
    let index = sender.indexOfSelectedItem
    guard options.graphics.indices.contains(index) else { return }
    settings.graphics = options.graphics[index]
    markCustom()
    changed()
  }

  @objc private func depthChanged(_ sender: NSPopUpButton) {
    let all = ClassicColorDepth.allCases
    guard all.indices.contains(sender.indexOfSelectedItem) else { return }
    settings.colorDepth = all[sender.indexOfSelectedItem]
    markCustom()
    changed()
  }

  @objc private func displayChanged(_ sender: NSPopUpButton) {
    let all = ClassicDisplayMode.allCases
    guard all.indices.contains(sender.indexOfSelectedItem) else { return }
    settings.display = all[sender.indexOfSelectedItem]
    refreshVideoControls()
    markCustom()
    changed()
  }

  @objc private func intensityChanged(_ sender: NSSlider) {
    settings.displayIntensity = sender.doubleValue
    changed()
  }

  @objc private func aspectChanged(_ sender: NSSlider) {
    settings.pixelAspect = sender.doubleValue
    markCustom()
    changed()
  }

  @objc private func integerChanged(_ sender: NSButton) {
    settings.integerScaling = sender.state == .on
    markCustom()
    changed()
  }

  @objc private func musicChanged(_ sender: NSPopUpButton) {
    let index = sender.indexOfSelectedItem
    guard options.music.indices.contains(index) else { return }
    settings.music = options.music[index]
    markCustom()
    changed()
  }

  @objc private func styleChanged(_ sender: NSPopUpButton) {
    let all = ClassicMusicStyle.allCases
    guard all.indices.contains(sender.indexOfSelectedItem) else { return }
    settings.musicStyle = all[sender.indexOfSelectedItem]
    markCustom()
    changed()
  }

  @objc private func graphicsShuffleChanged(_ sender: NSButton) {
    settings.shuffleGraphics = sender.state == .on
    changed()
  }

  @objc private func musicShuffleChanged(_ sender: NSButton) {
    settings.shuffleMusic = sender.state == .on
    changed()
  }

  @objc private func pauseBeatChanged(_ sender: NSButton) {
    settings.pauseMusicBeatOnly = sender.state == .on
    changed()
  }

  @objc private func menuMusicChanged(_ sender: NSButton) {
    settings.menuMusic = sender.state == .on
    changed()
  }

  @objc private func openSoundtrackFolder() {
    guard let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
    let folder = root.appendingPathComponent("Ultimate Lemmings/Soundtracks", isDirectory: true)
    do { try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true); NSWorkspace.shared.open(folder) }
    catch { GameScreen.shared.message(L10n.text("Soundtrack folder"), detail: error.localizedDescription) }
  }

  @objc private func openMusicLibraries() { help.dismiss(); MusicLibraryWindow.shared.show() }

  @objc private func pointerCaptureChanged(_ sender: NSButton) {
    settings.confinePointer = sender.state == .on
    changed()
  }

  @objc private func staticHomeScreenChanged(_ sender: NSButton) {
    settings.staticHomeScreen = sender.state == .on
    changed()
  }

  @objc private func reduceMotionChanged(_ sender: NSButton) {
    settings.reduceMotion = sender.state == .on
    changed()
  }

  @objc private func showSongInfoChanged(_ sender: NSButton) {
    settings.showSongInfo = sender.state == .on
    changed()
  }

  @objc private func fadeMenuButtonChanged(_ sender: NSButton) {
    settings.fadeMenuButton = sender.state == .on
    changed()
  }

  @objc private func reduceFlashesChanged(_ sender: NSButton) {
    settings.reduceFlashes = sender.state == .on
    changed()
  }

  @objc private func hdEffectsChanged(_ sender: NSButton) {
    settings.hdEffectsEnabled = sender.state == .on
    hdrFlashCheck?.isEnabled = settings.hdEffectsEnabled
    changed()
  }

  @objc private func hdrFlashesChanged(_ sender: NSButton) {
    settings.fullScreenHDRFlashes = sender.state == .on
    changed()
  }

  @objc private func djSoundtracksChanged(_ sender: NSButton) {
    settings.djIncludesOtherSoundtracks = sender.state == .on
    changed()
  }

  @objc private func musicVolumeChanged(_ sender: NSSlider) {
    settings.musicVolume = sender.doubleValue
    changed()
  }

  @objc private func soundChanged(_ sender: NSPopUpButton) {
    let index = sender.indexOfSelectedItem
    guard options.sound.indices.contains(index) else { return }
    settings.sound = options.sound[index]
    markCustom()
    changed()
  }

  @objc private func bottomFallSoundsChanged(_ sender: NSButton) {
    settings.bottomFallSounds = sender.state == .on
    changed()
  }

  @objc private func soundVolumeChanged(_ sender: NSSlider) {
    settings.soundVolume = sender.doubleValue
    changed()
  }
}
#endif
