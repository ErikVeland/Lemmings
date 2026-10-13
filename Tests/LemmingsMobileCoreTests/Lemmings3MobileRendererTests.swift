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
}
