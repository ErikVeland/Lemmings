import AppKit
import CryptoKit
import NxlvKit

/// One deck can play either a recording or a native ProTracker module.
@MainActor private final class DJDeck {
  private var recording: MusicFileDeck?
  private var module: ModuleMusicPlayer?
  let url: URL
  let timing: MusicTimingCatalogue.Entry?
  var openingHoldEndSourceSeconds: Double?
  var mixGain: Float = 0
  private var matchRatio: Float = 1
  var volume: Float = 0 { didSet { recording?.volume = volume; module?.setVolume(Double(volume)) } }
  var playbackRate: Float = 1 {
    didSet {
      recording?.playbackRate = playbackRate
      module?.setTempoScale(Double(playbackRate))
    }
  }
  var isPlaying: Bool { recording?.isPlaying == true || module?.isOutputRunning == true }
  func setBaseRate(_ rate: Float) {
    playbackRate = min(1.08, max(0.5, rate * matchRatio))
    let compensation = Double(playbackRate / rate)
    recording?.setMixTempoRatio(compensation); module?.setMixTempoRatio(compensation)
  }
  func matchTempo(_ ratio: Float, base: Float) { matchRatio = ratio; setBaseRate(base) }
  func setSpeedPitch(_ cents: Double) { recording?.setSpeedPitch(cents); module?.setSpeedPitch(cents) }

  init?(_ url: URL, repeats: Bool = true, timing: MusicTimingCatalogue.Entry? = nil, rhythmURL: URL? = nil,
        enhancements: ProTrackerEnhancements = .modern, profile: MusicPlaybackCatalogue.Entry? = nil) {
    self.url = url
    self.timing = timing
    if url.pathExtension.lowercased() == "mod" {
      let player = ModuleMusicPlayer()
      player.setEnhancements(enhancements)
      player.setVolume(0)
      guard player.play(url: url) != nil else { return nil }
      module = player
    } else {
      guard let player = MusicFileDeck(url: url, repeats: repeats, rhythmURL: rhythmURL, profile: profile) else { return nil }
      player.volume = 0
      recording = player
    }
  }
  var sourceSeconds: Double { recording?.sourceSeconds ?? module?.sourceSeconds ?? 0 }
  var beatInfo: (bpm: Double, delay: Double)? {
    if let timing { return timing.nextBeat(at: sourceSeconds, rate: Double(playbackRate)) }
    return module?.beatInfo
  }
  func setEnhancements(_ value: ProTrackerEnhancements) { module?.setEnhancements(value) }
  func setNukeAmount(_ amount: Float) { recording?.setNukeAmount(amount); module?.setNukeAmount(amount) }
  func setMixBass(_ gain: Float) { recording?.setMixBass(gain); module?.setMixBass(gain) }
  @discardableResult
  func play() -> Bool {
    if let recording {
      recording.play()
      return recording.isPlaying
    }
    if let module {
      do {
        if module.isRunning { try module.resumeOutput() } else { try module.start() }
      } catch { return false }
      return module.isOutputRunning
    }
    return false
  }
  func setVinyl(rate: Double, gain: Double) {
    recording?.setVinyl(rate: rate, gain: gain)
    module?.applyVinyl(rate: rate, gain: gain)
  }
  func pause(rhythmOnly: Bool = false) { recording?.suspendOutput(rhythmOnly: rhythmOnly); module?.suspendOutput(rhythmOnly: rhythmOnly) }
  func stop() { recording?.stop(); module?.stop() }
}

/// Mixes versions of the level theme, including a lift at the rescue target.
@MainActor final class AdaptiveDJPlayer {
  /// How long each kind of change takes.
  private enum Fade {
    /// Long enough to read as a mix rather than a cut.
    static let phrase = 2.6
    /// A new level should reveal its selected tune at once.
    static let levelEntry = 2.6
    static let step = 1.0 / 30.0
  }

  private enum Opening {
    static let minimumSourceSeconds = 30.0
    static let measuredBars = 16
  }

  private struct OutgoingLayer {
    let deck: DJDeck
    let gain: Float
    var startedAt: Double
    var deadline: Double
  }

