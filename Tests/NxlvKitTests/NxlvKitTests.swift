import Testing
@testable import NxlvKit

struct NxlvKitTests {
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

    @Test func testLevelParses() throws {
        let level = try #require(NxlvLevel(text: sample))
        #expect(level.title == "Sample Proving Ground")
        #expect(level.author == "Test Fixture")
        #expect(level.lemmingsCount == 20)
        #expect(level.saveRequirement == 15)
        #expect(level.spawnInterval == 30)
        #expect(level.skillset["builder"] == 10)
        #expect(level.gadgets.first?.piece == "exit")
        #expect(level.gadgets.first?.x == 700)
    }

    @Test func testTabsAndNestedSectionsParse() {
        let root = NxlvParser.parse("$OUTER\n\tVALUE\t42\n$INNER\nNAME nested\n$END\n$END")
        #expect(root.section("outer")?.numeric("value") == 42)
        #expect(root.section("outer")?.section("inner")?.line("name") == "nested")
    }

    @Test func testLastValueWins() {
        let root = NxlvParser.parse("TITLE first\nTITLE second")
        #expect(root.line("title") == "second")
        #expect(root.allLines("title") == ["first", "second"])
    }

    @Test func testReleaseRateFallback() throws {
        let level = try #require(NxlvLevel(text: "TITLE Test\nRELEASE_RATE 50"))
        #expect(level.spawnInterval == 28)
    }

    @Test func testMissingTitleReturnsNil() {
        #expect(NxlvLevel(text: "AUTHOR only") == nil)
    }
}
