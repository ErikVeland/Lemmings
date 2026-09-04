import Foundation
import NxlvKit

// The Macintosh release stores its levels as named resources rather than
// packed archives. Each one is the same 2,048 byte record every other release
// uses, so the existing parser reads them without new format work.

private struct Failure: Error, CustomStringConvertible {
    let description: String
}

private func require(
    _ condition: @autoclosure () -> Bool, _ message: @autoclosure () -> String
) throws {
    guard condition() else { throw Failure(description: message()) }
}

let arguments = CommandLine.arguments
guard arguments.count > 1 else {
    FileHandle.standardError.write(Data("pass a Macintosh disk image\n".utf8))
    exit(2)
}

do {
    let image = try Data(contentsOf: URL(fileURLWithPath: arguments[1]), options: .mappedIfSafe)
    let volume = try ClassicHFSVolume(image: image)
    print("PASS read '\(volume.volumeName)'")

    guard let levelsFile = volume.files.first(where: {
        $0.name.lowercased().contains("level")
    }) else {
        throw Failure(description: "no levels file on the disk")
    }
    let fork = try volume.resourceFork(named: levelsFile.name)
    print("PASS '\(levelsFile.name)' resource fork is \(fork.count) bytes")

    let records = ClassicResourceFork.resources(ofType: "LEVL", in: fork)
    try require(!records.isEmpty, "no LEVL resources found")
    try require(
        records.allSatisfy { $0.data.count == ClassicLevel.recordSize },
        "a LEVL resource is not \(ClassicLevel.recordSize) bytes")
    print("PASS \(records.count) level records, all the standard size")

    var levels: [ClassicLevel] = []
    for record in records {
        guard let level = try? ClassicLevel(data: record.data) else { continue }
        levels.append(level)
    }
    try require(
        levels.count == records.count,
        "only \(levels.count) of \(records.count) records parsed")
    print("PASS every record parsed with the existing level parser")

    // The overrides carry the repeat-level parameters, as on DOS.
    let overrides = ClassicResourceFork.resources(ofType: "ODDL", in: fork)
    print("PASS \(overrides.count) override records present")

    let titled = levels.filter { !$0.title.trimmingCharacters(in: .whitespaces).isEmpty }
    try require(!titled.isEmpty, "no level carries a title")
    print("PASS \(titled.count) levels carry titles")
    for level in levels.prefix(4) {
        print("     \(level.title.trimmingCharacters(in: .whitespaces))  "
            + "\(level.lemmingCount) lems, save \(level.saveRequirement), "
            + "style \(level.groundStyle)")
    }
    print("Classic Mac level tests passed.")
} catch {
    FileHandle.standardError.write(Data("Mac level tests failed: \(error)\n".utf8))
    exit(1)
}
