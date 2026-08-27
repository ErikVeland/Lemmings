import Foundation
import NxlvKit

enum TestFailure: Error, CustomStringConvertible {
    case assertion(String)

    var description: String {
        switch self {
        case let .assertion(message): message
        }
    }
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw TestFailure.assertion(message) }
}

func write(_ text: String, to url: URL) throws {
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try Data(text.utf8).write(to: url)
}

func touch(_ url: URL) throws {
    try write("", to: url)
}

func contains(
    _ code: NxlvStyleDiagnosticCode,
    in diagnostics: [NxlvStyleDiagnostic]
) -> Bool {
    diagnostics.contains { $0.code == code }
}

func testCaseInsensitiveResolution(_ fixture: URL) throws {
    let styles = fixture.appendingPathComponent("styles", isDirectory: true)
    let style = styles.appendingPathComponent("Orig_Marble", isDirectory: true)
    try write("LEMMINGS default\n", to: style.appendingPathComponent("Theme.NXMI"))
    try touch(style.appendingPathComponent("Terrain/Steel_01.PNG"))
    try write(
        "STEEL\nRESIZE_BOTH\nDEFAULT_WIDTH 32\nNINE_SLICE_LEFT 3\n",
        to: style.appendingPathComponent("Terrain/steel_01.NXMT")
    )
    try write(
        """
        EFFECT EXIT
        TRIGGER_X 4
        TRIGGER_Y 8
        TRIGGER_WIDTH 12
        TRIGGER_HEIGHT 16
        EDITOR_CROP false
        $PRIMARY_ANIMATION
          FRAMES 4
          HORIZONTAL_STRIP
        $END
        $ANIMATION
          NAME glow
          FRAMES 2
          OFFSET_X -1
          Z_INDEX 3
        $END
        """,
        to: style.appendingPathComponent("Objects/Exit.NXMO")
    )
    try touch(style.appendingPathComponent("Objects/EXIT.PNG"))
    try touch(style.appendingPathComponent("Objects/exit_GLOW.png"))
    try touch(style.appendingPathComponent("Backgrounds/Sky.PNG"))

    let level = try NxlvLevel(text: """
    TITLE Resolver Fixture
    THEME orig_marble
    BACKGROUND ORIG_MARBLE:sKy
    $TERRAIN
      STYLE ORIG_MARBLE
      PIECE STEEL_01
    $END
    $GADGET
      STYLE orig_marble
      PIECE exit
    $END
    """).unwrap("The fixture level did not parse.")

    let result = NxlvStyleResolver(stylesRootURL: styles).resolve(level: level)
    try expect(result.isComplete, "Case-insensitive resolution reported an error: \(result.diagnostics)")
    try expect(result.assets.count == 4, "Expected theme, terrain, object, and background assets.")

    let terrain = try result.assets.first { $0.reference.kind == .terrain }
        .unwrap("The terrain asset did not resolve.")
    try expect(terrain.terrainMetadata?.isSteel == true, "STEEL was not parsed.")
    try expect(terrain.terrainMetadata?.resizeAxes == .both, "RESIZE_BOTH was not parsed.")
    try expect(terrain.terrainMetadata?.defaultWidth == 32, "DEFAULT_WIDTH was not parsed.")
    try expect(terrain.terrainMetadata?.nineSlice.left == 3, "Nine-slice data was not parsed.")

    let object = try result.assets.first { $0.reference.kind == .object }
        .unwrap("The object asset did not resolve.")
    try expect(object.objectMetadata?.effect == .exit, "The EXIT effect was not parsed.")
    try expect(object.objectMetadata?.triggerWidth == 12, "The trigger area was not parsed.")
    try expect(object.objectMetadata?.editorCrop == false, "EDITOR_CROP was not parsed.")
    try expect(object.objectMetadata?.animations.count == 2, "Expected two object animations.")
    try expect(object.graphicURLs.count == 2, "Expected two object animation graphics.")
}

