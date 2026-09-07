// Appended to main.swift by the runner to exercise private app wiring directly.
private struct IntegrationFailure: Error { let message: String }
private func check(_ value: @autoclosure () -> Bool, _ message: String) throws {
  if !value() { throw IntegrationFailure(message: message) }
}

private final class FinalTickSession: GameSession {
  let levelWidth = 320, levelHeight = 160, ticksPerSecond = 17
  let lemmings: [SessionLemming] = []
  let entranceX: Int? = nil
  let released = 1, total = 1, required = 1, rate = 50
  let rateLabel = "Rate"
  let remainingSeconds: Int? = 1
  let isNuking = false, supportsRewind = true
  let skills: [SessionSkill] = []
  let lastCues: [ClassicSoundEffect] = []
  private(set) var currentTick = 0
  let saved: Int
  let finalTick: Int
  init(win: Bool, finalTick: Int = 1) { saved = win ? 1 : 0; self.finalTick = finalTick }
  var isComplete: Bool { currentTick >= finalTick }
  var didWin: Bool { isComplete && saved == 1 }
  func tick() { currentTick += 1 }
  func assign(skillIndex: Int, to lemmingID: Int) -> String? { nil }
  func adjustRate(by delta: Int) {}
  func nuke() {}
  func rewind(seconds: Double) -> Bool { false }
  func stepBackward() -> Bool { false }
  func stepForward() -> Bool { tick(); return true }
}

extension AppDelegate {
  fileprivate func testElapsedTimeAndAudioRecovery() async throws {
    phase = .playing
    isPaused = false
    lastStepTime = nil
    accumulator = 0
    let running = FinalTickSession(win: false, finalTick: 1000)
    session = running
    step(at: 1)
    step(at: 1.1)
    step(at: 1.2)
    try check(running.currentTick == 3, "missed display callbacks slowed the simulation")
    step(at: 1000)
    try check(running.currentTick <= 8, "wake caused an unbounded simulation catch-up")
    var updated = settings
    updated.music = .amigaModules
    apply(updated)
    suspendAudioOutput()
    try check(!music.isOutputRunning, "sleep did not suspend module output")
    wakeAudioOutput()
    try await Task.sleep(for: .milliseconds(100))
    try check(music.isOutputRunning, "wake did not restore module output")
    for source in [ClassicMusicSource.adaptiveDJ, .remix(name: soundtrackLibrary.keys.sorted()[0])] {
      updated.music = source
      apply(updated)
      suspendAudioOutput()
      try check(!dj.isPlaying && !soundtrack.isPlaying, "sleep left a recording playing")
      wakeAudioOutput()
      try await Task.sleep(for: .milliseconds(100))
      try check(dj.isPlaying || soundtrack.isPlaying, "wake did not restore recorded audio")
    }
    suspendCurrentEngine()
    resumeAudioOutput()
    try await Task.sleep(for: .milliseconds(100))
    try check(!music.isRunning && !dj.isPlaying && !soundtrack.isPlaying, "wake resurrected a stopped source")
    print("PASS elapsed-time catch-up and audio interruption recovery")
  }
  fileprivate func testMusicTransitions() throws {
    settings.music = .silent
    music.loadLibrary(at: URL(fileURLWithPath: "Sources/Music/lemmings_music_mod"))
    soundtrackLibrary = SoundtrackPlayer.soundtracks(at: URL(fileURLWithPath: "Sources/Music"))
    dj.load(soundtracks: soundtrackLibrary)
    try check(!music.library.isEmpty && !soundtrackLibrary.isEmpty, "missing audio fixtures")
    let recording = ClassicMusicSource.remix(name: soundtrackLibrary.keys.sorted()[0])
    let sources: [ClassicMusicSource] = [.amigaModules, recording, .adaptiveDJ, .silent]
    for from in sources {
      for to in sources {
        for source in [from, to] {
          var updated = settings
          updated.music = source
          updated.musicVolume = 0
          updated.soundVolume = 0
          apply(updated)
        }
        try check(music.isRunning == (to == .amigaModules), "module engine wrong after \(from) -> \(to)")
        try check(soundtrack.isPlaying == (to == recording), "recording wrong after \(from) -> \(to)")
        try check(dj.isPlaying == (to == .adaptiveDJ), "DJ wrong after \(from) -> \(to)")
      }
    }
    settings.music = .amigaModules
    for shuffled in [ClassicMusicSource.adaptiveDJ, recording] {
      levelMusic = shuffled
      playMusicForCurrentLevel()
      apply(settings)
      try check(shuffled == .adaptiveDJ ? dj.isPlaying : soundtrack.isPlaying,
        "applying settings stopped the shuffled source")
    }
    levelMusic = nil
    suspendCurrentEngine()
    print("PASS all 16 music source transitions and settings applied during shuffled playback")
  }

