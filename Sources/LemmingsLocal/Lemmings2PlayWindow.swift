import AppKit
import NxlvKit

@MainActor final class Lemmings2PlayWindow: NSWindowController, NSWindowDelegate {
    var onReturnToLibrary: (() -> Void)?
    var onProgressChanged: (() -> Void)?
    var onCampaignCompleted: (() -> Void)?
    private var usesSharedWindow = false

    /// Attach the engine after loading succeeds, so a failed load leaves the current game intact.
    func attach(to host: NSWindow) {
        let content = window?.contentView
        window?.delegate = nil
        window?.contentView = nil
        window = host
        usesSharedWindow = true
        host.contentView = content
        host.makeFirstResponder(content)
    }

    override func close() {
        if usesSharedWindow { onReturnToLibrary?() }
        else { super.close() }
    }

    private enum Screen { case menu, map, briefing, playing, results, preferences, save, load, talisman, ending, message }
    private let canvas = Lemmings2Canvas()
    private let front = Lemmings2MenuCanvas()
    private let assets: Lemmings2FrontEnd
    private let root: URL
    private let sprites: Lemmings2Sprites
    private let masks: Lemmings2TerrainMasks
    private let music = ModuleMusicPlayer()
    private let sounds: Lemmings2SoundPlayer
    private var campaign: Lemmings2Campaign
    private var game: Lemmings2Runtime?
    private var initial: Lemmings2Runtime?
    private var style: Lemmings2Style?
    private var preview: NSImage?
    private var screen: Screen = .menu
    private var previousScreen: Screen = .menu
    private var message = ""
    private var timer: Timer?
    private var lastTime = ProcessInfo.processInfo.systemUptime
    private var accumulator = 0.0
    private var frontTicks = 0
    private var paused = false
    private var fastForward = false
    private var fanSelected = false
    private var selected = 0
    private var nukeGesture = Lemmings2NukeGesture()
    private var selectedSlot = 0
    private var endingPage = 0
    private var hoverTribe: Int?
    private let progressKey: String
    private var level: Lemmings2Level { campaign.current }