func testTraversalAndSymlinkSafety(_ fixture: URL) throws {
    let styles = fixture.appendingPathComponent("safe-styles", isDirectory: true)
    let outside = fixture.appendingPathComponent("outside", isDirectory: true)
    try FileManager.default.createDirectory(at: styles, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
    try touch(outside.appendingPathComponent("theme.nxmi"))

    let traversal = NxlvStyleResolver(stylesRootURL: styles).resolve(references: [
        NxlvStyleAssetReference(kind: .terrain, style: "..", piece: "secret"),
        NxlvStyleAssetReference(kind: .terrain, style: "safe", piece: "../secret")
    ])
    try expect(
        traversal.diagnostics.filter { $0.code == .unsafeIdentifier }.count == 2,
        "Traversal identifiers were not rejected."
    )

    let link = styles.appendingPathComponent("EscapedStyle")
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)
    let escaped = NxlvStyleResolver(stylesRootURL: styles).resolve(references: [
        NxlvStyleAssetReference(kind: .theme, style: "escapedstyle")
    ])
    try expect(contains(.unsafeResolvedPath, in: escaped.diagnostics), "An escaping symlink was accepted.")
    try expect(escaped.assets.isEmpty, "An asset outside the styles root was returned.")
}

func testMissingAndAmbiguousAssets(_ fixture: URL) throws {
    let styles = fixture.appendingPathComponent("diagnostic-styles", isDirectory: true)
    let terrain = styles.appendingPathComponent("custom/Terrain", isDirectory: true)
    try touch(terrain.appendingPathComponent("rock.png"))
    try write("STEEL\n", to: terrain.appendingPathComponent("rock.nxmt"))
    try write("", to: terrain.appendingPathComponent("rock.nxtm"))

    let resolver = NxlvStyleResolver(stylesRootURL: styles)
    let result = resolver.resolve(references: [
        NxlvStyleAssetReference(kind: .terrain, style: "missing", piece: "rock"),
        NxlvStyleAssetReference(kind: .terrain, style: "custom", piece: "absent"),
        NxlvStyleAssetReference(kind: .terrain, style: "custom", piece: "rock")
    ])
    try expect(contains(.missingStyle, in: result.diagnostics), "A missing style was not diagnosed.")
    try expect(contains(.missingPieceGraphic, in: result.diagnostics), "A missing piece was not diagnosed.")
    try expect(
        contains(.ambiguousPieceMetadata, in: result.diagnostics),
        "Competing NXMT/NXTM metadata was not diagnosed."
    )
    try expect(!result.isComplete, "A result with missing assets was marked complete.")
}

func testMetadataDiagnosticsAndLimit(_ fixture: URL) throws {
    let styles = fixture.appendingPathComponent("metadata-styles", isDirectory: true)
    let objects = styles.appendingPathComponent("objects_bad/objects", isDirectory: true)
    try write(
        """
        EFFECT QUICKSAND
        TRIGGER_X nope
        $PRIMARY_ANIMATION
          FRAMES many
        $END
        """,
        to: objects.appendingPathComponent("bad.nxmo")
    )
    try touch(objects.appendingPathComponent("bad.png"))

    let malformed = NxlvStyleResolver(stylesRootURL: styles).resolve(references: [
        NxlvStyleAssetReference(kind: .object, style: "objects_bad", piece: "bad")
    ])
    try expect(contains(.unknownObjectEffect, in: malformed.diagnostics), "An unknown effect was not diagnosed.")
    try expect(
        contains(.malformedMetadataInteger, in: malformed.diagnostics),
        "Malformed metadata integers were not diagnosed."
    )
    try expect(!malformed.isComplete, "Malformed object metadata was marked complete.")

    let limited = NxlvStyleResolver(
        stylesRootURL: styles,
        maximumMetadataBytes: 8
    ).resolve(references: [
        NxlvStyleAssetReference(kind: .object, style: "objects_bad", piece: "bad")
    ])
    try expect(contains(.metadataTooLarge, in: limited.diagnostics), "The metadata size limit was not enforced.")
}

