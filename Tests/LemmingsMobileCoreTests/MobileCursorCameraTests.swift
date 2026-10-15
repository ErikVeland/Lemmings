import Foundation
import Testing
@testable import LemmingsMobileCore

struct MobileCursorCameraTests {
    @Test(arguments: [1.0, 1.2]) func edgesScrollBothAxesAndRespectLevelBounds(aspect: Double) {
        var viewport = MobileViewport(levelSize: .init(width: 640, height: 160),
            viewSize: .init(width: 960, height: 480), origin: .init(x: 100, y: 40),
            zoom: 6, pixelAspect: aspect)
        let pointer = MobilePoint(x: 960, y: 480)
        let before = viewport.levelPoint(fromView: pointer)
        let moved = viewport.scrollAtEdge(pointer, seconds: 1 / 60)
        #expect(moved)
        let after = viewport.levelPoint(fromView: pointer)
        #expect(after.x > before.x && after.y > before.y)
        for _ in 0..<500 { viewport.scrollAtEdge(pointer, seconds: 0.05) }
        #expect(abs(viewport.visibleLevelRect.maxX - 640) < 0.0001)
        #expect(abs(viewport.visibleLevelRect.maxY - 160) < 0.0001)
        let atBoundary = viewport.scrollAtEdge(pointer, seconds: 0.05)
        #expect(!atBoundary)
        for _ in 0..<500 { viewport.scrollAtEdge(.init(x: 1, y: 1), seconds: 0.05) }
        #expect(viewport.origin == .init(x: 0, y: 0))
    }

    @Test func centreOutsideLetterboxAndInvalidTimeDoNotScroll() {
        var viewport = MobileViewport(levelSize: .init(width: 640, height: 160),
            viewSize: .init(width: 960, height: 480), origin: .init(x: 100, y: 0), zoom: 2)
        let initial = viewport
        for (point, seconds) in [(MobilePoint(x: 480, y: 240), 0.05),
                                  (.init(x: 1, y: 1), 0.05), (.init(x: -1, y: 240), 0.05),
                                  (.init(x: 959, y: 240), 0), (.init(x: 959, y: 240), -1),
                                  (.init(x: 959, y: 240), .nan)] {
            let moved = viewport.scrollAtEdge(point, seconds: seconds)
            #expect(!moved)
            #expect(viewport == initial)
        }
        let moved = viewport.scrollAtEdge(.init(x: 959, y: 240), seconds: 0.05)
        #expect(moved)
        #expect(viewport.origin.x > initial.origin.x && viewport.origin.y == 0)
    }
}
