import Foundation
import NxlvKit

// Dumps the DOS panel bitmap so its contents can be seen: which button icons
// the artwork already carries, and which the game is drawing by hand.
let dir = URL(fileURLWithPath: "Sources/Ports/lemmings_dos_1991-07-30", isDirectory: true)
let assets = try ClassicMainDATAssets.load(from: dir)
guard let panel = assets.panel else { print("no panel graphics"); exit(1) }
let bytes = panel.rgba(using: ClassicLemmingPalette.panelVGA)
print("panel bitmap: \(panel.width)x\(panel.height), \(bytes.count) bytes")
let out = URL(fileURLWithPath: "/tmp/panel")
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
try Data(bytes).write(to: out.appendingPathComponent("panel.bin"))
try "\(panel.width) \(panel.height)".write(
    to: out.appendingPathComponent("size.txt"), atomically: true, encoding: .utf8)
