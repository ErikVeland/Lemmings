import CoreGraphics
import Foundation
import ImageIO
import NxlvKit
import UniformTypeIdentifiers

private struct Failure: Error, CustomStringConvertible {
    let description: String
}

private func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw Failure(description: message) }
}

private func writePNG(_ rgba: [UInt8], width: Int, height: Int, to url: URL) throws {
    try require(rgba.count == width * height * 4, "The preview has the wrong pixel count.")
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    guard let provider = CGDataProvider(data: Data(rgba) as CFData),
          let image = CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue).union(.byteOrder32Big),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
          ),
          let destination = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.png.identifier as CFString, 1, nil
          ) else { throw Failure(description: "Cannot start the PNG preview encoder.") }
    CGImageDestinationAddImage(destination, image, nil)
    try require(CGImageDestinationFinalize(destination), "Cannot write the PNG preview.")
}

private let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
private let styles = root.appendingPathComponent("Content/NeoLemmix/styles")
private let levels = root.appendingPathComponent("Content/NeoLemmix/levels")
private let previews = root.appendingPathComponent(".build/neolemmix-recreated-artwork/previews")
private let preparedResources = root.appendingPathComponent(".build/neolemmix-recreated-artwork/resources")
private let xmasExport = root.appendingPathComponent(".build/mac-artwork/export/xmas")
if FileManager.default.fileExists(atPath: xmasExport.appendingPathComponent("manifest.json").path) {
    let macDirectory = preparedResources.appendingPathComponent("MacArtwork")
    try FileManager.default.createDirectory(at: macDirectory, withIntermediateDirectories: true)
    let xmasLink = macDirectory.appendingPathComponent("xmas")
    let portsLink = preparedResources.appendingPathComponent("Ports")
    if !FileManager.default.fileExists(atPath: xmasLink.path) {
        try FileManager.default.createSymbolicLink(at: xmasLink, withDestinationURL: xmasExport)
    }
    if !FileManager.default.fileExists(atPath: portsLink.path) {
        try FileManager.default.createSymbolicLink(at: portsLink,
            withDestinationURL: root.appendingPathComponent("Sources/Ports"))
    }
}
private let artwork = NeoLemmixMacArtwork(resources: preparedResources)
private let resolver = NxlvStyleResolver(stylesRootURL: styles)

private func level(style: String, terrain: String?, object: String?, background: String? = nil) -> NxlvLevel {
    let terrainSection = terrain.map { """
        $TERRAIN
          STYLE \(style)
          PIECE \($0)
          X 4
          Y 4
        $END
        """ } ?? ""
    let objectSection = object.map { """
        $GADGET
          STYLE \(style)
          PIECE \($0)
          X 60
          Y 8
        $END
        """ } ?? ""
    let backgroundLine = background.map { "BACKGROUND \($0)" } ?? ""
    return NxlvLevel(text: """
        TITLE Recreated artwork fixture
        THEME orig_dirt
        WIDTH 160
        HEIGHT 96
        \(backgroundLine)
        \(terrainSection)
        \(objectSection)
        """)!
}

@MainActor private func render(_ level: NxlvLevel, mac: Bool,
    using selectedArtwork: NeoLemmixMacArtwork? = nil) throws -> NxlvRenderedLevel {
    let resolution = resolver.resolve(level: level)
    try require(resolution.isComplete, "A fixture style is unavailable.")
    let result = NxlvRenderer(retainsVisualLayers: true, macArtwork: mac ? (selectedArtwork ?? artwork) : nil)
        .render(level: level, resolution: resolution)
    try require(!result.hasErrors && result.renderedLevel != nil, "A fixture did not render.")
    return result.renderedLevel!
}

