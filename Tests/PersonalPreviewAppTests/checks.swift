// Appended to the production entry point for isolated, offscreen preview checks.
import ImageIO

@MainActor private final class PreviewMenuKeyboardWindow: NSWindow {
    override var isKeyWindow: Bool { true }
}

private struct PersonalPreviewFailure: Error { let message: String }
private func previewCheck(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
    if try !condition() { throw PersonalPreviewFailure(message: message) }
}

@MainActor private func previewDescendants(_ view: NSView) -> [NSView] {
    [view] + view.subviews.flatMap(previewDescendants)
}

@MainActor private func previewCapture(_ view: NSView, name: String) throws -> Data {
    view.layoutSubtreeIfNeeded()
    for child in previewDescendants(view) { child.needsDisplay = true }
    guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds),
          let folder = ProcessInfo.processInfo.environment["LEMMIX_TEST_CAPTURES"] else {
        throw PersonalPreviewFailure(message: "Cannot capture " + name)
    }
    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    view.cacheDisplay(in: view.bounds, to: bitmap)
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw PersonalPreviewFailure(message: "Cannot encode " + name)
    }
    try png.write(to: URL(fileURLWithPath: folder).appendingPathComponent(name + ".png"), options: .atomic)
    return png
}

extension AppDelegate {
    fileprivate func testPersonalPreview() async throws {
        let environment = ProcessInfo.processInfo.environment
        let isClean = environment["LEMMIX_PREVIEW_TEST_CLEAN"] == "1"
        let fixture = URL(fileURLWithPath: environment["LEMMIX_TEST_STORAGE_ROOT"]!)
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try previewCheck(support.path.hasPrefix(fixture.path + "/"),
                         "The test process did not isolate its application-support paths")
        arcadeAutoPresent = false
        ArcadeStore.shared = ArcadeStore(file: fixture.appendingPathComponent("records.json"),
            bundledProofs: nil, checkpoints: RunRecoveryStore(directory: fixture.appendingPathComponent("checkpoints")),
            playlistDataRemover: { _ in })
        playlistStoreCache = (ArcadeStore.shared.records.activeProfileID,
                              try LevelPlaylistStore(file: fixture.appendingPathComponent("playlists.json")))
        defer {
            try? recoveryStore.checkSaveSucceeded()
            try? FileManager.default.removeItem(at: recoveryStore.directory)
        }
        try previewCheck(recoveryStore.directory.lastPathComponent.hasPrefix("RunRecovery-"),
                         "The preview checkpoint store is not isolated")
        try previewCheck(AppDistribution.isStore && AppDistribution.isPersonalPreview == !isClean
            && AppDistribution.name == "Ultimate Lemmix", "The personal-preview identity is absent")
        if isClean {
            try previewCheck(GameMenuArtwork.renderer() == nil, "The clean build exposed original menu lettering")
            guard let resources = Bundle.main.resourceURL else {
                throw PersonalPreviewFailure(message: "The clean build has no resources")
            }
            let font = try LixInterfaceText(directory: resources.appendingPathComponent("Fonts/Lix"))
            try previewCheck(font.frame("CLIMB 4", pixelSize: 18, red: 80, green: 160, blue: 255) != nil,
                             "The clean Lix font could not rasterise HUD text")
        } else {
          guard let fonts = GameMenuArtwork.renderer(),
              let small = fonts.font(.small), let large = fonts.font(.large) else {
            throw PersonalPreviewFailure(message: "The original menu lettering is unavailable")
        }
        try previewCheck(small.cellWidth == 12 && small.cellHeight == 18
            && large.cellWidth == 16 && large.cellHeight == 20, "The original font metrics changed")
        try previewCheck(fonts.interface.logo == nil && fonts.interface.publisher == nil
            && fonts.interface.icons.isEmpty, "The font-only resource contains unrelated interface pictures")
        }
        try previewCheck(LixArtworkRenderer.shared.isAvailable && CharacterArtworkPreference.lixEnabled,
                         "The preview lost its Lix character default")
        preparingLaunch = true
        buildInterface()
        window.setContentSize(CGSize(width: 1120, height: 760))
        restoreSettings()
        settings.display = .flat
        settings.graphics = .dosVGA
        settings.reduceMotion = true
        settings.music = .silent
        settings.sound = .silent
        FanLevelLibrary.Progress.seedBundledCounts()
        loadContent()
        window.contentView?.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        try previewCheck(dataSets.count == 1 && OpenStarterContent.isStarter(dataSets[0].set),
                         "The personal preview exposed an official campaign")
        let expectedCount = Bundle.main.object(forInfoDictionaryKey: "UltimateLemmixCommunityLevelCount") as? Int ?? 0
        let packs = FanLevelLibrary.packs()
        try previewCheck(isClean || expectedCount > 0 && !packs.isEmpty, "The prepared community corpus is unavailable")
        let items = homeMenuItems()
        let community = items.firstIndex(where: {
            if case .browse(.fan) = $0.action { return true }; return false
        })
        let scope = environment["LEMMIX_PREVIEW_TEST_SCOPE"] ?? "home"
        if ["menus", "starter-browser", "home"].contains(scope) {
            try previewCheck(LearningJourneyLibrary.journey?.lessons.isEmpty == false,
                             "The resource bundle has no valid learning journey")
            try previewCheck(!RunRecovery.bundledEngine.isEmpty,
                             "The resource bundle has no recovery engine fingerprint")
        }
        switch scope {
        case "starter-browser":
            openLevelBrowser(family: .classic)
            for _ in 0..<1_500 {
                if levelBrowserLoadTask == nil, GameScreen.shared.controllerPage(in: window) != nil { break }
                try await Task.sleep(nanoseconds: 10_000_000)
            }
            guard let starter = levelCatalogue.packs.first(where: { $0.id == dataSets[0].set.identifierKey }),
                  let page = GameScreen.shared.controllerPage(in: window),
                  let start = previewDescendants(page).compactMap({ $0 as? NSButton }).first(where: { $0.title == "Start" }) else {
                throw PersonalPreviewFailure(message: "The restored Classic family did not open the starter level browser")
            }
            try previewCheck(starter.levels.count == 3 && starter.status == .complete
                && levelBrowserPackFamilies[browserPackKey(starter)] == .classic,
                "The generated starter lost its Classic family or verified three-level catalogue")
            for level in starter.levels {
                guard let request = levelPreviewRequests[level.identity] else {
                    throw PersonalPreviewFailure(message: "A starter browser level has no thumbnail request")
                }
                let bitmap = try await LevelPreviewStore.shared.bitmap(for: request)
                try previewCheck(bitmap.width == 320 && bitmap.height == 160,
                                 "A starter thumbnail has invalid browser dimensions")
            }
            page.layoutSubtreeIfNeeded()
            let target = start.convert(CGPoint(x: start.bounds.midX, y: start.bounds.midY), to: page.superview)
            try previewCheck(start.isEnabled && page.hitTest(target) === start,
                             "The starter browser Start target cannot receive input")
            _ = try previewCapture(window.contentView!, name: "personal-restored-starter-browser-window")
            start.performClick(nil)
            for _ in 0..<1_500 {
                if levelBrowserLaunchTask == nil && phase == .briefing { break }
                try await Task.sleep(nanoseconds: 10_000_000)
            }
            try previewCheck(phase == .briefing && !GameScreen.shared.isPresented && playfield.assets == nil,
                             "The native starter Start action failed to reach its asset-free briefing")
            advancePhase()
            playfield.startCountdown.cancel()
            try previewCheck(phase == .playing && playfield.imageScale == 2 && playfield.lixSceneTheme == .brick,
                             "The browser-selected starter did not use the actual Lix scene")
            _ = try previewCapture(window.contentView!, name: "personal-restored-starter-start-window")
            guard let live = session as? ClassicSession else {
                throw PersonalPreviewFailure(message: "The browser-selected starter has no Classic session")
            }
            for _ in 0..<7 { live.tick() }
            let savedTick = live.currentTick
            let savedState = ClassicDOSReplayRecorder.stateHash(of: live.simulation)
            saveRunCheckpoint(immediately: true)
            guard let checkpoint = try recoveryStore.latest(profileID: arcadeProfileID) else {
                throw PersonalPreviewFailure(message: "The starter checkpoint was not saved")
            }
            _ = try checkpoint.validated()
            live.tick()
            restoreRun(checkpoint)
            try previewCheck(phase == .playing && isPaused && session?.currentTick == savedTick
                && (session as? ClassicSession).map { ClassicDOSReplayRecorder.stateHash(of: $0.simulation) } == savedState,
                "The generated starter did not restore its exact saved tick/state paused")
            print("PASS restored Classic family: verified three-level catalogue, Lix thumbnails, native Start, briefing/gameplay and exact saved checkpoint recovery")
        case "menus":
            let previousMenu = NSApp.mainMenu
            let previousHelp = NSApp.helpMenu
            defer { NSApp.mainMenu = previousMenu; NSApp.helpMenu = previousHelp; GameScreen.shared.dismissAll() }
            buildMenu()
            guard let menu = NSApp.mainMenu else {
                throw PersonalPreviewFailure(message: "The native application menu is absent")
            }
            func allItems(_ menu: NSMenu) -> [NSMenuItem] {
                menu.items.flatMap { item in [item] + (item.submenu.map(allItems) ?? []) }
            }
            let nativeItems = allItems(menu)
            for title in ["Settings…", "Player Profiles…", "Hot Seat…", "Level Records…", "Play Insights…",
                          "Replay Last Game", "Game Library", "Add Game…", "Level Select…", "Fan Levels…",
                          "Add Fan Level Folder…", "Add NeoLemmix Packs…", "Open Level File…"] {
                guard let item = nativeItems.first(where: { $0.title == title }), let action = item.action else {
                    throw PersonalPreviewFailure(message: "The native menu lost " + title)
                }
                try previewCheck(item.target === self && responds(to: action),
                                 "The native menu action is disconnected: " + title)
            }
            try previewCheck(["File", "View", "Audio", "Help"].allSatisfy { title in
                menu.items.contains { $0.submenu?.title == title }
            }, "The native menu hierarchy is incomplete")
            let families = homeMenuItems().compactMap { item -> HomeContentFamily? in
                if case let .browse(family) = item.action { return family }; return nil
            }
            try previewCheck(families == HomeContentFamily.allCases,
                             "The clean-content home lost an existing game family")
            try previewCheck(homeContentRow(.classic).contains("/3"),
                             "The Classic home family does not count the three generated starter levels")
            try previewCheck(isClean || homeContentRow(.fan).contains(String(expectedCount)),
                             "The fan home family does not count the selected community corpus")
            _ = try previewCapture(window.contentView!, name: "personal-restored-home-window")
            func event(_ key: String, code: UInt16, modifiers: NSEvent.ModifierFlags,
                       in host: NSWindow) -> NSEvent {
                NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers,
                    timestamp: 1, windowNumber: host.windowNumber, context: nil,
                    characters: modifiers.contains(.shift) ? key.uppercased() : key,
                    charactersIgnoringModifiers: key, isARepeat: false, keyCode: code)!
            }
            let settingsKey = event(",", code: 43, modifiers: [.command], in: window)
            try previewCheck(handleClassicKeyboardEvent(settingsKey) === settingsKey,
                             "Classic gameplay swallowed the Settings shortcut")
            let host = PreviewMenuKeyboardWindow(contentRect: CGRect(x: 0, y: 0, width: 400, height: 300),
                                                 styleMask: [], backing: .buffered, defer: false)
            host.isReleasedWhenClosed = false
            defer { host.close() }
            let sharedKeyboard = GameplayKeyboard(window: host)
            sharedKeyboard.active = { true }
            let shortcuts: [(String, UInt16, NSEvent.ModifierFlags)] = [
                ("p", 35, [.command, .shift]), ("b", 11, [.command, .shift]), (",", 43, [.command])]
            for (key, code, modifiers) in shortcuts {
                let modified = event(key, code: code, modifiers: modifiers, in: host)
                try previewCheck(sharedKeyboard.handle(modified) === modified,
                                 "Shared sequel gameplay routing swallowed a native menu shortcut")
            }
            try previewCheck(menu.performKeyEquivalent(with: settingsKey), "Command-comma did not reach the native Settings item")
            guard let settingsPage = GameScreen.shared.controllerPage(in: window) else {
                throw PersonalPreviewFailure(message: "Command-comma did not open Settings")
            }
            try previewCheck(previewDescendants(settingsPage).contains { $0 is NSTabView },
                             "The keyboard Settings route opened the wrong page")
            guard let cursor = previewDescendants(settingsPage).compactMap({ $0 as? NSPopUpButton })
                .first(where: { $0.accessibilityLabel() == "Cursor style" }) else {
                throw PersonalPreviewFailure(message: "Settings has no cursor style control")
            }
            try previewCheck(cursor.isEnabled && cursor.itemTitles == GameplayCursorStyle.allCases.map(\.title),
                             "The clean build hid the Original cursor mode")
            cursor.selectItem(withTitle: "Original")
            try previewCheck(cursor.sendAction(cursor.action!, to: cursor.target)
                && settings.gameplayCursorStyle == .original && settingsWindow?.current.gameplayCursorStyle == .original,
                "Selecting Original cursor mode was forced back to Modern")
            var originalSettings = settings
            originalSettings.gameplayCursorStyle = .original
            let originalOptions = settingsOptions()
            let preservedSettings = SettingsWindow(settings: originalSettings, options: originalOptions)
            preservedSettings.update(options: originalOptions, settings: originalSettings)
            try previewCheck(preservedSettings.current.gameplayCursorStyle == .original,
                             "Settings init/update discarded the Original cursor choice")
            _ = try previewCapture(window.contentView!, name: "personal-native-menu-settings-window")
            GameScreen.shared.dismissAll()
            for (key, code, expected) in [("p", UInt16(35), ArcadeView.Mode.profiles), ("b", UInt16(11), .records)] {
                try previewCheck(menu.performKeyEquivalent(with: event(key, code: code, modifiers: [.command, .shift], in: window)),
                                 "A native player/history shortcut was not handled")
                try previewCheck(GameScreen.shared.contains(ArcadeWindow.shared.arcadeView)
                    && ArcadeWindow.shared.arcadeView.mode == expected, "A native player/history shortcut opened the wrong page")
                _ = try previewCapture(window.contentView!, name: "personal-native-menu-" + key + "-window")
                GameScreen.shared.dismissAll()
            }
            for (title, expected) in [("Hot Seat…", ArcadeView.Mode.hotSeat)] {
                let item = nativeItems.first { $0.title == title }!
                try previewCheck(NSApp.sendAction(item.action!, to: item.target, from: item), "The native Hot Seat action was not delivered")
                try previewCheck(GameScreen.shared.contains(ArcadeWindow.shared.arcadeView)
                    && ArcadeWindow.shared.arcadeView.mode == expected, "The native Hot Seat action opened the wrong page")
                _ = try previewCapture(window.contentView!, name: "personal-native-menu-hot-seat-window")
                GameScreen.shared.dismissAll()
            }
            let insights = nativeItems.first { $0.title == "Play Insights…" }!
            try previewCheck(NSApp.sendAction(insights.action!, to: insights.target, from: insights),
                             "The native insights action was not delivered")
            try previewCheck(GameScreen.shared.controllerPage(in: window)?.accessibilityLabel() == "Play insights",
                             "The native insights action opened the wrong page")
            _ = try previewCapture(window.contentView!, name: "personal-native-menu-insights-window")
            print("PASS native full menu hierarchy; real Cmd-comma, Cmd-Shift-P/B, Hot Seat and insights routes; restored home families; Classic/shared sequel shortcut pass-through")
        case "hud", "hud-paused", "hud-undo", "hud-small":
            try previewCheck(LixInterfaceRenderer.shared.isAvailable && LixInterfaceRenderer.shared.isEnabled,
                             "The pinned Lix interface artwork is unavailable")
            startOpenStarter()
            advancePhase()
            flow?.selectLevel(rank: 0, position: 2, recordsCampaignProgress: false)
            renderScreen()
            advancePhase()
            guard let session = session as? ClassicSession, let content = window.contentView else {
                throw PersonalPreviewFailure(message: "The full-window HUD session is unavailable")
            }
            for _ in 0..<70 { session.tick() }
            playfield.startCountdown.cancel()
            isPaused = false
            panel.isPaused = false
            if scope == "hud-small" {
                window.setContentSize(CGSize(width: 860, height: 640))
                fitClassicDisplay()
                applyDisplayMode()
            }
            updateStatus()
            refreshProgressText()
            content.layoutSubtreeIfNeeded()
            let controls = panel.accessibilityChildren()?.compactMap { $0 as? GameAccessibleElement } ?? []
            try previewCheck(controls.count >= 17, "The full Classic HUD lost input controls")
            for control in controls {
                try previewCheck(control.localFrame.width > 0 && control.localFrame.height > 0
                    && panel.bounds.contains(control.localFrame), "A native HUD input target is clipped")
            }
            func target(_ label: String) throws -> GameAccessibleElement {
                guard let found = controls.first(where: { $0.accessibilityLabel() == label }) else {
                    throw PersonalPreviewFailure(message: "The HUD has no " + label + " target")
                }
                return found
            }
            func click(_ target: GameAccessibleElement, at time: TimeInterval = ProcessInfo.processInfo.systemUptime) {
                panel.handleClick(at: CGPoint(x: target.localFrame.midX, y: target.localFrame.midY), time: time)
            }
            let tick = session.currentTick
            let rate = session.rate
            click(try target("Increase release rate"))
            try previewCheck(session.rate == rate + 1, "The native rate-up target did not change the release rate")
            click(try target("Decrease release rate"))
            try previewCheck(session.rate == rate, "The native rate-down target did not restore the release rate")
            if scope == "hud-paused" {
                click(try target("Pause"))
                try previewCheck(isPaused && panel.isPaused, "The native pause target did not change its state")
            } else if scope == "hud-undo" {
                let nuke = try target("End run")
                click(nuke, at: 10)
                click(nuke, at: 10.1)
                try previewCheck(session.canUndoNuke, "The native end-run gesture did not expose Undo")
            }
            try previewCheck(session.currentTick == tick, "A HUD selection advanced the simulation")
            panel.needsDisplay = true
            playfield.needsDisplay = true
            let prefix = isClean ? "clean-" : "personal-"
            _ = try previewCapture(content, name: prefix + scope + "-window")
            _ = try previewCapture(panel, name: prefix + scope + "-panel")
            print("PASS full-window \(scope), \(isClean ? "licensed Lix" : "original bitmap") HUD lettering, actual Lix sockets/icons and \(controls.count) native input targets")
        case "home":
            guard let community else { throw PersonalPreviewFailure(message: "The fan home item is absent") }
            _ = try previewCapture(playfield, name: "personal-home")
            let targets = playfield.accessibilityChildren()?.compactMap { $0 as? GameAccessibleElement } ?? []
            guard let target = targets.first(where: { $0.accessibilityLabel() == items[community].title }) else {
                throw PersonalPreviewFailure(message: "The community row has no native accessibility target")
            }
            try previewCheck(target.localFrame.width > 200 && target.localFrame.height >= 32
                && playfield.bounds.contains(target.localFrame), "The community home target is clipped")
            try previewCheck(isClean ? items[community].title.contains("NO PACKS")
                : items[community].title.contains(String(expectedCount)),
                "The restored fan row lost its content availability/count")
            print("PASS original-font home and restored fan-family \(expectedCount) native target; \(packs.count) packs")
        case "settings":
            showSettings()
            guard let page = GameScreen.shared.controllerPage(in: window),
                  let tabs = previewDescendants(page).compactMap({ $0 as? NSTabView }).first,
                  let graphics = tabs.tabViewItems.first(where: { $0.label == "Artwork" }) else {
                throw PersonalPreviewFailure(message: "The settings page is unavailable")
            }
            tabs.selectTabViewItem(graphics)
            page.layoutSubtreeIfNeeded()
            guard let characters = previewDescendants(page).compactMap({ $0 as? NSButton })
                .first(where: { $0.title == "Lix artwork" }) else {
                throw PersonalPreviewFailure(message: "The Lix artwork setting is absent")
            }
            try previewCheck(characters.state == .on && !characters.isEnabled,
                             "The starter allows its required Lix characters to disappear")
            _ = try previewCapture(page, name: "personal-settings")
            print("PASS original-font settings and required Lix character state")
        case "browser":
            guard let community else { throw PersonalPreviewFailure(message: "The community browser item is absent") }
            let targets = playfield.accessibilityChildren()?.compactMap { $0 as? GameAccessibleElement } ?? []
            guard let target = targets.first(where: { $0.accessibilityLabel() == items[community].title }) else {
                throw PersonalPreviewFailure(message: "The community home row has no click target")
            }
            try previewCheck(target.accessibilityPerformPress(), "The community home action rejected input")
            for _ in 0..<1_500 {
                if GameScreen.shared.controllerPage(in: window) != nil { break }
                try await Task.sleep(nanoseconds: 10_000_000)
            }
            guard let page = GameScreen.shared.controllerPage(in: window),
                  let browse = previewDescendants(page).compactMap({ $0 as? NSButton })
                    .first(where: { $0.title == "Browse levels" }) else {
                throw PersonalPreviewFailure(message: "The community action did not open its pack browser")
            }
            page.layoutSubtreeIfNeeded()
            let targetPoint = browse.convert(CGPoint(x: browse.bounds.midX, y: browse.bounds.midY),
                                             to: page.superview)
            try previewCheck(browse.isEnabled && browse.bounds.width >= 100 && browse.bounds.height >= 32
                && page.hitTest(targetPoint) === browse, "The community browse action cannot receive input")
            try previewCheck(levelBrowserFanPacks.count == packs.count,
                             "The pack browser does not contain the full selected pack list")
            _ = try previewCapture(page, name: "personal-community-browser")
            print("PASS native community home action, \(packs.count)-pack browser, original lettering and Browse target")
        case "starter", "starter2", "starter3":
            let index = scope == "starter2" ? 1 : scope == "starter3" ? 2 : 0
            startOpenStarter()
            advancePhase()
            if index > 0 {
                flow?.selectLevel(rank: 0, position: index, recordsCampaignProgress: false)
                renderScreen()
            }
            advancePhase()
            try previewCheck(phase == .playing && playfield.assets == nil, "The starter loaded original actor assets")
            guard let session = session as? ClassicSession, let scene = playfield.classicScene else {
                throw PersonalPreviewFailure(message: "The starter session is absent")
            }
            for _ in 0..<70 { session.tick() }
            playfield.startCountdown.cancel()
            let state = ClassicDOSReplayRecorder.stateHash(of: session.simulation)
            let themes: [LixSceneArtwork.Theme] = [.brick, .earth, .wood]
            let name = index == 0 ? "personal-starter-lix" : "personal-starter-lix-\(index + 1)"
            let png = try previewCapture(playfield, name: name)
            try previewCheck(playfield.lixSceneTheme == themes[index] && playfield.imageScale == 2
                && playfield.levelImage?.width == scene.width * 2 && playfield.levelImage?.height == scene.height * 2,
                "The native starter lost its complete Lix scene or source detail")
            let pixels = NSBitmapImageRep(data: png)!
            var red = 0
            for y in 0..<pixels.pixelsHigh { for x in 0..<pixels.pixelsWide {
                if let colour = pixels.colorAt(x: x, y: y)?.usingColorSpace(.sRGB),
                   colour.redComponent > 0.65 && colour.redComponent > colour.greenComponent + 0.25
                    && colour.redComponent > colour.blueComponent + 0.25 { red += 1 }
            } }
            try previewCheck(!session.lemmings.isEmpty && red > 0, "The native starter canvas did not render Lix")
            try previewCheck(ClassicDOSReplayRecorder.stateHash(of: session.simulation) == state,
                             "The native scene renderer changed gameplay state")
            var benchmark = session.simulation
            let began = ProcessInfo.processInfo.systemUptime
            for _ in 0..<5 {
                _ = benchmark.tick()
                _ = LixArtworkRenderer.shared.sceneFrame(scene, simulation: benchmark, theme: themes[index])
            }
            let milliseconds = (ProcessInfo.processInfo.systemUptime - began) * 200
            print("PASS native starter \(index + 1), complete \(themes[index].rawValue) Lix scene at 2×, actor and unchanged physics; mean scene \(String(format: "%.2f", milliseconds)) ms")
        case "fan":
            guard let resources = Bundle.main.resourceURL,
                  let pack = packs.first(where: { $0.lastPathComponent.lowercased().contains("geoo") }) ?? packs.first,
                  let entry = FanLevelLibrary.entries(in: pack).first,
                  let fingerprint = FanLevelLibrary.archiveFingerprint(pack) else {
                throw PersonalPreviewFailure(message: "No representative community entry is available")
            }
            let result = Self.prepareFanBrowserLevel(pack: pack, entry: entry,
                packName: FanLevelLibrary.displayName(of: pack), expectedFingerprint: fingerprint,
                portsRoot: resources.appendingPathComponent("Ports"), ownedClassicRoots: [])
            guard case let .ready(prepared) = result else {
                if case let .failed(message) = result { throw PersonalPreviewFailure(message: message) }
                throw PersonalPreviewFailure(message: "The community entry could not prepare")
            }
            fanPack = pack
            fanEntries = [entry]
            startFanRun([entry], prepared: prepared)
            try previewCheck(fanPlaying && session != nil, "The prepared community level did not start")
            advancePhase()
            for _ in 0..<70 { session?.tick() }
            playfield.startCountdown.cancel()
            _ = try previewCapture(playfield, name: "personal-community-gameplay")
            try previewCheck(phase == .playing && (session?.currentTick ?? 0) > 0,
                             "The native community session did not advance")
            guard let session = session as? ClassicSession, let scene = playfield.classicScene else {
                throw PersonalPreviewFailure(message: "The community simulation is absent")
            }
            let state = ClassicDOSReplayRecorder.stateHash(of: session.simulation)
            try previewCheck(playfield.imageScale == 2 && playfield.levelImage?.width == scene.width * 2,
                             "The community scene did not select full Lix artwork")
            _ = CharacterArtworkPreference.setLixEnabled(false)
            _ = try previewCapture(playfield, name: "personal-community-original")
            try previewCheck(playfield.imageScale == 1 && playfield.levelImage?.width == scene.width,
                             "The original community scene did not return at the same tick")
            _ = CharacterArtworkPreference.setLixEnabled(true)
            _ = try previewCapture(playfield, name: "personal-community-lix-restored")
            try previewCheck(playfield.imageScale == 2 && playfield.levelImage?.width == scene.width * 2,
                             "The full Lix scene did not return at the same tick")
            try previewCheck(ClassicDOSReplayRecorder.stateHash(of: session.simulation) == state,
                             "Changing native scene artwork changed gameplay state")
            print("PASS production preparation/render/start for \(pack.lastPathComponent): \(entry.label)")
        default:
            throw PersonalPreviewFailure(message: "Unknown personal-preview test scope")
        }
    }
}

let personalTestApp = NSApplication.shared
guard let personalTestDomain = Bundle.main.bundleIdentifier,
      personalTestDomain == "academy.glasscode.lemmix.integration-tests.personal-preview" else { exit(2) }
let previousPersonalDefaults = UserDefaults.standard.persistentDomain(forName: personalTestDomain)
UserDefaults.standard.removePersistentDomain(forName: personalTestDomain)
UserDefaults.standard.set(true, forKey: "NSApplicationCrashOnExceptions")
personalTestApp.setActivationPolicy(.prohibited)
@MainActor private func finishPersonalTests(_ code: Int32) -> Never {
    if let previousPersonalDefaults {
        UserDefaults.standard.setPersistentDomain(previousPersonalDefaults, forName: personalTestDomain)
    } else { UserDefaults.standard.removePersistentDomain(forName: personalTestDomain) }
    UserDefaults.standard.synchronize()
    exit(code)
}
Task { @MainActor in
    do {
        let subject = AppDelegate()
        try await subject.testPersonalPreview()
        finishPersonalTests(0)
    } catch {
        FileHandle.standardError.write(Data("FAIL \(error)\n".utf8))
        finishPersonalTests(1)
    }
}
personalTestApp.run()
