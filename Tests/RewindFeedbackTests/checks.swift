// Compiled beside the private sequel canvases by run-rewind-feedback-tests.sh.
import AppKit
import NxlvKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let output = root.appendingPathComponent(".build/rewind-feedback/renders")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
struct RewindFailure: Error { let message: String }
func checkRewind(_ value: Bool, _ message: String) throws {
    if !value { throw RewindFailure(message: message) }
}
@MainActor func rewindShot(_ view: NSView, _ name: String) throws -> Data {
    let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
    view.cacheDisplay(in: view.bounds, to: bitmap)
    let data = bitmap.representation(using: .png, properties: [:])!
    try data.write(to: output.appendingPathComponent(name + ".png"))
    return data
}

@MainActor func checkRewindTargets(_ view: NSView, _ timeline: TimelinePanelControls) throws {
    let oldEnabled = timeline.enabled, oldPerform = timeline.perform
    defer { timeline.enabled = oldEnabled; timeline.perform = oldPerform }
    timeline.enabled = { _ in true }
    var selected: TimelinePanelControls.Action?
    timeline.perform = { selected = $0 }
    for action in TimelinePanelControls.Action.allCases {
        let box = timeline.rect(for: action)
        try checkRewind(view.bounds.contains(box) && box.width > 0 && box.height > 0, "Timeline target escaped the rendered canvas")
        let point = CGPoint(x: box.midX, y: box.midY)
        try checkRewind(view.hitTest(point) === view && timeline.click(at: point) && selected == action,
            "The rewind effect intercepted a timeline target")
    }
    selected = nil
    let gap = CGPoint(x: timeline.rect(for: .backward).maxX + 1, y: timeline.frame.midY)
    try checkRewind(timeline.click(at: gap) && selected == nil, "A timeline gap passed input through")
}

@MainActor func checkSharedRewind() throws {
    let trails = SpeedTrails()
    trails.prepareRewind(actors: [.init(id: 1, position: CGPoint(x: 80, y: 40))])
    var redraws = 0
    trails.finishRewind(tick: 9, actors: [.init(id: 1, position: CGPoint(x: 79, y: 40))]) { redraws += 1 }
    try checkRewind(trails.isRewinding && trails.motion(actor: 1).dx == -1, "One tick rewind had no immediate reverse direction")
    trails.update(tick: 9, enabled: true, actors: [])
    try checkRewind(trails.motion(actor: 1).dx == -1, "A redraw lost the paused rewind impulse")
    trails.prepareRewind(actors: [.init(id: 1, position: CGPoint(x: 79, y: 40))])
    trails.finishRewind(tick: 8, actors: [.init(id: 1, position: CGPoint(x: 79, y: 39))]) { redraws += 1 }
    try checkRewind(trails.motion(actor: 1) == CGVector(dx: 0, dy: -1), "Repeat tap retained the previous direction")
    RunLoop.current.run(until: Date().addingTimeInterval(0.22))
    try checkRewind(!trails.isRewinding && trails.motion(actor: 1) == .zero && redraws == 1,
        "The cue did not expire while paused, or the replaced timer still fired")
    trails.prepareRewind(actors: [.init(id: 1, position: CGPoint(x: 79, y: 40))])
    trails.finishRewind(tick: 8, actors: [.init(id: 1, position: CGPoint(x: 78, y: 40))]) {}
    trails.update(tick: 9, enabled: true, actors: [])
    try checkRewind(!trails.isRewinding, "Forward play retained the rewind impulse")
    print("PASS immediate reverse direction, repeat replacement, paused expiry and forward cancellation")
}

private final class RewindPreviewSession: GameSession {
    var currentTick = 20
    var x = 170
    var lemmings: [SessionLemming] { [.init(id: 1, x: x, y: 80, pose: .walking, facingLeft: false, animationFrame: 0, countdown: nil)] }
    let levelWidth = 320, levelHeight = 160, ticksPerSecond = 17
    let entranceX: Int? = nil
    let released = 1, total = 1, saved = 0, required = 1, rate = 50
    let rateLabel = "Rate"
    let remainingSeconds: Int? = nil
    let isComplete = false, didWin = false, isNuking = false, canUndoNuke = false, supportsRewind = true
    let skills: [SessionSkill] = [], lastCues: [ClassicSoundEffect] = []
    func tick() {}
    func assign(skillIndex: Int, to lemmingID: Int) -> String? { nil }
    func assignmentState(skillIndex: Int, to lemmingID: Int) -> AssignmentState { .unavailable }
    func adjustRate(by delta: Int) {}
    func setRateLimit(maximum: Bool) {}
    func nuke() {}
    func undoNuke() {}
    func rewind(seconds: Double) -> Bool { false }
    func stepBackward() -> Bool { false }
    func stepForward() -> Bool { false }
}

