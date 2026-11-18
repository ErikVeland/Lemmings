// Appended to the production entry point to inspect its private wiring.
import ImageIO

private struct StoreAppTestFailure: Error { let message: String }
private func storeCheck(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
    if try !condition() { throw StoreAppTestFailure(message: message) }
}

@MainActor private func storeDescendants(_ root: NSView) -> [NSView] {
    [root] + root.subviews.flatMap(storeDescendants)
}

@MainActor private func storeCapture(_ view: NSView, name: String) throws -> Data {
    view.layoutSubtreeIfNeeded()
    for descendant in storeDescendants(view) { descendant.needsDisplay = true }
    guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
        throw StoreAppTestFailure(message: "Cannot capture " + name)
    }
    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    view.cacheDisplay(in: view.bounds, to: bitmap)
    guard let bytes = bitmap.representation(using: .png, properties: [:]),
          let folder = ProcessInfo.processInfo.environment["LEMMIX_TEST_CAPTURES"] else {
        throw StoreAppTestFailure(message: "Cannot save " + name)
    }
    try bytes.write(to: URL(fileURLWithPath: folder).appendingPathComponent(name + ".png"), options: .atomic)
    return bytes
}

@MainActor private func storeImportCapture(_ window: NSWindow, name: String) throws {
    let view = window.contentView!
    view.layoutSubtreeIfNeeded()
    for descendant in storeDescendants(view) { descendant.needsDisplay = true }
    window.displayIfNeeded()
    guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds),
          let context = NSGraphicsContext(bitmapImageRep: bitmap),
          let folder = ProcessInfo.processInfo.environment["LEMMIX_TEST_CAPTURES"] else {
        throw StoreAppTestFailure(message: "Cannot capture " + name)
    }
    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    NSGraphicsContext.current = context
    view.displayIgnoringOpacity(view.bounds, in: context)
    guard let bytes = bitmap.representation(using: .png, properties: [:]) else {
        throw StoreAppTestFailure(message: "Cannot encode " + name)
    }
    try bytes.write(to: URL(fileURLWithPath: folder).appendingPathComponent(name + ".png"), options: .atomic)
}

@MainActor private func storeCheckWalkingFrame(_ capture: Data, in bounds: CGRect,
    expected: LixArtworkRenderer.Frame, rect: CGRect, name: String) throws {
    guard let bitmap = NSBitmapImageRep(data: capture),
          let cg = expected.image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        throw StoreAppTestFailure(message: name + " cannot inspect the native sprite capture")
    }
    let sprite = NSBitmapImageRep(cgImage: cg)
    let scaleX = CGFloat(bitmap.pixelsWide) / bounds.width
    let scaleY = CGFloat(bitmap.pixelsHigh) / bounds.height
    var samples = 0, matches = 0
    for y in 0..<sprite.pixelsHigh { for x in 0..<sprite.pixelsWide {
        guard let source = sprite.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
              source.alphaComponent > 0.9, source.redComponent > 0.75,
              source.greenComponent < 0.4, source.blueComponent < 0.4 else { continue }
        let px = Int((rect.minX + (CGFloat(x) + 0.5) / CGFloat(sprite.pixelsWide) * rect.width) * scaleX)
        let py = Int((rect.minY + (CGFloat(y) + 0.5) / CGFloat(sprite.pixelsHigh) * rect.height) * scaleY)
        guard (0..<bitmap.pixelsWide).contains(px), (0..<bitmap.pixelsHigh).contains(py) else { continue }
        samples += 1
        // Native captures include the display profile. Compare the shirt hue at its expected pixels.
        if let actual = bitmap.colorAt(x: px, y: py)?.usingColorSpace(.sRGB),
           actual.redComponent > 0.65,
           actual.redComponent > actual.greenComponent + 0.25,
           actual.redComponent > actual.blueComponent + 0.25 { matches += 1 }
    } }
    try storeCheck(samples > 0 && matches * 2 >= samples,
        name + " did not draw the Lix walking pixels at their foot anchor: \(matches)/\(samples), rect \(rect), bounds \(bounds)")
    print("PASS \(name) anchored Lix shirt pixels: \(matches)/\(samples)")
}

