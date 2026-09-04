import Foundation
import NxlvKit

struct Failure: Error { let message: String }
func require(_ value: Bool, _ message: String) throws {
    if !value { throw Failure(message: message) }
}
func rejects(_ message: String, _ action: () throws -> Void) throws {
    do { try action() } catch { return }
    throw Failure(message: message)
}
func be32(_ value: Int) -> Data {
    Data([UInt8((value >> 24) & 255), UInt8((value >> 16) & 255),
          UInt8((value >> 8) & 255), UInt8(value & 255)])
}
func section(_ name: String, _ data: Data) -> Data {
    Data(name.utf8) + be32(data.count) + data
}
func form(_ sections: Data) -> Data {
    Data("FORM".utf8) + be32(sections.count + 4) + Data("L2LV".utf8) + sections
}

func testGraphics() throws {
    let styleSections = section("L2CL", Data(repeating: 0, count: 386))
        + section("L2BL", Data([1, 0]) + Data((0..<128).map(UInt8.init)))
        + section("L2OB", Data([0, 0]))
        + section("L2BF", Data([1, 0, 2, 0, 0, 0]))
        + section("L2BA", Data([1, 0, 1, 0, 1, 0, 1, 0, 0, 0]))
        + section("L2BI", Data([1, 0, 0, 0]))
    let styleData = Data("FORM".utf8) + be32(styleSections.count + 4) + Data("L2VG".utf8) + styleSections
    let style = try Lemmings2Style(data: styleData)
    try require(Array(style.tiles[0].prefix(4)) == [0, 32, 64, 96], "L2 four-plane decoding")
    let frames = try style.animation(0)
    try require(frames.count == 1 && frames[0].width == 16 && frames[0].height == 8,
                "L2 animation dimensions")
    try require(frames[0].pixels == style.tiles[0], "L2 animation frame offsets")
    let levelSections = section("L2LH", Data(repeating: 0, count: 74))
        + section("L2MH", Data(repeating: 0, count: 6))
        + section("L2MP", Data(repeating: 0, count: 1971 * 4))
        + section("L2BO", Data())
    let terrain = try Lemmings2Terrain(level: Lemmings2Level(data: form(levelSections)), style: style)
    try require(terrain.image.width == 1280 && terrain.image.height == 160, "L2 map geometry")
    try require(!terrain.solid[0] && terrain.solid[1], "L2 terrain zero-pixel collision")
    try rejects("accepted missing L2 animation") { _ = try style.animation(1) }
    var taggedMap = Data(repeating: 0, count: 1971 * 4)
    // First visible tile: upper six bits are metadata, not a tile index.
    taggedMap[165 * 4 + 2] = 0xfc
    let taggedLevel = try Lemmings2Level(data: form(
        section("L2LH", Data(repeating: 0, count: 74))
        + section("L2MH", Data(repeating: 0, count: 6))
        + section("L2MP", taggedMap) + section("L2BO", Data())))
    try require(taggedLevel.tiles[165].identifier == 0 && taggedLevel.tiles[165].metadata == 0xfc00
        && taggedLevel.tiles[165].rawIdentifier == 0xfc00, "L2 preserves non-graphics tile bits")
    let taggedTerrain = try Lemmings2Terrain(level: taggedLevel, style: style)
    try require(taggedTerrain.image.pixels == terrain.image.pixels && taggedTerrain.solid == terrain.solid,
        "L2 tile metadata does not select a different terrain image")

    let record = Data([7, 0, 32, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0])
    let bank = try Lemmings3StyleBank(objects: record, frames: Data([2, 0, 1, 1, 0, 0, 0]),
                                    blocks: Data((0..<16).map(UInt8.init)))
    let image = try bank.image(object: 7, palette: Array(repeating: 0, count: 1024))
    try require(image.width == 8 && image.height == 2 && Array(image.pixels.prefix(4)) == [0, 4, 8, 12],
                "L3 block planes and frame references")
    try rejects("accepted truncated L3 object graphics") {
        _ = try Lemmings3StyleBank(objects: Data(record.dropLast()), frames: Data(), blocks: Data())
    }
    try rejects("accepted missing L3 graphics frame") {
        _ = try bank.image(object: 7, frame: 1, palette: Array(repeating: 0, count: 1024))
    }
    print("PASS synthetic native tile, animation, terrain and object graphics")
}

