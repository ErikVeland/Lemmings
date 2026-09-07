import Foundation
import NxlvKit

// Reports the exit trigger geometry of every ground set, to see whether a
// fixed entry depth lands in the middle of the exit or somewhere else.
struct Source { let name: String; let path: String; let styles: Range<Int> }
let sources = [
    Source(name: "Lemmings DOS", path: "Sources/Ports/lemmings_dos_1991-07-30", styles: 0..<5),
    Source(name: "Oh No! DOS", path: "Sources/Ports/oh_no_more_lemmings_dos-1991-11-14_2232", styles: 0..<4),
    Source(name: "Xmas DOS", path: "Sources/Ports/xmas_dos_XmasLemmingsV1.9", styles: 0..<3),
]

print("style : exit object   trigger x range   width  centre offset from object centre")
for source in sources {
    let dir = URL(fileURLWithPath: source.path, isDirectory: true)
    for style in source.styles {
        guard let ground = try? ClassicGroundSet.load(style: style, from: dir) else { continue }
        for (id, g) in ground.objects.sorted(by: { $0.key < $1.key }) where g.triggerEffect == 1 {
            // Trigger position relative to the object's own top-left.
            let left = g.triggerLeft
            let right = g.triggerLeft + g.triggerWidth
            let triggerCentre = Double(left + right) / 2
            let objectCentre = Double(g.width) / 2
            print(String(
                format: "  %@ style %d: id%d %dx%d  trigger %d..<%d (w %d)  centre %+.1f",
                source.name, style, id, g.width, g.height,
                left, right, g.triggerWidth, triggerCentre - objectCentre))
        }
    }
}
