import Foundation
import NxlvKit

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("Usage: SequelAudit L2_DATA_ROOT\n".utf8))
    exit(2)
}
let root = URL(fileURLWithPath: CommandLine.arguments[1])
let style = try Lemmings2Style(data: Data(contentsOf: root.appendingPathComponent("STYLES/CLASSIC.DAT")))
let sprites = try Lemmings2Sprites(data: Data(contentsOf: root.appendingPathComponent("VLEMMS.DAT")))
for name in ["LM11", "LM12", "LM13", "LM14", "LM15", "LM16", "LM33", "LM5C"] {
    if let frames = sprites.animations[name] {
        print("SPRITE \(name) \(frames.prefix(14).map { "\($0.width)x\($0.height) offset \($0.x),\($0.y)" })")
    }
}
for (id, object) in style.objects.enumerated() {
    print("OBJECT \(id) type \(object.type) params \(object.parameters)")
    for c in object.components {
        print("  xy \(c.x),\(c.y) pos \(String(c.positioningFlags, radix: 16)) trigger \(String(c.triggerFlags, radix: 16)) solidity \(c.solidity) gfx \(c.graphics)/\(c.graphicsFlags) interaction \(c.interaction)")
    }
}
for number in Array(0..<10) + [904, 906, 908, 910] {
    let file = String(format: "LEVELS/LEVEL%03d.DAT", number)
    let level = try Lemmings2Level(data: Data(contentsOf: root.appendingPathComponent(file)))
    let h = [UInt8](try level.container.requiredSection("L2LH"))
    if number < 10 {
        let terrain = try Lemmings2Terrain(level: level, style: style)
        for exit in level.objects where exit.identifier == 1 || exit.identifier == 13 {
            let x = exit.x + 26 - 16, y = exit.y + 24 - 16
            let index = y * terrain.image.width + x
            print("NORMALIZED EXIT \(number): \(x),\(y) ground=\(terrain.solid[index]) above=\(terrain.solid[index-terrain.image.width])")
        }
    }
    print("LEVEL \(number) \(level.title) style \(level.style) columns \(level.tileColumns) records \(level.tiles.count) skills \(level.skills) bounds \(Array(h[54..<70]))")
    if number == 4 || number == 0 {
        let exit = level.objects.first { $0.identifier == 1 }!
        let ex = exit.x + 26
        var profile: [String] = []
        for y in max(0, exit.y - 16)..<176 {
            let tile = level.tiles[(y / 8 + 2) * 82 + ex / 16 + 1]
            if style.tiles[tile.identifier][y % 8 * 16 + ex % 16] != 0 { profile.append(String(y)) }
        }
        print("EXIT FLOOR x=\(ex) solid y=\(profile.joined(separator: ","))")
        for offset in [0, 1, 2] {
            let yProbe = exit.y + 24
            let row = yProbe / 8 + offset
            let values = (-2...2).map { colOffset in
                let xProbe = ex + colOffset * 16
                let tile = level.tiles[row * 82 + xProbe / 16]
                return style.tiles[tile.identifier][yProbe % 8 * 16 + xProbe % 16]
            }
            print("PROBE rowOffset\(offset) \(values)")
        }
        for row in 19..<24 {
            let start = row * 82
            let ids = level.tiles[start..<min(start + 82, level.tiles.count)].map(\.identifier)
            print("RAW ROW \(row): \(ids)")
        }
    }
    for o in level.objects where o.identifier != 65535 {
        print("  placed \(o.identifier) at \(o.x),\(o.y) extension \(o.parameter1),\(o.parameter2)")
    }
}
