import AppKit
@preconcurrency import AVFoundation
import NxlvKit
import UniformTypeIdentifiers

/// The last run remains available until another level starts.
@MainActor final class RunMovie {
  private(set) var recorder: ReplayMovieRecorder?
  private var ready: Result<URL, ReplayMovieError>?
  private var finishing = false
  private var waiting: [(Result<URL, ReplayMovieError>) -> Void] = []
  private var generation = 0
  private var recordCompletions: [Int: (Result<URL, ReplayMovieError>) -> Void] = [:]
  private var title = "Lemmings"
  var hasFrames = false
  #if PERFORMANCE_TESTS
  private(set) var capturedFrames = 0
  func performanceFile() async throws -> URL {
    try await withCheckedThrowingContinuation { continuation in
      let callback: (Result<URL, ReplayMovieError>) -> Void = {
        continuation.resume(with: $0.mapError { $0 as Error })
      }
      if let ready { callback(ready) }
      else { waiting.append(callback); finish() }
    }
  }
  #endif
  var onWillReview: (() -> Void)?
  var onDidReview: (() -> Void)?

  func begin(ticksPerSecond: Double, title: String) {
    #if PERFORMANCE_TESTS
    capturedFrames = 0
    #endif
    if recordCompletions[generation] == nil { recorder?.discard() }
    generation += 1
    recorder = ReplayMovieRecorder(ticksPerSecond: ticksPerSecond)
    ready = nil; finishing = false; waiting.removeAll(); hasFrames = false
    self.title = title
  }
  func capture(_ image: @autoclosure () -> CGImage?) {
    guard let recorder, !finishing, recorder.isAcceptingFrames, let image = image() else { return }
    #if PERFORMANCE_TESTS
    capturedFrames += 1
    #endif
    hasFrames = true; recorder.append(image)
  }
  func finish() {
    guard !finishing, let recorder else { return }
    finishing = true
    let expected = generation
    recorder.finish { [weak self, recorder] result in
      self?.recordCompletions.removeValue(forKey: expected)?(result)
      if self?.generation != expected { recorder.discard() }
      guard let self, expected == self.generation else { return }
      self.ready = result
      let callbacks = self.waiting; self.waiting.removeAll()
      for callback in callbacks { callback(result) }
    }
  }
  func preserveRecord(_ report: ArcadeReport) {
    guard hasFrames, let trolley = report.trolley, let conditions = report.run.level.conditions else { return }
    let store = ArcadeStore.shared
    let qualifies = TrolleyBoard.allCases.contains { board in
      store.records.trolley.leaderboard(conditions: conditions, assisted: report.run.assisted, board: board)
        .contains { $0.id == trolley.attempt.id }
    }
    guard qualifies else { return }
    let retain: (Result<URL, ReplayMovieError>) -> Void = { result in
      if case let .success(url) = result { store.preserveReplay(url, attemptID: trolley.attempt.id) }
    }
    if let ready { retain(ready) } else { recordCompletions[generation] = retain; finish() }
  }
  func review(save: Bool = false) {
    guard hasFrames else { return }
    let show: (Result<URL, ReplayMovieError>) -> Void = { [weak self, title] result in
      switch result {
      case let .success(url):
        ReplayMovieWindow.shared.open(url, title: title, save: save, onOpen: self?.onWillReview, onClose: self?.onDidReview)
      case let .failure(error):
        GameScreen.shared.message("Replay unavailable", detail: error.localizedDescription)
      }
    }
    if let ready { show(ready) } else { waiting.append(show); finish() }
  }
  func discard() {
    if recordCompletions[generation] == nil { recorder?.discard() }
    generation += 1; recorder = nil
    ready = nil; waiting.removeAll(); hasFrames = false; finishing = false
  }
}

@MainActor final class ReplayMovieWindow {
  static let shared = ReplayMovieWindow()
  private let player = AVPlayer()
  private let video = NSView()
  private let root = ReplaySurface()
  private var window: NSWindow? { GameScreen.shared.gameWindow }
  private let bar = ReplayBar()
  private var surface: AVPlayerLayer?
  private var sourceURL: URL?
  private var ownedURL: URL?
  private var movieTitle = "Lemmings"
  private var timer: Timer?
  private var rateIndex = 2
  private var onClose: (() -> Void)?
  private var exportTask: Task<Void, Never>?
  private var exporter: AVAssetExportSession?
  static let speeds: [Float] = [0.25, 0.5, 1, 2, 3, 4, 8]
  var playbackRate: Float { Self.speeds[rateIndex] }

