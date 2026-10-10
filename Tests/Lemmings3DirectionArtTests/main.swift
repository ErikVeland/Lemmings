import AppKit
import NxlvKit

extension Lemmings3Canvas {
    var directionArtTestRect: CGRect { directionPickerRect }
    var directionArtTestOrigin: CGPoint { screenOrigin }
    var directionArtTestZoom: CGFloat { zoom }
    var directionArtBackingWidth: Int? {
        guard sprites.indices.contains(Lemmings3Panel.directionAnimation),
              let frame = sprites[Lemmings3Panel.directionAnimation].first else { return nil }
        return frame.cgImage(forProposedRect: nil, context: nil, hints: nil)?.width
    }
}

func check(_ condition: Bool, _ message: String) throws {
    if !condition { throw SequelDataError.invalid(message) }
}

func read(_ root: URL, _ path: String) throws -> Data {
    try Data(contentsOf: root.appendingPathComponent(path))
}

@MainActor func capture(_ view: NSView, to url: URL) throws -> Data {
    view.needsDisplay = true
    guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
        throw SequelDataError.invalid("Cannot render the L3 direction picker.")
    }
    view.cacheDisplay(in: view.bounds, to: bitmap)
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw SequelDataError.invalid("Cannot save the L3 direction picker capture.")
    }
    try png.write(to: url)
    return png
}

let application = NSApplication.shared
let project = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let dataRoot = project.appendingPathComponent("Sources/Ports/LEM3CD")
let output = project.appendingPathComponent(".build/l3-direction-art/captures")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let previousPreference = UserDefaults.standard.object(forKey: SequelArtworkPreference.key)
defer {
    if let previousPreference { UserDefaults.standard.set(previousPreference, forKey: SequelArtworkPreference.key) }
    else { UserDefaults.standard.removeObject(forKey: SequelArtworkPreference.key) }
}

let directions: [Lemmings3Runtime.Direction] = [.up, .upRight, .right, .downRight,
    .down, .downLeft, .left, .upLeft]
for number in [1, 101, 201] {
    let level = try Lemmings3Level(data: read(dataRoot, String(format: "LEVELS/LEVEL%03d.DAT", number)))
    let style = try Lemmings3Style(directory: dataRoot.appendingPathComponent("STYLES"), number: level.style)
    let permanent = try Lemmings3Objects(data: read(dataRoot,
        String(format: "LEVELS/PERM%03d.OBS", level.permanentObjectsReference)))
    let temporary = try Lemmings3Objects(data: read(dataRoot,
        String(format: "LEVELS/TEMP%03d.OBS", level.temporaryObjectsReference)))
    let prefix = String(format: "GRAPHICS/TRIBE%03d", level.lemmingStyle)
    let bank = try Lemmings3Sprites(index: read(dataRoot, prefix + ".IND"),
        commands: read(dataRoot, prefix + ".CMP"))
    let animation = Lemmings3Panel.directionAnimation
    try check(bank.animations.indices.contains(animation)
        && bank.animations[animation].width == 16
        && bank.animations[animation].height == 16
        && bank.animations[animation].frames.count == 8,
        "L3 tribe \(level.lemmingStyle) has no eight-frame native direction bank")
    for (index, direction) in directions.enumerated() {
        try check(Lemmings3Panel.directionFrame(direction) == index,
            "L3 direction \(direction) selected the wrong native frame")
        let frame = bank.animations[animation].frames[index]
        try check(frame.opaque.enumerated().allSatisfy {
            !$0.element || (1..<14).contains($0.offset % 16) && (1..<14).contains($0.offset / 16)
        }, "L3 direction \(direction) is clipped by its 13-pixel cell")
    }

    let scene = try Lemmings3Scene(level: level, style: style,
        permanent: permanent, temporary: temporary)
    let runtime = try Lemmings3Runtime(level: level, style: style,
        permanent: permanent, temporary: temporary)
    let view = Lemmings3Canvas(frame: NSRect(x: 0, y: 0, width: 640, height: 320))
    let window = NSWindow(contentRect: view.frame, styleMask: [], backing: .buffered, defer: false)
    window.contentView = view
    SequelArtworkPreference.setEnabled(false)
    try view.load(scene: scene, style: style, permanent: permanent,
        temporary: temporary, sprites: bank, root: dataRoot, terrainStyle: level.style)
    view.resetCamera(level)
    view.game = runtime
    view.directionPoint = CGPoint(x: 9999, y: 9999)
    let pc = try capture(view, to: output.appendingPathComponent("l3-\(number)-pc.png"))
    try check(view.directionArtBackingWidth == 16, "Original PC mode changed the native arrow backing size")
    let cameraX = view.cameraX, cameraY = view.cameraY
    let tick = view.game?.tick

    var selectedDirection: Lemmings3Runtime.Direction?
    view.onDirection = { selectedDirection = $0 }
    for direction in directions {
        let rect = view.directionArtTestRect
        let sx = rect.minX + CGFloat(direction.dx + 1) * 14 + 6
        let sy = rect.minY + CGFloat(direction.dy + 1) * 14 + 6
        let point = NSPoint(x: view.directionArtTestOrigin.x + sx * view.directionArtTestZoom,
            y: view.directionArtTestOrigin.y + sy * view.directionArtTestZoom)
        let location = view.convert(point, to: nil)
        let event = NSEvent.mouseEvent(with: .leftMouseDown, location: location,
            modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber,
            context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
        view.mouseDown(with: event)
        try check(selectedDirection == direction, "L3 direction click missed \(direction)")
    }

    SequelArtworkPreference.setEnabled(true)
    try view.refreshArtwork()
    _ = try capture(view, to: output.appendingPathComponent("l3-\(number)-mac.png"))
    try check(view.directionArtBackingWidth == 32, "Mac mode did not recreate the native arrow at 2×")
    SequelArtworkPreference.setEnabled(false)
    try view.refreshArtwork()
    let restored = try capture(view, to: output.appendingPathComponent("l3-\(number)-restored.png"))
    try check(restored == pc, "Restoring PC mode changed the L3 direction picker")
    try check(view.cameraX == cameraX && view.cameraY == cameraY && view.game?.tick == tick,
        "L3 direction art changed the camera or simulation")
    window.contentView = nil
    print("PASS L3 tribe \(level.lemmingStyle): eight native arrows, click targets, PC/Mac backing and restoration")
}
