import Foundation
import Testing
@testable import NxlvKit

struct MacExitDoorTests {
    private let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    /// The fire and crystal exits draw their doors right of the DOS trigger.
    /// The exiting lemming moves onto the drawn door; the others barely move.
    @Test func exitingLemmingJumpsIntoTheDrawnDoor() throws {
        let directory = root.appendingPathComponent("Sources/Ports/lemmings_dos_1991-07-30")
        let artwork = try ClassicMacArtwork(directory: root.appendingPathComponent(".build/mac-artwork/export/lemmings"))
        let campaign = try ClassicDataSet.detect(directory: directory).campaign
        let offsetX = -8
        let expected = [0: 1, 1: 6, 2: 2, 3: 2, 4: 10]
        var checked = Set<Int>()
        for entry in campaign.levels where !checked.contains(entry.level.groundStyle) {
            let level = entry.level
            let ground = try ClassicGroundSet.load(style: level.groundStyle, from: directory)
            let special = level.specialStyle > 0
                ? try ClassicSpecialGraphic.load(index: level.specialStyle - 1, from: directory) : nil
            let rendered = try ClassicLevelRenderer.render(level, groundSet: ground, specialGraphic: special)
            let scene = try ClassicMacScene(level: level, rendered: rendered, artwork: artwork, groundSet: ground)
            let exit = try #require(rendered.triggers.first { $0.effect == ClassicDOSObjectEffect.exit.rawValue })
            let footX = (exit.x1 + exit.x2) / 2, footY = exit.y2 - 1
            #expect(scene.exitingShift(footX: footX, footY: footY, spriteOffsetX: offsetX)
                == expected[level.groundStyle], "style \(level.groundStyle)")
            #expect(scene.exitingShift(footX: exit.x2, footY: footY, spriteOffsetX: offsetX) == 0)
            checked.insert(level.groundStyle)
        }
        #expect(checked == Set(expected.keys))
    }
}
