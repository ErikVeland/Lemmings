import CryptoKit
import LemmingsMobileCore

private struct AssetParityFailure: Error { let message: String }
private func parityRequire(_ value: @autoclosure () throws -> Bool, _ message: String) throws {
  if try !value() { throw AssetParityFailure(message: message) }
}
private func parityCanonical(_ data: Data) -> Data {
  guard let object = try? JSONSerialization.jsonObject(with: data),
        let canonical = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) else { return data }
  return canonical
}
private func parityHash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }

@MainActor private func parityViews(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(parityViews) }

/**
 * Captures native pixels and the visible input contract without a desktop screenshot.
 */
@MainActor private func parityCapture(_ view: NSView, name: String, folder: URL) throws -> [String: Any] {
  if let window = view.window {
    window.setContentSize(CGSize(width: 1120, height: 760))
    window.contentView?.needsUpdateConstraints = true
    window.contentView?.updateConstraintsForSubtreeIfNeeded()
    window.contentView?.needsLayout = true
    window.contentView?.layoutSubtreeIfNeeded()
    GameScreen.shared.reattach()
    window.contentView?.layoutSubtreeIfNeeded()
    window.displayIfNeeded()
  }
  view.layoutSubtreeIfNeeded()
  for child in parityViews(view) { child.needsDisplay = true }
  guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds),
        let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
    throw AssetParityFailure(message: "Cannot capture " + name)
  }
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = context
  view.displayIgnoringOpacity(view.bounds, in: context)
  NSGraphicsContext.restoreGraphicsState()
  guard let png = bitmap.representation(using: .png, properties: [:]), let pixels = bitmap.bitmapData else {
    throw AssetParityFailure(message: "Cannot encode " + name)
  }
  try png.write(to: folder.appendingPathComponent(name + ".png"), options: .atomic)
  let controls: [[String: Any]] = parityViews(view).compactMap { child in
    guard !child.isHiddenOrHasHiddenAncestor else { return nil }
    let frame = view.convert(child.bounds, from: child)
    if let popup = child as? NSPopUpButton {
      return ["kind": "popup", "items": popup.itemTitles, "enabled": popup.isEnabled, "selection": popup.indexOfSelectedItem,
        "frame": NSStringFromRect(frame)]
    }
    if let button = child as? NSButton {
      return ["kind": "button", "title": button.title, "enabled": button.isEnabled, "state": button.state.rawValue,
        "action": button.action.map(NSStringFromSelector) ?? "", "frame": NSStringFromRect(frame)]
    }
    return nil
  }
  return ["pixelHash": parityHash(Data(bytes: pixels, count: bitmap.bytesPerRow * bitmap.pixelsHigh)),
    "width": bitmap.pixelsWide, "height": bitmap.pixelsHigh, "controls": controls]
}

@MainActor private func parityMenu(_ menu: NSMenu) -> [[String: Any]] {
  menu.items.map { item in
    ["title": item.title, "key": item.keyEquivalent, "modifiers": item.keyEquivalentModifierMask.rawValue,
      "action": item.action.map(NSStringFromSelector) ?? "", "separator": item.isSeparatorItem,
      "enabled": item.isEnabled, "state": item.state.rawValue,
      "children": item.submenu.map(parityMenu) ?? []]
  }
}