  private init() {
    video.wantsLayer = true
    let layer = AVPlayerLayer(player: player)
    layer.videoGravity = .resizeAspect
    layer.backgroundColor = NSColor.black.cgColor
    video.layer = layer; surface = layer
    root.addSubview(video); root.addSubview(bar)
    root.onLayout = { [weak self] in
      guard let self else { return }
      let bounds = self.root.bounds
      let scale = max(0.01, min(bounds.width / 1120, bounds.height / 720))
      let height = 154 * scale
      self.video.frame = CGRect(x: 0, y: height, width: bounds.width, height: max(0, bounds.height - height))
      self.bar.frame = CGRect(x: 0, y: 0, width: bounds.width, height: height)
      self.bar.bounds = CGRect(x: 0, y: 0, width: bounds.width / scale, height: 154)
    }
    bar.onAction = { [weak self] action in self?.action(action) }
    bar.onSeek = { [weak self] fraction in self?.seek(fraction) }
  }
  func open(_ url: URL, title: String, save: Bool = false, onOpen: (() -> Void)? = nil, onClose: (() -> Void)? = nil) {
    guard exportTask == nil else { GameScreen.shared.present(root, focus: bar); return }
    self.onClose?(); self.onClose = onClose
    onOpen?()
    bar.note = "SPACE PLAY / PAUSE   - + SPEED   S SAVE MOVIE   ESC CLOSE"
    player.pause()
    if let ownedURL { try? FileManager.default.removeItem(at: ownedURL) }
    // Hold a separate copy while the player starts the next level.
    let copy = ReplayStorage.directory.appendingPathComponent("lemmings-view-\(UUID().uuidString).mp4")
    do { try FileManager.default.copyItem(at: url, to: copy) }
    catch { self.onClose?(); self.onClose = nil; showError(error); return }
    ownedURL = copy; sourceURL = copy; movieTitle = title
    rateIndex = 2
    let item = AVPlayerItem(url: copy)
    item.audioTimePitchAlgorithm = .spectral
    player.replaceCurrentItem(with: item)
    bar.movieTitle = title
    guard GameScreen.shared.present(root, focus: bar, onDismiss: { [weak self] in self?.didClose() }) else {
      didClose(); return
    }
    player.playImmediately(atRate: playbackRate)
    timer?.invalidate()
    timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated { self?.refresh() }
    }
    refresh()
    if save { saveMovie() }
  }
  func openMovie(onOpen: (() -> Void)? = nil, onClose: (() -> Void)? = nil) {
    guard let window = GameScreen.shared.gameWindow else { return }
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.mpeg4Movie, .quickTimeMovie]
    panel.allowsMultipleSelection = false
    panel.beginSheetModal(for: window) { [weak self] response in
      guard response == .OK, let url = panel.url else { return }
      self?.open(url, title: url.deletingPathExtension().lastPathComponent, onOpen: onOpen, onClose: onClose)
    }
  }
  private func action(_ action: ReplayBar.Action) {
    switch action {
    case .play:
      if player.rate != 0 { player.pause() }
      else {
        if fraction >= 0.999 { seek(0) }
        player.playImmediately(atRate: playbackRate)
      }
    case .slower: changeSpeed(-1)
    case .faster: changeSpeed(1)
    case .restart: seek(0); player.playImmediately(atRate: playbackRate)
    case .save: saveMovie()
    case .close: close()
    }
    refresh()
  }
  private func changeSpeed(_ delta: Int) {
    rateIndex = max(0, min(Self.speeds.count - 1, rateIndex + delta))
    if player.rate != 0 { player.playImmediately(atRate: playbackRate) }
  }
  private var duration: Double {
    let value = player.currentItem?.duration.seconds ?? 0
    return value.isFinite ? max(0, value) : 0
  }
  private var fraction: Double { duration > 0 ? player.currentTime().seconds / duration : 0 }
  private func seek(_ fraction: Double) {
    let time = CMTime(seconds: min(1, max(0, fraction)) * duration, preferredTimescale: 600)
    player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
  }
  private func refresh() {
    bar.fraction = min(1, max(0, fraction.isFinite ? fraction : 0))
    let seconds = max(0, Int(player.currentTime().seconds.isFinite ? player.currentTime().seconds : 0))
    bar.caption = String(format: "REPLAY  %d:%02d / %d:%02d   SPEED %gX", seconds / 60, seconds % 60,
      Int(duration) / 60, Int(duration) % 60, playbackRate)
    bar.playing = player.rate != 0
    if let exporter { bar.note = "SAVING MOVIE  \(Int(exporter.progress * 100))%   ESC TO CANCEL" }
    bar.needsDisplay = true
  }
  private func saveMovie() {
    guard exportTask == nil, let sourceURL, let window else { return }
    player.pause()
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.mpeg4Movie]
    panel.nameFieldStringValue = movieTitle.replacingOccurrences(of: "/", with: "-") + " Replay.mp4"
    panel.message = "Save this replay at \(playbackRate)× speed, with music and sound effects."
    panel.beginSheetModal(for: window) { [weak self] response in
      guard response == .OK, let destination = panel.url, let self else { return }
      let speed = self.playbackRate
      self.exportTask = Task { @MainActor [weak self] in
        guard let self else { return }
        let temporary = destination.deletingLastPathComponent().appendingPathComponent(".lemmings-export-\(UUID().uuidString).mp4")
        defer {
          try? FileManager.default.removeItem(at: temporary)
          self.exportTask = nil; self.exporter = nil; self.refresh()
        }
        do {
          try await Self.export(source: sourceURL, destination: temporary, speed: speed) { self.exporter = $0 }
          try Task.checkCancellation()
          if FileManager.default.fileExists(atPath: destination.path) {
            _ = try FileManager.default.replaceItemAt(destination, withItemAt: temporary)
          } else { try FileManager.default.moveItem(at: temporary, to: destination) }
          self.bar.note = "MOVIE SAVED"
        } catch is CancellationError { self.bar.note = "SAVE CANCELLED" }
        catch { self.bar.note = "SAVE FAILED"; self.showError(error) }
      }
    }
  }
  static func export(source: URL, destination: URL, speed: Float,
    onStart: (AVAssetExportSession) -> Void = { _ in }) async throws {
    guard speeds.contains(speed) else { throw ReplayMovieError.message("That replay speed is unavailable.") }
    let asset = AVURLAsset(url: source)
    let duration = try await asset.load(.duration)
    guard duration.isNumeric, duration.seconds > 0 else { throw ReplayMovieError.message("The replay has no video.") }
    let composition = AVMutableComposition()
    for media in [AVMediaType.video, .audio] {
      for sourceTrack in try await asset.loadTracks(withMediaType: media) {
        guard let track = composition.addMutableTrack(withMediaType: media, preferredTrackID: kCMPersistentTrackID_Invalid) else { continue }
        try track.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: sourceTrack, at: .zero)
        if media == .video { track.preferredTransform = try await sourceTrack.load(.preferredTransform) }
      }
    }
    guard !composition.tracks(withMediaType: .video).isEmpty else { throw ReplayMovieError.message("The replay has no video track.") }
    composition.scaleTimeRange(CMTimeRange(start: .zero, duration: duration), toDuration: CMTimeMultiplyByFloat64(duration, multiplier: 1 / Double(speed)))
    guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
      throw ReplayMovieError.message("Movie export is unavailable.")
    }
    exporter.outputURL = destination; exporter.outputFileType = .mp4
    exporter.timeRange = CMTimeRange(start: .zero, duration: composition.duration)
    exporter.shouldOptimizeForNetworkUse = true
    exporter.audioTimePitchAlgorithm = .spectral
    onStart(exporter)
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      exporter.exportAsynchronously { continuation.resume() }
    }
    try Task.checkCancellation()
    guard exporter.status == .completed else { throw ReplayMovieError.message(exporter.error?.localizedDescription ?? "Movie export failed.") }
  }
  private func showError(_ error: Error) {
    GameScreen.shared.message("Replay movie", detail: error.localizedDescription)
  }
  func close() {
    if exportTask != nil {
      exporter?.cancelExport(); exportTask?.cancel(); bar.note = "Save cancelled"; return
    }
    GameScreen.shared.dismiss(root)
  }
  private func didClose() {
    exporter?.cancelExport(); exportTask?.cancel()
    player.pause(); player.replaceCurrentItem(with: nil); timer?.invalidate(); timer = nil
    if let ownedURL { try? FileManager.default.removeItem(at: ownedURL) }
    ownedURL = nil; sourceURL = nil
    onClose?(); onClose = nil
  }
}