private func verify(_ original: NxlvRenderedLevel, _ recreated: NxlvRenderedLevel) throws {
    try require(original.rgba == recreated.rgba, "The source scene changed.")
    try require(original.terrainRGBA == recreated.terrainRGBA, "The source terrain changed.")
    try require(original.backgroundRGBA == recreated.backgroundRGBA, "The source background changed.")
    try require(original.foregroundRGBA == recreated.foregroundRGBA, "The source foreground changed.")
    try require(original.solidMask == recreated.solidMask, "The solid mask changed.")
    try require(original.steelMask == recreated.steelMask, "The steel mask changed.")
    try require(original.oneWayMask == recreated.oneWayMask, "The one-way mask changed.")
    try require(original.oneWayEligibleMask == recreated.oneWayEligibleMask, "The one-way eligible mask changed.")
    try require(original.terrainOpaqueMask == recreated.terrainOpaqueMask, "The terrain opacity mask changed.")
    try require(original.gadgets.count == recreated.gadgets.count, "The gadget count changed.")
    for (before, after) in zip(original.gadgets, recreated.gadgets) {
        try require(before.animationRGBA == after.animationRGBA, "The gadget source frames changed.")
        try require(before.secondaryAnimations.map(\.framesRGBA) == after.secondaryAnimations.map(\.framesRGBA),
            "The secondary source frames changed.")
        try require(before.effect == after.effect && before.x == after.x && before.y == after.y,
            "The gadget placement changed.")
    }
}

private func beachDetailMetrics(source: [UInt8], high: [UInt8], width: Int, height: Int)
    -> (isolated: Int, changed: Int) {
    let highWidth = width * 2
    func sameRGB(_ first: [UInt8], _ a: Int, _ second: [UInt8], _ b: Int) -> Bool {
        first[a] == second[b] && first[a + 1] == second[b + 1] && first[a + 2] == second[b + 2]
    }
    var isolated = 0, changed = 0
    for y in 0..<height { for x in 0..<width {
        let sourceOffset = (y * width + x) * 4
        guard source[sourceOffset + 3] > 0 else { continue }
        var marks: [(x: Int, y: Int, offset: Int)] = []
        for dy in 0..<2 { for dx in 0..<2 {
            let px = x * 2 + dx, py = y * 2 + dy
            let offset = (py * highWidth + px) * 4
            if !sameRGB(high, offset, source, sourceOffset) {
                changed += 1
                marks.append((px, py, offset))
            }
        } }
        guard x > 0, x + 1 < width, y > 0, y + 1 < height,
              source[sourceOffset + 3] == 255,
              source[sourceOffset - 4 + 3] == 255,
              source[sourceOffset + 4 + 3] == 255,
              source[sourceOffset - width * 4 + 3] == 255,
              source[sourceOffset + width * 4 + 3] == 255,
              marks.count == 1 else { continue }
        let mark = marks[0]
        let hasNeighbour = (-1...1).contains { dy in
            (-1...1).contains { dx in
                guard dx != 0 || dy != 0 else { return false }
                let offset = ((mark.y + dy) * highWidth + mark.x + dx) * 4
                return high[offset + 3] > 0 && sameRGB(high, offset, high, mark.offset)
            }
        }
        if !hasNeighbour { isolated += 1 }
    } }
    return (isolated, changed)
}

