import Foundation
import NxlvKit

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

let ports = URL(fileURLWithPath: ProcessInfo.processInfo.environment["FAN_TEST_PORTS_DIR"]
  ?? root.appendingPathComponent(".build/local/Ultimate Lemmings.app/Contents/Resources/Ports").path)
let originalStyles = ports.appendingPathComponent("lemmings_dos_1991-07-30")
let extraStyles = ports.appendingPathComponent("oh_no_more_lemmings_dos-1991-11-14_2232")
for slot in 0..<10 {
  var bytes = Data(repeating: 0, count: ClassicLevel.recordSize)
  bytes[0x1B] = UInt8(slot)
  let level = try ClassicLevel(data: bytes)
  let resolved = try FanLevelLibrary.groundSet(for: level, styleName: nil, portsRoot: ports)
  let expected = try ClassicGroundSet.load(style: slot < 5 ? slot : (slot < 9 ? slot - 5 : 2),
    from: slot < 5 ? originalStyles : (slot < 9 ? extraStyles : ports.appendingPathComponent("holiday_native_1994")))
  check(resolved == expected, "custom graphics slot \(slot) uses its own release assets")
}
let emptyLevel = try ClassicLevel(data: Data(repeating: 0, count: ClassicLevel.recordSize))
let namedSnow = try FanLevelLibrary.groundSet(for: emptyLevel, styleName: " Snow ", portsRoot: ports)
check(namedSnow == (try ClassicGroundSet.load(style: 2, from: extraStyles)), "named graphics take precedence over the numeric slot")
for name in ["xmas", "christmas"] {
  let ground = try FanLevelLibrary.groundSet(for: emptyLevel, styleName: name, portsRoot: ports)
  check(ground == (try ClassicGroundSet.load(style: 2, from: ports.appendingPathComponent("holiday_native_1994"))), "\(name) resolves Holiday graphics")
}
do {
  _ = try FanLevelLibrary.groundSet(for: emptyLevel, styleName: "missing-custom-style", portsRoot: ports)
  preconditionFailure("unknown style silently used a different style")
} catch { check(true, "unknown named styles fail instead of silently changing level geometry") }

func member(_ name: String, in pack: URL) throws -> Data {
  let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
  process.arguments = ["-p", pack.path, name]
  let pipe = Pipe(); process.standardOutput = pipe
  try process.run(); let data = pipe.fileHandleForReading.readDataToEndOfFile(); process.waitUntilExit()
  check(process.terminationStatus == 0, "read fixture asset \(name)")
  return data
}
let applePack = root.appendingPathComponent("Content/LevelPacks/0395-The-Apple-Computer-Level.zip")
let appleEntry = FanLevelLibrary.entries(in: applePack)[0]
let (apple, appleStyle) = try FanLevelLibrary.level(appleEntry, in: applePack)
let appleGraphic = try FanLevelLibrary.specialGraphic(for: apple, entry: appleEntry, pack: applePack, portsRoot: ports)
check(appleGraphic == (try ClassicSpecialGraphic(archiveData: member("vgaspec6.dat", in: applePack))),
  "fan special picture comes from its own archive")
let appleGround = try FanLevelLibrary.groundSet(for: apple, styleName: appleStyle, portsRoot: ports, pack: applePack, entry: appleEntry)
let appleScene = try ClassicLevelRenderer.render(apple, groundSet: appleGround, specialGraphic: appleGraphic)
_ = try ClassicDOSSimulation(level: apple, renderedLevel: appleScene, mainDATAssets: ClassicMainDATAssets.load(from: originalStyles))
check(true, "Apple Computer fan level renders and starts with its bundled picture")
let genesisPack = root.appendingPathComponent("Content/LevelPacks/0491-Genesis-Mayhem.zip")
for entry in FanLevelLibrary.entries(in: genesisPack) {
  let (level, style) = try FanLevelLibrary.level(entry, in: genesisPack)
  let ground = try FanLevelLibrary.groundSet(for: level, styleName: style, portsRoot: ports, pack: genesisPack, entry: entry)
  let graphicsFile = originalStyles.appendingPathComponent("VGAGR\(level.groundStyle).DAT")
  let expected = try ClassicGroundSet(style: level.groundStyle,
    groundData: member("GROUND\(level.groundStyle)O.DAT", in: genesisPack), graphicsArchiveData: Data(contentsOf: graphicsFile))
  check(ground == expected, "Genesis fan pack uses its own terrain definitions for \(entry.label)")
}
let stockEntry = FanLevelLibrary.entries(in: source)[0]
let stockLevel = try FanLevelLibrary.level(stockEntry, in: source)
check(try FanLevelLibrary.groundSet(for: stockLevel.0, styleName: stockLevel.1, portsRoot: ports, pack: source, entry: stockEntry)
  == FanLevelLibrary.groundSet(for: stockLevel.0, styleName: stockLevel.1, portsRoot: ports),
  "packs without custom graphics retain stock terrain")