extension Lemmings2Canvas {
    func storeCaptureWalking(_ actor: Lemmings2Runtime.Lemming) throws {
        let frame = LixArtworkRenderer.shared.frame(activity: .walker, animationFrame: actor.age, facingLeft: actor.direction < 0)!
        let capture = try storeCapture(self, name: "l2-live-lix-walking")
        let rect = precisionLens.display(CGRect(x: origin.x + (CGFloat(actor.x) - frame.footX - cameraX) * zoom,
            y: origin.y + (CGFloat(actor.y) - frame.footY - cameraY) * zoom * 1.2,
            width: frame.image.size.width * zoom, height: frame.image.size.height * zoom * 1.2))
        try storeCheckWalkingFrame(capture, in: bounds, expected: frame, rect: rect, name: "L2")
    }
}

extension Lemmings3Canvas {
    func storeCaptureWalking(_ actor: Lemmings3Runtime.Lemming) throws {
        let frame = LixArtworkRenderer.shared.frame(activity: .walker, animationFrame: actor.age, facingLeft: actor.direction < 0)!
        let capture = try storeCapture(self, name: "l3-live-lix-walking")
        let rect = precisionLens.display(CGRect(x: origin.x + (CGFloat(actor.x) - frame.footX - cameraX) * zoom,
            y: origin.y + (CGFloat(actor.y) - frame.footY - cameraY) * zoom,
            width: frame.image.size.width * zoom, height: frame.image.size.height * zoom))
        try storeCheckWalkingFrame(capture, in: bounds, expected: frame, rect: rect, name: "L3")
    }
}

extension Lemmings2PlayWindow {
    fileprivate func storeTestWalking() throws {
        timer?.invalidate(); timer = nil
        var choice = ClassicSettings()
        choice.music = .remix(name: "Lix"); choice.musicVolume = 0; choice.soundVolume = 0
        choice.confinePointer = false; choice.lemmingSelectionStyle = .none; choice.hdEffectsEnabled = false
        setAudioSettings(choice, muted: true)
        window?.setContentSize(CGSize(width: 1120, height: 760))
        prepareBriefing(); startLevel(); paused = true; canvas.startCountdown.cancel()
        for _ in 0..<500 {
            game?.step()
            if let game, game.tick > 90, game.lemmings.contains(where: { $0.active && $0.state == .walking }) { break }
        }
        refreshGame()
        guard let actor = game?.lemmings.first(where: { $0.active && $0.state == .walking }) else {
            throw StoreAppTestFailure(message: "The local L2 fixture did not produce a walking character")
        }
        canvas.focusLemming(actor.id)
        try canvas.storeCaptureWalking(actor)
        try storeCheck(dj.currentURL?.path.contains("/Music/Lix/") == true, "L2 did not honour the selected Lix soundtrack")
        print("PASS live L2 Lix walking frame, native foot anchor and selected Lix music (muted)")
        stop()
    }
}

extension Lemmings3PlayWindow {
    fileprivate func storeTestWalking() throws {
        timer?.invalidate(); timer = nil
        var choice = ClassicSettings()
        choice.music = .remix(name: "Lix"); choice.musicVolume = 0; choice.soundVolume = 0
        choice.confinePointer = false; choice.lemmingSelectionStyle = .none; choice.hdEffectsEnabled = false
        setAudioSettings(choice, muted: true)
        window?.setContentSize(CGSize(width: 1120, height: 760))
        paused = true; canvas.startCountdown.cancel(); canvas.menuRows = nil; canvas.confinePointer = false
        for _ in 0..<500 {
            game.step()
            if game.tick > 90, game.lemmings.contains(where: { $0.active && $0.state == .walking }) { break }
        }
        refresh()
        guard let actor = game.lemmings.first(where: { $0.active && $0.state == .walking }) else {
            throw StoreAppTestFailure(message: "The local L3 fixture did not produce a walking character")
        }
        canvas.focusLemming(actor.id)
        try canvas.storeCaptureWalking(actor)
        try storeCheck(dj.currentURL?.path.contains("/Music/Lix/") == true, "L3 did not honour the selected Lix soundtrack")
        print("PASS live L3 Lix walking frame, native foot anchor and selected Lix music (muted)")
        stop()
    }
}

