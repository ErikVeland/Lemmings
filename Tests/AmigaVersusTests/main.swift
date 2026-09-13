import Foundation
import NxlvKit

private struct Failure: Error, CustomStringConvertible { let description: String }
private func require(
    _ condition: @autoclosure () -> Bool, _ message: @autoclosure () -> String
) throws {
    guard condition() else { throw Failure(description: message()) }
}

private let root = URL(fileURLWithPath: "Sources/Ports/amiga_extracted", isDirectory: true)

private func testAllThirtyVersusLevelsLoad() throws {
    let entries = try AmigaVersusCampaign.load(from: root)
    try require(entries.count == 30, "loaded \(entries.count) versus levels, expected 30")

    let lemmings = entries.filter { $0.source.family == "lemmings" }
    let ohno = entries.filter { $0.source.family == "ohno" }
    try require(lemmings.count == 20, "Lemmings gave \(lemmings.count) versus levels, expected 20")
    try require(ohno.count == 10, "Oh No! gave \(ohno.count) versus levels, expected 10")

    for entry in entries {
        let level = entry.level
        try require(!level.title.isEmpty, "a versus level has no title")
        try require(level.lemmingCount > 0, "\(level.title) releases no lemmings")
        try require(
            level.saveRequirement <= level.lemmingCount,
            "\(level.title) asks for more lemmings than it releases")
        try require(!level.terrain.isEmpty, "\(level.title) has no terrain")
        try require((0..<5).contains(level.groundStyle), "\(level.title) names style \(level.groundStyle)")
    }
    print("PASS all 30 Amiga versus levels load with terrain, titles and sane counts")
}

private func testTheNamesAreTheVersusOnes() throws {
    let entries = try AmigaVersusCampaign.load(from: root)
    let titles = entries.map { $0.level.title }
    // These are unmistakably competitive, and they are what marks the block.
    for expected in ["There can be only one", "and the winner is.....", "The Duel", "I Want It All"] {
        try require(
            titles.contains { $0.hasPrefix(expected.prefix(12)) },
            "the versus block does not contain \"\(expected)\"")
    }
    // The one-player levels must not have been swept in with them.
    for onePlayer in ["Just dig!", "Only floaters can survive this"] {
        try require(!titles.contains(onePlayer), "\(onePlayer) is a one-player level")
    }
    print("PASS the block holds the versus levels and none of the one-player ones")
}

private func testOhNoVersusLevelsShareTheirShape() throws {
    let ohno = try AmigaVersusCampaign.load(from: root).filter { $0.source.family == "ohno" }
    // Every Oh No! versus level gives each side forty lemmings, asks for all of
    // them, and starts at the slowest release rate. That shape is what marks
    // them out from the one-player levels either side.
    for entry in ohno {
        try require(
            entry.level.lemmingCount == 40,
            "\(entry.level.title) releases \(entry.level.lemmingCount), expected 40")
        try require(
            entry.level.saveRequirement == 40,
            "\(entry.level.title) needs \(entry.level.saveRequirement), expected 40")
        try require(
            entry.level.releaseRate == 1,
            "\(entry.level.title) starts at rate \(entry.level.releaseRate), expected 1")
    }
    print("PASS every Oh No! versus level has the versus shape: 40 out, 40 needed, rate 1")
}

private func testNumbersRunFromOnePerRelease() throws {
    let entries = try AmigaVersusCampaign.load(from: root)
    let lemmings = entries.filter { $0.source.family == "lemmings" }.map(\.number)
    let ohno = entries.filter { $0.source.family == "ohno" }.map(\.number)
    try require(lemmings == Array(1...20), "Lemmings numbering was \(lemmings)")
    try require(ohno == Array(1...10), "Oh No! numbering was \(ohno)")
    print("PASS each release numbers its versus levels from one")
}