    init(root: URL) throws {
        self.root = root
        assets = try Lemmings2FrontEnd(root: root)
        sounds = try Lemmings2SoundPlayer(root: root)
        campaign = try Lemmings2Campaign(root: root)
        sprites = try Lemmings2Sprites(data: Data(contentsOf: root.appendingPathComponent("VLEMMS.DAT")))
        masks = try Lemmings2TerrainMasks(root: root)
        let bundled = (try? BundledGameResources.lemmings2())?.standardizedFileURL == root.standardizedFileURL
        progressKey = "nativeL2Campaign.v1." + (bundled ? "bundled" : root.standardizedFileURL.path)
        if let data = UserDefaults.standard.data(forKey: progressKey),
           let saved = try? JSONDecoder().decode(Lemmings2Campaign.Progress.self, from: data) {
            try? campaign.restore(saved)
        }
        super.init(window: NSWindow(contentRect: NSRect(x: 0, y: 0, width: 960, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false))
        guard let window else { return }
        window.title = "Lemmings 2 — The Tribes"
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 640, height: 502)
        window.contentAspectRatio = NSSize(width: 4, height: 3)
        window.contentView = front
        front.onDraw = { [weak self] in self?.drawFront() }
        front.onClick = { [weak self] x, y in self?.clickFront(x, y) }
        front.onMove = { [weak self] x, y in
            guard let self, self.screen == .map else { return }
            self.hoverTribe = self.tribeAt(x, y); self.front.needsDisplay = true
        }
        front.onKey = { [weak self] key in self?.key(key) }
        canvas.onClick = { [weak self] x, y in self?.assign(x, y) }
        canvas.onPanel = { [weak self] slot, count, time in self?.panelAction(slot, clickCount: count, time: time) }
        canvas.onHover = { [weak self] in self?.refreshGame() }
        canvas.pointers = assets.pointers
        canvas.onKey = { [weak self] key in self?.key(key) }
        let musicRoot = root.deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Music/lemmings_2_music_mod_tsyu")
        music.loadLibrary(at: musicRoot)
        music.setMuted(UserDefaults.standard.bool(forKey: progressKey + ".musicMuted"))
        try? music.start()
        sounds.setMuted(UserDefaults.standard.bool(forKey: progressKey + ".soundsMuted"))
        try sounds.start()
        playMusic("Maintune")
        window.center()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.update() }
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func present() { showWindow(nil); window?.makeKeyAndOrderFront(nil); window?.makeFirstResponder(front) }
    func windowWillClose(_ notification: Notification) {
        stop()
    }
    func stop() {
        timer?.invalidate(); timer = nil; music.stop(); sounds.stop(); persist()
    }
    func setMuted(_ muted: Bool) { music.setMuted(muted); sounds.setMuted(muted) }
    static func savedCompletion(root: URL) -> Int {
        guard var campaign = try? Lemmings2Campaign(root: root) else { return 0 }
        let bundled = (try? BundledGameResources.lemmings2())?.standardizedFileURL == root.standardizedFileURL
        let key = "nativeL2Campaign.v1." + (bundled ? "bundled" : root.standardizedFileURL.path)
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode(Lemmings2Campaign.Progress.self, from: data) {
            try? campaign.restore(saved)
        }
        return campaign.results.count
    }
    private func playMusic(_ name: String) {
        if let index = music.library.firstIndex(where: { $0.deletingPathExtension().lastPathComponent.lowercased() == name.lowercased() }) {
            _ = music.play(index: index)
        }
    }
    private func persist() {
        if let data = try? JSONEncoder().encode(campaign.progress) { UserDefaults.standard.set(data, forKey: progressKey) }
    }
    private func show(_ screen: Screen) {
        nukeGesture.reset()
        if screen != .playing { sounds.silence() }
        self.screen = screen; frontTicks = 0
        accumulator = 0; lastTime = ProcessInfo.processInfo.systemUptime
        let view: NSView = screen == .playing ? canvas : front
        window?.contentView = view; window?.makeFirstResponder(view)
        front.needsDisplay = true
        if screen == .menu { playMusic("Maintune") }
    }
    private func explain(_ text: String, returnTo: Screen) {
        message = text; previousScreen = returnTo; show(.message)
    }
    private func prepareBriefing() {
        do {
            let decoded = try Lemmings2Style(data: Data(contentsOf:
                root.appendingPathComponent("STYLES/\(Lemmings2Campaign.styleNames[campaign.tribe]).DAT")))
            style = decoded
            let terrain = try Lemmings2Terrain(level: level, style: decoded)
            let left = max(0, level.minimumScreenX), top = max(0, level.minimumScreenY)
            let width = min(terrain.image.width - left, level.maximumScreenX + 320 - left)
            let height = min(terrain.image.height - top, level.maximumScreenY + 160 - top)
            guard width > 0, height > 0 else { throw SequelDataError.invalid("Invalid level camera bounds.") }
            let pixels = (0..<height).flatMap { y in
                Array(terrain.image.pixels[((top + y) * terrain.image.width + left)..<((top + y) * terrain.image.width + left + width)])
            }
            preview = front.makeImage(pixels, width: width, height: height, palette: decoded.palette)
            show(.briefing)
        } catch { explain(String(describing: error), returnTo: .menu) }
    }
    private func startLevel() {
        guard let style else { return }
        do {
            let replacement = try Lemmings2Runtime(level: level, style: style, masks: masks, total: campaign.population)
            try canvas.load(level: level, style: style, sprites: sprites)
            game = replacement; initial = replacement
            selected = 0; paused = false; fastForward = false; fanSelected = false; nukeGesture.reset()
            sounds.silence()
            show(.playing)
            playTribeMusic()
            refreshGame()
        } catch { explain(String(describing: error), returnTo: .briefing) }
    }
    private func playTribeMusic() {
        let names = ["classic", "beach", "cavelem", "circus", "egyptian", "highland",
                     "medieval", "outdoor", "polar", "shadow", "space", "sports"]
        playMusic(names[campaign.tribe])
    }
    private func playFromMenu() {
        if let game, !game.isComplete, game.configuration.levelFingerprint == level.fingerprint {
            paused = false; show(.playing); playTribeMusic(); refreshGame()
        } else { prepareBriefing() }
    }
    private func panelAction(_ slot: Int, clickCount: Int = 1, time: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        guard (0..<12).contains(slot), screen == .playing, game?.isComplete == false else { return }
        if let click = Lemmings2SoundRequest.panel(slot: slot) { sounds.play([click]) }
        let confirmedNuke = nukeGesture.click(slot: slot, count: clickCount, time: time, interval: NSEvent.doubleClickInterval)
        if slot < 8 {
            selected = slot; fanSelected = false
        } else {
            switch Lemmings2Control(rawValue: slot) {
            case .pause: paused.toggle(); accumulator = 0
            case .fan: fanSelected.toggle()
            case .nuke:
                if confirmedNuke { game?.nuke(); paused = false; fanSelected = false; accumulator = 0 }
            case .fastForward: fastForward.toggle()
            case nil: break
            }
        }
        refreshGame()
    }
    private func assign(_ x: Int, _ y: Int) {
        nukeGesture.reset()
        if !fanSelected, let lem = game?.target(slot: selected, x: x, y: y) {
            _ = game?.assign(slot: selected, to: lem.id)
        }
        sounds.play(game?.drainSoundEvents() ?? [])
        refreshGame()
    }
    private func refreshGame() {
        guard let game else { return }
        canvas.update(game)
        let palette = Lemmings2Panel.palette(over: game.configuration.palette, phase: frontTicks / 4)
        let hover = canvas.updateSelection(slot: selected, fan: fanSelected, palette: palette)
        var controls: Set<Lemmings2Control> = []
        if paused { controls.insert(.pause) }
        if fastForward { controls.insert(.fastForward) }
        if fanSelected { controls.insert(.fan) }
        let armed = nukeGesture.armedAt.map { ProcessInfo.processInfo.systemUptime - $0 <= NSEvent.doubleClickInterval } ?? false
        if armed || game.isNuking { controls.insert(.nuke) }
        let label = game.isNuking || armed ? "NUKE" : fanSelected ? "FAN" : hover ?? game.configuration.skills[selected].name
        if let rendered = try? assets.panel.render(skills: game.configuration.skills.map(\.rawValue), supplies: game.supplies,
            selected: selected, saved: game.saved, remaining: game.lemmings.filter(\.active).count,
            seconds: game.remainingSeconds, label: label, palette: palette, highlightedControls: controls) {
            canvas.setPanel(rendered)
        }
        canvas.setAccessibilityLabel("Lemmings 2. \(game.configuration.skills[selected].name) selected. \(label). \(paused ? "Paused." : "Running.") \(game.isNuking ? "Nuke active." : "") \(game.released) released, \(game.saved) saved.")
    }
    private func update() {
        let now = ProcessInfo.processInfo.systemUptime
        let elapsed = min(0.25, now - lastTime); lastTime = now
        frontTicks += 1
        if screen != .playing {
            if (screen == .map || screen == .results) && frontTicks.isMultiple(of: 4) { front.needsDisplay = true }
            return
        }
        guard !paused, var game, !game.isComplete else {
            if frontTicks.isMultiple(of: 4) { refreshGame() }
            return
        }
        let previousTick = game.tick
        // Original fast-forward performs three physics updates per displayed frame.
        accumulator += elapsed * (fastForward ? 3 : 1)
        while accumulator >= 1 / Lemmings2Runtime.ticksPerSecond && !game.isComplete {
            accumulator -= 1 / Lemmings2Runtime.ticksPerSecond; game.step()
        }
        guard game.tick != previousTick else {
            if frontTicks.isMultiple(of: 4) { refreshGame() }
            return
        }
        sounds.play(game.drainSoundEvents())
        self.game = game; refreshGame()
        if game.isComplete {
            _ = campaign.record(game); persist(); onProgressChanged?(); show(.results)
        }
    }
    private func key(_ key: String) {
        if key == "\u{1b}" {
            if screen == .playing { paused = true; show(.menu) }
            else if screen == .message { show(previousScreen) }
            else { show(.menu) }
            return
        }
        if screen == .playing {
            if let number = Int(key), (1...8).contains(number) { panelAction(number - 1) }
            else if key == " " || key.lowercased() == "p" { panelAction(8) }
            else if key.lowercased() == "f" { panelAction(11) }
            else if key.lowercased() == "r", let initial {
                game = initial; canvas.resetCamera(level: level)
                paused = false; fastForward = false; fanSelected = false; nukeGesture.reset(); sounds.silence()
                accumulator = 0; refreshGame()
            }
        } else if key == "\r" || key == " " {
            if screen == .menu { playFromMenu() }
            else if screen == .briefing { startLevel() }
            else if screen == .results { continueResult() }
            else if screen == .message { show(previousScreen) }
        } else if screen == .briefing && (key == "left" || key == "right") {
            changeLevel(key == "left" ? -1 : 1)
        }
    }
    private func changeLevel(_ direction: Int) {
        if (try? campaign.select(tribe: campaign.tribe, level: campaign.level + direction)) != nil { prepareBriefing() }
    }
    private func continueResult() {
        guard let game else { return }
        if game.didWin && campaign.level == 9 { show(.talisman) }
        else if campaign.advance(after: game) { persist(); prepareBriefing() }
        else { prepareBriefing() }
    }
    // Region centres follow the original map artwork; the nearest tribe owns
    // the intervening land. The ark has its own hit region at the top.
    private let tribePoints = [(82,42), (82,153), (135,50), (254,81), (166,145), (105,76),
                              (279,166), (218,151), (168,54), (255,42), (78,91), (78,123)]
    private func tribeAt(_ x: Int, _ y: Int) -> Int? {
        guard (18..<306).contains(x), (15..<181).contains(y) else { return nil }
        return tribePoints.indices.min { a, b in
            let p = tribePoints[a], q = tribePoints[b]
            return (p.0-x)*(p.0-x)+(p.1-y)*(p.1-y) < (q.0-x)*(q.0-x)+(q.1-y)*(q.1-y)
        }
    }
    private func clickFront(_ x: Int, _ y: Int) {
        func inside(_ a: Int, _ b: Int, _ w: Int, _ h: Int) -> Bool { x >= a && x < a+w && y >= b && y < b+h }
        switch screen {
        case .menu:
            if inside(10, 125, 70, 22) { playFromMenu() }
            else if inside(10, 150, 70, 22) { show(.map) }
            else if inside(10, 175, 70, 22) { show(.preferences) }
            else if inside(240, 125, 70, 22) { show(.load) }
            else if inside(240, 150, 70, 22) { show(.save) }
            else if inside(240, 175, 70, 22) { close() }
            else if inside(120, 150, 70, 22) {
                explain("The original introduction still needs its native animation interpreter.", returnTo: .menu)
            } else if inside(100, 175, 110, 22) {
                explain("Practice needs the remaining tribe skills before it can be played.", returnTo: .menu)
            }
        case .map:
            if inside(106, 5, 40, 20) { show(.talisman) }
            else if let tribe = tribeAt(x, y) {
                try? campaign.select(tribe: tribe); persist(); prepareBriefing()
            }
        case .briefing:
            if inside(148, 120, 40, 31) { changeLevel(-1) }
            else if inside(273, 120, 40, 31) { changeLevel(1) }
            else { startLevel() }
        case .results:
            if inside(0, 178, 100, 22) { prepareBriefing() }
            else if inside(220, 178, 100, 22) { show(.menu) }
            else { continueResult() }
        case .preferences:
            if inside(25, 110, 100, 24) {
                music.setMuted(!music.muted)
                UserDefaults.standard.set(music.muted, forKey: progressKey + ".musicMuted")
                front.needsDisplay = true
            } else if inside(160, 110, 135, 24) {
                sounds.setMuted(!sounds.muted)
                UserDefaults.standard.set(sounds.muted, forKey: progressKey + ".soundsMuted")
                if let click = Lemmings2SoundRequest.panel(slot: 0) { sounds.play([click]) }
                front.needsDisplay = true
            } else if y >= 180 { show(.menu) }
        case .save, .load:
            if y >= 178 {
                if x >= 160 { show(.menu); return }
                let key = progressKey + ".slot.\(selectedSlot)"
                if screen == .save {
                    if let data = try? JSONEncoder().encode(campaign.progress) {
                        UserDefaults.standard.set(data, forKey: key); show(.menu)
                    }
                } else if let data = UserDefaults.standard.data(forKey: key) {
                    do {
                        try campaign.restore(JSONDecoder().decode(Lemmings2Campaign.Progress.self, from: data))
                        game = nil; initial = nil
                        persist(); prepareBriefing()
                    } catch { explain("This saved game cannot be loaded.", returnTo: .load) }
                }
            } else if (40..<168).contains(y) { selectedSlot = (y - 40) / 16; front.needsDisplay = true }
        case .talisman:
            if campaign.isComplete { endingPage = 0; playMusic("endtune"); show(.ending) }
            else { show(.map) }
        case .ending:
            endingPage += 1
            if endingPage == 5 {
                if let onCampaignCompleted { onCampaignCompleted() } else { show(.menu) }
            } else { front.needsDisplay = true }
        case .message: show(previousScreen)
        case .playing: break
        }
    }

