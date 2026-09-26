import Darwin
import Foundation
import NxlvKit

private struct CorpusFailure: Error, CustomStringConvertible {
    let description: String
}

private func replayURLs(beneath root: URL) throws -> [URL] {
    guard let enumerator = FileManager.default.enumerator(
        at: root,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles, .skipsPackageDescendants]
    ) else {
        throw CorpusFailure(description: "Could not enumerate \(root.path).")
    }
    return enumerator.compactMap { item -> URL? in
        guard let url = item as? URL,
              url.pathExtension.caseInsensitiveCompare("nxrp") == .orderedSame,
              (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
            return nil
        }
        return url
    }.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
}

private func run() throws {
    let arguments = Array(CommandLine.arguments.dropFirst())
    guard arguments.count == 1 else {
        throw CorpusFailure(description: "Usage: NxrpCorpusDiagnostics <replays-directory>")
    }
    let root = URL(fileURLWithPath: arguments[0], isDirectory: true)
    let urls = try replayURLs(beneath: root)
    guard !urls.isEmpty else {
        throw CorpusFailure(description: "No NXRP files were found beneath \(root.path).")
    }

    var commandCount = 0
    var warningCount = 0
    var unsupportedAssignments = 0
    var failures: [String] = []

    for url in urls {
        do {
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            guard data.count <= 16_777_216,
                  let text = String(data: data, encoding: .utf8)
                    ?? String(data: data, encoding: .isoLatin1) else {
                throw CorpusFailure(description: "The replay text is too large or undecodable.")
            }
            let result = NxrpReplayDecoder.decode(text)
            warningCount += result.diagnostics.filter { $0.severity == .warning }.count
            let errors = result.diagnostics.filter { $0.severity == .error }
            guard let replay = result.replay, errors.isEmpty else {
                let details = errors.prefix(4).map {
                    "\($0.code.rawValue)\($0.line.map { " at line \($0)" } ?? ""): \($0.message)"
                }.joined(separator: "; ")
                throw CorpusFailure(description: details)
            }
            commandCount += replay.commands.count
            unsupportedAssignments += replay.commands.reduce(into: 0) { count, item in
                if case let .assign(_, skill) = item.command,
                   NeoLemmixRules.unsupportedSkills.contains(skill) {
                    count += 1
                }
            }
        } catch {
            let relative = url.path.replacingOccurrences(of: root.path + "/", with: "")
            failures.append("\(relative): \(error)")
        }
    }

    print(
        "NXRP corpus: \(urls.count) replays, \(commandCount) commands, "
            + "\(warningCount) warnings, \(unsupportedAssignments) unsupported assignments, "
            + "\(failures.count) failures."
    )
    if !failures.isEmpty {
        for failure in failures.prefix(40) { print("FAIL \(failure)") }
        if failures.count > 40 { print("...and \(failures.count - 40) more failures") }
        throw CorpusFailure(description: "NXRP corpus import verification failed.")
    }
}

do {
    try run()
} catch {
    fputs("\(error)\n", stderr)
    exit(1)
}
