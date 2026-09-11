
// Appended to the two canvas source files by the runner to inspect real views.
import CryptoKit

let app = NSApplication.shared
ArcadeStore.shared = ArcadeStore(file: FileManager.default.temporaryDirectory.appendingPathComponent("arcade-sequel-tests-\(UUID().uuidString).json"))
let sourceRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let testAppRoot = ProcessInfo.processInfo.environment["LEMMINGS_TEST_APP"].map { URL(fileURLWithPath: $0) }
    ?? sourceRoot.appendingPathComponent(".build/local/Ultimate Lemmings.app")
ArcadeWindow.shared.arcadeView.useArtwork(try ClassicMacArtwork(directory:
    testAppRoot.appendingPathComponent("Contents/Resources/MacArtwork/lemmings")))
let shotRoot = sourceRoot.appendingPathComponent(".build/sequel-mac-artwork/levels")
try FileManager.default.createDirectory(at:shotRoot,withIntermediateDirectories:true)
let previousPreference = UserDefaults.standard.object(forKey:SequelArtworkPreference.key)
defer {
    if let previousPreference { UserDefaults.standard.set(previousPreference,forKey:SequelArtworkPreference.key) }
    else { UserDefaults.standard.removeObject(forKey:SequelArtworkPreference.key) }
}
func readAsset(_ base: URL, _ path: String) throws -> Data { try Data(contentsOf:base.appendingPathComponent(path)) }
@MainActor func shot(_ view: NSView, _ name: String) throws -> Data {
    view.needsDisplay = true
    guard let bitmap = view.bitmapImageRepForCachingDisplay(in:view.bounds) else {
        throw SequelDataError.invalid("Cannot render the sequel canvas.")
    }
    view.cacheDisplay(in:view.bounds,to:bitmap)
    guard let png = bitmap.representation(using:.png,properties:[:]) else {
        throw SequelDataError.invalid("Cannot encode the sequel canvas.")
    }
    try png.write(to:shotRoot.appendingPathComponent(name+".png"))
    return png
}
func assertArtwork(_ condition: Bool, _ message: String) throws {
    if !condition { throw SequelDataError.invalid(message) }
}
@MainActor private func assertSolidSpritePixels(view: NSView, playfield: CGRect,
    plain: Data, fast: Data, drawSprites: () -> Void) throws {
    let normal = NSBitmapImageRep(data: plain)!, speed = NSBitmapImageRep(data: fast)!
    let width = normal.pixelsWide, height = normal.pixelsHigh
    let mask = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
        bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    mask.translateBy(x: 0, y: CGFloat(height))
    mask.scaleBy(x: CGFloat(width) / view.bounds.width, y: -CGFloat(height) / view.bounds.height)
    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    NSGraphicsContext.current = NSGraphicsContext(cgContext: mask, flipped: true)
    mask.clip(to: playfield)
    drawSprites()
    let pixels = mask.data!.assumingMemoryBound(to: UInt8.self)
    var checked = 0
    for y in 0..<height { for x in 0..<width where pixels[(y * width + x) * 4 + 3] == 255 {
        checked += 1
        try assertArtwork(normal.colorAt(x: x, y: y) == speed.colorAt(x: x, y: y),
            "A speed ghost changed a solid sprite pixel at \(x),\(y)")
    } }
    try assertArtwork(checked > 0, "The sprite layering test had no solid sprite pixels")
}

extension Lemmings2Canvas {
    fileprivate func checkSuperSpeedLifecycle() throws {
        guard let host = window else { throw SequelDataError.invalid("No L2 window for speed test") }
        isFastForward = true
        try assertArtwork(hdrOverlay?.isSuperSpeedActive == true, "L2 did not engage screen speed effects")
        hdEffectsEnabled = false
        try assertArtwork(isFastForward && !usesSpeedEffects && hdrOverlay?.isSuperSpeedActive == false,
            "L2 old-school mode retained speed effects or disabled fast-forward")
        hdEffectsEnabled = true
        try assertArtwork(hdrOverlay?.isSuperSpeedActive == true, "L2 HD mode did not restore speed effects")
        reduceMotion = true
        try assertArtwork(hdrOverlay?.isSuperSpeedActive == false && isFastForward, "Reduced motion did not suppress sequel speed effects")
        reduceMotion = false
        reduceFlashes = true
        try assertArtwork(usesSpeedEffects && hdrOverlay?.isSuperSpeedActive == true, "Reduced flashes disabled sequel speed effects")
        reduceFlashes = false
        fullScreenHDRFlashes = false
        try assertArtwork(hdrOverlay?.isSuperSpeedActive == true, "L2 explosion setting disabled speed effects")
        host.contentView = nil
        try assertArtwork(hdrOverlay?.isSuperSpeedActive == false, "Detached L2 canvas kept animating speed effects")
        host.contentView = self
        try assertArtwork(hdrOverlay?.isSuperSpeedActive == true, "L2 did not restore speed effects on return")
        isFastForward = false
        try assertArtwork(hdrOverlay?.isSuperSpeedActive == false, "L2 retained speed effects at 1x")
        print("PASS L2 super speed: engagement, explosion independence, detach, return and 1x")
    }
    fileprivate func checkSpeedSpriteLayers(plain: Data, fast: Data) throws {
        guard let game else { throw SequelDataError.invalid("No L2 game for the layering test") }
        try assertSolidSpritePixels(view: self,
            playfield: CGRect(x: origin.x, y: origin.y, width: visibleWidth * zoom, height: 192 * zoom),
            plain: plain, fast: fast) { drawLemmings(game, ghostsOnly: false) }
    }
}
extension Lemmings3Canvas {
    fileprivate func checkSuperSpeedLifecycle() throws {
        isFastForward = true
        try assertArtwork(hdrOverlay?.isSuperSpeedActive == true, "L3 did not engage screen speed effects")
        menuRows = ["RESUME"]
        try assertArtwork(hdrOverlay?.isSuperSpeedActive == false, "L3 menu retained speed effects")
        menuRows = nil
        try assertArtwork(hdrOverlay?.isSuperSpeedActive == true, "L3 did not restore speed effects after its menu")
        hdEffectsEnabled = false
        try assertArtwork(isFastForward && !usesSpeedEffects && hdrOverlay?.isSuperSpeedActive == false,
            "L3 old-school mode retained speed effects or disabled fast-forward")
        hdEffectsEnabled = true
        try assertArtwork(hdrOverlay?.isSuperSpeedActive == true, "L3 HD mode did not restore speed effects")
        reduceMotion = true
        try assertArtwork(hdrOverlay?.isSuperSpeedActive == false && isFastForward, "Reduced motion did not suppress sequel speed effects")
        reduceMotion = false
        reduceFlashes = true
        try assertArtwork(usesSpeedEffects && hdrOverlay?.isSuperSpeedActive == true, "Reduced flashes disabled sequel speed effects")
        reduceFlashes = false
        fullScreenHDRFlashes = false
        try assertArtwork(hdrOverlay?.isSuperSpeedActive == true, "L3 explosion setting disabled speed effects")
        isFastForward = false
        try assertArtwork(hdrOverlay?.isSuperSpeedActive == false, "L3 retained speed effects at 1x")
        print("PASS L3 super speed: engagement, menu, resume, explosion independence and 1x")
    }
    fileprivate func checkSpeedSpriteLayers(plain: Data, fast: Data) throws {
        guard let game else { throw SequelDataError.invalid("No L3 game for the layering test") }
        try assertSolidSpritePixels(view: self, playfield: playfieldRect, plain: plain, fast: fast) {
            drawLemmings(game, ghostsOnly: false)
        }
    }
}