func testSpriteCommands() throws {
    let index = Data([8, 0, 2, 0, 1, 0])
    // Each plane draws a black pixel, skips one pixel, advances a row,
    // then writes two values. Literal FF must not end the plane.
    let plane: [UInt8] = [0x19, 0, 0, 0x20, 7, 255, 255]
    let commands = Data(plane + plane + plane + plane)
    let sprites = try Lemmings3Sprites(index: index, commands: commands)
    let frame = sprites.animations[0].frames[0]
    try require(Array(frame.opaque.prefix(8)) == [true, true, true, true, false, false, false, false],
                "L3 skipped pixels differ from opaque black pixels")
    try require(Array(frame.pixels.suffix(8)) == [7, 7, 7, 7, 255, 255, 255, 255], "L3 plane order")
    for length in 0..<commands.count {
        try rejects("accepted truncated CMP commands") {
            _ = try Lemmings3Sprites(index: index, commands: Data(commands.prefix(length)))
        }
    }
    try rejects("accepted out-of-bounds CMP write") {
        _ = try Lemmings3Sprites(index: Data([1, 0, 1, 0, 1, 0]), commands: commands)
    }
    try rejects("accepted invalid CMP command") {
        _ = try Lemmings3Sprites(index: index, commands: Data([0xf1]))
    }
    var l2 = Data([1, 0, 4, 0, 254, 255, 253, 255, 10, 0, 8, 0, 2, 0,
                   22, 0, 28, 0, 34, 0, 40, 0])
    let l2Plane: [UInt8] = [0x10, 0, 0x11, 7, 255, 255]
    l2 += Data(l2Plane + l2Plane + l2Plane + l2Plane)
    func spriteForm(_ payload: Data) -> Data {
        let body = section("LM01", payload)
        return Data("FORM".utf8) + be32(body.count + 4) + Data("L2VL".utf8) + body
    }
    let l2Frame = try Lemmings2Sprites(data: spriteForm(l2)).animations["LM01"]![0]
    try require(l2Frame.x == -2 && l2Frame.y == -3 && l2Frame.pixels == frame.pixels
                && l2Frame.opaque == frame.opaque, "L2 signed anchors, plane pointers and literal pixels")
    for length in 0..<l2.count {
        try rejects("accepted truncated VLEMMS frame") {
            _ = try Lemmings2Sprites(data: spriteForm(Data(l2.prefix(length))))
        }
    }
    var invalidPointer = l2
    invalidPointer[8] = 11
    try rejects("accepted inconsistent VLEMMS self pointer") {
        _ = try Lemmings2Sprites(data: spriteForm(invalidPointer))
    }
    var invalidCommand = l2
    invalidCommand[22] = 0xee
    try rejects("accepted unknown VLEMMS opcode") {
        _ = try Lemmings2Sprites(data: spriteForm(invalidCommand))
    }
    print("PASS native L3 sprite command interpreter, transparency and bounds")
    print("PASS native L2 sprite command interpreter, anchors and pointer validation")
}

