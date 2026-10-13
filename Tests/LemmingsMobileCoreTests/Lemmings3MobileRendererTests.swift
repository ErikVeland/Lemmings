import Foundation
import Testing
@testable import LemmingsMobileCore

struct Lemmings3MobileRendererTests {
    @Test func creatureSpriteUsesItsOwnPaletteAndHonoursTransparency() {
        var palette = [UInt8](repeating: 0, count: 1024)
        palette[4...7] = [210, 120, 30, 255]
        var canvas: [UInt8] = [20, 40, 60, 255, 20, 40, 60, 255]

        Lemmings3MobileSceneRenderer.composite(
            [1, 2], opaque: [true, false], frameWidth: 2, frameHeight: 1, palette: palette,
            x: 0, y: 0, width: 2, height: 1, into: &canvas)

        #expect(canvas == [210, 120, 30, 255, 20, 40, 60, 255])
    }

    @Test func animatedTrapFrameUsesRuntimeFrameAndClampsToDecodedFrames() {
        #expect(Lemmings3MobileSceneRenderer.animatedFrameIndex(1, count: 3) == 1)
        #expect(Lemmings3MobileSceneRenderer.animatedFrameIndex(-1, count: 3) == 0)
        #expect(Lemmings3MobileSceneRenderer.animatedFrameIndex(4, count: 3) == 2)
        #expect(Lemmings3MobileSceneRenderer.animatedFrameIndex(0, count: 0) == nil)
    }

    @Test func animatedTrapFrameCompositesItsPaletteAndKeepsTransparentPixels() throws {
        var palette = [UInt8](repeating: 0, count: 1024)
        palette[4...7] = [210, 120, 30, 255]
        var canvas: [UInt8] = [20, 40, 60, 255, 20, 40, 60, 255]
        let frame = try Lemmings3MobileSceneRenderer.AnimatedObject.Frame(
            width: 2, height: 1, pixels: [1, 255], palette: palette)

        Lemmings3MobileSceneRenderer.composite(
            frame, x: 0, y: 0, width: 2, height: 1, into: &canvas)

        #expect(canvas == [210, 120, 30, 255, 20, 40, 60, 255])
    }

    @Test func animatedTrapFrameRejectsInvalidDimensionsAndPalette() {
        #expect(throws: MobileSessionError.invalidFrame) {
            try Lemmings3MobileSceneRenderer.AnimatedObject.Frame(
                width: 2, height: 1, pixels: [1], palette: [UInt8](repeating: 0, count: 1024))
        }
        #expect(throws: MobileSessionError.invalidFrame) {
            try Lemmings3MobileSceneRenderer.AnimatedObject.Frame(
                width: 1, height: 1, pixels: [1], palette: [0, 0, 0, 255])
        }
    }

    @Test func fireballUsesTheNativeSixByFourFootprint() {
        var canvas = [UInt8](repeating: 0, count: 6 * 4 * 4)

        Lemmings3MobileSceneRenderer.compositeFireball(
            x: 0, y: 0, width: 6, height: 4, into: &canvas)

        let core = (1 * 6 + 3) * 4
        #expect(Array(canvas[core..<core + 4]) == [255, 255, 238, 255])
        let transparent = 0
        #expect(Array(canvas[transparent..<transparent + 4]) == [0, 0, 0, 0])
    }
}
