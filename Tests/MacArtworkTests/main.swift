import Foundation
import NxlvKit

func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw SequelDataError.invalid(message) }
}
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let exported = root.appendingPathComponent(".build/mac-artwork/export")
let original = try ClassicMacArtwork(directory: exported.appendingPathComponent("lemmings"))
let rightWalk = original.lemming(pose: .walking, left: false, tick: 0)!
let leftWalk = original.lemming(pose: .walking, left: true, tick: 0)!
try require(rightWalk.width == leftWalk.width && rightWalk.height == leftWalk.height,
    "Walking directions do not have matching silhouettes")
var mirroredPixels = 0
for y in 0..<rightWalk.height { for x in 0..<rightWalk.width {
    let r = (y * rightWalk.width + x) * 4 + 3
    let l = (y * leftWalk.width + leftWalk.width - x - 1) * 4 + 3
    if rightWalk.rgba[r] == leftWalk.rgba[l] { mirroredPixels += 1 }
} }
// Hair and shading vary slightly between the two authored directions.
try require(Double(mirroredPixels) / Double(rightWalk.width * rightWalk.height) > 0.9,
    "The left walking silhouette does not match the right pose")
for family in ["lemmings", "ohno", "xmas", "holiday"] {
    let artwork = try ClassicMacArtwork(directory: exported.appendingPathComponent(family))
    try require(artwork.frame(1202) != nil, "Missing Mac logo: \(family)")
    for pose in ClassicLemmingPose.allCases {
        for left in [false, true] {
            for tick in 0..<32 {
                try require(artwork.lemming(pose: pose, left: left, tick: tick) != nil,
                    "Missing Mac animation: \(family) \(pose)")
            }
        }
    }
}
let folders = [
    ("lemmings", "Content/lemming1.pc"),
    ("ohno", "Sources/Ports/oh_no_more_lemmings_dos-1991-11-14_2232"),
    ("xmas", "Sources/Ports/xmas_dos_XmasLemmingsV1.9"),
    ("xmas", "Sources/Ports/xmas_dos_XmasLemmingsV1.9a1"),
    ("holiday", ".build/local/Ultimate Lemmings.app/Contents/Resources/Ports/holiday_native_1993"),
    ("holiday", ".build/local/Ultimate Lemmings.app/Contents/Resources/Ports/holiday_native_1994")]
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
        try require(scene.width == 3200 && scene.height == 320, "Mac resolution was lost")
        for object in level.objects {
            guard let defs = art.objects[level.groundStyle], defs.indices.contains(object.id), defs[object.id].count > 0 else {
                throw SequelDataError.invalid("Missing Mac object: \(family) \(level.title) \(object.id)")
            }
            let seq = defs[object.id]
            for frame in 0..<seq.count {
                try require(art.frame(1600 + level.groundStyle, seq.base + frame) != nil, "Missing Mac object frame")
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
                    "Mac entrance did not start on its authored closed frame")
            } }
            for _ in 0..<148 { _ = sim.tick() }
            let before = scene.rgba(simulation: sim)
            try require(before.count == 3200 * 320 * 4, "Bad composed Mac frame")
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
                        "A dug pixel remains visible in Mac artwork")
                } }
            }
            var history = ClassicDOSRewind(simulation: sim)
            let saved = scene.rgba(simulation: history.simulation)
            for _ in 0..<10 { _ = history.tick() }
            _ = history.rewind(seconds: 10.0 / Double(ClassicDOSRules.ticksPerSecond))
            try require(scene.rgba(simulation: history.simulation) == saved, "Mac frame did not rewind")
        }
        checked += 1
    }
    print("PASS \(family): \(campaign.levels.count) levels and object mappings")
}
print("PASS \(checked) Mac level scenes; all sprite poses in both directions")