  private var deckA: DJDeck?
  private var deckB: DJDeck?
  private var carryDecks: [DJDeck] = []
  private var outgoingMix: [OutgoingLayer] = []
  private var incomingStartGain: Float = 0
  private var activeIsA = true
  private var director = AdaptiveDJDirector()
  private var fadeTask: Task<Void, Never>?
  private var fadeGeneration = 0
  private var fadePosition = 0.0
  private var outputSuspended = false
  private var suspendedAtUptime: Double?
  private var pauseUsesRhythm = false
  private var resumeDeckA = false
  private var resumeDeckB = false
  private var resumeCarry: [DJDeck] = []
  private var fadingIn: DJDeck?
  private var fadingOut: DJDeck?
  private var fadeIsLevelEntry = false
  private var fadeBass = true
  private var levelOpeningHoldEndSourceSeconds: Double?
  private var suppressResultCue = false
  private var playbackRate: Float = 1
  private var speedPitch: Double = 0
  private var enhancements: ProTrackerEnhancements = .modern
  private var journeyCycle = 0
  private var allowCelebrationAlternates = true


  /// Soundtracks the player supplied, keyed by folder name.
  private var pools: [String: [URL]] = [:]
  private var currentPool: String?
  private(set) var currentURL: URL?
  private var catalogue: SoundtrackCatalogue?
  private var timingCatalogue: MusicTimingCatalogue?
  private var catalogueRoot: URL?
  private var availablePaths: Set<String> = []
  private var availableURLs: [String: URL] = [:]

  private(set) var masterVolume: Float = 0.8
  private(set) var isMuted = false

  private(set) var currentTrackName = ""
  /// Called when the mix moves, so the status line can say what is playing.
  var onTrackChange: ((String) -> Void)?

  init() {}

  var isPlaying: Bool { playingDeckCount > 0 }
  var isCrossfading: Bool { fadeTask != nil }
  var playingDeckCount: Int { allDecks.filter(\.isPlaying).count }
  /// The mix needs somewhere to travel between.
  var hasTracks: Bool { !pools.isEmpty }

  private var activeDeck: DJDeck? { activeIsA ? deckA : deckB }
  private var idleDeck: DJDeck? { activeIsA ? deckB : deckA }
  private var allDecks: [DJDeck] {
    var seen = Set<ObjectIdentifier>()
    return ([deckA, deckB].compactMap { $0 } + carryDecks).filter {
      seen.insert(ObjectIdentifier($0)).inserted
    }
  }

  private func setGain(_ gain: Float, for deck: DJDeck?) {
    guard let deck else { return }
    deck.mixGain = max(0, min(1, gain))
    deck.volume = (isMuted ? 0 : masterVolume) * deck.mixGain
  }

  private func refreshVolumes() {
    for deck in allDecks { deck.volume = (isMuted ? 0 : masterVolume) * deck.mixGain }
  }

  private func retiringLayers(for decks: [DJDeck]) -> [OutgoingLayer] {
    let now = ProcessInfo.processInfo.systemUptime
    return decks.map { deck in
      let previous = fadeIsLevelEntry ? outgoingMix.first(where: { $0.deck === deck }) : nil
      return OutgoingLayer(deck: deck, gain: deck.mixGain, startedAt: now,
        deadline: previous?.deadline ?? now + Fade.levelEntry)
    }
  }

  func load(soundtracks: [String: [URL]], catalogueRoot: URL? = nil) {
    pools = soundtracks.filter { !$0.value.isEmpty }
    self.catalogueRoot = catalogueRoot
    catalogue = catalogueRoot.flatMap { SoundtrackCatalogue.load(at: $0) }
    timingCatalogue = catalogueRoot.flatMap { MusicTimingCatalogue.load(at: $0) }
    availableURLs = [:]
    for url in pools.values.flatMap({ $0 }).sorted(by: { $0.path < $1.path }) {
      if let path = relativePath(url), availableURLs[path] == nil { availableURLs[path] = url }
    }
    availablePaths = Set(availableURLs.keys)
  }

  private func relativePath(_ url: URL) -> String? {
    catalogueRoot.flatMap { SoundtrackPlayer.cataloguePath(url, root: $0) }
  }

