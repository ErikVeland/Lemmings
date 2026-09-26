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
extension SettingsWindow {
    @MainActor fileprivate func checkAudio() throws {
        show()
        let tabs = page!.body.subviews.first { $0 is GameTabs }!
        let audio = tabs.subviews.compactMap { $0 as? NSButton }.first { $0.title == "Audio" }!
        audio.performClick(nil)
        page!.layoutSubtreeIfNeeded()
        let beat = pauseBeatCheck!
        try checkTarget(beat, in: page!)
        var changed = false
        onChange = { changed = $0.pauseMusicBeatOnly }
        beat.performClick(nil)
        try checkUI(changed && current.pauseMusicBeatOnly && beat.state == .on, "Pause checkbox did not apply its setting")
        try checkUI(beat.accessibilityLabel()?.contains("Pause") == true, "Pause control lacks its accessible action name")
        let pane = beat.superview!
        let controls = pane.subviews.filter { $0 is NSControl && !($0 is NSTextField) }
        for control in controls { try checkTarget(control, in: page!) }
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
try SettingsWindow(settings: ClassicSettings(), options: ClassicSettingsOptions(graphics: [.macintosh], music: ClassicSettingsOptions.playableMusic, sound: ClassicSettingsOptions.playableSound)).checkAudio()
try AppUpdates().checkReminder()
try checkReleaseWelcome()
try MusicLibraryWindow(directory: temporary.appendingPathComponent("libraries")).checkStates()

try Lemmings2PlayWindow(root: Bundle.main.resourceURL!.appendingPathComponent("Ports/Lemm2")).checkMusicPause()
try Lemmings3PlayWindow(root: Bundle.main.resourceURL!.appendingPathComponent("Ports/LEM3CD")).checkMusicPause()

print("Music UI and sequel pause tests passed.")
