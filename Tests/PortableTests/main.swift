import Foundation
import CryptoKit
import NxlvKit

private struct TestFailure: Error, CustomStringConvertible {
    let description: String
}

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw TestFailure(description: message) }
}

private func sha256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func objectRGBA(_ indexed: Data, palette: [ClassicRGBColor]) -> Data {
    var output = [UInt8](repeating: 0, count: indexed.count * 4)
    for (index, pixel) in indexed.enumerated() where pixel & 0x80 == 0 {
        let colour = palette[Int(pixel & 0x0F)]
        output[index * 4] = colour.red
        output[index * 4 + 1] = colour.green
        output[index * 4 + 2] = colour.blue
        output[index * 4 + 3] = 255
    }
    return Data(output)
}

private func testClassicArchives(projectDirectory: URL) throws {
    let dataDirectory = projectDirectory.appendingPathComponent("Content/lemming1.pc", isDirectory: true)
    var physicalLevelCount = 0
    var foundSteelVector = false
    for fileID in 0..<10 {
        let filename = String(format: "level%03d.dat", fileID)
        let data = try Data(contentsOf: dataDirectory.appendingPathComponent(filename))
        let sections = try ClassicDATArchive.decode(data)
        try expect(sections.count == 8, "\(filename) should contain eight sections")
        try expect(sections.allSatisfy(\.checksumIsValid), "\(filename) contains an invalid checksum")
        for section in sections {
            let level = try ClassicLevel(data: section.data)
            physicalLevelCount += 1
            if level.steel.contains(ClassicSteelArea(x: 452, y: 72, width: 64, height: 24)) {
                foundSteelVector = true
            }
        }
    }
    try expect(physicalLevelCount == 80, "expected 80 physical classic level records")
    try expect(foundSteelVector, "steel bit-field regression vector was not decoded correctly")
}

private func testClassicFanLevelVectors() throws {
    var bytes = [UInt8](repeating: 0, count: ClassicLevel.recordSize)

    // A nonzero object record with a zero display/modifier word is valid.
    bytes[0x0021] = 1
    bytes[0x0025] = 0xF3

    // The DOS upside-down marker is the complete display byte 0x8F.
    bytes[0x0028 + 1] = 8
    bytes[0x0028 + 5] = 1
    bytes[0x0028 + 7] = 0x80
    bytes[0x0030 + 1] = 16
    bytes[0x0030 + 5] = 1
    bytes[0x0030 + 7] = 0x8F

    let level = try ClassicLevel(data: Data(bytes))
    try expect(level.objects.count == 3, "normal fan object with zero flags was dropped")
    try expect(level.objects[0].x == -16, "fan object X was not rounded to an eight-pixel boundary")
    try expect(level.objects[0].id == 3, "fan object ID was not masked to its low nibble")
    try expect(!level.objects[1].draw.isUpsideDown, "partial upside-down display marker was accepted")
    try expect(level.objects[2].draw.isUpsideDown, "exact upside-down display marker was not accepted")

    var reservedMarker = bytes
    reservedMarker[0x001E] = 0x00
    reservedMarker[0x001F] = 0x01
    let nonSuperLevel = try ClassicLevel(data: Data(reservedMarker))
    try expect(
        !nonSuperLevel.isSuperLemming,
        "a nonzero reserved LVL marker enabled Superlemming mode"
    )
    reservedMarker[0x001E] = 0xFF
    reservedMarker[0x001F] = 0xFF
    let superLevel = try ClassicLevel(data: Data(reservedMarker))
    try expect(
        superLevel.isSuperLemming,
        "the exact 0xFFFF LVL marker did not enable Superlemming mode"
    )
}

