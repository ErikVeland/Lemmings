import AppKit
import NxlvKit

func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw SequelDataError.invalid(message) }
}

func testRecords() throws -> (ArcadeRecords, ArcadeReport) {
    var records = ArcadeRecords()
    let first = records.activeProfile.id
    let second = records.addProfile(initials: "abc!xyz", portrait: 40)!
    try require(second.initials == "ABC" && second.portrait == 7, "Profile input was not bounded")
    records.selectProfile(first)
    let level = ArcadeLevel(id: "beach-1", title: "Tricky rescue", game: "Lemmings 2", rules: "L2 native v1", total: 10, required: 5)
    func run(_ saved: Int, skills: Int, owner: String? = nil, assisted: Bool = false, win: Bool = true) -> ArcadeRun {
        ArcadeRun(profileID: owner ?? first, level: level, saved: saved, didWin: win,
            skills: ["builder": skills], seconds: 51.5, assisted: assisted)
    }
    let failed = run(0, skills: 0, win: false)
    _ = records.record(failed)
    try require(records.record(failed) == nil, "One completion counted twice")
    try require(records.leaderboard(level: level, board: .efficiency, assisted: false).isEmpty, "Failed zero-skill run ranked for efficiency")
    _ = records.record(run(5, skills: 1))
    _ = records.record(run(9, skills: 8))
    _ = records.record(run(2, skills: 1, win: false))
    try require(records.leaderboard(level: level, board: .rescue, assisted: false).first?.saved == 9, "Worse run erased rescue record")
    try require(records.leaderboard(level: level, board: .efficiency, assisted: false).first?.skillCount == 1, "Rescue record erased efficiency record")
    _ = records.record(run(10, skills: 0, owner: second.id, assisted: true))
    try require(records.leaderboard(level: level, board: .allSaved, assisted: false).isEmpty, "Assisted record entered clean board")
    try require(records.leaderboard(level: level, board: .allSaved, assisted: true).count == 1, "Assisted solution missing")
    let improved = records.record(run(9, skills: 6))!
    try require(improved.earned.contains(.fewerSkills) && improved.newSkillBest, "Efficiency improvement did not earn an award")
    try require(!improved.maximumIsProven && improved.bestKnown.saved == 9, "Best known was labelled a true maximum")
    let perfect = records.record(run(10, skills: 4))!
    try require(perfect.maximumIsProven && perfect.stats.allSaved == 1 && perfect.stats.zeroSaved == 1, "No/all-save statistics are wrong")
    try require(perfect.earned.contains(.allHome) && perfect.run.percentage == "100.0%", "Perfect rescue did not earn its award")
    try require(perfect.run.mostUsedSkill == "BUILDER X4", "Most-used skill is wrong")
    try require(perfect.challenge.contains("3 SKILLS"), "Perfect rescue did not suggest a further challenge")
    let otherPopulation = ArcadeLevel(id: level.id, title: level.title, game: level.game, rules: level.rules, total: 5, required: 5)
    try require(records.leaderboard(level: otherPopulation, board: .rescue, assisted: false).isEmpty, "Different carry-over populations shared a board")
    let otherPhysics = ArcadeLevel(id: level.id, title: level.title, game: level.game, rules: "Future physics", total: 10, required: 5)
    try require(records.leaderboard(level: otherPhysics, board: .rescue, assisted: false).isEmpty, "Different rules shared a board")
    let oldStats = records.stats(level: level, profileID: first, assisted: false)
    records.selectProfile(second.id)
    try require(records.stats(level: level, profileID: second.id, assisted: false).attempts == 0, "Profile inherited another player's level awards")
    try require(oldStats.attempts == 6 && oldStats.clears == 4, "Attempt/clear counts are wrong")
    for _ in 0..<100 { _ = records.record(run(1, skills: 2, win: false)) }
    try require(records.runs.count <= 6, "Record history grew with every failed attempt")
    try require(records.leaderboard(level: level, board: .rescue, assisted: false).first?.saved == 10, "Pruning erased the perfect rescue")
    let data = try JSONEncoder().encode(records)
    let restored = try JSONDecoder().decode(ArcadeRecords.self, from: data).validated()
    try require(restored == records, "Arcade records failed to round-trip")
    print("PASS rescue/efficiency/100% boards, record retention, awards, population/rules/assistance isolation and profile statistics")
    return (records, perfect)
}

