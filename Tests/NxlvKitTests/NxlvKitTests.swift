import XCTest
@testable import NxlvKit

final class NxlvKitTests: XCTestCase {
    private let sample = """
    TITLE Sample Proving Ground
    AUTHOR Test Fixture
    THEME orig_marble
    LEMMINGS 20
    SAVE_REQUIREMENT 15
    MAX_SPAWN_INTERVAL 30
    WIDTH 800
    HEIGHT 160
    START_X 100
    START_Y 80

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

    func testLevelParses() throws {
        let level = try XCTUnwrap(NxlvLevel(text: sample))
        XCTAssertEqual(level.title, "Sample Proving Ground")
        XCTAssertEqual(level.author, "Test Fixture")
        XCTAssertEqual(level.lemmingsCount, 20)
        XCTAssertEqual(level.saveRequirement, 15)
        XCTAssertEqual(level.spawnInterval, 30)
        XCTAssertEqual(level.skillset["builder"], 10)
        XCTAssertEqual(level.gadgets.first?.piece, "exit")
        XCTAssertEqual(level.gadgets.first?.x, 700)
    }

    func testTabsAndNestedSectionsParse() {
        let root = NxlvParser.parse("$OUTER\n\tVALUE\t42\n$INNER\nNAME nested\n$END\n$END")
        XCTAssertEqual(root.section("outer")?.numeric("value"), 42)
        XCTAssertEqual(root.section("outer")?.section("inner")?.line("name"), "nested")
    }

    func testLastValueWins() {
        let root = NxlvParser.parse("TITLE first\nTITLE second")
        XCTAssertEqual(root.line("title"), "second")
        XCTAssertEqual(root.allLines("title"), ["first", "second"])
    }

    func testReleaseRateFallback() throws {
        let level = try XCTUnwrap(NxlvLevel(text: "TITLE Test\nRELEASE_RATE 50"))
        XCTAssertEqual(level.spawnInterval, 28)
    }

    func testMissingTitleReturnsNil() {
        XCTAssertNil(NxlvLevel(text: "AUTHOR only"))
    }
}
