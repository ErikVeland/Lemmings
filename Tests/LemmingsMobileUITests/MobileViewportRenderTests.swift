import Foundation
import LemmingsMobileCore
import NxlvKit
import Testing
@testable import LemmingsMobileUI

struct MobileViewportRenderTests {
    @Test func neoViewportPreservesProductionActorPixelsAndSimulationState() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: temporary) }
        let library = try NeoLemmixMobileLibrary(directory: root.appendingPathComponent("Content/NeoLemmix"),
            storage: MobileStorage(directory: temporary))
        let index = try #require(library.styleResolvedLevelIndices.first)
        let game = try library.loadLevel(at: index).session
        for _ in 0..<120 { game.tick() }
        let snapshot = game.snapshot
        let full = try game.render(highlight: nil)
        for origin in [0.0, game.entrancePoint.x - 30, game.levelSize.width / 2, game.levelSize.width - 80] {
            let partial = try game.render(highlight: nil, viewport: .init(x: max(0, origin), y: 0,
                width: 80, height: game.levelSize.height))
            let rect = try #require(partial.renderedRect)
            let request = SceneRasterContext.Viewport(levelWidth: Int(game.levelSize.width), levelHeight: Int(game.levelSize.height),
                x: Int(rect.x), y: Int(rect.y), width: Int(rect.width), height: Int(rect.height))
            let expected = SceneRasterContext.request.withValue(request) {
                SceneRasterContext.crop(full.rgba, width: full.width, height: full.height)
            }
            #expect(partial.rgba == expected)
            #expect(game.snapshot == snapshot)
        }
        #expect(try game.render(highlight: nil).rgba == full.rgba)
    }
}
