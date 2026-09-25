import AppKit
import NxlvKit

/// Settings are a page inside the game. Choices apply immediately.
@MainActor final class SettingsWindow: NSObject {
  private var page: GameMenuPage?
  private var options: ClassicSettingsOptions
  private var settings: ClassicSettings

  /// Called whenever a choice changes, so the game can follow immediately.
  var onChange: ((ClassicSettings) -> Void)?

  private var presetPopUp: NSPopUpButton?
  private var experiencePopUp: NSPopUpButton?
  private var graphicsPopUp: NSPopUpButton?
  private var depthPopUp: NSPopUpButton?
  private var displayPopUp: NSPopUpButton?
  private var intensitySlider: NSSlider?
  private var aspectSlider: NSSlider?
  private var integerCheck: NSButton?
  private var musicPopUp: NSPopUpButton?
  private var stylePopUp: NSPopUpButton?
  private var musicSlider: NSSlider?
  private var soundPopUp: NSPopUpButton?
  private var soundSlider: NSSlider?
  private var graphicsShuffleCheck: NSButton?
  private var musicShuffleCheck: NSButton?
  private var sequelArtworkCheck: NSButton?
  private var pointerCaptureCheck: NSButton?
  private var modernControlsCheck: NSButton?
  private var variableSpeedCheck: NSButton?
  private var interruptionCheck: NSButton?
  private var reticleCountCheck: NSButton?
  private var skillCursorSizePopUp: NSPopUpButton?
  private var favorApproachingCheck: NSButton?
  private var favorBombBlockersCheck: NSButton?
  private var favorBuildersCheck: NSButton?
  private var levelSelectionPopUp: NSPopUpButton?
  private var controllerCheck: NSButton?
  private var controllerTapCheck: NSButton?
  private var controllerSwapCheck: NSButton?
  private var controllerRemapButton: NSButton?
  private var controllerHelpText: NSTextView?
  private var remapSource: NSPopUpButton?
  private var remapRole: NSPopUpButton?
  private var interfaceSizePopUp: NSPopUpButton?
  private var reduceMotionCheck: NSButton?
  private var reduceFlashesCheck: NSButton?
  private var hdEffectsCheck: NSButton?
  private var hdrFlashCheck: NSButton?
  private var djSoundtracksCheck: NSButton?

  /// Whether the tube simulation is in the live drawing path.
  var videoIsConnected = true

  init(settings: ClassicSettings, options: ClassicSettingsOptions) {
    self.settings = options.correcting(settings)
    self.options = options
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
    let page = GameMenuPage(title: "Settings")
    page.onBack = { [weak page] in if let page { GameScreen.shared.dismiss(page) } }
    let tabs = GameTabs()
    tabs.addTabViewItem(tab("Gameplay", gameplayPane()))
    tabs.addTabViewItem(tab("Controller", controllerPane()))
    tabs.addTabViewItem(tab("Graphics", graphicsPane()))
    tabs.addTabViewItem(tab("Video", videoPane()))
    tabs.addTabViewItem(tab("Audio", audioPane()))
    tabs.addTabViewItem(tab("Accessibility", accessibilityPane()))
    tabs.translatesAutoresizingMaskIntoConstraints = false
    page.body.addSubview(tabs)
    NSLayoutConstraint.activate([
      tabs.topAnchor.constraint(equalTo: page.body.topAnchor),
      tabs.bottomAnchor.constraint(equalTo: page.body.bottomAnchor),
      tabs.leadingAnchor.constraint(equalTo: page.body.leadingAnchor),
      tabs.trailingAnchor.constraint(equalTo: page.body.trailingAnchor)
    ])
    self.page = page
    rebuildSources()
    GameScreen.shared.present(page)
  }

  private func tab(_ label: String, _ view: NSView) -> NSTabViewItem {
    let item = NSTabViewItem(identifier: label)
    item.label = label
    item.view = view
    return item
  }

  // MARK: - Building panes

