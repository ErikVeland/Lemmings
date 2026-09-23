import AppKit
import NxlvKit

/// One deck can play either a recording or a native ProTracker module.
@MainActor private final class DJDeck {
  private var recording: MusicFileDeck?
  private var module: ModuleMusicPlayer?
  var volume: Float = 0 { didSet { recording?.volume = volume; module?.setVolume(Double(volume)) } }
  var playbackRate: Float = 1 {
    didSet {
      recording?.playbackRate = playbackRate
      module?.setTempoScale(Double(playbackRate))
    }
  }
  var isPlaying: Bool { recording?.isPlaying == true || module?.isOutputRunning == true }

  init?(_ url: URL) {
    if url.pathExtension.lowercased() == "mod" {
      let player = ModuleMusicPlayer()
      player.setEnhancements(.modern)
      player.setVolume(0)
      guard player.play(url: url) != nil else { return nil }
      module = player
    } else {
      guard let player = MusicFileDeck(url: url) else { return nil }
      player.volume = 0
      recording = player
    }
  }
  func play() {
    recording?.play()
    if let module {
      if module.isRunning { try? module.resumeOutput() } else { try? module.start() }
    }
  }
  func pause() { recording?.suspendOutput(); module?.suspendOutput() }
  func stop() { recording?.stop(); module?.stop() }
}

/// Mixes recordings and modules. Gameplay energy shapes each phrase change.
@MainActor final class AdaptiveDJPlayer {
  /// How long each kind of change takes.
  private enum Fade {
    /// Long enough to read as a mix rather than a cut.
    static let phrase = 2.6
    /// The nuke still moves quickly, but leaves room for the outgoing phrase.
    static let immediate = 1.1
    static let step = 1.0 / 30.0
  }

  private var deckA: DJDeck?
  private var deckB: DJDeck?
  private var activeIsA = true
  private var director = AdaptiveDJDirector()
  private var energyEngine = AdaptiveDJEngine()
  private var currentEnergy: AdaptiveDJEngine.DJEnergyLevel = .chill
  private var lastEnergyChangeAt = -Double.infinity
  private var fadeTask: Task<Void, Never>?
  private var rotationTask: Task<Void, Never>?
  private var fadeGeneration = 0
  private var fadePosition = 0.0
  private var fadeSuspendedAt: TimeInterval?
  private var fadeSuspendedDuration: TimeInterval = 0
  private var outputSuspended = false
  private var resumeDeckA = false
  private var resumeDeckB = false
  private var fadingIn: DJDeck?
  private var fadingOut: DJDeck?
  private var playbackRate: Float = 1

  /// Keep the megamix moving even when the level has no state cue.
  private let rotationInterval: TimeInterval = 64

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
    let next = soundtracks.filter { !$0.value.isEmpty }
    let changed = Set(pools.values.flatMap { $0.map(\.path) })
      != Set(next.values.flatMap { $0.map(\.path) })
    pools = next
    // A seasonal pool can replace the regular pool while a level is already
    // audible. Crossfade into it so a Holiday level starts with Holiday music.
    if changed, isPlaying, !outputSuspended { crossfade(seconds: Fade.phrase) }
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
    armRotation()
  }

  /// A new level, so every cue may happen again.
  func resetLevel() {
    director.reset()
    energyEngine = AdaptiveDJEngine()
    currentEnergy = .chill
    lastEnergyChangeAt = -Double.infinity
  }

  /// Offers the game state to the director and moves the mix when its energy changes.
  func updateTelemetry(_ telemetry: AdaptiveDJEngine.Telemetry) {
    guard isPlaying else { return }
    let energy = energyEngine.evaluate(telemetry: telemetry)
    let cue = director.cue(for: telemetry)
    let now = ProcessInfo.processInfo.systemUptime
    let urgent = cue != nil || energy == .nukeDrop || energy == .victory
    let energyChanged = energy != currentEnergy
        && (urgent || now - lastEnergyChangeAt >= 3.0)
    guard energyChanged || cue != nil else { return }
    if energyChanged {
      currentEnergy = energy
      lastEnergyChangeAt = now
    }
    let isVictory = energy == .victory || cue?.reason == .won
    let duration = cue?.timing == .immediate ? Fade.immediate : Fade.phrase
    crossfade(seconds: duration, victory: isVictory)
  }

  // MARK: - Decks

  private func makeDeck(_ url: URL) -> DJDeck? {
    let deck = DJDeck(url)
    deck?.playbackRate = playbackRate
    return deck
  }

  func setPlaybackRate(_ value: Double) {
    playbackRate = Float(min(1, max(0.5, value)))
    deckA?.playbackRate = playbackRate
    deckB?.playbackRate = playbackRate
    fadingIn?.playbackRate = playbackRate
    fadingOut?.playbackRate = playbackRate
  }

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
  private func crossfade(seconds: Double, victory: Bool = false) {
    guard let next = pickTrack(avoiding: currentPool, victory: victory), let incoming = makeDeck(next.url) else {
      return
    }
    rotationTask?.cancel()
    rotationTask = nil
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
      self?.armRotation()
    }
  }

  private func armRotation() {
    rotationTask?.cancel()
    rotationTask = Task { @MainActor [weak self] in
      do { try await Task.sleep(nanoseconds: UInt64(self?.rotationInterval ?? 64) * 1_000_000_000) }
      catch { return }
      guard let self, !self.outputSuspended, self.isPlaying, self.fadeTask == nil else { return }
      self.crossfade(seconds: Fade.phrase)
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
    rotationTask?.cancel()
    rotationTask = nil
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
    armRotation()
    resumeDeckA = false
    resumeDeckB = false
  }
}
