import AppKit
import Darwin
import NxlvKit

func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw SequelDataError.invalid(message) }
}

@MainActor func testLevelPlaylistStore() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("playlist-store-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("playlists.json")
    let date = Date(timeIntervalSince1970: 1_700_000_000)
    func entry(_ number: Int) throws -> LevelPlaylistEntry {
        try LevelPlaylistEntry(
            id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", number))!,
            identity: .init(engine: .classic, packID: "classic", levelID: "level-\(number)"),
            catalogueRevision: "catalogue-1",
            sourceRevision: "source-\(number)",
            packNameSnapshot: "Classic",
            levelNameSnapshot: "Level \(number)",
            levelNumberSnapshot: number)
    }
    let first = try LevelPlaylist(
        id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
        name: "First", entries: [try entry(1)], createdAt: date)
    let second = try LevelPlaylist(
        id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!,
        name: "Second", entries: [try entry(2)], createdAt: date)
    let pool = try LevelPool(id: "playlist:first", summary: "First playlist")
    let firstRun = try LevelSequenceRun.playlist(first, pool: pool, createdAt: date)

    let writer = try LevelPlaylistStore(file: file)
    try require(writer.playlists.isEmpty && writer.selectedPlaylistID == nil,
        "A new playlist store was not empty")
    try writer.add(first)
    try require(writer.selectedPlaylist() == first, "Adding a playlist did not select it")
    try writer.setActiveRun(firstRun)
    let stale = try LevelPlaylistStore(file: file)
    try writer.add(second)
    do {
        try stale.selectPlaylist(id: first.id)
        throw SequelDataError.invalid("A stale playlist store overwrote a newer save")
    } catch LevelPlaylistStore.Failure.changedOnDisk {
        // Expected: the newer file stays authoritative.
    }

    let legacyFile = directory.appendingPathComponent("legacy-v1.json")
    var legacy = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as! [String: Any]
    legacy["version"] = 1
    legacy.removeValue(forKey: "savedRuns"); legacy.removeValue(forKey: "activeRunHotSeatID")
    try JSONSerialization.data(withJSONObject: legacy).write(to: legacyFile)
    let migrated = try LevelPlaylistStore(file: legacyFile)
    try require(migrated.activeRun == firstRun && migrated.savedRuns.isEmpty,
        "A version 1 solo run did not load")
    try migrated.selectPlaylist(id: first.id)
    let upgraded = try JSONSerialization.jsonObject(with: Data(contentsOf: legacyFile)) as! [String: Any]
    try require(upgraded["version"] as? Int == 2,
        "Session history was left writable by an older app version")

    let sessionsFile = directory.appendingPathComponent("sessions.json")
    let sessions = try LevelPlaylistStore(file: sessionsFile)
    try sessions.add(first)
    try sessions.add(second)
    try sessions.setActiveRun(firstRun)
    let sharedRun = try LevelSequenceRun.playlist(second, pool: pool)
    try sessions.startRun(sharedRun, hotSeatID: "shared-session")
    let reopenedSessions = try LevelPlaylistStore(file: sessionsFile)
    try require(reopenedSessions.activeRunHotSeatID == "shared-session"
        && reopenedSessions.savedRuns.first?.run == firstRun
        && reopenedSessions.savedRuns.first?.hotSeatID == nil,
        "Starting Hot Seat did not save the previous solo sequence")
    try reopenedSessions.resumeRun(id: firstRun.id)
    try require(reopenedSessions.activeRun == firstRun && reopenedSessions.activeRunHotSeatID == nil
        && reopenedSessions.savedRuns.first?.run == sharedRun
        && reopenedSessions.savedRuns.first?.hotSeatID == "shared-session",
        "Resuming solo lost the shared sequence or its owner")
    let staleSessions = try LevelPlaylistStore(file: sessionsFile)
    try reopenedSessions.resumeRun(id: sharedRun.id)
    do {
        try staleSessions.startRun(sharedRun, hotSeatID: "other-session")
        throw SequelDataError.invalid("A stale session writer replaced saved runs")
    } catch LevelPlaylistStore.Failure.changedOnDisk {}
    try require(staleSessions.activeRun == firstRun && staleSessions.activeRunHotSeatID == nil,
        "A failed session save changed in-memory ownership")
    try reopenedSessions.removePlaylist(id: first.id)
    try require(reopenedSessions.savedRuns.isEmpty && reopenedSessions.activeRun == sharedRun,
        "Deleting a playlist retained its archived run or removed another session")

    let restored = try LevelPlaylistStore(file: file)
    try require(restored.playlists == [first, second]
        && restored.selectedPlaylistID == second.id
        && restored.activeRun == firstRun,
        "Playlists, selection or active sequence did not round-trip")
    try restored.removePlaylist(id: second.id)
    try require(restored.selectedPlaylistID == first.id && restored.activeRun == firstRun,
        "Removing another playlist changed the active sequence")
    try restored.removePlaylist(id: first.id)
    try require(restored.playlists.isEmpty && restored.selectedPlaylistID == nil
        && restored.activeRun == nil,
        "Removing an active playlist left its selection or sequence")

    do {
        try restored.add(first)
        try restored.add(first)
        throw SequelDataError.invalid("A duplicate playlist identity was accepted")
    } catch LevelPlaylistStore.Failure.duplicatePlaylist {
        // Expected.
    }
    do {
        try restored.setActiveRun(try LevelSequenceRun.playlist(
            second,
            pool: try LevelPool(id: "playlist:missing", summary: "Missing playlist"),
            createdAt: date))
        throw SequelDataError.invalid("A sequence for a missing playlist was accepted")
    } catch LevelPlaylistStore.Failure.missingPlaylist {
        // Expected.
    }

    let expectedBackup = try Data(contentsOf: file.appendingPathExtension("backup"))
    try Data("broken".utf8).write(to: file, options: .atomic)
    let recovered = try LevelPlaylistStore(file: file)
    let recoveredData = try Data(contentsOf: file)
    try require(recovered.recovered && recoveredData == expectedBackup,
        "A damaged playlist file was not restored from its last good backup")
    let preserved = try FileManager.default.contentsOfDirectory(
        at: directory, includingPropertiesForKeys: nil)
        .filter { $0.lastPathComponent.hasPrefix("playlists.json.unreadable-") }
    let preservedData = try preserved.first.map { try Data(contentsOf: $0) }
    try require(preserved.count == 1 && preservedData == Data("broken".utf8),
        "Playlist recovery did not preserve the unreadable primary")
    let heldLock = open(
        file.appendingPathExtension("lock").path,
        O_CREAT | O_RDWR,
        S_IRUSR | S_IWUSR)
    try require(heldLock >= 0 && flock(heldLock, LOCK_EX | LOCK_NB) == 0,
        "Playlist deletion lock fixture could not start")
    DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) {
        flock(heldLock, LOCK_UN)
        close(heldLock)
    }
    let deletionStarted = ProcessInfo.processInfo.systemUptime
    LevelPlaylistStore.removeData(at: file)
    try require(ProcessInfo.processInfo.systemUptime - deletionStarted >= 0.03,
        "Playlist deletion did not wait for an active writer lock")
    let playlistRemainders = try FileManager.default.contentsOfDirectory(
        at: directory, includingPropertiesForKeys: nil).filter {
            $0.lastPathComponent == file.lastPathComponent
                || $0.lastPathComponent == file.appendingPathExtension("backup").lastPathComponent
                || $0.lastPathComponent.hasPrefix(file.lastPathComponent + ".unreadable-")
        }
    try require(playlistRemainders.isEmpty,
        "Deleting playlist data left a recovered unreadable sibling")
    try require(FileManager.default.fileExists(
        atPath: file.appendingPathExtension("lock").path),
        "Deleting playlist data removed the cross-process lock inode")

    let unsupportedFile = directory.appendingPathComponent("unsupported.json")
    let unsupportedStore = try LevelPlaylistStore(file: unsupportedFile)
    try unsupportedStore.add(first)
    var object = try JSONSerialization.jsonObject(with: Data(contentsOf: unsupportedFile)) as! [String: Any]
    object["version"] = 3
    object.removeValue(forKey: "playlists")
    try JSONSerialization.data(withJSONObject: object).write(to: unsupportedFile, options: .atomic)
    do {
        _ = try LevelPlaylistStore(file: unsupportedFile)
        throw SequelDataError.invalid("A future playlist format was replaced from backup")
    } catch LevelPlaylistStore.Failure.unsupportedVersion {
        // Expected: preserve a future format for a newer app.
    }

    var removedProfiles: [String] = []
    let recordsFile = directory.appendingPathComponent("records.json")
    let arcade = ArcadeStore(
        file: recordsFile,
        bundledProofs: nil,
        playlistDataRemover: { removedProfiles.append($0) })
    let previewLevel = ArcadeLevel(
        id: "playlist-preview", title: "Playlist preview", game: "Lemmings",
        rules: "classic-dos-v1", total: 10, required: 5)
    let previewRun = ArcadeRun(
        profileID: arcade.records.activeProfileID, level: previewLevel,
        saved: 5, didWin: true, skills: ["builder": 1], seconds: 20)
    let beforePreview = arcade.records
    try require(arcade.previewReport(for: previewRun) != nil
        && arcade.records == beforePreview,
        "A transient playlist result changed player records")
    let guest = arcade.addProfile(initials: "PLY", portrait: 1)!
    try require(arcade.deleteProfile(guest.id) && removedProfiles == [guest.id],
        "Deleting a player did not remove that player's playlist data")
    print("PASS profile-owned playlist persistence, conflict detection, recovery and deletion cleanup")
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
    try require(store.records.activeProfile.initials == "XYZ" && before == 0 && after == 0 && closed == 0
        && store.storageError == nil, "Retry did not save the edited initials in place")
    try shot("profiles-saved")
    key("\r", code: 36)
    try require(closed == 1 && before == 0, "Done did not close the players page without switching")
    view.canSwitch = false; view.selectProfile(store.records.profile(legacy)!)
    try require(view.profilePrimaryTitle == "Done", "A run in progress offered to switch players")
    key("\r", code: 36)
    try require(store.records.activeProfile.id == profile.id && before == 0, "Mid-run profile switch changed the run owner")
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
        try await Task.sleep(nanoseconds: 200_000_000)
    let windowCount = NSApplication.shared.windows.count
    ArcadeWindow.shared.showResult(result, owner: window, retry: { retried += 1 }, next: {}, replay: { _ in })
        try await Task.sleep(nanoseconds: 100_000_000)
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
        try await Task.sleep(nanoseconds: 100_000_000)
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
    let freshID = store.hotSeatID!
    store.turnPolicy = .everyLevel
    try require(store.savedHotSeats.contains(where: { $0.id == previousID }),
        "The previous Hot Seat was not available to resume")
    try require(store.resumeHotSeat(id: previousID!) && store.progressKey("campaign") == sharedKey
        && store.playingProfileID == friend.id && store.turnPolicy == .atFirstFail,
        "Resuming a saved Hot Seat lost progress, roster, turn or house rule")
    let resumedHistory = ArcadeStore(file: directory.appendingPathComponent("records.json"), bundledProofs: nil)
    try require(resumedHistory.hotSeatID == previousID
        && resumedHistory.savedHotSeats.contains(where: { $0.id == freshID }),
        "Session history did not survive relaunch")
    try require(store.resumeHotSeat(id: freshID), "Could not resume the new Hot Seat")
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

