import Foundation
import NxlvKit

private enum ExitCode: Int32 {
    case usage = 64
    case dataError = 65
    case inputMissing = 66
}

private func fail(_ message: String, code: ExitCode) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    Foundation.exit(code.rawValue)
}

private func usage() -> Never {
    fail(
        """
        usage:
          LemmingsDataTool inspect <LEVEL*.DAT> [more archives ...]
          LemmingsDataTool inspect-pack <game-data-directory>
          LemmingsDataTool export-json <LEVEL*.DAT> <output-directory>
        """,
        code: .usage
    )
}

private func readSections(at path: String) throws -> [ClassicDATSection] {
    let url = URL(fileURLWithPath: path)
    let data = try Data(contentsOf: url, options: .mappedIfSafe)
    return try ClassicDATArchive.decode(data)
}

private func inspect(paths: ArraySlice<String>) throws {
    guard !paths.isEmpty else { usage() }
    var total = 0
    for path in paths {
        let sections = try readSections(at: path)
        print("\(URL(fileURLWithPath: path).lastPathComponent): \(sections.count) sections")
        for (index, section) in sections.enumerated() {
            let level = try ClassicLevel(data: section.data)
            print(
                String(
                    format: "  %02d  %-32s  RR %3d  %3d/%3d  style %d/%d  terrain %3d  objects %2d  steel %2d",
                    index,
                    (level.title as NSString).utf8String!,
                    level.releaseRate,
                    level.saveRequirement,
                    level.lemmingCount,
                    level.groundStyle,
                    level.specialStyle,
                    level.terrain.count,
                    level.objects.count,
                    level.steel.count
                )
            )
        }
        total += sections.count
    }
    print("Validated \(total) classic level records; all DAT checksums passed.")
}

private func exportJSON(archivePath: String, outputPath: String) throws {
    let sections = try readSections(at: archivePath)
    let outputURL = URL(fileURLWithPath: outputPath, isDirectory: true)
    try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]

    for (index, section) in sections.enumerated() {
        let level = try ClassicLevel(data: section.data)
        let json = try encoder.encode(level)
        let filename = String(format: "%@-%02d.json", URL(fileURLWithPath: archivePath).deletingPathExtension().lastPathComponent, index)
        try json.write(to: outputURL.appendingPathComponent(filename), options: .atomic)
    }
    print("Exported \(sections.count) levels to \(outputURL.path)")
}

private func inspectPack(path: String) throws {
    let campaign = try ClassicCampaignDefinition.originalDOSLemmings.load(
        from: URL(fileURLWithPath: path, isDirectory: true)
    )
    print("\(campaign.name): \(campaign.levels.count) campaign levels")
    for item in campaign.levels {
        let source = String(format: "LEVEL%03d/%d", item.archiveFile, item.archiveSection)
        let marker = item.usesOddTableProperties ? "repeat" : "unique"
        print(String(format: "  %-7s %2d  %-32s  %-10s  %s", (item.rank as NSString).utf8String!, item.number, (item.level.title as NSString).utf8String!, (marker as NSString).utf8String!, (source as NSString).utf8String!))
    }
    print("Validated the complete \(campaign.levels.count)-level official campaign.")
}

let arguments = CommandLine.arguments
guard arguments.count >= 2 else { usage() }

do {
    switch arguments[1] {
    case "inspect":
        try inspect(paths: arguments.dropFirst(2))
    case "inspect-pack":
        guard arguments.count == 3 else { usage() }
        try inspectPack(path: arguments[2])
    case "export-json":
        guard arguments.count == 4 else { usage() }
        try exportJSON(archivePath: arguments[2], outputPath: arguments[3])
    default:
        usage()
    }
} catch CocoaError.fileReadNoSuchFile {
    fail("input file does not exist", code: .inputMissing)
} catch {
    fail(error.localizedDescription, code: .dataError)
}
