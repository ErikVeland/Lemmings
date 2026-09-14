import Foundation
import NxlvKit

enum PromotionOutcome: Equatable, Sendable {
    case fixture
    case chain
    case kept(String)
}

/// Writes an accepted route into the completion gate's directories.
/// - A route for 60 lemmings goes to Fixtures and replaces only a route that saves less.
/// - A route for another population goes to Chains. It replaces a chain route at another population,
///   or one that saves less. With `chosenByChain`, it also replaces one that saves more, because a
///   tribe run's backtracking needs that exact population forward. A fixture never gets worse.
/// - The gate allows one route per population for each level, so a route at the fixture's own
///   population goes to Fixtures. A level without a fixture takes its first route there, at any
///   population, because the gate needs a fixture before it accepts a chain route.
func promote(_ route: Lemmings2ReplayWitness, name: String, fixtures: URL, chains: URL,
             chosenByChain: Bool = false) throws -> PromotionOutcome {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    func existing(_ url: URL) -> Lemmings2ReplayWitness? {
        (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode(Lemmings2ReplayWitness.self, from: $0) }
    }
    let fixtureURL = fixtures.appendingPathComponent(name + ".json")
    let fixture = existing(fixtureURL)
    if fixture == nil || route.population == 60 || fixture?.population == route.population {
        if let fixture, fixture.population == route.population, fixture.expectedSaved >= route.expectedSaved {
            return .kept("the fixture already saves \(fixture.expectedSaved) of \(fixture.population)")
        }
        if let fixture, fixture.population != route.population {
            return .kept("the fixture is recorded for \(fixture.population) lemmings")
        }
        try encoder.encode(route).write(to: fixtureURL)
        return .fixture
    }
    let chainURL = chains.appendingPathComponent(name + ".json")
    if let old = existing(chainURL), old.population == route.population,
       old.expectedSaved >= route.expectedSaved, !(chosenByChain && old.expectedSaved != route.expectedSaved) {
        return .kept("the chain route already saves \(old.expectedSaved) of \(old.population)")
    }
    try FileManager.default.createDirectory(at: chains, withIntermediateDirectories: true)
    try encoder.encode(route).write(to: chainURL)
    return .chain
}

/// The seed for a level: a route at the starting population first, then the best route at any
/// population. Unreadable files and routes for other levels are skipped.
func seed(for name: String, level: Lemmings2Level, population: Int, fixtures: URL, chains: URL, extra: URL?)
    -> (events: [Lemmings2TimedEvent], source: String) {
    var found: [(route: Lemmings2ReplayWitness, source: String)] = []
    func read(_ url: URL, _ source: String) {
        guard let data = try? Data(contentsOf: url),
              let route = try? JSONDecoder().decode(Lemmings2ReplayWitness.self, from: data),
              route.levelSHA256 == level.fingerprint else { return }
        found.append((route, source))
    }
    read(chains.appendingPathComponent(name + ".json"), "chain")
    read(fixtures.appendingPathComponent(name + ".json"), "fixture")
    if let extra, let files = try? FileManager.default.contentsOfDirectory(at: extra, includingPropertiesForKeys: nil) {
        for file in files.sorted(by: { $0.path < $1.path }) where file.pathExtension == "json" {
            read(file, "recorded " + file.lastPathComponent)
        }
    }
    if let exact = found.first(where: { $0.route.population == population }) {
        return (exact.route.timedEvents(), exact.source + " at \(population)")
    }
    if let best = found.max(by: { $0.route.expectedSaved < $1.route.expectedSaved }) {
        return (best.route.timedEvents(), best.source + " at \(best.route.population)")
    }
    return ([], "none")
}