  /// Resolve a composition once per level. The caller's score position, never
  /// elapsed time or a random seed, owns progression through its versions.
  @discardableResult
  func startJourney(trackID: String, cycle: Int, identity: String, fallback: URL? = nil,
                    includeAlternates: Bool = true) -> Bool {
    journeyCycle = cycle
    allowCelebrationAlternates = includeAlternates
    let selected = catalogue?.select(trackID: trackID, cycle: cycle,
      availablePaths: availablePaths, includeAlternates: includeAlternates)
    guard let url = selected.flatMap({ availableURLs[$0.path] }) ?? fallback,
          FileManager.default.isReadableFile(atPath: url.path) else { return false }
    return startLevel(url: url, identity: identity)
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
    carryDecks.forEach { $0.stop() }
    carryDecks = []
    outgoingMix = []
    deckB = nil
    resumeDeckA = false
    resumeDeckB = false
    resumeCarry = []
    deckA = makeDeck(first.url)
    activeIsA = true
    currentPool = first.pool
    currentURL = first.url
    setGain(1, for: deckA)
    deckA?.play()
    announce(first.url)
  }

  /// Level entry owns track selection. Repeated UI refreshes leave it playing.
  @discardableResult
  func startLevel(url: URL, identity: String) -> Bool {
    guard identity != levelIdentity else { return true }
    guard FileManager.default.isReadableFile(atPath: url.path) else { return false }
    let canonicalURL = url.resolvingSymlinksInPath().standardizedFileURL
    if !vinylStopping && !vinylHeld && !outputSuspended,
       let continuing = allDecks.first(where: {
         $0.url.resolvingSymlinksInPath().standardizedFileURL == canonicalURL && $0.isPlaying
       }) {
      if fadeTask != nil {
        if fadingIn !== continuing || !fadeIsLevelEntry { retargetFade(to: continuing) }
      } else {
        keepPlaying(continuing)
      }
      levelIdentity = identity
      resetLevel()
      // The same recording or module keeps its original opening. A new level
      // does not restart the song or impose another opening hold.
      levelOpeningHoldEndSourceSeconds = selectedOpeningHold(for: continuing)
      return true
    }
    guard let selected = makeDeck(url) else { return false }
    if outputSuspended { pendingLevel = (url, identity); return true }
    if vinylStopping {
      // The braking record finishes first. Its release starts this track.
      vinylPending = (url, identity)
      resetLevel()
      return true
    }
    if vinylHeld {
      setGain(1, for: selected)
      guard selected.play() else { selected.stop(); return false }
      vinylHeld = false
      allDecks.forEach { $0.stop() }
      carryDecks = []
      outgoingMix = []
      deckA = selected; deckB = nil; activeIsA = true; currentURL = url
      currentPool = url.deletingLastPathComponent().lastPathComponent
      vinylRamp.run(.start, apply: { selected.setVinyl(rate: $0, gain: $1) }) { selected.setVinyl(rate: 1, gain: 1) }
      announce(url)
      levelIdentity = identity
      resetLevel()
      levelOpeningHoldEndSourceSeconds = selectedOpeningHold(for: selected)
      return true
    }
    if isPlaying {
      guard crossfade(seconds: Fade.levelEntry, destination: url, prepared: selected, immediate: true) else { return false }
    } else {
      fadeTask?.cancel()
      fadeGeneration += 1
      fadeTask = nil
      fadingIn = nil
      fadingOut = nil
      fadeIsLevelEntry = false
      fadeBass = true
      allDecks.forEach { $0.stop() }
      carryDecks = []
      outgoingMix = []
      setGain(1, for: selected)
      guard selected.play() else {
        selected.stop()
        deckA = nil; deckB = nil; currentURL = nil; currentPool = nil
        return false
      }
      deckA = selected; deckB = nil; activeIsA = true; currentURL = url
      currentPool = url.deletingLastPathComponent().lastPathComponent
      announce(url)
    }
    levelIdentity = identity
    resetLevel()
    levelOpeningHoldEndSourceSeconds = selectedOpeningHold(for: selected)
    return true
  }
  private var levelIdentity: String?
  private var pendingLevel: (url: URL, identity: String)?

  private func openingHoldEnd(for deck: DJDeck) -> Double {
    let minimum = deck.sourceSeconds + Opening.minimumSourceSeconds
    guard let timing = deck.timing, timing.supportsBarMixing,
          timing.downbeats.count > Opening.measuredBars else { return minimum }
    return max(minimum, timing.downbeats[Opening.measuredBars])
  }

  private func selectedOpeningHold(for deck: DJDeck) -> Double {
    if let hold = deck.openingHoldEndSourceSeconds { return hold }
    let hold = openingHoldEnd(for: deck)
    deck.openingHoldEndSourceSeconds = hold
    return hold
  }