// Fan packs redraw single pieces. Only identical pieces may take the Mac picture.
do {
    let directory = root.appendingPathComponent("Content/lemming1.pc")
    let art = try ClassicMacArtwork(directory: exported.appendingPathComponent("lemmings"))
    let campaign = try ClassicDataSet.detect(directory: directory).campaign
    let level = campaign.levels.map(\.level).first { $0.specialStyle == 0 && $0.terrain.count > 3 && $0.objects.contains { $0.id == 1 } }!
    let stock = try ClassicGroundSet.load(style: level.groundStyle, from: directory)
    func edited(_ change: (inout [String: Any]) -> Void) throws -> ClassicGroundSet {
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(stock)) as! [String: Any]
        change(&json)
        return try JSONDecoder().decode(ClassicGroundSet.self, from: JSONSerialization.data(withJSONObject: json))
    }
    /// Alters the first opaque pixel of one entry in an Int-keyed Codable dictionary.
    func touch(_ json: inout [String: Any], _ map: String, id: Int, field: String, frame: Int? = nil) {
        var table = json[map] as! [String: Any]
        var entry = table[String(id)] as! [String: Any]
        func flip(_ base64: String) -> String {
            var bytes = [UInt8](Data(base64Encoded: base64)!)
            let i = bytes.firstIndex { $0 & 0x80 == 0 }!
            bytes[i] = (bytes[i] & 0xF0) | ((bytes[i] + 1) & 0x0F)
            return Data(bytes).base64EncodedString()
        }
        if let frame {
            var frames = entry[field] as! [String]
            frames[frame] = flip(frames[frame]); entry[field] = frames
        } else { entry[field] = flip(entry[field] as! String) }
        table[String(id)] = entry; json[map] = table
    }
    func rendered(_ ground: ClassicGroundSet) throws -> ClassicRenderedLevel {
        try ClassicLevelRenderer.render(level, groundSet: ground, specialGraphic: nil)
    }

    let all = ClassicMacPieceMatch.compare(stock, with: stock)!
    try require(all.share(of: level) == 1, "Stock pieces should all match themselves")
    let reference = try ClassicMacScene(level: level, rendered: rendered(stock), artwork: art, groundSet: stock)
    let same = try ClassicMacScene(level: level, rendered: rendered(stock), artwork: art, groundSet: stock, match: all)
    try require(same.terrainRGBA == reference.terrainRGBA, "A full match changed the Mac picture")

    let piece = level.terrain[0].id
    let redrawn = try edited { touch(&$0, "terrain", id: piece, field: "indexedPixels") }
    let partial = ClassicMacPieceMatch.compare(redrawn, with: stock)!
    try require(!partial.terrain.contains(piece) && partial.terrain.count == stock.terrain.count - 1,
        "Only the redrawn terrain piece should lose its match")
    try require(partial.objects == all.objects, "Unchanged objects lost their match")
    let patched = try ClassicMacScene(level: level, rendered: rendered(redrawn), artwork: art, groundSet: redrawn, match: partial)
    try require(patched.terrainRGBA != reference.terrainRGBA, "A redrawn piece still shows the Mac picture")
    try require(patched.width == 3200 && patched.height == 320, "Fallback pieces broke the 2× scale")

    let entrance = try edited { touch(&$0, "objects", id: 1, field: "frames", frame: 0) }
    let objectMatch = ClassicMacPieceMatch.compare(entrance, with: stock)!
    try require(!objectMatch.objects.contains(1) && objectMatch.terrain == all.terrain,
        "Only the redrawn object should lose its match")
    let objectRender = try rendered(entrance)
    let objectScene = try ClassicMacScene(level: level, rendered: objectRender, artwork: art, groundSet: entrance, match: objectMatch)
    let simulation = try ClassicDOSSimulation(level: level, renderedLevel: objectRender,
        mainDATAssets: ClassicMainDATAssets.load(from: directory))
    let referenceFrame = reference.rgba(simulation: simulation), objectFrame = objectScene.rgba(simulation: simulation)
    try require(objectFrame.count == referenceFrame.count && objectFrame != referenceFrame,
        "A redrawn object still shows the Mac picture")
    try require(objectScene.terrainRGBA == reference.terrainRGBA, "An object change altered terrain")

    let recoloured = try edited {
        var palette = $0["terrainPalette"] as! [[String: Any]]
        palette[0]["red"] = 123; $0["terrainPalette"] = palette
    }
    try require(ClassicMacPieceMatch.compare(recoloured, with: stock) == nil, "A recoloured set must not match")

    if let special = campaign.levels.map(\.level).first(where: { $0.specialStyle > 0 }) {
        let ground = try ClassicGroundSet.load(style: special.groundStyle, from: directory)
        let picture = try ClassicSpecialGraphic.load(index: special.specialStyle - 1, from: directory)
        let image = try ClassicLevelRenderer.render(special, groundSet: ground, specialGraphic: picture)
        let pieces = ClassicMacPieceMatch.compare(ground, with: ground)!
        var unmatched = pieces; unmatched.special = false
        var threw = false
        do { _ = try ClassicMacScene(level: special, rendered: image, artwork: art, groundSet: ground, match: unmatched) }
        catch { threw = true }
        try require(threw, "A replaced special picture still used the Mac picture")
        var matched = pieces; matched.special = true
        _ = try ClassicMacScene(level: special, rendered: image, artwork: art, groundSet: ground, match: matched)
    }
    print("PASS fan pieces: per-piece Mac artwork, DOS fallback for redrawn pieces and objects")
}