@MainActor func checkClassicRewind() throws {
    let view = PlayfieldView(frame: CGRect(x: 0, y: 0, width: 640, height: 320))
    let session = RewindPreviewSession()
    view.session = session; view.phase = .playing; view.viewport.zoom = 2
    view.assets = try ClassicMainDATAssets.load(from: root.appendingPathComponent("Content/lemming1.pc"))
    view.palette = ClassicLemmingPalette.panelVGA
    view.lemmingSelectionStyle = .none
    view.levelImage = CGContext(data: nil, width: 320, height: 160, bitsPerComponent: 8, bytesPerRow: 1280,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!.makeImage()
    view.beginRewindCue(at: 20); view.prepareRewindEffects()
    session.x -= 1; session.currentTick -= 1
    view.updateRewindCue(at: 19); view.endRewindCue()
    let rewound = try rewindShot(view, "classic-rewind")
    try checkRewind(view.hitTest(CGPoint(x: 338, y: 160)) === view,
        "The Classic rewind cue intercepted the playfield")
    view.hdEffectsEnabled = false
    let plain = try rewindShot(view, "classic-plain")
    try checkRewind(rewound != plain, "Classic Cmd-Z had no reverse echoes")
    let effect = NSBitmapImageRep(data: rewound)!, normal = NSBitmapImageRep(data: plain)!
    let captureScale = CGFloat(effect.pixelsWide) / view.bounds.width
    var extras = 0
    for y in Int(80 * captureScale)..<Int(230 * captureScale) { for x in 0..<effect.pixelsWide {
        let a = effect.colorAt(x: x, y: y)!, b = normal.colorAt(x: x, y: y)!
        if b.brightnessComponent > 0 { try checkRewind(a == b, "A rewind ghost changed a solid sprite pixel") }
        else if a.brightnessComponent > 0 { extras += 1; try checkRewind(CGFloat(x) > 320 * captureScale, "Rewind echo pointed away from the future position") }
    } }
    try checkRewind(extras > 0, "Classic sprite echo mask was empty")
    print("PASS Classic rendered one-tick reverse echoes, sharp solid sprites and HD opt-out")
}

extension Lemmings2Canvas { fileprivate var rewindIsActive: Bool { speedTrails.isRewinding } }
extension Lemmings3Canvas { fileprivate var rewindIsActive: Bool { speedTrails.isRewinding } }

@MainActor func checkSequelRewinds() throws {
    let l2root = root.appendingPathComponent("Sources/Ports/Lemm2")
    func l2data(_ path: String) throws -> Data { try Data(contentsOf: l2root.appendingPathComponent(path)) }
    let level = try Lemmings2Level(data: l2data("LEVELS/LEVEL010.DAT"))
    let style = try Lemmings2Style(data: l2data("STYLES/\(Lemmings2Campaign.styleNames[level.style]).DAT"))
    var game = try Lemmings2Runtime(level: level, style: style, masks: Lemmings2TerrainMasks(root: l2root))
    for _ in 0..<110 { game.step() }
    let old = game
    game.step()
    let view = Lemmings2Canvas(frame: CGRect(x: 0, y: 0, width: 640, height: 480))
    try view.load(level: level, style: style, sprites: Lemmings2Sprites(data: l2data("VLEMMS.DAT")),
        intern: Lemmings2SpecialGraphics(data: l2data("INTERN.DAT")),
        explosion: Lemmings2Explosion(data: l2data("EXPLOSION.DAT")), walker: Lemmings2Walker(data: l2data("WALKER.DAT")))
    view.lemmingSelectionStyle = .none
    view.update(game); view.prepareRewindEffects(); view.finishRewindEffects(old); view.update(old)
    let l2effect = try rewindShot(view, "l2-rewind")
    try checkRewindTargets(view, view.timeline)
    view.hdEffectsEnabled = false
    try checkRewind(l2effect != rewindShot(view, "l2-plain"), "L2 rewind had no sprite echoes")
    view.hdEffectsEnabled = true; view.reduceMotion = true
    view.prepareRewindEffects(); view.finishRewindEffects(old)
    try checkRewind(!view.rewindIsActive, "L2 reduced motion started a rewind impulse")

    let l3root = root.appendingPathComponent("Sources/Ports/LEM3CD")
    func l3data(_ path: String) throws -> Data { try Data(contentsOf: l3root.appendingPathComponent(path)) }
    let l3level = try Lemmings3Level(data: l3data("LEVELS/LEVEL001.DAT"))
    let l3style = try Lemmings3Style(directory: l3root.appendingPathComponent("STYLES"), number: l3level.style)
    let perm = try Lemmings3Objects(data: l3data(String(format: "LEVELS/PERM%03d.OBS", l3level.permanentObjectsReference)))
    let temp = try Lemmings3Objects(data: l3data(String(format: "LEVELS/TEMP%03d.OBS", l3level.temporaryObjectsReference)))
    let prefix = String(format: "GRAPHICS/TRIBE%03d", l3level.lemmingStyle)
    let sprites = try Lemmings3Sprites(index: l3data(prefix + ".IND"), commands: l3data(prefix + ".CMP"))
    var l3game = try Lemmings3Runtime(level: l3level, style: l3style, permanent: perm, temporary: temp)
    for _ in 0..<110 { l3game.step() }
    let l3old = l3game
    l3game.step()
    let l3view = Lemmings3Canvas(frame: CGRect(x: 0, y: 0, width: 640, height: 320))
    try l3view.load(scene: Lemmings3Scene(level: l3level, style: l3style, permanent: perm, temporary: temp),
        style: l3style, permanent: perm, temporary: temp, sprites: sprites, root: l3root, terrainStyle: l3level.style)
    l3view.resetCamera(l3level); l3view.lemmingSelectionStyle = .none
    l3view.game = l3game; l3view.prepareRewindEffects(); l3view.finishRewindEffects(l3old); l3view.game = l3old
    let l3effect = try rewindShot(l3view, "l3-rewind")
    try checkRewindTargets(l3view, l3view.timeline)
    l3view.hdEffectsEnabled = false
    try checkRewind(l3effect != rewindShot(l3view, "l3-plain"), "L3 rewind had no sprite echoes")
    l3view.hdEffectsEnabled = true; l3view.reduceFlashes = true
    l3view.prepareRewindEffects(); l3view.finishRewindEffects(l3old)
    try checkRewind(!l3view.rewindIsActive, "L3 reduced flashes started a rewind impulse")
    print("PASS L2 and L3 rendered one-tick rewind, timeline targets and gaps, HD opt-out, reduced motion and reduced flashes")
}
@MainActor func checkControllerResetPriority() throws {
    let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 640, height: 480), styleMask: [.borderless], backing: .buffered, defer: false)
    let keyboard = GameplayKeyboard(window: window)
    let speed = GameSpeedControl()
    keyboard.speedControl = speed
    keyboard.active = { true }
    keyboard.controllerEnabled = { true }
    keyboard.ownsController = { true }
    var pauses = 0
    keyboard.togglePause = { pauses += 1 }
    speed.setFast(true)
    keyboard.controllerAction(.pause)
    try checkRewind(!speed.isFast && pauses == 0, "Play/Pause paused before restoring 1x")
    keyboard.controllerAction(.pause)
    try checkRewind(pauses == 1, "Play/Pause did not pause at 1x")
    let controller = GameplayController(keyboard: keyboard, pollsAutomatically: false)
    controller.processButtons([], at: 0, playing: true)
    speed.setFast(true)
    controller.processButtons([.rightTrigger], at: 1, playing: true)
    controller.processButtons([.rightTrigger], at: 2, playing: true)
    controller.processButtons([], at: 3, playing: true)
    try checkRewind(!speed.isFast && speed.target == 1, "Held R2 or its release undid the reset to 1x")
    print("PASS shared Classic/L2/L3 controller reset priority, pause and held-trigger release")
}
try checkControllerResetPriority()
try checkSharedRewind()
try checkClassicRewind()
try checkSequelRewinds()