for sample in [
    (name: "xmas", style: "xmas", terrain: Optional<String>.none, object: Optional("exit")),
    (name: "orig-sega", style: "orig_sega", terrain: Optional("blocks_08"), object: Optional<String>.none),
    (name: "l2-beach", style: "l2_beach", terrain: Optional("sand_grassy_08"), object: Optional("exit")),
    (name: "l2-outdoor", style: "l2_outdoor", terrain: Optional<String>.none, object: Optional("plant")),
    (name: "l3-biolab", style: "l3_biolab", terrain: Optional("block_green_13"), object: Optional<String>.none)
] {
    let source = level(style: sample.style, terrain: sample.terrain, object: sample.object)
    let original = try render(source, mac: false)
    let recreated = try render(source, mac: true)
    try verify(original, recreated)
    if sample.terrain != nil {
        let high = recreated.macTerrainRGBA
        try require(high.count == recreated.width * recreated.height * 16, "The terrain has no 2× display plane.")
        try writePNG(original.terrainRGBA, width: original.width, height: original.height,
            to: previews.appendingPathComponent("\(sample.name)-terrain-original.png"))
        try writePNG(high, width: recreated.width * 2, height: recreated.height * 2,
            to: previews.appendingPathComponent("\(sample.name)-terrain-mac.png"))
        if sample.name == "l2-beach" {
            try require(high != NeoLemmixMacArtwork.doubled(original.terrainRGBA,
                width: original.width, height: original.height), "The non-stock terrain is only doubled.")
            let detail = beachDetailMetrics(source: original.terrainRGBA, high: high,
                width: original.width, height: original.height)
            try require(detail.isolated == 0, "The Beach terrain retains isolated colour flecks.")
            try require(detail.changed >= 500, "The Beach terrain lost its 2× detail.")
            print("Beach terrain detail: isolated=\(detail.isolated), changed=\(detail.changed)")
        }
    }
    if let gadget = recreated.gadgets.first, let sourceGadget = original.gadgets.first {
        try require(gadget.macAnimationRGBA.count == gadget.animationRGBA.count,
            "The object lost a 2× animation frame.")
        let originalFrame = sourceGadget.animationRGBA[0]
        let highFrame = gadget.macAnimationRGBA[0]
        try require(highFrame.count == gadget.width * gadget.height * 16,
            "The object has no 2× display frame.")
        try writePNG(originalFrame, width: gadget.width, height: gadget.height,
            to: previews.appendingPathComponent("\(sample.name)-object-original.png"))
        try writePNG(highFrame, width: gadget.width * 2, height: gadget.height * 2,
            to: previews.appendingPathComponent("\(sample.name)-object-mac.png"))
        if sample.name == "l2-beach" || sample.name == "l2-outdoor" {
            try require(highFrame != NeoLemmixMacArtwork.doubled(originalFrame,
                width: gadget.width, height: gadget.height), "The non-stock object is only doubled.")
        }
    }
    print("PASS \(sample.name) source parity and 2× preview")
}

let alphaAsset = resolver.resolve(level: level(style: "l2_beach", terrain: "sand_grassy_08", object: nil))
    .assets.first { $0.resolvedReference.kind == .terrain }!
let partial: [UInt8] = [
    180, 100, 30, 0, 180, 100, 30, 128, 180, 100, 30, 255,
    150, 80, 20, 255, 180, 100, 30, 128, 220, 145, 55, 255,
    180, 100, 30, 255, 150, 80, 20, 128, 180, 100, 30, 0
]
let partialHigh = artwork.recreated(asset: alphaAsset, width: 3, height: 3, rgba: partial)
try require(partialHigh == artwork.recreated(asset: alphaAsset, width: 3, height: 3, rgba: partial),
    "Recreation is not deterministic.")
for y in 0..<3 { for x in 0..<3 {
    let alpha = partial[(y * 3 + x) * 4 + 3]
    for dy in 0..<2 { for dx in 0..<2 {
        try require(partialHigh[((y * 2 + dy) * 6 + x * 2 + dx) * 4 + 3] == alpha,
            "Recreation changed a source alpha value.")
    } }
} }
print("PASS partial alpha and repeatability")

let backgroundLevel = level(style: "l2_beach", terrain: nil, object: "cloud_01",
    background: "orig_dirt:nessy")
let plainBackground = try render(backgroundLevel, mac: false)
let detailedBackground = try render(backgroundLevel, mac: true)
try verify(plainBackground, detailedBackground)
try require(detailedBackground.macBackgroundRGBA.count == detailedBackground.width * detailedBackground.height * 16,
    "The background lost its 2× display plane.")
try writePNG(plainBackground.backgroundRGBA, width: plainBackground.width, height: plainBackground.height,
    to: previews.appendingPathComponent("background-original.png"))
