
@MainActor extension AppDelegate {
  fileprivate func testHomeBackdrop() async throws {
    if window == nil { buildInterface() }
    GameScreen.shared.dismissAll()
    let previousStore = ArcadeStore.shared
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("home-backdrop-\(UUID())")
    ArcadeStore.shared = ArcadeStore(file: directory.appendingPathComponent("records.json"), bundledProofs: nil)
    defer {
      homeBackdropTask?.cancel(); homeBackdropTask = nil; homeBackdropKey = nil
      ArcadeStore.shared = previousStore
      try? FileManager.default.removeItem(at: directory)
    }
    settings.music = .silent; settings.soundVolume = 0
    loadContent()
    let profile = ArcadeStore.shared.playingProfileID
    try check((try LevelCollections.store(profileID: profile).recentlyPlayed).isEmpty,
      "Home scenery created a false Recently Played visit")
    guard let discovery = await makeLevelBrowserDiscoveryTask().value else {
      throw IntegrationFailure(message: "Home scenery discovery failed")
    }
    preparedLevelBrowserDiscovery = discovery
    rebuildLevelCatalogue(discovery)
    let folder = URL(fileURLWithPath: ".build/home-backdrop-renders")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let clockProbe = PlayfieldView(frame: CGRect(x: 0, y: 0, width: 900, height: 620))
    clockProbe.setHomeBackdrop(LevelPreviewBitmap(width: 1600, height: 160,
      rgba: Data(repeating: 255, count: 1600 * 160 * 4), start: CGPoint(x: 160, y: 80),
      goal: CGPoint(x: 1440, y: 80)))
    let opening = clockProbe.homeBackdropSource(at: 0)!
    let destination = CGPoint(x: 1440, y: 80)
    let travel = destination.x - opening.width / 2 - opening.minX
    let duration = max(60, travel * .pi / 6)
    let end = clockProbe.homeBackdropSource(at: duration)!
    let back = clockProbe.homeBackdropSource(at: duration * 2)!
    try check(abs(end.midX - destination.x) < 0.01 && abs(back.minX - opening.minX) < 0.01,
      "Home scenery did not pan to the goal and back")
    let requests = levelPreviewRequests
    for engine in [LevelSourceEngine.classic, .lemmings2, .lemmings3] {
      guard let request = requests.values.filter({ $0.identity.engine == engine })
        .sorted(by: { $0.identity.levelID < $1.identity.levelID }).first else {
        throw IntegrationFailure(message: "Missing \(engine) Home scenery fixture")
      }
      let bitmap = try await LevelPreviewStore.backdrop(for: request)
      try check(bitmap.width >= 320 && bitmap.rgba.count == bitmap.width * bitmap.height * 4 && bitmap.goal != nil,
        "\(engine) Home scenery lost its full map or exit")
      let entry = try collectionEntry(for: request.identity)
      try LevelCollections.store(profileID: profile).recordVisit(entry)
      flow = ClassicGameFlow(ranks: [ClassicRank(name: "Fun", levelIndices: [0])])
      fanScreen = .off; fanPlaying = false
      homeBackdropKey = nil
      refreshHomeBackdrop()
      await homeBackdropTask?.value
      try check(playfield.homeBackdropImage?.width == bitmap.width
        && (playfield.homeBackdropImage?.dataProvider?.data as Data?) == bitmap.rgba
        && homeBackdropKey == profile + ":" + entry.id.uuidString,
        "\(engine) Home did not select the last played level")
      for size in [CGSize(width: 900, height: 620), CGSize(width: 1600, height: 1000),
                   CGSize(width: 2555, height: 1439), CGSize(width: 5110, height: 2878)] {
        let probe = PlayfieldView(frame: CGRect(origin: .zero, size: size))
        probe.interfaceArtwork = playfield.interfaceArtwork
        probe.overlayTitle = L10n.text("LEMMINGS"); probe.phase = .briefing
        probe.overlayProfileInitials = "AB v CD"; probe.overlayShowsLemmings = true
        probe.overlaySavedCounts = "LEMMINGS SAVED  LOCAL 5,080  GLOBAL 9,354"
        probe.overlayShowsSettingsButton = true
        probe.overlayHomeLeadingCount = 2
        probe.overlayHomeLogos = [8: .lemmings2, 9: .lemmings3]
        probe.overlayLines = ["RESUME LEVEL - AB v CD", "JOURNEY MAP 4/227 SOLVED", "CLASSIC LEMMINGS 10/120",
          "OH NO! MORE LEMMINGS 24/100", "HOLIDAY LEMMINGS 3/72", "OH YES! MORE LEMMINGS 0/60",
          "FAN LEMMINGS 0/6022", "NEOLEMMIX 2/788", "LEMMINGS 2", "LEMMINGS 3"]
        probe.overlayHighlight = 0
        probe.setHomeBackdrop(bitmap)
        let start = probe.homeBackdropSource(at: 0)!
        let later = probe.homeBackdropSource(at: 60)!
        let map = CGRect(x: 0, y: 0, width: bitmap.width, height: bitmap.height)
        try check(map.contains(start) && map.contains(later), "\(engine) Home camera crossed a map edge")
        if start != later, let goal = bitmap.goal {
          try check(hypot(later.midX - goal.x, later.midY - goal.y) < hypot(start.midX - goal.x, start.midY - goal.y),
            "\(engine) Home camera moved away from the exit")
        }
        probe.reduceMotion = true
        probe.advanceHomeBackdrop(seconds: 30)
        try check(probe.homeBackdropElapsed == 0, "Reduce Motion animated Home scenery")
        probe.reduceMotion = false
        if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
          probe.advanceHomeBackdrop(seconds: 60)
          try check(probe.homeBackdropElapsed == 60, "Home scenery clock did not advance")
        }
        var selected: Int?
        probe.onSelectOverlayLine = { selected = $0 }
        var settingsPressed = false
        probe.onSettings = { settingsPressed = true }
        func capture(_ suffix: String) throws {
          let image = ReplayFrameCapture.image(size: size) { ReplayFrameCapture.draw(probe, in: probe.bounds) }!
          try NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!.write(
            to: folder.appendingPathComponent("\(engine)-\(Int(size.width))-\(suffix).png"))
        }
        try capture("selected")
        let controls = probe.accessibilityChildren()!.compactMap { $0 as? GameAccessibleElement }
          .filter { $0.accessibilityRole() == .button }
        for (index, control) in controls.enumerated() {
          try check(probe.bounds.contains(control.localFrame), "Home clipped a visible input target")
          for other in controls.dropFirst(index + 1) {
            try check(!control.localFrame.intersects(other.localFrame), "Home input targets overlap")
          }
        }
        if size.width >= 1600 {
          let top = controls.map(\.localFrame.minY).min()!
          let bottom = controls.map(\.localFrame.maxY).max()!
          try check(top > size.height * 0.1 && bottom < size.height * 0.9,
            "Large Mac Home stretched through the screen height")
          try check(controls.count == probe.homeActionCount, "Large Mac Home hid an action")
        }
        for index in probe.overlayLines.indices {
          if let control = controls.first(where: { $0.accessibilityLabel() == probe.overlayLines[index] }) {
            probe.handleClick(at: CGPoint(x: control.localFrame.midX, y: control.localFrame.midY))
            try check(selected == index, "Centred Home mouse target selected the wrong action")
          }
        }
        for index in 0..<probe.homeActionCount {
          probe.overlayHighlight = index
          _ = ReplayFrameCapture.image(size: size) { ReplayFrameCapture.draw(probe, in: probe.bounds) }
          let visible = probe.accessibilityChildren()!.compactMap { $0 as? GameAccessibleElement }
          if index == probe.homeActionCount - 1 {
            guard let settings = visible.first(where: { $0.accessibilityLabel() == "Settings" }) else {
              throw IntegrationFailure(message: "Keyboard focus did not reveal Home Settings")
            }
            probe.handleClick(at: CGPoint(x: settings.localFrame.midX, y: settings.localFrame.midY))
            try check(settingsPressed, "Centred Settings target did not activate")
          }
        }
        try capture("footer")
      }
    }
    let missing = try LevelPlaylistEntry(identity: .init(engine: .classic, packID: "missing", levelID: "missing"),
      catalogueRevision: "missing", sourceRevision: "missing", packNameSnapshot: "Missing", levelNameSnapshot: "Missing", levelNumberSnapshot: 1)
    try LevelCollections.store(profileID: profile).recordVisit(missing)
    refreshHomeBackdrop(); await homeBackdropTask?.value
    try check(homeBackdropKey == profile + ":" + missing.id.uuidString && playfield.homeBackdropImage != nil,
      "Missing last-played content did not fall back to random scenery")
    // A new profile has no history. Keep a single random choice across menu refreshes.
    let guest = ArcadeStore.shared.addProfile(initials: "NEW", portrait: 1, select: true)!
    homeBackdropKey = nil
    refreshHomeBackdrop(); await homeBackdropTask?.value
    try check(homeBackdropKey == guest.id + ":random" && playfield.homeBackdropImage != nil,
      "Fresh Home did not choose random scenery")
    let random = playfield.homeBackdropImage
    refreshHomeBackdrop()
    try check(homeBackdropTask == nil && random === playfield.homeBackdropImage,
      "Home reselected random scenery during a menu refresh")
    print("PASS Classic/L2/L3 full-map scenery, last played/random selection, exit pan, Reduce Motion, 24 compact/large renders and input targets")
  }
}
