import Foundation
import NxlvKit

// Detection has to work on more than the one data set it was written against,
// so this runs over every directory it is given.

private struct Failure: Error, CustomStringConvertible {
    let description: String
}

private func require(
    _ condition: @autoclosure () -> Bool, _ message: @autoclosure () -> String
) throws {
    guard condition() else { throw Failure(description: message()) }
}

let directories = Array(CommandLine.arguments.dropFirst())
guard !directories.isEmpty else {
    FileHandle.standardError.write(Data("pass one or more data directories\n".utf8))
    exit(2)
}

do {
    var seenKinds: Set<String> = []
    for path in directories {
        let url = URL(fileURLWithPath: path, isDirectory: true)
        let set = try ClassicDataSet.detect(directory: url)
        seenKinds.insert(set.kind.rawValue)

        try require(!set.campaign.levels.isEmpty, "\(set.name): no levels")
        try require(!set.groundStyles.isEmpty, "\(set.name): no ground styles")

        // Every level must name a style the directory actually provides.
        for entry in set.campaign.levels {
            try require(
                set.groundStyles.contains(entry.level.groundStyle),
                "\(set.name): level \(entry.number) wants missing style \(entry.level.groundStyle)")
        }
        // Plain interpolation: bridging to NSString for %@ hands the
        // formatter a pointer into a temporary that may already be gone.
        func pad(_ text: String, _ width: Int) -> String {
            text.count >= width ? text : text + String(repeating: " ", count: width - text.count)
        }
        let styles = set.groundStyles.map(String.init).joined(separator: ",")
        print(
            "PASS \(pad(set.name, 24)) \(pad(set.kind.rawValue, 18))"
                + " prefix \(pad(set.levelFilePrefix, 6))"
                + " \(set.campaign.levels.count) levels, styles \(styles)")
    }
    try require(seenKinds.count >= 1, "no data sets were detected")
    print("Classic data set tests passed.")
} catch {
    FileHandle.standardError.write(Data("Data set tests failed: \(error)\n".utf8))
    exit(1)
}