    private func drawFront() {
        func bank(_ name: String) -> Lemmings2FrontEnd.Bank { assets.banks[name]! }
        func palette(_ name: String) -> [UInt8] { bank(name).palettes[1] }
        func picture(_ name: String, _ pal: [UInt8]) {
            if let pixels = assets.pictures[name] { front.draw(pixels, width: 320, height: 200, palette: pal, x: 0, y: 0) }
        }
        func sprite(_ name: String, _ id: Int, _ x: Int, _ y: Int, frame: Int = 0, pal: [UInt8]? = nil) {
            let frames = bank(name).sprites[id], f = frames[max(0, frame) % frames.count]
            front.draw(f.pixels, width: f.width, height: f.height, palette: pal ?? palette(name),
                       x: x + f.x, y: y + f.y, opaque: f.opaque)
        }
        func text(_ string: String, _ x: Int, _ y: Int, _ name: String = "INFO", centered: Bool = false) {
            front.text(string, font: assets.font, palette: palette(name), x: centered ? x - assets.font.width(string) / 2 : x, y: y)
        }
        switch screen {
        case .menu: picture("MENU", palette("MENU"))
        case .map:
            picture("MAP", palette("MAP"))
            for (id, x, y) in [(2,232,59),(4,117,144),(3,288,141),(5,44,151),(6,47,104)] {
                sprite("MAP", id, x, y, frame: frontTicks / 6)
            }
            text(Lemmings2Campaign.tribeNames[hoverTribe ?? campaign.tribe], 165, 183, "MAP", centered: true)
        case .briefing:
            picture("ROCKWALL", palette("INFO"))
            // INFO.GAL uses the left 140 pixels for eight 25-pixel skill rows.
            for i in 0..<8 {
                let skill = level.skills[i].identifier
                sprite("INFO", 0, 0, i * 25)
                if (1...51).contains(skill) { sprite("INFO", 7, 0, i * 25, frame: skill - 1) }
                text(String(format: "%02d", level.skills[i].count), 32, i * 25 + 2)
                if (1...51).contains(skill) { text(bank("INFO").strings[skill - 1], 32, i * 25 + 13) }
            }
            sprite("INFO", 8 + campaign.tribe, 150, 10, pal: bank("INFO").palettes[2 + campaign.tribe])
            sprite("INFO", 3, 144, 64)
            if let preview {
                let scale = min(160 / preview.size.width, 64 / preview.size.height)
                let width = preview.size.width * scale, height = preview.size.height * scale
                front.drawImage(preview, rect: NSRect(x: 232 - width / 2, y: 99 - height / 2, width: width, height: height))
            }
            if campaign.level > 0 { sprite("INFO", 5, 152, 127) }
            if campaign.level < campaign.unlockedLevel(in: campaign.tribe) { sprite("INFO", 4, 279, 127) }
            text("Level \(campaign.level + 1)", 231, 151, centered: true)
            front.wrappedText(level.title, font: assets.font, palette: palette("INFO"), x: 145, y: 163, width: 173)
            text("\(campaign.population) Lemmings", 231, 176, centered: true)
            text(String(format: "TIME %d:%02d", level.timeLimitSeconds / 60, level.timeLimitSeconds % 60), 231, 187, centered: true)
        case .results:
            picture("ROCKWALL", palette("MEDALS"))
            if let game {
                let medal = Lemmings2Campaign.medal(saved: game.saved, total: game.configuration.total, allowedLosses: level.allowedLossesForGold)
                sprite("MEDALS", 2, 30, 25)
                if medal != .none {
                    let locations = [(0,0),(43,64),(85,54),(64,44)]
                    let p = locations[medal.rawValue]
                    sprite("MEDALS", medal == .gold ? 3 : medal == .silver ? 4 : 5, p.0, p.1, frame: min(20, frontTicks / 4))
                }
                text("You saved \(game.saved) lemmings", 160, 8, "MEDALS", centered: true)
                text(medal == .none ? "Oh dear!" : medal.name + " medal", 220, 42, "MEDALS", centered: true)
                front.wrappedText(game.didWin ? "Click to continue. Your survivors will go on to the next level."
                    : bank("MEDALS").strings[4], font: assets.font, palette: palette("MEDALS"), x: 135, y: 70, width: 170)
                text("Retry", 35, 182, "MEDALS", centered: true)
                text("Continue", 160, 182, "MEDALS", centered: true)
                text("Menu", 285, 182, "MEDALS", centered: true)
            }
        case .preferences:
            picture("ROCKWALL", palette("PREFS"))
            text("Control Method", 160, 24, "PREFS", centered: true)
            text("Mouse", 160, 44, "PREFS", centered: true)
            text("Music", 52, 124, "PREFS")
            sprite("PREFS", music.muted ? 5 : 6, 38, 114)
            text("Sound FX", 189, 124, "PREFS")
            sprite("PREFS", sounds.muted ? 5 : 6, 175, 114)
            text("OK", 160, 184, "PREFS", centered: true)
        case .load, .save:
            picture("ROCKWALL", palette("LOAD"))
            text(screen == .save ? "Save Game" : "Select a game to load", 160, 12, "LOAD", centered: true)
            for i in 0..<8 {
                let key = progressKey + ".slot.\(i)"
                let saved = UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode(Lemmings2Campaign.Progress.self, from: $0) }
                let name = saved.map { "\(Lemmings2Campaign.tribeNames[$0.tribe]) - Level \($0.level + 1)" } ?? "<Unsaved Position>"
                text("\(i == selectedSlot ? ">" : " ") \(i + 1). \(name)", 34, 40 + i * 16, "LOAD")
            }
            text(screen == .save ? "Save" : "Load", 80, 184, "LOAD", centered: true)
            text("Cancel", 240, 184, "LOAD", centered: true)
        case .talisman:
            picture("AWARD", palette("AWARD"))
            for tribe in 0..<12 where campaign.tribeMedal(tribe) != .none {
                sprite("AWARD", 0, 0, 0, frame: tribe)
            }
            text(campaign.isComplete ? "The tribes are saved!" : "Click to return to the map", 160, 184, "AWARD", centered: true)
        case .ending:
            picture("END\(endingPage + 1)", palette("END"))
            text("Click to Continue", 160, 184, "END", centered: true)
        case .message:
            picture("ROCKWALL", palette("INFO"))
            front.wrappedText(message, font: assets.font, palette: palette("INFO"), x: 24, y: 55, width: 272)
            text("Click to return", 160, 182, centered: true)
        case .playing: break
        }
    }
}

