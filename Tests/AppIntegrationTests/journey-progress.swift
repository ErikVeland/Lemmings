#if os(macOS)
@MainActor extension AppDelegate {
  fileprivate func testHomeJourneyProgressCounts() throws {
    if window == nil { buildInterface() }
    let oldArcade = ArcadeStore.shared, oldCache = playlistStoreCache
    let oldRecovery = menuRecovery
    let storage = try AppStorage.temporary(named: "home-journey-counts")
    let arcade = ArcadeStore(storage: storage, bundledProofs: nil)
    ArcadeStore.shared = arcade
    let store = try LevelPlaylistStore(file: storage.applicationSupport.appendingPathComponent("journey.json"))
    playlistStoreCache = (arcade.records.activeProfileID, store)
    defer {
      ArcadeStore.shared = oldArcade; playlistStoreCache = oldCache
      menuRecovery = oldRecovery
      storage.removeTemporaryFiles()
    }
    // A revised curriculum must retain older campaign wins, imported sources and sequel records.
    let encoder = JSONEncoder(), summarySeat = "summary-seat"
    let summaryPrefix = "HotSeat.\(summarySeat)."
    let passes = (0..<85).map { ["Fun", "Tricky", "Taxing"][$0 / 30] + "#\($0 % 30)" }
    storage.defaults.set(try encoder.encode(ClassicGameFlow.Progress(furthestReached: [:], passed: passes)),
      forKey: summaryPrefix + "ClassicGameProgress.lemmings-LEVEL-120")
    storage.defaults.set(try encoder.encode(ClassicGameFlow.Progress(furthestReached: [:], passed: ["Fun#0"])),
      forKey: summaryPrefix + "ClassicGameProgress.lemmings-LEVEL-120:source-test")
    let medal = Lemmings2Campaign.Result(startingPopulation: 60, saved: 60, medal: .gold, levelFingerprint: "test")
    storage.defaults.set(try encoder.encode(Lemmings2Campaign.Progress(tribe: 1, level: 2, results: [10: medal, 11: medal])),
      forKey: summaryPrefix + "nativeL2Campaign.v1.bundled")
    storage.defaults.set(try encoder.encode(Lemmings3ClassicCampaign.Progress(index: 3, population: 20,
      completed: [0: 20, 1: 20, 2: 20], tribe: .classic)), forKey: summaryPrefix + "nativeL3ClassicPreview.v1.bundled")
    var history = LearningJourneyProgress()
    history.record(.init(engine: .classic, packID: "lemmings-LEVEL-120", levelID: "0:Fun:1:0:0"), won: true)
    history.record(.init(engine: .classic, packID: "lemmings-LEVEL-120:source-test", levelID: "passed:Fun#0"), won: true)
    history.record(.init(engine: .lemmings2, packID: "tribes-1", levelID: "0:test"), won: true)
    history.record(.init(engine: .lemmings3, packID: "chronicles-1", levelID: "0:test"), won: true)
    history.record(.init(engine: .classic, packID: "removed-fan", levelID: "old.dat#2"), won: true)
    history.record(.init(engine: .classic, packID: "deferred", levelID: "later"), won: false)
    let beforeSummary = storage.defaults.dictionaryRepresentation()
    try check(JourneyCompletionSummary.count(profileID: "one", hotSeatID: summarySeat, learning: history,
      defaults: storage.defaults) == 92, "Journey summary lost historical wins or duplicated campaign/route results")
    try check(JourneyCompletionSummary.count(profileID: "one", hotSeatID: "new-seat", learning: .init(),
      defaults: storage.defaults) == 0, "A new Hot Seat inherited an older session's wins")
    try check(NSDictionary(dictionary: beforeSummary).isEqual(to: storage.defaults.dictionaryRepresentation()),
      "Reading Journey progress rewrote the saved records")
    loadContent()
    guard let journey = LearningJourneyLibrary.journey,
          let classic = journey.lessons.first(where: { $0.entry.identity.packID == "lemmings-LEVEL-120" })?.entry,
          let fan = journey.lessons.first(where: { $0.entry.identity.packID.hasPrefix("fan:") })?.entry,
          let l2 = ShortPlayCatalogue.sequence(id: "lemmings2")?.levels.first?.identity,
          let l3 = ShortPlayCatalogue.sequence(id: "lemmings3")?.levels.first?.identity,
          let guest = arcade.addProfile(initials: "PAL", portrait: 2, select: false) else {
      throw IntegrationFailure(message: "Home progress fixtures are unavailable")
    }
    arcade.toggleSessionProfile(guest.id)
    guard let seat = arcade.hotSeatID else { throw IntegrationFailure(message: "Missing shared owner") }
    try store.add(journey.playlist())
    var wins = LearningJourneyProgress()
    for identity in [classic.identity, fan.identity, l2, l3] { wins.record(identity, won: true) }
    try store.mergeLearningProgress(wins, hotSeatID: seat)
    let run = try LevelSequenceRun.playlist(journey.playlist(), pool: .init(id: LearningJourney.version, summary: "Journey"))
    try store.startRun(run, hotSeatID: seat)
    let owner = arcade.playingProfileID
    menuRecovery = RunRecovery(engine: "test", profileID: owner, runID: UUID(), dataSetID: "test",
      levelIndex: 0, levelFingerprint: "test", initialStateHash: "test", tick: 0, events: [], stateHash: "test",
      usedRewind: false, nukeCount: 0, rewindCount: 0, undoCount: 0, selectedSkill: 0, scrollX: 0, scrollY: 0)
    menuRecovery?.hotSeatID = seat
    var resumes = homeMenuItems().filter { [.resume, .resumeSequence].contains($0.action) }
    try check(resumes.count == 1 && resumes[0].action == .resume,
      "Home did not select the latest standalone level over the older queue")
    menuRecovery?.sequence = .init(runID: run.id, entry: run.currentEntry)
    resumes = homeMenuItems().filter { [.resume, .resumeSequence].contains($0.action) }
    try check(resumes.count == 1 && resumes[0].action == .resumeSequence,
      "A checkpoint in the current route produced duplicate Resume actions")
    try check(homeMenuItems().contains { $0.title == L10n.text("JOURNEY MAP  \(4) SOLVED") },
      "Home hid wins outside the current curriculum")
    let originalCampaign = UserDefaults.standard.dictionaryRepresentation().filter { $0.key.hasPrefix("HotSeat.\(seat).") }
    rebuildLibrary()
    let classicTitle = homeContentRow(.classic)
    try check(classicTitle.contains("1/120"), "Home ignored a Classic Journey win: \(classicTitle)")
    try check(!fanHomeRow().contains("  0/"), "Home ignored the fan Journey win")
    try check(store.learningProgress.completed.isEmpty, "Home copied Hot Seat wins into Solo")
    if let root = try? BundledGameResources.lemmings2() {
      try check(Lemmings2PlayWindow.savedCompletion(root: root, journeyWins: [l2]) == 1,
        "L2 completion omitted its exact Journey win")
    }
    if let root = try? BundledGameResources.lemmings3() {
      try check(Lemmings3PlayWindow.savedCompletion(root: root, journeyWins: [l3]) == 1,
        "L3 completion omitted its exact Journey win")
    }
    let captureDirectory = URL(fileURLWithPath: ".build/journey-progress/renders")
    try FileManager.default.createDirectory(at: captureDirectory, withIntermediateDirectories: true)
    for size in [CGSize(width: 900, height: 620), CGSize(width: 1180, height: 820)] {
      window.setContentSize(size); window.contentView?.layoutSubtreeIfNeeded()
      renderScreen()
      let image = playfield.bitmapImageRepForCachingDisplay(in: playfield.bounds)!
      playfield.cacheDisplay(in: playfield.bounds, to: image)
      try image.representation(using: .png, properties: [:])!.write(to: captureDirectory.appendingPathComponent("hotseat-\(Int(size.width)).png"))
      let controls = playfield.accessibilityChildren()?.compactMap { $0 as? GameAccessibleElement } ?? []
      let rows = controls.filter { ($0.accessibilityLabel() ?? "").contains("1/120") || ($0.accessibilityLabel() ?? "").hasPrefix("FAN LEMMINGS") }
      try check(rows.count == 2 && rows.allSatisfy { playfield.bounds.contains($0.localFrame) && $0.localFrame.height >= 28 },
        "Corrected counts lost their visible targets")
      let priorAction = playfield.onSelectOverlayLine
      var selected: Int?
      playfield.onSelectOverlayLine = { selected = $0 }
      for row in rows {
        selected = nil
        playfield.handleClick(at: CGPoint(x: row.localFrame.midX, y: row.localFrame.midY))
        try check(selected.map { playfield.overlayLines[$0] == row.accessibilityLabel() } == true,
          "A corrected count lost its mouse target: \(row.accessibilityLabel() ?? "unknown"), selected \(String(describing: selected))")
        selected = nil
        try check(row.accessibilityPerformPress() && selected.map { playfield.overlayLines[$0] == row.accessibilityLabel() } == true,
          "A corrected count lost its accessibility action")
      }
      playfield.onSelectOverlayLine = priorAction
    }
    try check(arcade.hotSeatID == seat && arcade.playingProfileID == owner && store.activeRun == run,
      "Counting Journey wins changed the session or turn")
    try check(NSDictionary(dictionary: originalCampaign).isEqual(to: UserDefaults.standard.dictionaryRepresentation().filter { $0.key.hasPrefix("HotSeat.\(seat).") }),
      "Displaying Journey counts wrote campaign progress")
    arcade.endHotSeat()
    try check(!homeContentRow(.classic).contains("1/120"), "Solo inherited the Hot Seat Home count")
    print("PASS historical Journey counts, unique Resume, Solo/Hot Seat isolation, Classic/L2/L3 records, two renders and input targets")
  }
}
#endif
