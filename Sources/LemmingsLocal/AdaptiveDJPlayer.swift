import AVFoundation
import AppKit
import NxlvKit

/// One deck can play either a recording or a native ProTracker module.
@MainActor private final class DJDeck {
  private var recording: AVAudioPlayer?
  private var module: ModuleMusicPlayer?
  var volume: Float = 0 { didSet { recording?.volume = volume; module?.setVolume(Double(volume)) } }
  var isPlaying: Bool { recording?.isPlaying == true || module?.isOutputRunning == true }

  init?(_ url: URL) {
    if url.pathExtension.lowercased() == "mod" {
      let player = ModuleMusicPlayer()
      player.setVolume(0)
      guard player.play(url: url) != nil else { return nil }
      module = player
    } else {
      guard let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
      player.numberOfLoops = -1
      player.volume = 0
      player.prepareToPlay()
      recording = player
    }
  }
  func play() {
    recording?.play()
    if let module {
      if module.isRunning { try? module.resumeOutput() } else { try? module.start() }
    }
  }
  func pause() { recording?.pause(); module?.suspendOutput() }
  func stop() { recording?.stop(); module?.stop() }
}

/// Mixes recordings and modules. The rescue target earns one victory fade.
@MainActor final class AdaptiveDJPlayer {
  /// How long each kind of change takes.
  private enum Fade {
    /// Long enough to read as a mix rather than a cut.
    static let phrase = 2.6
    /// The nuke. Short, and deliberately abrupt.
    static let immediate = 0.35
    static let step = 1.0 / 30.0
  }

  private var deckA: DJDeck?
  private var deckB: DJDeck?
  private var activeIsA = true
  private var director = AdaptiveDJDirector()
  private var fadeTask: Task<Void, Never>?
  private var fadeGeneration = 0
  private var fadePosition = 0.0
  private var fadeSuspendedAt: TimeInterval?
  private var fadeSuspendedDuration: TimeInterval = 0
  private var outputSuspended = false
  private var resumeDeckA = false
  private var resumeDeckB = false
  private var fadingIn: DJDeck?
  private var fadingOut: DJDeck?

  /// Soundtracks the player supplied, keyed by folder name.
  private var pools: [String: [URL]] = [:]
  private var currentPool: String?
  private(set) var currentURL: URL?
  private var playedTracks: Set<String> = []

  private(set) var masterVolume: Float = 0.8
  private(set) var isMuted = false

  private(set) var currentTrackName = ""
  /// Called when the mix moves, so the status line can say what is playing.
  var onTrackChange: ((String) -> Void)?

  init() {}

  var isPlaying: Bool { activeDeck?.isPlaying == true }
  var isCrossfading: Bool { fadeTask != nil }
  var playingDeckCount: Int { [deckA, deckB].compactMap { $0 }.filter(\.isPlaying).count }
  /// The mix needs somewhere to travel between.
  var hasTracks: Bool { !pools.isEmpty }

  private var activeDeck: DJDeck? { activeIsA ? deckA : deckB }
  private var idleDeck: DJDeck? { activeIsA ? deckB : deckA }

  func load(soundtracks: [String: [URL]]) {
    pools = soundtracks.filter { !$0.value.isEmpty }
  }

  /// Starts the mix, or leaves it alone when it is already running.
  func start() {
    // A suspended or crossfading deck may not report isPlaying yet (the engine
    // starts asynchronously), so treat those states as already running too.
    guard !pools.isEmpty, !outputSuspended, fadeTask == nil,
          activeDeck == nil || activeDeck?.isPlaying != true else { return }
    guard let first = pickTrack(avoiding: nil) else { return }
    // A deck can be left behind in the other slot when a crossfade was
    // interrupted before it finished (a level ending mid-fade, for example).
    // Clear both decks before starting fresh, or the old one can resurface
    // later - resumed by a later suspend/resume cycle - and play alongside
    // the new track.
    deckA?.stop()
    deckB?.stop()
    deckB = nil
    resumeDeckA = false
    resumeDeckB = false
    deckA = makeDeck(first.url)
    activeIsA = true
    currentPool = first.pool
    currentURL = first.url
    deckA?.volume = isMuted ? 0 : masterVolume
    deckA?.play()
    announce(first.url)
  }

  /// A new level, so every cue may happen again.
  func resetLevel() {
    director.reset()
  }

  /// Offers the game's state to the director and acts on any cue it returns.
  func updateTelemetry(_ telemetry: AdaptiveDJEngine.Telemetry) {
    guard isPlaying, let cue = director.cue(for: telemetry) else { return }
    crossfade(seconds: cue.timing == .immediate ? Fade.immediate : Fade.phrase)
  }

  // MARK: - Decks

  private func makeDeck(_ url: URL) -> DJDeck? { DJDeck(url) }

  /// Favour victory themes, then a different source and an unplayed track.
  static func victoryPreference(_ url: URL) -> Int {
    let name = url.deletingPathExtension().lastPathComponent.lowercased()
    if ["endtune", "victory", "triumph", "fanfare", "ending", "success", "win"].contains(where: name.contains) { return 3 }
    if ["cancan", "awesome", "turkish march", "rainbow", "sports", "highland", "classic3", "smile"].contains(where: name.contains) { return 2 }
    if ["shadow", "cave", "intro", "frontend", "maintune", "game over"].contains(where: name.contains) { return 0 }
    return 1
  }