func testSpecialGraphics() throws {
    let base = section("L2CL", Data(repeating: 0, count: 386))
        + section("L2BL", Data([0, 0])) + section("L2OB", Data([0, 0]))
    // Two entries deliberately share dimensions but not pixels. All four
    // plane pointers in the second entry must omit BOTH size words.
    let first = Data([24, 0, 4, 0, 1, 0, 12, 0, 15, 0, 18, 0, 21, 0,
                      0x10, 7, 255, 0x10, 8, 255, 0x10, 9, 255, 0x10, 10, 255])
    let second = Data([21, 0, 4, 0, 1, 0, 36, 0, 39, 0, 42, 0, 43, 0,
                       0x10, 0, 255, 0x10, 255, 255, 255, 0, 255])
    let shapes = Data([2, 0]) + first + second
    let positions = Data([2, 0, 254, 255, 253, 255, 0, 0, 5, 0, 6, 0, 24, 0])
    let animations = Data([1, 0, 2, 0, 0, 0, 6, 0])
    let indices = Data([1, 0, 0, 0])
    func bank(_ ss: Data, _ sf: Data = positions, _ sa: Data = animations, _ si: Data = indices) throws -> Lemmings2Style {
        let body = base + section("L2SS", ss) + section("L2SF", sf)
            + section("L2SA", sa) + section("L2SI", si)
        return try Lemmings2Style(data: Data("FORM".utf8) + be32(body.count + 4) + Data("L2VG".utf8) + body)
    }
    let style = try bank(shapes)
    let frames = try style.specialAnimation(0)
    try require(frames.count == 2 && frames[0].x == -2 && frames[0].y == -3,
                "L2SS signed anchors and frame order")
    try require(frames[0].pixels == [7, 8, 9, 10] && frames[1].pixels == [0, 255, 0, 0]
        && frames[1].opaque == [true, true, false, false] && frames[1].x == 5 && frames[1].y == 6,
        "L2SS logical pointers, plane order, opaque black and skipped pixels")
    for length in 0..<shapes.count {
        try rejects("accepted truncated L2SS entry") {
            _ = try bank(Data(shapes.prefix(length))).specialAnimation(0)
        }
    }
    try rejects("accepted missing L2SI animation") { _ = try style.specialAnimation(1) }
    var broken = shapes
    broken[8] = 11
    try rejects("accepted L2SS plane inside header") { _ = try bank(broken).specialAnimation(0) }
    var badFrame = positions
    badFrame[12] = 25
    try rejects("accepted L2SF offset inside sprite") { _ = try bank(shapes, badFrame).specialAnimation(0) }
    var badSequence = animations
    badSequence[6] = 1
    try rejects("accepted unaligned L2SF reference") { _ = try bank(shapes, positions, badSequence).specialAnimation(0) }
    try rejects("accepted L2SA pointer inside sequence") {
        _ = try bank(shapes, positions, animations, Data([1, 0, 2, 0])).specialAnimation(0)
    }
    print("PASS L2 special object graphics, anchors, opacity and malformed pointers")
}

func testAirPhysics() throws {
    var air = try Lemmings2AirPhysics(x: 100, y: 100, velocityX: 3, velocityY: -3,
                                     horizontalCountdown: 0, verticalCountdown: 0, fallDistance: 12)
    let expected: [(Int16, Int16, Int16, Int16)] = [
        (103, 97, 2, -2), (105, 95, 2, -1), (107, 94, 2, 0),
        (109, 94, 2, 1), (111, 95, 2, 2), (113, 97, 2, 3),
        (115, 100, 2, 3), (117, 103, 2, 4), (119, 107, 1, 4)
    ]
    for (x, y, vx, vy) in expected {
        air.step()
        try require(air.x == x && air.y == y && air.velocityX == vx && air.velocityY == vy,
                    "L2 airborne countdown and pre-acceleration position order")
    }
    var mirror = try Lemmings2AirPhysics(x: 0, y: 0, velocityX: -2, velocityY: 8,
                                        horizontalCountdown: 0, verticalCountdown: 0)
    mirror.step()
    try require(mirror.x == -2 && mirror.velocityX == -1 && mirror.y == 8 && mirror.velocityY == 8,
                "L2 negative horizontal drag and terminal velocity")
    for _ in 0..<32 { mirror.step() }
    try require(mirror.velocityX == -1 && mirror.fallDistance == 264, "L2 persistent minimum drift")
    var wrap = try Lemmings2AirPhysics(x: 32767, y: 32767, velocityX: 1, velocityY: 1,
                                      horizontalCountdown: 0, verticalCountdown: 1)
    wrap.step()
    try require(wrap.x == -32768 && wrap.y == -32768, "L2 signed-word position wrap")
    try rejects("accepted unsupported air acceleration index") {
        _ = try Lemmings2AirPhysics(x: 0, y: 0, velocityX: 0, velocityY: -10,
                                    horizontalCountdown: 0, verticalCountdown: 0)
    }
    print("PASS native L2 airborne tick order, countdowns, drift and word arithmetic")
}