func testRecursiveAliasesAndDefaults(_ fixture: URL) throws {
    let styles = fixture.appendingPathComponent("alias-styles", isDirectory: true)
    try write(
        """
        $STYLE
          FROM OldTheme
          TO MidTheme
        $END
        $STYLE
          FROM midtheme
          TO FinalStyle
        $END
        $LEMMINGS
          FROM OldLems
          TO NewLems
        $END
        """,
        to: styles.appendingPathComponent("default/ALIAS.NXMI")
    )
    try write(
        """
        $TERRAIN
          FROM :OldRock
          TO MidStyle:Middle
          WIDTH 90
          HEIGHT 50
        $END
        $GADGET
          FROM :OldDoor
          TO AssetStyle:Door
          WIDTH 80
          HEIGHT 48
        $END
        $BACKGROUND
          FROM :OldSky
          TO AssetStyle:Sky
        $END
        """,
        to: styles.appendingPathComponent("FinalStyle/Alias.NxMi")
    )
    try write(
        """
        $TERRAIN
          FROM :middle
          TO assetstyle:rock
          WIDTH 33
          HEIGHT 17
        $END
        """,
        to: styles.appendingPathComponent("MidStyle/alias.nxmi")
    )

    try write("LEMMINGS default\n", to: styles.appendingPathComponent("FinalStyle/theme.nxtm"))
    try touch(styles.appendingPathComponent("AssetStyle/terrain/Rock.PNG"))
    try write("STEEL\n", to: styles.appendingPathComponent("AssetStyle/terrain/rock.NXMT"))
    try write(
        """
        EFFECT EXIT
        $PRIMARY_ANIMATION
          FRAMES 1
        $END
        """,
        to: styles.appendingPathComponent("AssetStyle/objects/door.NXMO")
    )
    try touch(styles.appendingPathComponent("AssetStyle/objects/DOOR.png"))
    try touch(styles.appendingPathComponent("AssetStyle/backgrounds/SKY.PNG"))
    try touch(styles.appendingPathComponent("NewLems/lemmings/WALKER.PNG"))
    try write("", to: styles.appendingPathComponent("NewLems/lemmings/Scheme.NXMI"))

    let references = [
        NxlvStyleAssetReference(kind: .theme, style: "oldtheme", sourceLine: 1),
        NxlvStyleAssetReference(kind: .terrain, style: "finalstyle", piece: "oldrock", sourceLine: 2),
        NxlvStyleAssetReference(kind: .object, style: "FINALSTYLE", piece: "olddoor", sourceLine: 3),
        NxlvStyleAssetReference(kind: .background, style: "FinalStyle", piece: "oldsky", sourceLine: 4),
        NxlvStyleAssetReference(kind: .lemmings, style: "oldlems", sourceLine: 5)
    ]
    let result = NxlvStyleResolver(stylesRootURL: styles).resolve(references: references)
    try expect(result.isComplete, "Valid recursive aliases reported an error: \(result.diagnostics)")
    try expect(result.assets.count == 5, "Expected all five aliased asset kinds to resolve.")

    let theme = try result.assets.first { $0.reference.kind == .theme }
        .unwrap("The aliased theme did not resolve.")
    try expect(theme.reference.style == "oldtheme", "The original theme reference was not preserved.")
    try expect(
        theme.resolvedReference.style.caseInsensitiveCompare("FinalStyle") == .orderedSame,
        "The recursive style aliases did not resolve."
    )
    try expect(theme.metadataURL?.pathExtension.lowercased() == "nxtm", "Current theme.nxtm metadata did not resolve.")

    let terrain = try result.assets.first { $0.reference.kind == .terrain }
        .unwrap("The recursively aliased terrain did not resolve.")
    try expect(
        terrain.resolvedReference.style.caseInsensitiveCompare("AssetStyle") == .orderedSame
            && terrain.resolvedReference.piece?.caseInsensitiveCompare("rock") == .orderedSame,
        "The recursive terrain alias did not reach its physical asset."
    )
    try expect(terrain.aliasDefaultWidth == 33, "The final terrain alias width was not retained.")
    try expect(terrain.aliasDefaultHeight == 17, "The final terrain alias height was not retained.")
    try expect(terrain.terrainMetadata?.isSteel == true, "Aliased terrain metadata was not decoded.")

    let object = try result.assets.first { $0.reference.kind == .object }
        .unwrap("The aliased gadget did not resolve.")
    try expect(object.resolvedReference.piece == "Door", "The GADGET alias target was not retained.")
    try expect(object.aliasDefaultWidth == 80, "The gadget alias width was not retained.")
    try expect(object.aliasDefaultHeight == 48, "The gadget alias height was not retained.")

    let background = try result.assets.first { $0.reference.kind == .background }
        .unwrap("The aliased background did not resolve.")
    try expect(background.resolvedReference.piece == "Sky", "The BACKGROUND alias did not resolve.")

    let lemmings = try result.assets.first { $0.reference.kind == .lemmings }
        .unwrap("The aliased lemming sprite set did not resolve.")
    try expect(lemmings.resolvedReference.style == "NewLems", "The LEMMINGS alias did not resolve.")
    try expect(lemmings.graphicURLs.count == 1, "The lemming sprite graphics were not collected.")
    try expect(lemmings.metadataURL?.lastPathComponent == "Scheme.NXMI", "The lemming scheme did not resolve.")
}