@MainActor func testProfileJourneys() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let checkpoints = RunRecoveryStore(directory: directory.appendingPathComponent("Checkpoints"))
    let records = directory.appendingPathComponent("records.json")
    let store = ArcadeStore(file: records, bundledProofs: nil, checkpoints: checkpoints)
    let previous = ArcadeStore.shared
    ArcadeStore.shared = store
    defer { ArcadeStore.shared = previous }
    let host = store.records.activeProfileID
    let view = ArcadeView(frame: CGRect(x: 0, y: 0, width: 1120, height: 720))
    let artwork = try ClassicMacArtwork(directory: URL(fileURLWithPath: ProcessInfo.processInfo.environment["LEMMINGS_TEST_APP"] ?? ".build/local/Ultimate Lemmings.app").appendingPathComponent("Contents/Resources/MacArtwork/lemmings"))
    view.useArtwork(artwork)
    let window = NSWindow(contentRect: view.frame, styleMask: [.titled], backing: .buffered, defer: false)
    window.contentView = view
    let output = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".build/profile-shots")
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    func shot(_ name: String) throws {
        let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
        view.cacheDisplay(in: view.bounds, to: bitmap)
        try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(name + ".png"))
    }
    func key(_ text: String, code: UInt16 = 0) {
        view.keyDown(with: NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: window.windowNumber, context: nil, characters: text, charactersIgnoringModifiers: text,
            isARepeat: false, keyCode: code)!)
    }
    func buttons(_ view: NSView) -> [NSButton] { (view as? NSButton).map { [$0] } ?? view.subviews.flatMap(buttons) }
    var switches = 0, closes = 0
    view.beforeSwitch = {}; view.afterSwitch = { switches += 1 }; view.onClose = { closes += 1 }

    // Hot Seat with one player: the primary action adds a player and returns to the roster.
    view.canSwitch = true
    view.mode = .hotSeat; try shot("hot-seat-one-player")
    key("\r", code: 36)
    try require(view.mode == .profiles && view.isNewProfile && view.profilePrimaryTitle == "Add player", "Hot Seat did not start a new player")
    try shot("new-player")
    key("b"); key("o"); key("b"); key("\r", code: 36)
    let bob = store.records.profiles.first { $0.initials == "BOB" }
    try require(bob != nil && view.mode == .hotSeat && store.hotSeatIsActive && store.sessionProfileIDs.contains(bob!.id)
        && store.records.activeProfileID == host, "Adding a player from Hot Seat did not join the roster without switching host")
    try shot("hot-seat-ready")

    // Editing an existing player saves at once, without a confirm button.
    view.mode = .profiles; view.selectProfile(bob!)
    key("r"); key("o"); key("b")
    try require(store.records.profile(bob!.id)?.initials == "ROB" && ArcadeStore(file: records, bundledProofs: nil, checkpoints: checkpoints)
        .records.profile(bob!.id)?.initials == "ROB", "Edited initials were not saved automatically")
    try shot("edit-player")
    let nextPortrait = (bob!.portrait + 1) % 8
    let portraitButton = view.accessibilityChildren()?.compactMap { $0 as? GameAccessibleElement }
        .first { $0.accessibilityLabel() == "Portrait: " + ArcadeProfile.portraitNames[nextPortrait] }
    try require(portraitButton?.accessibilityPerformPress() == true, "The next portrait has no input target")
    try require(store.records.profile(bob!.id)?.portrait == (bob!.portrait + 1) % 8, "Portrait change was not saved automatically")
    try require(view.profilePrimaryTitle == "Play as ROB", "Other player did not offer Play as")
    try shot("edit-player")

    // A run in progress cannot delete the host or a roster player.
    try require(!store.canDeleteProfile(host, runInProgress: true) && !store.canDeleteProfile(bob!.id, runInProgress: true),
        "A player in the current run or turn could be deleted")
    store.endHotSeat()

    // Deleting a player removes records, progress, saved runs and shared campaigns they host.
    let level = ArcadeLevel(id: "delete", title: "Delete level", game: "Classic", rules: "test", total: 10, required: 5)
    _ = store.record(ArcadeRun(profileID: bob!.id, level: level, saved: 7, didWin: true, skills: [:], seconds: 3))
    _ = store.record(ArcadeRun(profileID: host, level: level, saved: 5, didWin: true, skills: [:], seconds: 4))
    let progressKey = ArcadeStore.progressKey("ClassicGameProgress.test", profileID: bob!.id)
    UserDefaults.standard.set(Data([1]), forKey: progressKey)
    defer { UserDefaults.standard.removeObject(forKey: progressKey) }
    let run = RunRecovery(engine: "test", profileID: bob!.id, runID: UUID(), dataSetID: "lemmings", levelIndex: 0,
        levelFingerprint: "f", initialStateHash: "i", tick: 1, events: [], stateHash: "s", usedRewind: false,
        nukeCount: 0, rewindCount: 0, undoCount: 0, selectedSkill: 0, scrollX: 0, scrollY: 0)
    checkpoints.save(run, immediately: true) { _ in }
    let savedRun = try checkpoints.latest(profileID: bob!.id)
    try require(savedRun?.runID == run.runID, "Checkpoint fixture was not saved")
    view.selectProfile(store.records.profile(bob!.id)!)
    view.confirmDeleteSelectedProfile()
    guard let confirmation = GameScreen.shared.controllerPage(in: window) as? GameMenuPage,
          let delete = buttons(confirmation).first(where: { $0.title == "Delete ROB" }) else {
        throw SequelDataError.invalid("Delete did not ask for confirmation")
    }
    try shot("delete-confirmation")
    delete.performClick(nil)
    let remainingRun = try checkpoints.latest(profileID: bob!.id)
    try require(store.records.profile(bob!.id) == nil && store.records.runs.allSatisfy { $0.profileID != bob!.id }
        && store.records.trolley.attempts.allSatisfy { $0.run.profileID != bob!.id }
        && UserDefaults.standard.object(forKey: progressKey) == nil
        && remainingRun == nil
        && store.records.leaderboard(level: level, board: .rescue, assisted: false).first?.saved == 5,
        "Deleting a player left their data or removed another player's records")
    let reloaded = try ArcadeStore(file: records, bundledProofs: nil, checkpoints: checkpoints).records.validated()
    try require(reloaded.profile(bob!.id) == nil, "Deletion was not saved")
    try require(view.selectedProfileID == host && store.records.profiles.count == 1, "Deletion did not select a remaining player")
    try require(!store.canDeleteProfile(host, runInProgress: false), "The last player could be deleted")
    try shot("after-delete")

    // Deleting the active player switches to another player.
    let cat = store.addProfile(initials: "CAT", portrait: 2, select: true)!
    let beforeDelete = switches
    view.canSwitch = true
    view.deleteProfile(cat.id)
    try require(store.records.activeProfileID == host && switches == beforeDelete + 1, "Deleting the active player did not switch players")

    // A saved run that cannot restore can be discarded; its bytes are kept aside.
    let broken = RunRecovery(engine: "test", profileID: host, runID: UUID(), dataSetID: "lemmings", levelIndex: 0,
        levelFingerprint: "f", initialStateHash: "i", tick: 1, events: [], stateHash: "s", usedRewind: false,
        nukeCount: 0, rewindCount: 0, undoCount: 0, selectedSkill: 0, scrollX: 0, scrollY: 0)
    checkpoints.save(broken, immediately: true) { _ in }
    try checkpoints.setAside(broken.runID)
    let afterDiscard = try checkpoints.latest(profileID: host)
    let aside = try FileManager.default.contentsOfDirectory(atPath: checkpoints.setAsideDirectory.path)
    try require(afterDiscard == nil && aside.contains { $0.hasPrefix(broken.runID.uuidString) },
        "Discarded run stayed in Resume or lost its bytes")
    let damaged = checkpoints.directory.appendingPathComponent(UUID().uuidString + ".json")
    try Data("damaged".utf8).write(to: damaged)
    var threw = false
    do { _ = try checkpoints.latest(profileID: host) } catch { threw = true }
    try require(threw, "Damaged checkpoint fixture did not fail")
    let moved = try checkpoints.setAsideUnreadable()
    let afterUnreadable = try checkpoints.latest(profileID: host)
    try require(moved == 1 && afterUnreadable == nil,
        "Unreadable run still blocked Resume")

    // Unreadable records offer a way out that keeps the old files.
    try Data("broken records".utf8).write(to: records)
    try? FileManager.default.removeItem(at: records.appendingPathExtension("backup"))
    let stuck = ArcadeStore(file: records, bundledProofs: nil, checkpoints: checkpoints)
    ArcadeStore.shared = stuck
    try require(!stuck.profilesAreWritable && stuck.storageError != nil, "Broken records fixture was readable")
    view.mode = .profiles; view.selectProfile(stuck.records.activeProfile)
    try shot("records-unreadable")
    view.fixRecords()
    guard let fix = GameScreen.shared.controllerPage(in: window) as? GameMenuPage,
          let start = buttons(fix).first(where: { $0.title == "Start new records" }) else {
        throw SequelDataError.invalid("Unreadable records offered no way out")
    }
    start.performClick(nil)
    let kept = try FileManager.default.contentsOfDirectory(atPath: directory.path).filter { $0.hasPrefix("records.json.set-aside-") }
    try require(stuck.profilesAreWritable && stuck.storageError == nil && kept.count == 1
        && ArcadeStore(file: records, bundledProofs: nil, checkpoints: checkpoints).storageError == nil,
        "Start new records did not restore saving or lost the unreadable file")
    _ = closes
    print("PASS player add-to-Hot-Seat, automatic edits, deletion cleanup, active-player deletion, discarded runs and unreadable records way out")
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
Task { @MainActor in
    do {
        try testLevelPlaylistStore()
        try testSharedSession()
        try testProfileJourneys()
        let sample = try testRecords()
        try testSkillAccounting()
        try await testStoreAndView(sample)
        exit(0)
    } catch { print("FAIL: \(error)"); exit(1) }
}
app.run()
