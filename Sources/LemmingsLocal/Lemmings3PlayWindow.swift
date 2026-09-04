import AppKit
import NxlvKit

@MainActor final class Lemmings3PlayWindow: NSWindowController, NSWindowDelegate {
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
        campaignFinished = Self.savedCompletion(root: dataRoot) == 90
        host.contentView = content
        host.makeFirstResponder(content)
    }

    override func close() {
        if usesSharedWindow { onReturnToLibrary?() }
        else { super.close() }
    }

    private var game: Lemmings3Runtime
    private var initial: Lemmings3Runtime
    private let dataRoot: URL
    private var style: Lemmings3Style
    private var sprites: Lemmings3Sprites
    private var campaign: Lemmings3ClassicCampaign
    private var availability: [String?]
    private var progressKey: String
    private var recorded = false
    private var campaignFinished = false
    private let levels = NSPopUpButton()
    private let tribes = NSPopUpButton()
    private let direction = NSPopUpButton()
    private let next = NSButton(title: "Next level", target: nil, action: nil)
    private let endRun = NSButton(title: "End run…", target: nil, action: nil)
    private let canvas = Lemmings3Canvas()
    private let status = NSTextField(labelWithString: "")
    private let pause = NSButton(title: "Start", target: nil, action: nil)
    private let speed = NSButton(title: "Fast ×8 (F)", target: nil, action: nil)
    private var actions: [NSButton] = []
    private var selected = 0
    private var paused = true
    private var fast = false
    private var timer: Timer?
    private var lastTime = ProcessInfo.processInfo.systemUptime
    private var accumulator = 0.0
    private var message = "Choose an action, then click a lemming. Walker turns or releases a blocker."

    private struct Session {
        var campaign: Lemmings3ClassicCampaign
        let style: Lemmings3Style, sprites: Lemmings3Sprites
        let availability: [String?], progressKey: String
    }
    private static func storageIdentity(_ root: URL) -> String {
        let bundled = (try? BundledGameResources.lemmings3())?.standardizedFileURL == root.standardizedFileURL
        return bundled ? "bundled" : root.standardizedFileURL.path
    }
    private static func session(root: URL, tribe: Lemmings3ClassicCampaign.Tribe) throws -> Session {
        var sequence = try Lemmings3ClassicCampaign(root: root, tribe: tribe)
        let key = "nativeL3\(tribe.title)Preview.v1." + storageIdentity(root)
        if let data = UserDefaults.standard.data(forKey: key), let progress = try? JSONDecoder().decode(Lemmings3ClassicCampaign.Progress.self, from: data) { try? sequence.restore(progress) }
        let decodedStyle = try Lemmings3Style(directory: root.appendingPathComponent("STYLES"), number: tribe.rawValue)
        let availability: [String?] = sequence.levels.map { entry in
            do {
                let perm = try Lemmings3Objects(data: Data(contentsOf: root.appendingPathComponent(String(format: "LEVELS/PERM%03d.OBS", entry.permanentObjectsReference))))
                let temp = try Lemmings3Objects(data: Data(contentsOf: root.appendingPathComponent(String(format: "LEVELS/TEMP%03d.OBS", entry.temporaryObjectsReference))))
                _ = try Lemmings3Runtime(level: entry, style: decodedStyle, permanent: perm, temporary: temp)
                return nil
            } catch { return String(describing: error) }
        }
        if availability[sequence.index] != nil {
            guard let available = availability.firstIndex(where: { $0 == nil }) else { throw SequelDataError.invalid("No supported levels in the \(tribe.title) tribe yet.") }
            try sequence.select(available)
        }
        let prefix = String(format: "GRAPHICS/TRIBE%03d", tribe.spriteStyle)
        let sprites = try Lemmings3Sprites(index: Data(contentsOf: root.appendingPathComponent(prefix + ".IND")),
            commands: Data(contentsOf: root.appendingPathComponent(prefix + ".CMP")))
        return Session(campaign: sequence, style: decodedStyle, sprites: sprites, availability: availability, progressKey: key)
    }
    init(root: URL) throws {
        dataRoot = root
        let selectedTribe = Lemmings3ClassicCampaign.Tribe(rawValue: UserDefaults.standard.integer(forKey: "nativeL3SelectedTribe.v1." + Self.storageIdentity(root))) ?? .classic
        let session = try Self.session(root: root, tribe: selectedTribe)
        let sequence = session.campaign
        style = session.style; sprites = session.sprites; availability = session.availability; progressKey = session.progressKey
        campaign = sequence
        let level = sequence.levels[sequence.index]
        let permanent = try Lemmings3Objects(data: Data(contentsOf: root.appendingPathComponent(String(format: "LEVELS/PERM%03d.OBS", level.permanentObjectsReference))))
        let temporary = try Lemmings3Objects(data: Data(contentsOf: root.appendingPathComponent(String(format: "LEVELS/TEMP%03d.OBS", level.temporaryObjectsReference))))
        game = try Lemmings3Runtime(level: level, style: style, permanent: permanent, temporary: temporary, total: sequence.population)
        initial = game
        let scene = try Lemmings3Scene(level: level, style: style, permanent: permanent, temporary: temporary)
        super.init(window: NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1050, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false))
        guard let window else { return }
        window.title = "Lemmings 3 — \(campaign.tribe.title) \(campaign.index + 1) — Experimental native preview"
        window.delegate = self; window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 850, height: 540)
        pause.target = self; pause.action = #selector(togglePause)
        let step = NSButton(title: "Step (.)", target: self, action: #selector(singleStep))
        speed.target = self; speed.action = #selector(toggleFast)
        speed.setButtonType(.pushOnPushOff)
        let retry = NSButton(title: "Retry (R)", target: self, action: #selector(restart))
        tribes.addItems(withTitles: Lemmings3ClassicCampaign.Tribe.allCases.map(\.title))
        tribes.selectItem(at: campaign.tribe.rawValue - 1)
        tribes.target = self; tribes.action = #selector(chooseTribe)
        rebuildLevels()
        levels.target = self; levels.action = #selector(chooseLevel)
        next.target = self; next.action = #selector(advance)
        let controls = NSStackView(views: [pause, step, speed, retry, tribes, levels, next])
        controls.spacing = 8
        let notice = NSTextField(labelWithString: "Experimental physics, tool limits and animation mapping · Unsupported levels disabled · No achievement credit")
        notice.font = .systemFont(ofSize: 12); notice.textColor = .secondaryLabelColor
        for (index, action) in Lemmings3Runtime.Action.allCases.enumerated() {
            let button = NSButton(title: "\(index + 1) \(action.rawValue.capitalized)", target: self, action: #selector(selectAction(_:)))
            button.tag = index; button.setButtonType(.pushOnPushOff); actions.append(button)
        }
        direction.addItems(withTitles: ["↖ Up-left", "↑ Up", "↗ Up-right", "← Left", "→ Right", "↙ Down-left", "↓ Down", "↘ Down-right"])
        direction.selectItem(at: 4)
        direction.toolTip = "Direction for bricks and spades. Grenades and Hadokens follow the lemming's facing direction."
        endRun.target = self; endRun.action = #selector(confirmEndRun)
        endRun.toolTip = "End the run after confirmation. Active lemmings are lost; rescued lemmings and reserves are retained."
        let bar = NSStackView(views: actions + [direction, endRun]); bar.spacing = 10
        status.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        status.maximumNumberOfLines = 2
        let rootView = NSView()
        for view in [controls, notice, canvas, bar, status] {
            view.translatesAutoresizingMaskIntoConstraints = false; rootView.addSubview(view)
        }
        NSLayoutConstraint.activate([
            controls.topAnchor.constraint(equalTo: rootView.topAnchor, constant: 12),
            controls.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 12),
            notice.topAnchor.constraint(equalTo: controls.bottomAnchor, constant: 8),
            notice.leadingAnchor.constraint(equalTo: controls.leadingAnchor),
            canvas.topAnchor.constraint(equalTo: notice.bottomAnchor, constant: 8),
            canvas.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            canvas.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            canvas.bottomAnchor.constraint(equalTo: bar.topAnchor, constant: -8),
            bar.leadingAnchor.constraint(equalTo: controls.leadingAnchor),
            bar.bottomAnchor.constraint(equalTo: status.topAnchor, constant: -8),
            status.leadingAnchor.constraint(equalTo: controls.leadingAnchor),
            status.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -12),
            status.bottomAnchor.constraint(equalTo: rootView.bottomAnchor, constant: -12),
            status.heightAnchor.constraint(equalToConstant: 36)
        ])
        window.contentView = rootView
        try canvas.load(scene: scene, style: style, permanent: permanent, temporary: temporary, sprites: sprites, root: dataRoot)
        canvas.resetCamera(level)
        canvas.onClick = { [weak self] x, y in self?.assign(x: x, y: y) }
        canvas.onKey = { [weak self] key in
            guard let self else { return }
            if let number = Int(key), (1...5).contains(number) { self.selected = number - 1; self.refresh() }
            else if key == " " { self.togglePause() }
            else if key == "." { self.singleStep() }
            else if key.lowercased() == "r" { self.restart() }
            else if key.lowercased() == "f" { self.toggleFast() }
            else if key == "\u{1b}" { self.confirmEndRun() }
        }
        window.center(); refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.update() }
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func present() { showWindow(nil); window?.makeKeyAndOrderFront(nil); window?.makeFirstResponder(canvas) }
    func windowWillClose(_ notification: Notification) { stop() }
    func stop() { timer?.invalidate(); timer = nil; save() }
    static func savedCompletion(root: URL) -> Int {
        Lemmings3ClassicCampaign.Tribe.allCases.reduce(0) { count, tribe in
            guard var campaign = try? Lemmings3ClassicCampaign(root: root, tribe: tribe) else { return count }
            let key = "nativeL3\(tribe.title)Preview.v1." + storageIdentity(root)
            if let data = UserDefaults.standard.data(forKey: key),
               let saved = try? JSONDecoder().decode(Lemmings3ClassicCampaign.Progress.self, from: data) {
                try? campaign.restore(saved)
            }
            return count + campaign.completed.count
        }
    }

    @objc private func togglePause() { paused.toggle(); accumulator = 0; refresh() }
    @objc private func singleStep() { paused = true; game.step(); refresh() }
    @objc private func toggleFast() { fast.toggle(); refresh() }
    @objc private func confirmEndRun() {
        guard !game.isComplete, let window, window.attachedSheet == nil else { return }
        let wasPaused = paused
        paused = true; accumulator = 0; refresh()
        let alert = NSAlert()
        alert.messageText = "End this run?"
        alert.informativeText = "Active lemmings will be lost. Rescued lemmings and reserves will be retained. You can retry the level."
        alert.addButton(withTitle: "Keep playing")
        alert.addButton(withTitle: "End run")
        alert.window.defaultButtonCell = alert.buttons[0].cell as? NSButtonCell
        alert.buttons[0].keyEquivalent = "\u{1b}"
        alert.buttons[1].keyEquivalent = ""
        alert.beginSheetModal(for: window) { [weak self] response in
            guard let self else { return }
            if response == .alertSecondButtonReturn {
                self.game.abort(); self.paused = true
            } else {
                self.paused = wasPaused
            }
            self.accumulator = 0; self.refresh()
            window.makeFirstResponder(self.canvas)
        }
    }
    @objc private func restart() { game = initial; recorded = false; paused = true; accumulator = 0; canvas.resetCamera(campaign.levels[campaign.index]); message = "Ready. The direction menu controls bricks and spades. Arrow keys move the camera."; refresh() }
    private func save() { if let data = try? JSONEncoder().encode(campaign.progress) { UserDefaults.standard.set(data, forKey: progressKey) } }
    private func rebuildLevels() {
        levels.removeAllItems()
        levels.addItems(withTitles: campaign.levels.indices.map { "Level \($0 + 1)\(availability[$0] == nil ? "" : " — unavailable")" })
        levels.menu?.autoenablesItems = false
        for index in availability.indices { levels.item(at: index)?.isEnabled = availability[index] == nil; levels.item(at: index)?.toolTip = availability[index] }
        levels.selectItem(at: campaign.index)
    }
    @objc private func chooseTribe() {
        guard let tribe = Lemmings3ClassicCampaign.Tribe(rawValue: tribes.indexOfSelectedItem + 1), tribe != campaign.tribe else { return }
        do {
            let session = try Self.session(root: dataRoot, tribe: tribe)
            let level = session.campaign.levels[session.campaign.index]
            let perm = try Lemmings3Objects(data: Data(contentsOf: dataRoot.appendingPathComponent(String(format: "LEVELS/PERM%03d.OBS", level.permanentObjectsReference))))
            let temp = try Lemmings3Objects(data: Data(contentsOf: dataRoot.appendingPathComponent(String(format: "LEVELS/TEMP%03d.OBS", level.temporaryObjectsReference))))
            let replacement = try Lemmings3Runtime(level: level, style: session.style, permanent: perm, temporary: temp, total: session.campaign.population)
            let scene = try Lemmings3Scene(level: level, style: session.style, permanent: perm, temporary: temp)
            try canvas.load(scene: scene, style: session.style, permanent: perm, temporary: temp, sprites: session.sprites, root: dataRoot)
            save()
            style = session.style; sprites = session.sprites; availability = session.availability; progressKey = session.progressKey
            campaign = session.campaign; initial = replacement
            UserDefaults.standard.set(tribe.rawValue, forKey: "nativeL3SelectedTribe.v1." + Self.storageIdentity(dataRoot))
            rebuildLevels()
            window?.title = "Lemmings 3 — \(tribe.title) \(campaign.index + 1) — Experimental native preview"
            restart()
        } catch {
            tribes.selectItem(at: campaign.tribe.rawValue - 1)
            message = String(describing: error); refresh()
        }
    }
    @objc private func chooseLevel() {
        var proposed = campaign
        do { try proposed.select(levels.indexOfSelectedItem); try load(proposed) }
        catch { message = String(describing: error); refresh() }
    }
    @objc private func advance() {
        if campaignFinished, let onCampaignCompleted { onCampaignCompleted(); return }
        var proposed = campaign
        guard proposed.advance(after: game), availability[proposed.index] == nil else { return }
        do { try load(proposed) } catch { message = String(describing: error); refresh() }
    }
    private func load(_ proposed: Lemmings3ClassicCampaign) throws {
        let level = proposed.levels[proposed.index]
        let perm = try Lemmings3Objects(data: Data(contentsOf: dataRoot.appendingPathComponent(String(format: "LEVELS/PERM%03d.OBS", level.permanentObjectsReference))))
        let temp = try Lemmings3Objects(data: Data(contentsOf: dataRoot.appendingPathComponent(String(format: "LEVELS/TEMP%03d.OBS", level.temporaryObjectsReference))))
        let replacement = try Lemmings3Runtime(level: level, style: style, permanent: perm, temporary: temp, total: proposed.population)
        let scene = try Lemmings3Scene(level: level, style: style, permanent: perm, temporary: temp)
        try canvas.load(scene: scene, style: style, permanent: perm, temporary: temp, sprites: sprites, root: dataRoot)
        campaign = proposed; initial = replacement; save()
        window?.title = "Lemmings 3 — \(campaign.tribe.title) \(campaign.index + 1) — Experimental native preview"
        restart()
    }
    @objc private func selectAction(_ sender: NSButton) { selected = sender.tag; refresh(); window?.makeFirstResponder(canvas) }
    private func assign(x: Int, y: Int) {
        let nearby = game.lemmings.filter { $0.active && abs($0.x - x) <= 9 && abs($0.y - 8 - y) <= 12 }
        guard let lem = nearby.min(by: {
            if selected >= 3 && ($0.tool == nil) != ($1.tool == nil) { return $0.tool != nil }
            return abs($0.x - x) + abs($0.y - 8 - y) < abs($1.x - x) + abs($1.y - 8 - y)
        }) else { return }
        let action = Lemmings3Runtime.Action.allCases[selected]
        let accepted = action == .use ? game.useTool(to: lem.id, direction: Lemmings3Runtime.Direction.allCases[direction.indexOfSelectedItem]) : game.assign(action, to: lem.id)
        message = accepted ? "\(action.rawValue.capitalized) assigned to lemming \(lem.id + 1)." : "That lemming cannot use this action now."
        refresh()
    }
    private func update() {
        let now = ProcessInfo.processInfo.systemUptime
        let elapsed = min(0.1, now - lastTime); lastTime = now
        guard !paused, !game.isComplete else { return }
        accumulator += elapsed * (fast ? 8 : 1)
        while accumulator >= 1 / Lemmings3Runtime.ticksPerSecond {
            accumulator -= 1 / Lemmings3Runtime.ticksPerSecond; game.step()
        }
        refresh()
    }
    private func refresh() {
        pause.title = paused ? "Start / Resume (Space)" : "Pause (Space)"
        speed.state = fast ? .on : .off
        for (index, button) in actions.enumerated() { button.state = index == selected ? .on : .off }
        if game.isComplete && !recorded { recorded = true; if campaign.record(game) {
            save()
            campaignFinished = Self.savedCompletion(root: dataRoot) == 90
            onProgressChanged?()
        } }
        levels.selectItem(at: campaign.index)
        next.title = campaignFinished && usesSharedWindow ? "Continue" : "Next level"
        next.isEnabled = game.isComplete && game.saved > 0 && ((campaignFinished && usesSharedWindow)
            || (availability.indices.contains(campaign.index + 1) && availability[campaign.index + 1] == nil))
        endRun.isEnabled = !game.isComplete
        let result = game.isComplete ? "Run ended — \(game.saved) rescued, \(game.reserve) in reserve.\(next.isEnabled ? " Continue with Next level." : " Retry or choose an available level.")" : message
        status.stringValue = "Released \(game.released)   Reserve \(game.reserve)   Saved \(game.saved)   Lost \(game.lost)   Time \(game.remainingSeconds)s   \(fast ? "8×" : "1×")\n\(result)"
        canvas.game = game; canvas.needsDisplay = true
    }
}

