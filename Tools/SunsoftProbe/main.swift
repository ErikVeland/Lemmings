import Foundation
import NxlvKit

let dir = URL(fileURLWithPath: "Sources/Ports/Genesis-Sunsoft", isDirectory: true)
let archive = dir.appendingPathComponent("Genesis Sunsoft.dat")

let data = try Data(contentsOf: archive)
let sections = try ClassicDATArchive.decode(data)
print("Genesis Sunsoft.dat: \(data.count) bytes -> \(sections.count) sections")
for (i, s) in sections.enumerated() {
    print("  section \(i): \(s.decompressedSize) bytes, checksum \(s.checksumIsValid ? "ok" : "BAD")")
}

var levels: [ClassicLevel] = []
for section in sections {
    var start = 0
    while start + ClassicLevel.recordSize <= section.data.count {
        let record = section.data.subdata(in: start..<(start + ClassicLevel.recordSize))
        if let level = try? ClassicLevel(data: record) { levels.append(level) }
        start += ClassicLevel.recordSize
    }
}
print("\nlevels parsed: \(levels.count)")
for (i, level) in levels.enumerated() {
    print("  \(i): \(level.title) — lems=\(level.lemmingCount) need=\(level.saveRequirement) "
        + "rr=\(level.releaseRate) min=\(level.timeLimitMinutes) style=\(level.groundStyle) "
        + "special=\(level.specialStyle) objects=\(level.objects.count) terrain=\(level.terrain.count)")
}