  fileprivate func testSavedAudioAndBanks() throws {
    UserDefaults.standard.set(false, forKey: "AudioMuted")
    UserDefaults.standard.set(true, forKey: musicPresetKey)
    for silent in [false, true] {
      let saved = ClassicSettings(music: silent ? .silent : .amigaModules,
        musicStyle: .faithful, musicVolume: 0.12,
        sound: silent ? .silent : .macintoshResources, soundVolume: 0.23)
      UserDefaults.standard.set(try JSONEncoder().encode(saved), forKey: settingsKey)
      restoreSettings()
      applyAudioSettings()
      try check(music.muted == silent && soundtrack.muted == silent && dj.isMuted == silent,
        "saved music silence was not applied")
      try check(effects.muted == silent, "saved sound silence was not applied")
      try check(abs(music.volume - 0.12) < 0.001 && abs(effects.volume - 0.23) < 0.001
        && abs(soundtrack.volume - 0.12) < 0.001 && abs(dj.masterVolume - 0.12) < 0.001,
        "saved volumes were not applied to every player")
      try check(!music.usesModernPreset, "legacy preset overrode current settings")
    }
    var updated = settings
    updated.musicVolume = 0
    updated.soundVolume = 0
    updated.sound = .macintoshResources
    apply(updated)
    let macEffects = effects.loadedEffects
    try check(!macEffects.isEmpty, "bundled Macintosh bank did not load")
    updated.sound = .amigaVoices
    apply(updated)
    let amigaEffects = effects.loadedEffects
    try check(!amigaEffects.isEmpty && amigaEffects != macEffects, "Amiga bank did not replace Macintosh")
    updated.sound = .macintoshResources
    apply(updated)
    try check(effects.loadedEffects == macEffects, "Macintosh bank did not return")
    print("PASS saved silence, volume and preset; live Macintosh/Amiga bank replacement")
  }

  fileprivate func testGlobalMuteAndStop() throws {
    for source in [ClassicMusicSource.adaptiveDJ, .remix(name: soundtrackLibrary.keys.sorted()[0])] {
      var updated = settings
      updated.music = source
      apply(updated)
      audioMuted = false
      toggleMute()
      try check(music.muted && soundtrack.muted && dj.isMuted && effects.muted,
        "global mute omitted a player")
      restoreSettings()
      try check(audioMuted, "global mute did not persist")
      toggleMute()
      try check(!soundtrack.muted && !dj.isMuted, "recordings did not unmute")
      suspendCurrentEngine()
      try check(!music.isRunning && !effects.isRunning && !soundtrack.isPlaying && !dj.isPlaying,
        "title suspension left audio playing")
    }
    print("PASS global mute persists and title suspension stops all players")
  }

  fileprivate func testCRTInput() async throws {
    phase = .playing
    settings.display = .monitor
    panel.panelImage = nil
    panel.macArtwork = nil
    panel.session = FinalTickSession(win: false)
    panel.isMenuMode = false
    applyDisplayMode()
    guard let frame = composeNativeFrame() else { throw IntegrationFailure(message: "no CRT frame") }
    try check(frame.width == 320 && frame.height == 200, "CRT source inherited Retina scale")
    crtView.setSource(frame)
    crtView.settings.curvature = 0
    let mapped = crtView.sourcePoint(from: CGPoint(x: crtView.bounds.midX, y: crtView.bounds.height * 0.1))
    try check(abs((mapped?.y ?? 0) - 180) < 0.01, "bottom panel did not map to source row 180")
    crtView.settings.curvature = 10
    let edge = crtView.sourcePoint(from: CGPoint(x: crtView.bounds.width * 0.9, y: crtView.bounds.height * 0.2))
    try check(abs((edge?.x ?? 0) - 288.4608) < 0.01, "CRT input disagrees with shader sampling")
    var presses = 0
    panel.onButton = { if $0 == .rateDown { presses += 1 } }
    tubeClick(CGPoint(x: 20, y: 180))
    try await Task.sleep(for: .milliseconds(450))
    try check(presses >= 3, "detached CRT panel did not repeat a held rate button")
    crtView.onMouseUp?()
    let released = presses
    try await Task.sleep(for: .milliseconds(100))
    try check(presses == released, "CRT release did not stop repetition")
    var scrolled: Double?
    panel.levelSize = CGSize(width: 1600, height: 160)
    panel.onMinimapScroll = { scrolled = $0 }
    crtView.onMouseDragged?(CGPoint(x: 250, y: 180))
    try check(scrolled != nil, "CRT minimap drag did not scroll")
    settings.display = .flat
    applyDisplayMode()
    print("PASS CRT dimensions, shader coordinates, held rate, release and minimap drag")
  }

