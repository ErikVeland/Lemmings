import Testing
@testable import LemmingsMobileCore

struct MobileTerrainCacheTests {
    private let palette: [UInt8] = (0..<256).flatMap { [UInt8($0), UInt8(255 - $0), UInt8($0 / 2), UInt8(255)] }

    @Test func unchangedTerrainReusesConversionAndCompositingCannotMutateIt() {
        let cache = MobileIndexedTerrainCache()
        let pixels: [UInt8] = [1, 2, 3, 4]
        var composed = cache.frame(pixels: pixels, palette: palette)
        composed[0] = 99
        #expect(cache.frame(pixels: pixels, palette: palette) == MobileIndexedTerrainCache.expand(pixels, palette: palette))
        #expect(cache.buildCount == 1)
        #expect(composed[0] == 99)
    }

    @Test func terrainEditsRewindBranchesAndPaletteChangesInvalidateTheCache() {
        let cache = MobileIndexedTerrainCache()
        let original: [UInt8] = [1, 2, 3, 4]
        let edited: [UInt8] = [1, 0, 3, 4]
        _ = cache.frame(pixels: original, palette: palette)
        #expect(cache.frame(pixels: edited, palette: palette) == MobileIndexedTerrainCache.expand(edited, palette: palette))
        #expect(cache.frame(pixels: original, palette: palette) == MobileIndexedTerrainCache.expand(original, palette: palette))
        var changed = palette; changed[4] = 100
        #expect(cache.frame(pixels: original, palette: changed) == MobileIndexedTerrainCache.expand(original, palette: changed))
        #expect(cache.buildCount == 4)
    }

    @Test func chroniclesSparseEditsMatchFreshFullSceneConversionAfterRewind() {
        let width = 16, height = 12
        let background = [UInt8](repeating: 2, count: width * height)
        let pixels = (0..<width * height).map { UInt8($0 % 128) }
        let bricks = (0..<64).map { UInt8($0 + 128) }
        let terrain = MobileEditedTerrain(pixels: pixels, background: background, palette: palette, bricks: bricks, width: width)
        let changes: [[Int: Bool]] = [[:], [1: false, 18: true, 170: true], [1: true, 18: false], [:]]
        for edits in changes {
            var reference = pixels
            for (index, filled) in edits {
                reference[index] = filled ? bricks[(index / width % 8) * 8 + index % width % 8] : background[index]
            }
            #expect(terrain.frame(edits: edits) == MobileIndexedTerrainCache.expand(reference, palette: palette))
        }
    }

    @Test func editedTerrainCacheSurvivesActorWritesAndReturnsToAnEarlierBranch() {
        let terrain = MobileEditedTerrain(pixels: [1, 2, 3, 4], background: [4, 3, 2, 1],
            palette: palette, bricks: [UInt8](repeating: 5, count: 64), width: 2)
        let expected = terrain.frame(edits: [1: false])
        var actorFrame = terrain.frame(edits: [1: false])
        actorFrame[0] = 77
        #expect(terrain.frame(edits: [1: false]) == expected)
        _ = terrain.frame(edits: [1: true])
        #expect(terrain.frame(edits: [1: false]) == expected)
        #expect(actorFrame[0] == 77)
    }

    @Test func concurrentRendererCopiesKeepIndependentCompositedFrames() async {
        let cache = MobileIndexedTerrainCache()
        let pixels: [UInt8] = [1, 2, 3, 4]
        let palette = palette
        await withTaskGroup(of: [UInt8].self) { group in
            for index in 0..<16 {
                group.addTask {
                    var frame = cache.frame(pixels: pixels, palette: palette)
                    frame[0] = UInt8(index)
                    return frame
                }
            }
            var values = Set<UInt8>()
            for await frame in group { values.insert(frame[0]) }
            #expect(values.count == 16)
        }
        #expect(cache.frame(pixels: pixels, palette: palette)[0] == 1)
        #expect(cache.buildCount == 1)
    }
}