private func testClassicCampaign(projectDirectory: URL) throws {
    let campaign = try ClassicCampaignDefinition.originalDOSLemmings.load(
        from: projectDirectory.appendingPathComponent("Content/lemming1.pc", isDirectory: true)
    )
    try expect(campaign.levels.count == 120, "expected the full 120-level campaign")
    try expect(campaign.ranks == ["Fun", "Tricky", "Taxing", "Mayhem"], "campaign ranks are out of order")
    try expect(campaign.levels.filter(\.usesOddTableProperties).count == 40, "expected 40 ODDTABLE repeat levels")

    let expected: [(Int, String, String, Int, Int)] = [
        (0, "Fun", "Just dig!", 9, 1),
        (7, "Fun", "Not as complicated as it looks", 0, 6),
        (21, "Fun", "A Beast of a level", 1, 3),
        (30, "Tricky", "This should be a doddle!", 0, 0),
        (100, "Mayhem", "We all fall down", 6, 7),
        (109, "Mayhem", "No added colours or Lemmings", 9, 2),
        (119, "Mayhem", "Rendezvous at the Mountain", 9, 0),
    ]
    for (index, rank, title, file, section) in expected {
        let item = campaign.levels[index]
        try expect(item.rank == rank, "unexpected rank at campaign index \(index)")
        try expect(item.level.title == title, "unexpected title at campaign index \(index): \(item.level.title)")
        try expect(item.archiveFile == file && item.archiveSection == section, "unexpected source at campaign index \(index)")
    }

    guard let taxing13 = campaign.levels.first(where: { $0.rank == "Taxing" && $0.number == 13 }) else {
        throw TestFailure(description: "Taxing 13 is missing from the campaign")
    }
    let bothFlagArrows = taxing13.level.objects.filter {
        $0.id == 4 && $0.draw.noOverwrite && $0.draw.onlyOverwrite
    }
    try expect(bothFlagArrows.count == 5, "Taxing 13 should retain five both-flag arrow objects")
}