  fileprivate func testInterruptedFade() async throws {
    dj.setVolume(0)
    dj.start()
    dj.resetLevel()
    var telemetry = AdaptiveDJEngine.Telemetry(releasedCount: 10, totalCount: 10,
      savedCount: 1, requiredCount: 5, releaseRate: 50, dangerCount: 0, remainingSeconds: 300)
    dj.updateTelemetry(telemetry)
    try await Task.sleep(for: .milliseconds(80))
    telemetry.isNuking = true
    dj.updateTelemetry(telemetry)
    try await Task.sleep(for: .milliseconds(80))
    try check(dj.isCrossfading && dj.playingDeckCount == 2, "cancelled fade finished the new transition")
    try await Task.sleep(for: .milliseconds(500))
    try check(!dj.isCrossfading && dj.playingDeckCount == 1, "fade did not retire its outgoing deck")
    dj.resetLevel()
    dj.updateTelemetry(telemetry)
    dj.stop()
    dj.start()
    try await Task.sleep(for: .milliseconds(100))
    try check(dj.isPlaying && dj.playingDeckCount == 1, "cancelled fade damaged restarted playback")
    dj.stop()
    print("PASS overlapping DJ cues, fade completion and stop/start cancellation")
  }

  fileprivate func testSteppedCompletion() throws {
    buildInterface()
    window.orderOut(nil)
    for fan in [false, true] {
      for win in [false, true] {
        let label = "step-\(fan)-\(win)-\(UUID())"
        var gameFlow = ClassicGameFlow(ranks: [ClassicRank(name: "Test", levelIndices: [0, 1])])
        gameFlow.startGame()
        gameFlow.selectRank(0)
        gameFlow.beginPlaying()
        flow = gameFlow
        phase = .playing
        session = FinalTickSession(win: win)
        fanPlaying = fan
        fanPack = URL(fileURLWithPath: "/test-pack.zip")
        fanQueue = [FanLevelLibrary.Entry(file: "test.lvl", section: nil, label: label)]
        stepForward()
        try check(phase == .results, "single-step did not show results (fan=\(fan), win=\(win))")
        if fan {
          try check(FanLevelLibrary.Progress.hasPassed(pack: fanPack!, label: label) == win,
            "single-step recorded the wrong fan result")
        } else {
          try check(flow?.hasPassed(rank: "Test", position: 0) == win,
            "single-step recorded the wrong campaign result")
        }
        finishSessionIfNeeded()
        try check(phase == .results, "completion was not idempotent")
      }
    }
    fanPlaying = false
    print("PASS final single-step handles wins, losses, campaign and fan progress")
  }
}

let testApp = NSApplication.shared
guard let testDomain = Bundle.main.bundleIdentifier,
  testDomain.hasPrefix("academy.glasscode.lemmings.integration-tests") else { exit(2) }
UserDefaults.standard.removePersistentDomain(forName: testDomain)
testApp.setActivationPolicy(.accessory)
Task { @MainActor in
  do {
    let subject = AppDelegate()
    try subject.testSteppedCompletion()
    try subject.testMusicTransitions()
    try subject.testSavedAudioAndBanks()
    try subject.testGlobalMuteAndStop()
    try await subject.testCRTInput()
    try await subject.testInterruptedFade()
    try await subject.testElapsedTimeAndAudioRecovery()
    print("App integration tests passed.")
    exit(0)
  } catch {
    print("FAIL \(error)")
    exit(1)
  }
}
testApp.run()