func testSkillAccounting() throws {
    var pixels = Data(repeating: 0, count: 128 * 96)
    for x in 0..<128 { pixels[70 * 128 + x] = 1 }
    let terrain = try ClassicDOSTerrain(width: 128, height: 96, solidMask: pixels, steelMask: Data(repeating: 0, count: pixels.count))
    let simulation = try ClassicDOSSimulation(terrain: terrain, configuration: ClassicDOSConfiguration(
        totalLemmings: 2, requiredToSave: 1, timeLimitTicks: 1000, initialReleaseRate: 50,
        entrances: [ClassicDOSPoint(x: 20, y: 50)], initialSkills: [.climber: 2], maximumX: 127, maximumY: 95))
    let session = ClassicSession(simulation: simulation, width: 128, height: 96)
    for _ in 0..<120 where session.lemmings.isEmpty { session.tick() }
    let id = session.lemmings.first!.id
    try require(session.assign(skillIndex: -1, to: id) != nil && session.assign(skillIndex: 8, to: id) != nil, "Invalid classic skill indices were accepted")
    try require(session.assign(skillIndex: 0, to: id) == nil, "Classic skill assignment fixture failed")
    try require(session.assign(skillIndex: 0, to: id) != nil, "Classic duplicate assignment should be rejected")
    try require(session.skillAssignments == ["climber": 1], "Rejected classic clicks counted as skills")
    for _ in 0..<3 { session.tick() }
    try require(session.rewind(seconds: 1), "Classic rewind fixture failed")
    try require(session.skillAssignments.isEmpty && session.usedRewind, "Rewind retained discarded skills or entered clean records")
    session.nuke(); session.undoNuke()
    try require(session.skillAssignments.isEmpty && session.usedRewind, "Nuke undo corrupted skill accounting")

    var neoTerrain = try NeoLemmixTerrain(width: 128, height: 96)
    for x in 0..<128 { neoTerrain.setSolid(true, x: x, y: 48) }
    let config = try NeoLemmixConfiguration(totalLemmings: 1, requiredToSave: 1, timeLimitTicks: 1000,
        spawnInterval: 20, entrances: [], zones: [],
        preplacedLemmings: [NeoLemmixPreplacedLemming(position: NeoLemmixPoint(x: 20, y: 48))], skills: [.climber: .infinite])
    let neo = NeoLemmixSession(simulation: try NeoLemmixSimulation(terrain: neoTerrain, configuration: config), width: 128, height: 96)
    neo.tick()
    try require(neo.assign(skillIndex: -1, to: 0) != nil && neo.assign(skillIndex: 999, to: 0) != nil, "Invalid NeoLemmix skill indices were accepted")
    try require(neo.assign(skillIndex: 0, to: 0) == nil, "NeoLemmix infinite skill fixture failed")
    try require(neo.assign(skillIndex: 0, to: 0) != nil, "NeoLemmix duplicate assignment should be rejected")
    try require(neo.skillAssignments == ["climber": 1], "Infinite supplies bypassed skill accounting")
    neo.nuke(); neo.undoNuke()
    try require(neo.skillAssignments == ["climber": 1] && neo.usedRewind, "NeoLemmix nuke undo lost skill accounting")
    print("PASS accepted-only classic and infinite NeoLemmix skill counts, rewind and nuke-undo accounting")
}

