import Foundation

private func checkUI(_ value: Bool, _ message: String) throws {
    if !value { throw NSError(domain: "MusicUI", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
}
@MainActor private func shot(_ view: NSView, _ name: String) throws {
    view.layoutSubtreeIfNeeded()
    guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw CocoaError(.fileWriteUnknown) }
    func invalidate(_ item: NSView) { item.needsDisplay = true; item.subviews.forEach(invalidate) }
    invalidate(view)
    view.displayIgnoringOpacity(view.bounds, in: NSGraphicsContext(bitmapImageRep: bitmap)!)
    try bitmap.representation(using: .png, properties: [:])!.write(to: shots.appendingPathComponent(name + ".png"))
}
@MainActor private func checkTarget(_ control: NSView, in root: NSView) throws {
    let rect = control.convert(control.bounds, to: root)
    try checkUI(root.bounds.contains(rect), "Control clipped outside its page: \(control)")
    let hit = root.hitTest(NSPoint(x: rect.midX, y: rect.midY))
    try checkUI(hit === control || hit?.isDescendant(of: control) == true, "Control has no input target: \(control)")
}

@MainActor private func checkDistractionFeedback() throws {
    let keyboard = GameplayKeyboard(window: window)
    keyboard.active = { true }; keyboard.ownsController = { true }
    keyboard.navigationAvailable = { true }; keyboard.mainMenu = {}
    keyboard.navigationReduceMotion = { false }
    var preferences = ClassicSettings()
    keyboard.showSongInfo = { preferences.showSongInfo }
    keyboard.fadeMenuButton = { preferences.fadeMenuButton }
    var track: PlayingTrack? = .init(url: URL(fileURLWithPath: "/test/song.mod"),
        title: "Lend a Helping Hand", soundtrack: "Lemmings - Amiga")
    keyboard.playingTrack = { track }
    defer { keyboard.removeNavigationControl() }
    for width in [1120, 900] {
        window.setContentSize(NSSize(width: width, height: 620))
        keyboard.removeNavigationControl()
        track = nil; keyboard.refreshNavigationControl(at: 90)
        track = .init(url: URL(fileURLWithPath: "/test/song.mod"), title: "Lend a Helping Hand", soundtrack: "Lemmings - Amiga")
        keyboard.refreshNavigationControl(at: 100)
        let root = window.contentView!
        let notice = root.subviews.compactMap { $0 as? NowPlayingNotice }.first!
        let menu = root.subviews.compactMap { $0 as? GameplayMenuButton }.first!
        try checkUI(notice.artworkOpacity == 0 && notice.hitTest(.zero) == nil, "Song notice appeared abruptly or captured input")
        keyboard.refreshNavigationControl(at: 100.175)
        try checkUI(abs(notice.artworkOpacity - 0.5) < 0.01, "Song notice missed its smooth fade-in")
        try shot(root, "song-fade-in-\(width)")
        keyboard.refreshNavigationControl(at: 100.35)
        try checkUI(abs(notice.artworkOpacity - 1) < 0.01 && root.bounds.contains(notice.frame), "Song notice was clipped or never became visible")
        try shot(root, "song-visible-\(width)")
        keyboard.refreshNavigationControl(at: 104.25)
        try checkUI(abs(notice.artworkOpacity - 0.5) < 0.01, "Song notice missed its fade-out")
        preferences.showSongInfo = false; preferences.fadeMenuButton = false
        keyboard.refreshNavigationControl(at: 104.3)
        try checkUI(notice.isHidden && notice.track == nil && !notice.isAccessibilityElement(), "Disabled song info retained a stale notice")
        try checkUI(menu.artworkOpacity == 1 && !menu.isHidden, "Disabling Menu fading did not restore it")
        try checkTarget(menu, in: root)
        try shot(root, "song-off-menu-steady-\(width)")
        keyboard.navigationReduceMotion = { true }
        preferences.showSongInfo = true
        keyboard.refreshNavigationControl(at: 110)
        try checkUI(notice.artworkOpacity == 1 && !notice.isHidden && menu.artworkOpacity == 1, "Reduced motion changed steady notice/Menu states")
        keyboard.refreshNavigationControl(at: 115)
        try checkUI(notice.isHidden, "Reduced motion prevented notice expiry")
        keyboard.navigationReduceMotion = { false }
        preferences.fadeMenuButton = true
    }
    print("PASS shared song/Menu controls: fade-in/out, disabled/steady states, reduced motion, compact renders and pointer targets")
}

@MainActor private func checkRescueCanvas(_ view: NSView, name: String,
    set: (CGFloat, Bool) -> Void, effects: () -> [LemmingSelectionEffect]) throws {
    func capture(_ state: String, amount: CGFloat, reduced: Bool = false) throws -> CGImage {
        set(amount, reduced)
        let image = ReplayFrameCapture.image(size: view.bounds.size) { view.draw(view.bounds) }!
        try NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!.write(
            to: shots.appendingPathComponent("rescue-\(name)-\(state).png"))
        return image
    }
    let inactive = try capture("inactive", amount: 0)
    try checkUI(effects().isEmpty, "\(name) had a rescue aura before meeting the target")
    let earned = try capture("earned", amount: 1)
    try checkUI(effects().isEmpty, "\(name) created crowd glow for a secured rescue target")
    let a = inactive.dataProvider!.data! as Data, b = earned.dataProvider!.data! as Data
    let changed = stride(from: 0, to: a.count, by: 4).filter { a[$0..<$0 + 4] != b[$0..<$0 + 4] }.count
    try checkUI(changed > 0 && Double(changed) / Double(a.count / 4) < 0.01,
        "\(name) rescue cue changed more than a thin playfield border")
    func drawCost(amount: CGFloat) -> Double {
        set(amount, false)
        let start = ProcessInfo.processInfo.systemUptime
        for _ in 0..<32 {
            _ = ReplayFrameCapture.image(size: view.bounds.size) { view.draw(view.bounds) }
        }
        return (ProcessInfo.processInfo.systemUptime - start) / 32
    }
    let baseline = drawCost(amount: 0), secured = drawCost(amount: 1)
    try checkUI(secured < baseline * 1.3 + 0.001,
        "\(name) rescue cue added sustained bitmap draw cost")
    print(String(format: "MEASURE %@ bitmap capture: inactive %.3f ms, secured %.3f ms", name, baseline * 1_000, secured * 1_000))
    _ = try capture("reduced", amount: 1, reduced: true)
    try checkUI(effects().isEmpty, "\(name) kept bright sprite auras with reduced flashes")
    _ = try capture("reset", amount: 0)
    try checkUI(effects().isEmpty, "\(name) retained an aura after the glow expired")
    print("PASS \(name) faint rescue border, no crowd glow, reduced flashes and reset renders")
}

@MainActor private func checkClassicRescueAura() throws {
    let width = 320, height = 96
    let terrain = try ClassicDOSTerrain(width: width, height: height,
        solidMask: Data((0..<(width * height)).map { UInt8($0 / width >= 80 ? 1 : 0) }),
        steelMask: Data(repeating: 0, count: width * height))
    let config = ClassicDOSConfiguration(totalLemmings: 10, requiredToSave: 5, timeLimitTicks: nil,
        initialReleaseRate: 99, entrances: [.init(x: 80, y: 50)], initialSkills: [:], maximumX: width - 1, maximumY: height - 1)
    let session = ClassicSession(simulation: try ClassicDOSSimulation(terrain: terrain, configuration: config), width: width, height: height)
    for _ in 0..<120 { session.tick() }
    try checkUI(!session.lemmings.isEmpty, "Classic rescue fixture has no released lemmings")
    let view = PlayfieldView(frame: CGRect(x: 0, y: 0, width: 900, height: 400))
    view.phase = .playing; view.session = session; view.assets = try ClassicMainDATAssets.load(from: Bundle.main.resourceURL!.appendingPathComponent("Ports/lemmings_dos_1991-07-30"))
    view.palette = ClassicLemmingPalette.panelVGA
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.setFillColor(CGColor(gray: 0.03, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    view.levelImage = context.makeImage(); view.viewport.zoom = 3
    try checkRescueCanvas(view, name: "classic", set: { view.completionGlowAmount = $0; view.reduceFlashes = $1 }, effects: { view.rescueAuras })
}

extension Lemmings2PlayWindow {
    @MainActor fileprivate func checkRescueAura() throws {
        defer { stop() }
        prepareBriefing(); startLevel(); timer?.invalidate(); timer = nil
        paused = true; canvas.startCountdown.cancel()
        for _ in 0..<120 { game?.step() }
        for _ in 0..<600 where game?.lemmings.contains(where: { $0.active }) != true { game?.step() }
        refreshGame()
        if let id = game?.lemmings.first(where: { $0.active })?.id { canvas.focusLemming(id) }
        try checkRescueCanvas(canvas, name: "lemmings2", set: { self.canvas.completionGlowAmount = $0; self.canvas.reduceFlashes = $1 }, effects: { self.canvas.rescueAuras })
    }
}

extension Lemmings3PlayWindow {
    @MainActor fileprivate func checkRescueAura() throws {
        defer { stop() }
        timer?.invalidate(); timer = nil; paused = true; canvas.startCountdown.cancel(); canvas.menuRows = nil
        for _ in 0..<120 { game.step() }
        for _ in 0..<600 where !game.lemmings.contains(where: { $0.active }) { game.step() }
        refresh()
        if let id = game.lemmings.first(where: { $0.active })?.id { canvas.focusLemming(id) }
        try checkRescueCanvas(canvas, name: "lemmings3", set: { self.canvas.completionGlowAmount = $0; self.canvas.reduceFlashes = $1 }, effects: { self.canvas.rescueAuras })
    }
}

extension SettingsWindow {
    @MainActor fileprivate func checkDistractionOptions() throws {
        show()
        let tabs = page!.body.subviews.first { $0 is GameTabs } as! GameTabs
        tabs.subviews.compactMap { $0 as? GameTabButton }.first { $0.title == "Accessibility" }!.performClick(nil)
        var lastSettings = settings
        onChange = { lastSettings = $0 }
        for size in [NSSize(width: 1120, height: 720), NSSize(width: 900, height: 620)] {
            window.setContentSize(size); page!.layoutSubtreeIfNeeded()
            for button in [showSongInfoCheck!, fadeMenuButtonCheck!] {
                try checkTarget(button, in: page!)
                let captionPoint = button.convert(NSPoint(x: 50, y: button.bounds.midY), to: page!)
                try checkUI(page!.hitTest(captionPoint) === button, "Accessibility caption lost its checkbox target")
                try checkUI(button.accessibilityPerformPress(), "Accessibility checkbox could not be toggled")
            }
            try checkUI(!lastSettings.showSongInfo && !lastSettings.fadeMenuButton,
                "Accessibility changes did not reach the settings callback")
            try shot(page!, "distraction-options-off-\(Int(size.width))")
            for button in [showSongInfoCheck!, fadeMenuButtonCheck!] {
                window.makeFirstResponder(button)
                let key = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                    windowNumber: window.windowNumber, context: nil, characters: "\r", charactersIgnoringModifiers: "\r",
                    isARepeat: false, keyCode: 36)!
                try checkUI(GameScreen.shared.handleDialogKey(key), "Accessibility checkbox missed Return")
            }
            try checkUI(lastSettings.showSongInfo && lastSettings.fadeMenuButton,
                "Keyboard changes did not restore the Accessibility choices")
            try shot(page!, "distraction-options-on-\(Int(size.width))")
        }
        GameScreen.shared.dismissAll()
        print("PASS Accessibility options: checked/unchecked/focused renders, caption targets, accessible press and Return")
    }

    @MainActor fileprivate func checkSettings() async throws {
        show()
        let tabs = page!.body.subviews.first { $0 is GameTabs } as! GameTabs
        let buttons = tabs.subviews.compactMap { $0 as? GameTabButton }
        try checkUI(buttons.map(\.title) == ["Gameplay", "Controller", "Graphics", "Video", "Audio", "Accessibility", "Privacy"], "Settings tab order changed")
        func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
        for size in [NSSize(width: 1120, height: 720), NSSize(width: 900, height: 620)] {
            window.setContentSize(size)
            for button in buttons {
                button.performClick(nil)
                page!.layoutSubtreeIfNeeded()
                let container = page!.enclosingScrollView!
                try checkUI(container.verticalScrollElasticity == .none && container.horizontalScrollElasticity == .none,
                    "Settings can bounce away from the underlying menu")
                let origin = container.contentView.bounds.origin
                for delta: Int32 in [-120, 120] {
                    let event = NSEvent(cgEvent: CGEvent(scrollWheelEvent2Source: nil, units: .pixel,
                        wheelCount: 2, wheel1: delta, wheel2: delta, wheel3: 0)!)!
                    container.scrollWheel(with: event)
                    try checkUI(container.contentView.bounds.origin == origin,
                        "Scrolling moved the Settings page at a fitting window size")
                }
                try checkTarget(button, in: page!)
                let selected = descendants(tabs).compactMap { $0 as? NSTabView }.first!.selectedTabViewItem!.view!
                let controls = descendants(selected).compactMap { $0 as? NSControl }.filter { $0 is NSButton || $0 is NSSlider }
                try checkUI(!controls.isEmpty, "Settings pane has no controls")
                for control in controls {
                    control.scrollToVisible(control.bounds)
                    page!.layoutSubtreeIfNeeded()
                    try checkTarget(control, in: page!)
                    try checkUI(control.accessibilityLabel()?.isEmpty == false && control.accessibilityHelp()?.isEmpty == false,
                        "Setting lacks accessible help: \(control)")
                    try checkUI(control.toolTip == nil && !control.trackingAreas.isEmpty, "Setting lacks game hover help")
                    if let checkbox = control as? GameCheckButton {
                        let labelPoint = checkbox.convert(CGPoint(x: 30, y: checkbox.bounds.midY), to: page!)
                        try checkUI(page!.hitTest(labelPoint) === checkbox, "Checkbox text is not part of its target")
                    }
                }
                let scroll = selected as! GameSettingsScrollView
                let document = scroll.documentView!
                scroll.contentView.scroll(to: .zero)
                scroll.reflectScrolledClipView(scroll.contentView)
                try shot(page!, "settings-\(Int(size.width))-" + button.title.lowercased())
                if document.bounds.height > scroll.contentSize.height {
                    scroll.contentView.scroll(to: CGPoint(x: 0, y: document.bounds.height - scroll.contentSize.height))
                    scroll.reflectScrolledClipView(scroll.contentView)
                    try shot(page!, "settings-\(Int(size.width))-" + button.title.lowercased() + "-bottom")
                }
            }
        }
        window.setContentSize(NSSize(width: 1120, height: 720))
        buttons.first { $0.title == "Audio" }!.performClick(nil)
        page!.layoutSubtreeIfNeeded()
        let beat = pauseBeatCheck!
        let audioScroll = beat.enclosingScrollView!
        try checkUI(audioScroll.documentView!.bounds.height <= audioScroll.contentSize.height + 1, "Audio requires scrolling at the standard menu size: \(audioScroll.documentView!.bounds.height) / \(audioScroll.contentSize.height)")
        let falls = (beat.superview!.subviews.compactMap { $0 as? GameCheckButton }).first { $0.title == "Play death sound" }!
        let download = (beat.superview!.subviews.compactMap { $0 as? GameButton }).first { $0.title == "Download soundtracks" }!
        try checkUI(beat.frame.maxY <= falls.frame.minY && falls.frame.maxY < download.frame.minY, "Audio behaviour and downloads are in the wrong order")
        try checkUI(abs(beat.frame.maxY - falls.frame.minY) <= 8, "Audio behaviour switches are separated")
        beat.scrollToVisible(beat.bounds)
        let enter = NSEvent.enterExitEvent(with: .mouseEntered, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: window.windowNumber, context: nil, eventNumber: 0, trackingNumber: 0, userData: nil)!
        let exit = NSEvent.enterExitEvent(with: .mouseExited, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: window.windowNumber, context: nil, eventNumber: 0, trackingNumber: 0, userData: nil)!
        let tracker = beat.trackingAreas.first!.owner as! NSObject
        tracker.perform(NSSelectorFromString("mouseEntered:"), with: enter)
        try await Task.sleep(nanoseconds: 200_000_000)
        try checkUI(help.panel == nil, "Help appeared before its delay")
        try await Task.sleep(nanoseconds: 700_000_000)
        guard let panel = help.panel else { throw CocoaError(.validationMissingMandatoryProperty) }
        try checkUI(!panel.pinned && panel.superview!.bounds.contains(panel.frame), "Hover help is clipped")
        try checkTarget(beat, in: page!)
        try shot(page!, "settings-hover-help")
        tracker.perform(NSSelectorFromString("mouseExited:"), with: exit)
        try checkUI(help.panel == nil, "Hover help survived pointer exit")
        tracker.perform(NSSelectorFromString("mouseEntered:"), with: enter)
        tracker.perform(NSSelectorFromString("mouseExited:"), with: exit)
        try await Task.sleep(nanoseconds: 900_000_000)
        try checkUI(help.panel == nil, "Brief hover opened stale help")
        help.hover(beat, title: "Pause", text: "Delayed help")
        buttons.first { $0.title == "Privacy" }!.performClick(nil)
        try await Task.sleep(nanoseconds: 900_000_000)
        try checkUI(help.panel == nil, "Delayed help survived a tab change")
        let info = descendants(tabs).compactMap { $0 as? GameButton }.first { $0.title == "Privacy info" }!
        try checkUI(telemetryCheck!.isEnabled == (telemetry.endpoint != nil), "Sharing availability is incorrect")
        GameScreen.shared.keyboardNavigation.focus(info, in: window)
        let activation = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: window.windowNumber, context: nil, characters: "\r", charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36)!
        try checkUI(GameScreen.shared.handleDialogKey(activation), "Privacy info did not accept keyboard activation")
        try checkUI(help.panel?.pinned == true, "Privacy info did not open")
        try shot(page!, "settings-privacy-popover")
        let close = help.panel!.subviews.compactMap { $0 as? NSButton }.first!
        try checkTarget(close, in: page!)
        try checkUI(GameScreen.shared.keyboardNavigation.controls(in: page!).contains { $0 === close }, "Privacy Close is unavailable to keyboard navigation")
        close.performClick(nil)
        try checkUI(help.panel == nil, "Privacy popover did not close")
        try checkUI(!descendants(telemetryCheck!.superview!).compactMap { $0 as? GameLabel }.contains { $0.stringValue.contains("network address") }, "Privacy detail remains inline")
        try checkUI(pointerCaptureCheck!.superview === experiencePopUp!.superview, "Pointer capture is outside Gameplay")
        buttons.first { $0.title == "Controller" }!.performClick(nil)
        controllerRemapButton!.performClick(nil)
        let mappingPage = GameScreen.shared.controllerPage(in: window) as! GameMenuPage
        mappingPage.layoutSubtreeIfNeeded()
        try checkTarget(remapSource!, in: mappingPage)
        try checkTarget(remapRole!, in: mappingPage)
        help.show(remapRole!.accessibilityHelp()!, title: "Gameplay action", relativeTo: remapRole!)
        try checkUI(help.panel != nil, "Button mapping lacks its help popover")
        try shot(mappingPage, "settings-controller-mapping-help")
        mappingPage.onBack?()
        try checkUI(help.panel == nil, "Mapping help survived Back")
        GameScreen.shared.dismiss(page!)
        print("PASS all settings groups, two window sizes, targets, checkbox labels, delayed hover, cancellation and privacy popover")
    }

    @MainActor fileprivate func checkAudio() throws {
        show()
        let tabs = page!.body.subviews.first { $0 is GameTabs }!
        let audio = tabs.subviews.compactMap { $0 as? NSButton }.first { $0.title == "Audio" }!
        audio.performClick(nil)
        page!.layoutSubtreeIfNeeded()
        let beat = pauseBeatCheck!
        beat.scrollToVisible(beat.bounds)
        try checkTarget(beat, in: page!)
        var changed = false
        onChange = { changed = $0.pauseMusicBeatOnly }
        beat.performClick(nil)
        try checkUI(changed && current.pauseMusicBeatOnly && beat.state == .on, "Pause checkbox did not apply its setting")
        try checkUI(beat.accessibilityLabel()?.contains("Pause") == true, "Pause control lacks its accessible action name")
        let pane = beat.superview!
        let controls = pane.subviews.filter { $0 is NSControl && !($0 is NSTextField) }
        for control in controls { control.scrollToVisible(control.bounds); try checkTarget(control, in: page!) }
        for (index, control) in controls.enumerated() {
            for other in controls.dropFirst(index+1) {
                try checkUI(!control.frame.intersects(other.frame), "Audio controls overlap")
            }
        }
        try shot(page!, "audio-settings")
        beat.performClick(nil)
        try checkUI(!current.pauseMusicBeatOnly, "Pause checkbox could not be disabled")
        GameScreen.shared.dismiss(page!)
        print("PASS rendered Audio settings, pause toggle, accessibility and all input targets")
    }
}
extension MusicLibraryWindow {
    @MainActor fileprivate func checkStates() throws {
        let defaults = UserDefaults(suiteName: "music-welcome-" + UUID().uuidString)!
        showIfNeeded(in: window, defaults: defaults)
        page!.layoutSubtreeIfNeeded()
        let pack = packs.first { $0.id == "demos" }!
        try checkUI(page!.controllerBackButton.title == "Not now" && selected.count == downloadable.count,
            "First launch did not offer optional libraries and a skip action")
        try checkUI(action!.isEnabled && action!.title == "Download" && rows.count == packs.count,
            "The checklist omitted libraries or its download action")
        try checkTarget(action!, in: page!); try checkTarget(all!, in: page!)
        try shot(page!, "library-welcome")
        window.setContentSize(NSSize(width: 900, height: 620))
        page!.layoutSubtreeIfNeeded()
        try checkTarget(action!, in: page!); try checkTarget(all!, in: page!)
        try shot(page!, "library-compact")
        window.setContentSize(NSSize(width: 1120, height: 720))
        page!.layoutSubtreeIfNeeded()
        all!.performClick(nil)
        try checkUI(selected.isEmpty && !action!.isEnabled, "Deselect all left an active download")
        let first = packs[0]
        rows[first.id]!.performClick(nil)
        try checkUI(selected == [first.id] && all!.state == .mixed, "Individual selection failed")
        try checkTarget(rows[first.id]!, in: page!)
        try shot(page!, "library-selected")
        all!.performClick(nil)
        activePack = pack.id; queueBytes = pack.bytes; progress = 0.42; refresh()
        try checkUI(!action!.isEnabled && !all!.isEnabled && !cancel!.isHidden && abs(meter!.doubleValue - 0.42) < 0.001,
            "Download progress state is wrong")
        try checkTarget(cancel!, in: page!)
        try checkUI(cancel!.title == "Cancel" && cancel!.accessibilityLabel() == "Cancel download", "Cancel action lost its accessible name")
        try shot(page!, "library-downloading")
        progress = 1; refresh()
        try checkUI(status!.stringValue == "Verifying", "Verification is not shown")
        try shot(page!, "library-verifying")
        activePack = nil; failure = "The soundtrack download is unavailable. Try again later."; refresh()
        try checkUI(action!.isEnabled && action!.title == "Retry" && cancel!.isHidden, "Failed download cannot be retried")
        try shot(page!, "library-retry")
        failure = nil
        let packRoot = directory.appendingPathComponent(pack.id)
        for file in pack.files {
            let url = packRoot.appendingPathComponent(file.path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            FileManager.default.createFile(atPath: url.path, contents: nil)
            let handle = try FileHandle(forWritingTo: url)
            try handle.truncate(atOffset: UInt64(file.bytes)); try handle.close()
        }
        try JSONEncoder().encode(["id": pack.id, "sha256": pack.sha256]).write(to: packRoot.appendingPathComponent("installed.json"))
        refresh()
        try checkUI(rows[pack.id]!.state == .on && !rows[pack.id]!.isEnabled && rowStates[pack.id]!.stringValue == "Installed" && !remove!.isHidden,
            "Installed state is wrong")
        try checkTarget(remove!, in: page!)
        try shot(page!, "library-installed")
        page!.onBack?()
        try checkUI(defaults.bool(forKey: Self.welcomeKey), "Closing welcome was not remembered")
        showIfNeeded(in: window, defaults: defaults)
        try checkUI(!GameScreen.shared.isPresented, "The first-launch offer repeated")
        show(in: window)
        try checkUI(page?.controllerBackButton.title == "Back", "Settings could not reopen the libraries")
        GameScreen.shared.dismissAll()
        print("PASS first-launch soundtrack checklist, selection, skip persistence, progress, retry, installed states and Settings reopen")
    }
}
extension AppUpdates {
    @MainActor fileprivate func checkReminder() throws {
        var changed = 0; onChange = { changed += 1 }
        let item = SUAppcastItem(dictionary: ["enclosure": ["url": "https://example.invalid/update.zip",
            "sparkle:version": "52", "sparkle:shortVersionString": "1.6.1"]])!
        setAvailable(item, downloaded: false)
        try checkUI(availableVersion == "1.6.1" && !isDownloaded, "Available update was not announced")
        setAvailable(item, downloaded: true)
        try checkUI(isDownloaded && changed == 2, "Automatic download did not update the reminder")
        clear()
        try checkUI(availableVersion == nil && !isDownloaded, "Unavailable or skipped updates kept a reminder")
        print("PASS available, downloaded and cleared update reminder states")
    }
}
@MainActor private func checkReleaseWelcome() throws {
    let defaults = UserDefaults(suiteName: "release-welcome-" + UUID().uuidString)!
    let notes = ReleaseWelcome(defaults: defaults, build: 51, version: "1.6")
    var continuations = 0
    notes.showIfNeeded(in: window, existingPlayer: true) { continuations += 1 }
    let page = GameScreen.shared.controllerPage(in: window) as! GameMenuPage
    try checkUI(page.accessibilityLabel() == "What's new in 1.6" && continuations == 0,
        "An existing player did not see upgrade notes before onboarding")
    try shot(page, "whats-new")
    let key = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 1,
        windowNumber: window.windowNumber, context: nil, characters: "\r", charactersIgnoringModifiers: "\r",
        isARepeat: false, keyCode: 36)!
    try checkUI(GameScreen.shared.handleDialogKey(key), "Continue did not accept Return")
    try checkUI(continuations == 1 && defaults.integer(forKey: ReleaseWelcome.seenKey) == 51,
        "Upgrade notes were not acknowledged")
    notes.showIfNeeded(in: window, existingPlayer: true) { continuations += 1 }
    try checkUI(continuations == 2 && !GameScreen.shared.isPresented, "Upgrade notes repeated on ordinary launch")
    let next = ReleaseWelcome(defaults: defaults, build: 52, version: "1.6.1")
    next.showIfNeeded(in: window, existingPlayer: true) { continuations += 1 }
    try checkUI(GameScreen.shared.isPresented, "A later automatic update skipped its notes")
    GameScreen.shared.dismissAll()
    let fresh = UserDefaults(suiteName: "fresh-welcome-" + UUID().uuidString)!
    ReleaseWelcome(defaults: fresh, build: 51).showIfNeeded(in: window, existingPlayer: false) { continuations += 1 }
    try checkUI(!GameScreen.shared.isPresented && fresh.integer(forKey: ReleaseWelcome.seenKey) == 51,
        "A fresh install was treated as an upgrade")
    print("PASS upgrade notes persist only after acknowledgement, repeat for later builds and do not block a fresh install")
}
extension Lemmings2PlayWindow {
    @MainActor fileprivate func checkNukeReturn() throws {
        defer { stop() }
        timer?.invalidate(); timer = nil
        audioSettings.music = .silent
        prepareBriefing()
        for tribe in [0, 1] {
            for hd in [true, false] {
                canvas.hdEffectsEnabled = hd
                failureMusic.update(failed: false, isNuking: false, allPopped: false, now: -5)
                failureMusic.advance(at: -1)
                failureMood.set(active: false, now: -5)
                failureMood.advance(at: -1)
                let width = 512, height = 160
                let solid = (0..<(width * height)).map { $0 / width >= 80 }
                var fixture = try Lemmings2Runtime(configuration: .init(
                    width: width, height: height, pixels: solid.map { $0 ? 1 : 0 }, solid: solid,
                    palette: [UInt8](repeating: 0, count: 1024),
                    entrance: .init(x: 100, y: 40, width: 1, height: 1),
                    exits: [.init(x: 500, y: 60, width: 5, height: 20)],
                    skills: [.digger, .climber, .builder, .basher, .miner, .floater, .bomber, .blocker],
                    supplies: [Int](repeating: 10, count: 8), total: 3, timeLimit: 300,
                    releaseInterval: 2, terrainMasks: masks, firstReleaseTick: 1, tribe: tribe))
                for _ in 0..<20 { fixture.step() }
                try checkUI(fixture.lemmings.filter(\.active).count == 3, "L2 nuke fixture needs three live lemmings")
                _ = fixture.drainSoundEvents()
                fixture.nuke(); game = fixture; screen = .playing; nukeMood.reset(); refreshGame(at: 0)
                failureMusic.advance(at: 0.9)
                try checkUI(failureMusic.rate == 1, "L2 nuke slowed music before countdown one")
                var pops = 0, lastPopTime = 0.0, reachedOne = false
                for index in 1...200 {
                    fixture.step()
                    pops += fixture.drainSoundEvents().filter { $0.sample == Lemmings2SoundCue.explode.rawValue }.count
                    let now = Double(index) / 17
                    failureMusic.advance(at: now)
                    game = fixture; refreshGame(at: now)
                    if !reachedOne, let ticks = fixture.lemmings.compactMap(\.bombTicks).min() {
                        if ticks > 15 {
                            try checkUI(failureMusic.rate == 1, "L2 slowed music before countdown one")
                        } else {
                            reachedOne = true
                            try checkUI(failureMusic.rate == 1, "L2 countdown one jumped to funeral speed")
                            failureMusic.advance(at: now + 0.03)
                            try checkUI(failureMusic.rate < 1, "L2 2-to-1 countdown did not start the slowdown")
                            failureMood.advance(at: now + 0.9)
                            try checkUI(failureMood.amount == 0, "L2 nuke slowdown desaturated a recoverable run")
                        }
                    }
                    if pops == 3 { lastPopTime = now; break }
                    if hd && index >= 75 {
                        nukeMood.advanceReturn(at: now + 0.14)
                        try checkUI(nukeMood.amount == 1, "L2 opened its filter before the final audible pop in tribe \(tribe)")
                    }
                }
                try checkUI(reachedOne && pops == 3, "L2 nuke fixture did not produce three pops in tribe \(tribe)")
                if tribe == 0 {
                    try checkUI(!fixture.isComplete, "L2 discarded its explosion tails")
                }
                let returnRate = failureMusic.rate
                nukeMood.advanceReturn(at: lastPopTime + NukeMusicSweep.returnDuration / 2)
                failureMusic.advance(at: lastPopTime + NukeMusicSweep.returnDuration / 2)
                try checkUI(returnRate < 1 && abs(failureMusic.rate - (1 + returnRate) / 2) < 0.0001,
                    "L2 did not spin up after the final pop")
                try checkUI(abs(nukeMood.amount - (hd ? 0.5 : 0)) < 0.0001, "L2 did not open its filter after the last pop")
                show(.results)
                try checkUI(!hd || nukeMood.amount > 0, "L2 results cut the return sweep short")
                refreshGame(at: lastPopTime + NukeMusicSweep.returnDuration)
                failureMusic.advance(at: lastPopTime + NukeMusicSweep.returnDuration)
                try checkUI(abs(failureMusic.rate - 1) < 0.0001, "L2 results stalled the tempo return")
                try checkUI(nukeMood.amount == 0, "L2 return sweep stalled after simulation stopped")
            }
        }
        print("PASS L2 2-to-1 nuke slowdown, separate saturation and final-pop recovery in Classic and non-Classic tribes, HD on and off")
    }

    @MainActor fileprivate func checkMusicPause() throws {
        defer { stop() }
        timer?.invalidate(); timer = nil
        audioSettings.music = .amigaModules; audioSettings.musicVolume = 0
        audioSettings.pauseMusicBeatOnly = true
        prepareBriefing(); startLevel(); canvas.startCountdown.cancel(); paused = false
        _ = music.play(url: Bundle.main.resourceURL!.appendingPathComponent("Music/lemmings_music_mod/cancan.mod"))
        singleStep()
        try checkUI(paused && userPausedMusic && music.isOutputRunning, "L2 frame-step did not keep its rhythm")
        try resumeAudioOutput()
        try checkUI(music.isOutputRunning, "L2 lost its pause mode after audio interruption")
        interruptGameplay(); try resumeAudioOutput()
        try checkUI(!music.isOutputRunning && paused, "L2 interruption resumed before Ready")
        restart()
        try checkUI(!userPausedMusic && music.isOutputRunning, "L2 retry retained its old pause mode")
        try checkUI(paused && canvas.startCountdown.isActive, "L2 retry bypassed its ready countdown")
        window?.orderOut(nil)
        print("PASS L2 frame-step, rhythm pause, interruption and paused retry")
    }
}
extension Lemmings3PlayWindow {
    @MainActor fileprivate func checkMusicPause() throws {
        defer { stop() }
        timer?.invalidate(); timer = nil
        var settings = ClassicSettings(); settings.music = .amigaModules; settings.pauseMusicBeatOnly = false
        setAudioSettings(settings, muted: true)
        canvas.startCountdown.cancel(); paused = false; updateUserMusicPause()
        _ = music.play(url: Bundle.main.resourceURL!.appendingPathComponent("Music/lemmings_music_mod/cancan.mod"))
        singleStep()
        try checkUI(paused && userPausedMusic && !music.isOutputRunning, "L3 frame-step did not pause music")
        audioSettings.pauseMusicBeatOnly = true; updateUserMusicPause()
        try checkUI(music.isOutputRunning, "L3 beat pause did not keep percussion")
        suspendAudioOutput(); try resumeAudioOutput()
        try checkUI(paused && music.isOutputRunning, "L3 lost the user's pause mode after audio interruption")
        interruptGameplay(); try resumeAudioOutput()
        try checkUI(!music.isOutputRunning && paused, "L3 interruption resumed before the player was ready")
        restart()
        try checkUI(!userPausedMusic && music.isOutputRunning, "L3 retry retained the old music pause")
        try checkUI(paused && game.tick == 0, "L3 retry bypassed its ready countdown")
        print("PASS L3 frame-step, rhythm pause, interruption, resume and paused retry")
    }
}
@MainActor private final class SharingPrivacyTransport: AnonymousTelemetryTransport {
    func data(for request: URLRequest) async throws -> (Data, URLResponse) { throw URLError(.cancelled) }
}

@MainActor extension SettingsWindow {
    fileprivate func checkAutomaticSharingPrivacy() throws {
        show()
        let tabs = page!.body.subviews.first { $0 is GameTabs } as! GameTabs
        tabs.subviews.compactMap { $0 as? GameTabButton }.first { $0.title == "Privacy" }!.performClick(nil)
        for size in [NSSize(width: 900, height: 620), NSSize(width: 1120, height: 720)] {
            window.setContentSize(size); page!.layoutSubtreeIfNeeded()
            let control = telemetryCheck!
            try checkUI(control.title == "Share counts and records", "Privacy still promises counts alone")
            try checkUI(privacyHelp.contains("player initials, scores and action replays"), "Privacy omitted public ranking data")
            for state in [false, true] {
                if (control.state == .on) != state { control.performClick(nil) }
                try checkUI(telemetry.sharesCounts == state, "Privacy sharing input did not update its state")
                try checkTarget(control, in: page!)
                try checkUI(control.bounds.width >= control.intrinsicContentSize.width, "Sharing caption is clipped")
                try shot(page!, "sharing-privacy-\(Int(size.width))-\(state ? "on" : "off")")
            }
        }
        GameScreen.shared.dismissAll()
    }
}

@MainActor private func checkSharingConsent() throws {
    let suite = "sharing-consent-" + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let telemetry = AnonymousTelemetry(defaults: defaults, endpoint: URL(string: "https://example.invalid/counts"), transport: SharingPrivacyTransport())
    let consent = TelemetryConsentWindow(telemetry: telemetry)
    for width in [900, 1120] {
        window.setContentSize(NSSize(width: width, height: 720))
        defaults.removeObject(forKey: AnonymousTelemetry.decidedKey)
        consent.showIfNeeded(in: window) {}
        let page = GameScreen.shared.controllerPage(in: window) as! GameMenuPage
        page.layoutSubtreeIfNeeded()
        func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
        let children = descendants(page)
        try checkUI(children.compactMap { $0 as? GameLabel }.contains { $0.stringValue == "Public: initials, scores and action replays." }, "Consent omitted public records")
        let share = children.compactMap { $0 as? NSButton }.first { $0.title == "Share" }!
        try checkTarget(share, in: page)
        try checkTarget(page.controllerBackButton, in: page)
        try shot(page, "sharing-consent-\(width)")
        page.controllerBackButton.performClick(nil)
        try checkUI(!telemetry.sharesCounts, "Not now enabled sharing")
    }
    print("PASS sharing Privacy on/off, two consent renders, captions, public-data disclosure and input targets")
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let shots = root.appendingPathComponent(".build/music-ui-tests/screenshots")
try FileManager.default.createDirectory(at: shots, withIntermediateDirectories: true)
let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("music-ui-" + UUID().uuidString)
try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: temporary) }
ArcadeStore.shared = ArcadeStore(file: temporary.appendingPathComponent("arcade.json"))
let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1120, height: 720), styleMask: [.titled], backing: .buffered, defer: false)
window.contentView = NSView(frame: NSRect(x: 0, y: 0, width: 1120, height: 720))
GameScreen.shared.gameWindow = window
if ProcessInfo.processInfo.environment["TEST_SCOPE"] == "sharing" {
    let suite = "sharing-ui-" + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let telemetry = AnonymousTelemetry(defaults: defaults, endpoint: URL(string: "https://example.invalid/counts"), transport: SharingPrivacyTransport())
    let preferences = SettingsWindow(settings: ClassicSettings(), options: ClassicSettingsOptions(graphics: [.macintosh], music: [.silent], sound: [.silent]), telemetry: telemetry)
    try preferences.checkAutomaticSharingPrivacy()
    try checkSharingConsent()
} else if ProcessInfo.processInfo.environment["TEST_SCOPE"] == "distraction" {
    let preferences = SettingsWindow(settings: ClassicSettings(), options: ClassicSettingsOptions(graphics: [.macintosh], music: [.silent], sound: [.silent]))
    try preferences.checkDistractionOptions()
    try checkDistractionFeedback()
} else if ProcessInfo.processInfo.environment["TEST_SCOPE"] == "rescue-aura" {
    try checkClassicRescueAura()
    try Lemmings2PlayWindow(root: Bundle.main.resourceURL!.appendingPathComponent("Ports/Lemm2")).checkRescueAura()
    try Lemmings3PlayWindow(root: Bundle.main.resourceURL!.appendingPathComponent("Ports/LEM3CD")).checkRescueAura()
} else if ProcessInfo.processInfo.environment["TEST_SCOPE"] == "settings" {
    let suite = "settings-ui-" + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let telemetry = AnonymousTelemetry(defaults: defaults, endpoint: URL(string: "https://example.invalid/counts"))
    let preferences = SettingsWindow(settings: ClassicSettings(), options: ClassicSettingsOptions(graphics: [.macintosh], music: ClassicSettingsOptions.playableMusic, sound: ClassicSettingsOptions.playableSound), telemetry: telemetry)
    try await preferences.checkSettings()
    try preferences.checkAudio()
    let offline = SettingsWindow(settings: ClassicSettings(), options: ClassicSettingsOptions(graphics: [], music: [.silent], sound: []), telemetry: AnonymousTelemetry(defaults: defaults, endpoint: URL(string: "http://example.invalid")))
    try await offline.checkSettings()
} else if ProcessInfo.processInfo.environment["TEST_SCOPE"] == "sequel-pause" {
    try Lemmings2PlayWindow(root: Bundle.main.resourceURL!.appendingPathComponent("Ports/Lemm2")).checkMusicPause()
    try Lemmings3PlayWindow(root: Bundle.main.resourceURL!.appendingPathComponent("Ports/LEM3CD")).checkMusicPause()
} else if ProcessInfo.processInfo.environment["TEST_SCOPE"] == "nuke" {
    try Lemmings2PlayWindow(root: Bundle.main.resourceURL!.appendingPathComponent("Ports/Lemm2")).checkNukeReturn()
    print("Nuke controller integration tests passed.")
} else {
try SettingsWindow(settings: ClassicSettings(), options: ClassicSettingsOptions(graphics: [.macintosh], music: ClassicSettingsOptions.playableMusic, sound: ClassicSettingsOptions.playableSound)).checkAudio()
try AppUpdates().checkReminder()
try checkReleaseWelcome()
try MusicLibraryWindow(directory: temporary.appendingPathComponent("libraries")).checkStates()

try Lemmings2PlayWindow(root: Bundle.main.resourceURL!.appendingPathComponent("Ports/Lemm2")).checkMusicPause()
try Lemmings2PlayWindow(root: Bundle.main.resourceURL!.appendingPathComponent("Ports/Lemm2")).checkNukeReturn()
try Lemmings3PlayWindow(root: Bundle.main.resourceURL!.appendingPathComponent("Ports/LEM3CD")).checkMusicPause()

print("Music UI and sequel pause tests passed.")
}

exit(0)