  private func retargetFade(to deck: DJDeck) {
    let otherDecks = allDecks.filter { $0 !== deck && $0.isPlaying }
    guard !otherDecks.isEmpty else { keepPlaying(deck); return }
    let originalGain = deck.mixGain
    let layers = retiringLayers(for: otherDecks)
    fadeTask?.cancel()
    fadeGeneration += 1
    let generation = fadeGeneration
    let primaryOutgoing = otherDecks.max(by: { $0.mixGain < $1.mixGain })!
    outgoingMix = layers
    incomingStartGain = originalGain
    carryDecks = otherDecks.filter { $0 !== primaryOutgoing }
    deckA = primaryOutgoing
    deckB = deck
    activeIsA = false
    fadingOut = primaryOutgoing
    fadingIn = deck
    fadeIsLevelEntry = true
    fadeBass = false
    deck.setMixBass(0)
    otherDecks.forEach { $0.setMixBass(0) }
    currentURL = deck.url
    currentPool = deck.url.deletingLastPathComponent().lastPathComponent
    announce(deck.url)
    let position = originalGain < 0.08 ? 0.08 : 0
    applyFade(position: position)
    runLevelEntryFade(from: position, generation: generation)
  }

  private func runLevelEntryFade(from position: Double, generation: Int) {
    fadeTask = Task { @MainActor [weak self] in
      var elapsed = Fade.levelEntry * position
      var last = ProcessInfo.processInfo.systemUptime
      while elapsed < Fade.levelEntry, !Task.isCancelled {
        do { try await Task.sleep(nanoseconds: UInt64(Fade.step * 1_000_000_000)) }
        catch { return }
        guard !Task.isCancelled, self?.fadeGeneration == generation else { return }
        let now = ProcessInfo.processInfo.systemUptime
        defer { last = now }
        if self?.outputSuspended == true { continue }
        elapsed += now - last
        self?.applyFade(position: min(1, elapsed / Fade.levelEntry))
      }
      guard !Task.isCancelled, self?.fadeGeneration == generation else { return }
      self?.finishFade()
    }
  }

