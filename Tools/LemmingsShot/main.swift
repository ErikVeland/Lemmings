import AppKit
import NxlvKit

// Renders the real game views offscreen to a PNG. This verifies drawing
// without needing screen-capture permission, and gives the test suite a way to
// inspect frames.

private struct ShotError: Error, CustomStringConvertible {
    let description: String
}

@MainActor
private func render(
    directory: URL, levelIndex: Int, ticks: Int, zoom: Double, size: CGSize, output: URL
) throws {
    let campaign = try ClassicCampaignDefinition.originalDOSLemmings.load(from: directory)
    let assets = try ClassicMainDATAssets.load(from: directory)
    guard levelIndex < campaign.levels.count else {
        throw ShotError(description: "level index out of range")
    }
    let entry = campaign.levels[levelIndex]
    let level = entry.level
    let ground = try ClassicGroundSet.load(style: level.groundStyle, from: directory)
    let special = level.specialStyle > 0
        ? try ClassicSpecialGraphic.load(index: level.specialStyle - 1, from: directory)
        : nil
    let rendered = try ClassicLevelRenderer.render(
        level, groundSet: ground, specialGraphic: special)

    guard let provider = CGDataProvider(data: rendered.rgba as CFData),
        let image = CGImage(
            width: rendered.width, height: rendered.height, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: rendered.width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    else { throw ShotError(description: "could not build the level image") }

    var simulation = try ClassicDOSSimulation(
        level: level, renderedLevel: rendered, mainDATAssets: assets)
    for _ in 0..<ticks where !simulation.isComplete { _ = simulation.tick() }

    let panel = PanelView()
    let playfield = PlayfieldView()

    let panelHeight = panel.intrinsicHeight
    playfield.frame = CGRect(x: 0, y: 0, width: size.width, height: size.height - panelHeight)
    panel.frame = CGRect(x: 0, y: 0, width: size.width, height: panelHeight)

    playfield.levelImage = image
    playfield.assets = assets
    playfield.palette = (try? ClassicLemmingPalette.inLevelVGA(
        terrainPalette: ground.terrainPalette)) ?? []
    let session = ClassicSession(
        simulation: simulation, width: rendered.width, height: rendered.height)
    playfield.session = session
    playfield.viewport.zoom = zoom
    playfield.viewport.levelSize = CGSize(width: rendered.width, height: rendered.height)
    playfield.viewport.viewSize = playfield.frame.size
    if let entrance = simulation.configuration.entrances.first {
        playfield.viewport.center(on: Double(entrance.x))
    }

    let panelPalette = ClassicLemmingPalette.panelVGA
    if let graphics = assets.panel {
        let bytes = graphics.rgba(using: panelPalette)
        if let provider = CGDataProvider(data: bytes as CFData) {
            panel.panelImage = CGImage(
                width: graphics.width, height: graphics.height, bitsPerComponent: 8,
                bitsPerPixel: 32, bytesPerRow: graphics.width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                provider: provider, decode: nil, shouldInterpolate: false,
                intent: .defaultIntent)
        }
    }
    panel.session = session
    // Mirror the app: arm the first skill the level actually provides.
    panel.selectedSkillIndex = session.skills.firstIndex { $0.count > 0 } ?? 0
    panel.levelSize = playfield.viewport.levelSize
    panel.visibleLevelRect = playfield.viewport.visibleLevelRect
    panel.statusText =
        "\(entry.rank) \(entry.number) — \(level.title.trimmingCharacters(in: .whitespaces))"
        + "   Out \(simulation.releasedCount)/\(simulation.configuration.totalLemmings)"
        + "   Home \(simulation.savedCount)/\(simulation.configuration.requiredToSave)"
        + "   Rate \(simulation.releaseRate)   tick \(simulation.tickCount)"

    // Each view is rendered on its own. A windowless parent does not reliably
    // recurse into its subviews during cacheDisplay.
    func bitmap(of view: NSView) throws -> NSBitmapImageRep {
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            throw ShotError(description: "could not allocate a bitmap")
        }
        view.cacheDisplay(in: view.bounds, to: rep)
        return rep
    }

    let playfieldRep = try bitmap(of: playfield)
    let panelRep = try bitmap(of: panel)

    // Compose in the default bottom-left origin space. The panel sits below
    // the playfield, so it draws at y = 0.
    let composed = NSImage(size: size)
    composed.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .none
    NSColor.black.setFill()
    CGRect(origin: .zero, size: size).fill()
    panelRep.draw(in: CGRect(x: 0, y: 0, width: size.width, height: panelHeight))
    playfieldRep.draw(in: CGRect(
        x: 0, y: panelHeight, width: size.width, height: playfield.frame.height))
    composed.unlockFocus()

    guard let tiff = composed.tiffRepresentation,
        let rep = NSBitmapImageRep(data: tiff),
        let png = rep.representation(using: .png, properties: [:])
    else { throw ShotError(description: "could not encode PNG") }
    try png.write(to: output)

    let active = simulation.lemmings.filter(\.isActive).count
    print(
        "wrote \(output.lastPathComponent) — \(entry.rank) \(entry.number)"
            + " '\(level.title.trimmingCharacters(in: .whitespaces))'"
            + " tick \(simulation.tickCount), \(active) active, \(png.count) bytes")
}

// MARK: - Entry point

let arguments = CommandLine.arguments
func value(_ flag: String, _ fallback: String) -> String {
    guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else {
        return fallback
    }
    return arguments[index + 1]
}

let directory = URL(fileURLWithPath: value("--data", "Content/lemming1.pc"), isDirectory: true)
let levelIndex = Int(value("--level", "1"))! - 1
let ticks = Int(value("--ticks", "150"))!
let zoom = Double(value("--zoom", "3"))!
let output = URL(fileURLWithPath: value("--out", "shot.png"))

_ = NSApplication.shared
NSApplication.shared.setActivationPolicy(.prohibited)

do {
    try MainActor.assumeIsolated {
        try render(
            directory: directory, levelIndex: levelIndex, ticks: ticks, zoom: zoom,
            size: CGSize(width: 1000, height: 620), output: output)
    }
} catch {
    FileHandle.standardError.write(Data("Shot failed: \(error)\n".utf8))
    exit(1)
}