@MainActor func testStoreAndView(_ sample: (ArcadeRecords, ArcadeReport)) async throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".build/arcade")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let file = root.appendingPathComponent("test-records-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: file) }
    let store = ArcadeStore(file: file); ArcadeStore.shared = store
    let legacy = store.records.activeProfileID
    try require(store.progressKey("ClassicGameProgress.lemmings") == "ClassicGameProgress.lemmings", "Legacy campaign save was moved")
    let profile = store.addProfile(initials: "ACE", portrait: 3)!
    try require(store.progressKey("ClassicGameProgress.lemmings") != "ClassicGameProgress.lemmings", "New profile shares old campaign progress")
    _ = store.record(ArcadeRun(profileID: profile.id, level: sample.1.run.level, saved: 10,
        didWin: true, skills: ["builder": 4], seconds: 51.5))
    let restored = ArcadeStore(file: file)
    try require(restored.records == store.records && restored.storageError == nil, "Atomic store did not restore profile and records")
    let bytes = try Data(contentsOf: file)
    try Data("broken".utf8).write(to: file)
    let backup = try Data(contentsOf: file.appendingPathExtension("backup"))
    let recovered = ArcadeStore(file: file)
    try require(recovered.storageError == nil && recovered.storageNotice != nil && recovered.profilesAreWritable,
        "Valid backup was not recovered through the app store")
    let recoveredBytes = try Data(contentsOf: file)
    try require(recoveredBytes == backup, "Recovery did not restore the previous good records")
    let copies = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
        .filter { $0.lastPathComponent.hasPrefix(file.lastPathComponent + ".unreadable-") }
    try require(copies.count == 1, "Recovery did not preserve one unreadable primary")
    let preservedBytes = try Data(contentsOf: copies[0])
    try require(preservedBytes == Data("broken".utf8), "Recovery discarded the unreadable primary")
    for copy in copies { try FileManager.default.removeItem(at: copy) }
    try bytes.write(to: file)
    let view = ArcadeView(frame: NSRect(x: 0, y: 0, width: 1120, height: 720))
    let artwork = try ClassicMacArtwork(directory: URL(fileURLWithPath: ProcessInfo.processInfo.environment["LEMMINGS_TEST_APP"] ?? ".build/local/Ultimate Lemmings.app").appendingPathComponent("Contents/Resources/MacArtwork/lemmings"))
    view.useArtwork(artwork)
    view.mode = .profiles; view.selectProfile(profile)
    let window = NSWindow(contentRect: view.frame, styleMask: [.titled], backing: .buffered, defer: false)
    window.contentView = view
    func shot(_ name: String) throws {
        let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
        view.cacheDisplay(in: view.bounds, to: bitmap)
        try bitmap.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent(name + ".png"))
    }
    try shot("profiles")
    var before = 0, after = 0, closed = 0
    view.beforeSwitch = { before += 1 }; view.afterSwitch = { after += 1 }; view.onClose = { closed += 1 }
    func key(_ text: String, code: UInt16 = 0) {
        view.keyDown(with: NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: window.windowNumber, context: nil, characters: text, charactersIgnoringModifiers: text,
            isARepeat: false, keyCode: code)!)
    }
    let beforeFailure = try Data(contentsOf: file)
    let backupURL = file.appendingPathExtension("backup")
    try FileManager.default.removeItem(at: backupURL)
    try FileManager.default.createDirectory(at: backupURL, withIntermediateDirectories: false)
    key("xyz"); key("\r", code: 36)
    try require(store.storageError != nil && store.records.activeProfile.initials == profile.initials
        && after == 0 && closed == 0, "Failed profile save changed the player or dismissed the error")
    let afterFailure = try Data(contentsOf: file)
    try require(afterFailure == beforeFailure, "Failed profile save damaged stored records")
    let profileCount = store.records.profiles.count
    try require(store.addProfile(initials: "ERR", portrait: 0) == nil && store.records.profiles.count == profileCount,
        "Failed player creation left an unsaved profile active")
    try shot("save-failure")
    try FileManager.default.removeItem(at: backupURL)
    let retryPoint = view.convert(NSPoint(x: 971, y: 703), to: nil)
    view.mouseDown(with: NSEvent.mouseEvent(with: .leftMouseDown, location: retryPoint, modifierFlags: [], timestamp: 0,
        windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!)
    try require(store.records.activeProfile.initials == "XYZ" && before == 2 && after == 1 && closed == 1
        && store.storageError == nil, "Retry did not commit the profile and close after success")
    view.canSwitch = false; view.selectProfile(store.records.profile(legacy)!); key("\r", code: 36)
    try require(store.records.activeProfile.id == profile.id && before == 2, "Mid-run profile switch changed the run owner")
    view.mode = .result; view.level = sample.1.run.level
    let result = store.record(ArcadeRun(profileID: profile.id, level: sample.1.run.level, saved: 10,
        didWin: true, skills: ["builder": 3], seconds: 48.2))!
    view.report = result
    var retried = 0, continued = 0
    view.onRetry = { retried += 1 }; view.onContinue = { continued += 1 }
    try shot("results-perfect")
    key("a"); try shot("level-awards"); key("\r", code: 36)
    try require(continued == 0 && view.mode == .result, "Leaving achievements advanced the level")
    key("r"); key("\r", code: 36)
    try require(retried == 1 && continued == 1, "Successful results do not offer retry and continue")
    let failed = store.record(ArcadeRun(profileID: profile.id, level: sample.1.run.level, saved: 0,
        didWin: false, skills: [:], seconds: 10))!
    view.report = failed
    try shot("results-failed")
    key("b"); try shot("leaderboards")
    key("d"); try shot("run-details")
    key("\r", code: 36)
    window.makeKeyAndOrderFront(nil)
    NSApplication.shared.activate(ignoringOtherApps: true)
    try await Task.sleep(for: .milliseconds(200))
    let windowCount = NSApplication.shared.windows.count
    ArcadeWindow.shared.showResult(result, owner: window, retry: { retried += 1 }, next: {}, replay: { _ in })
    try await Task.sleep(for: .milliseconds(100))
    try require(ArcadeWindow.shared.arcadeView.window === window && NSApplication.shared.windows.count == windowCount,
                "Results created a separate window")
    let nested = GameMenuPage(title: "Nested screen")
    GameScreen.shared.present(nested)
    window.setContentSize(CGSize(width: 2240, height: 1440))
    window.contentView?.layoutSubtreeIfNeeded(); nested.layoutSubtreeIfNeeded()
    let menuBounds = nested.convert(nested.body.bounds, from: nested.body)
    try require(menuBounds.minX >= 0 && menuBounds.maxX <= nested.bounds.width && abs(menuBounds.width - 992 * GamePageLayout.scale(in: nested.bounds.size)) < 1,
                "Menu controls escaped the page at the fullscreen render scale")
    try require(ArcadeWindow.shared.arcadeView.isHidden && nested.window === window, "Nested page escaped the game")
    GameScreen.shared.dismiss(nested)
    window.setContentSize(CGSize(width: 1120, height: 720))
    try require(!ArcadeWindow.shared.arcadeView.isHidden && window.firstResponder === ArcadeWindow.shared.arcadeView,
                "Back did not restore the results page")
    ArcadeWindow.shared.arcadeView.onRetry?()
    try await Task.sleep(for: .milliseconds(100))
    try require(window.isKeyWindow && retried == 2, "Retry did not restore keyboard focus to the game window (active: \(NSApplication.shared.isActive), visible: \(window.isVisible), retried: \(retried), key: \(NSApplication.shared.keyWindow?.title ?? "none"))")
    window.orderOut(nil)
    print("PASS atomic save/reload, corrupt-file preservation, legacy progress namespace, sprite profiles, in-game pages, nested Back and successful retry controls")
}