@MainActor private final class Lemmings2MenuCanvas: NSView {
    var onDraw: (() -> Void)?
    var onClick: ((Int, Int) -> Void)?
    var onMove: ((Int, Int) -> Void)?
    var onKey: ((String) -> Void)?
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    private var zoom: CGFloat { max(0.1, min(bounds.width / 320, bounds.height / 240)) }
    private var origin: NSPoint { NSPoint(x: (bounds.width - 320 * zoom) / 2, y: (bounds.height - 240 * zoom) / 2) }
    override func updateTrackingAreas() {
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect], owner: self))
        super.updateTrackingAreas()
    }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill(); bounds.fill()
        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: origin.x, yBy: origin.y); transform.scaleX(by: zoom, yBy: zoom * 1.2); transform.concat()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 320, height: 200)).addClip()
        onDraw?()
        NSGraphicsContext.restoreGraphicsState()
    }
    func makeImage(_ pixels: [UInt8], width: Int, height: Int, palette: [UInt8], opaque: [Bool]? = nil) -> NSImage {
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        for i in pixels.indices {
            for c in 0..<3 { rgba[i * 4 + c] = palette[Int(pixels[i]) * 4 + c] }
            rgba[i * 4 + 3] = (opaque?[i] ?? true) ? 255 : 0
        }
        let cg = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
            provider: CGDataProvider(data: Data(rgba) as CFData)!, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        return NSImage(cgImage: cg, size: NSSize(width: width, height: height))
    }
    func drawImage(_ image: NSImage, rect: NSRect) {
        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true,
                   hints: [.interpolation: NSImageInterpolation.none.rawValue])
    }
    func draw(_ pixels: [UInt8], width: Int, height: Int, palette: [UInt8], x: Int, y: Int, opaque: [Bool]? = nil) {
        drawImage(makeImage(pixels, width: width, height: height, palette: palette, opaque: opaque),
                  rect: NSRect(x: x, y: y, width: width, height: height))
    }
    func text(_ text: String, font: Lemmings2FrontEndFont, palette: [UInt8], x: Int, y: Int) {
        var cursor = x
        for byte in text.utf8 where (32..<123).contains(byte) {
            let glyph = font.glyphs[Int(byte) - 32]
            draw(glyph, width: 16, height: 11, palette: palette, x: cursor, y: y, opaque: glyph.map { $0 != 0 })
            cursor += font.advances[Int(byte) - 32]
        }
    }
    func wrappedText(_ text: String, font: Lemmings2FrontEndFont, palette: [UInt8], x: Int, y: Int, width: Int) {
        var line = "", row = y
        for word in text.split(whereSeparator: { $0.isWhitespace }) {
            let next = line.isEmpty ? String(word) : line + " " + word
            if font.width(next) > width && !line.isEmpty {
                self.text(line, font: font, palette: palette, x: x, y: row); row += 13; line = String(word)
            } else { line = next }
        }
        self.text(line, font: font, palette: palette, x: x, y: row)
    }
    private func point(_ event: NSEvent) -> (Int, Int)? {
        let p = convert(event.locationInWindow, from: nil)
        let x = (p.x - origin.x) / zoom, y = (p.y - origin.y) / (zoom * 1.2)
        return x >= 0 && x < 320 && y >= 0 && y < 200 ? (Int(x), Int(y)) : nil
    }
    override func mouseDown(with event: NSEvent) { if let p = point(event) { onClick?(p.0, p.1) } }
    override func mouseMoved(with event: NSEvent) { if let p = point(event) { onMove?(p.0, p.1) } }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 123 { onKey?("left") }
        else if event.keyCode == 124 { onKey?("right") }
        else if let text = event.characters { onKey?(text) }
    }
}