private func testClassicGraphics(projectDirectory: URL) throws {
    let dataDirectory = projectDirectory.appendingPathComponent("Content/lemming1.pc", isDirectory: true)
    let expectedTerrainCounts = [50, 64, 60, 62, 37]
    let expectedTerrainPieceHashes = [
        "84fd5d157688859d12d092fbecb6d31efd9ffc02ccaeb6db9e7c4ec6c29256f4",
        "5558192d30df34efb96086cb29c55284b5ea3740a107601c580bdcd0da1783ac",
        "fd1895a6dcbf395958018d0c2f1cf7811a017d42c2b58d942119faed1639b14e",
        "22c32b89ab3ed7532ee3ebc2a682f1f98004d8f96fc48bc447898d83383e9cec",
        "cdc38eabbeed935d5345dea833050f35ef1bc269ba65dabc747569f37641ed0d",
    ]
    let expectedEntranceFrameHashes = [
        "d824b65ce94d7581daa75c0527e25ad93287767ad59421b8d2177a41793ebaa3",
        "63a543ed5837d60d3ec15ab0d719ea63ad438d20656075db437a51013c90c65c",
        "86610312dca0a19c7c1a5a1e513a7e2f402879bc654bbb9a3b9d8a0b52b66b57",
        "170e828b35ff6d6b8f3af8e072c5adc4a9e3070cb705469fd23c3a832b9ed4aa",
        "3311fdc9d3b2722802373fd5e9517bebbfc38e35f4e6b1f66b0b50ba7fa1eb16",
    ]
    var groundSets: [Int: ClassicGroundSet] = [:]
    for style in 0..<5 {
        let groundSet = try ClassicGroundSet.load(style: style, from: dataDirectory)
        try expect(
            groundSet.terrain.count == expectedTerrainCounts[style],
            "style \(style) terrain-piece count mismatch: \(groundSet.terrain.count)"
        )
        try expect(groundSet.objects[0]?.triggerEffect == 1, "style \(style) object 0 should be an exit")
        try expect(groundSet.objects[1] != nil, "style \(style) should contain entrance object 1")
        try expect(groundSet.objects[1]?.animationType == .onceAtStart, "style \(style) entrance animation type mismatch")
        try expect(
            groundSet.terrain[0].map { sha256($0.indexedPixels) } == expectedTerrainPieceHashes[style],
            "style \(style) terrain piece 0 differs from the independent decoder golden"
        )
        try expect(
            groundSet.objects[1]?.frames.first.map(sha256) == expectedEntranceFrameHashes[style],
            "style \(style) entrance frame differs from the independent decoder golden"
        )
        if style == 0, let arrowFrame = groundSet.objects[3]?.frames.first {
            try expect(
                groundSet.objectPalette[4] == ClassicRGBColor(red: 243, green: 243, blue: 0),
                "style 0 fixed object yellow should use VGA DAC value 60"
            )
            try expect(
                sha256(arrowFrame) == "a9cb691f714e75e6fd121edf35b86ba9612680973565b4553f2d25916774538e",
                "style 0 arrow indexed pixels differ from the independent decoder golden"
            )
            try expect(
                sha256(objectRGBA(arrowFrame, palette: groundSet.objectPalette))
                    == "af7f1d57f7c589025bf4e354132fcaf325296df755b60fe0c30ae1ec11e2b5c1",
                "style 0 arrow colour differs from the fixed DOS gameplay palette golden"
            )
        }
        groundSets[style] = groundSet
    }
    let expectedSpecialRGBAHashes = [
        "74d3e93bbbcb273653fe036cb5acee0048aca267cb66a67d816abb72e2e94f17",
        "9517b14650c82e686d3b470a48520dc1c12fc924ae332e7fe5d583e4cda7c914",
        "e04b8acc38279631f0becb64da0ce3ff8d36e65600ce5d90cdbf013ac6979996",
        "ecb2c4eb4149aae673368add405027427c1d8fb7ed034e69391f1ba9d4fa2fd7",
    ]
    let expectedSpecialMaskHashes = [
        "f79b2a28694f46e901a0d52a257e862e8a360468316885e4acd1906ef138bce4",
        "569f064b943526bfab5f41fd0e6168acffbf4d8ce93b0fc6f0f614f64cc969a1",
        "cbfc9204ad4e0602d8b6dc70f578af457db1c8d56afd86fb571dd457d7750bc8",
        "7a15aff66b86b61d3d76cca4fd9098800ee46941a6d472cb354a21ee0f7fd61f",
    ]
    var specialGraphics: [Int: ClassicSpecialGraphic] = [:]
    for index in 0..<4 {
        let special = try ClassicSpecialGraphic.load(index: index, from: dataDirectory)
        try expect(special.rgba.count == ClassicLevel.width * ClassicLevel.height * 4, "VGASPEC\(index) RGBA size mismatch")
        try expect(special.solidMask.contains(where: { $0 != 0 }), "VGASPEC\(index) contains no solid pixels")
        try expect(
            sha256(special.rgba) == expectedSpecialRGBAHashes[index],
            "VGASPEC\(index) differs from the independent decoder golden"
        )
        try expect(
            sha256(special.solidMask) == expectedSpecialMaskHashes[index],
            "VGASPEC\(index) solid mask differs from the independent decoder golden"
        )
        specialGraphics[index] = special
    }
    let specialArchiveData = try Data(contentsOf: dataDirectory.appendingPathComponent("vgaspec0.dat"))
    let unpackedSpecial = try ClassicDATArchive.decode(specialArchiveData)[0].data
    var specialWithTrailingByte = unpackedSpecial
    specialWithTrailingByte.append(0)
    do {
        _ = try ClassicSpecialGraphic(uncompressedData: specialWithTrailingByte)
        throw TestFailure(description: "VGASPEC trailing data should be rejected")
    } catch is ClassicGraphicsError {
        // Expected.
    }

    var emptySteelLevelBytes = [UInt8](repeating: 0, count: ClassicLevel.recordSize)
    for offset in 0x0120..<0x0760 { emptySteelLevelBytes[offset] = 0xFF }
    emptySteelLevelBytes[0x0760] = 0x02
    emptySteelLevelBytes[0x0761] = 0x00
    emptySteelLevelBytes[0x0762] = 0x00
    let emptySteelLevel = try ClassicLevel(data: Data(emptySteelLevelBytes))
    let emptySteelRender = try ClassicLevelRenderer.render(
        emptySteelLevel,
        groundSet: groundSets[0]!
    )
    try expect(
        emptySteelRender.steelMask.filter { $0 != 0 }.count == 16,
        "steel protection should cover an empty four-by-four region"
    )
    try expect(
        !emptySteelRender.solidMask.contains(where: { $0 != 0 }),
        "an empty steel region must not create invisible terrain"
    )

    let campaign = try ClassicCampaignDefinition.originalDOSLemmings.load(from: dataDirectory)
    let expectedRenderedHashes: [String: (rgba: String, mask: String)] = [
        "9:1": (
            "afbc56cae574e7be4d6eeb8c3c3814eab78415325b334233d0d57da0d19a5288",
            "e5f442169f62c563d856c6b580176f238d915b476d2b8c7e7d86f7b51e209db9"
        ),
        "9:5": (
            "2df5905a25ed2b511f19c35043beb420604dbbddb480f0f5746331c2e305d81b",
            "65a6b09185e5fd9a1e802d65e0aa44cd90f303b1c9b7767647aa8d82ee0ef720"
        ),
        "9:2": (
            "8f8202765e09f6396e676ed29188dd47899114471ea3c5a3db9a6916e5a4ec93",
            "fa4b9b515fc6aee01a7979fc9576d2d06392e9df3c2f2fcd55af308d5b1b5588"
        ),
        "9:3": (
            "42eae95eae41c34353507c857f6c71e3c59c4eec98c2db3d41c8da0fc5acd2fe",
            "4634b9c4240e656aa63bbc6df93ea487da61163a0e3c72e5a3e26d560ff6904c"
        ),
        "9:4": (
            "232b4b7a83e2a440e87b430df82e1c9b9e4ba7527b1d0a3bdc6538303aaef50a",
            "fdb83beb963803f831f983d780a70c7c099767d87d901cd54e1219b318bcbc40"
        ),
    ]
    var renderedSources: Set<String> = []
    var renderedCount = 0
    var visualFakeCount = 0
    var effectBearingFakeCount = 0
    for item in campaign.levels {
        let sourceKey = "\(item.archiveFile):\(item.archiveSection)"
        guard renderedSources.insert(sourceKey).inserted else { continue }
        guard let groundSet = groundSets[item.level.groundStyle] else {
            throw TestFailure(description: "missing decoded ground style \(item.level.groundStyle)")
        }
        let special = item.level.specialStyle == 0 ? nil : specialGraphics[item.level.specialStyle - 1]
        let rendered = try ClassicLevelRenderer.render(item.level, groundSet: groundSet, specialGraphic: special)
        try expect(rendered.rgba.count == ClassicLevel.width * ClassicLevel.height * 4, "rendered RGBA size mismatch")
        try expect(rendered.solidMask.count == ClassicLevel.width * ClassicLevel.height, "rendered solid-mask size mismatch")
        try expect(!rendered.entrances.isEmpty, "\(item.level.title) has no decoded entrance")
        try expect(rendered.triggers.contains(where: { $0.effect == 1 }), "\(item.level.title) has no decoded exit")
        let visualFakes = item.level.objects.filter { $0.slot >= 16 }
        visualFakeCount += visualFakes.count
        effectBearingFakeCount += visualFakes.filter {
            (groundSet.objects[$0.id]?.triggerEffect ?? 0) != 0
        }.count
        let expectedInteractiveTriggerCount = item.level.objects.filter {
            $0.slot < 16 && (groundSet.objects[$0.id]?.triggerEffect ?? 0) != 0
        }.count
        try expect(
            rendered.triggers.count == expectedInteractiveTriggerCount,
            "fake object slot created an interactive trigger in \(sourceKey)"
        )
        if sourceKey == "9:1" {
            try expect(
                rendered.entrances.contains(ClassicPoint(x: 720, y: 42)),
                "Just dig! sprite spawn origin mismatch"
            )
        }
        if let expected = expectedRenderedHashes[sourceKey] {
            try expect(sha256(rendered.rgba) == expected.rgba, "rendered RGBA golden mismatch for \(sourceKey)")
            try expect(sha256(rendered.solidMask) == expected.mask, "rendered solid-mask golden mismatch for \(sourceKey)")
        }
        renderedCount += 1
    }
    try expect(renderedCount == 80, "expected to render all 80 physical level maps")
    try expect(visualFakeCount == 40, "expected 40 visual objects after interactive slot 15")
    try expect(effectBearingFakeCount == 7, "expected seven effect-bearing visual fake objects")
    try expect(expectedRenderedHashes.keys.allSatisfy(renderedSources.contains), "not all rendered map goldens were exercised")
}