extension AppDelegate {
  fileprivate func waitForParityLayout(_ stage: String) async throws {
    let deadline = ProcessInfo.processInfo.systemUptime + 2
    var previous = ""
    while true {
      fitClassicDisplay()
      plainRoot?.needsUpdateConstraints = true
      plainRoot?.updateConstraintsForSubtreeIfNeeded()
      plainRoot?.needsLayout = true
      plainRoot?.layoutSubtreeIfNeeded()
      let description = "LAYOUT \(stage): attached=\(window.contentView === plainRoot) tube=\(tubeIsActive) menu=\(panel.isMenuMode) panel=\(panelHeightConstraint?.constant ?? -1) active=\(panelHeightConstraint?.isActive == true) constraints=\(plainRoot?.constraints.count ?? -1) children=\(playfield.superview === plainRoot && panel.superview === plainRoot) playfield=\(playfield.frame) root=\(plainRoot?.frame ?? .zero)"
      if description != previous { print(description); previous = description }
      if let root = plainRoot, let height = panelHeightConstraint,
         window.contentView === root, !tubeIsActive, !panel.isMenuMode, height.isActive,
         playfield.superview === root, panel.superview === root,
         abs(playfield.frame.width - root.bounds.width) < 0.5,
         abs(playfield.frame.height - (root.bounds.height - height.constant)) < 0.5,
         abs(panel.frame.height - height.constant) < 0.5 {
        return
      }
      try parityRequire(ProcessInfo.processInfo.systemUptime < deadline,
        "The native gameplay layout did not settle: " + description)
      try await Task.sleep(nanoseconds: 20_000_000)
    }
  }

  fileprivate func prepareAssetParityLaunch() {
    arcadeAutoPresent = false
  }

  /**
   * Uses the current native frontend with two resource trees and stable isolated saves.
   */
  fileprivate func installParityResources(source: URL) throws -> OwnedResourceLibrary.Installation {
    showOwnedGameImport()
    let installed = try AppDistribution.ownedResourceLibrary.install(directory: source)
    guard ownedGameImport.onResourcesInstalled != nil else {
      throw AssetParityFailure(message: "The real importer completion callback is missing.")
    }
    ownedGameImport.parityFinishResourceImport(installed)
    try parityRequire(GameArtworkSkin.lixEnabled, "Resource import changed the selected Lix characters.")
    GameArtworkSkin.setLixEnabled(false)
    return installed
  }