func testAliasCycleAndDepthDiagnostics(_ fixture: URL) throws {
    let cycleStyles = fixture.appendingPathComponent("alias-cycle-styles", isDirectory: true)
    try write(
        """
        $STYLE
          FROM CycleA
          TO CycleB
        $END
        $STYLE
          FROM cycleb
          TO cyclea
        $END
        """,
        to: cycleStyles.appendingPathComponent("default/alias.nxmi")
    )
    let styleCycle = NxlvStyleResolver(stylesRootURL: cycleStyles).resolve(references: [
        NxlvStyleAssetReference(kind: .theme, style: "cyclea")
    ])
    try expect(contains(.aliasCycle, in: styleCycle.diagnostics), "A recursive style alias cycle was not diagnosed.")
    try expect(styleCycle.assets.isEmpty, "A cyclic style alias returned an asset.")

    let pieceStyles = fixture.appendingPathComponent("piece-cycle-styles", isDirectory: true)
    try write(
        """
        $TERRAIN
          FROM :A
          TO :B
        $END
        $TERRAIN
          FROM :b
          TO :a
        $END
        """,
        to: pieceStyles.appendingPathComponent("CyclePieces/alias.nxmi")
    )
    let pieceCycle = NxlvStyleResolver(stylesRootURL: pieceStyles).resolve(references: [
        NxlvStyleAssetReference(kind: .terrain, style: "cyclepieces", piece: "a")
    ])
    try expect(contains(.aliasCycle, in: pieceCycle.diagnostics), "A recursive piece alias cycle was not diagnosed.")

    let depthStyles = fixture.appendingPathComponent("alias-depth-styles", isDirectory: true)
    try write(
        """
        $STYLE
          FROM DepthA
          TO DepthB
        $END
        $STYLE
          FROM DepthB
          TO DepthC
        $END
        $STYLE
          FROM DepthC
          TO DepthD
        $END
        """,
        to: depthStyles.appendingPathComponent("default/alias.nxmi")
    )
    let tooDeep = NxlvStyleResolver(
        stylesRootURL: depthStyles,
        maximumAliasDepth: 2
    ).resolve(references: [
        NxlvStyleAssetReference(kind: .theme, style: "DepthA")
    ])
    try expect(contains(.aliasDepthExceeded, in: tooDeep.diagnostics), "The alias depth limit was not enforced.")
    try expect(tooDeep.assets.isEmpty, "An over-depth alias chain returned an asset.")
}

