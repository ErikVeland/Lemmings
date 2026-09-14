import Foundation
import NxlvKit

// Copied from Tests/Lemmings2RuntimeTests/main.swift. The release audit compiles each
// suite from its main.swift alone, so the runtime suite keeps its own copy.

func fixture(wall: Bool = false) throws -> Lemmings2Runtime {
    let width = 120, height = 80
    var pixels = [UInt8](repeating: 0, count: width * height)
    var solid = [Bool](repeating: false, count: width * height)
    for y in 60..<height { for x in 0..<width { solid[y * width + x] = true; pixels[y * width + x] = 6 } }
    if wall { for y in 20..<60 { for x in 50..<56 { solid[y * width + x] = true; pixels[y * width + x] = 6 } } }
    let config = Lemmings2Runtime.Configuration(width: width, height: height, pixels: pixels, solid: solid,
        palette: [UInt8](repeating: 255, count: 1024),
        entrance: .init(x: 20, y: 45, width: 1, height: 1), exits: [.init(x: 90, y: 50, width: 16, height: 16)],
        skills: Lemmings2Runtime.Skill.allCases.filter { $0 != .unused },
        supplies: [Int](repeating: 10, count: Lemmings2Runtime.Skill.allCases.count - 1), total: 3,
        timeLimit: 120, releaseInterval: 20, terrainMasks: try syntheticMasks())
    return try Lemmings2Runtime(configuration: config)
}

func syntheticMasks() throws -> Lemmings2TerrainMasks {
    func frame(_ x: Int, _ y: Int, _ w: Int, _ h: Int) -> Lemmings2SpriteFrame {
        .init(x: x, y: y, width: w, height: h, pixels: [UInt8](repeating: 7, count: w * h),
              opaque: [Bool](repeating: true, count: w * h))
    }
    return try .init(digger: frame(4, 0, 9, 3),
        basher: (0..<8).map { frame($0 < 4 ? 9 : 1, 7, 7, 9) },
        miner: (0..<4).map { frame($0 < 2 ? 7 : 0, 3, 9, 14) },
        exploder: frame(0, 0, 16, 22), brick: frame(8, 0, 6, 1),
        stacker: [frame(8, 4, 2, 4), frame(6, 4, 2, 4)], platformer: frame(5, 6, 5, 2), stomper: frame(3, 4, 10, 4),
        scooper: Array(repeating: frame(0, 6, 12, 10), count: 12),
        fencer: Array(repeating: frame(0, 6, 12, 9), count: 2),
        clubBasher: Array(repeating: frame(0, 12, 12, 12), count: 14),
        laser: [frame(5,0,6,8)],
        flame: Array(repeating: frame(0,0,32,12), count:2), blast: frame(0,0,22,22), plant:(0..<8).map { frame(8,0,4+$0,8) }, twister:frame(2,0,12,11), stone:Array(repeating:frame(0,0,4,4),count:4), spear:Array(repeating:frame(0,7,15,1),count:16), arrow:Array(repeating:frame(0,7,14,1),count:32))
}