@MainActor private final class Lemmings3Canvas: NSView {
    var game: Lemmings3Runtime?
    var onClick: ((Int, Int) -> Void)?
    var onKey: ((String) -> Void)?
    private var terrain: NSImage?
    private var sprites: [[NSImage]] = []
    private var objects: [(Int, Int, Int, Bool, [NSImage])] = []
    private var foreground: NSImage?
    private var foregroundPixels: [UInt8] = []
    private var palette: [UInt8] = []
    private var brickPixels: [UInt8] = []
    private var renderedEdits: [Int: Bool] = [:]
    private var pickupImages: [Int: NSImage] = [:]
    private var creatureImages: [Int: [[NSImage]]] = [:]
    private var mapWidth = 320
    private var mapHeight = 160
    private var cameraX: CGFloat = 0
    private var cameraY: CGFloat = 0
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    private var zoom: CGFloat { max(0.1, min(bounds.width / 320, bounds.height / 160)) }
    private var origin: NSPoint { NSPoint(x: (bounds.width - 320 * zoom) / 2, y: (bounds.height - 160 * zoom) / 2) }
    private func image(width: Int, height: Int, pixels: [UInt8], palette: [UInt8], opaque: [Bool]? = nil) throws -> NSImage {
        var bytes = pixels.flatMap { colour in Array(palette[Int(colour) * 4..<(Int(colour) * 4 + 4)]) }
        if let opaque { for index in opaque.indices where !opaque[index] { bytes[index * 4 + 3] = 0 } }
        guard let provider = CGDataProvider(data: Data(bytes) as CFData), let cg = CGImage(width: width, height: height,
            bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue), provider: provider, decode: nil,
            shouldInterpolate: false, intent: .defaultIntent) else { throw SequelDataError.invalid("Cannot create a Chronicles frame.") }
        return NSImage(cgImage: cg, size: NSSize(width: width, height: height))
    }
    func load(scene: Lemmings3Scene, style: Lemmings3Style, permanent: Lemmings3Objects, temporary: Lemmings3Objects, sprites bank: Lemmings3Sprites, root: URL) throws {
        let staged = Lemmings3Canvas()
        try staged.populate(scene: scene, style: style, permanent: permanent, temporary: temporary, sprites: bank, root: root)
        terrain = staged.terrain; sprites = staged.sprites; objects = staged.objects
        foreground = staged.foreground; foregroundPixels = staged.foregroundPixels
        palette = staged.palette; brickPixels = staged.brickPixels; renderedEdits = [:]
        pickupImages = staged.pickupImages; creatureImages = staged.creatureImages
        mapWidth = staged.mapWidth; mapHeight = staged.mapHeight
    }
    private func populate(scene: Lemmings3Scene, style: Lemmings3Style, permanent: Lemmings3Objects, temporary: Lemmings3Objects, sprites bank: Lemmings3Sprites, root: URL) throws {
        objects = []; pickupImages = [:]; creatureImages = [:]; renderedEdits = [:]
        mapWidth = scene.image.width; mapHeight = scene.image.height; palette = style.palette
        terrain = try image(width: mapWidth, height: mapHeight, pixels: scene.background.pixels, palette: style.palette)
        foregroundPixels = Array(repeating: 255, count: mapWidth * mapHeight)
        // Native 8x8 construction tile. Its placement rules remain experimental.
        brickPixels = try style.constructionTile().pixels
        sprites = try bank.animations.map { animation in
            try animation.frames.map { try image(width: animation.width, height: animation.height,
                pixels: $0.pixels, palette: style.palette, opaque: $0.opaque) }
        }
        for (placementIndex, placed) in permanent.placements.enumerated() {
            if let kind = Lemmings3Runtime.Creature.Kind(rawValue: placed.identifier / 2 * 2), creatureImages[kind.rawValue] == nil {
                let prefix = String(format: "GRAPHICS/CREAT%03d", (kind.rawValue - 10008) / 2)
                let creatureBank = try Lemmings3Sprites(index: Data(contentsOf: root.appendingPathComponent(prefix + ".IND")),
                    commands: Data(contentsOf: root.appendingPathComponent(prefix + ".CMP")))
                let colours = try Lemmings3Sprites.palette(Data(contentsOf: root.appendingPathComponent(prefix + ".PAL")), over: palette)
                creatureImages[kind.rawValue] = try creatureBank.animations.map { animation in
                    try animation.frames.map { try image(width: animation.width, height: animation.height,
                        pixels: $0.pixels, palette: colours, opaque: $0.opaque) }
                }
            }
            guard let object = style.permanent.objects[placed.identifier], placed.identifier < 5000, object.frameCount > 1 else { continue }
            let frames = try (0..<object.frameCount).map { index in
                let frame = try style.permanent.image(object: placed.identifier, frame: index, palette: style.palette)
                return try image(width: frame.width, height: frame.height, pixels: frame.pixels, palette: style.palette, opaque: frame.pixels.map { $0 != 255 })
            }
            objects.append((placementIndex, placed.x, placed.y, object.flags == 0x0402, frames))
        }
        for placed in temporary.placements {
            let frame = try style.temporary.image(object: placed.identifier, palette: style.palette)
            for y in 0..<frame.height where placed.y + y < mapHeight {
                for x in 0..<frame.width where placed.x + x < mapWidth {
                    let colour = frame.pixels[y * frame.width + x]
                    if colour != 255 { foregroundPixels[(placed.y + y) * mapWidth + placed.x + x] = colour }
                }
            }
        }
        foreground = try image(width: mapWidth, height: mapHeight, pixels: foregroundPixels, palette: palette, opaque: foregroundPixels.map { $0 != 255 })
        for tool in Lemmings3Runtime.Tool.allCases {
            let frame = try style.permanent.image(object: tool.rawValue, palette: palette)
            pickupImages[tool.rawValue] = try image(width: frame.width, height: frame.height, pixels: frame.pixels, palette: palette, opaque: frame.pixels.map { $0 != 255 })
        }
    }
    func resetCamera(_ level: Lemmings3Level) {
        cameraX = CGFloat(min(max(0, mapWidth - 320), level.screenX))
        cameraY = CGFloat(min(max(0, mapHeight - 160), level.screenY))
    }
    private func drawImage(_ image: NSImage, x: CGFloat, y: CGFloat) {
        image.draw(in: NSRect(x: origin.x + (x - cameraX) * zoom, y: origin.y + (y - cameraY) * zoom,
            width: image.size.width * zoom, height: image.size.height * zoom), from: .zero,
            operation: .sourceOver, fraction: 1, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.none.rawValue])
    }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill(); bounds.fill()
        guard let game, let terrain else { return }
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: NSRect(x: origin.x, y: origin.y, width: 320 * zoom, height: 160 * zoom)).addClip()
        drawImage(terrain, x: 0, y: 0)
        for (id, x, y, entrance, frames) in objects {
            let isTrap = game.configuration.traps.contains { $0.id == id }
            let index = isTrap ? game.trapFrame(id: id) : (entrance ? min(frames.count - 1, game.tick / 3) : game.tick / 3 % frames.count)
            drawImage(frames[index], x: CGFloat(x), y: CGFloat(y))
        }
        if game.terrainEdits != renderedEdits {
            var pixels = foregroundPixels
            for (index, filled) in game.terrainEdits {
                pixels[index] = filled ? brickPixels[(index / mapWidth % 8) * 8 + index % mapWidth % 8] : 255
            }
            if let frame = try? image(width: mapWidth, height: mapHeight, pixels: pixels, palette: palette, opaque: pixels.map { $0 != 255 }) {
                foreground = frame; renderedEdits = game.terrainEdits
            }
        }
        if let foreground { drawImage(foreground, x: 0, y: 0) }
        for pickup in game.pickups where pickup.quantity > 0 {
            if let frame = pickupImages[pickup.tool.rawValue] { drawImage(frame, x: CGFloat(pickup.x), y: CGFloat(pickup.y)) }
        }
        // Native sprite banks and palettes; animation IDs and anchors remain provisional.
        for creature in game.creatures where creature.alive {
            let animation = creature.direction > 0 ? 0 : 1
            if let bank = creatureImages[creature.kind.rawValue], bank.indices.contains(animation), !bank[animation].isEmpty {
                let frame = bank[animation][creature.age / 3 % bank[animation].count]
                drawImage(frame, x: CGFloat(creature.x) - frame.size.width / 2, y: CGFloat(creature.y) - frame.size.height)
            }
        }
        // Tool icons and blast rings are preview art until effect sprites are mapped.
        for item in game.explosives {
            if let frame = pickupImages[item.tool.rawValue] { drawImage(frame, x: CGFloat(item.x - 4), y: CGFloat(item.y - 7)) }
            let seconds = (item.fuseTicks - item.age + 22) / 23
            "\(seconds)".draw(at: NSPoint(x: origin.x + (CGFloat(item.x - 2) - cameraX) * zoom,
                y: origin.y + (CGFloat(item.y - 14) - cameraY) * zoom),
                withAttributes: [.foregroundColor: NSColor.yellow, .font: NSFont.boldSystemFont(ofSize: 11)])
        }
        for blast in game.blasts {
            NSColor.orange.setStroke()
            let ring = NSBezierPath(ovalIn: NSRect(x: origin.x + (CGFloat(blast.x - 20) - cameraX) * zoom,
                y: origin.y + (CGFloat(blast.y - 20) - cameraY) * zoom, width: 40 * zoom, height: 40 * zoom))
            ring.lineWidth = 2; ring.stroke()
        }
        for shot in game.fireballs {
            NSColor.cyan.setFill()
            NSBezierPath(ovalIn: NSRect(x: origin.x + (CGFloat(shot.x - 3) - cameraX) * zoom,
                y: origin.y + (CGFloat(shot.y - 2) - cameraY) * zoom, width: 6 * zoom, height: 4 * zoom)).fill()
        }
        for lem in game.lemmings where lem.active {
            // Animation IDs and anchors remain provisional. The bytes are native.
            let animation = lem.direction > 0 ? 0 : 1
            guard sprites.indices.contains(animation), !sprites[animation].isEmpty else { continue }
            let frames = sprites[animation]
            let sprite = frames[(lem.state == .blocking ? 0 : lem.age) % frames.count]
            drawImage(sprite, x: CGFloat(lem.x) - sprite.size.width / 2, y: CGFloat(lem.y) - sprite.size.height)
            if lem.charmedBy != nil {
                "Charmed".draw(at: NSPoint(x: origin.x + (CGFloat(lem.x - 8) - cameraX) * zoom,
                    y: origin.y + (CGFloat(lem.y - 30) - cameraY) * zoom),
                    withAttributes: [.foregroundColor: NSColor.systemPink, .font: NSFont.boldSystemFont(ofSize: 10)])
            }
            if let tool = lem.tool ?? lem.mobilityTool {
                let label = lem.tool == nil ? "\(tool.label) \((lem.mobilityTicks + 22) / 23)s" : "\(tool.label)\(lem.quantity)"
                label.draw(at: NSPoint(x: origin.x + (CGFloat(lem.x - 4) - cameraX) * zoom, y: origin.y + (CGFloat(lem.y - 23) - cameraY) * zoom),
                    withAttributes: [.foregroundColor: NSColor.white, .font: NSFont.boldSystemFont(ofSize: 11)])
            }
        }
        NSGraphicsContext.restoreGraphicsState()
    }
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let point = convert(event.locationInWindow, from: nil)
        let x = (point.x - origin.x) / zoom, y = (point.y - origin.y) / zoom
        guard x >= 0, x < 320, y >= 0, y < 160 else { return }
        onClick?(Int(x + cameraX), Int(y + cameraY))
    }
    override func keyDown(with event: NSEvent) {
        guard event.modifierFlags.intersection([.command, .control, .option]).isEmpty else { super.keyDown(with: event); return }
        switch event.keyCode {
        case 123: pan(-24, 0); return
        case 124: pan(24, 0); return
        case 125: pan(0, 16); return
        case 126: pan(0, -16); return
        default: break
        }
        if let text = event.characters { onKey?(text) }
    }
    private func pan(_ x: CGFloat, _ y: CGFloat) {
        cameraX = max(0, min(CGFloat(max(0, mapWidth - 320)), cameraX + x))
        cameraY = max(0, min(CGFloat(max(0, mapHeight - 160)), cameraY + y)); needsDisplay = true
    }
    override func scrollWheel(with event: NSEvent) {
        pan(event.modifierFlags.contains(.shift) ? event.scrollingDeltaY * 4 : event.scrollingDeltaX * 4,
            event.modifierFlags.contains(.shift) ? 0 : event.scrollingDeltaY * 4)
    }
}
