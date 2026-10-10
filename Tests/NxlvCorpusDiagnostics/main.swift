import Darwin
import Foundation
import NxlvKit

private struct CorpusFailure: Error, CustomStringConvertible {
    let description: String
}

private func diagnosticText(
    code: String,
    line: Int?,
    message: String
) -> String {
    "\(code)\(line.map { " at line \($0)" } ?? ""): \(message)"
}

private func levelURLs(beneath root: URL) throws -> [URL] {
    guard let enumerator = FileManager.default.enumerator(
        at: root,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles, .skipsPackageDescendants]
    ) else {
        throw CorpusFailure(description: "Could not enumerate \(root.path).")
    }
    return enumerator.compactMap { item -> URL? in
        guard let url = item as? URL,
              url.pathExtension.caseInsensitiveCompare("nxlv") == .orderedSame,
              (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
            return nil
        }
        return url
    }.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
}

private func run() throws {
    let arguments = Array(CommandLine.arguments.dropFirst())
    let options = Set(arguments.dropFirst(2))
    guard (2...4).contains(arguments.count),
          options.isSubset(of: ["--require-runnable", "--warnings-only"]),
          options.count == arguments.count - 2 else {
        throw CorpusFailure(
            description: "Usage: NxlvCorpusDiagnostics <levels-directory> <styles-directory> [--require-runnable] [--warnings-only]"
        )
    }
    let requireRunnable = options.contains("--require-runnable")
    let warningsOnly = options.contains("--warnings-only")
    let levelsRoot = URL(fileURLWithPath: arguments[0], isDirectory: true)
    let stylesRoot = URL(fileURLWithPath: arguments[1], isDirectory: true)
    let urls = try levelURLs(beneath: levelsRoot)
    guard !urls.isEmpty else {
        throw CorpusFailure(description: "No NXLV files were found beneath \(levelsRoot.path).")
    }

    let resolver = NxlvStyleResolver(stylesRootURL: stylesRoot)
    let renderer = NxlvRenderer()
    var failures: [String] = []
    var warnings = 0
    var warningCounts: [String: Int] = [:]
    var warningSamples: [String: [String]] = [:]
    var simulatedTicks = 0
    var unsupportedLevels: [(path: String, features: [String])] = []

    for (index, url) in urls.enumerated() {
        let relative = url.path.replacingOccurrences(
            of: levelsRoot.path + "/",
            with: ""
        )
        do {
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            guard data.count <= 16_777_216,
                  let text = String(data: data, encoding: .utf8)
                    ?? String(data: data, encoding: .isoLatin1) else {
                throw CorpusFailure(description: "The level text is too large or undecodable.")
            }
            let decode = NxlvLevel.decode(text: text)
            let parseWarnings = decode.diagnostics.filter { $0.severity == .warning }
            warnings += parseWarnings.count
            for warning in parseWarnings {
                let key = "parse.\(warning.code.rawValue)"
                warningCounts[key, default: 0] += 1
                if warningSamples[key, default: []].count < 8 {
                    warningSamples[key, default: []].append("\(relative): \(warning.message)")
                }
            }
            let parseErrors = decode.diagnostics.filter { $0.severity == .error }
            guard let level = decode.level, parseErrors.isEmpty else {
                throw CorpusFailure(description: parseErrors.prefix(4).map {
                    diagnosticText(
                        code: $0.code.rawValue,
                        line: $0.line,
                        message: $0.message
                    )
                }.joined(separator: "; "))
            }

            let resolution = resolver.resolve(level: level)
            let styleWarnings = resolution.diagnostics.filter { $0.severity == .warning }
            warnings += styleWarnings.count
            for warning in styleWarnings {
                let key = "style.\(warning.code.rawValue)"
                warningCounts[key, default: 0] += 1
                if warningSamples[key, default: []].count < 8 {
                    warningSamples[key, default: []].append("\(relative): \(warning.message)")
                }
            }
            let styleErrors = resolution.diagnostics.filter { $0.severity == .error }
            guard styleErrors.isEmpty else {
                throw CorpusFailure(description: styleErrors.prefix(4).map {
                    diagnosticText(
                        code: $0.code.rawValue,
                        line: $0.line,
                        message: $0.message
                    )
                }.joined(separator: "; "))
            }

            let rendering = renderer.render(level: level, resolution: resolution)
            let renderWarnings = rendering.diagnostics.filter { $0.severity == .warning }
            warnings += renderWarnings.count
            for warning in renderWarnings {
                let key = "render.\(warning.code.rawValue)"
                warningCounts[key, default: 0] += 1
                if warningSamples[key, default: []].count < 8 {
                    warningSamples[key, default: []].append("\(relative): \(warning.message)")
                }
            }
            let renderErrors = rendering.diagnostics.filter { $0.severity == .error }
            guard !rendering.hasErrors,
                  renderErrors.isEmpty,
                  let rendered = rendering.renderedLevel else {
                throw CorpusFailure(description: renderErrors.prefix(4).map {
                    diagnosticText(
                        code: $0.code.rawValue,
                        line: $0.line,
                        message: $0.message
                    )
                }.joined(separator: "; "))
            }

            let unsupported = NeoLemmixRules.unsupportedFeatures(
                level: level,
                renderedLevel: rendered
            )
            if !unsupported.isEmpty {
                unsupportedLevels.append((path: relative, features: unsupported))
                continue
            }

            if !warningsOnly {
                var original = try NeoLemmixSimulation(level: level, renderedLevel: rendered)
                original.run(ticks: 256)
                simulatedTicks += original.tickCount
                var restored = try JSONDecoder().decode(
                    NeoLemmixSimulation.self,
                    from: JSONEncoder().encode(original)
                )
                for _ in 0..<64 where !original.isComplete {
                    let originalEvents = original.tick()
                    let restoredEvents = restored.tick()
                    guard originalEvents == restoredEvents, original == restored else {
                        throw CorpusFailure(
                            description: "Codable continuation diverged at tick \(original.tickCount)."
                        )
                    }
                    simulatedTicks += 1
                }
            }
        } catch {
            failures.append("\(relative): \(error)")
        }
        if (index + 1).isMultiple(of: 50) || index + 1 == urls.count {
            print("NXLV corpus progress: \(index + 1)/\(urls.count)")
            fflush(stdout)
        }
    }

    print(
        "NXLV corpus: \(urls.count) levels, \(simulatedTicks) deterministic ticks, "
            + "\(warnings) warnings, \(unsupportedLevels.count) unsupported, "
            + "\(failures.count) import/render failures."
    )
    for code in warningCounts.keys.sorted() {
        print("WARN \(code): \(warningCounts[code, default: 0])")
        for sample in warningSamples[code, default: []] { print("  \(sample)") }
    }
    let featureCounts = unsupportedLevels
        .flatMap(\.features)
        .reduce(into: [String: Int]()) { counts, feature in counts[feature, default: 0] += 1 }
    for feature in featureCounts.keys.sorted() {
        print("OPEN \(feature): \(featureCounts[feature, default: 0]) level(s)")
    }
    if !failures.isEmpty {
        for failure in failures.prefix(40) { print("FAIL \(failure)") }
        if failures.count > 40 { print("...and \(failures.count - 40) more failures") }
        throw CorpusFailure(description: "NXLV corpus verification failed.")
    }
    if requireRunnable, !unsupportedLevels.isEmpty {
        for item in unsupportedLevels.prefix(40) {
            print("OPEN \(item.path): \(item.features.joined(separator: ", "))")
        }
        if unsupportedLevels.count > 40 {
            print("...and \(unsupportedLevels.count - 40) more unsupported levels")
        }
        throw CorpusFailure(description: "NXLV runnable corpus verification failed.")
    }
}

do {
    try run()
} catch {
    fputs("\(error)\n", stderr)
    exit(1)
}