let l2root = sourceRoot.appendingPathComponent("Sources/Ports/Lemm2")
let l2sprites = try Lemmings2Sprites(data:readAsset(l2root,"VLEMMS.DAT"))
let l2intern = try Lemmings2SpecialGraphics(data:readAsset(l2root,"INTERN.DAT"))
let l2masks = try Lemmings2TerrainMasks(root:l2root)
let l2explosion = try Lemmings2Explosion(data:readAsset(l2root,"EXPLOSION.DAT"))
let l2walker = try Lemmings2Walker(data:readAsset(l2root,"WALKER.DAT"))
let l2front = try Lemmings2FrontEnd(root:l2root)
UserDefaults.standard.removeObject(forKey: SequelArtworkPreference.key)
try assertArtwork(SequelArtworkPreference.enabled, "Sequel artwork must default to Macintosh-style")
private let menuCanvas = Lemmings2MenuCanvas(frame: NSRect(x: 0, y: 0, width: 640, height: 400))
for (name, pixels) in l2front.pictures {
    let colours = l2front.banks["MENU"]!.palettes[0]
    let upgraded = menuCanvas.makeImage(pixels, width: 320, height: 200, palette: colours)
    let backing = upgraded.cgImage(forProposedRect: nil, context: nil, hints: nil)!
    try assertArtwork(backing.width == 640 && backing.height == 400 && upgraded.size == NSSize(width: 320, height: 200),
                      "L2 \(name) must use 2x artwork by default without changing layout")
}
let uiRenderer = SequelArtworkRenderer()
let menuPixels = l2front.pictures["MENU"]!
let menuPalette = l2front.banks["MENU"]!.palettes[1]
let uiImage = try uiRenderer.image(width: 320, height: 200, pixels: menuPixels, palette: menuPalette,
                                   category: .architectural, frontEnd: true)
let terrainImage = try uiRenderer.image(width: 320, height: 200, pixels: menuPixels, palette: menuPalette,
                                        category: .architectural)