for (name, picture) in [("0002-geooPk1.zip", "vgaspecS.dat"), ("0399-Mon0lith.zip", "vgaspecm.dat")] {
  let pack = root.appendingPathComponent("Content/LevelPacks/" + name)
  var checked = false
  for entry in FanLevelLibrary.entries(in: pack) {
    let (level, style) = try FanLevelLibrary.level(entry, in: pack)
    guard level.specialStyle > 10 else { continue }
    let graphic = try FanLevelLibrary.specialGraphic(for: level, entry: entry, pack: pack, portsRoot: ports)
    check(graphic == (try ClassicSpecialGraphic(archiveData: member(picture, in: pack))), "letter-coded special graphic for \(level.title)")
    let ground = try FanLevelLibrary.groundSet(for: level, styleName: style, portsRoot: ports, pack: pack, entry: entry)
    let scene = try ClassicLevelRenderer.render(level, groundSet: ground, specialGraphic: graphic)
    _ = try ClassicDOSSimulation(level: level, renderedLevel: scene, mainDATAssets: ClassicMainDATAssets.load(from: originalStyles))
    checked = true
  }
  check(checked, "letter-coded pack fixture renders and starts: \(name)")
}

// Text steel uses exact rectangles, including partial offscreen areas.
let steelText = """
releaseRate = 1
numLemmings = 10
numToRescue = 5
timeLimit = 3
object_0 = 1, 100, 20
steel_0 = -3, -2, 10, 9
steel_1 = 1598, 158, 960, 400
steel_2 = -1000000000, -1000000000, 2, 2
"""
let steelLevel = try FanLevelReader.level(fromINI: steelText)
let steelGround = try ClassicGroundSet.load(style: 0, from: originalStyles)
let steelScene = try ClassicLevelRenderer.render(steelLevel, groundSet: steelGround)
check(steelScene.steelMask.filter { $0 != 0 }.count == 53,
      "exact text steel clips to the playfield without rounding or scanning offscreen pixels")
var steelTerrain = try ClassicDOSTerrain(renderedLevel: steelScene)
_ = steelTerrain.addSolid(x: 6, y: 6)
_ = steelTerrain.addSolid(x: 7, y: 6)
check(steelTerrain.isSteelProtected(x: 6, y: 6) && !steelTerrain.removeSolid(x: 6, y: 6)
  && !steelTerrain.isSteelProtected(x: 7, y: 6) && steelTerrain.removeSolid(x: 7, y: 6),
  "simulation terrain protects the exact text steel boundary")
let extremeLevel = try ClassicLevel(data: Data(repeating: 0, count: ClassicLevel.recordSize),
  steelOverride: [ClassicSteelArea(x: -1, y: -1, width: Int.max, height: Int.max),
                  ClassicSteelArea(x: Int.max, y: 0, width: 5, height: 5),
                  ClassicSteelArea(x: 0, y: 0, width: -1, height: 5)])
let extremeScene = try ClassicLevelRenderer.render(extremeLevel, groundSet: steelGround)
check(extremeScene.steelMask.allSatisfy { $0 == 1 }, "extreme steel rectangles render in bounded work without overflow")
