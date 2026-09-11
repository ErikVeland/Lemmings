private struct FanUIFailure: Error { let message: String }
private func verifyFanUI(_ condition: Bool, _ message: String) throws {
  if !condition { throw FanUIFailure(message: message) }
  print("PASS \(message)")
}
extension AppDelegate {
  fileprivate func testEmbeddedFans() async throws {
    ArcadeStore.shared = ArcadeStore(file: FileManager.default.temporaryDirectory.appendingPathComponent("fan-ui-records-\(UUID().uuidString).json"))
    UserDefaults.standard.removeObject(forKey: FanLevelLibrary.folderKey)
    FanLevelLibrary.Progress.seedBundledCounts()
    buildInterface()
    settings.graphics = .macintosh
    loadContent()
    let packs = FanLevelLibrary.packs()
    try verifyFanUI(packs.count == 535 && FanLevelLibrary.Progress.isComplete(for: packs)
      && FanLevelLibrary.Progress.total(for: packs) == 6043, "embedded first launch shows all 535 packs and 6043 levels without counting")
    try verifyFanUI(fanLibraryRow().contains("6043") && !fanLibraryRow().contains("FOLDER"),
                    "Fan Levels title row opens the embedded library without a folder prompt")
    let windows = NSApp.windows.count
    showFanLevels()
    try verifyFanUI(fanScreen == .packs && !GameScreen.shared.isPresented && NSApp.windows.count == windows,
                    "Fan Levels opens its pack list in the game window")
    fanChoice = 4
    let selectedPack = fanPacks[fanChoice]
    startFanUpdates()
    await fanUpdateTask?.value
    try verifyFanUI(fanPacks[fanChoice] == selectedPack && fanScreen == .packs,
                    "launch update check preserves the selected pack")
    try verifyFanUI(fanUpdateStatus != "CHECKING FOR NEW PACKS", "update status reaches the fan browser")
    if let bitmap = playfield.bitmapImageRepForCachingDisplay(in: playfield.bounds) {
      playfield.cacheDisplay(in: playfield.bounds, to: bitmap)
      try bitmap.representation(using: .png, properties: [:])!.write(to:
        URL(fileURLWithPath: ".build/fan-library/fan-browser.png"))
    }
    fanChoice = 0
    _ = advanceFanScreen()
    try verifyFanUI(fanScreen == .levels && !fanEntries.isEmpty, "embedded pack opens its level list")
    fanChoice = 2
    _ = advanceFanScreen()
    try verifyFanUI(fanPlaying && session != nil, "embedded level loads for play without external content")
    runMovie.discard()
    window.orderOut(nil)
  }
}
let fanTestApp = NSApplication.shared
guard let domain = Bundle.main.bundleIdentifier, domain == "academy.glasscode.lemmings.fan-library-tests" else { exit(2) }
UserDefaults.standard.removePersistentDomain(forName: domain)
fanTestApp.setActivationPolicy(.accessory)
Task { @MainActor in
  do { try await AppDelegate().testEmbeddedFans(); exit(0) }
  catch { print("FAIL \(error)"); exit(1) }
}
fanTestApp.run()
