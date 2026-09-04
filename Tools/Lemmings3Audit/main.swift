import Foundation
import NxlvKit

guard (2...3).contains(CommandLine.arguments.count) else {
    FileHandle.standardError.write(Data("Usage: Lemmings3Audit L3_DATA_ROOT [LEVEL_NUMBER]\n".utf8)); exit(2)
}
let root = URL(fileURLWithPath: CommandLine.arguments[1])
let number = CommandLine.arguments.count == 3 ? Int(CommandLine.arguments[2]) ?? 1 : 1
let level = try Lemmings3Level(data: Data(contentsOf: root.appendingPathComponent(String(format: "LEVELS/LEVEL%03d.DAT", number))))
let style = try Lemmings3Style(directory: root.appendingPathComponent("STYLES"), number: level.style)
for object in style.permanent.objects.values.sorted(by: { $0.identifier < $1.identifier }) where (0x4002...0x400a).contains(object.flags) {
    let control = Int(object.rawRecord[12]) | Int(object.rawRecord[13]) << 8
    print("TRAPDEF \(object.identifier): kind \(object.flags & 255), frames \(object.frameCount), start \(object.rawRecord[11]), delay \(control & 127), pause \(control >> 9), mode \((control >> 7) & 3)")
}
for object in style.temporary.objects.values.sorted(by: { $0.identifier < $1.identifier }) where object.columns == 1 && object.rows == 4 {
    print("TILE8 \(object.identifier) flags \(String(object.flags, radix: 16))")
}
for object in style.permanent.objects.values.sorted(by: { $0.identifier < $1.identifier }) where object.identifier >= 10000 {
    print("ACTOR \(object.identifier) \(object.columns * 8)x\(object.rows * 2) flags \(String(object.flags, radix: 16))")
}
for (prefix, bank) in [("PERM", style.permanent), ("TEMP", style.temporary)] {
    let reference = prefix == "PERM" ? level.permanentObjectsReference : level.temporaryObjectsReference
    let placements = try Lemmings3Objects(data: Data(contentsOf: root.appendingPathComponent(String(format: "LEVELS/%@%03d.OBS", prefix, reference))))
    for id in Set(placements.placements.map(\.identifier)).sorted() {
        let object = bank.objects[id]!
        let frame = try bank.image(object: id, palette: style.palette)
        let tags = try bank.attributes(object: id)
        for (index, tag) in tags.enumerated() where tag != 0x1000 && prefix == "PERM" {
            print("TAG \(id) at \(index % object.columns * 8),\(index / object.columns * 2): \(String(tag, radix: 16))")
        }
        print("\(prefix) \(id): flags \(String(object.flags, radix: 16)), record \([UInt8](object.rawRecord)), colours \(Set(frame.pixels).sorted())")
    }
}
let perm = try Lemmings3Objects(data: Data(contentsOf: root.appendingPathComponent(String(format: "LEVELS/PERM%03d.OBS", level.permanentObjectsReference))))
for placed in perm.placements where placed.identifier >= 10000 || style.permanent.objects[placed.identifier]?.flags == 0x402 {
    print("SPAWN \(placed.identifier): \(placed.x),\(placed.y)")
}
let temp = try Lemmings3Objects(data: Data(contentsOf: root.appendingPathComponent(String(format: "LEVELS/TEMP%03d.OBS", level.temporaryObjectsReference))))
let scene = try Lemmings3Scene(level: level, style: style, permanent: perm, temporary: temp)
if (1...3).contains(level.style) {
    let first = (level.style - 1) * 100 + 1
    let construction = try style.constructionTile()
    print("CONSTRUCTION \(construction.width)×\(construction.height) pixels \(construction.pixels.count)")
    for candidate in first..<(first + 30) {
        do {
            let record = try Lemmings3Level(data: Data(contentsOf: root.appendingPathComponent(String(format: "LEVELS/LEVEL%03d.DAT", candidate))))
            let permanent = try Lemmings3Objects(data: Data(contentsOf: root.appendingPathComponent(String(format: "LEVELS/PERM%03d.OBS", record.permanentObjectsReference))))
            let temporary = try Lemmings3Objects(data: Data(contentsOf: root.appendingPathComponent(String(format: "LEVELS/TEMP%03d.OBS", record.temporaryObjectsReference))))
            _ = try Lemmings3Runtime(level: record, style: style, permanent: permanent, temporary: temporary)
            print("LOADABLE \(candidate)")
        } catch { print("BLOCKED \(candidate): \(error)") }
    }
}
for placed in perm.placements where [202, 203].contains(placed.identifier) {
    let x = placed.x + 4
    let column = (max(0, placed.y - 4)..<min(level.height, placed.y + 56)).map { y in
        "\(y)=\(String(scene.attributes[y * level.width + x], radix: 16))"
    }.joined(separator: " ")
    print("TRAP \(placed.identifier) \(placed.x),\(placed.y): column \(column)")
}
for number in 1...3 {
    let corpusStyle = try Lemmings3Style(directory: root.appendingPathComponent("STYLES"), number: number)
    for bank in [corpusStyle.permanent, corpusStyle.temporary] {
        for object in bank.objects.values { _ = try bank.attributes(object: object.identifier) }
    }
    print("PASS all attribute grids in style \(number)")
}
