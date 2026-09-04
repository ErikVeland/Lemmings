import Foundation
import NxlvKit

func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw SequelDataError.invalid(message) }
}
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let exported = root.appendingPathComponent(".build/amiga-artwork/export")
for family in ["lemmings", "ohno", "xmas", "holiday"] {
    let artwork = try ClassicMacArtwork(directory: exported.appendingPathComponent(family))
    for pose in ClassicLemmingPose.allCases {
        for left in [false, true] {
            for tick in 0..<32 {
                try require(artwork.lemming(pose: pose, left: left, tick: tick) != nil,
                    "Missing Amiga animation: \(family) \(pose)")
            }
        }
    }
}
let folders = [
    ("lemmings", "Content/lemming1.pc"),
    ("ohno", "Sources/Ports/oh_no_more_lemmings_dos-1991-11-14_2232"),
    ("xmas", "Sources/Ports/xmas_dos_XmasLemmingsV1.9"),
    ("xmas", "Sources/Ports/xmas_dos_XmasLemmingsV1.9a1"),
    ("holiday", ".build/local/Lemmings Local.app/Contents/Resources/Ports/holiday_native_1993"),
    ("holiday", ".build/local/Lemmings Local.app/Contents/Resources/Ports/holiday_native_1994")]
var checked = 0
for (family, path) in folders {
    let art = try ClassicMacArtwork(directory: exported.appendingPathComponent(family))
    let directory = root.appendingPathComponent(path)
    let campaign = try ClassicDataSet.detect(directory: directory).campaign
    let assets = try ClassicMainDATAssets.load(from: directory)
    var grounds: [Int: ClassicGroundSet] = [:]
    for entry in campaign.levels {
        let level = entry.level
        if grounds[level.groundStyle] == nil { grounds[level.groundStyle] = try ClassicGroundSet.load(style: level.groundStyle, from: directory) }
        let special = level.specialStyle > 0 ? try ClassicSpecialGraphic.load(index: level.specialStyle - 1, from: directory) : nil
        let rendered = try ClassicLevelRenderer.render(level, groundSet: grounds[level.groundStyle]!, specialGraphic: special)
        let scene: ClassicMacScene
        do { scene = try ClassicMacScene(level: level, rendered: rendered, artwork: art, groundSet: grounds[level.groundStyle]) }
        catch { FileHandle.standardError.write(Data("\(family) \(entry.rank) \(entry.number): \(level.title): \(error)\n".utf8)); throw error }
        try require(scene.width == 3200 && scene.height == 320, "Amiga resolution was lost")
        for object in level.objects {
            guard let defs = art.objects[level.groundStyle], defs.indices.contains(object.id), defs[object.id].count > 0 else {
                throw SequelDataError.invalid("Missing Amiga object: \(family) \(level.title) \(object.id)")
            }
            let seq = defs[object.id]
            for frame in 0..<seq.count {
                try require(art.frame(1600 + level.groundStyle, seq.base + frame) != nil, "Missing Amiga object frame")
            }
        }
        if checked == 0 {
            var sim = try ClassicDOSSimulation(level: level, renderedLevel: rendered, mainDATAssets: assets)
            let closed = scene.rgba(simulation: sim)
            let hatch = rendered.objects.first { $0.placement.id == 1 }!
            let seq = art.objects[level.groundStyle]![1]
            let closedFrame = art.frame(1600 + level.groundStyle, seq.base + seq.first)!
            for y in 0..<closedFrame.height { for x in 0..<closedFrame.width {
                let source = (y * closedFrame.width + x) * 4
                guard closedFrame.rgba[source+3] != 0 else { continue }
                let target = ((hatch.placement.y * 2 + closedFrame.y + y) * scene.width
                    + hatch.placement.x * 2 + closedFrame.x + x) * 4
                try require(closed[target..<target+4] == closedFrame.rgba[source..<source+4],
                    "Amiga entrance did not start on its authored closed frame")
            } }
            for _ in 0..<148 { _ = sim.tick() }
            let before = scene.rgba(simulation: sim)
            try require(before.count == 3200 * 320 * 4, "Bad composed Amiga frame")
            let tick = sim.tickCount
            _ = scene.rgba(simulation: sim)
            try require(sim.tickCount == tick, "Rendering changed the simulation")
            try require(sim.assign(.digger, to: 0) == .assigned, "Could not start digger")
            for _ in 0..<30 { _ = sim.tick() }
            let dug = scene.rgba(simulation: sim)
            let removed = rendered.solidMask.indices.filter { rendered.solidMask[$0] != 0 && sim.terrain.solidMask[$0] == 0 }
            try require(!removed.isEmpty, "No terrain was removed")
            for i in removed {
                let x = i % rendered.width * 2, y = i / rendered.width * 2
                for dy in 0..<2 { for dx in 0..<2 {
                    try require(dug[((y + dy) * scene.width + x + dx) * 4 + 3] == 0,
                        "A dug pixel remains visible in Amiga artwork")
                } }
            }
            var history = ClassicDOSRewind(simulation: sim)
            let saved = scene.rgba(simulation: history.simulation)
            for _ in 0..<10 { _ = history.tick() }
            _ = history.rewind(seconds: 10.0 / Double(ClassicDOSRules.ticksPerSecond))
            try require(scene.rgba(simulation: history.simulation) == saved, "Amiga frame did not rewind")
        }
        checked += 1
    }
    print("PASS \(family): \(campaign.levels.count) levels and object mappings")
}
print("PASS \(checked) Amiga level scenes; all sprite poses in both directions")