  /// Lays out labelled rows down a pane.
  private func pane(_ rows: [(String, NSView)], spacing: CGFloat = 22) -> NSView {
    let container = NSView()
    var previous: NSView?
    for (label, control) in rows {
      let caption = GameLabel(labelWithString: label)
      if control.accessibilityLabel() == nil {
        control.setAccessibilityLabel((control as? NSButton).map { label + ": " + $0.title } ?? label)
      }
      caption.alignment = .right
      caption.translatesAutoresizingMaskIntoConstraints = false
      control.translatesAutoresizingMaskIntoConstraints = false
      container.addSubview(caption)
      container.addSubview(control)

      NSLayoutConstraint.activate([
        caption.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 18),
        caption.widthAnchor.constraint(equalToConstant: 180),
        caption.centerYAnchor.constraint(equalTo: control.centerYAnchor),
        control.leadingAnchor.constraint(equalTo: caption.trailingAnchor, constant: 12),
        control.trailingAnchor.constraint(
          equalTo: container.trailingAnchor, constant: -18),
        control.topAnchor.constraint(
          equalTo: previous?.bottomAnchor ?? container.topAnchor,
          constant: previous == nil ? 32 : spacing),
      ])
      previous = control
    }
    return container
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
    let experience = popUp(#selector(experienceChanged))
    experience.addItems(withTitles: ClassicExperiencePreset.allCases.map(\.title))
    experience.setAccessibilityLabel("Gameplay preset")
    experiencePopUp = experience
    let count = GameCheckButton(title: "Show lemming count", target: self, action: #selector(reticleCountChanged))
    count.state = settings.showReticleCount ? .on : .off
    reticleCountCheck = count
    let iconSize = popUp(#selector(skillCursorSizeChanged))
    iconSize.addItems(withTitles: SkillCursorIconSize.allCases.map(\.title))
    iconSize.selectItem(at: SkillCursorIconSize.allCases.firstIndex(of: settings.skillCursorIconSize) ?? 1)
    iconSize.setAccessibilityLabel("Skill icon size")
    skillCursorSizePopUp = iconSize
    let modern = GameCheckButton(title: "Modern keyboard controls", target: self, action: #selector(modernControlsChanged))
    modernControlsCheck = modern
    let variable = GameCheckButton(title: "Variable speed: 2×, 3×, 5×, 10×", target: self, action: #selector(variableSpeedChanged))
    variableSpeedCheck = variable
    let interruption = GameCheckButton(title: "Pause when switching apps or a controller disconnects", target: self, action: #selector(interruptionChanged))
    interruption.state = settings.pauseOnInterruption ? .on : .off
    interruptionCheck = interruption
    let favorApproaching = GameCheckButton(title: "Favor lemmings still approaching", target: self, action: #selector(favorApproachingChanged))
    favorApproaching.toolTip = "When a click could match more than one lemming, pick the one still approaching. Skip the one that already turned away."
    favorApproaching.state = settings.favorApproachingLemmings ? .on : .off
    favorApproachingCheck = favorApproaching
    let bombBlockers = GameCheckButton(title: "Favor blockers for bombs", target: self, action: #selector(favorBombBlockersChanged))
    bombBlockers.state = settings.favorBombBlockers ? .on : .off
    favorBombBlockersCheck = bombBlockers
    let builders = GameCheckButton(title: "Favor current builders for Build", target: self, action: #selector(favorBuildersChanged))
    builders.state = settings.favorBuilders ? .on : .off
    favorBuildersCheck = builders
    let targeting = NSStackView(views: [favorApproaching, bombBlockers, builders])
    targeting.orientation = .vertical; targeting.alignment = .leading; targeting.spacing = 8
    let levelSelection = popUp(#selector(levelSelectionChanged))
    levelSelection.addItems(withTitles: ["Player Unlocked", "All"])
    levelSelection.setAccessibilityLabel("Level selection")
    levelSelection.toolTip = "Choose which Classic levels are available for direct selection."
    levelSelection.selectItem(at: settings.unlockAllClassicLevels ? 1 : 0)
    levelSelectionPopUp = levelSelection
    variable.toolTip = SpeedPanelControls.help
    modern.state = settings.modernControlsEnabled ? .on : .off
    variable.state = settings.variableSpeedEnabled ? .on : .off
    variable.isEnabled = settings.modernControlsEnabled
    return pane([
      ("Preset", experience), ("Controls", modern), ("Speed", variable), ("Pause", interruption),
      ("Targeting", targeting), ("Skill icon", iconSize), ("Reticule", count), ("Level Select", levelSelection),
    ], spacing: 14)
  }

  @objc private func reticleCountChanged(_ sender: NSButton) {
    settings.showReticleCount = sender.state == .on
    changed()
  }
  @objc private func skillCursorSizeChanged(_ sender: NSPopUpButton) {
    settings.skillCursorIconSize = SkillCursorIconSize.allCases[sender.indexOfSelectedItem]
    changed()
  }
  @objc private func modernControlsChanged(_ sender: NSButton) {
    settings.modernControlsEnabled = sender.state == .on
    variableSpeedCheck?.isEnabled = settings.modernControlsEnabled
    changed()
  }
  @objc private func interruptionChanged(_ sender: NSButton) { settings.pauseOnInterruption = sender.state == .on; changed() }
  @objc private func variableSpeedChanged(_ sender: NSButton) {
    settings.variableSpeedEnabled = sender.state == .on; changed()
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
    case .custom: settings.experiencePreset = .custom; changed()
    }
  }
  private func controllerPane() -> NSView {
    let enabled = GameCheckButton(title: "Enable gamepad controls", target: self, action: #selector(controllerChanged))
    let tap = GameCheckButton(title: "Tap RT to toggle fast-forward; hold RT for a temporary boost", target: self, action: #selector(controllerTapChanged))
    let swap = GameCheckButton(title: "Swap sticks: right aims, left moves the camera", target: self, action: #selector(controllerSwapChanged))
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
    let remap = GameButton(title: "Remap buttons…", target: self, action: #selector(showControllerRemapping))
    remap.isEnabled = settings.controllerEnabled; controllerRemapButton = remap
    return pane([("Gamepad", enabled), ("Speed", tap), ("Sticks", swap), ("Buttons", remap), ("Bindings", scroll)])
  }
  @objc private func showControllerRemapping() {
    let page = GameMenuPage(title: "Controller buttons", subtitle: "Choose a button, then choose what it does during play.")
    let source = GamePopUpButton(), role = GamePopUpButton()
    source.target = self; source.action = #selector(remapSourceChanged)
    role.target = self; role.action = #selector(remapRoleChanged)
    for button in ControllerBindings.Button.allCases {
      source.addItem(withTitle: ControllerDevicePresentation.name(button))

      role.addItem(withTitle: ControllerBindings.roleName(button))
    }
    remapSource = source; remapRole = role
    source.setAccessibilityLabel("Controller button")
    role.setAccessibilityLabel("Gameplay action")
    let reset = GameButton(title: "Reset button mappings", target: self, action: #selector(resetControllerMapping))
    let note = GameLabel(wrappingLabelWithString: "If another button has that action, the two bindings swap. Modifier combinations follow the new buttons. Menu navigation always uses the standard controls. Sticks can be swapped in Controller settings.")
    let content = pane([("Button", source), ("Action", role), ("Defaults", reset), ("How it works", note)])
    content.frame = page.body.bounds; content.autoresizingMask = [.width, .height]
    page.body.addSubview(content)
    page.onBack = { [weak page] in if let page { GameScreen.shared.dismiss(page) } }
    remapSourceChanged(source)
    GameScreen.shared.present(page)
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
  @objc private func controllerSwapChanged(_ sender: NSButton) { settings.controllerSwapSticks = sender.state == .on; changed() }
  private func applyExperiencePreset(modern: Bool) {
    settings.applyExperiencePreset(modern: modern)
    SequelArtworkPreference.setEnabled(modern)
    rebuildSources(); markCustom(); changed(customizeExperience: false)
  }

  private func graphicsPane() -> NSView {
    // A preset sets every choice at once, the way one machine sounded and
    // looked. Anything changed afterwards moves the list back to Custom.
    let preset = popUp(#selector(presetChanged))
    preset.addItem(withTitle: "Custom")
    for profile in PlatformProfile.all { preset.addItem(withTitle: profile.name) }
    presetPopUp = preset

    let graphics = popUp(#selector(graphicsChanged))
    let depth = popUp(#selector(depthChanged))
    for option in ClassicColorDepth.allCases { depth.addItem(withTitle: option.displayName) }
    let shuffle = GameCheckButton(
      title: "Change artwork every level", target: self,
      action: #selector(graphicsShuffleChanged))
    shuffle.state = settings.shuffleGraphics ? .on : .off
    graphicsPopUp = graphics
    depthPopUp = depth
    graphicsShuffleCheck = shuffle
    let sequel = GameCheckButton(title: "Macintosh-style 2× artwork", target: self,
                          action: #selector(sequelArtworkChanged))
    sequelArtworkCheck = sequel
    sequel.state = SequelArtworkPreference.enabled ? .on : .off
    return pane([
      ("Machine", preset), ("Artwork", graphics), ("Colour Depth", depth), ("Shuffle", shuffle),
      ("Lemmings 2 + 3", sequel),
    ])
  }

  @objc private func sequelArtworkChanged(_ sender: NSButton) {
    SequelArtworkPreference.setEnabled(sender.state == .on)
    changed()
  }

  @objc private func refreshSequelArtwork() {
    sequelArtworkCheck?.state = SequelArtworkPreference.enabled ? .on : .off
  }

  private func videoPane() -> NSView {
    let display = popUp(#selector(displayChanged))
    for option in ClassicDisplayMode.allCases { display.addItem(withTitle: option.displayName) }
    let intensity = slider(#selector(intensityChanged), value: settings.displayIntensity)
    let aspect = slider(
      #selector(aspectChanged), value: settings.pixelAspect, min: 0.8, max: 1.5)
    let integer = GameCheckButton(
      title: "Whole pixels only", target: self,
      action: #selector(integerChanged))
    integer.state = settings.integerScaling ? .on : .off

    displayPopUp = display
    intensitySlider = intensity
    aspectSlider = aspect
    integerCheck = integer

    for control in [display, intensity, aspect, integer] as [NSControl] {
      control.isEnabled = videoIsConnected
    }
    let note = GameLabel(
      labelWithString: videoIsConnected
        ? "" : "The tube simulation is not in the drawing path yet.")

    let hdEffects = GameCheckButton(title: "Enable HD effects", target: self, action: #selector(hdEffectsChanged))
    hdEffects.toolTip = "Cinematic explosions, HDR flashes, speed streaks and ghost trails. Turn off for old-school effects."
    hdEffects.state = settings.hdEffectsEnabled ? .on : .off
    hdEffectsCheck = hdEffects
    let flashes = GameCheckButton(title: "Cinematic nuclear explosions", target: self, action: #selector(hdrFlashesChanged))
    flashes.toolTip = "White flash, expanding fireball, shockwave and rising smoke. Works on all displays, with extra brightness in HDR."
    flashes.state = settings.fullScreenHDRFlashes ? .on : .off
    flashes.isEnabled = settings.hdEffectsEnabled
    hdrFlashCheck = flashes
    let pointer = GameCheckButton(title: "Keep pointer inside the game", target: self, action: #selector(pointerCaptureChanged))
    pointer.toolTip = "Hold Option or pause to release the pointer. Menus also release it."
    pointer.state = settings.confinePointer ? .on : .off
    pointerCaptureCheck = pointer
    return pane([
      ("Effects", hdEffects),
      ("Screen", display),
      ("Tube Strength", intensity),
      ("Pixel Width", aspect),
      ("Scaling", integer),
      ("Explosions", flashes),
      ("Pointer", pointer),
      ("", note),
    ])
  }

  private func accessibilityPane() -> NSView {
    let motion = GameCheckButton(title: "Reduce added motion", target: self, action: #selector(reduceMotionChanged))
    motion.toolTip = "Disable speed trails and cinematic explosions. Keep gameplay speed and controls."
    motion.state = settings.reduceMotion ? .on : .off
    reduceMotionCheck = motion
    let reducedFlashes = GameCheckButton(title: "Reduce added flashes", target: self, action: #selector(reduceFlashesChanged))
    reducedFlashes.toolTip = "Disable added bright explosion cores, HDR flashes and cinematic explosions. Original game sprites remain."
    reducedFlashes.state = settings.reduceFlashes ? .on : .off
    reduceFlashesCheck = reducedFlashes
    let size = popUp(#selector(interfaceSizeChanged))
    size.addItems(withTitles: ClassicInterfaceSize.allCases.map(\.title))
    size.selectItem(at: ClassicInterfaceSize.allCases.firstIndex(of: settings.interfaceSize) ?? 0)
    size.toolTip = "Enlarge menu pages and controls help. Scroll enlarged pages to reach every control."
    interfaceSizePopUp = size
    return pane([("UI size", size), ("Motion", motion), ("Flashes", reducedFlashes)])
  }

  private func audioPane() -> NSView {
    let music = popUp(#selector(musicChanged))
    let style = popUp(#selector(styleChanged))
    for option in ClassicMusicStyle.allCases { style.addItem(withTitle: option.displayName) }
    let musicLevel = slider(#selector(musicVolumeChanged), value: settings.musicVolume)
    let sound = popUp(#selector(soundChanged))
    let soundLevel = slider(#selector(soundVolumeChanged), value: settings.soundVolume)
    let falls = GameCheckButton(title: "Play death sound", target: self, action: #selector(bottomFallSoundsChanged))
    falls.state = settings.bottomFallSounds ? .on : .off

    musicPopUp = music
    stylePopUp = style
    musicSlider = musicLevel
    soundPopUp = sound
    soundSlider = soundLevel
    let shuffle = GameCheckButton(
      title: "Change soundtrack every level", target: self,
      action: #selector(musicShuffleChanged))
    shuffle.state = settings.shuffleMusic ? .on : .off
    musicShuffleCheck = shuffle
    let mixes = GameCheckButton(title: "Include L2, L3 and other ports", target: self, action: #selector(djSoundtracksChanged))
    mixes.state = settings.djIncludesOtherSoundtracks ? .on : .off
    djSoundtracksCheck = mixes
    let folders = GameButton(title: "Open Soundtrack Folder", target: self, action: #selector(openSoundtrackFolder))
    return pane([
      ("Music", music),
      ("Music Style", style),
      ("Music Volume", musicLevel),
      ("Shuffle", shuffle),
      ("DJ Mix", mixes),
      ("", folders),
      ("Sound Effects", sound),
      ("Effects Volume", soundLevel),
      ("Bottom Falls", falls),
    ])
  }

  /// Refills the source lists and reselects what is chosen.
  private func rebuildSources() {
    experiencePopUp?.selectItem(at: ClassicExperiencePreset.allCases.firstIndex(of: settings.experiencePreset) ?? 2)
    graphicsPopUp?.removeAllItems()
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
    stylePopUp?.selectItem(
      at: ClassicMusicStyle.allCases.firstIndex(of: settings.musicStyle) ?? 0)
    graphicsShuffleCheck?.state = settings.shuffleGraphics ? .on : .off
    musicShuffleCheck?.state = settings.shuffleMusic ? .on : .off
    pointerCaptureCheck?.state = settings.confinePointer ? .on : .off
    modernControlsCheck?.state = settings.modernControlsEnabled ? .on : .off
    variableSpeedCheck?.state = settings.variableSpeedEnabled ? .on : .off
    variableSpeedCheck?.isEnabled = settings.modernControlsEnabled
    interruptionCheck?.state = settings.pauseOnInterruption ? .on : .off
    reticleCountCheck?.state = settings.showReticleCount ? .on : .off
    skillCursorSizePopUp?.selectItem(at: SkillCursorIconSize.allCases.firstIndex(of: settings.skillCursorIconSize) ?? 1)
    favorApproachingCheck?.state = settings.favorApproachingLemmings ? .on : .off
    favorBombBlockersCheck?.state = settings.favorBombBlockers ? .on : .off
    favorBuildersCheck?.state = settings.favorBuilders ? .on : .off
    levelSelectionPopUp?.selectItem(at: settings.unlockAllClassicLevels ? 1 : 0)
    controllerCheck?.state = settings.controllerEnabled ? .on : .off
    controllerTapCheck?.state = settings.controllerTapSpeed ? .on : .off
    controllerSwapCheck?.state = settings.controllerSwapSticks ? .on : .off
    controllerRemapButton?.isEnabled = settings.controllerEnabled
    controllerHelpText?.string = ControllerDevicePresentation.help(mapping: settings.controllerMappings)
    controllerTapCheck?.isEnabled = settings.controllerEnabled
    controllerSwapCheck?.isEnabled = settings.controllerEnabled
    reduceMotionCheck?.state = settings.reduceMotion ? .on : .off
    reduceFlashesCheck?.state = settings.reduceFlashes ? .on : .off
    hdEffectsCheck?.state = settings.hdEffectsEnabled ? .on : .off
    hdrFlashCheck?.isEnabled = settings.hdEffectsEnabled
    hdrFlashCheck?.state = settings.fullScreenHDRFlashes ? .on : .off
    djSoundtracksCheck?.state = settings.djIncludesOtherSoundtracks ? .on : .off
    // Shuffling needs something to choose between.
    graphicsShuffleCheck?.isEnabled = options.graphics.count > 1
    musicShuffleCheck?.isEnabled = options.music.count > 2
  }

  // MARK: - Changes

  private func changed(customizeExperience: Bool = true) {
    if customizeExperience { settings.experiencePreset = .custom }
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
    applied.variableSpeedEnabled = settings.variableSpeedEnabled
    applied.showReticleCount = settings.showReticleCount
    applied.skillCursorIconSize = settings.skillCursorIconSize
    applied.favorApproachingLemmings = settings.favorApproachingLemmings
    applied.favorBombBlockers = settings.favorBombBlockers
    applied.favorBuilders = settings.favorBuilders
    applied.experiencePreset = settings.experiencePreset
    applied.musicStyle = settings.musicStyle
    applied.pauseOnInterruption = settings.pauseOnInterruption
    applied.unlockAllClassicLevels = settings.unlockAllClassicLevels
    applied.controllerEnabled = settings.controllerEnabled
    applied.controllerTapSpeed = settings.controllerTapSpeed
    applied.controllerSwapSticks = settings.controllerSwapSticks
    applied.controllerMappings = settings.controllerMappings
    applied.interfaceSize = settings.interfaceSize
    applied.reduceMotion = settings.reduceMotion
    applied.reduceFlashes = settings.reduceFlashes
    applied.hdEffectsEnabled = settings.hdEffectsEnabled
    applied.confinePointer = settings.confinePointer
    applied.fullScreenHDRFlashes = settings.fullScreenHDRFlashes
    applied.djIncludesOtherSoundtracks = settings.djIncludesOtherSoundtracks
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

  @objc private func openSoundtrackFolder() {
    guard let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
    let folder = root.appendingPathComponent("Ultimate Lemmings/Soundtracks", isDirectory: true)
    do { try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true); NSWorkspace.shared.open(folder) }
    catch { GameScreen.shared.message("Soundtrack folder", detail: error.localizedDescription) }
  }

  @objc private func pointerCaptureChanged(_ sender: NSButton) {
    settings.confinePointer = sender.state == .on
    changed()
  }

  @objc private func reduceMotionChanged(_ sender: NSButton) {
    settings.reduceMotion = sender.state == .on
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
