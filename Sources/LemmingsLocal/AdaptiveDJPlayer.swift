import AVFoundation
import AppKit
import NxlvKit

/// Plays the soundtrack across two decks and crossfades between them.
///
/// The player owns two questions the director does not: which track comes
/// next, and how the change is made. `AdaptiveDJDirector` decides only whether
/// the game has earned a change.
///
/// The point of the mix is travel. A change moves to a different soundtrack
/// folder where one exists, so a run drifts between the machines people played
/// this game on rather than sitting on one for hours.
///
/// One limit is worth stating plainly. A phrase-aligned change needs a beat
/// grid, and a recording carries none. Until soundtrack folders declare their
/// tempo, `atNextPhrase` fades over a musical few seconds rather than landing
/// on a bar line, and only `immediate` is exact.
@MainActor final class AdaptiveDJPlayer {
  /// How long each kind of change takes.
  private enum Fade {
    /// Long enough to read as a mix rather than a cut.
    static let phrase = 2.6
    /// The nuke. Short, and deliberately abrupt.
    static let immediate = 0.35
    static let step = 1.0 / 30.0
  }

  private var deckA: AVAudioPlayer?
  private var deckB: AVAudioPlayer?
  private var activeIsA = true
  private var director = AdaptiveDJDirector()
  private var fadeTask: Task<Void, Never>?
  private var fadeGeneration = 0
  private var fadePosition = 0.0
  private var outputSuspended = false
  private var resumeDeckA = false
  private var resumeDeckB = false
  private var fadingIn: AVAudioPlayer?
  private var fadingOut: AVAudioPlayer?

  /// Soundtracks the player supplied, keyed by folder name.
  private var pools: [String: [URL]] = [:]
  private var currentPool: String?
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

  private var activeDeck: AVAudioPlayer? { activeIsA ? deckA : deckB }
  private var idleDeck: AVAudioPlayer? { activeIsA ? deckB : deckA }

  func load(soundtracks: [String: [URL]]) {
    pools = soundtracks.filter { !$0.value.isEmpty }
  }

  /// Starts the mix, or leaves it alone when it is already running.
  func start() {
    guard !pools.isEmpty, activeDeck == nil || activeDeck?.isPlaying != true else { return }
    guard let first = pickTrack(avoiding: nil) else { return }
    deckA = makeDeck(first.url)
    activeIsA = true
    currentPool = first.pool
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

  private func makeDeck(_ url: URL) -> AVAudioPlayer? {
    guard let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
    // A track is shorter than a level, so it repeats until the mix moves on.
    player.numberOfLoops = -1
    player.prepareToPlay()
    return player
  }

  /// Chooses the next track, preferring a soundtrack the mix is not on.
  ///
  /// Every track is played before any repeats, so a long run does not keep
  /// returning to the same two tunes.
  private func pickTrack(avoiding pool: String?) -> (pool: String, url: URL)? {
    let others = pools.keys.filter { $0 != pool }
    let names = others.isEmpty ? Array(pools.keys) : others
    guard !names.isEmpty else { return nil }

    var candidates: [(String, URL)] = []
    for name in names {
      for url in pools[name] ?? [] where !playedTracks.contains(url.path) {
        candidates.append((name, url))
      }
    }
    if candidates.isEmpty {
      playedTracks.removeAll()
      for name in names {
        for url in pools[name] ?? [] { candidates.append((name, url)) }
      }
    }
    guard let choice = candidates.randomElement() else { return nil }
    playedTracks.insert(choice.1.path)
    return choice
  }

  /// Brings the next track up as the current one goes down.
  ///
  /// The two curves are equal power rather than linear, so the middle of the
  /// change does not sag. A linear pair sounds like a dip.
  private func crossfade(seconds: Double) {
    guard let next = pickTrack(avoiding: currentPool), let incoming = makeDeck(next.url) else {
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
    announce(next.url)

    // The fade runs on the main actor, because a deck is not safe to touch
    // from anywhere else.
    fadeTask = Task { @MainActor [weak self] in
      var elapsed = 0.0
      while elapsed < seconds, !Task.isCancelled {
        do { try await Task.sleep(nanoseconds: UInt64(Fade.step * 1_000_000_000)) }
        catch { return }
        guard !Task.isCancelled, self?.fadeGeneration == generation else { return }
        if self?.outputSuspended == true { continue }
        elapsed += Fade.step
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
    fadingIn = nil
    fadingOut = nil
    deckA?.stop()
    deckB?.stop()
    deckA = nil
    deckB = nil
    currentPool = nil
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
  }
}
