import CoreGraphics
import XCTest
import LemmingsGameArt
@testable import LemmingsMobileCore

final class MobileControlTipMapTests: XCTestCase {
    func testMapCoordinatesMoveBothCameraAxesAndClampAtEveryEdge() throws {
        let level = CGSize(width: 1000, height: 600)
        let verticalOnly = GameMinimapArt.adjustedCentre(in: CGRect(x: 0, y: 100, width: 1000, height: 200),
            levelSize: level, direction: 1)
        XCTAssertEqual(verticalOnly, CGPoint(x: 500, y: 300))
        let socket = CGRect(x: 8, y: 4, width: 320, height: 64)
        let map = GameMinimapArt.content(in: socket, levelSize: level)
        XCTAssertNil(GameMinimapArt.levelPoint(at: CGPoint(x: socket.minX, y: socket.midY), content: map, levelSize: level))
        for aspect in [1.0, 1.2] {
            var camera = MobileViewport(levelSize: .init(width: level.width, height: level.height),
                viewSize: .init(width: 320, height: 180), zoom: 2, pixelAspect: aspect)
            let centre = try XCTUnwrap(GameMinimapArt.levelPoint(at: CGPoint(x: map.midX, y: map.midY),
                content: map, levelSize: level))
            camera.centre(on: .init(x: centre.x, y: centre.y))
            XCTAssertEqual(camera.origin.x + camera.visibleLevelSize.width / 2, 500, accuracy: 0.001)
            XCTAssertEqual(camera.origin.y + camera.visibleLevelSize.height / 2, 300, accuracy: 0.001)
            let bottom = try XCTUnwrap(GameMinimapArt.levelPoint(at: CGPoint(x: map.maxX + 50, y: map.maxY + 50),
                content: map, levelSize: level, clamp: true))
            camera.centre(on: .init(x: bottom.x, y: bottom.y))
            XCTAssertEqual(camera.visibleLevelRect.maxX, 1000, accuracy: 0.001)
            XCTAssertEqual(camera.visibleLevelRect.maxY, 600, accuracy: 0.001)
            camera.centre(on: .init(x: 0, y: 0))
            XCTAssertEqual(camera.origin, .init(x: 0, y: 0))
            XCTAssertEqual(camera.zoom, 2)
        }
    }
}