@MainActor private final class ReplaySurface: NSView {
  var onLayout: (() -> Void)?
  override func setFrameSize(_ newSize: NSSize) { super.setFrameSize(newSize); needsLayout = true }
  override func layout() { super.layout(); onLayout?() }
}

/// Replay controls use the same lettering and stone colours as the game.
@MainActor final class ReplayBar: NSView, GameDialogCustomNavigation {
  enum Action { case restart, play, slower, faster, save, close }
  var onAction: ((Action) -> Void)?
  var onSeek: ((Double) -> Void)?
  var fraction = 0.0
  var caption = "REPLAY"
  var movieTitle = "Replay"
  var note = "SPACE PLAY / PAUSE   - + SPEED   S SAVE MOVIE   ESC CLOSE"
  var playing = false
  private var buttons: [(Action, CGRect)] = []
  private var scrub = CGRect.zero
  private var keyboardIndex: Int? = 1
  private let accessibleElements = GameAccessibleElements()
  private var choices: [(Action, String)] { [(.play, playing ? "Pause" : "Play"), (.restart, "Restart"),
      (.slower, "Slower"), (.faster, "Faster"), (.save, "Save movie"), (.close, "Back")] }
  private func layoutControls() {
    scrub = CGRect(x: 24, y: 49, width: bounds.width - 48, height: 7)
    let width = (bounds.width - 48) / 6
    buttons = choices.enumerated().map { index, choice in
      (choice.0, CGRect(x: 24 + CGFloat(index) * width, y: 75, width: width - 10, height: 42))
    }
  }
  override func isAccessibilityElement() -> Bool { true }
  override func accessibilityRole() -> NSAccessibility.Role? { .group }
  override func accessibilityChildren() -> [Any]? {
    layoutControls()
    let position = accessibleElements.element(id: "position", owner: self, label: "Replay position", frame: scrub.insetBy(dx: 0, dy: -7))
    position.setAccessibilityRole(.slider)
    position.readNumber = { [weak self] in (self?.fraction ?? 0) * 100 }
    position.adjustValue = { [weak self] direction in
      guard let self else { return }
      self.onSeek?(min(1, max(0, self.fraction + direction / 100)))
    }
    position.writeValue = { [weak self] text in
      if let value = Double(text), value.isFinite { self?.onSeek?(min(1, max(0, value / 100))) }
    }
    position.setAccessibilityMinValue(0); position.setAccessibilityMaxValue(100)
    position.onFocus = { [weak self] in self?.keyboardIndex = 0; self?.needsDisplay = true }
    return [position] + buttons.enumerated().map { index, item in
      let element = accessibleElements.element(id: "replay-\(index)", owner: self,
        label: choices[index].1, frame: item.1) { [weak self] in self?.onAction?(item.0) }
      element.onFocus = { [weak self] in self?.keyboardIndex = index + 1; self?.needsDisplay = true }
      return element
    }
  }
  private var font: MacInterfaceRenderer?
  override init(frame: NSRect) {
    super.init(frame: frame)
    if let url = Bundle.main.resourceURL?.appendingPathComponent("MacArtwork/lemmings"),
       let artwork = try? ClassicMacArtwork(directory: url), let ui = ClassicMacUserInterface(artwork: artwork) {
      font = MacInterfaceRenderer(interface: ui)
    }
    setAccessibilityLabel("Replay controls. Space plays or pauses. Minus and plus change speed. S saves a movie. Escape closes.")
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  override var isFlipped: Bool { true }
  override var acceptsFirstResponder: Bool { true }
  private func text(_ value: String, in rect: CGRect) {
    guard let font else { GamePixelText.draw(value, in: rect); return }
    font.menuLine(value, in: CGRect(x: rect.minX + 8, y: rect.midY - 10, width: rect.width - 16, height: 20), palette: .green)
  }
  override func draw(_ dirtyRect: NSRect) {
    GameStyle.fill(bounds, NSColor(calibratedWhite: 0.015, alpha: 1))
    GameMenuFrame.draw(CGRect(x: 8, y: 3, width: bounds.width - 16, height: bounds.height - 3))
    let titleRect = CGRect(x: 24, y: 16, width: bounds.width * 0.53 - 24, height: 24)
    let timeRect = CGRect(x: bounds.width * 0.55, y: 16, width: bounds.width * 0.45 - 24, height: 24)
    let timing = caption.replacingOccurrences(of: "REPLAY  ", with: "")
    if let font {
      font.menuLine(movieTitle, in: titleRect, alignment: .left)
      font.menuLine(timing, in: timeRect, alignment: .right)
    } else {
      GamePixelText.draw(movieTitle, in: titleRect)
      GamePixelText.draw(timing, in: timeRect)
    }
    layoutControls()
    GameStyle.fill(scrub, NSColor(calibratedWhite: 0.2, alpha: 1))
    GameStyle.fill(CGRect(x: scrub.minX, y: scrub.minY, width: scrub.width * fraction, height: scrub.height), NSColor.lightGray)

    for (index, choice) in choices.enumerated() {
      let width = (bounds.width - 48) / 6
      let rect = CGRect(x: 24 + CGFloat(index) * width, y: 75, width: width - 10, height: 42)
      GameStyle.fill(rect, index == 0 ? NSColor(calibratedRed: 0.78, green: 0.82, blue: 0.88, alpha: 1) : NSColor(calibratedWhite: 0.025, alpha: 1))
      NSColor(calibratedWhite: index == 0 ? 0.96 : 0.29, alpha: 1).setStroke()
      NSBezierPath(rect: rect.insetBy(dx: 0.5, dy: 0.5)).stroke()
      text(choice.1, in: rect)

    }
    if let keyboardIndex {
      let box = keyboardIndex == 0 ? scrub.insetBy(dx: -3, dy: -5) : buttons[keyboardIndex - 1].1.insetBy(dx: -3, dy: -3)
      NSColor.white.setStroke()
      let outline = NSBezierPath(rect: box); outline.lineWidth = 2
      outline.setLineDash([3, 3], count: 2, phase: 0); outline.stroke()
    }
    let hintRect = CGRect(x: 24, y: 127, width: bounds.width - 48, height: 20)
    if let font { font.menuLine(note, in: hintRect) }
    else { GamePixelText.draw(note, in: hintRect) }
  }
  override func mouseDown(with event: NSEvent) {
    window?.makeFirstResponder(self)
    let point = convert(event.locationInWindow, from: nil)
    if scrub.insetBy(dx: 0, dy: -7).contains(point) { onSeek?((point.x - scrub.minX) / scrub.width) }
    else if let button = buttons.first(where: { $0.1.contains(point) }) { onAction?(button.0) }
  }
  override func mouseDragged(with event: NSEvent) {
    let point = convert(event.locationInWindow, from: nil)
    if scrub.insetBy(dx: 0, dy: -15).contains(point) { onSeek?((point.x - scrub.minX) / scrub.width) }
  }
  override func keyDown(with event: NSEvent) {
    guard event.modifierFlags.intersection([.command, .control, .option]).isEmpty else { super.keyDown(with: event); return }
    if event.isARepeat, [36, 76, 49, 53].contains(event.keyCode) { return }
    if event.keyCode == 48 || [125, 126].contains(event.keyCode) {
      let back = event.keyCode == 126 || (event.keyCode == 48 && event.modifierFlags.contains(.shift))
      keyboardIndex = ((keyboardIndex ?? (back ? 0 : -1)) + (back ? -1 : 1) + 7) % 7
      if let element = accessibilityChildren()?[keyboardIndex!] {
        NSAccessibility.post(element: element, notification: .focusedUIElementChanged)
      }
      needsDisplay = true; return
    }
    if [123, 124].contains(event.keyCode) {
      onSeek?(min(1, max(0, fraction + (event.keyCode == 123 ? -0.01 : 0.01)))); return
    }
    if [36, 76, 49].contains(event.keyCode) {
      onAction?(keyboardIndex.flatMap { $0 > 0 ? choices[$0 - 1].0 : nil } ?? .play); return
    }
    switch event.charactersIgnoringModifiers?.lowercased() {
    case " ": onAction?(.play)
    case "-", "[": onAction?(.slower)
    case "+", "=", "]": onAction?(.faster)
    case "r": onAction?(.restart)
    case "s": onAction?(.save)
    case "\u{1b}": onAction?(.close)
    default: super.keyDown(with: event)
    }
  }
}
