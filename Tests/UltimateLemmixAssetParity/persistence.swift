/**
 * Retains native run and Hot Seat ownership across separate harness processes.
 */
private struct ParitySavedSession: Codable {
  let host: String
  let turn: String
  let roster: [String]
  let hotSeatID: String
  let runID: UUID
  let stateHash: String
  let tick: Int
  let queueID: UUID
  let queueIndex: Int
}

extension AppDelegate {
  fileprivate func paritySavedSession(folder: URL, reopen: Bool) throws -> [String: Any] {
    let support = AppStorage.current().applicationSupport
    let marker = support.appendingPathComponent("asset-parity-native-session.json")
    let queueFile = support.appendingPathComponent("asset-parity-queue.json")
    let store = ArcadeStore.shared
    let queue = try LevelPlaylistStore(file: queueFile)
    playlistStoreCache = (store.records.activeProfileID, queue)
    let saved: ParitySavedSession
    if reopen {
      saved = try JSONDecoder().decode(ParitySavedSession.self, from: Data(contentsOf: marker))
      try parityRequire(store.records.activeProfileID == saved.host && store.playingProfileID == saved.turn,
        "Reopening changed the host or next turn.")
      try parityRequire(store.sessionProfiles.map(\.id) == saved.roster && store.hotSeatID == saved.hotSeatID,
        "Reopening changed the Hot Seat roster or session.")
      guard let run = queue.resumableRun(hotSeatID: saved.hotSeatID)?.run else {
        throw AssetParityFailure(message: "The saved queue cannot be resolved for its Hot Seat session.")
      }
      try parityRequire(run.id == saved.queueID && run.currentIndex == saved.queueIndex,
        "Reopening changed the queue identity or position.")
      guard let checkpoint = try recoveryStore.latest(profileID: saved.turn, hotSeatID: saved.hotSeatID) else {
        throw AssetParityFailure(message: "The native Classic checkpoint is missing after reopening.")
      }
      try parityRequire(checkpoint.runID == saved.runID && checkpoint.stateHash == saved.stateHash,
        "Reopening changed the native Classic checkpoint identity.")
      restoreRun(checkpoint)
      guard let classic = session as? ClassicSession else {
        throw AssetParityFailure(message: "The native Classic checkpoint did not restore a Classic session.")
      }
      try parityRequire(isPaused && arcadeRunID == saved.runID && classic.currentTick == saved.tick,
        "Native Classic restoration changed the run or resumed play.")
      try parityRequire(ClassicDOSReplayRecorder.stateHash(of: classic.simulation) == saved.stateHash,
        "Native Classic restoration changed simulation state.")
      _ = try parityCapture(playfield, name: "classic-restored", folder: folder)
    } else {
      let host = store.records.activeProfileID
      guard let guest = store.records.profiles.first(where: { $0.initials == "PAL" }) else {
        throw AssetParityFailure(message: "Cannot create the isolated Hot Seat guest.")
      }
      store.toggleSessionProfile(guest.id)
      try parityRequire(store.passSessionTurn(after: host), "Cannot pass the isolated Hot Seat turn.")
      guard let hotSeat = store.hotSeatID,
            let index = dataSets.firstIndex(where: { $0.set.title == .lemmings }),
            let pack = levelCatalogue.packs.first(where: { $0.engine == .classic && $0.levels.count >= 2 }) else {
        throw AssetParityFailure(message: "The Hot Seat queue fixture has no canonical Classic levels.")
      }
      GameScreen.shared.dismissAll()
      try applyDataSetSelection(at: index)
      loadLevel(at: 0)
      flow?.selectLevel(rank: 0, position: 0)
      flow?.beginPlaying()
      renderScreen()
      guard let classic = session as? ClassicSession else {
        throw AssetParityFailure(message: "The native Classic save fixture did not start.")
      }
      for _ in 0..<17 { classic.tick() }
      isPaused = true
      saveRunCheckpoint(immediately: true)
      try recoveryStore.checkSaveSucceeded()
      guard let checkpoint = try recoveryStore.latest(profileID: guest.id, hotSeatID: hotSeat) else {
        throw AssetParityFailure(message: "The native Classic checkpoint was not saved for the next player.")
      }
      let entries = try pack.levels.prefix(2).map { try collectionEntry(for: $0.identity) }
      let playlist = try LevelPlaylist(name: "Parity queue", entries: entries)
      try queue.add(playlist)
      let run = try LevelSequenceRun(source: .playlist(playlist.id),
        pool: .init(id: "parity", summary: "Parity queue"), entries: entries)
      try queue.startRun(run, hotSeatID: hotSeat)
      try parityRequire(try queue.advanceActiveRun(), "Cannot advance the isolated queue.")
      let solo = try LevelSequenceRun(source: .playlist(playlist.id),
        pool: .init(id: "parity-solo", summary: "Another route"), entries: entries)
      try queue.startRun(solo, hotSeatID: nil)
      try parityRequire(queue.savedRuns.contains { $0.run.id == run.id && $0.run.currentIndex == 1 },
        "Starting another route removed the saved Hot Seat queue.")
      saved = ParitySavedSession(host: host, turn: guest.id, roster: store.sessionProfiles.map(\.id),
        hotSeatID: hotSeat, runID: checkpoint.runID, stateHash: checkpoint.stateHash,
        tick: checkpoint.tick, queueID: run.id, queueIndex: 1)
      try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
      try JSONEncoder().encode(saved).write(to: marker, options: .atomic)
      store.save(); store.flushPendingSaves(); UserDefaults.standard.synchronize()
    }
    try parityRequire(queue.savedRuns.contains { $0.run.id == saved.queueID && $0.hotSeatID == saved.hotSeatID },
      "The selected Hot Seat queue did not remain archived.")
    GameScreen.shared.dismissAll()
    returnToLibrary()
    renderScreen()
    let actions = homeMenuItems().map(\.title)
    try parityRequire(homeMenuItems().contains { $0.action == .resumeSequence },
      "Home did not resolve the saved queue for the selected session.")
    return ["roster": store.sessionProfiles.map(\.initials),
      "nextTurnIndex": store.sessionProfiles.firstIndex { $0.id == store.playingProfileID } ?? -1,
      "queueIndex": saved.queueIndex, "archivedQueue": true, "checkpointTick": saved.tick, "checkpointStateHash": saved.stateHash,
      "homeActions": actions, "savedHome": try parityCapture(playfield, name: "saved-home", folder: folder),
      "restoredAcrossProcesses": reopen]
  }
}