private func testTheExclusivePackIsBuilt() throws {
    let ranks = try PortExclusivePack.load(amigaRoot: root)
    try require(PortExclusivePack.name == "Oh Yes! More Lemmings!", "the pack was renamed")
    try require(ranks.count == 3, "the pack has \(ranks.count) ranks, expected 3")
    try require(ranks[0].levels.count == 20, "the first rank holds \(ranks[0].levels.count)")
    try require(ranks[1].levels.count == 10, "the second rank holds \(ranks[1].levels.count)")
    try require(ranks[2].levels.count == 30, "the Sunsoft rank holds \(ranks[2].levels.count)")

    let all = try PortExclusivePack.allLevels(amigaRoot: root)
    try require(all.count == 60, "the pack holds \(all.count) levels, expected 60")
    try require(
        Set(all.map(\.title)).count == all.count,
        "the pack repeats a level title")
    for level in all {
        // "SUNSOFT Special" draws its whole picture from a special graphic
        // rather than from placed terrain, so it is the one level with none.
        if level.specialStyle != 0 { continue }
        try require(!level.terrain.isEmpty, "\(level.title) reached the pack with no terrain")
    }
    print("PASS the pack holds 60 playable port-exclusive levels in 3 ranks")
}

private func testTheSunsoftLevelsAreTheMegaDriveOnes() throws {
    let ports = root.deletingLastPathComponent()
    let levels = try PortExclusivePack.sunsoftLevels(portsRoot: ports)
    try require(levels.count == 30, "read \(levels.count) Sunsoft levels, expected 30")
    let titles = Set(levels.map(\.title))
    // These appear in no DOS or Amiga release, which is what makes them
    // exclusive, and they match the titles read straight from the cartridge.
    for expected in ["Doomsday", "Exodus!", "I am A.T.", "SUNSOFT Special", "Anxiety"] {
        try require(titles.contains(expected), "the Sunsoft set is missing \"\(expected)\"")
    }
    for level in levels {
        try require(level.lemmingCount > 0, "\(level.title) releases no lemmings")
        try require(
            level.saveRequirement <= level.lemmingCount,
            "\(level.title) asks for more lemmings than it releases")
    }
    print("PASS the 30 Mega Drive Sunsoft levels load with their own titles")
}

private func testAPackWithNoDataIsEmptyRatherThanBroken() throws {
    let nowhere = URL(fileURLWithPath: "/tmp/no-amiga-data-here", isDirectory: true)
    let ranks = try PortExclusivePack.load(amigaRoot: nowhere)
    try require(ranks.isEmpty, "a pack with no data installed produced \(ranks.count) ranks")
    print("PASS the pack is empty when no port data is installed")
}

private func testFanLevelReaderEncodesTheTrickyFields() throws {
    // A small level exercising the parts most likely to be encoded wrongly:
    // the x offset of sixteen, the terrain modifier bits, and the two ways
    // editors write a time limit.
    let text = """
    # written by hand for this test
    releaseRate = 39
    numLemmings = 74
    numToRescue = 70
    timeLimit = 3
    numClimbers = 2
    numBuilders = 1
    numDiggers = 5
    xPos = 1300
    name = A test level
    object_0 = 6, 1750, 291, 4, 0
    object_1 = 10, 1719, 40, 8, 1
    terrain_0 = 13, 1749, 88, 0
    terrain_1 = 25, 1723, 104, 2
    terrain_2 = 25, 1632, 123, 8
    """
    let level = try FanLevelReader.level(fromINI: text)
    try require(level.title == "A test level", "title came back as \"\(level.title)\"")
    try require(level.releaseRate == 39, "release rate was \(level.releaseRate)")
    try require(level.lemmingCount == 74, "lemming count was \(level.lemmingCount)")
    try require(level.saveRequirement == 70, "save requirement was \(level.saveRequirement)")
    try require(level.timeLimitMinutes == 3, "time limit was \(level.timeLimitMinutes)")
    try require(level.skills[.climber] == 2, "climbers were \(level.skills[.climber] ?? -1)")
    try require(level.skills[.digger] == 5, "diggers were \(level.skills[.digger] ?? -1)")
    try require(level.startX == 1300, "start x was \(level.startX)")

    // x survives the sixteen pixel offset in both directions.
    try require(level.objects.count == 2, "objects came back as \(level.objects.count)")
    try require(level.terrain.count == 3, "terrain came back as \(level.terrain.count)")
    try require(level.terrain[0].x == 1749, "terrain x was \(level.terrain[0].x)")
    try require(level.terrain[0].y == 88, "terrain y was \(level.terrain[0].y)")
    // Modifier 2 is remove, 8 is no-overwrite. The record stores them one bit
    // lower, which is the step most easily got wrong.
    try require(level.terrain[1].draw.isErase, "modifier 2 did not become erase")
    try require(level.terrain[2].draw.noOverwrite, "modifier 8 did not become no-overwrite")
    try require(!level.terrain[0].draw.isErase, "a plain piece was marked erase")
    print("PASS a text level encodes its offsets, modifiers and skills correctly")
}

