extension AppDelegate {
  /**
   * Loads one available owned NeoLemmix level through the native session and recovery path.
   */
  fileprivate func captureNeoAssetParity(folder: URL, reopen: Bool) async throws -> [String: Any] {
    let packs = levelCatalogue.packs.filter { $0.engine == .neolemmix }
    let catalogue: [[String: Any]] = packs.map { pack in
      ["id": pack.id, "levels": pack.levels.map { level in
        ["packID": level.identity.packID, "levelID": level.identity.levelID,
         "sourceRevision": playlistSourceRevision(for: level.identity) ?? "missing",
         "available": level.availability == .available] as [String: Any]
      }]
    }
    guard let entry = packs.flatMap(\.levels).first(where: { $0.availability == .available }),
          let route = levelBrowserRoutes[entry.identity],
          case let .neolemmix(level, _, _, packName, _, styles) = route, let styles else {
      throw AssetParityFailure(message: "The owned NeoLemmix catalogue has no available native fixture.")
    }
    GameScreen.shared.dismissAll()
    try parityRequire(loadNxlv(level.url, stylesDirectory: styles,
      catalogueIdentity: entry.identity, packName: packName), "The native owned NeoLemmix level did not start.")
    guard let live = session as? NeoLemmixSession else {
      throw AssetParityFailure(message: "The owned level did not create a NeoLemmix session.")
    }
    playfield.startCountdown.cancel()
    for _ in 0..<17 { live.tick() }
    let expected = live.simulation
    guard let referencePath = ProcessInfo.processInfo.environment["LEMMIX_PARITY_REFERENCE"] else {
      throw AssetParityFailure(message: "The NeoLemmix reference folder is not configured.")
    }
    let referenceFolder = URL(fileURLWithPath: referencePath)
    let stateFile = referenceFolder.appendingPathComponent("neo-state.json")
    if ProcessInfo.processInfo.environment["LEMMIX_PARITY_PHASE"] == "reference" {
      try JSONEncoder().encode(expected).write(to: stateFile, options: .atomic)
    } else {
      let reference = try JSONDecoder().decode(NeoLemmixSimulation.self, from: Data(contentsOf: stateFile))
      try parityRequire(reference == expected, "The imported native NeoLemmix simulation differs from the reference.")
    }
    let terrainHash = parityHash(Data(expected.terrain.solidMask))
    let file = RunRecoveryFile(url: AppStorage.current().applicationSupport.appendingPathComponent("asset-parity-neo.json"))
    if reopen {
      guard var checkpoint = try file.load() else {
        throw AssetParityFailure(message: "The NeoLemmix checkpoint did not survive reopening.")
      }
      try parityRequire(checkpoint.neoPackID == entry.identity.packID && checkpoint.neoLevelID == entry.identity.levelID,
        "The NeoLemmix checkpoint changed its canonical identity.")
      checkpoint.sourcePath = "/private/tmp/removed-parity-source.nxlv"
      restoreRun(checkpoint)
      try parityRequire((session as? NeoLemmixSession)?.simulation == expected && isPaused,
        "Native NeoLemmix restoration changed state or resumed play.")
    } else {
      saveRunCheckpoint(immediately: true)
      try recoveryStore.checkSaveSucceeded()
      guard let checkpoint = try recoveryStore.latest(profileID: arcadeProfileID), checkpoint.neo != nil else {
        throw AssetParityFailure(message: "The native NeoLemmix checkpoint was not saved.")
      }
      try file.save(checkpoint)
    }
    isPaused = true
    try await waitForParityLayout("neo-gameplay")
    let capture = try parityCapture(playfield, name: "neo-gameplay", folder: folder)
    return ["catalogue": catalogue, "packID": entry.identity.packID, "levelID": entry.identity.levelID,
      "terrainHash": terrainHash, "stateMatchesReference": true, "tick": 17, "capture": capture, "restoredAcrossProcesses": reopen]
  }
}