let uiBytes = uiImage.cgImage(forProposedRect: nil, context: nil, hints: nil)!.dataProvider!.data! as Data
let terrainBytes = terrainImage.cgImage(forProposedRect: nil, context: nil, hints: nil)!.dataProvider!.data! as Data
try assertArtwork(uiBytes != terrainBytes, "Front-end art still uses only terrain rules")
try assertArtwork(uiImage.size == terrainImage.size, "UI contours changed logical layout")
print("PASS front-end contour treatment differs from terrain reconstruction without changing layout")
SequelArtworkPreference.setEnabled(false)
try assertArtwork(!SequelArtworkPreference.enabled, "Explicit original artwork choice must persist")
print("PASS default-on artwork, explicit opt-out, and all L2 front-end picture backing sizes")
for number in stride(from: 0, to: 120, by: 10) {
    let level = try Lemmings2Level(data:readAsset(l2root,String(format:"LEVELS/LEVEL%03d.DAT",number)))
    let style = try Lemmings2Style(data:readAsset(l2root,"STYLES/\(Lemmings2Campaign.styleNames[level.style]).DAT"))
    var game = try Lemmings2Runtime(level:level,style:style,masks:l2masks)
    for _ in 0..<110 { game.step() }
    let view = Lemmings2Canvas(frame:NSRect(x:0,y:0,width:640,height:480))
    let window = NSWindow(contentRect:view.frame,styleMask:[],backing:.buffered,defer:false)
    window.contentView = view
    SequelArtworkPreference.setEnabled(false)
    try view.load(level:level,style:style,sprites:l2sprites,intern:l2intern,explosion:l2explosion,walker:l2walker)
    view.update(game)
    let panel = try l2front.panel.render(skills:game.configuration.skills.map(\.rawValue),supplies:game.supplies,
        selected:0,saved:game.saved,remaining:game.lemmings.filter(\.active).count,seconds:game.remainingSeconds,
        label:"WALKER",palette:Lemmings2Panel.palette(over:style.palette))
    view.setPanel(panel)
    let original = try shot(view,"l2-\(number)-pc")
    SequelArtworkPreference.setEnabled(true)
    try view.refreshArtwork(); view.setPanel(panel)
    let upgraded = try shot(view,"l2-\(number)-mac")
    try assertArtwork(original != upgraded,"L2 artwork setting does not affect the live canvas")
    SequelArtworkPreference.setEnabled(false)
    try view.refreshArtwork(); view.setPanel(panel)
    let restored = try shot(view,"l2-\(number)-restored")
    try assertArtwork(original == restored,"L2 artwork toggle changed camera, registration or game state")
    if number == 10 {
        view.isFastForward = true
        for _ in 0..<3 { game.step(); view.update(game); _ = try shot(view,"l2-speed-trails") }
        let tick = game.tick, pixels = game.pixels, saved = game.saved
        let trails = try shot(view,"l2-speed-trails")
        view.isFastForward = false
        let plain = try shot(view,"l2-speed-plain")
        try assertArtwork(trails != plain, "Speed mode did not add afterimages")
        try view.checkSpeedSpriteLayers(plain: plain, fast: trails)
        try assertArtwork(game.tick == tick && game.pixels == pixels && game.saved == saved, "Speed rendering changed physics")
        print("PASS L2 speed afterimages changes only presentation")
        try view.checkSuperSpeedLifecycle()
    }
    window.contentView = nil
    print("PASS L2 live canvas \(number), 110 ticks, original/2x/toggle restoration")
}
let l3root = sourceRoot.appendingPathComponent("Sources/Ports/LEM3CD")
for number in [1,101,201] {
    let level = try Lemmings3Level(data:readAsset(l3root,String(format:"LEVELS/LEVEL%03d.DAT",number)))
    let style = try Lemmings3Style(directory:l3root.appendingPathComponent("STYLES"),number:level.style)
    let perm = try Lemmings3Objects(data:readAsset(l3root,String(format:"LEVELS/PERM%03d.OBS",level.permanentObjectsReference)))
    let temp = try Lemmings3Objects(data:readAsset(l3root,String(format:"LEVELS/TEMP%03d.OBS",level.temporaryObjectsReference)))
    let prefix = String(format:"GRAPHICS/TRIBE%03d",level.lemmingStyle)
    let sprites = try Lemmings3Sprites(index:readAsset(l3root,prefix+".IND"),commands:readAsset(l3root,prefix+".CMP"))
    let scene = try Lemmings3Scene(level:level,style:style,permanent:perm,temporary:temp)
    var game = try Lemmings3Runtime(level:level,style:style,permanent:perm,temporary:temp)
    for _ in 0..<110 { game.step() }
    let view = Lemmings3Canvas(frame:NSRect(x:0,y:0,width:640,height:320))
    let window = NSWindow(contentRect:view.frame,styleMask:[],backing:.buffered,defer:false)
    window.contentView = view
    SequelArtworkPreference.setEnabled(false)
    try view.load(scene:scene,style:style,permanent:perm,temporary:temp,sprites:sprites,root:l3root,terrainStyle:level.style)
    view.resetCamera(level); view.game = game
    try assertArtwork(view.playfieldRect.maxY == view.panelRect.minY, "L3 playfield must stop at the panel")
    var panelClick: Int?, gameClicks = 0
    view.onPanel = { slot, _ in panelClick = slot }
    view.onSpeedPress = { _, _ in panelClick = 6 }
    view.onClick = { _, _ in gameClicks += 1 }
    for slot in 0..<9 {
        let x = CGFloat(Lemmings3Panel.edges[slot] + Lemmings3Panel.edges[slot + 1]) / 2
        let p = view.convert(NSPoint(x: view.panelRect.minX + x * view.panelRect.width / 320, y: view.panelRect.midY), to: nil)
        view.mouseDown(with: NSEvent.mouseEvent(with: .leftMouseDown, location: p, modifierFlags: [], timestamp: 0,
            windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!)
        try assertArtwork(panelClick == slot && gameClicks == 0, "L3 panel click leaked into the playfield")
    }
    let original = try shot(view,"l3-\(number)-pc")
    SequelArtworkPreference.setEnabled(true); try view.refreshArtwork()
    let upgraded = try shot(view,"l3-\(number)-mac")
    try assertArtwork(original != upgraded,"L3 artwork setting does not affect the live canvas")
    SequelArtworkPreference.setEnabled(false); try view.refreshArtwork()
    var restored = try shot(view,"l3-\(number)-restored")
    try assertArtwork(original == restored,"L3 artwork toggle changed camera, registration or game state")
    let preceding = game
    game.step(); view.game = game
    restored = try shot(view, "l3-\(number)-speed-plain")
    view.game = preceding
    view.isFastForward = true
    _ = try shot(view, "l3-\(number)-speed-start")
    view.game = game
    let afterimages = try shot(view, "l3-\(number)-speed")
    view.isFastForward = false
    try assertArtwork(try shot(view, "l3-\(number)-speed-off") == restored,
        "L3 normal speed retained a afterimages frame")
    let normalBitmap = NSBitmapImageRep(data: restored)!, speedBitmap = NSBitmapImageRep(data: afterimages)!
    let panelScale = CGFloat(normalBitmap.pixelsHigh) / view.bounds.height
    for y in Int(view.panelRect.minY * panelScale)..<Int(view.panelRect.maxY * panelScale) {
        for x in 0..<normalBitmap.pixelsWide {
            try assertArtwork(normalBitmap.colorAt(x: x, y: y) == speedBitmap.colorAt(x: x, y: y),
                "L3 fast-forward changed a panel pixel")
        }
    }
    if number == 1 {
        try assertArtwork(afterimages != restored, "L3 speed mode did not add afterimages")
        try view.checkSpeedSpriteLayers(plain: restored, fast: afterimages)
        try view.checkSuperSpeedLifecycle()
    }
    // A contextual picker next to a lemming at the lower edge cannot cover the HUD.
    view.directionPoint = CGPoint(x: 9999, y: 9999)
    let picker = try shot(view, "l3-\(number)-direction")
    let plainPixels = NSBitmapImageRep(data: restored)!, pickerPixels = NSBitmapImageRep(data: picker)!
    let pixelScale = CGFloat(plainPixels.pixelsHigh) / view.bounds.height
    for y in Int(view.panelRect.minY * pixelScale)..<Int(view.panelRect.maxY * pixelScale) {
        for x in stride(from: 0, to: plainPixels.pixelsWide, by: 4) {
            try assertArtwork(plainPixels.colorAt(x: x, y: y) == pickerPixels.colorAt(x: x, y: y), "L3 direction picker overwrote panel counters")
        }
    }
    view.directionPoint = nil
    view.menuRows = ["RESUME", "RETRY LEVEL", "TRIBE CLASSIC", "PREVIOUS LEVEL", "NEXT LEVEL", "PLAY LEVEL 1", "ARTWORK ORIGINAL PC", "BACK TO LIBRARY"]
    _ = try shot(view, "l3-\(number)-menu")
    view.menuRows = nil

    window.contentView = nil
    print("PASS L3 live canvas \(number), 110 ticks, original/2x/toggle restoration")
}

extension SettingsWindow {
    fileprivate func checkExperiencePreset() throws {
        let artwork = SequelArtworkPreference.enabled
        defer { SequelArtworkPreference.setEnabled(artwork) }
        let pane = gameplayPane()
        let host = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 960, height: 480), styleMask: [], backing: .buffered, defer: false)
        host.contentView = pane
        pane.layoutSubtreeIfNeeded()
        let image = pane.bitmapImageRepForCachingDisplay(in: pane.bounds)!
        pane.cacheDisplay(in: pane.bounds, to: image)
        let folder = URL(fileURLWithPath: ".build/variable-speed-tests")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try image.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent("gameplay-settings.png"))
        try assertArtwork(modernControlsCheck?.state == .on && variableSpeedCheck?.state == .on,
            "Modern controls and variable speed are not the defaults")
        useOGSettings()
        try assertArtwork(!current.modernControlsEnabled && !current.variableSpeedEnabled && !current.hdEffectsEnabled
            && !current.confinePointer && !SequelArtworkPreference.enabled && variableSpeedCheck?.isEnabled == false,
            "The OG action did not switch off the new conveniences")
        useModernDefaults()
        try assertArtwork(current.modernControlsEnabled && current.variableSpeedEnabled && current.hdEffectsEnabled
            && current.confinePointer && SequelArtworkPreference.enabled && variableSpeedCheck?.isEnabled == true,
            "Modern defaults failed to restore the conveniences")
        variableSpeedCheck!.performClick(nil)
        try assertArtwork(!current.variableSpeedEnabled && current.modernControlsEnabled,
            "Variable speed cannot be disabled independently")
        variableSpeedCheck!.performClick(nil)
        print("PASS Settings modern/OG presets, individual variable-speed option and default controls")
    }
    fileprivate func checkHDEffectsSetting() throws {
        let pane = videoPane()
        pane.frame = CGRect(x: 0, y: 0, width: 940, height: 480)
        pane.layoutSubtreeIfNeeded()
        try assertArtwork(hdEffectsCheck?.state == .on && hdrFlashCheck?.isEnabled == true,
            "HD effects did not default on in Settings")
        hdEffectsCheck!.performClick(nil)
        try assertArtwork(!current.hdEffectsEnabled && hdrFlashCheck?.isEnabled == false,
            "The Settings master switch did not disable HD effects")
        _ = accessibilityPane()
        reduceMotionCheck!.performClick(nil)
        reduceFlashesCheck!.performClick(nil)
        try assertArtwork(current.reduceMotion && current.reduceFlashes, "Accessibility switches did not apply")
        _ = graphicsPane()
        presetPopUp!.selectItem(at: 1); presetChanged(presetPopUp!)
        try assertArtwork(current.reduceMotion && current.reduceFlashes, "Machine preset erased accessibility choices")
        try assertArtwork(!current.hdEffectsEnabled && hdEffectsCheck?.state == .off,
            "A machine preset discarded old-school mode")
        hdEffectsCheck!.performClick(nil)
        try assertArtwork(current.hdEffectsEnabled && hdrFlashCheck?.isEnabled == true,
            "The Settings master switch did not restore HD effects")
        print("PASS Settings HD switch, dependent explosion control and preserved old-school choice across presets")
    }
    fileprivate func artworkCheckboxForTest() -> NSButton {
        _ = graphicsPane()
        return sequelArtworkCheck!
    }
}