  fileprivate func captureAssetParity(folder: URL, reopen: Bool) async throws -> [String: Any] {
    timer?.invalidate(); timer = nil
    arcadeAutoPresent = false
    GameScreen.shared.dismissAll()
    preparingLaunch = false
    settings.display = .flat
    settings.graphics = .dosVGA
    settings.shuffleGraphics = false
    settings.shuffleMusic = false
    settings.music = .silent
    try parityRequire(!GameArtworkSkin.lixEnabled, "The selected Original artwork was not retained.")
    apply(settings, forceArtworkRefresh: true)
    window.setContentSize(CGSize(width: 1120, height: 760))
    window.contentView?.layoutSubtreeIfNeeded()
    returnToLibrary()
    renderScreen()
    guard let discovery = await makeLevelBrowserDiscoveryTask().value else {
      throw AssetParityFailure(message: "The native level catalogue discovery failed.")
    }
    rebuildLevelCatalogue(discovery)
    var persistence: [String: Any]?
    if reopen {
      persistence = try paritySavedSession(folder: folder, reopen: true)
      ArcadeStore.shared.endHotSeat()
      menuRecovery = nil
      while let previous = try recoveryStore.latest(profileID: ArcadeStore.shared.records.activeProfileID) {
        try recoveryStore.setAside(previous.runID)
      }
      playlistStoreCache = (ArcadeStore.shared.records.activeProfileID,
        try LevelPlaylistStore(file: AppStorage.current().applicationSupport.appendingPathComponent("fresh-presentation-queue.json")))
    } else {
      try parityRequire(ArcadeStore.shared.addProfile(initials: "PAL", portrait: 1, select: false) != nil,
        "Cannot create the isolated Hot Seat guest.")
    }
    returnToLibrary()
    menuRecovery = nil
    renderScreen()
    let browserCatalogue: [[String: Any]] = levelCatalogue.packs.filter { $0.engine == .classic && !$0.id.hasPrefix("fan:") }.map { pack in
      ["id": pack.id, "name": pack.name, "levels": pack.levels.map { level in
        ["identity": ["engine": level.identity.engine.rawValue, "packID": level.identity.packID,
          "levelID": level.identity.levelID], "sourceRevision": playlistSourceRevision(for: level.identity) ?? "missing"] as [String: Any]
      }]
    }
    try parityRequire(Set(browserCatalogue.compactMap { $0["id"] as? String }) == Set(dataSets.map { $0.set.identifierKey }),
      "The official browser packs changed their historical catalogue identities.")
    try parityRequire(dataSets.allSatisfy { dataSetID($0) == $0.set.identifierKey },
      "An official campaign changed its historical storage identity.")
    let catalogue: [[String: Any]] = dataSets.map { entry in
      ["id": entry.set.identifierKey, "storageID": dataSetID(entry), "name": entry.set.name,
       "levels": entry.set.campaign.levels.map { level in
          ["rank": level.rank, "number": level.number, "title": level.level.title,
           "archive": level.archiveFile, "section": level.archiveSection] as [String: Any]
       }]
    }
    try parityRequire(dataSets.count == 7 && browserCatalogue.count == 7,
      "The complete resource tree must expose all seven official Classic campaigns.")
    var captures: [String: Any] = [:]
    captures["home"] = try parityCapture(playfield, name: "home", folder: folder)
    let homeActions = homeMenuItems().map { item -> [String: String] in
      let action: String
      switch item.action {
      case .resume: action = "resume"
      case .resumeSequence: action = "resumeSequence"
      case .fullQuest: action = "fullQuest"
      case .collections: action = "collections"
      case let .browse(family): action = "browse:" + String(HomeContentFamily.allCases.firstIndex(of: family)!)
      }
      return ["title": item.title, "action": action]
    }
    showSettings()
    guard let settingsPage = GameScreen.shared.controllerPage(in: window) else {
      throw AssetParityFailure(message: "Settings did not open.")
    }
    captures["settings"] = try parityCapture(settingsPage, name: "settings", folder: folder)
    GameScreen.shared.dismissAll()
    showOwnedGameImport()
    guard let importPage = GameScreen.shared.controllerPage(in: window) else {
      throw AssetParityFailure(message: "The importer did not open.")
    }
    captures["importer"] = try parityCapture(importPage, name: "importer", folder: folder)
    GameScreen.shared.dismissAll()
    guard let index = dataSets.firstIndex(where: { $0.set.title == .lemmings }) else {
      throw AssetParityFailure(message: "The original Classic catalogue is missing.")
    }
    try applyDataSetSelection(at: index)
    loadLevel(at: 0)
    flow?.selectLevel(rank: 0, position: 0)
    flow?.beginPlaying()
    try parityRequire(session != nil, "Classic gameplay did not start.")
    isPaused = true
    renderScreen()
    try await waitForParityLayout("classic-gameplay")
    captures["classic-gameplay"] = try parityCapture(playfield, name: "classic-gameplay", folder: folder)
    presentPauseMenu()
    guard let pausePage = GameScreen.shared.controllerPage(in: window) else {
      throw AssetParityFailure(message: "Pause did not open.")
    }
    captures["pause"] = try parityCapture(pausePage, name: "pause", folder: folder)
    let markerKey = "AssetParity.savedProfileID"
    let profile = ArcadeStore.shared.records.activeProfileID
    if reopen {
      try parityRequire(UserDefaults.standard.string(forKey: markerKey) == profile,
        "The active player changed after reopening.")
    } else {
      UserDefaults.standard.set(profile, forKey: markerKey)
    }
    saveProgress()
    ArcadeStore.shared.save()
    ArcadeStore.shared.flushPendingSaves()
    UserDefaults.standard.synchronize()
    var result: [String: Any] = ["catalogue": catalogue, "browserCatalogue": browserCatalogue, "homeActions": homeActions,
      "captures": captures, "originalSkin": !GameArtworkSkin.lixEnabled,
      "menu": NSApp.mainMenu.map(parityMenu) ?? [], "profileSurvivedReopen": reopen]
    var mobile: [String: Any] = [:]
    for engine in ["l2", "l3"] {
      let support = AppStorage.current().applicationSupport.appendingPathComponent("parity-mobile-" + engine)
      let storage = MobileStorage(directory: support)
      let library: any MobileGameLibrary
      if engine == "l2" {
        library = try Lemmings2MobileLibrary(directory: AppDistribution.lemmings2(), storage: storage)
      } else {
        library = try Lemmings3MobileLibrary(directory: AppDistribution.lemmings3(), storage: storage)
      }
      let live = try library.loadLevel(at: 0).session
      for _ in 0..<17 { live.tick() }
      let checkpoint = try live.checkpointPayload()
      let checkpointURL = support.appendingPathComponent("parity-checkpoint.bin")
      if reopen {
        let restored = try library.loadLevel(at: 0).session
        try restored.restoreCheckpointPayload(Data(contentsOf: checkpointURL))
        try parityRequire(restored.snapshot == live.snapshot, engine + " changed its checkpoint after reopening.")
        try parityRequire(try restored.render(highlight: nil) == live.render(highlight: nil),
          engine + " changed its checkpoint pixels after reopening.")
      } else {
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        try checkpoint.write(to: checkpointURL, options: .atomic)
      }
      let frame = try live.render(highlight: nil)
      mobile[engine] = ["catalogue": try JSONSerialization.jsonObject(with: JSONEncoder().encode(library.levels)),
        "frameHash": parityHash(frame.rgba), "width": frame.width, "height": frame.height,
        "checkpointHash": parityHash(parityCanonical(checkpoint)), "reopenChecked": reopen]
    }
    result["mobileHostSessions"] = mobile
    result["neoNative"] = try await captureNeoAssetParity(folder: folder, reopen: reopen)
    if !reopen { persistence = try paritySavedSession(folder: folder, reopen: false) }
    result["persistence"] = persistence
    return result
  }
}

