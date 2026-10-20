import Foundation
import Testing
import NxlvKit
@testable import LemmingsMobileCore

struct Lemmings3MobileRendererTests {
    @Test func nativePanelDecoderUsesModeXPlanesAndSixBitPalette() throws {
        var raw = Data(repeating: 0, count: 12_800)
        raw[0] = 1
        raw[3_200] = 2
        raw[6_400] = 3
        raw[9_600] = 4
        var colours = Data(repeating: 0, count: 96)
        colours.replaceSubrange(3...5, with: [63, 32, 0])

        let frame = try Lemmings3MobileSceneRenderer.decodePanel(raw: raw, colours: colours)

        #expect(frame.width == 320)
        #expect(frame.height == 40)
        #expect(Array(frame.rgba[0..<4]) == [255, 129, 0, 255])
        #expect(Array(frame.rgba[4..<8]) == [0, 0, 0, 255])
        #expect(Array(frame.rgba[8..<12]) == [0, 0, 0, 255])
        #expect(Array(frame.rgba[12..<16]) == [0, 0, 0, 255])
        #expect(Array(frame.rgba[(4 * 4)..<(4 * 4 + 4)]) == [0, 0, 0, 255])
    }

    @Test func nativePanelDecoderRejectsInvalidSourceDimensions() {
        #expect(throws: MobileSessionError.invalidFrame) {
            try Lemmings3MobileSceneRenderer.decodePanel(raw: Data(), colours: Data())
        }
    }

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

    @Test func moleUsesTraceMappedFramesForKnownStates() {
        var mole = Lemmings3Runtime.Creature(id: 1, kind: .mole, x: 0, y: 0)
        mole.age = 7
        #expect(Lemmings3MobileSceneRenderer.moleAnimationFrame(for: mole)?.animationIndex == 11)
        #expect(Lemmings3MobileSceneRenderer.moleAnimationFrame(for: mole)?.frameIndex == 3)

        mole.age = 14
        #expect(Lemmings3MobileSceneRenderer.moleAnimationFrame(for: mole)?.animationIndex == 4)
        #expect(Lemmings3MobileSceneRenderer.moleAnimationFrame(for: mole)?.frameIndex == 3)

        mole.age = 31
        mole.digDirection = .downLeft
        mole.cooldown = 5
        #expect(Lemmings3MobileSceneRenderer.moleAnimationFrame(for: mole)?.animationIndex == 9)
        #expect(Lemmings3MobileSceneRenderer.moleAnimationFrame(for: mole)?.frameIndex == 3)

        mole.age = 40
        mole.cooldown = 0
        #expect(Lemmings3MobileSceneRenderer.moleAnimationFrame(for: mole)?.animationIndex == 10)
        #expect(Lemmings3MobileSceneRenderer.moleAnimationFrame(for: mole)?.frameIndex == 2)

        mole.age = 101
        mole.digDirection = .upLeft
        #expect(Lemmings3MobileSceneRenderer.moleAnimationFrame(for: mole)?.animationIndex == 11)
        #expect(Lemmings3MobileSceneRenderer.moleAnimationFrame(for: mole)?.frameIndex == 0)

        mole.age = 146
        mole.digDirection = .downRight
        #expect(Lemmings3MobileSceneRenderer.moleAnimationFrame(for: mole)?.animationIndex == 9)
        #expect(Lemmings3MobileSceneRenderer.moleAnimationFrame(for: mole)?.frameIndex == 5)
    }

    @Test func moleFallsBackWhenStateHasNoCapturedSourceMapping() {
        var mole = Lemmings3Runtime.Creature(id: 1, kind: .mole, x: 0, y: 0)
        mole.age = 181
        mole.digDirection = .down
        #expect(Lemmings3MobileSceneRenderer.moleAnimationFrame(for: mole) == nil)

        let potato = Lemmings3Runtime.Creature(id: 2, kind: .potato, x: 0, y: 0)
        #expect(Lemmings3MobileSceneRenderer.moleAnimationFrame(for: potato) == nil)
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