extension Lemmings2PlayWindow {
    fileprivate func checkSettingsArtwork() throws {
        timer?.invalidate(); timer = nil
        setMuted(true)
        let savedProgress = UserDefaults.standard.object(forKey: progressKey)
        defer {
            stop()
            if let savedProgress { UserDefaults.standard.set(savedProgress, forKey: progressKey) }
            else { UserDefaults.standard.removeObject(forKey: progressKey) }
        }
        let host = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 960, height: 720),
                            styleMask: [], backing: .buffered, defer: false)
        attach(to: host)
        campaign = try Lemmings2Campaign(root: root)
        try assertArtwork(campaign.tribe == 1 && campaign.current.style == 1, "New campaigns must start at Beach")
        try campaign.restore(.init(tribe: 0, level: 0, results: [:]))
        try assertArtwork(campaign.tribe == 0, "Existing Classic selections must be preserved")
        try campaign.select(tribe: 1)
        print("PASS Beach default and preserved Classic save selection: \(campaign.current.title)")
        prepareBriefing()
        for page: Screen in [.menu, .map, .briefing, .practice, .preferences, .save, .load] {
            show(page)
            SequelArtworkPreference.setEnabled(false)
            let original = try shot(front, "l2-front-\(page)-pc")
            SequelArtworkPreference.setEnabled(true)
            let upgraded = try shot(front, "l2-front-\(page)-mac")
            SequelArtworkPreference.setEnabled(false)
            let restored = try shot(front, "l2-front-\(page)-restored")
            try assertArtwork(original != upgraded && original == restored,
                              "Front-end artwork did not change and restore on \(page)")
        }
        show(.intro)
        introduction = try Lemmings2Introduction(root: root, font: assets.font)
        for _ in 0..<180 { try introduction?.step() }
        SequelArtworkPreference.setEnabled(false)
        let introPC = try shot(front, "l2-front-intro-pc")
        SequelArtworkPreference.setEnabled(true)
        let introMac = try shot(front, "l2-front-intro-mac")
        SequelArtworkPreference.setEnabled(false)
        try assertArtwork(introPC != introMac && introPC == (try shot(front, "l2-front-intro-restored")),
                          "Intro frame did not change and restore")
        print("PASS live L2 menu, map, briefing, practice, preferences, save/load and intro artwork toggles")
        SequelArtworkPreference.setEnabled(false)
        prepareBriefing(); startLevel()
        try assertArtwork(replaySize == CGSize(width: 640, height: 480),
                          "The first L2 replay must use the attached game view's aspect ratio")
        print("PASS first-run L2 replay dimensions match the attached game view")
        for wasPaused in [false, true] {
            paused = wasPaused
            let tick = game!.tick
            gameplayKeyboard?.controllerAction(.hints)
            try assertArtwork(paused && LevelHintWindow.shared.page != nil, "L2 hints failed to pause")
            lastTime -= 0.1; update()
            try assertArtwork(game!.tick == tick, "L2 ran behind hints")
            GameScreen.shared.dismissAll()
            try assertArtwork(paused == wasPaused, "L2 hints changed the previous pause state")
        }
        print("PASS attached L2 hints pause and restore both running and paused games")
        paused = false
        showLevelHints()
        gameplayKeyboard?.handleInterruption()
        GameScreen.shared.dismissAll()
        try assertArtwork(paused, "Closing sequel hints resumed an interrupted game")
        paused = false
        let resumeAfterHelp = gameplayKeyboard!.pauseForHelp()
        gameplayKeyboard?.handleInterruption(); resumeAfterHelp()
        try assertArtwork(paused, "Closing sequel help resumed an interrupted game")
        paused = false
        let resumeAfterReplay = suspendForReplay()
        gameplayKeyboard?.handleInterruption(); resumeAfterReplay()
        try assertArtwork(paused, "Closing a replay resumed an interrupted sequel")
        paused = false
        gameplayKeyboard?.handleInterruption()
        let interruptedTick = game!.tick
        lastTime -= 0.1; update()
        try assertArtwork(paused && game!.tick == interruptedTick, "Sequel advanced after interruption")

        var requestedSettings = 0
        onShowSettings = { requestedSettings += 1 }
        gameplayKeyboard?.controllerAction(.settings)
        try assertArtwork(requestedSettings == 1, "L2 controller settings is disconnected")
        game?.step()
        gameplayKeyboard?.controllerAction(.retry)
        try assertArtwork(game?.tick == 0 && screen == .playing, "L2 controller retry did not reset the level")
        gameplayKeyboard?.controllerAction(.endRun)
        try assertArtwork(GameScreen.shared.isPresented && game?.tick == 0 && !game!.isComplete,
                          "L2 controller end-run skipped confirmation")
        gameplayKeyboard?.controllerMenuAction(.cancel)
        try assertArtwork(!GameScreen.shared.isPresented, "L2 controller could not cancel end-run")
        onShowSettings = nil
        print("PASS attached L2 controller hints, settings, retry and end-run confirmation")
        for _ in 0..<110 { game?.step() }
        paused = true; selected = 3; refreshGame()
        let before = game!
        let oldX = canvas.cameraX, oldY = canvas.cameraY
        let original = try shot(canvas, "l2-beach-settings-pc")
        let options = ClassicSettingsOptions.available(hasDOSData: true, hasAmigaDisk: false,
            hasMacintoshDisk: false, moduleCount: 0, remixFolders: [], hasSoundtracks: false)
        let settings = SettingsWindow(settings: ClassicSettings(), options: options)
        try settings.checkHDEffectsSetting()
        try settings.checkExperiencePreset()
        let checkbox = settings.artworkCheckboxForTest()
        checkbox.performClick(nil)
        try assertArtwork(checkbox.state == .on && SequelArtworkPreference.enabled,
                          "Settings checkbox did not enable sequel artwork")
        let upgraded = try shot(canvas, "l2-beach-settings-mac")
        try assertArtwork(original != upgraded, "Settings did not refresh the attached L2 player")
        checkbox.performClick(nil)
        let restored = try shot(canvas, "l2-beach-settings-restored")
        try assertArtwork(original == restored, "Settings did not restore the original L2 artwork")
        try assertArtwork(game!.tick == before.tick && game!.lemmings == before.lemmings
            && game!.pixels == before.pixels && game!.solid == before.solid
            && game!.supplies == before.supplies && selected == 3 && paused
            && canvas.cameraX == oldX && canvas.cameraY == oldY,
            "Settings artwork switch changed L2 gameplay or camera state")
        checkbox.performClick(nil)
        let menu = GameMenuPage(title: "Settings")
        GameScreen.shared.present(menu, owner: host)
        paused = false; lastTime -= 0.2; update()
        try assertArtwork(game?.tick == before.tick, "L2 ran behind an in-game menu")
        GameScreen.shared.dismiss(menu)
        fastForward = true; paused = false
        let start = ProcessInfo.processInfo.systemUptime
        for _ in 0..<90 { game?.step(); refreshGame(); captureReplayFrame() }
        let elapsed = ProcessInfo.processInfo.systemUptime - start
        try assertArtwork(runMovie.hasFrames, "The L2 controller did not record replay frames")
        print("L2 benchmark: 90 Mac-artwork ticks, speed trails and movie capture in \(String(format: "%.2f", elapsed))s")
        if let target = game?.lemmings.first(where: \.active) {
            for slot in game!.supplies.indices {
                if game?.assign(slot: slot, to: target.id) == true { break }
            }
        }
        let expectedSkills = zip(game!.configuration.supplies, game!.supplies).reduce(0) { $0 + $1.0 - $1.1 }
        game?.nuke()
        for _ in 0..<2000 where game?.isComplete == false { game?.step() }
        try assertArtwork(game?.isComplete == true, "L2 test run did not finish")
        for page: Screen in [.results, .talisman, .ending] {
            show(page)
            if page == .ending { ending = try Lemmings2Ending(root: root, assets: assets, golden: false) }
            for _ in 0..<1000 {
                if page == .talisman { try award?.step() }
                if page == .ending { try ending?.step() }
            }
            SequelArtworkPreference.setEnabled(false)
            let original = try shot(front, "l2-front-\(page)-pc")
            SequelArtworkPreference.setEnabled(true)
            let upgraded = try shot(front, "l2-front-\(page)-mac")
            SequelArtworkPreference.setEnabled(false)
            let restored = try shot(front, "l2-front-\(page)-restored")
            try assertArtwork(original != upgraded && original == restored,
                              "Results or celebration artwork did not change and restore on \(page)")
        }
        print("PASS native results, talisman and ending use reversible 2x front-end artwork")
        recordArcadeResult(game!)
        try assertArtwork(arcadeReport?.run.saved == game?.saved && arcadeReport?.run.skillCount == expectedSkills,
                          "L2 arcade result lost its rescues or successful skill assignments")
        try assertArtwork(arcadeReport?.trolley?.attempt.run.didWin == game?.didWin
                          && arcadeReport?.trolley?.attempt.run.level.required == 1,
                          "L2 Trolley confused gold medal target with the engine pass condition")
        try assertArtwork(arcadeReport?.trolley?.attempt.run.telemetry?.released == game?.released,
                          "L2 Trolley did not capture released population")
        _ = try shot(ArcadeWindow.shared.arcadeView, "trolley-l2-result")
        let owner = arcadeProfileID, descriptor = arcadeLevel!
        recordArcadeResult(game!)
        try assertArtwork(ArcadeStore.shared.records.stats(level: descriptor, profileID: owner, assisted: false).attempts == 1,
                          "L2 recorded its result twice")
        ArcadeWindow.shared.arcadeView.onRetry?()
        try assertArtwork(screen == .playing && game?.tick == 0 && arcadeReport == nil,
                          "L2 Retry did not start a fresh run immediately")
        try assertArtwork(selected == 3, "L2 result Retry changed the selected skill")
        panelAction(2); game?.step(); key("r")
        try assertArtwork(selected == 2 && game?.tick == 0, "L2 keyboard restart changed the selected skill")
        fanSelected = true; game?.step(); key("r")
        try assertArtwork(fanSelected && selected == 2 && game?.tick == 0,
                          "L2 keyboard restart changed the selected fan")
        fanSelected = false
        print("PASS completed L2 run records actual skill use and rescues exactly once")
        // The real result callback must advance with only the native minimum rescued.
        var floor = [Bool](repeating: false, count: 120 * 80)
        for y in 60..<80 { for x in 0..<120 { floor[y * 120 + x] = true } }
        var minimum = try Lemmings2Runtime(configuration: .init(width: 120, height: 80,
            pixels: floor.map { $0 ? 6 : 0 }, solid: floor, palette: [UInt8](repeating: 255, count: 1024),
            entrance: .init(x: 20, y: 45, width: 1, height: 1), exits: [.init(x: 90, y: 50, width: 16, height: 16)],
            skills: [.builder], supplies: [1], total: campaign.population, timeLimit: 120, releaseInterval: 200,
            terrainMasks: l2masks, levelFingerprint: campaign.current.fingerprint))
        initial = minimum; self.game = minimum; beginReplay()
        for _ in 0..<500 where minimum.saved == 0 { minimum.step() }
        minimum.nuke()
        for _ in 0..<500 where !minimum.isComplete { minimum.step() }
        try assertArtwork(minimum.didWin && minimum.saved == 1, "L2 minimum-clear fixture failed")
        self.game = minimum; show(.results); recordArcadeResult(minimum)
        try assertArtwork(arcadeReport?.trolley?.attempt.goals.stars == 1, "L2 one-star clear was not recognised")
        _ = try shot(ArcadeWindow.shared.arcadeView, "trolley-l2-one-star")
        let oldLevel = campaign.level
        ArcadeWindow.shared.arcadeView.performDefaultResultAction()
        try assertArtwork(campaign.level == oldLevel + 1 && screen == .briefing, "L2 required an optional rescue before advancing")
        print("PASS L2 one-star primary action advances to the next briefing")
        host.contentView = nil
        print("PASS actual Settings checkbox updates the attached Beach player and preserves its state")
    }
}

