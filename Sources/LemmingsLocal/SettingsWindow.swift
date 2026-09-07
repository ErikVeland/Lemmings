import AppKit
import NxlvKit

/// The settings dialog.
///
/// The game surface is drawn to look like the original. This is not part of
/// that surface, so it uses ordinary controls and behaves the way any other
/// Macintosh settings window does.
///
/// Every list is built from what is installed rather than written out here. An
/// interface that lists every source will offer Macintosh music to somebody
/// with no Macintosh disk, and then fail when they choose it.
@MainActor final class SettingsWindow: NSObject, NSWindowDelegate {
  private var window: NSWindow?
  private var options: ClassicSettingsOptions
  private var settings: ClassicSettings

  /// Called whenever a choice changes, so the game can follow immediately.
  var onChange: ((ClassicSettings) -> Void)?

  private var presetPopUp: NSPopUpButton?
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
    guard window != nil else { return }
    rebuildSources()
    onChange?(settings)
  }

  var current: ClassicSettings { settings }

  // MARK: - Presenting

  func show() {
    if let window {
      window.makeKeyAndOrderFront(nil)
      return
    }
    let made = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 430, height: 320),
      styleMask: [.titled, .closable], backing: .buffered, defer: false)
    made.title = "Settings"
    made.delegate = self
    made.isReleasedWhenClosed = false

    let tabs = NSTabView(frame: NSRect(x: 0, y: 0, width: 430, height: 320))
    tabs.addTabViewItem(tab("Graphics", graphicsPane()))
    tabs.addTabViewItem(tab("Video", videoPane()))
    tabs.addTabViewItem(tab("Audio", audioPane()))
    made.contentView = tabs
    made.center()
    made.makeKeyAndOrderFront(nil)
    window = made
    rebuildSources()
  }

  func windowWillClose(_ notification: Notification) {
    window = nil
  }

  private func tab(_ label: String, _ view: NSView) -> NSTabViewItem {
    let item = NSTabViewItem(identifier: label)
    item.label = label
    item.view = view
    return item
  }

  // MARK: - Building panes

  /// Lays out labelled rows down a pane.
  private func pane(_ rows: [(String, NSView)]) -> NSView {
    let container = NSView()
    var previous: NSView?
    for (label, control) in rows {
      let caption = NSTextField(labelWithString: label)
      caption.alignment = .right
      caption.translatesAutoresizingMaskIntoConstraints = false
      control.translatesAutoresizingMaskIntoConstraints = false
      container.addSubview(caption)
      container.addSubview(control)

      NSLayoutConstraint.activate([
        caption.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 18),
        caption.widthAnchor.constraint(equalToConstant: 120),
        caption.centerYAnchor.constraint(equalTo: control.centerYAnchor),
        control.leadingAnchor.constraint(equalTo: caption.trailingAnchor, constant: 12),
        control.trailingAnchor.constraint(
          equalTo: container.trailingAnchor, constant: -18),
        control.topAnchor.constraint(
          equalTo: previous?.bottomAnchor ?? container.topAnchor,
          constant: previous == nil ? 26 : 14),
      ])
      previous = control
    }
    return container
  }

  private func popUp(_ action: Selector) -> NSPopUpButton {
    let button = NSPopUpButton()
    button.target = self
    button.action = action
    return button
  }

  private func slider(_ action: Selector, value: Double, min: Double = 0, max: Double = 1)
    -> NSSlider
  {
    let control = NSSlider(value: value, minValue: min, maxValue: max, target: self, action: action)
    control.isContinuous = true
    return control
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
    let shuffle = NSButton(
      checkboxWithTitle: "Change artwork every level", target: self,
      action: #selector(graphicsShuffleChanged))
    shuffle.state = settings.shuffleGraphics ? .on : .off
    graphicsPopUp = graphics
    depthPopUp = depth
    graphicsShuffleCheck = shuffle
    let sequel = NSButton(checkboxWithTitle: "Macintosh-style 2× artwork", target: self,
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
    let integer = NSButton(
      checkboxWithTitle: "Whole pixels only", target: self,
      action: #selector(integerChanged))
    integer.state = settings.integerScaling ? .on : .off

    displayPopUp = display
    intensitySlider = intensity
    aspectSlider = aspect
    integerCheck = integer

    for control in [display, intensity, aspect, integer] as [NSControl] {
      control.isEnabled = videoIsConnected
    }
    let note = NSTextField(
      labelWithString: videoIsConnected
        ? "" : "The tube simulation is not in the drawing path yet.")
    note.font = .systemFont(ofSize: 11)
    note.textColor = .secondaryLabelColor

    return pane([
      ("Screen", display),
      ("Tube Strength", intensity),
      ("Pixel Width", aspect),
      ("Scaling", integer),
      ("", note),
    ])
  }

  private func audioPane() -> NSView {
    let music = popUp(#selector(musicChanged))
    let style = popUp(#selector(styleChanged))
    for option in ClassicMusicStyle.allCases { style.addItem(withTitle: option.displayName) }
    let musicLevel = slider(#selector(musicVolumeChanged), value: settings.musicVolume)
    let sound = popUp(#selector(soundChanged))
    let soundLevel = slider(#selector(soundVolumeChanged), value: settings.soundVolume)

    musicPopUp = music
    stylePopUp = style
    musicSlider = musicLevel
    soundPopUp = sound
    soundSlider = soundLevel
    let shuffle = NSButton(
      checkboxWithTitle: "Change soundtrack every level", target: self,
      action: #selector(musicShuffleChanged))
    shuffle.state = settings.shuffleMusic ? .on : .off
    musicShuffleCheck = shuffle
    return pane([
      ("Music", music),
      ("Music Style", style),
      ("Music Volume", musicLevel),
      ("Shuffle", shuffle),
      ("Sound Effects", sound),
      ("Effects Volume", soundLevel),
    ])
  }

  /// Refills the source lists and reselects what is chosen.
  private func rebuildSources() {
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
    // Shuffling needs something to choose between.
    graphicsShuffleCheck?.isEnabled = options.graphics.count > 1
    musicShuffleCheck?.isEnabled = options.music.count > 2
  }

  // MARK: - Changes

  private func changed() { onChange?(settings) }

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
    settings = applied
    rebuildSources()
    presetPopUp?.selectItem(at: index + 1)
    changed()
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

  @objc private func soundVolumeChanged(_ sender: NSSlider) {
    settings.soundVolume = sender.doubleValue
    changed()
  }
}
