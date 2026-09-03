import Foundation
import NxlvKit

// Scans any directory of Lemmings-format level data and reports what it finds.
// This is how a new title is checked before the app gains a campaign for it.

let arguments = CommandLine.arguments
func flag(_ name: String, _ fallback: String) -> String {
    guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else {
        return fallback
    }
    return arguments[index + 1]
}

let directory = URL(fileURLWithPath: flag("--dir", "Content/lemming1.pc"), isDirectory: true)
let prefix = flag("--prefix", "LEVEL")

do {
    let campaign = try ClassicCampaign.scan(
        directory: directory, name: "Scan", levelFilePrefix: prefix)
    print("scanned \(directory.lastPathComponent) with prefix \(prefix)")
    print("  levels found: \(campaign.levels.count)")

    var styleUse: [Int: Int] = [:]
    var specialUse: [Int: Int] = [:]
    var noExit = 0
    for entry in campaign.levels {
        styleUse[entry.level.groundStyle, default: 0] += 1
        if entry.level.specialStyle > 0 { specialUse[entry.level.specialStyle, default: 0] += 1 }
        if entry.level.objects.isEmpty { noExit += 1 }
    }
    print("  ground styles used: "
        + styleUse.sorted { $0.key < $1.key }.map { "\($0.key)x\($0.value)" }
            .joined(separator: " "))
    if !specialUse.isEmpty {
        print("  special graphics used: "
            + specialUse.sorted { $0.key < $1.key }.map { "\($0.key)x\($0.value)" }
                .joined(separator: " "))
    }
    print("  levels with no objects: \(noExit)")
    print("")
    print("  first 12 titles:")
    for entry in campaign.levels.prefix(12) {
        let title = entry.level.title.trimmingCharacters(in: .whitespaces)
        print(String(
            format: "    %3d  %-32s  style %d  %d lems, save %d",
            entry.number, (title as NSString).utf8String!,
            entry.level.groundStyle, entry.level.lemmingCount, entry.level.saveRequirement))
    }
} catch {
    FileHandle.standardError.write(Data("scan failed: \(error)\n".utf8))
    exit(1)
}