extension AppDelegate {
    fileprivate func testCleanStoreApp() throws {
        let fixture = URL(fileURLWithPath: ProcessInfo.processInfo.environment["LEMMIX_TEST_OWNED_GAMES_DIRECTORY"]!)
        arcadeAutoPresent = false
        ArcadeStore.shared = ArcadeStore(file: fixture.appendingPathComponent("records.json"),
                                         checkpoints: RunRecoveryStore(directory: fixture.appendingPathComponent("checkpoints")))
        playlistStoreCache = (ArcadeStore.shared.records.activeProfileID,
                              try LevelPlaylistStore(file: fixture.appendingPathComponent("playlists.json")))
        try storeCheck(AppDistribution.isStore && AppDistribution.name == "Ultimate Lemmix", "Separate store identity is missing")
        try storeCheck(CharacterArtworkPreference.lixEnabled, "The store edition does not default to Lix characters")
        try storeCheck(!AppDistribution.hasOwnedGames, "The clean-store fixture contains owned data")
        try storeCheck(BundledGameResources.classicDirectories().isEmpty, "The store candidate contains original Classic data")
        try storeCheck((try? BundledGameResources.lemmings2()) == nil, "The store candidate contains original L2 data")
        try storeCheck((try? BundledGameResources.lemmings3()) == nil, "The store candidate contains original L3 data")
        var missingGameMessages: [String] = []
        do { _ = try AppDistribution.lemmings2() } catch { missingGameMessages.append(error.localizedDescription) }
        do { _ = try AppDistribution.lemmings3() } catch { missingGameMessages.append(error.localizedDescription) }
        try storeCheck(missingGameMessages.count == 2 && missingGameMessages.allSatisfy {
            $0.contains("Import Owned Games") && !$0.lowercased().contains("rebuild")
        }, "A missing owned game does not offer the player a usable import action")
        let resources = Bundle.main.resourceURL!
        for name in ["Ports", "MacArtwork", "AmigaArtwork", "NeoLemmix", "OriginalData"] {
            try storeCheck(!FileManager.default.fileExists(atPath: resources.appendingPathComponent(name).path),
                           "The clean app contains " + name)
        }
        try storeCheck(LixArtworkRenderer.shared.isAvailable, "The store candidate cannot load its Lix characters")
        let fakeStarter = fixture.appendingPathComponent("OpenStarter", isDirectory: true)
        try FileManager.default.createDirectory(at: fakeStarter, withIntermediateDirectories: true)
        var rejectedFakeStarter = false
        do { _ = try Self.readClassicArtwork(directory: fakeStarter, styles: [0], specialIndices: []) }
        catch { rejectedFakeStarter = true }
        try storeCheck(rejectedFakeStarter, "An unrelated OpenStarter folder bypassed game-data validation")
        guard let backpack = LixArtworkRenderer.shared.frame(pose: .walking, animationFrame: 0,
            facingLeft: false, backpack: .both) else {
            throw StoreAppTestFailure(message: "Lix characters lost the shared permanent-skill backpack")
        }
        try storeCheck(backpack.footX == 10 && backpack.footY == 13 && backpack.image.size.width == 21,
                       "A Lix skill backpack moved the character's feet")
        preparingLaunch = true
        buildInterface()
        window.setContentSize(CGSize(width: 1120, height: 760))
        restoreSettings()
        settings.display = .flat
        settings.graphics = .dosVGA
        loadContent()
        try storeCheck(dataSets.count == 1 && OpenStarterContent.isStarter(dataSets[0].set), "Fresh installation does not offer only the open starter")
        try storeCheck(assets == nil && playfield.assets == nil, "The open starter loaded protected character assets")
        let titles = homeMenuItems().map(\.title)
        try storeCheck(titles.contains("PLAY STARTER") && titles.contains("IMPORT OWNED GAMES") && titles.contains("GET BYO BUNDLE"),
                       "The clean home screen lost its main routes")
        try storeCheck(playfield.overlaySavedCounts?.hasPrefix("RESCUED ") == true
            && playfield.overlaySavedCounts?.contains("GLOBAL") == false, "The store counter retained unavailable legacy totals")
        if ProcessInfo.processInfo.environment["LEMMIX_TEST_IMPORTER_ONLY"] == "1" {
        showOwnedGameImport()
        guard let importPage = GameScreen.shared.controllerPage(in: window),
              let gameChoice = storeDescendants(importPage).compactMap({ $0 as? NSPopUpButton })
                .first(where: { $0.accessibilityLabel() == "Game to import" }),
              let chooseFolder = storeDescendants(importPage).compactMap({ $0 as? NSButton })
                .first(where: { $0.title == "Choose game folder" }),
              let exportBundle = storeDescendants(importPage).compactMap({ $0 as? NSButton })
                .first(where: { $0.title == "Get BYO bundle" }) else {
            throw StoreAppTestFailure(message: "The player-owned game importer lost its controls")
        }
        importPage.layoutSubtreeIfNeeded()
        try storeCheck(gameChoice.itemTitles == BYOGame.allCases.map(\.displayName),
                       "The importer does not offer all three supported game families")
        guard let back = (importPage as? GameMenuPage)?.controllerBackButton else {
            throw StoreAppTestFailure(message: "The importer has no Back action")
        }
        try storeCheck(back.title == "Back", "The importer changed its Back caption")
        var importTargets: [CGRect] = []
        for control in [gameChoice, chooseFolder, exportBundle, back] as [NSControl] {
            let target = importPage.convert(control.bounds, from: control)
            let point = control.convert(CGPoint(x: control.bounds.midX, y: control.bounds.midY), to: importPage.superview)
            try storeCheck(control.isEnabled && control.acceptsFirstResponder && target.width >= 100 && target.height >= 32
                && importPage.bounds.contains(target) && importPage.hitTest(point) === control,
                "An importer control is clipped or cannot receive input")
            print("Importer control: \((control as? NSButton)?.title ?? gameChoice.titleOfSelectedItem ?? ""), frame \(target)")
            importTargets.append(target)
        }
        for first in importTargets.indices { for second in importTargets.indices where second > first {
            try storeCheck(!importTargets[first].intersects(importTargets[second]), "The importer input targets overlap")
        } }
        for button in [chooseFolder, exportBundle, back] {
            try storeCheck(button.action != nil && button.target != nil && button.target!.responds(to: button.action!),
                           "An importer button has no action")
        }
        try storeImportCapture(window, name: "import-owned-games")
        try storeCheck(gameChoice.accessibilityPerformPress(), "The importer game choices cannot open")
        guard let choicesPage = GameScreen.shared.controllerPage(in: window), choicesPage !== importPage,
              let sequelChoice = storeDescendants(choicesPage).compactMap({ $0 as? NSButton })
                .first(where: { $0.title == BYOGame.allCases.last!.displayName }) else {
            throw StoreAppTestFailure(message: "The importer game choices page is missing")
        }
        choicesPage.layoutSubtreeIfNeeded()
        let choicePoint = sequelChoice.convert(CGPoint(x: sequelChoice.bounds.midX, y: sequelChoice.bounds.midY), to: choicesPage.superview)
        try storeCheck(choicesPage.hitTest(choicePoint) === sequelChoice, "The sequel game choice has no input target")
        try storeImportCapture(window, name: "import-game-choices")
        sequelChoice.performClick(nil)
        try storeCheck(gameChoice.indexOfSelectedItem == BYOGame.allCases.count - 1,
                       "The importer game selector did not change its choice")
        try storeCheck(GameScreen.shared.controllerPage(in: window) === importPage,
                       "The game choice did not return to the importer")
        GameScreen.shared.dismissAll()
        print("PASS native player-owned importer, primary/export/Back targets and actual game selection")
        return
        }

        _ = try storeCapture(window.contentView!, name: "store-home")
        showSettings()
        guard let page = GameScreen.shared.controllerPage(in: window),
              let tabs = storeDescendants(page).compactMap({ $0 as? NSTabView }).first,
              let graphics = tabs.tabViewItems.first(where: { $0.label == "Graphics" }) else {
            throw StoreAppTestFailure(message: "The graphics settings page is missing")
        }
        guard let cursor = storeDescendants(page).compactMap({ $0 as? NSPopUpButton })
            .first(where: { $0.accessibilityLabel() == "Cursor style" }),
              let experience = storeDescendants(page).compactMap({ $0 as? NSPopUpButton })
            .first(where: { $0.accessibilityLabel() == "Gameplay preset" }) else {
            throw StoreAppTestFailure(message: "The gameplay cursor controls are missing")
        }
        try storeCheck(cursor.itemTitles == ["Modern"] && !cursor.isEnabled,
                       "The clean store app offers an unavailable original cursor")
        experience.selectItem(withTitle: "Original")
        _ = NSApp.sendAction(experience.action!, to: experience.target, from: experience)
        try storeCheck(settingsWindow?.current.gameplayCursorStyle == .modern && playfield.gameplayCursorStyle == .modern,
                       "The Original gameplay preset selected a missing cursor")
        _ = try storeCapture(page, name: "settings-store-cursor")
        tabs.selectTabViewItem(graphics)
        page.layoutSubtreeIfNeeded()
        guard let characters = storeDescendants(page).compactMap({ $0 as? NSButton }).first(where: { $0.title == "Lix artwork" }),
              let owner = characters.superview else {
            throw StoreAppTestFailure(message: "The Lix character control is missing")
        }
        try storeCheck(characters.state == .on && !characters.isEnabled, "The starter allows its required characters to be disabled")
        characters.performClick(nil)
        try storeCheck(characters.state == .on && CharacterArtworkPreference.lixEnabled, "The disabled character control changed its choice")
        _ = try storeCapture(page, name: "settings-lix-required")

        settingsWindow?.allowsOriginalCharacters = true
        page.layoutSubtreeIfNeeded()
        try storeCheck(characters.isEnabled && characters.acceptsFirstResponder, "The character choice cannot be used when original characters are allowed")
        let labelPoint = characters.convert(NSPoint(x: min(150, characters.bounds.width - 4), y: characters.bounds.midY),
                                            to: owner.superview)
        try storeCheck(owner.hitTest(labelPoint) === characters, "The checkbox caption is not part of its input target")
        try storeCheck(window.makeFirstResponder(characters), "The enabled character control cannot receive keyboard focus")
        let captionCapture = try storeCapture(characters, name: "lix-character-control")
        let captionPixels = NSBitmapImageRep(data: captionCapture)!
        let captionScale = CGFloat(captionPixels.pixelsWide) / characters.bounds.width
        var captionStart = captionPixels.pixelsWide
        for y in 0..<captionPixels.pixelsHigh {
            for x in Int(24 * captionScale)..<captionPixels.pixelsWide {
                if let colour = captionPixels.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                   colour.greenComponent > 0.8 && colour.redComponent > 0.3 && colour.blueComponent < 0.55 {
                    captionStart = min(captionStart, x)
                }
            }
        }
        try storeCheck(CGFloat(captionStart) / captionScale >= 27 && CGFloat(captionStart) / captionScale <= 32,
                       "The checkbox caption is detached from its box")
        _ = try storeCapture(page, name: "settings-lix-selected")
        characters.performClick(nil)
        try storeCheck(characters.state == .off && !CharacterArtworkPreference.lixEnabled, "The real character checkbox did not select original characters")
        _ = try storeCapture(page, name: "settings-original-selected")
        characters.performClick(nil)
        try storeCheck(characters.state == .on && CharacterArtworkPreference.lixEnabled, "The real character checkbox did not restore Lix")
        settingsWindow?.allowsOriginalCharacters = false
        GameScreen.shared.dismissAll()

        startOpenStarter()
        advancePhase()
        try storeCheck(session != nil && playfield.assets == nil, "The starter cannot create a native session without original assets")
        advancePhase()
        try storeCheck(phase == .playing, "The normal starter flow did not reach gameplay")
        guard let session else { throw StoreAppTestFailure(message: "Starter session disappeared") }
        for _ in 0..<70 { session.tick() }
        try storeCheck(!session.lemmings.isEmpty, "The starter did not release a character")
        playfield.startCountdown.cancel()
        playfield.needsDisplay = true
        let lixCapture = try storeCapture(playfield, name: "starter-gameplay-lix")
        let pixels = NSBitmapImageRep(data: lixCapture)!
        let actor = session.lemmings[0]
        let head = playfield.viewport.viewPoint(fromLevel: CGPoint(x: actor.x - 8, y: actor.y - 13))
        let scaleX = CGFloat(pixels.pixelsWide) / playfield.bounds.width
        let scaleY = CGFloat(pixels.pixelsHigh) / playfield.bounds.height
        let area = CGRect(x: head.x * scaleX, y: head.y * scaleY,
            width: 17 * playfield.viewport.zoom * scaleX, height: 12 * playfield.viewport.zoom * scaleY)
            .intersection(CGRect(x: 0, y: 0, width: pixels.pixelsWide, height: pixels.pixelsHigh)).integral
        var visibleLixPixels = 0
        if !area.isEmpty {
            for y in Int(area.minY)..<Int(area.maxY) { for x in Int(area.minX)..<Int(area.maxX) {
                if let colour = pixels.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                   colour.redComponent > 0.75 && colour.greenComponent < 0.4 && colour.blueComponent < 0.4 {
                    visibleLixPixels += 1
                }
            } }
        }
        try storeCheck(visibleLixPixels > 0, "The actual starter canvas did not render the Lix character")
        let tick = session.currentTick
        let population = session.lemmings.count
        _ = CharacterArtworkPreference.setLixEnabled(false)
        playfield.needsDisplay = true
        let fallbackCapture = try storeCapture(playfield, name: "starter-gameplay-after-original-choice")
        try storeCheck(lixCapture == fallbackCapture, "The starter lost its Lix characters when the global preference selected original")
        try storeCheck(session.currentTick == tick && session.lemmings.count == population, "The character selection changed simulation state")
        _ = CharacterArtworkPreference.setLixEnabled(true)
        try storeCheck(LixArtworkRenderer.l2Mapping(.walking).activity == .walker
            && LixArtworkRenderer.l2Mapping(.jetPacking).isApproximation
            && LixArtworkRenderer.l3Mapping(.swimming).isApproximation,
            "Special sequel-pose limits are not explicit")
        print("PASS clean store startup, native starter gameplay, rendered character choice, hit targets and state preservation")
    }
}