do {
    try testGraphics()
    try testSpriteCommands()
    try testSpecialGraphics()
    try testAirPhysics()
    // A -> ab, then A -> A+c. Redefinition must retain the old A.
    let packed = Data(Array("GSCM".utf8) + [3, 0, 0, 0, 255, 2, 0,
        65, 65, 97, 65, 98, 99, 1, 0, 65])
    try require(try Lemmings2Compression.decode(packed) == Data("abc".utf8), "GSCM redefinition")
    for length in 4..<packed.count {
        try rejects("accepted truncated GSCM") {
            _ = try Lemmings2Compression.decode(Data(packed.prefix(length)))
        }
    }
    try rejects("ignored output limit") { _ = try Lemmings2Compression.decode(packed, maximumOutputSize: 2) }
    try rejects("accepted trailing GSCM bytes") { _ = try Lemmings2Compression.decode(packed + Data([0])) }
    let multipleChunks = Data(Array("GSCM".utf8) + [2, 0, 0, 0,
        0, 0, 0, 1, 0, 97, 255, 0, 0, 1, 0, 98])
    try require(try Lemmings2Compression.decode(multipleChunks) == Data("ab".utf8), "multiple chunks")
    var header = Data(repeating: 0, count: 74)
    header[0] = 65
    header[48] = 2
    header[50] = 30
    header[68] = 255
    header[69] = 255
    let sections = section("L2LH", header)
        + section("L2MH", Data([0, 0, 1, 0, 0, 0]))
        + section("L2MP", Data([64, 0, 1, 2]))
        + section("L2BO", Data([3, 0, 16, 0, 8, 0, 2, 0, 4, 0]))
        + section("TEST", Data([9]))
    let synthetic = form(sections)
    let level2 = try Lemmings2Level(data: synthetic)
    try require(level2.title == "A" && level2.timeLimitSeconds == 150 && level2.releaseRate == -1,
                "L2 metadata fields")
    try require(level2.tileColumns == 64 && level2.tiles[0].identifier == 258
        && level2.tiles[0].modifier == 0x4000 && level2.objects[0].parameter2 == 4,
                "L2 record byte order")
    try require(try level2.container.requiredSection("TEST") == Data([9]), "unknown section preservation")
    for length in 0..<synthetic.count {
        try rejects("accepted truncated FORM") { _ = try Lemmings2Level(data: Data(synthetic.prefix(length))) }
    }
    try rejects("accepted duplicate level header") {
        _ = try Lemmings2Level(data: form(sections + section("L2LH", header)))
    }
    var header3 = Data(repeating: 0, count: 30)
    header3[12] = 64
    header3[13] = 1
    header3[14] = 160
    header3[22] = 7
    let level3 = try Lemmings3Level(data: header3)
    try require(level3.width == 320 && level3.height == 160 && level3.extraLemmings == 7, "L3 fields")
    let objects = try Lemmings3Objects(data: Data([1, 0, 8, 0, 2, 0]))
    try require(objects.placements[0].x == 8 && objects.placements[0].y == 2, "L3 placements")
    try rejects("accepted partial object") { _ = try Lemmings3Objects(data: Data([0])) }
    for length in 0..<30 {
        try rejects("accepted truncated L3 header") { _ = try Lemmings3Level(data: Data(repeating: 0, count: length)) }
    }
    print("PASS synthetic decompression, truncation and size guards")

    for (sequel, argument) in CommandLine.arguments.dropFirst().enumerated() {
        let root = URL(fileURLWithPath: argument)
        guard FileManager.default.fileExists(atPath: root.path) else {
            print("SKIP unavailable private data: \(root.lastPathComponent)")
            continue
        }
        let directory = root.appendingPathComponent("LEVELS")
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("LEVEL") && $0.pathExtension == "DAT" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        try require(!files.isEmpty, "missing sequel level fixtures")
        var styles2: [Int: Lemmings2Style] = [:]
        var styles3: [Int: Lemmings3Style] = [:]
        if sequel == 0 {
            let spriteData = try Data(contentsOf: root.appendingPathComponent("VLEMMS.DAT"))
            let sprites = try Lemmings2Sprites(data: spriteData)
            print("PASS decoded \(sprites.animations.count) L2 lemming animations")
            let names = ["CLASSIC", "BEACH", "CAVEMAN", "CIRCUS", "EGYPTIAN", "HIGHLAND", "MEDIEVAL", "OUTDOOR", "POLAR", "SHADOW", "SPACE", "SPORTS"]
            for (index, name) in names.enumerated() {
                let style = try Lemmings2Style(data: Data(contentsOf: root.appendingPathComponent("STYLES/\(name).DAT")))
                styles2[index] = style
                let data = Array(try style.container.requiredSection("L2BI"))
                let count = Int(data[0]) + Int(data[1]) * 256
                for animation in 0..<count { _ = try style.animation(animation) }
                let specialData = Array(try style.container.requiredSection("L2SI"))
                let specialCount = Int(specialData[0]) + Int(specialData[1]) * 256
                for animation in 0..<specialCount { _ = try style.specialAnimation(animation) }
                print("PASS \(name): \(count) regular and \(specialCount) special object animations")
            }
        } else {
            for index in 1...3 {
                styles3[index] = try Lemmings3Style(directory: root.appendingPathComponent("STYLES"), number: index)
            }
            let egyptian = styles3[3]!
            let emptyObjects = try Lemmings3Objects(data: Data())
            let egyptianLevel = try Lemmings3Level(data: Data(contentsOf:
                directory.appendingPathComponent("LEVEL202.DAT")))
            let sky = try Lemmings3Scene(level: egyptianLevel, style: egyptian,
                permanent: emptyObjects, temporary: emptyObjects)
            let artwork = try egyptian.permanent.image(object: 100, palette: egyptian.palette)
            let blue = Array(egyptian.palette[Int(artwork.pixels[0]) * 4..<Int(artwork.pixels[0]) * 4 + 4])
            try require(blue == [0, 0, 113, 255], "Egyptian artwork sky colour")
            try require(sky.image.pixels.allSatisfy { $0 == artwork.pixels[0] }
                && sky.background.pixels == sky.image.pixels,
                "Egyptian empty sky and exposed background must match artwork")
            try require(sky.attributes.allSatisfy { $0 == 0x1000 }
                && sky.backgroundAttributes == sky.attributes,
                "Sky colour must not change empty-space collision tags")
            print("PASS Egyptian sky matches native artwork and exposed background")
        }
        for file in files {
            let data = try Data(contentsOf: file)
            do {
                if sequel == 0 {
                    let level = try Lemmings2Level(data: data)
                    try require(level.skills.count == 8 && !level.tiles.isEmpty, "empty L2 level")
                    guard let style = styles2[level.style] else { throw Failure(message: "missing L2 style") }
                    _ = try Lemmings2Terrain(level: level, style: style)
                    _ = try Lemmings2Objects(level: level, style: style)
                    if file.lastPathComponent == "LEVEL066.DAT" {
                        try require(level.tiles[710].rawIdentifier == 0xf193 && level.tiles[710].identifier == 403,
                            "Medieval 7 tagged tile must resolve to native block 403")
                    }
                    if file.lastPathComponent == "LEVEL067.DAT" {
                        try require(level.tiles[747].rawIdentifier == 0xf02c && level.tiles[747].identifier == 44,
                            "Medieval 8 tagged tile must resolve to native block 44")
                    }
                    if file.lastPathComponent == "LEVEL000.DAT" {
                        print("L2 first: \(level.title), style \(level.style), \(level.tiles.count) tiles, \(level.objects.count) objects")
                    }
                } else {
                    let level = try Lemmings3Level(data: data)
                    guard let style = styles3[level.style] else { throw Failure(message: "missing L3 style") }
                    for (prefix, reference) in [("TEMP", level.temporaryObjectsReference), ("PERM", level.permanentObjectsReference)] {
                        let path = directory.appendingPathComponent(String(format: "%@%03d.OBS", prefix, reference))
                        let placements = try Lemmings3Objects(data: Data(contentsOf: path))
                        let bank = prefix == "TEMP" ? style.temporary : style.permanent
                        for placed in placements.placements {
                            _ = try bank.image(object: placed.identifier, palette: style.palette)
                        }
                    }
                    if file.lastPathComponent == "LEVEL001.DAT" {
                        try require(level.width == 320 && level.height == 160 && level.timeLimitSeconds == 420,
                                    "L3 first-level metadata mismatch")
                    }
                }
            } catch { throw Failure(message: "\(file.path): \(error)") }
        }
        print("PASS decoded \(files.count) Lemmings \(sequel + 2) level files")
        if sequel == 0 {
            let front = try Lemmings2FrontEnd(root: root)
            try require(front.banks.count == 11 && front.pictures.count == 9, "Missing original front-end banks")
            try require(front.font.glyphs.count == 102 && front.font.glyphs[0].allSatisfy { $0 == 0 }, "Native proportional font")
            try require(front.font.width("Classic") == 50, "Native proportional text advances")
            try require(front.panel.controls.count == 26 && front.panel.skills.count == 54, "Original panel sprite counts")
            try require(front.pointers.frames.count == 18 && front.pointers.frames.allSatisfy { $0.count == 256 }, "Native cross, box and fan pointers")
            let pointerRaw = [UInt8](try Lemmings2Compression.decode(Data(contentsOf: root.appendingPathComponent("POINTER.DAT"))))
            for f in 0..<18 { for i in 0..<256 {
                try require(front.pointers.frames[f][i] == pointerRaw[f * 256 + i % 4 * 64 + i / 4], "Pointer plane order")
            } }
            let pal = Lemmings2Panel.palette(over: [UInt8](repeating: 17, count: 1024))
            try require(Array(pal[145 * 4..<148 * 4]) == [255,255,0,255,255,0,0,255,255,0,0,255], "Visible original selection colours")
            try require(pal[0] == 17 && pal[148 * 4] == 17, "Panel palette damaged terrain colours")
            let cycled = Lemmings2Panel.palette(over: pal, phase: 1)
            try require(cycled[145 * 4 + 1] == 0 && cycled[147 * 4 + 1] == 255, "Selection outline did not cycle")
            for picture in front.pictures.values { try require(picture.count == 64000, "Original screen dimensions") }
            let menu = front.banks["MENU"]!
            try require(menu.sprites.count == 4 && menu.sprites[1][0].width == 17, "GAL paragraph sprite addressing")
            let info = front.banks["INFO"]!
            try require(info.sprites.count == 26 && info.sprites[7].count == 51 && info.palettes.count == 14,
                        "Original briefing skill animations and tribe palettes")
            for selection in 0..<12 {
                let panel = try front.panel.render(skills: [18,22,24,51,19,20,21,17], supplies: [20,20,20,20,20,20,20,20],
                    selected: selection, saved: 0, remaining: 0, seconds: 300, label: "CLIMBER", palette: pal)
                try require(panel.width == 320 && panel.height == 40 && panel.pixels.count == 12800, "Native panel layout")
                try require(panel.pixels.contains(145) && panel.pixels.contains(146), "Missing selection outline")
            }
            let pausedPanel = try front.panel.render(skills: [18,22,24,51,19,20,21,17], supplies: Array(repeating: 20, count: 8),
                selected: 4, saved: 0, remaining: 0, seconds: 300, label: "BUILDER", palette: pal,
                highlightedControls: [.pause, .nuke, .fastForward])
            for (x, y) in [(128,9),(256,0),(288,0),(288,20)] {
                let region = (y..<min(40,y+20)).flatMap { row in Array(pausedPanel.pixels[(row*320+x)..<(row*320+x+32)]) }
                try require(region.contains(145), "Paused/armed control hid skill selection")
            }
            do {
                _ = try Lemmings2Panel(panel: Data([0,0]), icons: Data())
                throw Failure(message: "Truncated panel accepted")
            } catch is SequelDataError {}
            print("PASS original L2 front end: 11 banks, 9 screens, 51 skill animations, font and 12 panel selections")
            let soundData = try Data(contentsOf: root.appendingPathComponent("MUSIC/SBLAST.VOC"))
            let sounds = try Lemmings2SoundBank(data: soundData)
            try require(sounds.clips.count == 80, "Missing L2 native sound clips")
            try require(sounds.clips[49].samples.count == 4094 && abs(sounds.clips[49].sampleRate - 1_000_000 / 120) < 0.01, "Panel PCM length/rate")
            try require(sounds.clips.allSatisfy { !$0.samples.isEmpty && $0.samples.allSatisfy { $0.isFinite && abs($0) <= 1 } }, "Invalid native PCM output")
            var mixer = Lemmings2SoundMixer(bank: sounds)
            mixer.play(.init(.explode))
            let rendered = (0..<50000).map { _ in mixer.nextSample() }
            try require(rendered.contains { abs($0) > 0.01 } && rendered.suffix(5000).allSatisfy { $0 == 0 }, "Explosion audio is silent or loops")
            mixer.setMuted(true); mixer.play(.init(.assignSkill))
            try require((0..<100).allSatisfy { _ in mixer.nextSample() == 0 }, "Muted sound still plays")
            mixer.setMuted(false); mixer.play(.panel(slot: 9)!)
            try require((0..<5000).contains { _ in abs(mixer.nextSample()) > 0.01 }, "Unmuting did not restore panel sound")
            mixer.silence()
            try require(mixer.nextSample() == 0, "Level reset retained old sounds")
            for slot in 0..<12 { try require(Lemmings2SoundRequest.panel(slot: slot)?.sample == 49, "Native panel sound mapping") }
            try require(Lemmings2SoundRequest.panel(slot: 12) == nil, "Invalid panel sound index")
            var corrupt = soundData
            corrupt[4] = 255; corrupt[5] = 255; corrupt[6] = 255; corrupt[7] = 127
            for data in [Data(soundData.prefix(510)), Data(soundData.prefix(soundData.count - 5)), corrupt] {
                do { _ = try Lemmings2SoundBank(data: data); throw Failure(message: "Malformed sound bank accepted") }
                catch is SequelDataError {}
            }
            print("PASS 80 original L2 VOC clips, multi-block voice, PCM mixer, sound mute and malformed banks")
            let styles = try FileManager.default.contentsOfDirectory(
                at: root.appendingPathComponent("STYLES"), includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "DAT" }
            for style in styles { _ = try Lemmings2Form(data: Data(contentsOf: style)) }
            print("PASS decoded \(styles.count) Lemmings 2 style containers")
        } else {
            for folder in ["GRAPHICS", "STYLES"] {
                let directory = root.appendingPathComponent(folder)
                for file in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
                    .filter({ $0.pathExtension == "IND" }) {
                    do {
                        let sprites = try Lemmings3Sprites(index: Data(contentsOf: file),
                            commands: Data(contentsOf: file.deletingPathExtension().appendingPathExtension("CMP")))
                        print("PASS \(file.lastPathComponent): \(sprites.animations.count) native L3 animations")
                    } catch { throw Failure(message: "\(file.path): \(error)") }
                }
            }
        }
    }
} catch {
    FileHandle.standardError.write(Data("Sequel data tests failed: \(error)\n".utf8))
    exit(1)
}