@MainActor private final class Lemmings2Canvas: NSView {
    var onClick: ((Int, Int) -> Void)?
    var onPanel: ((Int, Int, TimeInterval) -> Void)?
    var onHover: (() -> Void)?
    var onKey: ((String) -> Void)?
    var pointers: Lemmings2Pointers?
    private var cursorFrames: [NSCursor] = []
    private var cursorZoom: CGFloat = 0
    private var pointerFrame = 0
    var cameraX: CGFloat = 0
    var cameraY: CGFloat = 0
    private var cameraBounds: (left: CGFloat, top: CGFloat, right: CGFloat, bottom: CGFloat) = (0, 0, 0, 0)
    private var game: Lemmings2Runtime?
    private var terrain: NSImage?
    private var terrainRevision: Int?
    private var panel: NSImage?
    private var sprites: [String: [(image: NSImage, x: Int, y: Int)]] = [:]
    private var objects: [(x: Int, y: Int, entrance: Bool, animated: Bool,
                           frames: [(image: NSImage, x: Int, y: Int)])] = []
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    private var zoom: CGFloat { max(0.1, min(bounds.width / 320, bounds.height / 240)) }
    private var origin: NSPoint { NSPoint(x: (bounds.width - 320 * zoom) / 2, y: (bounds.height - 240 * zoom) / 2) }

