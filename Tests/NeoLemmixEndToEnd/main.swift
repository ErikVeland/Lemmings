import CoreGraphics
import Foundation
import ImageIO
import NxlvKit
import UniformTypeIdentifiers

// Drives one unofficial level through the whole unofficial pipeline:
// .nxlv text -> parse -> resolve styles -> render -> simulate.
// Each stage already had tests. Nothing joined them, so a break between two
// stages would not have been caught.

private struct Failure: Error, CustomStringConvertible {
    let description: String
}

private func require(
    _ condition: @autoclosure () -> Bool, _ message: @autoclosure () -> String
) throws {
    guard condition() else { throw Failure(description: message()) }
}

private func writePNG(width: Int, height: Int, rgba: [UInt8], to url: URL) throws {
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    guard let provider = CGDataProvider(data: Data(rgba) as CFData),
        let image = CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue)
                .union(.byteOrder32Big),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent),
        let destination = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { throw Failure(description: "could not encode \(url.lastPathComponent)") }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw Failure(description: "could not write \(url.lastPathComponent)")
    }
}

private func solidBlock(width: Int, height: Int, red: UInt8, green: UInt8, blue: UInt8) -> [UInt8] {
    var pixels: [UInt8] = []
    pixels.reserveCapacity(width * height * 4)
    for _ in 0..<(width * height) { pixels.append(contentsOf: [red, green, blue, 255]) }
    return pixels
}

private func write(_ text: String, to url: URL) throws {
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(text.utf8).write(to: url)
}

private func buildStyles(at root: URL) throws {
    let style = root.appendingPathComponent("testpack")

    // A wide floor the lemmings can walk along.
    try writePNG(
        width: 200, height: 8,
        rgba: solidBlock(width: 200, height: 8, red: 200, green: 120, blue: 40),
        to: style.appendingPathComponent("terrain/ground.png"))

    try writePNG(
        width: 16, height: 16,
        rgba: solidBlock(width: 16, height: 16, red: 60, green: 90, blue: 220),
        to: style.appendingPathComponent("objects/hatch.png"))
    try write(
        """
        EFFECT ENTRANCE
        TRIGGER_X 4
        TRIGGER_Y 12
        TRIGGER_WIDTH 8
        TRIGGER_HEIGHT 4
        $PRIMARY_ANIMATION
          FRAMES 1
        $END
        """,
        to: style.appendingPathComponent("objects/hatch.nxmo"))

    try writePNG(
        width: 16, height: 16,
        rgba: solidBlock(width: 16, height: 16, red: 40, green: 200, blue: 90),
        to: style.appendingPathComponent("objects/door.png"))
    try write(
        """
        EFFECT EXIT
        TRIGGER_X 2
        TRIGGER_Y 10
        TRIGGER_WIDTH 12
        TRIGGER_HEIGHT 6
        $PRIMARY_ANIMATION
          FRAMES 1
        $END
        """,
        to: style.appendingPathComponent("objects/door.nxmo"))
}

private let levelText = """
    TITLE End to end
    AUTHOR harness
    WIDTH 200
    HEIGHT 100
    LEMMINGS 10
    SAVE_REQUIREMENT 1
    SPAWN_INTERVAL 20
    $SKILLSET
      BASHER 5
      DIGGER 5
    $END
    $TERRAIN
      STYLE testpack
      PIECE ground
      X 0
      Y 70
    $END
    $GADGET
      STYLE testpack
      PIECE hatch
      X 20
      Y 40
    $END
    $GADGET
      STYLE testpack
      PIECE door
      X 150
      Y 60
    $END
    """

let fixture = FileManager.default.temporaryDirectory
    .appendingPathComponent("nxlv-e2e-\(UUID().uuidString)")
let styles = fixture.appendingPathComponent("styles")