try Lemmings2PlayWindow(root: l2root).checkSettingsArtwork()

extension Lemmings3PlayWindow {
    fileprivate func checkArcadeResult() throws {
        timer?.invalidate(); timer = nil
        let oldProgress = UserDefaults.standard.object(forKey: progressKey)
        defer {
            stop(); ArcadeWindow.shared.close()
            if let oldProgress { UserDefaults.standard.set(oldProgress, forKey: progressKey) }
            else { UserDefaults.standard.removeObject(forKey: progressKey) }
        }
        canvas.onPanel?(2, 1)
        try assertArtwork(selected == 2, "L3 native panel did not select Jumper")
        let wasPaused = paused
        canvas.onPanel?(7, 1)
        try assertArtwork(paused != wasPaused, "L3 native pause icon is disconnected")
        canvas.onPanel?(6, 1)
        try assertArtwork(fast, "L3 native fast-forward icon is disconnected")
        canvas.onPanel?(8, 1)
        try assertArtwork(!GameScreen.shared.isPresented && !game.isComplete, "L3 end-run needs a double click")
        showGameMenu(); let menuTick = game.tick
        lastTime -= 0.1; update()
        try assertArtwork(canvas.menuRows != nil && game.tick == menuTick, "L3 ran behind its native menu")
        menuAction(0)
        try assertArtwork(canvas.menuRows == nil, "L3 native menu could not resume")
        for wasPaused in [false, true] {
            paused = wasPaused
            let tick = game.tick
            gameplayKeyboard?.controllerAction(.hints)
            try assertArtwork(paused && LevelHintWindow.shared.page != nil, "L3 hints failed to pause")
            lastTime -= 0.1; update()
            try assertArtwork(game.tick == tick, "L3 ran behind hints")
            GameScreen.shared.dismissAll()
            try assertArtwork(paused == wasPaused, "L3 hints changed the previous pause state")
        }
        print("PASS L3 hints pause and restore both running and paused games")
        paused = false
        showLevelHints()
        gameplayKeyboard?.handleInterruption()
        GameScreen.shared.dismissAll()
        try assertArtwork(paused, "Closing sequel hints resumed an interrupted game")
        paused = false
        let resumeAfterHelp = gameplayKeyboard!.pauseForHelp()
        gameplayKeyboard?.handleInterruption(); resumeAfterHelp()
        try assertArtwork(paused, "Closing sequel help resumed an interrupted game")
        paused = false
        let resumeAfterReplay = suspendForReplay()
        gameplayKeyboard?.handleInterruption(); resumeAfterReplay()
        try assertArtwork(paused, "Closing a replay resumed an interrupted sequel")
        paused = false
        gameplayKeyboard?.handleInterruption()
        let interruptedTick = game.tick
        lastTime -= 0.1; update()
        try assertArtwork(paused && game.tick == interruptedTick, "Sequel advanced after interruption")

        var requestedSettings = 0
        onShowSettings = { requestedSettings += 1 }
        gameplayKeyboard?.controllerAction(.settings)
        try assertArtwork(requestedSettings == 1, "L3 controller settings is disconnected")
        let stepTick = game.tick
        gameplayKeyboard?.controllerAction(.step(1))
        try assertArtwork(paused && game.tick == stepTick + 1, "L3 controller forward step did not advance one tick")
        gameplayKeyboard?.controllerAction(.step(-1))
        try assertArtwork(game.tick == stepTick + 1, "Unsupported L3 backward step changed the game")
        gameplayKeyboard?.controllerAction(.retry)
        try assertArtwork(game.tick == 0 && !paused, "L3 controller retry did not reset the level")
        gameplayKeyboard?.controllerAction(.endRun)
        try assertArtwork(GameScreen.shared.isPresented && !game.isComplete,
                          "L3 controller end-run skipped confirmation")
        gameplayKeyboard?.controllerMenuAction(.cancel)
        try assertArtwork(!GameScreen.shared.isPresented, "L3 controller could not cancel end-run")
        onShowSettings = nil
        print("PASS L3 controller hints, settings, forward step, retry and end-run confirmation")
        let windowCount = NSApp.windows.count
        canvas.onPanel?(8, 2)
        func endButton(in view: NSView) -> NSButton? {
            if let button = view as? NSButton, button.title == "End run" { return button }
            return view.subviews.compactMap { endButton(in: $0) }.first
        }
        guard let page = window?.contentView?.subviews.last, let end = endButton(in: page) else {
            try assertArtwork(false, "L3 end-run choice did not appear in the game"); return
        }
        try assertArtwork(NSApp.windows.count == windowCount, "L3 end-run confirmation created a separate window")
        end.performClick(nil)
        try assertArtwork(arcadeReport?.run.saved == 0 && arcadeReport?.run.savedAll == false,
                          "L3 counted untouched reserves as a perfect rescue")
        try assertArtwork(arcadeReport?.stats.attempts == 1, "L3 did not record its completed run")
        try assertArtwork(arcadeReport?.trolley?.attempt.run.telemetry?.released == game.released + game.configuration.extras.count,
                          "L3 Trolley confused reserves or extras with released population")
        try assertArtwork(arcadeReport?.trolley?.attempt.metrics.unreleased == game.reserve,
                          "L3 Trolley counted reserves as deaths")
        _ = try shot(ArcadeWindow.shared.arcadeView, "trolley-l3-result")
        refresh()
        try assertArtwork(arcadeReport?.stats.attempts == 1, "L3 recorded a run again on refresh")
        ArcadeWindow.shared.arcadeView.onRetry?()
        try assertArtwork(arcadeReport == nil && skillAssignments.isEmpty && !recorded && game.tick == 0,
                          "L3 retry retained the old run's records or skill count")
        try assertArtwork(selected == 2, "L3 result Retry changed the selected action")
        // A stopped attempt must also remain stopped when no next level can load.
        var tags = [UInt16](repeating: 0x1000, count: 128 * 64)
        for y in 48..<64 { for x in 0..<128 { tags[y * 128 + x] = 0x20 } }
        let configuration = Lemmings3Runtime.Configuration(width: 128, height: 64, attributes: tags,
            entrance: .init(x: 20, y: 40), exits: [.init(x: 110, y: 46)], total: campaign.population,
            releaseInterval: 200, releaseDelay: 0, sourceLevelReference: campaign.levels[campaign.index].permanentObjectsReference)
        initial = try Lemmings3Runtime(configuration: configuration); game = initial; beginReplay(); recorded = false
        for _ in 0..<500 where game.saved == 0 { game.step() }
        game.abort(); refresh()
        try assertArtwork(game.saved == 1 && arcadeReport?.trolley?.attempt.goals.stars == 1, "L3 minimum-clear fixture failed")
        _ = try shot(ArcadeWindow.shared.arcadeView, "trolley-l3-one-star")
        let completedID = arcadeRunID, completedTick = game.tick
        canAdvance = false
        ArcadeWindow.shared.arcadeView.performDefaultResultAction()
        try assertArtwork(arcadeRunID == completedID && game.tick == completedTick && game.isComplete,
                          "L3 Continue silently restarted a successful run when Next was unavailable")
        canAdvance = true
        let oldLevel = campaign.index
        continueArcadeResult()
        try assertArtwork(campaign.index == oldLevel + 1 && game.tick == 0, "L3 one-star clear did not advance")
        print("PASS L3 one-star advancement and no forced retry at an unavailable next level")
        let menu = GameMenuPage(title: "Records")
        GameScreen.shared.present(menu, owner: window)
        lastTime -= 0.1; update()
        try assertArtwork(game.tick == 0, "L3 ran behind an in-game menu")
        GameScreen.shared.dismiss(menu)
        print("PASS L3 result excludes reserves, records once, and resets statistics on retry")
    }
}
extension Lemmings3PlayWindow {
    fileprivate func checkMusic() throws {
        defer { stop() }
        try assertArtwork(music.library.count == 8, "L3 did not load its eight bundled modules")
        try assertArtwork(music.currentURL?.lastPathComponent.uppercased().hasPrefix("CLASSIC") == true,
            "L3 Classic started another tribe's music")
        var settings = ClassicSettings()
        settings.music = .silent
        setAudioSettings(settings, muted: false)
        try assertArtwork(music.muted, "L3 ignored silent music")
        settings.music = .amigaModules
        setAudioSettings(settings, muted: true)
        try assertArtwork(music.muted, "L3 ignored global mute")
        setAudioSettings(settings, muted: false)
        try assertArtwork(!music.muted, "L3 music did not unmute")
        suspendAudioOutput()
        try assertArtwork(!music.isOutputRunning, "L3 music continued over replay playback")
        try resumeAudioOutput()
        try assertArtwork(music.isOutputRunning, "L3 music did not resume")
        stop(); try resumeAudioOutput()
        try assertArtwork(!music.isOutputRunning, "Resuming audio restarted a closed L3 player")
        print("PASS L3 module playback, silence, global mute, replay suspension and stopped-player safety")
    }
}
try Lemmings3PlayWindow(root: l3root).checkMusic()
try Lemmings3PlayWindow(root: l3root).checkArcadeResult()