  private func pickTrack(avoiding pool: String?, victory: Bool = false) -> (pool: String, url: URL)? {
    var candidates = pools.flatMap { name, urls in urls.map { (pool: name, url: $0) } }
    let different = candidates.filter { $0.url != currentURL }
    if !different.isEmpty { candidates = different }
    guard !candidates.isEmpty else { return nil }
    if victory {
      let best = candidates.map { Self.victoryPreference($0.url) }.max() ?? 0
      candidates = candidates.filter { Self.victoryPreference($0.url) == best }
    }
    let fresh = candidates.filter { !playedTracks.contains($0.url.path) }
    if !fresh.isEmpty { candidates = fresh }
    else { playedTracks.removeAll() }
    let otherPools = candidates.filter { $0.pool != pool }
    if !otherPools.isEmpty { candidates = otherPools }
    // Skip unreadable tracks without taking down the running deck.
    while let choice = candidates.randomElement() {
      if makeDeck(choice.url) != nil {
        playedTracks.insert(choice.url.path)
        return choice
      }
      candidates.removeAll { $0.url == choice.url }
    }
    return nil
  }

  /// Brings the next track up as the current one goes down.
  ///
  /// The two curves are equal power rather than linear, so the middle of the
  /// change does not sag. A linear pair sounds like a dip.
  private func crossfade(seconds: Double) {
    guard let next = pickTrack(avoiding: currentPool, victory: true), let incoming = makeDeck(next.url) else {
      return
    }
    fadeTask?.cancel()
    fadeGeneration += 1
    let generation = fadeGeneration
    finishFade()

    fadingOut = activeDeck
    fadingIn = incoming
    fadePosition = 0
    incoming.volume = 0
    incoming.play()
    if activeIsA { deckB = incoming } else { deckA = incoming }
    activeIsA.toggle()
    currentPool = next.pool
    currentURL = next.url
    announce(next.url)

    // The fade runs on the main actor, because a deck is not safe to touch
    // from anywhere else.
    let startedAt = ProcessInfo.processInfo.systemUptime
    fadeSuspendedAt = nil
    fadeSuspendedDuration = 0
    fadeTask = Task { @MainActor [weak self] in
      var elapsed = 0.0
      while elapsed < seconds, !Task.isCancelled {
        do { try await Task.sleep(nanoseconds: UInt64(Fade.step * 1_000_000_000)) }
        catch { return }
        guard !Task.isCancelled, self?.fadeGeneration == generation else { return }
        if self?.outputSuspended == true { continue }
        elapsed = ProcessInfo.processInfo.systemUptime - startedAt - (self?.fadeSuspendedDuration ?? 0)
        self?.applyFade(position: min(1, elapsed / seconds))
      }
      guard !Task.isCancelled, self?.fadeGeneration == generation else { return }
      self?.finishFade()
    }
  }

  /// Equal-power curves rather than linear ones. A linear pair sags in the
  /// middle of the change and sounds like a dip.
  private func applyFade(position: Double) {
    fadePosition = position
    let target = isMuted ? 0 : masterVolume
    fadingIn?.volume = target * sin(Float(position) * .pi / 2)
    fadingOut?.volume = target * cos(Float(position) * .pi / 2)
  }

  private func finishFade() {
    let outgoing = fadingOut
    outgoing?.stop()
    if deckA === outgoing { deckA = nil } else if deckB === outgoing { deckB = nil }
    fadingIn?.volume = isMuted ? 0 : masterVolume
    fadingIn = nil
    fadingOut = nil
    fadeTask = nil
    fadeSuspendedAt = nil
    fadeSuspendedDuration = 0
  }

  private func announce(_ url: URL) {
    currentTrackName = url.deletingPathExtension().lastPathComponent
    onTrackChange?(currentTrackName)
  }

  // MARK: - Levels

  func setVolume(_ volume: Double) {
    masterVolume = Float(min(1, max(0, volume)))
    guard fadeTask == nil else { applyFade(position: fadePosition); return }
    activeDeck?.volume = isMuted ? 0 : masterVolume
  }

  func setMuted(_ muted: Bool) {
    isMuted = muted
    guard fadeTask == nil else { applyFade(position: fadePosition); return }
    activeDeck?.volume = isMuted ? 0 : masterVolume
  }

  func stop() {
    outputSuspended = false
    resumeDeckA = false
    resumeDeckB = false
    fadeTask?.cancel()
    fadeGeneration += 1
    fadeTask = nil
    fadeSuspendedAt = nil
    fadeSuspendedDuration = 0
    fadingIn = nil
    fadingOut = nil
    deckA?.stop()
    deckB?.stop()
    deckA = nil
    deckB = nil
    currentPool = nil
    currentURL = nil
    director.reset()
  }

  func suspendOutput() {
    guard !outputSuspended else { return }
    outputSuspended = true
    if fadeTask != nil { fadeSuspendedAt = ProcessInfo.processInfo.systemUptime }
    resumeDeckA = deckA?.isPlaying == true
    resumeDeckB = deckB?.isPlaying == true
    deckA?.pause()
    deckB?.pause()
  }

  func resumeOutput() {
    guard outputSuspended else { return }
    outputSuspended = false
    if let suspendedAt = fadeSuspendedAt {
      fadeSuspendedDuration += ProcessInfo.processInfo.systemUptime - suspendedAt
      fadeSuspendedAt = nil
    }
    if resumeDeckA { deckA?.play() }
    if resumeDeckB { deckB?.play() }
    resumeDeckA = false
    resumeDeckB = false
  }
}