try writePNG(detailedBackground.macBackgroundRGBA,
    width: detailedBackground.width * 2, height: detailedBackground.height * 2,
    to: previews.appendingPathComponent("background-mac.png"))
print("PASS tiled background and static background object")

if FileManager.default.fileExists(atPath: xmasExport.appendingPathComponent("manifest.json").path) {
    let fallbackArtwork = NeoLemmixMacArtwork(resources: root.appendingPathComponent("Content"))
    var exactCount = 0
    for piece in ["exit", "fireplace", "jack", "jack_box", "lights", "snowman", "window"] {
        let fixture = level(style: "xmas", terrain: nil, object: piece)
        let reference = try render(fixture, mac: true)
        let inferred = try render(fixture, mac: true, using: fallbackArtwork)
        if reference.gadgets.first?.macAnimationRGBA != inferred.gadgets.first?.macAnimationRGBA {
            exactCount += 1
        }
    }
    print("XMAS verified-Mac-substitutions=\(exactCount)/7; remaining pieces use reconstruction")
}

let beachLevelURL = levels.appendingPathComponent(
    "NeoLemmix_Introduction_Pack/Basic_Training_2/Sandy_Danger.nxlv")
let beachLevel = NxlvLevel(text: try String(contentsOf: beachLevelURL, encoding: .utf8))!
let plainBeach = try render(beachLevel, mac: false)
let detailedBeach = try render(beachLevel, mac: true)
try verify(plainBeach, detailedBeach)
let beachTerrain = try NeoLemmixTerrain(
    width: plainBeach.width, height: plainBeach.height,
    solidMask: plainBeach.solidMask, steelMask: plainBeach.steelMask,
    oneWayMask: plainBeach.oneWayMask, visualOpaqueMask: plainBeach.terrainOpaqueMask)
let plainScene = NeoLemmixSceneFrame.rgba(plainBeach, terrain: beachTerrain)
let detailedScene = NeoLemmixSceneFrame.rgba(detailedBeach, terrain: beachTerrain, useMacArtwork: true)
try writePNG(plainScene, width: plainBeach.width, height: plainBeach.height,
    to: previews.appendingPathComponent("sandy-danger-original.png"))
try writePNG(detailedScene, width: detailedBeach.width * 2, height: detailedBeach.height * 2,
    to: previews.appendingPathComponent("sandy-danger-mac.png"))
try require(detailedScene != NeoLemmixMacArtwork.doubled(plainScene,
    width: plainBeach.width, height: plainBeach.height), "The composed scene is only doubled.")
print("PASS Sandy Danger composed scene previews")