do {
    defer { try? FileManager.default.removeItem(at: fixture) }
    try buildStyles(at: styles)

    // 1. Parse
    guard let level = NxlvLevel(text: levelText) else {
        throw Failure(description: "the level text did not parse")
    }
    try require(level.width == 200, "level width did not parse")
    try require(level.lemmingsCount == 10, "lemming count did not parse")
    print("PASS parse — '\(level.title)' \(level.width)x\(level.height)")

    // 2. Resolve styles
    let resolver = NxlvStyleResolver(stylesRootURL: styles)
    let resolution = resolver.resolve(level: level)
    for diagnostic in resolution.diagnostics {
        print("     style diagnostic: \(diagnostic.severity) \(diagnostic.message)")
    }
    try require(resolution.isComplete, "style resolution reported errors")
    print("PASS resolve — \(resolution.assets.count) assets")

    // 3. Render
    let result = NxlvRenderer().render(level: level, resolution: resolution)
    for diagnostic in result.diagnostics {
        print("     render diagnostic: \(diagnostic.severity) \(diagnostic.message)")
    }
    let rendered = try {
        guard let rendered = result.renderedLevel else {
            throw Failure(description: "the level did not render")
        }
        return rendered
    }()
    try require(!result.hasErrors, "rendering reported errors")
    let solidCount = rendered.solidMask.reduce(0) { $0 + ($1 != 0 ? 1 : 0) }
    try require(solidCount > 0, "rendered level has no solid terrain")
    print(
        "PASS render — \(rendered.width)x\(rendered.height),"
            + " \(solidCount) solid pixels, \(rendered.gadgets.count) gadgets")

    for skill in ["FENCER", "LASERER"] {
        let unsupported = NxlvLevel(text: levelText.replacingOccurrences(of: "BASHER 5", with: "\(skill) 1"))!
        do {
            _ = try NeoLemmixSimulation(level: unsupported, renderedLevel: rendered)
            throw Failure(description: "A level requiring \(skill) was allowed to start")
        } catch let error as NeoLemmixSimulationError {
            try require(error.description.contains(skill.capitalized), "Unsupported skill error did not name the missing action")
        }
        let unused = NxlvLevel(text: levelText.replacingOccurrences(of: "BASHER 5", with: "\(skill) 0"))!
        _ = try NeoLemmixSimulation(level: unused, renderedLevel: rendered)
    }
    let hatchMetadata = styles.appendingPathComponent("testpack/objects/hatch.nxmo")
    let originalMetadata = try String(contentsOf: hatchMetadata, encoding: .utf8)
    for effect in ["TELEPORTER", "LOCKEDEXIT", "UPDRAFT", "FORCELEFT"] {
        try write(originalMetadata.replacingOccurrences(of: "ENTRANCE", with: effect), to: hatchMetadata)
        let changed = NxlvRenderer().render(level: level, resolution: NxlvStyleResolver(stylesRootURL: styles).resolve(level: level))
        guard let image = changed.renderedLevel else { throw Failure(description: "Unsupported gadget test did not render") }
        do {
            _ = try NeoLemmixSimulation(level: level, renderedLevel: image)
            throw Failure(description: "A level requiring \(effect) was allowed to start")
        } catch let error as NeoLemmixSimulationError {
            try require(error.description.contains("not yet supported"), "Missing gadget was not explained")
        }
    }
    try write(originalMetadata, to: hatchMetadata)
    print("PASS unsupported skills and gadgets are rejected before gameplay; zero-stock skills remain allowed")

    // 4. Simulate
    var simulation = try NeoLemmixSimulation(level: level, renderedLevel: rendered)
    try require(
        !simulation.configuration.entrances.isEmpty,
        "no entrance was derived from the gadgets")
    let exits = simulation.configuration.zones.filter { $0.effect == .exit }
    try require(!exits.isEmpty, "no exit zone was derived from the gadgets")
    print(
        "PASS configure — \(simulation.configuration.entrances.count) entrance(s),"
            + " \(exits.count) exit zone(s)")
    for entrance in simulation.configuration.entrances {
        print("     entrance at \(entrance.position.x),\(entrance.position.y)")
    }
    for zone in exits {
        print(
            "     exit zone x \(zone.bounds.x)..\(zone.bounds.x + zone.bounds.width)"
                + " y \(zone.bounds.y)..\(zone.bounds.y + zone.bounds.height)")
    }

    var moved = false
    var firstPositions: [Int: NeoLemmixPoint] = [:]
    for _ in 0..<(NeoLemmixRules.ticksPerSecond * 90) {
        _ = simulation.tick()
        for lemming in simulation.lemmings where lemming.isActive {
            if let seen = firstPositions[lemming.id] {
                if seen != lemming.position { moved = true }
            } else {
                firstPositions[lemming.id] = lemming.position
            }
        }
        if simulation.isComplete { break }
    }

    let sample = simulation.lemmings.prefix(3).map {
        "#\($0.id) at \($0.position.x),\($0.position.y) \($0.action) active=\($0.isActive)"
    }
    print("     sample lemmings: \(sample.joined(separator: " | "))")
    try require(simulation.releasedCount > 0, "no lemmings were released")
    try require(moved, "lemmings were released but never moved")
    try require(
        simulation.savedCount > 0,
        "no lemming reached the exit, so the exit trigger never fired")
    print(
        "PASS simulate — released \(simulation.releasedCount),"
            + " saved \(simulation.savedCount), tick \(simulation.tickCount)")
    print("NeoLemmix end-to-end tests passed.")
} catch {
    FileHandle.standardError.write(Data("NeoLemmix end-to-end failed: \(error)\n".utf8))
    exit(1)
}