private func testFanLevelReaderTakesSecondsOrMinutes() throws {
    let base = """
    releaseRate = 1
    numLemmings = 80
    numToRescue = 75
    name = Timed
    terrain_0 = 1, 100, 50, 0
    """
    let minutes = try FanLevelReader.level(fromINI: base + "\ntimeLimit = 4")
    let seconds = try FanLevelReader.level(fromINI: base + "\ntimeLimitSeconds = 600")
    try require(minutes.timeLimitMinutes == 4, "minutes gave \(minutes.timeLimitMinutes)")
    try require(seconds.timeLimitMinutes == 10, "600 seconds gave \(seconds.timeLimitMinutes)")
    // Rounding up, so a level never loses time it was given.
    let partial = try FanLevelReader.level(fromINI: base + "\ntimeLimitSeconds = 90")
    try require(partial.timeLimitMinutes == 2, "90 seconds gave \(partial.timeLimitMinutes)")
    print("PASS a time limit is read whether it is written in seconds or minutes")
}

private func testMalformedTextLevelsAreRejected() throws {
    let base = "releaseRate = 1\nnumLemmings = 10\nnumToRescue = 5\ntimeLimit = 3\n"
    let cases: [(String, String)] = [
        ("object_0 = 1, invalid, 20, 4", "object_0"),
        ("terrain_0 = 1, , 20, 4", "terrain_0"),
        ("terrain_0 = 1, 20", "terrain_0"),
        ("steel_0 = 1, 2, invalid, 4", "steel_0"),
        ("numBuilders = invalid", "numBuilders"),
        ("timeLimit = invalid\ntimeLimitSeconds = 60", "timeLimit"),
        ("object_0 = 1, \(Int.max), 20", "object_0"),
        ("terrain_0 = 1, \(Int.max), 20", "terrain_0"),
        ("terrain_0 = 1, 20, \(Int.max)", "terrain_0"),
        ("terrain_0 = 1, 99999999999999999999999, 20", "terrain_0"),
    ]
    for (suffix, field) in cases {
        do {
            _ = try FanLevelReader.level(fromINI: base + suffix)
            throw Failure(description: "accepted malformed \(field): \(suffix)")
        } catch let error as FanLevelError {
            try require(error == .invalidField(field), "wrong malformed-field error: \(error)")
        }
    }
    do {
        let text = base.replacingOccurrences(of: "timeLimit = 3", with: "timeLimitSeconds = \(Int.max)")
        _ = try FanLevelReader.level(fromINI: text)
        throw Failure(description: "accepted overflowing seconds")
    } catch let error as FanLevelError {
        try require(error == .invalidField("timeLimitSeconds"), "wrong seconds error: \(error)")
    }
    print("PASS malformed text levels reject shifted fields and overflowing coordinates or time without crashing")
}

