#if os(macOS)
@MainActor extension AppDelegate {
  fileprivate func testHomeJourneyProgressCounts() throws {
    if window == nil { buildInterface() }
    let oldArcade = ArcadeStore.shared, oldCache = playlistStoreCache
    let storage = try AppStorage.temporary(named: "home-journey-counts")
    let arcade = ArcadeStore(storage: storage, bundledProofs: nil)
    ArcadeStore.shared = arcade
    let store = try LevelPlaylistStore(file: storage.applicationSupport.appendingPathComponent("journey.json"))
    playlistStoreCache = (arcade.records.activeProfileID, store)
    defer {
      ArcadeStore.shared = oldArcade; playlistStoreCache = oldCache
      storage.removeTemporaryFiles()
    }
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
    print("PASS Home Journey counts, Solo/Hot Seat isolation, exact Classic/L2/L3 identities, two renders and input targets")
  }
}
#endif
