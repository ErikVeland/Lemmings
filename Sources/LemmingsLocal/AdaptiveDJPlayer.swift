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
  func setSpeedPitch(_ cents: Double) { recording?.setSpeedPitch(cents); module?.setSpeedPitch(cents) }

  init?(_ url: URL, repeats: Bool = true) {
    if url.pathExtension.lowercased() == "mod" {
      let player = ModuleMusicPlayer()
      player.setEnhancements(.faithful)
      player.setVolume(0)
      guard player.play(url: url) != nil else { return nil }
      module = player
    } else {
      guard let player = MusicFileDeck(url: url, repeats: repeats) else { return nil }
      player.volume = 0
      recording = player
    }
  }
  var beatInfo: (bpm: Double, delay: Double)? { module?.beatInfo }
  func setMixBass(_ gain: Float) { recording?.setMixBass(gain); module?.setMixBass(gain) }
  func play() {
    recording?.play()
    if let module {
      if module.isRunning { try? module.resumeOutput() } else { try? module.start() }
    }
  }
  func setVinyl(rate: Double, gain: Double) {
    recording?.setVinyl(rate: rate, gain: gain)
    module?.applyVinyl(rate: rate, gain: gain)
  }
  func pause() { recording?.suspendOutput(); module?.suspendOutput() }
  func stop() { recording?.stop(); module?.stop() }
}

/// Mixes level tracks and completed game-state cues.
@MainActor final class AdaptiveDJPlayer {
  /// How long each kind of change takes.
  private enum Fade {
    /// Long enough to read as a mix rather than a cut.
    static let phrase = 2.6
    static let step = 1.0 / 30.0
  }

  private var deckA: DJDeck?
  private var deckB: DJDeck?
  private var activeIsA = true
  private var director = AdaptiveDJDirector()
  private var fadeTask: Task<Void, Never>?
  private var fadeGeneration = 0
  private var fadePosition = 0.0
  private var outputSuspended = false
  private var resumeDeckA = false
  private var resumeDeckB = false
  private var fadingIn: DJDeck?
  private var fadingOut: DJDeck?
  private var playbackRate: Float = 1
  private var speedPitch: Double = 0


  /// Soundtracks the player supplied, keyed by folder name.
  private var pools: [String: [URL]] = [:]
  private var currentPool: String?
  private(set) var currentURL: URL?
  private var catalogue: SoundtrackCatalogue?
  private var catalogueRoot: URL?
  private var availablePaths: Set<String> = []

  private(set) var masterVolume: Float = 0.8
  private(set) var isMuted = false

  private(set) var currentTrackName = ""
  /// Called when the mix moves, so the status line can say what is playing.
  var onTrackChange: ((String) -> Void)?

  init() {}

  var isPlaying: Bool { playingDeckCount > 0 }
  var isCrossfading: Bool { fadeTask != nil }
  var playingDeckCount: Int { [deckA, deckB].compactMap { $0 }.filter(\.isPlaying).count }
  /// The mix needs somewhere to travel between.
  var hasTracks: Bool { !pools.isEmpty }

  private var activeDeck: DJDeck? { activeIsA ? deckA : deckB }
  private var idleDeck: DJDeck? { activeIsA ? deckB : deckA }

  func load(soundtracks: [String: [URL]], catalogueRoot: URL? = nil) {
    pools = soundtracks.filter { !$0.value.isEmpty }
    self.catalogueRoot = catalogueRoot
    catalogue = catalogueRoot.flatMap { SoundtrackCatalogue.load(at: $0) }
    availablePaths = Set(pools.values.flatMap { $0 }.compactMap { relativePath($0) })
  }

  private func relativePath(_ url: URL) -> String? {
    catalogueRoot.flatMap { SoundtrackPlayer.relativePath(url, under: $0) }
  }

  /// Resolve a composition once per level. The caller's score position, never
  /// elapsed time or a random seed, owns progression through its versions.
  @discardableResult
  func startJourney(trackID: String, cycle: Int, identity: String, fallback: URL? = nil,
                    includeAlternates: Bool = true) -> Bool {
    let selected = catalogue?.select(trackID: trackID, cycle: cycle,
      availablePaths: availablePaths, includeAlternates: includeAlternates)
    guard let url = selected.flatMap({ variant in catalogueRoot?.appendingPathComponent(variant.path) }) ?? fallback,
          FileManager.default.isReadableFile(atPath: url.path) else { return false }
    startLevel(url: url, identity: identity)
    return true
  }