private final class L3VoiceCapture: @unchecked Sendable {
    private let lock = NSLock()
    private var events: [(Int, Double, Float)] = []
    func add(_ samples: [Float], _ rate: Double, _ gain: Float) {
        lock.lock(); defer { lock.unlock() }; events.append((samples.count, rate, gain))
    }
    var count: Int { lock.lock(); defer { lock.unlock() }; return events.count }
    var last: (Int, Double, Float)? { lock.lock(); defer { lock.unlock() }; return events.last }
}
extension Lemmings3PlayWindow {
    fileprivate func checkOriginalMedia() throws {
        defer { GameScreen.shared.dismissAll(); stop() }
        var settings = ClassicSettings(); settings.music = .amigaModules; settings.soundVolume = 0.2
        setAudioSettings(settings, muted: false)
        try assertArtwork(Set(Lemmings3SoundBank.filenames.keys).isSubset(of: Set(warningSound.loadedEffects)), "L3 voices were not installed")
        let captures = L3VoiceCapture()
        warningSound.onPlay = { captures.add($0, $1, $2) }
        for _ in 0..<110 { game.step() }
        guard let actor = game.lemmings.first(where: { $0.state == .walking }) else {
            throw SequelDataError.invalid("L3 voice test did not release a walker")
        }
        selected = 1; applyAction(to: actor.id, direction: .right)
        try assertArtwork(captures.count == 1 && captures.last?.0 == 5112 && captures.last?.1 == 14037,
            "Accepted L3 assignment did not supply original voice samples to recording")
        applyAction(to: actor.id, direction: .right)
        try assertArtwork(captures.count == 1, "Rejected L3 assignment played a voice")
        settings.sound = .silent; setAudioSettings(settings, muted: false)
        selected = 0; applyAction(to: actor.id, direction: .right)
        try assertArtwork(captures.count == 1 && warningSound.muted, "L3 silent effects reached replay audio")
        settings.sound = .sampleBank; setAudioSettings(settings, muted: false)
        let tick = game.tick
        showGameMenu()
        try assertArtwork(canvas.menuRows?.count == 9 && canvas.menuRows?[7] == "ORIGINAL MOVIES",
            "Original movies are missing from the L3 menu")
        _ = try shot(canvas, "l3-original-movies-menu")
        menuAction(7)
        if let content = window?.contentView { _ = try shot(content, "l3-original-movie-gallery") }
        playOriginalMovie(.shadow)
        guard let player = originalMovie else { throw SequelDataError.invalid("Original L3 movie did not open") }
        try assertArtwork(player.window === window && !music.isOutputRunning, "Movie changed windows or overlapped game music")
        player.advance(seconds: 0.2)
        _ = try shot(player, "l3-original-movie")
        let frame = player.displayedFrames
        player.togglePause(); player.advance(seconds: 20)
        try assertArtwork(player.displayedFrames == frame && player.paused, "Paused movie advanced")
        player.togglePause()
        for _ in 0..<100 { player.advance(seconds: 0.2); update() }
        try assertArtwork(player.finished && player.failure == nil && player.displayedFrames == 91,
            "Movie failed to finish or displayed its loop frame")
        try assertArtwork(game.tick == tick, "L3 gameplay advanced behind its original movie")
        player.close()
        try assertArtwork(originalMovie == nil && music.isOutputRunning && GameScreen.shared.isPresented,
            "Movie did not return to its gallery and restore audio")
        GameScreen.shared.dismissAll()
        playOriginalMovie(.introduction)
        stop(); try resumeAudioOutput()
        try assertArtwork(originalMovie == nil && !music.isOutputRunning, "Closing L3 leaked its movie or restarted audio")
        print("PASS original L3 voices, recording callback, rejection, mute, movie pause, final frame, gallery return and close lifecycle")
    }
}
try Lemmings3PlayWindow(root: l3root).checkOriginalMedia()

