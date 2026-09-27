import Darwin
import Foundation
import NxlvKit

private struct CorpusFailure: Error, CustomStringConvertible {
    let description: String
}

private func files(withExtension pathExtension: String, beneath root: URL) throws -> [URL] {
    guard let enumerator = FileManager.default.enumerator(
        at: root,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles, .skipsPackageDescendants]
    ) else {
        throw CorpusFailure(description: "Could not enumerate \(root.path).")
    }
    return enumerator.compactMap { item -> URL? in
        guard let url = item as? URL,
              url.pathExtension.caseInsensitiveCompare(pathExtension) == .orderedSame,
              (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
            return nil
        }
        return url
    }.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
}

private func text(at url: URL) throws -> String {
    let data = try Data(contentsOf: url, options: .mappedIfSafe)
    guard data.count <= 16_777_216,
          let value = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1) else {
        throw CorpusFailure(description: "The source text is too large or undecodable.")
    }
    return value
}

private struct PreparedLevel {
    let level: NxlvLevel
    let rendered: NxlvRenderedLevel
    let path: String
}

private func run() throws {
    let arguments = Array(CommandLine.arguments.dropFirst())
    guard arguments.count == 3 else {
        throw CorpusFailure(description:
            "Usage: NxrpPairedCorpusDiagnostics <levels-directory> <replays-directory> <styles-directory>")
    }
    let levelsRoot = URL(fileURLWithPath: arguments[0], isDirectory: true)
    let replaysRoot = URL(fileURLWithPath: arguments[1], isDirectory: true)
    let stylesRoot = URL(fileURLWithPath: arguments[2], isDirectory: true)
    let levelURLs = try files(withExtension: "nxlv", beneath: levelsRoot)
    let replayURLs = try files(withExtension: "nxrp", beneath: replaysRoot)
    guard !levelURLs.isEmpty, !replayURLs.isEmpty else {
        throw CorpusFailure(description: "The paired corpus needs at least one NXLV and one NXRP file.")
    }

    let resolver = NxlvStyleResolver(stylesRootURL: stylesRoot)
    let renderer = NxlvRenderer()
    var levelsByID: [UInt64: PreparedLevel] = [:]
    var failures: [String] = []

    for url in levelURLs {
        let relative = url.path.replacingOccurrences(of: levelsRoot.path + "/", with: "")
        do {
            let decoded = NxlvLevel.decode(text: try text(at: url))
            guard let level = decoded.level,
                  !decoded.diagnostics.contains(where: { $0.severity == .error }),
                  let id = level.id else {
                throw CorpusFailure(description: "The level did not decode with an ID.")
            }
            guard levelsByID[id] == nil else {
                throw CorpusFailure(description: "Duplicate level ID x\(String(id, radix: 16)).")
            }
            let resolution = resolver.resolve(level: level)
            guard !resolution.diagnostics.contains(where: { $0.severity == .error }) else {
                throw CorpusFailure(description: "Style resolution failed.")
            }
            let result = renderer.render(level: level, resolution: resolution)
            guard !result.hasErrors, let rendered = result.renderedLevel else {
                throw CorpusFailure(description: "Level rendering failed.")
            }
            levelsByID[id] = PreparedLevel(level: level, rendered: rendered, path: relative)
        } catch {
            failures.append("LEVEL \(relative): \(error)")
        }
    }

    var completed = 0
    var exactVersionPairs = 0
    var exactVersionCompletions = 0
    var commands = 0
    var versionMismatches = 0
    var recordedCompletionFrames = 0
    var matchingCompletionFrames = 0
    var recoveredCompletions = 0
    for (index, url) in replayURLs.enumerated() {
        let relative = url.path.replacingOccurrences(of: replaysRoot.path + "/", with: "")
        do {
            let decoded = NxrpReplayDecoder.decode(try text(at: url))
            guard let replay = decoded.replay,
                  !decoded.diagnostics.contains(where: { $0.severity == .error }),
                  let id = replay.metadata.levelID else {
                throw CorpusFailure(description: "The replay did not decode with a level ID.")
            }
            guard let prepared = levelsByID[id] else {
                throw CorpusFailure(description: "No level has replay ID x\(String(id, radix: 16)).")
            }
            let exactVersion = replay.metadata.levelVersion == (prepared.level.version ?? 0)
            if exactVersion {
                exactVersionPairs += 1
            } else {
                versionMismatches += 1
            }
            commands += replay.commands.count
            var playback = try NxrpReplayPlayback(
                sourceCompatibleReplay: replay,
                level: prepared.level,
                renderedLevel: prepared.rendered
            )
            let didComplete = try playback.runToSourceCutoff()
            var recovered = try NxrpReplayPlayback(
                sourceCompatibleReplay: replay,
                level: prepared.level,
                renderedLevel: prepared.rendered
            )
            let recoveryTick = max(1, (replay.commands.map(\.tick).max() ?? 1) / 2)
            while recovered.simulation.tickCount < recoveryTick,
                  !recovered.simulation.isComplete,
                  recovered.observedCompletionFrame == nil {
                try recovered.step()
            }
            let encoded = try JSONEncoder().encode(recovered)
            recovered = try JSONDecoder().decode(NxrpReplayPlayback.self, from: encoded)
            let recoveredDidComplete = try recovered.runToSourceCutoff()
            guard recoveredDidComplete == didComplete,
                  recovered == playback else {
                throw CorpusFailure(description:
                    "Encoded replay recovery diverged at checkpoint tick \(recoveryTick).")
            }
            if recoveredDidComplete { recoveredCompletions += 1 }
            if let expectedFrame = replay.metadata.expectedCompletionFrame {
                recordedCompletionFrames += 1
                if playback.observedCompletionFrame == expectedFrame {
                    matchingCompletionFrames += 1
                }
            }
            guard didComplete else {
                let sample = playback.simulation.activeLemmings.prefix(4).map {
                    "\($0.id):\($0.action.rawValue)@\($0.position.x),\($0.position.y):\($0.direction.rawValue)"
                }.joined(separator: ",")
                let rejections = playback.sourceAssignmentRejections.prefix(4)
                    .map { String(describing: $0) }
                    .joined(separator: ",")
                let divergences = playback.sourceStateDivergences.prefix(4).map {
                    "seq\($0.sequence):\($0.expectedPosition.x),\($0.expectedPosition.y),"
                        + "\($0.expectedDirection.rawValue)->\($0.actualPosition.x),"
                        + "\($0.actualPosition.y),\($0.actualDirection.rawValue),"
                        + "\($0.actualAction.rawValue)"
                }.joined(separator: ",")
                let removalCounts = Dictionary(
                    grouping: playback.simulation.lemmings.compactMap(\.removalReason),
                    by: { $0 }
                ).map { "\($0.key.rawValue)=\($0.value.count)" }
                    .sorted()
                    .joined(separator: ",")
                let removedSample = playback.simulation.lemmings.compactMap { lemming -> String? in
                    guard let reason = lemming.removalReason else { return nil }
                    return "\(lemming.id):\(reason.rawValue)@\(lemming.position.x),\(lemming.position.y)"
                }.prefix(6).joined(separator: ",")
                let removalTimeline = playback.sourceRemovalObservations.prefix(8).map {
                    "t\($0.tick):\($0.lemmingID):\($0.reason.rawValue)@"
                        + "\($0.position.x),\($0.position.y)"
                }.joined(separator: ",")
                throw CorpusFailure(description:
                    "Did not meet the rescue requirement by the NeoLemmix replay-check cutoff "
                    + "(level \(prepared.path), saved \(playback.simulation.savedCount)/"
                    + "\(playback.simulation.configuration.requiredToSave), lost "
                    + "\(playback.simulation.lostCount), active \(playback.simulation.activeLemmings.count), "
                    + "tick \(playback.simulation.tickCount), ignored assignment rejections "
                    + "\(playback.sourceAssignmentRejections.count) [\(rejections)], state divergences "
                    + "\(playback.sourceStateDivergences.count) [\(divergences)], removals "
                    + "[\(removalCounts)], removal timeline [\(removalTimeline)], removed sample "
                    + "[\(removedSample)], sample \(sample)).")
            }
            completed += 1
            if exactVersion { exactVersionCompletions += 1 }
        } catch {
            failures.append("REPLAY \(relative): \(error)")
        }
        if (index + 1).isMultiple(of: 25) || index + 1 == replayURLs.count {
            print("NXRP paired progress: \(index + 1)/\(replayURLs.count)")
            fflush(stdout)
        }
    }

    print(
        "NXRP paired corpus: \(levelURLs.count) levels, \(replayURLs.count) replays, "
            + "\(commands) commands, \(completed) native completions, "
            + "\(recoveredCompletions) recovered completions, "
            + "\(exactVersionPairs) exact-version pairs, \(exactVersionCompletions) exact-version completions, "
            + "\(versionMismatches) source-version mismatches, \(matchingCompletionFrames)/"
            + "\(recordedCompletionFrames) matching completion frames, \(failures.count) failures."
    )
    for failure in failures.prefix(60) { print("FAIL \(failure)") }
    if failures.count > 60 { print("...and \(failures.count - 60) more failures") }
    guard failures.isEmpty else {
        throw CorpusFailure(description: "NXRP paired corpus verification failed.")
    }
}

do {
    try run()
} catch {
    fputs("\(error)\n", stderr)
    exit(1)
}
