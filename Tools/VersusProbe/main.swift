import Foundation
import NxlvKit

// Reads the two-player level records off the Amiga disks and reports what they
// hold. A versus level should carry an entrance and an exit for each side.

let base = URL(fileURLWithPath: "Sources/Ports/amiga_extracted", isDirectory: true)

func records(_ family: String) throws -> [Data] {
    let folder = base.appendingPathComponent(family)
    let files = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        .filter { $0.hasPrefix("level0") }.sorted()
    var out: [Data] = []
    for file in files {
        let data = try Data(contentsOf: folder.appendingPathComponent(file))
        for start in stride(from: 0, to: data.count, by: 2048) {
            out.append(data.subdata(in: start..<min(start + 2048, data.count)))
        }
    }
    return out
}

for (family, range) in [("lemmings", 80..<100), ("ohno", 100..<110)] {
    let all = try records(family)
    print("=== \(family): \(all.count) records, versus block \(range)")
    for index in range where index < all.count {
        guard let level = try? ClassicLevel(data: all[index]) else {
            print("  \(index): FAILED TO PARSE"); continue
        }
        let entrances = level.objects.filter { $0.id == 1 }.count
        let skills = level.skills.values.reduce(0, +)
        print("  \(index) \(level.title.padding(toLength: 32, withPad: " ", startingAt: 0)) "
            + "lems=\(level.lemmingCount) need=\(level.saveRequirement) "
            + "rr=\(level.releaseRate) style=\(level.groundStyle) "
            + "entrances=\(entrances) objects=\(level.objects.count) "
            + "terrain=\(level.terrain.count) skills=\(skills)")
    }
}