func testAliasSafetyAndAmbiguity(_ fixture: URL) throws {
    let unsafeStyles = fixture.appendingPathComponent("unsafe-alias-styles", isDirectory: true)
    try write(
        """
        $TERRAIN
          FROM safe:old
          TO ../outside:secret
        $END
        """,
        to: unsafeStyles.appendingPathComponent("default/alias.nxmi")
    )
    try touch(unsafeStyles.appendingPathComponent("safe/terrain/old.png"))
    let unsafe = NxlvStyleResolver(stylesRootURL: unsafeStyles).resolve(references: [
        NxlvStyleAssetReference(kind: .terrain, style: "safe", piece: "old")
    ])
    try expect(contains(.unsafeIdentifier, in: unsafe.diagnostics), "An unsafe alias destination was not diagnosed.")
    try expect(!unsafe.isComplete, "An unsafe alias destination was marked complete.")

    let ambiguousStyles = fixture.appendingPathComponent("ambiguous-alias-styles", isDirectory: true)
    try write(
        """
        $TERRAIN
          FROM source:old
          TO target:first
        $END
        $TERRAIN
          FROM SOURCE:OLD
          TO target:second
        $END
        """,
        to: ambiguousStyles.appendingPathComponent("default/alias.nxmi")
    )
    let ambiguous = NxlvStyleResolver(stylesRootURL: ambiguousStyles).resolve(references: [
        NxlvStyleAssetReference(kind: .terrain, style: "Source", piece: "Old")
    ])
    try expect(contains(.ambiguousAlias, in: ambiguous.diagnostics), "Conflicting aliases were not diagnosed.")
    try expect(ambiguous.assets.isEmpty, "A conflicting alias returned an asset.")

    let malformedStyles = fixture.appendingPathComponent("malformed-alias-styles", isDirectory: true)
    try write(
        """
        $GADGET
          FROM :old
          TO :new
          WIDTH many
        $END
        $BACKGROUND
          FROM no_colon
          TO :sky
        $END
        $STYLE
          FROM only_source
        $END
        """,
        to: malformedStyles.appendingPathComponent("default/alias.nxmi")
    )
    let malformed = NxlvStyleResolver(stylesRootURL: malformedStyles).resolve(references: [
        NxlvStyleAssetReference(kind: .object, style: "default", piece: "old")
    ])
    try expect(contains(.malformedAliasInteger, in: malformed.diagnostics), "A malformed alias size was not diagnosed.")
    try expect(contains(.malformedAliasIdentifier, in: malformed.diagnostics), "A malformed piece alias was not diagnosed.")
    try expect(contains(.missingAliasField, in: malformed.diagnostics), "A missing alias field was not diagnosed.")
}

func testReferenceScan() throws {
    let level = try NxlvLevel(text: """
    TITLE Reference Scan
    BACKGROUND malformed
    $TERRAIN
      STYLE *GROUP
      PIECE local_group
    $END
    $TERRAIN
      PIECE missing_style
    $END
    $GADGET
      STYLE custom
    $END
    """).unwrap("The reference-scan fixture did not parse.")
    let scan = level.scanStyleAssetReferences()
    try expect(scan.references.isEmpty, "Local groups or incomplete references escaped the scan.")
    try expect(contains(.missingStyleIdentifier, in: scan.diagnostics), "Missing STYLE was not diagnosed.")
    try expect(contains(.missingPieceIdentifier, in: scan.diagnostics), "Missing PIECE was not diagnosed.")
    try expect(
        contains(.malformedBackgroundIdentifier, in: scan.diagnostics),
        "Malformed BACKGROUND was not diagnosed."
    )
}

extension Optional {
    func unwrap(_ message: String) throws -> Wrapped {
        guard let self else { throw TestFailure.assertion(message) }
        return self
    }
}

@main
struct NxlvStyleResolverTests {
    static func main() throws {
        let fixture = FileManager.default.temporaryDirectory
            .appendingPathComponent("NxlvStyleResolverTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: fixture, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: fixture) }

        try testCaseInsensitiveResolution(fixture)
        try testTraversalAndSymlinkSafety(fixture)
        try testMissingAndAmbiguousAssets(fixture)
        try testMetadataDiagnosticsAndLimit(fixture)
        try testRecursiveAliasesAndDefaults(fixture)
        try testAliasCycleAndDepthDiagnostics(fixture)
        try testAliasSafetyAndAmbiguity(fixture)
        try testReferenceScan()
        print("NXLV style resolver tests passed.")
    }
}