@MainActor func testSharedSession() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = ArcadeStore(file: directory.appendingPathComponent("records.json"), bundledProofs: nil)
    let previous = ArcadeStore.shared
    ArcadeStore.shared = store
    defer { ArcadeStore.shared = previous }
    let host = store.records.activeProfileID
    let partner = store.addProfile(initials: "TWO", portrait: 1)!
    let friend = store.addProfile(initials: "TRI", portrait: 2)!
    store.selectProfile(host)
    try require(store.nextSessionProfile(after: host) == nil, "Solo play offered a guest")
    store.toggleSessionProfile(partner.id); store.toggleSessionProfile(friend.id)
    let namespace = store.progressKey("campaign")
    try require(store.passSessionTurn(after: host) && store.playingProfileID == partner.id, "First handoff failed")
    try require(store.passSessionTurn(after: partner.id) && store.playingProfileID == friend.id, "Third player was skipped")
    try require(store.passSessionTurn(after: friend.id) && store.playingProfileID == host, "Turn order did not wrap")
    try require(store.records.activeProfileID == host && store.progressKey("campaign") == namespace, "Shared progress changed owner")
    store.toggleSessionProfile(partner.id)
    try require(store.nextSessionProfile(after: host)?.id == friend.id, "Removed guest stayed in rotation")
    let sharedKey = store.progressKey("campaign")
    UserDefaults.standard.set("shared progress", forKey: sharedKey)
    store.turnPolicy = .atFirstFail
    let resumed = ArcadeStore(file: directory.appendingPathComponent("records.json"), bundledProofs: nil)
    try require(resumed.hotSeatID == store.hotSeatID && resumed.sessionProfileIDs == store.sessionProfileIDs,
        "Relaunch lost shared campaign or roster")
    try require(resumed.playingProfileID == store.playingProfileID, "Relaunch lost the next turn")
    store.endHotSeat()
    try require(store.progressKey("campaign") != sharedKey && UserDefaults.standard.string(forKey: sharedKey) == "shared progress",
        "Solo transition erased shared progress or retained its namespace")
    try require(store.turnPolicy == .atFirstFail, "Solo transition erased the house rule")
    store.prepareHotSeat()
    try require(store.progressKey("campaign") == sharedKey, "Rejoining created an empty shared campaign")
    let previousID = store.hotSeatID
    let roster = store.sessionProfileIDs
    try require(store.passSessionTurn(after: host), "New-session fixture could not pass the turn")
    let soloKey = ArcadeStore.progressKey("campaign", profileID: host)
    UserDefaults.standard.set("solo progress", forKey: soloKey)
    defer { UserDefaults.standard.removeObject(forKey: soloKey) }
    try require(store.startNewHotSeat(), "Could not start a new Hot Seat")
    try require(store.hotSeatID != previousID && store.sessionProfileIDs == roster && store.playingProfileID == host,
        "New Hot Seat retained old identity/turn or changed players")
    try require(UserDefaults.standard.object(forKey: store.progressKey("campaign")) == nil
        && UserDefaults.standard.string(forKey: soloKey) == "solo progress"
        && UserDefaults.standard.string(forKey: sharedKey) == "shared progress",
        "New Hot Seat reused shared progress or erased prior/solo data")
    let fresh = ArcadeStore(file: directory.appendingPathComponent("records.json"), bundledProofs: nil)
    try require(fresh.hotSeatID == store.hotSeatID && fresh.playingProfileID == host,
        "Relaunch returned to the replaced Hot Seat")
    UserDefaults.standard.removeObject(forKey: sharedKey)
    store.turnPolicy = .everyLevel
    store.toggleSessionProfile("missing")
    try require(store.sessionProfiles.count == 2, "Unknown profile entered session")
    let level = ArcadeLevel(id: "shared", title: "Shared level", game: "Classic", rules: "test", total: 10, required: 5)
    let report = store.record(ArcadeRun(profileID: host, level: level, saved: 0, didWin: false, skills: [:], seconds: 2))!
    let view = ArcadeView(frame: CGRect(x: 0, y: 0, width: 1120, height: 720))
    view.mode = .result; view.report = report
    var retries = 0
    view.onRetry = { retries += 1 }
    try require(view.primaryResultTitle == "Retry as TRI", "Next player missing from retry label")
    view.performDefaultResultAction()
    try require(retries == 1 && store.playingProfileID == friend.id && report.run.profileID == host, "Default result handoff changed old results")
    let artwork = try ClassicMacArtwork(directory: URL(fileURLWithPath: ProcessInfo.processInfo.environment["LEMMINGS_TEST_APP"] ?? ".build/local/Ultimate Lemmings.app").appendingPathComponent("Contents/Resources/MacArtwork/lemmings"))
    view.useArtwork(artwork)
    let window = NSWindow(contentRect: view.frame, styleMask: [.titled], backing: .buffered, defer: false)
    window.contentView = view
    func shot(_ name: String) throws {
        let output = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".build/hot-seat-shots")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
        view.cacheDisplay(in: view.bounds, to: bitmap)
        try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(name + ".png"))
    }
    try shot("retry")
    view.performDefaultResultAction()
    guard let handover = GameScreen.shared.controllerPage(in: window) as? GameMenuPage else {
        throw SequelDataError.invalid("Handover did not wait for Ready")
    }
    func buttons(_ view: NSView) -> [NSButton] { (view as? NSButton).map { [$0] } ?? view.subviews.flatMap(buttons) }
    let ready = buttons(handover).first { $0.title == "Ready, TRI" }
    try require(ready != nil && handover.onBack == nil, "Handover has no explicit Ready action")
    let navigator = ControllerMenuNavigator()
    navigator.handle(.rate(-1), in: handover)
    try require(navigator.selected === ready, "Controller selected the hidden Back button during handover")
    let repeated = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
        windowNumber: window.windowNumber, context: nil, characters: "\r", charactersIgnoringModifiers: "\r", isARepeat: true, keyCode: 36)!
    try require(handover.performKeyEquivalent(with: repeated) && GameScreen.shared.isPresented,
        "A held Return key skipped the handover")
    navigator.handle(.assign, in: handover)
    try require(!GameScreen.shared.isPresented, "Ready did not release the handover")
    view.openSession()
    try shot("players")
    try require(view.mode == .hotSeat, "Players did not open session setup")
    let beforeCancel = store.hotSeatID
    view.confirmNewHotSeat()
    guard let confirmation = GameScreen.shared.controllerPage(in: window) as? GameMenuPage else {
        throw SequelDataError.invalid("New Hot Seat did not show confirmation")
    }
    confirmation.onBack?()
    try require(store.hotSeatID == beforeCancel, "Cancelling replaced the shared campaign")
    view.confirmNewHotSeat()
    guard let accepted = GameScreen.shared.controllerPage(in: window) as? GameMenuPage,
        let start = buttons(accepted).first(where: { $0.title == "Start new Hot Seat" }) else {
        throw SequelDataError.invalid("New Hot Seat confirmation has no explicit start action")
    }
    start.performClick(nil)
    try require(store.hotSeatID != beforeCancel && !GameScreen.shared.isPresented,
        "Confirmed New Hot Seat did not start a fresh campaign")
    view.closeSession()
    try require(view.mode == .result, "Done lost the result page")
    let winningReport = store.record(ArcadeRun(profileID: host, level: level, saved: 10, didWin: true, skills: [:], seconds: 2))!
    view.report = winningReport
    var advances = 0
    view.onContinue = { advances += 1 }
    try Data("external change".utf8).write(to: directory.appendingPathComponent("records.json"))
    store.save()
    let idBeforeFailure = store.hotSeatID
    try require(!store.startNewHotSeat() && store.hotSeatID == idBeforeFailure, "Storage failure replaced the shared campaign")
    let turnBeforeFailure = store.playingProfileID
    try require(!store.passSessionTurn(after: friend.id) && store.playingProfileID == turnBeforeFailure,
        "Storage failure changed the player")
    view.continueAsNextProfile()
    try require(advances == 0, "Failed handover advanced the level with the wrong player")
    store.endHotSeat()
    try require(store.playingProfileID == host && store.nextSessionProfile(after: host) == nil, "Play solo did not end rotation")
    print("PASS hot-seat roster, three-player rotation, removal, shared progress owner, separate result owner and retry action")
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
Task { @MainActor in
    do {
        try testSharedSession()
        let sample = try testRecords()
        try testSkillAccounting()
        try await testStoreAndView(sample)
        exit(0)
    } catch { print("FAIL: \(error)"); exit(1) }
}
app.run()
