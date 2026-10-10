import Testing
import NxlvKit

struct FanTextTerrainTests {
    @Test("Source placements survive DOS terrain range and object alignment")
    func retainsSourceCoordinatesWhenRequested() throws {
        let text = """
            releaseRate = 50
            numLemmings = 2
            numToRescue = 1
            timeLimit = 3
            object_0 = 1, 1750, 291, 0, 0
            terrain_0 = 1, 1605, 296, 8
            """

        let dos = try FanLevelReader.level(fromINI: text)
        let source = try FanLevelReader.level(fromINI: text,
            preserveTerrainCoordinates: true, preserveObjectCoordinates: true)

        #expect(dos.terrain[0].y == -216)
        #expect(source.terrain[0].x == 1605)
        #expect(source.terrain[0].y == 296)
        #expect(source.terrain[0].draw.noOverwrite)
        #expect(source.terrain[0].draw.isUpsideDown == false)
        #expect(dos.objects[0].x == 1744)
        #expect(source.objects[0].x == 1750)
        #expect(source.objects[0].y == 291)
        #expect(try FanLevelReader.canvasSize(fromINI: text,
            defaultWidth: 3200, defaultHeight: 320) == .init(width: 3200, height: 320))
        #expect(try FanLevelReader.canvasSize(fromINI: text + "\nwidth = 3168\nheight = 320",
            defaultWidth: 3200, defaultHeight: 320) == .init(width: 3168, height: 320))
    }
}
