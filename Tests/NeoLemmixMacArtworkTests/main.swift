import Foundation
import NxlvKit

func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw NSError(domain: message, code: 1) }
}
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resources = ProcessInfo.processInfo.environment["LEMMINGS_TEST_APP"].map { URL(fileURLWithPath: $0).appendingPathComponent("Contents/Resources") }
    ?? root.appendingPathComponent(".build/local/Ultimate Lemmings.app/Contents/Resources")
let styles = resources.appendingPathComponent("NeoLemmix/styles")
let mac = NeoLemmixMacArtwork(resources: resources)
let resolver = NxlvStyleResolver(stylesRootURL: styles)
let redux = resources.appendingPathComponent("NeoLemmix/levels/Lemmings_Redux")
let files = (FileManager.default.enumerator(at: redux, includingPropertiesForKeys: nil)!.allObjects as! [URL])
    .filter { $0.pathExtension == "nxlv" }.sorted { $0.path < $1.path }
// Transform the authored subpixels, including rotation followed by both flips.
@MainActor func tile(_ flags: String) -> NxlvRenderedLevel {
    let level = NxlvLevel(text: """
    TITLE Mac transform
    THEME orig_dirt
    WIDTH 64
    HEIGHT 64
    $TERRAIN
      STYLE orig_dirt
      PIECE clump_02
      X 0
      Y 0
      \(flags)
    $END
    """)!
    return NxlvRenderer(retainsVisualLayers: true, macArtwork: mac).render(level: level, resolution: resolver.resolve(level: level)).renderedLevel!
}
let untransformed = tile("")
try require(!untransformed.macTerrainRGBA.isEmpty, "Transform fixture lacks Mac artwork")
for rotate in [false, true] { for flipX in [false, true] { for flipY in [false, true] {
    let flags = [(rotate, "ROTATE"), (flipX, "FLIP_HORIZONTAL"), (flipY, "FLIP_VERTICAL")]
        .filter { $0.0 }.map { $0.1 }.joined(separator: "\n")
    let transformed = tile(flags)
    let w = rotate ? 54 : 64, h = rotate ? 64 : 54
    for y in 0..<54 { for x in 0..<64 {
        var dx = rotate ? 53 - y : x, dy = rotate ? x : y
        if flipX { dx = w - 1 - dx }; if flipY { dy = h - 1 - dy }
        let from = (y * 128 + x) * 4, to = (dy * 128 + dx) * 4
        try require(untransformed.macTerrainRGBA[from..<from + 4] == transformed.macTerrainRGBA[to..<to + 4],
            "Mac subpixels did not follow terrain transform: \(flags)")
    } }
} } }
print("PASS all eight terrain rotations/flips at native Mac resolution")
var themes = Set<String>(), checked = 0, matched = 0, gadgets = 0
let all = CommandLine.arguments.contains("--all-redux")
for url in files {
    let level = NxlvLevel(text: try String(contentsOf: url, encoding: .utf8))!
    guard all || !themes.contains(level.themeStyle) || url.lastPathComponent == "Just_dig!.nxlv" else { continue }
    themes.insert(level.themeStyle)
    let resolution = resolver.resolve(level: level)
    let original = NxlvRenderer(retainsVisualLayers: true).render(level: level, resolution: resolution).renderedLevel!
    let replacement = NxlvRenderer(retainsVisualLayers: true, macArtwork: mac).render(level: level, resolution: resolution).renderedLevel!
    try require(original.rgba == replacement.rgba && original.terrainRGBA == replacement.terrainRGBA,
        "Mac substitutions changed original pixels: \(url.lastPathComponent)")
    try require(original.solidMask == replacement.solidMask && original.steelMask == replacement.steelMask
        && original.oneWayMask == replacement.oneWayMask && original.oneWayEligibleMask == replacement.oneWayEligibleMask
        && original.terrainOpaqueMask == replacement.terrainOpaqueMask, "Mac substitutions changed physics masks")
    let oldConfig = try NeoLemmixSimulation(level: level, renderedLevel: original)
    var simulation = try NeoLemmixSimulation(level: level, renderedLevel: replacement)
    try require(oldConfig.configuration == simulation.configuration, "Mac substitutions changed triggers or rules")
    if !replacement.macTerrainRGBA.isEmpty {
        matched += 1
        try require(replacement.macTerrainRGBA.count == replacement.width * replacement.height * 16, "Mac terrain lost native resolution")
        try require(replacement.macTerrainRGBA != NeoLemmixMacArtwork.doubled(original.terrainRGBA, width: original.width, height: original.height), "Mac terrain is only an upscale")
        for i in replacement.solidMask.indices {
            let x = i % replacement.width, y = i / replacement.width
            let offsets = [0, 1, replacement.width * 2, replacement.width * 2 + 1].map { ((y * 2) * replacement.width * 2 + x * 2 + $0) * 4 + 3 }
            try require(offsets.contains(where: { replacement.macTerrainRGBA[$0] > 0 }) == (replacement.solidMask[i] != 0), "Visible Mac terrain disagrees with solidity")
        }
    }
    gadgets += replacement.gadgets.filter { $0.macAnimationRGBA.contains(where: { !$0.isEmpty }) }.count
    if url.lastPathComponent == "Just_dig!.nxlv" {
        try require(replacement.gadgets.allSatisfy { $0.macAnimationRGBA.allSatisfy { !$0.isEmpty } }, "Just dig entrance/exit did not map")
        for _ in 0..<160 { _ = simulation.tick() }
        let before = simulation
        func picture(_ sim: NeoLemmixSimulation) -> [UInt8] {
            NeoLemmixSceneFrame.rgba(replacement, terrain: sim.terrain, zones: sim.configuration.zones,
                disabledZoneIDs: sim.disabledZoneIDs, gadgetAnimationFrames: sim.gadgetAnimationFrames,
                tickCount: sim.tickCount, entranceOpenTick: sim.configuration.entranceOpenTick, useMacArtwork: true)
        }
        let saved = picture(before)
        _ = simulation.enqueue(.assign(lemmingID: 0, skill: .digger))
        for _ in 0..<35 { _ = simulation.tick() }
        let dug = picture(simulation)
        try require(dug != saved, "Digging did not update the Mac picture")
        let removed = replacement.solidMask.indices.filter { before.terrain.solidMask[$0] != 0 && simulation.terrain.solidMask[$0] == 0 }
        try require(!removed.isEmpty, "Dig fixture removed no terrain")
        for i in removed {
            let x = i % replacement.width, y = i / replacement.width
            for dy in 0..<2 { for dx in 0..<2 {
                try require(dug[((y * 2 + dy) * replacement.width * 2 + x * 2 + dx) * 4 + 3] == 0,
                    "Dug logical cell left a Mac pixel behind")
            } }
        }
        try require(picture(before) == saved, "Restored simulation did not restore the Mac picture")
        var constructed = before.terrain
        let empty = constructed.solidMask.firstIndex(of: 0)!
        let cx = empty % replacement.width, cy = empty / replacement.width
        constructed.setConstructiveSolid(x: cx, y: cy, shade: 3)
        let built = NeoLemmixSceneFrame.rgba(replacement, terrain: constructed, useMacArtwork: true)
        let color = NeoLemmixSceneFrame.constructiveColor(replacement.constructiveRGBA, shade: 3)
        for dy in 0..<2 { for dx in 0..<2 {
            let p = ((cy * 2 + dy) * replacement.width * 2 + cx * 2 + dx) * 4
            try require(Array(built[p..<p + 4]) == color, "Construction did not fill the correct Mac cell")
        } }
    }
    checked += 1
    print("PASS \(level.themeStyle): \(url.lastPathComponent)")
}
try require(checked >= 9 && matched >= 9 && gadgets > 0, "Insufficient original-theme coverage")
print("PASS \(checked) Redux levels, \(matched) Mac terrain scenes, \(gadgets) Mac gadgets; original pixels, masks and configuration unchanged")
