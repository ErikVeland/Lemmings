import Foundation
import NxlvKit
import Testing
@testable import LemmingsMobileCore

struct Lemmings2MobileRendererTests {
    @Test func indexedPixelsUseTheNativePalette() {
        var palette = [UInt8](repeating: 0, count: 128 * 4)
        palette[0...3] = [3, 5, 7, 255]
        palette[4...7] = [11, 13, 17, 255]

        let rgba = Lemmings2MobileSceneRenderer.expand([0, 1], palette: palette)

        #expect(rgba == [3, 5, 7, 255, 11, 13, 17, 255])
    }

    @Test func transparentSpritePixelsLeaveTerrainVisible() {
        var palette = [UInt8](repeating: 0, count: 128 * 4)
        palette[4...7] = [200, 100, 50, 255]
        let frame = Lemmings2SpriteFrame(x: 0, y: 0, width: 2, height: 1,
                                         pixels: [1, 1], opaque: [true, false])
        var canvas: [UInt8] = [20, 30, 40, 255, 20, 30, 40, 255]

        Lemmings2MobileSceneRenderer.composite(frame, palette: palette, atX: 0, y: 0,
                                               width: 2, height: 1, into: &canvas)

        #expect(canvas == [200, 100, 50, 255, 20, 30, 40, 255])
    }

    @Test func spriteCompositingClipsAndMirrorsAtTheLevelEdge() {
        var palette = [UInt8](repeating: 0, count: 128 * 4)
        palette[4...7] = [80, 90, 100, 255]
        let frame = Lemmings2SpriteFrame(x: 0, y: 0, width: 2, height: 1,
                                         pixels: [1, 1], opaque: [true, true])
        var canvas = [UInt8](repeating: 0, count: 8)

        Lemmings2MobileSceneRenderer.composite(frame, palette: palette, atX: -1, y: 0,
                                               width: 2, height: 1, mirrored: true, into: &canvas)

        #expect(canvas == [80, 90, 100, 255, 0, 0, 0, 0])
    }
}