    override func updateTrackingAreas() {
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseMoved, .mouseEnteredAndExited, .cursorUpdate, .activeInKeyWindow, .inVisibleRect], owner: self))
        super.updateTrackingAreas()
    }
    override func mouseMoved(with event: NSEvent) { onHover?() }
    override func mouseEntered(with event: NSEvent) { onHover?() }
    override func mouseExited(with event: NSEvent) { onHover?(); NSCursor.arrow.set() }
    override func cursorUpdate(with event: NSEvent) {
        if cursorFrames.indices.contains(pointerFrame) { cursorFrames[pointerFrame].set() }
    }
    override func resetCursorRects() {
        if cursorFrames.indices.contains(pointerFrame) { addCursorRect(bounds, cursor: cursorFrames[pointerFrame]) }
    }
    func updateSelection(slot: Int, fan: Bool, palette: [UInt8]) -> String? {
        if let pointers, cursorFrames.isEmpty || zoom != cursorZoom {
            cursorZoom = zoom
            cursorFrames = pointers.frames.map { pixels in
                let original = image(width: 16, height: 16, pixels: pixels, palette: palette, opaque: pixels.map { $0 != 0 })
                let size = NSSize(width: 16 * zoom, height: 16 * zoom * 1.2)
                let scaled = NSImage(size: size, flipped: true) { rect in
                    original.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true,
                                  hints: [.interpolation: NSImageInterpolation.none.rawValue])
                    return true
                }
                return NSCursor(image: scaled, hotSpot: NSPoint(x: 8 * zoom, y: 8 * zoom * 1.2))
            }
            window?.invalidateCursorRects(for: self)
        }
        var frame = 0, label: String?
        if let window, let game {
            let point = convert(window.mouseLocationOutsideOfEventStream, from: nil)
            let x = (point.x - origin.x) / zoom, y = (point.y - origin.y) / (zoom * 1.2)
            if (0..<320).contains(x), (0..<160).contains(y) {
                if fan { frame = 2 }
                else if let target = game.target(slot: slot, x: Int(x + cameraX), y: Int(y + cameraY)) {
                    frame = game.canAssign(slot: slot, to: target.id) ? 1 : 0
                    switch target.state {
                    case .walking: label = "WALKER"
                    case .falling: label = "FALLER"
                    case .floating: label = "FLOATER"
                    case .climbing: label = "CLIMBER"
                    case .building: label = "BUILDER"
                    case .bashing: label = "BASHER"
                    case .mining: label = "MINER"
                    case .digging: label = "DIGGER"
                    case .blocking: label = "BLOCKER"
                    case .stacking: label = "STACKER"
                    case .platforming: label = "PLATFORMER"
                    default: label = "LEMMING"
                    }
                }
            }
            if frame != pointerFrame {
                pointerFrame = frame; window.invalidateCursorRects(for: self)
            }
            if window.isKeyWindow, bounds.contains(point), cursorFrames.indices.contains(frame) { cursorFrames[frame].set() }
        }
        return label
    }

    private func image(width: Int, height: Int, pixels: [UInt8], palette: [UInt8], opaque: [Bool]? = nil) -> NSImage {
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        for index in pixels.indices {
            let colour = Int(pixels[index]) * 4
            rgba[index * 4] = palette[colour]; rgba[index * 4 + 1] = palette[colour + 1]
            rgba[index * 4 + 2] = palette[colour + 2]
            rgba[index * 4 + 3] = (opaque?[index] ?? true) ? 255 : 0
        }
        let provider = CGDataProvider(data: Data(rgba) as CFData)!
        let cg = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                         bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                         bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                         provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        return NSImage(cgImage: cg, size: NSSize(width: width, height: height))
    }
    func load(level: Lemmings2Level, style: Lemmings2Style, sprites bank: Lemmings2Sprites) throws {
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        let resolved = try Lemmings2Objects(level: level, style: style)
        terrainRevision = nil
        objects = []
        for (name, frames) in bank.animations {
            sprites[name] = frames.map { frame in
                (image(width: frame.width, height: frame.height, pixels: frame.pixels, palette: style.palette, opaque: frame.opaque), frame.x, frame.y)
            }
        }
        for part in resolved.parts where !part.frames.isEmpty {
                let frames = part.frames.map {
                    (image: image(width: $0.width, height: $0.height, pixels: $0.pixels, palette: style.palette,
                          opaque: $0.opaque), x: $0.x, y: $0.y)
                }
                objects.append((part.x, part.y, part.type == 2, part.component.graphicsFlags & 0x10 != 0, frames))
        }
        resetCamera(level: level)
    }
    func resetCamera(level: Lemmings2Level) {
        cameraBounds = (CGFloat(level.minimumScreenX), CGFloat(level.minimumScreenY),
                        CGFloat(level.maximumScreenX), CGFloat(level.maximumScreenY))
        cameraX = min(cameraBounds.right, max(cameraBounds.left, CGFloat(level.screenX)))
        cameraY = min(cameraBounds.bottom, max(cameraBounds.top, CGFloat(level.screenY)))
    }
    func update(_ game: Lemmings2Runtime) {
        if terrainRevision != game.terrainRevision || game.tick < (self.game?.tick ?? 0) {
            terrain = image(width: game.configuration.width, height: game.configuration.height,
                            pixels: game.pixels, palette: game.configuration.palette)
            terrainRevision = game.terrainRevision
        }
        self.game = game
        needsDisplay = true
    }
    func setPanel(_ panel: SequelIndexedImage) {
        self.panel = image(width: panel.width, height: panel.height, pixels: panel.pixels, palette: panel.palette)
        needsDisplay = true
    }
    private func drawImage(_ image: NSImage, x: CGFloat, y: CGFloat, mirrored: Bool = false) {
        let rect = NSRect(x: origin.x + (x - cameraX) * zoom, y: origin.y + (y - cameraY) * zoom * 1.2,
                          width: image.size.width * zoom, height: image.size.height * zoom * 1.2)
        NSGraphicsContext.saveGraphicsState()
        if mirrored {
            let transform = NSAffineTransform()
            transform.translateX(by: rect.midX * 2, yBy: 0); transform.scaleX(by: -1, yBy: 1); transform.concat()
        }
        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true,
                   hints: [.interpolation: NSImageInterpolation.none.rawValue])
        NSGraphicsContext.restoreGraphicsState()
    }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill(); bounds.fill()
        guard let game, let terrain else { return }
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: NSRect(x: origin.x, y: origin.y, width: 320 * zoom, height: 192 * zoom)).addClip()
        drawImage(terrain, x: 0, y: 0)
        for object in objects where !object.frames.isEmpty {
            let frame = object.entrance ? min(object.frames.count - 1, max(0, game.tick - 20))
                : (object.animated ? game.tick / 2 % object.frames.count : 0)
            let sprite = object.frames[frame]
            drawImage(sprite.image, x: CGFloat(object.x + sprite.x), y: CGFloat(object.y + sprite.y))
        }
        for lem in game.lemmings where lem.active {
            let name: String
            let offsetX: Int, offsetY: Int, phase: Int
            var directional = true
            var mirrored = false
            // PROCESS 7726 state geometry plus each native frame's L2VL
            // anchor. Cropped frames must not move the feet between frames.
            switch lem.state {
            case .digging:
                name = "LM11"; offsetX = -8; offsetY = -12; phase = lem.age % 16; directional = false
            case .climbing:
                name = "LM12"; offsetX = -8; offsetY = -13; phase = lem.age % 8
            case .building:
                name = "LM13"; offsetX = -8; offsetY = -13; phase = lem.age % 16
            case .stacking:
                name = "LM1F"; offsetX = lem.direction > 0 && (lem.work < 12 || lem.age >= 12) ? -9 : -8
                offsetY = lem.age % 16 >= 11 ? -9 : -11
                phase = lem.age % 32; directional = false
            case .platforming:
                name = "LM22"; offsetX = lem.direction > 0 ? -9 : -6; offsetY = -13; phase = lem.age
            case .platformerShrugging:
                name = "LM7C"; offsetX = lem.direction > 0 ? -9 : -7; offsetY = -13; phase = lem.age % 10
            case .bashing:
                name = "LM14"; offsetX = -7; offsetY = -10; phase = lem.age % 32
            case .mining:
                name = "LM15"; offsetX = -7; offsetY = -13; phase = lem.age % 24
            case .floating:
                name = "LM16"; offsetX = -7; offsetY = -16
                let frames = [1, 2, 3, 5, 5, 5, 5, 5, 5, 6, 7, 7, 6, 5, 4, 4]
                phase = frames[lem.age < 16 ? lem.age : 8 + (lem.age - 16) % 8]
            case .blocking:
                name = "LM33"; offsetX = -7; offsetY = -10; phase = lem.age % 16; directional = false
            case .falling:
                name = "LM40"; offsetX = -8; offsetY = -10; phase = lem.age % 4
            case .shrugging:
                name = "LM7B"; offsetX = lem.direction > 0 ? -9 : -8; offsetY = -13; phase = lem.age % 8
            case .exploding:
                guard lem.age < 16 else { continue } // Particle effects remain separate work.
                name = "LM18"; offsetX = -7; offsetY = -10; phase = lem.age; directional = false
            default:
                // The measured LM5C walking subset is still used until the
                // original optimized walker and exit drawing are reproduced.
                name = "LM5C"; offsetX = -9; offsetY = -10; phase = 6 + lem.age % 8
                directional = false; mirrored = lem.direction < 0
            }
            guard let frames = sprites[name], !frames.isEmpty else { continue }
            let index = phase + (directional && lem.direction < 0 ? frames.count / 2 : 0)
            guard frames.indices.contains(index) else { continue }
            let sprite = frames[index]
            drawImage(sprite.image, x: CGFloat(lem.x + offsetX + sprite.x), y: CGFloat(lem.y + offsetY + sprite.y), mirrored: mirrored)
            if let ticks = lem.bombTicks {
                let text = String(max(1, (ticks + 14) / 15))
                text.draw(at: NSPoint(x: origin.x + (CGFloat(lem.x) - cameraX) * zoom, y: origin.y + (CGFloat(lem.y - 16) - cameraY) * zoom * 1.2),
                          withAttributes: [.foregroundColor: NSColor.white, .font: NSFont.boldSystemFont(ofSize: 12)])
            }
        }
        NSGraphicsContext.restoreGraphicsState()
        panel?.draw(in: NSRect(x: origin.x, y: origin.y + 192 * zoom, width: 320 * zoom, height: 48 * zoom),
                    from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true,
                    hints: [.interpolation: NSImageInterpolation.none.rawValue])
    }
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let p = convert(event.locationInWindow, from: nil)
        let x = (p.x - origin.x) / zoom
        let y = (p.y - origin.y) / (zoom * 1.2)
        guard x >= 0, x < 320, y >= 0, y < 200 else { return }
        if y < 160 { onClick?(Int(x + cameraX), Int(y + cameraY)) }
        else if let slot = Lemmings2Control.slot(x: Int(x), y: Int(y)) { onPanel?(slot, event.clickCount, event.timestamp) }
    }
    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 123: pan(x: -24, y: 0)
        case 124: pan(x: 24, y: 0)
        case 125: pan(x: 0, y: 16)
        case 126: pan(x: 0, y: -16)
        default: if let text = event.characters { onKey?(text) }
        }
    }
    private func pan(x: CGFloat, y: CGFloat) {
        guard let game else { return }
        cameraX = min(min(cameraBounds.right, CGFloat(max(0, game.configuration.width - 320))), max(cameraBounds.left, cameraX + x))
        cameraY = min(min(cameraBounds.bottom, CGFloat(max(0, game.configuration.height - 160))), max(cameraBounds.top, cameraY + y))
        needsDisplay = true
        onHover?()
    }
    override func scrollWheel(with event: NSEvent) {
        let horizontal = event.modifierFlags.contains(.shift) ? event.scrollingDeltaY : event.scrollingDeltaX
        pan(x: horizontal * 4, y: event.modifierFlags.contains(.shift) ? 0 : event.scrollingDeltaY * 4)
    }
}