if CommandLine.arguments.contains("--all-bundled") {
    let styleDirectories = (try FileManager.default.contentsOfDirectory(
        at: styles, includingPropertiesForKeys: [.isDirectoryKey]))
        .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
    var styleFixtures = 0
    for directory in styleDirectories {
        let style = directory.lastPathComponent
        let terrainDirectory = directory.appendingPathComponent("terrain")
        let terrainPiece = (try? FileManager.default.contentsOfDirectory(
            at: terrainDirectory, includingPropertiesForKeys: nil))?
            .filter { $0.pathExtension.lowercased() == "png" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .first?.deletingPathExtension().lastPathComponent
        let objectPiece = FileManager.default.fileExists(
            atPath: directory.appendingPathComponent("objects/exit.nxmo").path)
            ? "exit" : "fallback"
        let fixture = level(style: style, terrain: terrainPiece, object: objectPiece)
        let plain = try render(fixture, mac: false)
        let mac = try render(fixture, mac: true)
        try verify(plain, mac)
        if terrainPiece != nil {
            try require(mac.macTerrainRGBA.count == mac.width * mac.height * 16,
                "A bundled style lacks a 2× terrain plane: \(style)")
        }
        try require(mac.gadgets.first?.macAnimationRGBA.first?.count
            == mac.gadgets.first.map { $0.width * $0.height * 16 },
            "A bundled style lacks a 2× object frame: \(style)")
        let terrain = try NeoLemmixTerrain(width: plain.width, height: plain.height,
            solidMask: plain.solidMask, steelMask: plain.steelMask,
            oneWayMask: plain.oneWayMask, visualOpaqueMask: plain.terrainOpaqueMask)
        let originalScene = NeoLemmixSceneFrame.rgba(plain, terrain: terrain)
        let macScene = NeoLemmixSceneFrame.rgba(mac, terrain: terrain, useMacArtwork: true)
        try writePNG(NeoLemmixMacArtwork.doubled(originalScene, width: plain.width, height: plain.height),
            width: plain.width * 2, height: plain.height * 2,
            to: previews.appendingPathComponent("bundled/\(style)-original.png"))
        try writePNG(macScene, width: mac.width * 2, height: mac.height * 2,
            to: previews.appendingPathComponent("bundled/\(style)-mac.png"))
        styleFixtures += 1
    }
    print("BUNDLED style-fixtures=\(styleFixtures)")
    try require(styleFixtures == 26, "The bundled style audit did not cover all 26 styles.")

    let files = (FileManager.default.enumerator(at: levels, includingPropertiesForKeys: nil)?.allObjects as? [URL] ?? [])
        .filter { $0.pathExtension == "nxlv" }.sorted { $0.path < $1.path }
    var checked = 0, missingStyle = 0, otherUnresolved = 0, failedRenders = 0
    var stylesChecked: Set<String> = []
    for file in files {
        guard let source = NxlvLevel(text: try String(contentsOf: file, encoding: .utf8)) else {
            otherUnresolved += 1
            continue
        }
        let resolution = resolver.resolve(level: source)
        guard resolution.isComplete else {
            if resolution.diagnostics.contains(where: { $0.code == .missingStyle }) { missingStyle += 1 }
            else { otherUnresolved += 1 }
            continue
        }
        let plainResult = NxlvRenderer(retainsVisualLayers: true).render(level: source, resolution: resolution)
        let macResult = NxlvRenderer(retainsVisualLayers: true, macArtwork: artwork)
            .render(level: source, resolution: resolution)
        guard !plainResult.hasErrors, !macResult.hasErrors,
              let plain = plainResult.renderedLevel, let mac = macResult.renderedLevel else {
            failedRenders += 1
            continue
        }
        try verify(plain, mac)
        if mac.solidMask.contains(where: { $0 != 0 }) {
            try require(mac.macTerrainRGBA.count == mac.width * mac.height * 16,
                "A bundled level lost the 2× terrain plane: \(file.lastPathComponent)")
        }
        for gadget in mac.gadgets {
            try require(gadget.macAnimationRGBA.count == gadget.animationRGBA.count,
                "A bundled object lost 2× animation frames: \(file.lastPathComponent)")
            for frame in gadget.macAnimationRGBA {
                try require(frame.count == gadget.width * gadget.height * 16,
                    "A bundled object has an incomplete 2× frame: \(file.lastPathComponent)")
            }
            for animation in gadget.secondaryAnimations {
                try require(animation.macFramesRGBA.count == animation.framesRGBA.count,
                    "A bundled secondary animation lost 2× frames: \(file.lastPathComponent)")
            }
        }
        let oldConfig = try NeoLemmixSimulation(level: source, renderedLevel: plain).configuration
        let macConfig = try NeoLemmixSimulation(level: source, renderedLevel: mac).configuration
        try require(oldConfig == macConfig, "The simulation configuration changed: \(file.lastPathComponent)")
        stylesChecked.insert(source.themeStyle)
        checked += 1
    }
    print("BUNDLED levels=\(files.count) rendered=\(checked) missing-style=\(missingStyle) other-unresolved=\(otherUnresolved) render-failures=\(failedRenders) themes=\(stylesChecked.count)")
    try require(files.count == checked + missingStyle + otherUnresolved + failedRenders,
        "The bundled audit did not account for every level.")
    try require(checked > 0 && failedRenders == 0, "The bundled artwork audit found a render failure.")
}