private func testTextSteelIsLossless() throws {
    let base = "releaseRate = 1\nnumLemmings = 10\nnumToRescue = 5\ntimeLimit = 3\n"
    let exact = base + "steel_0 = 452, 72, 64, 24\nsteel_1 = 0, 0, 4, 4"
    let expected = [ClassicSteelArea(x: 452, y: 72, width: 64, height: 24),
                    ClassicSteelArea(x: 0, y: 0, width: 4, height: 4)]
    let loaded = try FanLevelReader.level(fromINI: exact)
    let exported = try ClassicLevel(data: FanLevelReader.record(fromINI: exact))
    try require(loaded.steel == expected, "text steel changed")
    try require(exported.steel == expected,
                "DOS-compatible steel did not survive export")
    let extended = base + "steel_0 = 3, -7, 960, 400"
    let level = try FanLevelReader.level(fromINI: extended)
    try require(level.steel == [ClassicSteelArea(x: 3, y: -7, width: 960, height: 400)],
                "text steel was rounded or truncated")
    let legacy = try FanLevelReader.level(fromINI: extended, includeSteel: false)
    try require(legacy.steel.isEmpty,
                "legacy import changed its steel")
    let decoded = try JSONDecoder().decode(ClassicLevel.self, from: JSONEncoder().encode(level))
    try require(decoded == level, "exact text steel did not survive Codable")
    for line in ["steel_0 = 3, -7, 960, 400", "steel_0 = -16, 0, 4, 4"] {
        do {
            _ = try FanLevelReader.record(fromINI: base + line)
            throw Failure(description: "lossy DOS steel export succeeded")
        } catch is FanLevelError { }
    }
    for line in ["steel_0 = 0, 0, 0, 4", "steel_0 = 0, 0, 4, -1",
                 "steel_0 = \(Int.max), 0, 4, 4", "steel_0 = 0, \(Int.max), 4, 4",
                 "steel_0 = 0, 0, 4, 4, 1"] {
        do {
            _ = try FanLevelReader.level(fromINI: base + line)
            throw Failure(description: "invalid steel accepted: \(line)")
        } catch is FanLevelError { }
    }
    print("PASS exact text steel, DOS export, legacy loading and invalid geometry")
}

private func testAShortBinaryLevelIsRejected() throws {
    do {
        _ = try FanLevelReader.level(fromLVL: Data(repeating: 0, count: 1024))
        throw Failure(description: "a 1024 byte level was accepted")
    } catch let error as FanLevelError {
        try require(error == .wrongSize(bytes: 1024), "wrong error: \(error)")
    }
    print("PASS a .lvl file of the wrong size is reported rather than parsed")
}

private func testEveryStyleTheFanPacksUseResolves() throws {
    let ports = root.deletingLastPathComponent()
    let resolver = ClassicStyleResolver(portsRoot: ports)

    // Every name the mirrored packs actually write in a `style =` line.
    let used = [
        "Snow", "Marble", "Pillar", "Brick", "Fire", "Crystal",
        "Bubble", "Dirt", "Rock", "Xmas", "snow", "Christmas",
    ]
    for name in used {
        switch resolver.resolve(styleNamed: name) {
        case .unknown:
            throw Failure(description: "the style \"\(name)\" is not known")
        case let .notInstalled(location):
            throw Failure(description:
                "\(name) needs \(location.release.rawValue), which is not installed")
        case .found, .packSupplied, .specialGraphic:
            continue
        }
    }
    print("PASS all 12 style names the fan packs use resolve to installed data")
}

private func testStyleNamesIgnoreCaseAndSpace() throws {
    let ports = root.deletingLastPathComponent()
    let resolver = ClassicStyleResolver(portsRoot: ports)
    // The packs are not consistent about case, and some lines carry padding.
    try require(
        resolver.resolve(styleNamed: "snow") == resolver.resolve(styleNamed: "Snow"),
        "case changed how a style resolved")
    try require(
        resolver.resolve(styleNamed: "  Marble  ") == resolver.resolve(styleNamed: "Marble"),
        "surrounding space changed how a style resolved")
    print("PASS a style name resolves the same whatever its case or padding")
}

private func testSpecialAndUnknownStylesAreDistinguished() throws {
    let resolver = ClassicStyleResolver(portsRoot: root.deletingLastPathComponent())
    // A level marked Special paints from a VGASPEC file, so having no ground
    // set is correct rather than a failure.
    try require(
        resolver.resolve(styleNamed: "Special") == .specialGraphic,
        "Special was not recognised as a special graphic")
    guard case .unknown = resolver.resolve(styleNamed: "Wobblegong") else {
        throw Failure(description: "an invented style name was accepted")
    }
    print("PASS a special graphic is told apart from a name nobody knows")
}

