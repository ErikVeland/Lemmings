import Foundation

/**
 * Supplies original starter levels without commercial game data or destruction masks.
 */
public enum OpenStarterContent {
    public static let identifier = "ultimate-lemmix-open-starter-v1"

    /**
     * Identifies the authored campaign without inspecting a game-data folder.
     */
    public static func isStarter(_ dataSet: ClassicDataSet) -> Bool {
        dataSet.levelFilePrefix == identifier && dataSet.title == nil
    }

    /**
     * Builds three original routes for walking, floating and climbing.
     */
    public static func makeDataSet() throws -> ClassicDataSet {
        let levels = try [
            level(title: "First Steps", population: 6, floor: 112, hatchY: 66, skill: nil),
            level(title: "Float to Safety", population: 3, floor: 136, hatchY: 16, skill: .floater),
            level(title: "Over the Rise", population: 4, floor: 130, hatchY: 80, skill: .climber),
        ]
        return ClassicDataSet(
            kind: .scanned, title: nil, name: "Open Starter", levelFilePrefix: identifier,
            campaign: ClassicCampaign(name: "Open Starter", levels: levels.enumerated().map {
                .standalone($0.element, rank: "Starter", number: $0.offset + 1)
            }), groundStyles: [0], specialIndices: [])
    }

    /**
     * Defines terrain geometry and object triggers for the independent puzzles.
     * LixSceneArtwork supplies the full-colour presentation.
     */
    public static func makeGroundSet() -> ClassicGroundSet {
        let palette: [ClassicRGBColor] = [
            .init(red: 12, green: 17, blue: 28), .init(red: 90, green: 61, blue: 43),
            .init(red: 132, green: 94, blue: 63), .init(red: 162, green: 125, blue: 74),
            .init(red: 67, green: 127, blue: 79), .init(red: 98, green: 178, blue: 111),
            .init(red: 220, green: 217, blue: 176), .init(red: 43, green: 61, blue: 82),
        ]
        let floor = (0..<256).map { pixel -> UInt8 in
            let x = pixel % 16, y = pixel / 16
            return y < 2 ? 3 : (x + y * 3) % 7 == 0 ? 1 : 2
        }
        let wall = (0..<(16 * 44)).map { pixel -> UInt8 in
            let x = pixel % 16, y = pixel / 16
            return y < 2 ? 3 : x == 0 || x == 15 || y % 8 == 7 ? 1 : 2
        }
        func doorway(width: Int, height: Int, exit: Bool) -> Data {
            var pixels = [UInt8](repeating: 0x80, count: width * height)
            for y in 2..<height {
                for x in 3..<(width - 3) {
                    let border = x < 6 || x >= width - 6 || y < 5
                    pixels[y * width + x] = border ? 6 : exit ? 4 : 7
                }
            }
            if exit {
                for y in 8..<16 {
                    pixels[y * width + width / 2] = 5
                    if y < 12 { pixels[y * width + width / 2 + 1] = 5 }
                }
            }
            return Data(pixels)
        }
        let exit = ClassicObjectGraphic(
            id: 0, width: 24, height: 24, frames: [doorway(width: 24, height: 24, exit: true)],
            animationType: .none, firstFrameIndex: 0, triggerLeft: 4, triggerTop: 16,
            triggerWidth: 16, triggerHeight: 16, triggerEffect: ClassicDOSObjectEffect.exit.rawValue,
            trapSoundEffect: 0)
        let hatch = ClassicObjectGraphic(
            id: 1, width: 32, height: 20, frames: [doorway(width: 32, height: 20, exit: false)],
            animationType: .none, firstFrameIndex: 0, triggerLeft: 0, triggerTop: 0,
            triggerWidth: 0, triggerHeight: 0, triggerEffect: 0, trapSoundEffect: 0)
        return ClassicGroundSet(
            authoredStyle: 0, terrainPalette: palette, objectPalette: palette + palette,
            terrain: [
                0: ClassicTerrainGraphic(id: 0, width: 16, height: 16, indexedPixels: Data(floor)),
                1: ClassicTerrainGraphic(id: 1, width: 16, height: 44, indexedPixels: Data(wall)),
            ], objects: [0: exit, 1: hatch])
    }

    private static func level(
        title: String, population: Int, floor: Int, hatchY: Int, skill: ClassicSkill?
    ) throws -> ClassicLevel {
        let draw = ClassicDrawProperties(
            isUpsideDown: false, noOverwrite: false, onlyOverwrite: false, isErase: false)
        var terrain = stride(from: 0, to: 352, by: 16).map {
            ClassicTerrainPlacement(x: $0, y: floor, id: 0, draw: draw)
        }
        if skill == .climber {
            terrain.append(ClassicTerrainPlacement(x: 152, y: floor - 44, id: 1, draw: draw))
        }
        var skills = Dictionary(uniqueKeysWithValues: ClassicSkill.allCases.map { ($0, 0) })
        if let skill { skills[skill] = population }
        return try ClassicLevel(
            data: Data(repeating: 0, count: ClassicLevel.recordSize),
            propertiesOverride: .init(
                title: title, releaseRate: 50, lemmingCount: population,
                saveRequirement: population, timeLimitMinutes: 3, skills: skills),
            steelOverride: [], terrainOverride: terrain,
            objectsOverride: [
                .init(slot: 0, x: 40, y: hatchY, id: 1, draw: draw),
                .init(slot: 1, x: 264, y: floor - 24, id: 0, draw: draw),
            ])
    }
}

private extension ClassicGroundSet {
    init(
        authoredStyle: Int, terrainPalette: [ClassicRGBColor], objectPalette: [ClassicRGBColor],
        terrain: [Int: ClassicTerrainGraphic], objects: [Int: ClassicObjectGraphic]
    ) {
        style = authoredStyle
        self.terrainPalette = terrainPalette
        self.objectPalette = objectPalette
        self.terrain = terrain
        self.objects = objects
    }
}