extension Lemmings2PlayWindow {
    fileprivate func checkBundledRescueTarget() throws {
        let proofRoot = sourceRoot.appendingPathComponent("Resources/Trolley")
        guard let proofs = TrolleyBundledProofs.load(from: proofRoot) else {
            throw SequelDataError.invalid("Missing bundled rescue proofs")
        }
        ArcadeStore.shared = ArcadeStore(file: FileManager.default.temporaryDirectory.appendingPathComponent("tribes-proof-\(UUID().uuidString).json"),
                                        bundledProofs: proofs)
        campaign = try Lemmings2Campaign(root: root)
        try campaign.select(tribe: 0)
        prepareBriefing(); startLevel()
        guard let conditions = arcadeLevel?.conditions, let proof = proofs.maximum(for: conditions) else {
            throw SequelDataError.invalid("Live Tribes conditions do not match the bundled proof")
        }
        try assertArtwork(game?.configuration.total == 60 && proof.value == 60,
                          "Classic tribe's full-population rescue target is incorrect")
        try assertArtwork(ArcadeStore.shared.records.trolley.maximum(conditions: conditions, assisted: false) == proof,
                          "Live Tribes level start did not install its verified target")
        print("PASS bundled Tribes proof matches live assets, population, skills and level-start metadata")
    }
}
try Lemmings2PlayWindow(root: testAppRoot.appendingPathComponent("Contents/Resources/Ports/Lemm2")).checkBundledRescueTarget()


extension Lemmings3PlayWindow {
    fileprivate func checkRunRecovery() throws {
        defer { stop() }
        restart()
        for _ in 0..<120 { advanceTick() }
        guard let worker = game.lemmings.first(where: { $0.active }) else {
            throw SequelDataError.invalid("L3 recovery fixture has no active lemming.")
        }
        selected = 1
        applyAction(to: worker.id, direction: .right)
        try assertArtwork(!recoveryInputs.isEmpty, "L3 recovery did not record the assignment")
        for _ in 0..<15 { advanceTick() }
        var checkpoint = RunRecovery(engine: "recovery-test", profileID: arcadeProfileID, runID: arcadeRunID,
            dataSetID: "lemmings3", levelIndex: campaign.index,
            levelFingerprint: arcadeLevel.conditions!.levelFingerprint,
            initialStateHash: recoveryInitialHash, tick: game.tick, events: [], stateHash: L3RunRecovery.stateHash(game),
            usedRewind: false, nukeCount: 0, rewindCount: 0, undoCount: 0, selectedSkill: selected,
            scrollX: Double(canvas.cameraX), scrollY: Double(canvas.cameraY))
        checkpoint.sourcePath = dataRoot.path
        checkpoint.l3 = L3RunRecovery(progress: recoveryProgress!, inputs: recoveryInputs,
            skillAssignments: skillAssignments, toolUses: toolUses)
        let starts = ArcadeStore.shared.records.trolley.starts.count
        let checkpointURL = FileManager.default.temporaryDirectory.appendingPathComponent("sequel-checkpoint-\(UUID()).json")
        defer {
            for suffix in ["", ".backup", ".lock"] { try? FileManager.default.removeItem(atPath: checkpointURL.path + suffix) }
        }
        let checkpointFile = RunRecoveryFile(url: checkpointURL)
        _ = try checkpointFile.load(); try checkpointFile.save(checkpoint)
        guard let decoded = try RunRecoveryFile(url: checkpointURL).load() else { throw RunRecoveryError.invalid }
        let restored = try Lemmings3PlayWindow(root: dataRoot, recovery: decoded, expectedRecoveryEngine: "recovery-test")
        defer { restored.stop() }
        try assertArtwork(restored.paused && restored.arcadeRunID == arcadeRunID &&
            L3RunRecovery.stateHash(restored.game) == L3RunRecovery.stateHash(game), "L3 restored run differs or is not paused")
        try assertArtwork(ArcadeStore.shared.records.trolley.starts.count == starts && restored.skillAssignments == skillAssignments,
            "L3 recovery counted a new attempt or lost skill counts")
        for _ in 0..<40 { advanceTick(); restored.advanceTick() }
        try assertArtwork(L3RunRecovery.stateHash(restored.game) == L3RunRecovery.stateHash(game), "L3 recovery diverged on continuation")
        checkpoint.l3 = L3RunRecovery(progress: recoveryProgress!, inputs: [], skillAssignments: skillAssignments, toolUses: toolUses)
        do {
            _ = try Lemmings3PlayWindow(root: dataRoot, recovery: checkpoint, expectedRecoveryEngine: "recovery-test")
            throw SequelDataError.invalid("L3 recovery accepted a missing journal")
        } catch RunRecoveryError.invalid {}
        let store = ArcadeStore.shared
        let host = store.records.activeProfileID
        let guest = store.addProfile(initials: "PAL", portrait: 2)!
        store.selectProfile(host); store.toggleSessionProfile(guest.id)
        defer { store.endHotSeat() }
        let oldRun = arcadeRunID
        let oldConditions = arcadeLevel.conditions
        let oldProgressKey = progressKey
        try assertArtwork(store.passSessionTurn(after: host), "Sequel hot-seat handoff failed")
        restart()
        try assertArtwork(arcadeProfileID == guest.id && arcadeRunID != oldRun && arcadeLevel.conditions == oldConditions,
            "Sequel hot-seat retry changed the level or kept the old owner")
        try assertArtwork(progressKey == oldProgressKey && store.records.activeProfileID == host,
            "Sequel hot-seat retry changed the shared campaign owner")
        refresh()
        try assertArtwork(canvas.turnBadge.initials == guest.initials && !canvas.turnBadge.isHidden,
            "Hot-seat badge did not follow the new attempt owner")
        _ = try shot(canvas, "hot-seat-" + String(describing: type(of: canvas)))
        _ = store.passSessionTurn(after: guest.id)
        refresh()
        try assertArtwork(canvas.turnBadge.initials == guest.initials, "Badge changed owner during an active attempt")
        store.endHotSeat(); refresh()
        try assertArtwork(canvas.turnBadge.isHidden, "Solo sequel retained hot-seat badge")
        print("PASS L3 hot-seat restart preserves level conditions and campaign ownership with a new guest attempt")
        print("PASS L3 checkpoint round trip, original assets, campaign state, input journal, exact paused restore, continuation and rejected journal")
    }
}
try Lemmings3PlayWindow(root: l3root).checkRunRecovery()