  private func keepPlaying(_ deck: DJDeck) {
    fadeTask?.cancel()
    fadeGeneration += 1
    fadeTask = nil
    fadingIn = nil
    fadingOut = nil
    outgoingMix = []
    incomingStartGain = 0
    fadeIsLevelEntry = false
    allDecks.filter { $0 !== deck }.forEach { $0.stop() }
    carryDecks = []
    deckA = deck
    deckB = nil
    activeIsA = true
    deck.setMixBass(0)
    deck.matchTempo(1, base: playbackRate)
    setGain(1, for: deck)
    currentURL = deck.url
    currentPool = deck.url.deletingLastPathComponent().lastPathComponent
  }

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
    suppressResultCue = false
  }

  /// Reaching the rescue target allows one musical transition.
  func updateTelemetry(_ telemetry: AdaptiveDJEngine.Telemetry) {
    guard isPlaying, let deck = activeDeck, let holdEnd = levelOpeningHoldEndSourceSeconds else { return }
    if telemetry.isComplete && deck.sourceSeconds < holdEnd { suppressResultCue = true }
    guard !suppressResultCue, deck.sourceSeconds >= holdEnd,
          let cue = director.cue(for: telemetry) else { return }
    _ = crossfade(seconds: Fade.phrase, victory: cue.reason == .won, failure: cue.reason == .lost)
  }

  // MARK: - Decks

  private var nukeAmount: Float = 0
  func setNukeAmount(_ amount: Float) {
    nukeAmount = amount
    allDecks.forEach { $0.setNukeAmount(amount) }
  }

  private func makeDeck(_ url: URL) -> DJDeck? {
    let role = relativePath(url).flatMap { catalogue?.entry(path: $0)?.track.role }
    let repeats = !["victory", "failure", "cue", "medal", "milestone"].contains(role ?? "")
    // A replacement file must not inherit the previous recording's beat grid.
    var timing = relativePath(url).flatMap { timingCatalogue?.entry(path: $0) }
    if let candidate = timing {
      let hash = (try? Data(contentsOf: url, options: .mappedIfSafe)).map {
        SHA256.hash(data: $0).map { String(format: "%02x", $0) }.joined()
      }
      if hash != candidate.expectedSHA256 { timing = nil }
    }
    let deck = DJDeck(url, repeats: repeats, timing: timing,
      rhythmURL: MusicLibrary.rhythmURL(for: url, musicRoot: catalogueRoot), enhancements: enhancements,
      profile: SoundtrackPlayer.playbackProfile(for: url, musicRoot: catalogueRoot))
    deck?.playbackRate = playbackRate
    deck?.setSpeedPitch(speedPitch)
    deck?.setNukeAmount(nukeAmount)
    return deck
  }

  /// Apply the shared MOD mix to every deck and all later tracks.
  func setEnhancements(_ value: ProTrackerEnhancements) {
    guard enhancements != value else { return }
    enhancements = value
    allDecks.forEach { $0.setEnhancements(value) }
  }

  func setPlaybackRate(_ value: Double) {
    playbackRate = Float(min(1, max(0.5, value)))
    allDecks.forEach { $0.setBaseRate(playbackRate) }
  }

  func setSpeedPitch(_ cents: Double) {
    speedPitch = cents
    allDecks.forEach { $0.setSpeedPitch(cents) }
  }

  private func pickTrack(avoiding pool: String?, victory: Bool = false, failure: Bool = false) -> (pool: String, url: URL)? {
    guard let catalogue, let root = catalogueRoot else { return nil }
    let variant: SoundtrackCatalogue.Variant?
    if victory || failure {
      guard let currentURL, let path = relativePath(currentURL) else { return nil }
      variant = victory
        ? catalogue.celebration(currentPath: path, cycle: journeyCycle,
            availablePaths: availablePaths, includeAlternates: allowCelebrationAlternates)
        : catalogue.result(won: false, currentPath: path, availablePaths: availablePaths)
    } else {
      variant = catalogue.select(trackID: "classic.cancan", cycle: 0, availablePaths: availablePaths)
    }
    guard let variant, !victory || variant.path != currentURL.flatMap({ relativePath($0) }) else { return nil }
    let url = availableURLs[variant.path] ?? root.appendingPathComponent(variant.path)
    guard FileManager.default.isReadableFile(atPath: url.path) else { return nil }
    return (url.deletingLastPathComponent().lastPathComponent, url)
  }

  /// Brings the next track up as the current one goes down.
  ///
  /// The two curves are equal power rather than linear, so the middle of the
  /// change does not sag. A linear pair sounds like a dip.
  @discardableResult
  private func crossfade(seconds: Double, victory: Bool = false, failure: Bool = false,
                         destination: URL? = nil, prepared: DJDeck? = nil, immediate: Bool = false) -> Bool {
    guard let next = destination.map({ (pool: $0.deletingLastPathComponent().lastPathComponent, url: $0) }) ?? pickTrack(avoiding: currentPool, victory: victory, failure: failure), let incoming = prepared ?? makeDeck(next.url) else {
      return false
    }
    if immediate {
      setGain(0, for: incoming)
      guard incoming.play() else { incoming.stop(); return false }
    }
    let oldMix = immediate ? allDecks.filter(\.isPlaying) : []
    let oldLayers = immediate ? retiringLayers(for: oldMix) : []
    fadeTask?.cancel()
    fadeGeneration += 1
    let generation = fadeGeneration
    if immediate {
      let primaryOutgoing = oldMix.max(by: { $0.mixGain < $1.mixGain })
      outgoingMix = oldLayers
      incomingStartGain = 0
      carryDecks = oldMix.filter { $0 !== primaryOutgoing }
      deckA = primaryOutgoing
      deckB = incoming
      activeIsA = false
      fadingOut = primaryOutgoing
    } else {
      settleInterruptedFade()
      fadingOut = activeDeck
      outgoingMix = []
      incomingStartGain = 0
    }
    fadingIn = incoming
    fadePosition = 0
    fadeIsLevelEntry = immediate
    fadeBass = !immediate
    setGain(0, for: incoming)
    let outgoingBeat = fadingOut?.beatInfo
    let incomingBeat = incoming.beatInfo
    var beatDelay = immediate ? 0 : min(1, outgoingBeat?.delay ?? 0)
    var matchedRate = playbackRate
    if !immediate, let outgoingBeat, let incomingBeat {
      let ratio = outgoingBeat.bpm / incomingBeat.bpm
      if (0.92...1.08).contains(ratio) { matchedRate *= Float(ratio) }
    }
    matchedRate = min(1.08, max(0.5, matchedRate))
    incoming.matchTempo(matchedRate / playbackRate, base: playbackRate)
    incoming.setMixBass(immediate ? 0 : -18)
    var duration = seconds
    var preRoll = 0.0
    if !immediate, let outgoing = fadingOut, let grid = outgoing.timing, let incomingGrid = incoming.timing,
       let plan = grid.barTransition(to: incomingGrid, at: outgoing.sourceSeconds,
         outgoingRate: Double(outgoing.playbackRate), incomingRate: Double(matchedRate), minimumDuration: seconds) {
      beatDelay = plan.delay
      preRoll = plan.preRoll
      duration = plan.duration
    }
    if !immediate {
      if activeIsA { deckB = incoming } else { deckA = incoming }
      activeIsA.toggle()
    }
    currentPool = next.pool
    currentURL = next.url
    announce(next.url)
    if immediate {
      applyFade(position: 0.08)
      runLevelEntryFade(from: 0.08, generation: generation)
      return true
    }

    // The fade runs on the main actor, because a deck is not safe to touch
    // from anywhere else.
    fadeTask = Task { @MainActor [weak self] in
      var delay = beatDelay
      var delayTime = ProcessInfo.processInfo.systemUptime
      while delay > 0, !Task.isCancelled {
        do { try await Task.sleep(nanoseconds: UInt64(Fade.step * 1_000_000_000)) } catch { return }
        let now = ProcessInfo.processInfo.systemUptime
        if self?.outputSuspended != true { delay -= now - delayTime }
        delayTime = now
      }
      guard !Task.isCancelled, self?.fadeGeneration == generation else { return }
      while self?.outputSuspended == true {
        do { try await Task.sleep(nanoseconds: UInt64(Fade.step * 1_000_000_000)) } catch { return }
      }
      guard !Task.isCancelled, self?.fadeGeneration == generation else { return }
      if !immediate {
        guard incoming.play() else {
          self?.settleInterruptedFade()
          if let restored = self?.currentURL { self?.announce(restored) }
          return
        }
        _ = self?.selectedOpeningHold(for: incoming)
      }
      // Let a short pickup play silently so the fade starts on both downbeats.
      var pickup = preRoll
      var pickupTime = ProcessInfo.processInfo.systemUptime
      while pickup > 0, !Task.isCancelled {
        do { try await Task.sleep(nanoseconds: UInt64(Fade.step * 1_000_000_000)) } catch { return }
        guard self?.fadeGeneration == generation else { return }
        let now = ProcessInfo.processInfo.systemUptime
        if self?.outputSuspended != true { pickup -= now - pickupTime }
        pickupTime = now
      }
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
    return true
  }

  /// Equal-power curves rather than linear ones. A linear pair sags in the
  /// middle of the change and sounds like a dip.
  private func applyFade(position: Double) {
    fadePosition = position
    let incomingGain = sin(Float(position) * .pi / 2)
    let outgoingGain = cos(Float(position) * .pi / 2)
    if fadeIsLevelEntry {
      let now = ProcessInfo.processInfo.systemUptime
      for item in outgoingMix {
        let remaining = max(0.001, item.deadline - item.startedAt)
        let progress = min(1, max(0, (now - item.startedAt) / remaining))
        setGain(item.gain * cos(Float(progress) * .pi / 2), for: item.deck)
        if progress >= 1 { item.deck.stop() }
      }
      let remaining = incomingStartGain * outgoingGain
      setGain(sqrt(remaining * remaining + incomingGain * incomingGain), for: fadingIn)
      return
    }
    if fadeBass {
      fadingIn?.setMixBass(-18 * Float(max(0, 1 - position * 2)))
      fadingOut?.setMixBass(-18 * Float(min(1, position * 2)))
    }
    setGain(incomingGain, for: fadingIn)
    setGain(outgoingGain, for: fadingOut)
  }

  private func finishFade() {
    guard let incoming = fadingIn else { return }
    allDecks.filter { $0 !== incoming }.forEach { $0.stop() }
    carryDecks = []
    deckA = incoming
    deckB = nil
    activeIsA = true
    incoming.setMixBass(0)
    incoming.matchTempo(1, base: playbackRate)
    setGain(1, for: incoming)
    fadingIn = nil
    fadingOut = nil
    outgoingMix = []
    incomingStartGain = 0
    fadeTask = nil
    fadeIsLevelEntry = false
    fadeBass = true
  }

  private func settleInterruptedFade() {
    guard let outgoing = fadingOut, let incoming = fadingIn else { return }
    let keep = incoming.isPlaying && fadePosition >= 0.5 ? incoming : outgoing
    allDecks.filter { $0 !== keep }.forEach { $0.stop() }
    carryDecks = []
    deckA = keep
    deckB = nil
    activeIsA = true
    keep.setMixBass(0); keep.matchTempo(1, base: playbackRate)
    setGain(1, for: keep)
    currentURL = keep.url
    fadingIn = nil; fadingOut = nil; fadeTask = nil
    outgoingMix = []
    incomingStartGain = 0
    fadeIsLevelEntry = false
    fadeBass = true
  }

  private func announce(_ url: URL) {
    currentTrackName = url.deletingPathExtension().lastPathComponent
    onTrackChange?(currentTrackName)
  }

  // MARK: - Levels

  func setVolume(_ volume: Double) {
    masterVolume = Float(min(1, max(0, volume)))
    refreshVolumes()
  }

  func setMuted(_ muted: Bool) {
    isMuted = muted
    refreshVolumes()
  }

  func stop() {
    resetVinyl()
    outputSuspended = false
    suspendedAtUptime = nil
    resumeDeckA = false
    resumeDeckB = false
    resumeCarry = []
    fadeTask?.cancel()
    fadeGeneration += 1
    fadeTask = nil
    fadingIn = nil
    fadingOut = nil
    fadeIsLevelEntry = false
    allDecks.forEach { $0.stop() }
    deckA = nil
    deckB = nil
    carryDecks = []
    outgoingMix = []
    incomingStartGain = 0
    currentPool = nil
    currentURL = nil
    levelIdentity = nil
    pendingLevel = nil
    director.reset()
    levelOpeningHoldEndSourceSeconds = nil
    suppressResultCue = false
    fadeBass = true
  }

  func suspendOutput(rhythmOnly: Bool = false) {
    guard !outputSuspended || rhythmOnly != pauseUsesRhythm else { return }
    if !outputSuspended {
      suspendedAtUptime = ProcessInfo.processInfo.systemUptime
      resumeDeckA = deckA?.isPlaying == true
      resumeDeckB = deckB?.isPlaying == true
      resumeCarry = carryDecks.filter(\.isPlaying)
    }
    outputSuspended = true
    pauseUsesRhythm = rhythmOnly
    if resumeDeckA { deckA?.pause(rhythmOnly: rhythmOnly) }
    if resumeDeckB { deckB?.pause(rhythmOnly: rhythmOnly) }
    resumeCarry.forEach { $0.pause(rhythmOnly: rhythmOnly) }
  }

  func resumeOutput() {
    guard outputSuspended else { return }
    let interruptedDestination = fadingIn?.url
    let interruptedLevelEntry = fadeIsLevelEntry
    if let suspendedAtUptime {
      let paused = ProcessInfo.processInfo.systemUptime - suspendedAtUptime
      for index in outgoingMix.indices {
        outgoingMix[index].startedAt += paused
        outgoingMix[index].deadline += paused
      }
    }
    suspendedAtUptime = nil
    outputSuspended = false
    pauseUsesRhythm = false
    if resumeDeckA { deckA?.play() }
    if resumeDeckB { deckB?.play() }
    resumeCarry.forEach { _ = $0.play() }
    resumeDeckA = false
    resumeDeckB = false
    resumeCarry = []
    if let pending = pendingLevel {
      pendingLevel = nil
      startLevel(url: pending.url, identity: pending.identity)
    } else if let destination = interruptedDestination, !interruptedLevelEntry {
      // Rhythm playback and vinyl stops advance the decks differently. Plan
      // again from the audible deck's current grid when play resumes.
      fadeTask?.cancel()
      fadeGeneration += 1
      settleInterruptedFade()
      if currentURL != destination {
        crossfade(seconds: interruptedLevelEntry ? Fade.levelEntry : Fade.phrase,
          destination: destination, immediate: interruptedLevelEntry)
      }
    }
  }
}