private func testNxlvBaseline() throws {
    let text = """
    TITLE Portable Test
    AUTHOR Test Fixture
    THEME orig_marble
    LEMMINGS 20
    SAVE_REQUIREMENT 15
    MAX_SPAWN_INTERVAL 30
    WIDTH 800
    HEIGHT 160

    $SKILLSET
      CLIMBER 5
      BUILDER 10
    $END

    $GADGET
      STYLE orig_marble
      PIECE exit
      X 700
      Y 60
    $END
    """
    guard let level = NxlvLevel(text: text) else {
        throw TestFailure(description: "synthetic NXLV level did not parse")
    }
    try expect(level.title == "Portable Test", "NXLV title mismatch")
    try expect(level.skillset["builder"] == 10, "NXLV skill mismatch")
    try expect(level.gadgets.first?.piece == "exit", "NXLV gadget mismatch")
}

private func testNxlvExtendedModel() throws {
    let source = """
    TiTle Extended Portable Test
    AUTHOR Test Fixture
    ID xFFFFFFFFFFFFFFFF
    VERSION 18446744073709551615
    THEME orig_marble
    MUSIC tune.ogg
    BACKGROUND custom:sky
    LEMMINGS 20
    SAVE_REQUIREMENT 15
    TIME_LIMIT INFINITE
    MAX_SPAWN_INTERVAL 30
    WIDTH 800
    HEIGHT 160
    START_X -x10
    START_Y x20
    UNKNOWN_FIELD retained

    $SKILLSET
      WALKER INFINITE
      JUMPER x0A
    $END

    $TERRAIN
      STYLE custom_terrain
      PIECE block
      X -x10
      Y x20
      ROTATE
      FLIP_HORIZONTAL
      NO_OVERWRITE
    $END

    $TERRAINGROUP
      NAME ledge
      $TERRAIN
        STYLE custom_group
        PIECE fill
        X 1
        Y 2
      $END
    $END

    $GADGET
      STYLE custom_gadget
      PIECE hatch
      X 50
      Y 60
      DIRECTION LEFT
      FLIP_LEMMING
      LEMMINGS 5
      CLIMBER
    $END

    $LEMMING
      X 70
      Y 80
      FLIP_HORIZONTAL
      ZOMBIE
    $END

    $TALISMAN
      TITLE Builders only
      ID xFF
      COLOR GOLD
      SAVE 10
      USE_ONLY_SKILL BUILDER
    $END

    $PRETEXT
      LINE First line
      LINE
    $END

    $POSTTEXT
      LINE Last line
    $END
    """
    let text = "\u{feff}" + source.replacingOccurrences(of: "\n", with: "\r\n")
    let decoded = NxlvLevel.decode(text: text)
    guard let level = decoded.level else {
        throw TestFailure(description: "extended NXLV fixture did not decode")
    }
    try expect(decoded.diagnostics.isEmpty, "valid extended NXLV fixture produced diagnostics")
    try expect(level.id == UInt64.max && level.version == UInt64.max, "NXLV UInt64 fields did not retain their full range")
    try expect(level.screenStart == .position(x: -16, y: 32), "NXLV hexadecimal screen start mismatch")
    try expect(level.timeLimit == .infinite, "NXLV infinite time limit mismatch")
    try expect(level.skillQuantities[.walker] == .infinite, "NXLV infinite skill quantity mismatch")
    try expect(level.skillQuantities[.jumper] == .finite(10), "NXLV hexadecimal skill quantity mismatch")
    try expect(level.terrainPieces.first?.x == -16, "NXLV terrain coordinate mismatch")
    try expect(level.terrainPieces.first?.rotate == true, "NXLV terrain transform mismatch")
    try expect(level.terrainGroups.first?.terrain.first?.style == "custom_group", "NXLV terrain group mismatch")
    try expect(level.gadgets.first?.direction == .left, "NXLV gadget direction mismatch")
    try expect(level.gadgets.first?.lemmingTraits.contains(.climber) == true, "NXLV hatch trait mismatch")
    try expect(level.preplacedLemmings.first?.direction == .left, "NXLV preplaced lemming direction mismatch")
    try expect(level.preplacedLemmings.first?.traits.contains(.zombie) == true, "NXLV preplaced lemming trait mismatch")
    try expect(level.talismans.first?.id == 255, "NXLV talisman ID mismatch")
    try expect(level.talismans.first?.effectiveColor == .gold, "NXLV talisman colour mismatch")
    try expect(level.preText == ["First line", ""], "NXLV pretext blank-line preservation mismatch")
    try expect(level.postText == ["Last line"], "NXLV posttext mismatch")
    try expect(level.dependencies.styles.contains("custom_gadget"), "NXLV style dependency scan mismatch")
    try expect(level.dependencies.backgrounds == ["custom:sky"], "NXLV background dependency scan mismatch")
    try expect(level.document.rendered().contains("UNKNOWN_FIELD retained"), "NXLV unknown field was not preserved")
    try expect(level.document.rendered().contains("TiTle Extended Portable Test"), "NXLV source keyword spelling was not preserved")

    let missing = level.dependencies.missingDiagnostics(from: [
        .theme: ["orig_marble"],
        .style: ["orig_marble", "custom_terrain", "custom_group", "custom_gadget", "custom"],
        .background: [],
        .music: ["tune.ogg"],
    ])
    try expect(missing.count == 1 && missing[0].code.rawValue == "missingDependency", "NXLV missing dependency diagnostic mismatch")

    let malformed = NxlvLevel.decode(text: """
    TITLE Invalid values
    ID -1
    WIDTH nope
    $SKILLSET
      WALKER FOREVER
    $END
    """)
    let diagnosticCodes = Set(malformed.diagnostics.map { $0.code.rawValue })
    try expect(diagnosticCodes.contains("malformedUnsignedInteger"), "NXLV invalid unsigned value was not diagnosed")
    try expect(diagnosticCodes.contains("malformedInteger"), "NXLV invalid integer was not diagnosed")
    try expect(diagnosticCodes.contains("invalidSkillQuantity"), "NXLV invalid skill quantity was not diagnosed")
    try expect(malformed.diagnostics.allSatisfy { $0.line != nil }, "NXLV value diagnostics should include line numbers")
}

private func testMalformedClassicArchive() throws {
    let headerOnly = Data([0, 0, 0, 0, 0, 1, 0, 0, 0, 10])
    do {
        _ = try ClassicDATArchive.decode(headerOnly)
        throw TestFailure(description: "header-only DAT section should be rejected")
    } catch is ClassicDATError {
        // Expected.
    }
}

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: PortableTests <project-directory>\n".utf8))
    Foundation.exit(64)
}

do {
    let projectDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
    try testClassicArchives(projectDirectory: projectDirectory)
    try testClassicFanLevelVectors()
    try testClassicCampaign(projectDirectory: projectDirectory)
    try testClassicGraphics(projectDirectory: projectDirectory)
    try testNxlvBaseline()
    try testNxlvExtendedModel()
    try testMalformedClassicArchive()
    print("Portable core tests passed: 80 rendered maps, 120 campaign levels, DAT, ODDTABLE, VGA/VGASPEC graphics, steel, objects, NXLV.")
} catch {
    FileHandle.standardError.write(Data("test failure: \(error)\n".utf8))
    Foundation.exit(1)
}