  /// Starts the mix, or leaves it alone when it is already running.
  func start() {
    // A suspended or crossfading deck may not report isPlaying yet (the engine
    // starts asynchronously), so treat those states as already running too.
    guard !vinylStopping else { return }
    if vinylHeld { vinylRelease(); return }
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

  /// Level entry owns track selection. Repeated UI refreshes leave it playing.
  func startLevel(url: URL, identity: String) {
    if outputSuspended { pendingLevel = (url, identity); return }
    guard identity != levelIdentity else { return }
    guard FileManager.default.isReadableFile(atPath: url.path) else { return }
    levelIdentity = identity
    resetLevel()
    if vinylStopping {
      // The braking record finishes first. Its release starts this track.
      vinylPending = (url, identity)
      return
    }
    if vinylHeld, let deck = makeDeck(url) {
      vinylHeld = false
      deckA?.stop(); deckB?.stop()
      deckA = deck; deckB = nil; activeIsA = true; currentURL = url
      currentPool = url.deletingLastPathComponent().lastPathComponent
      deck.volume = isMuted ? 0 : masterVolume
      vinylRamp.run(.start, apply: { deck.setVinyl(rate: $0, gain: $1) }) { deck.setVinyl(rate: 1, gain: 1) }
      deck.play(); announce(url)
      return
    }
    if activeDeck != nil {
      crossfade(seconds: Fade.phrase, destination: url)
    } else {
      guard let deck = makeDeck(url) else { return }
      deckA = deck; activeIsA = true; currentURL = url
      currentPool = url.deletingLastPathComponent().lastPathComponent
      deck.volume = isMuted ? 0 : masterVolume
      deck.play(); announce(url)
    }
  }
  private var levelIdentity: String?
  private var pendingLevel: (url: URL, identity: String)?

  // MARK: - Vinyl

  private let vinylRamp = VinylRamp()
  private var vinylStopping = false
  private var vinylHeld = false
  private var vinylPending: (url: URL, identity: String)?
  private var vinylReleaseRequested = false
  private var vinylIdentity: String?

  /// Brakes the level track like a record stopped by hand.
  ///
  /// A retry calls this. `vinylRelease()` lets the track run on from the
  /// finger hold. A `startLevel` releases its own track instead, even when
  /// the attempt keeps the same identity.
  func vinylStop() {
    guard !outputSuspended, !vinylStopping, !vinylHeld else { return }
    fadeTask?.cancel()
    fadeGeneration += 1
    finishFade()
    guard let deck = activeDeck, deck.isPlaying else { return }
    idleDeck?.stop()
    if activeIsA { deckB = nil } else { deckA = nil }
    vinylIdentity = levelIdentity
    levelIdentity = nil
    vinylStopping = true
    vinylRamp.run(.stop, apply: { deck.setVinyl(rate: $0, gain: $1) }) { [weak self] in
      guard let self else { return }
      self.vinylStopping = false
      let release = self.vinylReleaseRequested
      self.vinylReleaseRequested = false
      // A resting record keeps turning silently at the slowest speed.
      self.vinylHeld = true
      if let pending = self.vinylPending {
        self.vinylPending = nil
        self.levelIdentity = nil
        self.startLevel(url: pending.url, identity: pending.identity)
      } else if release {
        self.vinylRelease()
      }
    }
  }

  /// Lets a braked track run on from the finger hold.
  func vinylRelease() {
    if vinylStopping { vinylReleaseRequested = true; return }
    guard vinylHeld, let deck = activeDeck else { return }
    vinylHeld = false
    if levelIdentity == nil { levelIdentity = vinylIdentity }
    vinylRamp.run(.start, apply: { deck.setVinyl(rate: $0, gain: $1) }) { deck.setVinyl(rate: 1, gain: 1) }
  }

  private func resetVinyl() {
    vinylRamp.cancel()
    vinylStopping = false
    vinylHeld = false
    vinylPending = nil
    vinylReleaseRequested = false
  }

  /// A new level, so every cue may happen again.
  func resetLevel() {
    director.reset()
  }

  /// Only completed wins and losses can interrupt a level track.
  func updateTelemetry(_ telemetry: AdaptiveDJEngine.Telemetry) {
    guard isPlaying, let cue = director.cue(for: telemetry) else { return }
    crossfade(seconds: Fade.phrase, victory: cue.reason == .won, failure: cue.reason == .lost)
  }

  // MARK: - Decks

  private func makeDeck(_ url: URL) -> DJDeck? {
    let role = relativePath(url).flatMap { catalogue?.entry(path: $0)?.track.role }
    let repeats = !["victory", "failure", "cue", "medal", "milestone"].contains(role ?? "")
    let deck = DJDeck(url, repeats: repeats)
    deck?.playbackRate = playbackRate
    deck?.setSpeedPitch(speedPitch)
    return deck
  }

  func setPlaybackRate(_ value: Double) {
    playbackRate = Float(min(1, max(0.5, value)))
    deckA?.playbackRate = playbackRate
    deckB?.playbackRate = playbackRate
    fadingIn?.playbackRate = playbackRate
    fadingOut?.playbackRate = playbackRate
  }

  func setSpeedPitch(_ cents: Double) {
    speedPitch = cents
    deckA?.setSpeedPitch(cents)
    deckB?.setSpeedPitch(cents)
    fadingIn?.setSpeedPitch(cents)
    fadingOut?.setSpeedPitch(cents)
  }

  private func pickTrack(avoiding pool: String?, victory: Bool = false, failure: Bool = false) -> (pool: String, url: URL)? {
    guard let catalogue, let root = catalogueRoot else { return nil }
    let variant: SoundtrackCatalogue.Variant?
    if victory || failure {
      guard let currentURL, let path = relativePath(currentURL) else { return nil }
      variant = catalogue.result(won: victory, currentPath: path, availablePaths: availablePaths)
    } else {
      variant = catalogue.select(trackID: "classic.cancan", cycle: 0, availablePaths: availablePaths)
    }
    guard let variant else { return nil }
    let url = root.appendingPathComponent(variant.path)
    guard FileManager.default.isReadableFile(atPath: url.path) else { return nil }
    return (url.deletingLastPathComponent().lastPathComponent, url)
  }

  /// Brings the next track up as the current one goes down.
  ///
  /// The two curves are equal power rather than linear, so the middle of the
  /// change does not sag. A linear pair sounds like a dip.
  private func crossfade(seconds: Double, victory: Bool = false, failure: Bool = false, destination: URL? = nil) {
    guard let next = destination.map({ (pool: $0.deletingLastPathComponent().lastPathComponent, url: $0) }) ?? pickTrack(avoiding: currentPool, victory: victory, failure: failure), let incoming = makeDeck(next.url) else {
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
    let outgoingBeat = activeDeck?.beatInfo
    let incomingBeat = incoming.beatInfo
    let beatDelay = min(1, outgoingBeat?.delay ?? 0)
    var matchedRate = playbackRate
    if let outgoingBeat, let incomingBeat {
      let ratio = outgoingBeat.bpm / incomingBeat.bpm
      if (0.92...1.08).contains(ratio) { matchedRate *= Float(ratio) }
    }
    incoming.playbackRate = matchedRate
    incoming.setMixBass(-18)
    let duration = outgoingBeat.map { max(seconds, 4 * 60 / $0.bpm) } ?? seconds
    if activeIsA { deckB = incoming } else { deckA = incoming }
    activeIsA.toggle()
    currentPool = next.pool
    currentURL = next.url
    announce(next.url)

    // The fade runs on the main actor, because a deck is not safe to touch
    // from anywhere else.
    fadeTask = Task { @MainActor [weak self] in
      var delay = beatDelay
      while delay > 0, !Task.isCancelled {
        do { try await Task.sleep(nanoseconds: UInt64(Fade.step * 1_000_000_000)) } catch { return }
        if self?.outputSuspended != true { delay -= Fade.step }
      }
      guard !Task.isCancelled, self?.fadeGeneration == generation else { return }
      while self?.outputSuspended == true {
        do { try await Task.sleep(nanoseconds: UInt64(Fade.step * 1_000_000_000)) } catch { return }
      }
      incoming.play()
      // Measure the clock, not the callbacks. A delayed main actor must not
      // stretch the fade, and suspended time must not advance it.
      var elapsed = 0.0
      var last = ProcessInfo.processInfo.systemUptime
      while elapsed < duration, !Task.isCancelled {
        do { try await Task.sleep(nanoseconds: UInt64(Fade.step * 1_000_000_000)) }
        catch { return }
        guard !Task.isCancelled, self?.fadeGeneration == generation else { return }
        let now = ProcessInfo.processInfo.systemUptime
        defer { last = now }
        if self?.outputSuspended == true { continue }
        elapsed += now - last
        self?.applyFade(position: min(1, elapsed / duration))
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
    fadingIn?.setMixBass(-18 * Float(max(0, 1 - position * 2)))
    fadingOut?.setMixBass(-18 * Float(min(1, position * 2)))
    fadingIn?.volume = target * sin(Float(position) * .pi / 2)
    fadingOut?.volume = target * cos(Float(position) * .pi / 2)
  }

  private func finishFade() {
    let outgoing = fadingOut
    outgoing?.stop()
    if deckA === outgoing { deckA = nil } else if deckB === outgoing { deckB = nil }
    fadingIn?.setMixBass(0)
    fadingIn?.playbackRate = playbackRate
    fadingIn?.volume = isMuted ? 0 : masterVolume
    fadingIn = nil
    fadingOut = nil
    fadeTask = nil
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
    resetVinyl()
    outputSuspended = false
    resumeDeckA = false
    resumeDeckB = false
    fadeTask?.cancel()
    fadeGeneration += 1
    fadeTask = nil
    fadingIn = nil
    fadingOut = nil
    deckA?.stop()
    deckB?.stop()
    deckA = nil
    deckB = nil
    currentPool = nil
    currentURL = nil
    levelIdentity = nil
    pendingLevel = nil
    director.reset()
  }

  func suspendOutput() {
    guard !outputSuspended else { return }
    outputSuspended = true
    resumeDeckA = deckA?.isPlaying == true
    resumeDeckB = deckB?.isPlaying == true
    deckA?.pause()
    deckB?.pause()
  }

  func resumeOutput() {
    guard outputSuspended else { return }
    outputSuspended = false
    if resumeDeckA { deckA?.play() }
    if resumeDeckB { deckB?.play() }
    resumeDeckA = false
    resumeDeckB = false
    if let pending = pendingLevel {
      pendingLevel = nil
      startLevel(url: pending.url, identity: pending.identity)
    }
  }
}