let parityApp = NSApplication.shared
parityApp.setActivationPolicy(.prohibited)
Task { @MainActor in
  do {
    let environment = ProcessInfo.processInfo.environment
    guard let phase = environment["LEMMIX_PARITY_PHASE"], let output = environment["LEMMIX_PARITY_OUTPUT"],
          let source = environment["LEMMIX_PARITY_SOURCE"],
          Bundle.main.bundleIdentifier?.contains("integration-tests") == true else { exit(2) }
    let folder = URL(fileURLWithPath: output)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    if phase != "reopen" {
      UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
    }
    if phase == "import" { UserDefaults.standard.set(true, forKey: GameArtworkSkin.key) }
    if phase == "reopen" {
      try parityRequire(UserDefaults.standard.object(forKey: GameArtworkSkin.key) as? Bool == false,
        "The saved Original artwork choice did not survive reopening.")
    }
    UserDefaults.standard.set(true, forKey: "NSApplicationCrashOnExceptions")
    var installation: OwnedResourceLibrary.Installation?
    if phase == "reference" {
      try GameResources.activate(bundleURL: URL(fileURLWithPath: source), forceReload: true)
      GameArtworkSkin.setLixEnabled(false)
    } else if phase == "reopen" {
      installation = try AppDistribution.ownedResourceLibrary.verifyInstalled()
      try parityRequire(installation != nil, "The installed bundle is missing after reopening.")
    }
    let support = AppStorage.current().applicationSupport.resolvingSymlinksInPath().standardizedFileURL
    try parityRequire(FanLevelLibrary.downloadFolder.resolvingSymlinksInPath().standardizedFileURL.path
      .hasPrefix(support.path + "/"), "Fan updates escaped isolated test storage.")
    let subject = AppDelegate()
    parityApp.delegate = subject
    subject.prepareAssetParityLaunch()
    subject.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
    if phase == "import" {
      installation = try subject.installParityResources(source: URL(fileURLWithPath: source))
    }
    var result = try await subject.captureAssetParity(folder: folder, reopen: phase == "reopen")
    result["phase"] = phase
    result["contentID"] = installation?.contentID ?? "reference-resources"
    result["resources"] = GameResources.resourceURL?.path ?? ""
    result["coverage"] = "Current frontend against source and restored resources. This does not run the unmodified baseline executable."
    let bytes = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
    try bytes.write(to: folder.appendingPathComponent("result.json"), options: .atomic)
    print("PASS asset parity phase " + phase)
    exit(0)
  } catch {
    FileHandle.standardError.write(Data("FAIL asset parity: \(error)\n".utf8))
    exit(1)
  }
}
parityApp.run()