private func testHolidayAliasesSelectSnow() throws {
    let ports = root.deletingLastPathComponent()
    let xmas1991 = ports.appendingPathComponent("xmas_dos_XmasLemmingsV1.9")
    let snow = try ClassicGroundSet.load(style: 2, from: xmas1991)
    let brick = try ClassicGroundSet.load(style: 0, from: xmas1991)
    let resolver = ClassicStyleResolver(portsRoot: ports)
    for name in ["Xmas", "Christmas", "  CHRISTMAS  "] {
        let actual = try resolver.groundSet(styleNamed: name)
        try require(actual == snow && actual != brick, "\(name) selected promotional brick instead of Holiday snow")
    }

    let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("HolidayAlias-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporary) }
    let xmas1992 = ports.appendingPathComponent("xmas_dos_XmasLemmingsV1.9a1")
    let isolatedRelease = temporary.appendingPathComponent(xmas1992.lastPathComponent)
    try FileManager.default.createDirectory(at: isolatedRelease, withIntermediateDirectories: true)
    for file in ["GROUND2O.DAT", "VGAGR2.DAT"] {
        try FileManager.default.copyItem(at: xmas1992.appendingPathComponent(file),
                                        to: isolatedRelease.appendingPathComponent(file))
    }
    let fallback = ClassicStyleResolver(portsRoot: temporary)
    let expected = try ClassicGroundSet.load(style: 2, from: xmas1992)
    let actual = try fallback.groundSet(styleNamed: "Christmas")
    try require(actual == expected, "Holiday style did not resolve with only Xmas 1992 installed")

    let override = ClassicStyleResolver(portsRoot: ports, packRoot: xmas1992)
    try require(override.resolve(styleNamed: "Xmas") == .packSupplied(directory: xmas1992, index: 2),
                "Holiday pack override did not use its source slot")
    try require(ClassicStyleResolver(portsRoot: temporary.appendingPathComponent("missing"))
        .resolve(styleNamed: "Christmas") == .notInstalled(ClassicStyleResolver.knownStyles["christmas"]!),
        "Missing Holiday assets were not reported")
    print("PASS Holiday aliases select snow, support Xmas 1992 alone, and retain pack overrides")
}

private func testEveryKnownStyleLoadsItsGroundSet() throws {
    let resolver = ClassicStyleResolver(portsRoot: root.deletingLastPathComponent())
    var loaded = 0
    for name in ClassicStyleResolver.knownStyles.keys {
        guard let set = try resolver.groundSet(styleNamed: name) else { continue }
        try require(!set.objects.isEmpty, "\(name) loaded a ground set with no objects")
        loaded += 1
    }
    try require(loaded >= 10, "only \(loaded) style names loaded a ground set")
    print("PASS \(loaded) style names load a real ground set with objects in it")
}

do {
    try testAllThirtyVersusLevelsLoad()
    try testTheNamesAreTheVersusOnes()
    try testOhNoVersusLevelsShareTheirShape()
    try testNumbersRunFromOnePerRelease()
    try testTheExclusivePackIsBuilt()
    try testTheSunsoftLevelsAreTheMegaDriveOnes()
    try testFanLevelReaderEncodesTheTrickyFields()
    try testFanLevelReaderTakesSecondsOrMinutes()
    try testMalformedTextLevelsAreRejected()
    try testTextSteelIsLossless()
    try testAShortBinaryLevelIsRejected()
    try testEveryStyleTheFanPacksUseResolves()
    try testStyleNamesIgnoreCaseAndSpace()
    try testSpecialAndUnknownStylesAreDistinguished()
    try testEveryKnownStyleLoadsItsGroundSet()
    try testHolidayAliasesSelectSnow()
    try testAPackWithNoDataIsEmptyRatherThanBroken()
    print("Amiga versus tests passed.")
} catch {
    FileHandle.standardError.write(Data("Amiga versus tests failed: \(error)\n".utf8))
    exit(1)
}