let storeTestApp = NSApplication.shared
guard let storeTestDomain = Bundle.main.bundleIdentifier,
      storeTestDomain == "academy.glasscode.lemmix.integration-tests.store" else { exit(2) }
let previousStoreTestDefaults = UserDefaults.standard.persistentDomain(forName: storeTestDomain)
UserDefaults.standard.removePersistentDomain(forName: storeTestDomain)
UserDefaults.standard.set(true, forKey: "NSApplicationCrashOnExceptions")
storeTestApp.setActivationPolicy(.prohibited)
@MainActor private func finishStoreTests(_ code: Int32) -> Never {
    if let previousStoreTestDefaults {
        UserDefaults.standard.setPersistentDomain(previousStoreTestDefaults, forName: storeTestDomain)
    } else {
        UserDefaults.standard.removePersistentDomain(forName: storeTestDomain)
    }
    UserDefaults.standard.synchronize()
    exit(code)
}
Task { @MainActor in
    do {
        let subject = AppDelegate()
        try subject.testCleanStoreApp()
        if ProcessInfo.processInfo.environment["LEMMIX_TEST_IMPORTER_ONLY"] != "1",
           let ports = ProcessInfo.processInfo.environment["LEMMIX_TEST_PORTS_DIRECTORY"] {
            let directory = URL(fileURLWithPath: ports)
            let l2Root = directory.appendingPathComponent("Lemm2")
            let l3Root = directory.appendingPathComponent("LEM3CD")
            if FileManager.default.fileExists(atPath: l2Root.appendingPathComponent("VLEMMS.DAT").path) {
                let l2 = try Lemmings2PlayWindow(root: l2Root, recordsCampaignProgress: false)
                try l2.storeTestWalking()
            } else { print("SKIP live L2 capture: local player-owned fixture is unavailable") }
            if FileManager.default.fileExists(atPath: l3Root.appendingPathComponent("GRAPHICS").path) {
                let l3 = try Lemmings3PlayWindow(root: l3Root, recordsCampaignProgress: false)
                try l3.storeTestWalking()
            } else { print("SKIP live L3 capture: local player-owned fixture is unavailable") }
        }
        finishStoreTests(0)
    } catch {
        FileHandle.standardError.write(Data("FAIL \(error)\n".utf8))
        finishStoreTests(1)
    }
}
storeTestApp.run()