extension Lemmings2PlayWindow {
    fileprivate func checkRunRecovery() throws {
        defer { stop() }
        campaign = try Lemmings2Campaign(root: root)
        try campaign.select(tribe: 0)
        prepareBriefing(); startLevel()
        for _ in 0..<100 { game?.step() }
        guard let worker = game?.lemmings.first(where: { $0.active }), let current = game,
            let slot = current.configuration.skills.indices.first(where: { current.canAssign(slot: $0, to: worker.id) }) else {
            throw SequelDataError.invalid("L2 recovery fixture has no assignable lemming")
        }
        try assertArtwork(performRecoveryInput(.assign(slot: slot, lemming: worker.id)), "L2 assignment failed")
        performRecoveryInput(.fan(x: 100, y: 40, active: true))
        performRecoveryInput(.aim(x: 120, y: 40, held: true))
        for _ in 0..<3 { game?.step() }
        releasePointerInput()
        beforeNukeInputCount = recoveryInputs.count; beforeNuke = game
        nukeCount += 1; performRecoveryInput(.nuke)
        for _ in 0..<2 { game?.step() }
        guard let game, let initial else { throw SequelDataError.invalid("Missing L2 recovery game") }
        var checkpoint = RunRecovery(engine: "recovery-test", profileID: arcadeProfileID, runID: arcadeRunID,
            dataSetID: "lemmings2", levelIndex: campaign.level,
            levelFingerprint: arcadeLevel!.conditions!.levelFingerprint,
            initialStateHash: try L2RunRecovery.stateHash(initial, includeConfiguration: true), tick: game.tick,
            events: [], stateHash: try L2RunRecovery.stateHash(game), usedRewind: usedRewind,
            nukeCount: nukeCount, rewindCount: 0, undoCount: undoCount, selectedSkill: selected,
            scrollX: Double(canvas.cameraX), scrollY: Double(canvas.cameraY))
        checkpoint.sourcePath = root.path
        checkpoint.l2 = L2RunRecovery(progress: campaign.progress, inputs: recoveryInputs)
        let starts = ArcadeStore.shared.records.trolley.starts.count
        let checkpointURL = FileManager.default.temporaryDirectory.appendingPathComponent("sequel-checkpoint-\(UUID()).json")
        defer {
            for suffix in ["", ".backup", ".lock"] { try? FileManager.default.removeItem(atPath: checkpointURL.path + suffix) }
        }
        let checkpointFile = RunRecoveryFile(url: checkpointURL)
        _ = try checkpointFile.load(); try checkpointFile.save(checkpoint)
        guard let decoded = try RunRecoveryFile(url: checkpointURL).load() else { throw RunRecoveryError.invalid }
        let restored = try Lemmings2PlayWindow(root: root, recovery: decoded, expectedRecoveryEngine: "recovery-test")
        defer { restored.stop() }
        try assertArtwork(restored.paused && restored.arcadeRunID == arcadeRunID && restored.beforeNuke != nil,
            "L2 recovery lost pause, identity or nuke undo")
        try assertArtwork(ArcadeStore.shared.records.trolley.starts.count == starts, "L2 recovery counted a new attempt")
        releasePointerInput()
        try assertArtwork(try L2RunRecovery.stateHash(restored.game!) == L2RunRecovery.stateHash(self.game!), "L2 recovered state differs")
        for _ in 0..<25 { self.game?.step(); restored.game?.step() }
        try assertArtwork(try L2RunRecovery.stateHash(restored.game!) == L2RunRecovery.stateHash(self.game!), "L2 recovery diverged on continuation")
        checkpoint.l2 = L2RunRecovery(progress: campaign.progress, inputs: [])
        do {
            _ = try Lemmings2PlayWindow(root: root, recovery: checkpoint, expectedRecoveryEngine: "recovery-test")
            throw SequelDataError.invalid("L2 recovery accepted a missing journal")
        } catch RunRecoveryError.invalid {}
        let store = ArcadeStore.shared
        let host = store.records.activeProfileID
        let guest = store.addProfile(initials: "PAL", portrait: 2)!
        store.selectProfile(host); store.toggleSessionProfile(guest.id)
        defer { store.endHotSeat() }
        let oldRun = arcadeRunID
        let oldConditions = arcadeLevel?.conditions
        let oldProgressKey = progressKey
        try assertArtwork(store.passSessionTurn(after: host), "Sequel hot-seat handoff failed")
        restart()
        try assertArtwork(arcadeProfileID == guest.id && arcadeRunID != oldRun && arcadeLevel?.conditions == oldConditions,
            "Sequel hot-seat retry changed the level or kept the old owner")
        try assertArtwork(progressKey == oldProgressKey && store.records.activeProfileID == host,
            "Sequel hot-seat retry changed the shared campaign owner")
        refreshGame()
        try assertArtwork(canvas.turnBadge.initials == guest.initials && !canvas.turnBadge.isHidden,
            "Hot-seat badge did not follow the new attempt owner")
        _ = try shot(canvas, "hot-seat-" + String(describing: type(of: canvas)))
        _ = store.passSessionTurn(after: guest.id)
        refreshGame()
        try assertArtwork(canvas.turnBadge.initials == guest.initials, "Badge changed owner during an active attempt")
        store.endHotSeat(); refreshGame()
        try assertArtwork(canvas.turnBadge.isHidden, "Solo sequel retained hot-seat badge")
        print("PASS L2 hot-seat restart preserves level conditions and campaign ownership with a new guest attempt")
        print("PASS L2 checkpoint round trip, campaign, assignments, fan/aim/release, nuke undo, exact paused restore, continuation and rejection")
    }
}
try Lemmings2PlayWindow(root: l2root).checkRunRecovery()

// Drive real panel pointer events through each sequel's production callbacks.
@MainActor private func checkSpeedMouse(view: NSView, rect: CGRect, speed: GameSpeedControl) throws {
    speed.variableEnabled = true; speed.newLevel()
    func event(_ type: NSEvent.EventType, _ time: Double, fraction: Double = 0.5, clicks: Int = 1) {
        let p = view.convert(CGPoint(x: rect.minX + rect.width * fraction, y: rect.midY), to: nil)
        let e = NSEvent.mouseEvent(with: type, location: p, modifierFlags: [], timestamp: time,
            windowNumber: view.window?.windowNumber ?? 0, context: nil, eventNumber: 0, clickCount: clicks, pressure: 1)!
        if type == .leftMouseDown { view.mouseDown(with: e) } else { view.mouseUp(with: e) }
    }
    event(.leftMouseDown, 100); event(.leftMouseUp, 100.05)
    try assertArtwork(speed.target == 2, "Sequel mouse toggle did not engage")
    event(.leftMouseDown, 101, fraction: 0.9); event(.leftMouseUp, 101.05)
    try assertArtwork(speed.target == 3, "Sequel speed arrow did not increase")
    let output = URL(fileURLWithPath: ".build/speed-controls")
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
    view.cacheDisplay(in: view.bounds, to: bitmap)
    try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("\(type(of: view)).png"))
    event(.leftMouseDown, 102); event(.leftMouseUp, 102.05)
    event(.leftMouseDown, 102.1, clicks: 2); event(.leftMouseUp, 102.15, clicks: 2)
    try assertArtwork(speed.multiplier == 1, "Sequel double-click restarted speed")
    event(.leftMouseDown, 103); speed.update(at: 105, active: true)
    try assertArtwork(speed.target == 10, "Sequel mouse hold failed")
    event(.leftMouseUp, 105.1)
    try assertArtwork(speed.multiplier == 1, "Sequel hold release did not return to normal")
}
extension Lemmings2PlayWindow {
    fileprivate func checkSpeedMouseControls() throws {
        defer { stop() }
        timer?.invalidate(); timer = nil
        prepareBriefing(); startLevel()
        canvas.variableSpeedEnabled = true
        try checkSpeedMouse(view: canvas, rect: canvas.speedTestRect, speed: speedControl)
        print("PASS L2 native mouse speed controls")
    }
}
extension Lemmings3PlayWindow {
    fileprivate func checkSpeedMouseControls() throws {
        defer { stop() }
        timer?.invalidate(); timer = nil
        canvas.menuRows = nil; canvas.variableSpeedEnabled = true
        let rect = canvas.speedTestRect
        try checkSpeedMouse(view: canvas, rect: rect, speed: speedControl)
        print("PASS L3 native mouse speed controls")
    }
}
try Lemmings2PlayWindow(root: l2root).checkSpeedMouseControls()
try Lemmings3PlayWindow(root: l3root).checkSpeedMouseControls()

extension Lemmings2Canvas { fileprivate var speedTestRect: CGRect { speedRect } }
extension Lemmings3Canvas { fileprivate var speedTestRect: CGRect {
    CGRect(x: screenOrigin.x + 214 * zoom, y: screenOrigin.y + 172 * zoom, width: 35 * zoom, height: 40 * zoom)
} }
