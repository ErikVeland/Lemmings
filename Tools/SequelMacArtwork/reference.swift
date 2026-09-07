import Foundation
import NxlvKit

// Export matched source records. Alignment uses authored origins, never resizing.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let out = URL(fileURLWithPath: CommandLine.arguments[1])
let macRoot = URL(fileURLWithPath: CommandLine.arguments[2])
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
var records: [[String: Any]] = []
@MainActor func add(_ name: String, category: String, width: Int, height: Int, rgba: Data,
         x: Int = 0, y: Int = 0, mac: ClassicMacArtwork.Frame) throws {
    try rgba.write(to: out.appendingPathComponent(name + "-dos.rgba"))
    try mac.rgba.write(to: out.appendingPathComponent(name + "-mac.rgba"))
    records.append(["name": name, "category": category,
        "dos": ["width": width, "height": height, "x": x, "y": y, "file": name + "-dos.rgba"],
        "mac": ["width": mac.width, "height": mac.height, "x": mac.x, "y": mac.y, "file": name + "-mac.rgba"]])
}
func rgba(_ data: Data, _ palette: [ClassicRGBColor]) -> Data {
    var result = [UInt8](repeating: 0, count: data.count * 4)
    for (i, p) in data.enumerated() where p & 128 == 0 {
        let c = palette[Int(p & 15)]
        result[i*4] = c.red; result[i*4+1] = c.green
        result[i*4+2] = c.blue; result[i*4+3] = 255
    }
    return Data(result)
}
for (family, path, styles) in [
    ("lemmings", "Content/lemming1.pc", Array(0...4)),
    ("ohno", "Sources/Ports/oh_no_more_lemmings_dos-1991-11-14_2232", Array(0...3)),
    ("xmas", "Sources/Ports/xmas_dos_XmasLemmingsV1.9a1", [2]),
    ("holiday", ".build/local/Ultimate Lemmings.app/Contents/Resources/Ports/holiday_native_1994", [2])
] {
    let directory = root.appendingPathComponent(path)
    let art = try ClassicMacArtwork(directory: macRoot.appendingPathComponent(family))
    for style in styles {
        let ground = try ClassicGroundSet.load(style: style, from: directory)
        for (id, tile) in ground.terrain.sorted(by: { $0.key < $1.key }) {
            guard let mac = art.frame(1500 + style, id) else { continue }
            try add("\(family)-terrain-\(style)-\(id)", category: "terrain",
                width: tile.width, height: tile.height, rgba: rgba(tile.indexedPixels, ground.objectPalette), mac: mac)
        }
        for (id, object) in ground.objects.sorted(by: { $0.key < $1.key }) {
            guard let seqs = art.objects[style], seqs.indices.contains(id) else { continue }
            let seq = seqs[id]
            // Count differences require manual frame correspondence and are excluded from training.
            guard seq.count == object.frames.count else { continue }
            let category = object.triggerEffect == 5 ? "liquid" : object.triggerEffect == 4 ? "trap" : "object"
            for (i, frame) in object.frames.enumerated() {
                guard let mac = art.frame(1600 + style, seq.base + i) else { continue }
                try add("\(family)-object-\(style)-\(id)-\(i)", category: category,
                    width: object.width, height: object.height, rgba: rgba(frame, ground.objectPalette), mac: mac)
            }
        }
    }
    let sprites = try ClassicMainDATAssets.load(from: directory)
    for animation in sprites.animations {
        for (i, frame) in animation.frames.enumerated() {
            guard let mac = art.lemming(pose: animation.pose, left: animation.direction == .left, tick: i) else { continue }
            try add("\(family)-sprite-\(animation.pose.rawValue)-\(animation.direction.rawValue)-\(i)", category: "sprite",
                width: frame.width, height: frame.height,
                rgba: try frame.rgba(using: ClassicLemmingPalette.panelVGA),
                x: animation.offsetX, y: animation.offsetY, mac: mac)
        }
    }
}
try JSONSerialization.data(withJSONObject: records, options: [.prettyPrinted, .sortedKeys])
    .write(to: out.appendingPathComponent("manifest.json"))
print("Exported \(records.count) DOS/Mac reference pairs.")
