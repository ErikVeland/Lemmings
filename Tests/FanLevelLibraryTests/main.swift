import Foundation

@MainActor final class ArcadeStore {
  static let shared = ArcadeStore()
  func progressKey(_ key: String) -> String { "FanLibraryTests." + key }
}
func check(_ value: Bool, _ text: String) {
  guard value else { FileHandle.standardError.write(Data("FAIL \(text)\n".utf8)); exit(1) }
  FileHandle.standardOutput.write(Data("PASS \(text)\n".utf8))
}
actor Server {
  var paths: [String] = []
  var responses: [String: Data]
  init(_ responses: [String: Data]) { self.responses = responses }
  func fetch(_ url: URL, _ limit: Int) throws -> Data {
    paths.append(url.path + (url.query.map { "?" + $0 } ?? ""))
    guard let data = responses[paths.last!], data.count <= limit else { throw FanLevelUpdates.Failure.response }
    return data
  }
}
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let source = root.appendingPathComponent("Content/LevelPacks/0001-geooPk0.zip")
let archive = try Data(contentsOf: source)
let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("FanLibraryTests-\(UUID().uuidString)")
try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: temporary) }
let embedded = temporary.appendingPathComponent("embedded"), cache = temporary.appendingPathComponent("cache")
try FileManager.default.createDirectory(at: embedded, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
try archive.write(to: embedded.appendingPathComponent(source.lastPathComponent))
try archive.write(to: cache.appendingPathComponent("0001-renamed.zip"))
let merged = FanLevelLibrary.packs(in: [embedded, cache, temporary.appendingPathComponent("missing")])
check(merged.count == 1 && merged[0].deletingLastPathComponent().resolvingSymlinksInPath().path == embedded.resolvingSymlinksInPath().path, "embedded packs open without a chosen folder and duplicate IDs are excluded")
check(FanLevelLibrary.Progress.countKey(URL(fileURLWithPath: "0384-Gronklems-1.zip"))
  != FanLevelLibrary.Progress.countKey(URL(fileURLWithPath: "0386-Gronklems-1.zip")),
  "different catalogue packs with the same display name keep separate counts")
let readable = FanLevelLibrary.entries(in: source)
check(!readable.isEmpty, "embedded pack exposes decoded levels")
_ = try FanLevelLibrary.level(readable[0], in: source)
let misnamed = root.appendingPathComponent("Content/LevelPacks/0416-grams88.zip")
let misnamedEntries = FanLevelLibrary.entries(in: misnamed)
check(misnamedEntries.count >= 20, "binary levels named .ini remain playable")
for entry in misnamedEntries { _ = try FanLevelLibrary.level(entry, in: misnamed) }
try FanLevelUpdates.validateZIP(archive)
for bytes in [Data("<html>error</html>".utf8), archive.dropLast(10), Data(repeating: 0, count: 100)] {
  do { try FanLevelUpdates.validateZIP(Data(bytes)); preconditionFailure("invalid archive accepted") }
  catch { }
}
check(true, "HTML, truncated and invalid downloads cannot be installed")
let list = Data(#"<a href="/levelpack/900/Test-New-Pack">New</a><a href="/levelpack/1/geooPk0">Old</a><a rel="next">Next</a>"#.utf8)
let next = Data(#"<a href="/levelpack/1/geooPk0">Old</a>"#.utf8)
let page = Data(#"<a href="/levelpack/download/900/Test-New-Pack?i=999">Download</a>"#.utf8)
let server = Server(["/levelpack/list?sort=-date&page=1": list,
  "/levelpack/list?sort=-date&page=2": next,
  "/levelpack/900/Test-New-Pack": page,
  "/levelpack/download/900/Test-New-Pack?i=999": archive])
let updater = FanLevelUpdates(delay: 0, fetch: { try await server.fetch($0, $1) })
let result = await updater.check(existing: merged, destination: cache)
check(result.added == 1 && !result.unavailable && result.counts["catalogue:900"] == readable.count,
      "new compatible pack downloads automatically, validates and supplies its count")
let paths = await server.paths
check(paths.count == 4 && !paths.contains(where: { $0.contains("download/1/") }), "installed packs are not downloaded and catch-up stops at a known page")
let all = FanLevelLibrary.packs(in: [embedded, cache])
check(all.count == 2 && all.contains(where: { $0.lastPathComponent == "0900-Test-New-Pack.zip" }), "downloaded additions merge with the offline library")
let repeated = await updater.check(existing: all, destination: cache)
let repeatedPaths = await server.paths
check(repeated.added == 0 && !repeated.unavailable && repeatedPaths.count == 5, "next launch performs one index check without duplicate downloads")
let offline = FanLevelUpdates(delay: 0, fetch: { _, _ in throw FanLevelUpdates.Failure.response })
let failed = await offline.check(existing: all, destination: cache)
check(failed.unavailable && FanLevelLibrary.packs(in: [embedded, cache]) == all, "offline launch preserves the entire installed collection")
let unsafe = try FanLevelUpdates.catalogue(Data(#"<a href="/levelpack/2/../../bad">Bad</a><a href="/levelpack/1/geooPk0">OK</a>"#.utf8))
check(unsafe.count == 1 && unsafe[0].id == 1, "remote names cannot escape the pack directory")
let badServer = Server(["/levelpack/list?sort=-date&page=1": list,
  "/levelpack/list?sort=-date&page=2": next,
  "/levelpack/900/Test-New-Pack": page,
  "/levelpack/download/900/Test-New-Pack?i=999": Data("<html>Unavailable</html>".utf8)])
let badDestination = temporary.appendingPathComponent("rejected")
let rejected = await FanLevelUpdates(delay: 0, fetch: { try await badServer.fetch($0, $1) })
  .check(existing: merged, destination: badDestination)
check(rejected.added == 0 && rejected.unavailable && FanLevelLibrary.packs(in: [badDestination]).isEmpty,
      "failed downloads leave no visible partial pack")
if CommandLine.arguments.contains("--live") {
  let packs = FanLevelLibrary.packs(in: [root.appendingPathComponent("Content/LevelPacks")])
  let live = await FanLevelUpdates().check(existing: packs, destination: temporary.appendingPathComponent("live"))
  check(!live.unavailable, "live catalogue check completes against the embedded collection (\(live.added) new packs)")
}
