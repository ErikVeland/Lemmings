import CryptoKit
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
let passedKey = ArcadeStore.shared.progressKey("FanLevelsPassed")
let installedPack = URL(fileURLWithPath: "0384-Gronklems-1.zip")
let removedPack = URL(fileURLWithPath: "0386-Gronklems-1.zip")
let previousPasses = UserDefaults.standard.object(forKey: passedKey)
defer {
  if let previousPasses {
    UserDefaults.standard.set(previousPasses, forKey: passedKey)
  } else {
    UserDefaults.standard.removeObject(forKey: passedKey)
  }
}
UserDefaults.standard.set([
  FanLevelLibrary.Progress.identifier(pack: installedPack, label: "Shared"),
  FanLevelLibrary.Progress.identifier(pack: removedPack, label: "Shared"),
], forKey: passedKey)
check(FanLevelLibrary.Progress.identifier(pack: installedPack, label: "Shared")
  != FanLevelLibrary.Progress.identifier(pack: removedPack, label: "Shared"),
  "same-named catalogue packs keep separate level progress identities")
check(FanLevelLibrary.Progress.passedCount(for: [installedPack]) == 1,
  "home progress excludes passes from removed fan packs")
check(FanLevelLibrary.Progress.passedCount(for: []) == 0,
  "home progress excludes every pass when no fan packs are installed")
let legacyPass = FanLevelLibrary.Progress.legacyIdentifier(
  pack: installedPack, label: "Legacy")
UserDefaults.standard.set([legacyPass], forKey: passedKey)
check(FanLevelLibrary.Progress.hasPassed(pack: installedPack, label: "Legacy")
  && FanLevelLibrary.Progress.passed.contains(
    FanLevelLibrary.Progress.identifier(pack: installedPack, label: "Legacy"))
  && !FanLevelLibrary.Progress.passed.contains(legacyPass),
  "legacy fan progress migrates to a stable pack identity")
check(FanLevelLibrary.Progress.countKey(URL(fileURLWithPath: "0384-Gronklems-1.zip"))
  != FanLevelLibrary.Progress.countKey(URL(fileURLWithPath: "0386-Gronklems-1.zip")),
  "different catalogue packs with the same display name keep separate counts")
let source = root.appendingPathComponent("Content/LevelPacks/0001-geooPk0.zip")
let archive = try Data(contentsOf: source)
let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("FanLibraryTests-\(UUID().uuidString)")
try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: temporary) }
let golemsPack = root.appendingPathComponent("Content/LevelPacks/0433-Level-Design-Game-04.zip")
check(FanLevelLibrary.mechanics(for: golemsPack) == .golems,
  "the exact source-checked Level Design Game pack uses Golems mechanics")
let juanjoPack = root.appendingPathComponent("Content/LevelPacks/0290-JUANJO1N.zip")
check(FanLevelLibrary.mechanics(for: juanjoPack) == .golems,
  "the exact source-checked JUANJO1N pack uses Golems mechanics")
let changedGolemsPack = temporary.appendingPathComponent("0433-replaced.zip")
try archive.write(to: changedGolemsPack)
let changedJuanjoPack = temporary.appendingPathComponent("0290-replaced.zip")
try archive.write(to: changedJuanjoPack)
check(FanLevelLibrary.mechanics(for: changedGolemsPack) == .original
  && FanLevelLibrary.mechanics(for: changedJuanjoPack) == .original
  && FanLevelLibrary.mechanics(for: source) == .original,
  "replacement and other fan archives retain original mechanics")
let mobiusPack = root.appendingPathComponent("Content/LevelPacks/0202-mobius1.zip")
let mobiusEntries = try FanLevelLibrary.validatedEntries(in: mobiusPack)
let sourceReplayedMobiusLevels: Set<String> = ["mobius1.dat#0", "mobius1.dat#1",
  "mobius1.dat#2", "mobius1.dat#3", "mobius1.dat#4", "Roundabout.lvl#-1",
  "LemmingsInArms.lvl#-1", "hard to port!.lvl#-1", "PlanB.lvl#-1",
  "LemmingsInMotion.lvl#-1"]
check(mobiusEntries.filter { sourceReplayedMobiusLevels.contains($0.file + "#\($0.section ?? -1)") }
    .allSatisfy { FanLevelLibrary.mechanics(for: mobiusPack, entry: $0) == .golems }
  && FanLevelLibrary.mechanics(for: mobiusPack) == .original
  && mobiusEntries.filter { !sourceReplayedMobiusLevels.contains($0.file + "#\($0.section ?? -1)") }
    .allSatisfy { FanLevelLibrary.mechanics(for: mobiusPack, entry: $0) == .original },
  "source-replayed Mobius levels and exact duplicate members use Golems mechanics only on the pinned archive")
let timpack = root.appendingPathComponent("Content/LevelPacks/0090-Timpack3.zip")
let timpackEntries = try FanLevelLibrary.validatedEntries(in: timpack)
check(timpackEntries.filter { $0.file + "#\($0.section ?? -1)" == "Timpack3.dat#6" }.count == 1
  && timpackEntries.filter { $0.file + "#\($0.section ?? -1)" == "Timpack3.dat#6" }
    .allSatisfy { FanLevelLibrary.mechanics(for: timpack, entry: $0) == .golems }
  && timpackEntries.filter { $0.file + "#\($0.section ?? -1)" != "Timpack3.dat#6" }
    .allSatisfy { FanLevelLibrary.mechanics(for: timpack, entry: $0) == .original },
  "the pinned Timpack source replay selects Golems mechanics for one level")
let akseliPack = root.appendingPathComponent("Content/LevelPacks/0220-AkseliPack01.zip")
let akseliEntries = try FanLevelLibrary.validatedEntries(in: akseliPack)
let akseliGolemsMembers: Set<String> = [
  "AkseliPack01.dat#3", "AkseliPack01.dat#4", "AkseliPack01.dat#6", "AkseliPack01.dat#8",
]
check(akseliEntries.filter { akseliGolemsMembers.contains($0.file + "#\($0.section ?? -1)") }.count == 4
  && akseliEntries.filter { akseliGolemsMembers.contains($0.file + "#\($0.section ?? -1)") }
    .allSatisfy { FanLevelLibrary.mechanics(for: akseliPack, entry: $0) == .golems }
  && akseliEntries.filter { !akseliGolemsMembers.contains($0.file + "#\($0.section ?? -1)") }
    .allSatisfy { FanLevelLibrary.mechanics(for: akseliPack, entry: $0) == .original },
  "the pinned Akseli source replays select Golems mechanics for four levels")
for (name, selectedMember) in [
  ("0207-LF-level-design-contest-1.zip", "contest1.dat#3"),
  ("0214-LF-Level-Jam-1.zip", "LF Level Jam #1.dat#6"),
] {
  let pack = root.appendingPathComponent("Content/LevelPacks/" + name)
  let entries = try FanLevelLibrary.validatedEntries(in: pack)
  check(entries.filter { $0.file + "#\($0.section ?? -1)" == selectedMember }.count == 1
    && entries.allSatisfy { entry in
      FanLevelLibrary.mechanics(for: pack, entry: entry)
        == (entry.file + "#\(entry.section ?? -1)" == selectedMember ? .golems : .original)
    }, "the pinned Akseli puzzle copy in \(name) selects Golems mechanics only for its exact member")
}
for (name, selectedMember) in [
  ("0264-Conway-Challenges-2.zip", "ConwayChallenges 2.DAT#6"),
  ("0301-Pacpack2.zip", "Pacpack2.dat#1"),
] {
  let pack = root.appendingPathComponent("Content/LevelPacks/" + name)
  let entries = try FanLevelLibrary.validatedEntries(in: pack)
  check(entries.filter { $0.file + "#\($0.section ?? -1)" == selectedMember }.count == 1
    && entries.allSatisfy { entry in
      FanLevelLibrary.mechanics(for: pack, entry: entry)
        == (entry.file + "#\(entry.section ?? -1)" == selectedMember ? .ohNoMore : .original)
    }, "the pinned official puzzle copy in \(name) selects later hatch rules only for its exact member")
}
for (name, selectedMembers) in [
  ("0002-geooPk1.zip", Set(["geooPk1.dat#7"])),
  ("0035-1tseug.zip", Set(["1tseug.dat#2", "1tseug.dat#9"])),
  ("0472-CPs-Level-Pack.zip", Set(["LEMPACK.DAT#3", "LEMPACK.DAT#4", "levels/04.LVL#-1", "levels/05.LVL#-1"])),
  ("0482-DOS-Frost.zip", Set(["Frost.DAT#12"])),
  ("0484-DOS-Flurry.zip", Set(["Flurry.DAT#3", "Flurry.DAT#14"])),
  ("0485-DOS-Blitz.zip", Set(["Blitz.DAT#3", "Blitz.DAT#4", "Blitz.DAT#7", "Blitz.DAT#9", "Blitz.DAT#13"])),
  ("0519-Van-Clan-Wild.zip", Set(["Van Clan Wild 1.dat#5"])),
] {
  let pack = root.appendingPathComponent("Content/LevelPacks/" + name)
  let entries = try FanLevelLibrary.validatedEntries(in: pack)
  let holidayLaterMembers: Set<String> = name == "0484-DOS-Flurry.zip" ? ["Flurry.DAT#13"]
    : name == "0485-DOS-Blitz.zip" ? [
      "Blitz.DAT#0", "Blitz.DAT#1", "Blitz.DAT#6", "Blitz.DAT#8",
      "Blitz.DAT#10", "Blitz.DAT#12", "Blitz.DAT#15",
    ] : []
  check(entries.filter { selectedMembers.contains($0.file + "#\($0.section ?? -1)") }.count == selectedMembers.count
    && entries.filter { holidayLaterMembers.contains($0.file + "#\($0.section ?? -1)") }.count == holidayLaterMembers.count
    && entries.allSatisfy { entry in
      let selected = selectedMembers.contains(entry.file + "#\(entry.section ?? -1)")
      let levelID = entry.file + "#\(entry.section ?? -1)"
      let fallback: ClassicDOSMechanics = (name == "0482-DOS-Frost.zip" && levelID != "Frost.DAT#3")
        || holidayLaterMembers.contains(levelID) ? .ohNoMore : .original
      return FanLevelLibrary.mechanics(for: pack, entry: entry) == (selected ? .golems : fallback)
    }, "pinned source replays select Golems mechanics for the exact geoo and 1tseug members")
}
for name in ["0478-DOS-Amiga-Crazy.zip", "0479-DOS-Amiga-Wild.zip", "0480-DOS-Amiga-Wicked.zip",
             "0481-DOS-Amiga-Havoc.zip", "0482-DOS-Frost.zip", "0483-DOS-Hail.zip",
             "0487-DOS-Xmas-1992.zip", "0583-Amiga-Oh-No-More-Lemmings-Two-Player.zip"] {
  let pack = root.appendingPathComponent("Content/LevelPacks/" + name)
  check(FanLevelLibrary.mechanics(for: pack) == .ohNoMore,
    "the pinned official conversion \(name) retains later hatch mechanics")
}
let sourceCheckedLevels: [(Int, String)] = [
  (523, "Deceit Tricky 1.dat#5"),
  (542, "Pieuw 2007 Peace 2.DAT#8"),
  (277, "CRISFN13.dat#6"),
  (552, "Lemmings Plus DOS Project - 06 - Wimpy (Part 3).dat#8"),
  (552, "Lemmings Plus DOS Project - 05 - Wimpy (Part 2).dat#6"),
  (268, "CRISFN04.dat#1"),
  (268, "CRISFN04.dat#7"),
  (327, "JM01.DAT#7"),
  (494, "JANNPCK3.DAT#4"),
  (232, "JANNPCK2.DAT#9"),
  (237, "JEFFPCK3.DAT#5"),
  (265, "CRISFN01.dat#3"),
  (82, "Yawg01.dat#1"),
  (179, "The lemming google pack.dat#5"),
  (181, "Lemmings platinum Fragle part 2.dat#10"),
  (246, "Martin Zurlinden 03.dat#2"),
  (497, "MARTPCK3.DAT#2"),
  (22, "ISteve08.dat#6"),
  (223, "ANTHPCK3.DAT#9"),
  (224, "ANTHPCK4.DAT#7"),
  (315, "TWPAK13.dat#1"),
  (306, "TWPAK04.dat#3"),
  (366, "LEVIPAK2.DAT#0"),
  (388, "geooPk2_preview2.dat#0"),
  (388, "geooPk2_preview2.dat#1"),
  (393, "pieuw01.dat#9"),
  (405, "Genesis 2P 2.dat#5"),
  (592, "LEVELPAK.DAT#1"),
  (33, "QBeez03.dat#9"),
  (78, "doggycharly random lvls.dat#0"),
  (140, "Epic giga02.dat#0"),
  (160, "Giga pack 01.dat#9"),
  (165, "Giga pack 04.dat#5"),
  (171, "Giga pack 09.dat#6"),
  (191, "Lemmings platinum Dangerous Part 2.dat#14"),
  (193, "Gronklems #1.dat#2"),
  (193, "Gronklems #1.dat#9"),
  (217, "PSP Special.dat#3"),
  (218, "PSP Special2.dat#2"),
  (218, "PSP Special2.dat#3"),
  (394, "pieuw02.dat#0"),
  (394, "pieuw02.dat#2"),
  (411, "mobius05.dat#1"),
  (496, "MARTPCK2.DAT#6"),
  (543, "Pieuw 2007 Awkward 2.DAT#6"),
  (544, "Pieuw 2007 Artful 1.DAT#0"),
  (544, "Pieuw 2007 Artful 1.DAT#3"),
  (544, "Pieuw 2007 Artful 1.DAT#7"),
  (545, "Pieuw 2007 Insane 2.DAT#4"),
]
let bundledPacks = FanLevelLibrary.packs(in: [root.appendingPathComponent("Content/LevelPacks")])
for (number, levelID) in sourceCheckedLevels {
  guard let pack = bundledPacks.first(where: { FanLevelLibrary.catalogueID($0) == "lldb-\(number)" })
  else { fatalError("Missing bundled source-checked pack \(number)") }
  let entries = try FanLevelLibrary.validatedEntries(in: pack)
  guard let selected = entries.first(where: { $0.file + "#\($0.section ?? -1)" == levelID })
  else { fatalError("Missing bundled source-checked level \(levelID)") }
  check(FanLevelLibrary.mechanics(for: pack, entry: selected) == .golems,
    "source-checked bundled level uses Golems rules")
  check(FanLevelLibrary.mechanics(for: pack) == .original
    && entries.filter { $0.file + "#\($0.section ?? -1)" != levelID }
      .contains { FanLevelLibrary.mechanics(for: pack, entry: $0) == .original },
    "mixed-evidence packs retain original rules for unselected levels")
}
let embedded = temporary.appendingPathComponent("embedded"), cache = temporary.appendingPathComponent("cache")
try FileManager.default.createDirectory(at: embedded, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
try archive.write(to: embedded.appendingPathComponent(source.lastPathComponent))
try archive.write(to: cache.appendingPathComponent("0001-renamed.zip"))
let merged = FanLevelLibrary.packs(in: [embedded, cache, temporary.appendingPathComponent("missing")])
check(merged.count == 1 && merged[0].deletingLastPathComponent().resolvingSymlinksInPath().path == embedded.resolvingSymlinksInPath().path, "embedded packs open without a chosen folder and duplicate IDs are excluded")
let readable = FanLevelLibrary.entries(in: source)
check(!readable.isEmpty, "embedded pack exposes decoded levels")
_ = try FanLevelLibrary.level(readable[0], in: source)
let verifiedReadable = try FanLevelLibrary.validatedEntries(in: source)
check(verifiedReadable.count == readable.count, "verified archive exposes the complete decoded level list")
let corruptArchive = temporary.appendingPathComponent("corrupt.zip")
try Data("not a zip archive".utf8).write(to: corruptArchive)
do {
  _ = try FanLevelLibrary.validatedEntries(in: corruptArchive)
  preconditionFailure("corrupt fan archive accepted")
} catch {
  check(true, "corrupt fan archives fail verified playlist discovery")
}
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
  check(FanLevelLibrary.artworkFamily(for: resolved, portsRoot: ports)
    == (slot < 5 ? "lemmings" : slot < 9 ? "ohno" : "holiday"),
    "alternate artwork for slot \(slot) follows its resolved release")
}
let emptyLevel = try ClassicLevel(data: Data(repeating: 0, count: ClassicLevel.recordSize))
let namedSnow = try FanLevelLibrary.groundSet(for: emptyLevel, styleName: " Snow ", portsRoot: ports)
check(namedSnow == (try ClassicGroundSet.load(style: 2, from: extraStyles)), "named graphics take precedence over the numeric slot")
check(FanLevelLibrary.artworkFamily(for: namedSnow, portsRoot: ports) == "ohno",
  "named Snow does not use the numeric slot's original artwork")
var customGround = try JSONSerialization.jsonObject(with: JSONEncoder().encode(namedSnow)) as! [String: Any]
var customPalette = customGround["terrainPalette"] as! [[String: Any]]
customPalette[0]["red"] = 123
customGround["terrainPalette"] = customPalette
let recoloured = try JSONDecoder().decode(ClassicGroundSet.self, from: JSONSerialization.data(withJSONObject: customGround))
check(FanLevelLibrary.artworkFamily(for: recoloured, portsRoot: ports) == nil,
  "custom pack artwork is not replaced by an unrelated stock bank")
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

// Release-local slots must use the source release, even when a wrong tile happens to fit.
let localFixtures: [(String, String)] = [
  ("0477-DOS-Amiga-Tame.zip", "oh_no_more_lemmings_dos-1991-11-14_2232"),
  ("0478-DOS-Amiga-Crazy.zip", "oh_no_more_lemmings_dos-1991-11-14_2232"),
  ("0479-DOS-Amiga-Wild.zip", "oh_no_more_lemmings_dos-1991-11-14_2232"),
  ("0480-DOS-Amiga-Wicked.zip", "oh_no_more_lemmings_dos-1991-11-14_2232"),
  ("0481-DOS-Amiga-Havoc.zip", "oh_no_more_lemmings_dos-1991-11-14_2232"),
  ("0486-DOS-Xmas-1991.zip", "xmas_dos_XmasLemmingsV1.9"),
  ("0487-DOS-Xmas-1992.zip", "xmas_dos_XmasLemmingsV1.9a1"),
  ("0530-Oh-No-More-cLemmings-Tame.zip", "oh_no_more_lemmings_dos-1991-11-14_2232"),
  ("0531-Oh-No-More-cLemmings-Crazy.zip", "oh_no_more_lemmings_dos-1991-11-14_2232"),
  ("0532-Oh-No-More-cLemmings-Wild.zip", "oh_no_more_lemmings_dos-1991-11-14_2232"),
  ("0533-Oh-No-More-cLemmings-Wicked.zip", "oh_no_more_lemmings_dos-1991-11-14_2232"),
  ("0534-Oh-No-More-cLemmings-Havoc.zip", "oh_no_more_lemmings_dos-1991-11-14_2232"),
  ("0583-Amiga-Oh-No-More-Lemmings-Two-Player.zip", "oh_no_more_lemmings_dos-1991-11-14_2232"),
]
var localLevelCount = 0
for (name, directory) in localFixtures {
  let pack = root.appendingPathComponent("Content/LevelPacks/" + name)
  check(FanLevelLibrary.localStyleDirectory(in: pack) == directory, "verified release identity: " + name)
  for entry in FanLevelLibrary.entries(in: pack) {
    let (level, style) = try FanLevelLibrary.level(entry, in: pack)
    let ground = try FanLevelLibrary.groundSet(for: level, styleName: style, portsRoot: ports, pack: pack, entry: entry)
    let expected = try ClassicGroundSet.load(style: level.groundStyle, from: ports.appendingPathComponent(directory))
    check(ground == expected, "release-local graphics: " + level.title)
    let scene = try ClassicLevelRenderer.render(level, groundSet: ground)
    _ = try ClassicDOSSimulation(level: level, renderedLevel: scene, mainDATAssets: ClassicMainDATAssets.load(from: originalStyles))
    localLevelCount += 1
  }
}
let localPack = root.appendingPathComponent("Content/LevelPacks/0478-DOS-Amiga-Crazy.zip")
let renamedLocal = temporary.appendingPathComponent("renamed.zip")
var localBytes = try Data(contentsOf: localPack)
try localBytes.write(to: renamedLocal)
check(FanLevelLibrary.localStyleDirectory(in: renamedLocal) == localFixtures[0].1, "renamed verified archive retains its convention")
localBytes[0] ^= 1
try localBytes.write(to: renamedLocal)
check(FanLevelLibrary.localStyleDirectory(in: renamedLocal) == nil, "same-sized changed archive cannot inherit verified metadata")
check(FanLevelLibrary.localStyleDirectory(in: source) == nil, "unknown packs retain combined-editor numbering")
let localEntry = FanLevelLibrary.entries(in: localPack)[1]
let localLevel = try FanLevelLibrary.level(localEntry, in: localPack).0
let legacyGround = try FanLevelLibrary.groundSet(for: localLevel, styleName: nil, portsRoot: ports, pack: localPack, useLocalStyles: false)
check(legacyGround == (try FanLevelLibrary.groundSet(for: localLevel, styleName: nil, portsRoot: ports)), "legacy attempt preserves combined-editor graphics")
check(try FanLevelLibrary.groundSet(for: localLevel, styleName: "dirt", portsRoot: ports, pack: localPack)
  == ClassicGroundSet.load(style: 0, from: originalStyles), "explicit named style overrides release metadata")
print("PASS \(localLevelCount) release-local levels render and start")

// Compare the canonical reissues directly with the bundled official records.
var canonicalMatches = 0
for (name, directory) in localFixtures where name.hasPrefix("047") || name.hasPrefix("048") {
  let official = try ClassicDataSet.detect(directory: ports.appendingPathComponent(directory))
  let pack = root.appendingPathComponent("Content/LevelPacks/" + name)
  for entry in FanLevelLibrary.entries(in: pack) {
    let level = try FanLevelLibrary.level(entry, in: pack).0
    if let original = official.campaign.levels.first(where: {
      $0.level.terrain == level.terrain && $0.level.objects == level.objects
    }) {
      check(original.level.groundStyle == level.groundStyle, "official record confirms release slot: " + level.title)
      canonicalMatches += 1
    }
  }
}
check(canonicalMatches >= 100, "at least 100 canonical records confirm release-local numbering")
print("PASS \(canonicalMatches) canonical terrain/object records match the original release")

let holidayFixtures: [String] = ["0482-DOS-Frost.zip", "0483-DOS-Hail.zip", "0535-Holiday-cLemmings-Frost.zip", "0536-Holiday-cLemmings-Hail.zip"]

var holidayCount = 0
var holidayMatches = 0
let holidayOfficial = try ClassicDataSet.detect(directory: ports.appendingPathComponent("holiday_native_1994"))
for name in holidayFixtures {
  let pack = root.appendingPathComponent("Content/LevelPacks/" + name)
  check(FanLevelLibrary.localStyleDirectory(in: pack) == nil, "previous graphics revision retains legacy Holiday assets")
  check(FanLevelLibrary.localStyleDirectory(in: pack, includeHoliday: true) == "holiday_native_1994", "verified Holiday identity: " + name)
  for entry in FanLevelLibrary.entries(in: pack) {
    let level = try FanLevelLibrary.level(entry, in: pack).0
    check(level.groundStyle == 2, "verified Holiday archive contains only slot 2")
    let ground = try FanLevelLibrary.groundSet(for: level, styleName: nil, portsRoot: ports, pack: pack, entry: entry)
    check(ground == (try ClassicGroundSet.load(style: 2, from: ports.appendingPathComponent("holiday_native_1994"))), "Holiday snow assets: " + level.title)
    let scene = try ClassicLevelRenderer.render(level, groundSet: ground)
    _ = try ClassicDOSSimulation(level: level, renderedLevel: scene, mainDATAssets: ClassicMainDATAssets.load(from: originalStyles))
    check(try FanLevelLibrary.groundSet(for: level, styleName: nil, portsRoot: ports, pack: pack, useHolidayStyles: false)
      == ClassicGroundSet.load(style: 2, from: originalStyles), "older Holiday attempt retains marble")
    if name.hasPrefix("048"), let match = holidayOfficial.campaign.levels.first(where: {
      $0.level.terrain == level.terrain && $0.level.objects == level.objects
    }) {
      check(match.level.groundStyle == 2, "official Holiday record confirms slot")
      holidayMatches += 1
    }
    holidayCount += 1
  }
}
check(holidayCount == 64 && holidayMatches >= 30, "Holiday inventory and original-record matches")
print("PASS \(holidayCount) Holiday levels render/start; \(holidayMatches) original records match")
for name in ["0484-DOS-Flurry.zip", "0485-DOS-Blitz.zip",
             "0537-Holiday-cLemmings-Flurry.zip", "0538-Holiday-cLemmings-Blitz.zip"] {
  let pack = root.appendingPathComponent("Content/LevelPacks/" + name)
  check(FanLevelLibrary.localStyleDirectory(in: pack, includeHoliday: true) == "holiday_native_1994",
    "verified Holiday Flurry and Blitz archives select Holiday graphics")
  for entry in try FanLevelLibrary.validatedEntries(in: pack) {
    let level = try FanLevelLibrary.level(entry, in: pack).0
    let ground = try FanLevelLibrary.groundSet(for: level, styleName: nil, portsRoot: ports, pack: pack, entry: entry)
    let expectedRoot = level.groundStyle == 2 ? ports.appendingPathComponent("holiday_native_1994") : originalStyles
    check(ground == (try ClassicGroundSet.load(style: level.groundStyle, from: expectedRoot)),
      "Holiday Flurry and Blitz keep the exact style for " + level.title)
  }
}

let literalPack = root.appendingPathComponent("Tests/FanLevelLibraryTests/Fixtures/literal-members.zip")
let literalNames = ["level[1].ini", "level1.ini", "star*.ini", "starX.ini", "q?.ini",
                    "qa.ini", #"back\slash.ini"#, "nested[1]/level.ini", "nested1/level.ini", "-x.ini"]
let literalEntries = FanLevelLibrary.entries(in: literalPack)
check(literalEntries.count == literalNames.count, "all literal member names remain independently selectable")
for (index, name) in literalNames.enumerated() {
  let entry = literalEntries.first { $0.file == name }!
  check(try FanLevelLibrary.level(entry, in: literalPack).0.title == "Literal \(index)",
        "exact archive member: " + name)
}
let duplicatePack = root.appendingPathComponent("Tests/FanLevelLibraryTests/Fixtures/duplicate-members.zip")
let duplicateEntries = FanLevelLibrary.entries(in: duplicatePack)
check(duplicateEntries.map(\.file) == ["unique.ini"], "ambiguous duplicate members cannot merge into one level")
do {
  _ = try FanLevelLibrary.level(.init(file: "same.ini", section: nil, label: "Duplicate"), in: duplicatePack)
  preconditionFailure("duplicate member selected directly")
} catch {
  check(true, "direct or saved selection of duplicate member is rejected")
}

// Remove an interior DAT record while keeping the saved identities on either side.
let sourceEntry = readable.first { $0.section != nil }!
let sourceDAT = try member(sourceEntry.file, in: source)
let sourceSections = try ClassicDATArchive.decode(sourceDAT)
check(sourceSections.count >= 3, "slot migration fixture has three records")
let pruningFolder = temporary.appendingPathComponent("pruned")
try FileManager.default.createDirectory(at: pruningFolder, withIntermediateDirectories: true)
let mappedDAT = pruningFolder.appendingPathComponent("levels.dat")
var retainedDAT = Data()
for slot in [0, 2] {
  let section = sourceSections[slot]
  retainedDAT.append(sourceDAT[section.archiveOffset..<(section.archiveOffset + section.compressedSize)])
}
try retainedDAT.write(to: mappedDAT)
let mappingFile = pruningFolder.appendingPathComponent("classic-section-slots.json")
func mappedPack(_ slots: [Int], name: String) throws -> URL {
  try JSONEncoder().encode(["levels.dat": slots]).write(to: mappingFile)
  let destination = temporary.appendingPathComponent(name + ".zip")
  let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
  process.currentDirectoryURL = pruningFolder
  process.arguments = ["-q", destination.path, "levels.dat", "classic-section-slots.json"]
  try process.run(); process.waitUntilExit()
  check(process.terminationStatus == 0, "create mapped archive \(name)")
  return destination
}
let prunedPack = try mappedPack([0, 2], name: "valid-slots")
let prunedEntries = FanLevelLibrary.entries(in: prunedPack)
check(prunedEntries.map(\.section) == [0, 2], "pruning keeps original DAT slot identities")
for entry in prunedEntries {
  check(try FanLevelLibrary.level(entry, in: prunedPack).0 == ClassicLevel(data: sourceSections[entry.section!].data),
        "saved slot \(entry.section!) still resolves to its original level")
}
let oldQueue = (0..<3).map { FanLevelLibrary.Entry(file: "levels.dat", section: $0, label: "saved") }
let restored = try FanLevelLibrary.restoredQueue(oldQueue, index: 2, in: prunedPack)
check(restored.index == 1 && restored.entries.map(\.section) == [0, 2],
      "saved queue removes deleted entries and preserves current ownership and position")
do {
  _ = try FanLevelLibrary.level(oldQueue[1], in: prunedPack)
  preconditionFailure("removed slot resolves to its neighbour")
} catch { check(true, "deleted slots never select another level") }
do {
  _ = try FanLevelLibrary.restoredQueue(oldQueue, index: 1, in: prunedPack)
  preconditionFailure("removed current attempt restored as another level")
} catch { check(true, "deleted current attempt fails without changing its identity") }
for (index, slots) in [[0, 0], [-1, 2], [0], [0, 10000]].enumerated() {
  let invalid = try mappedPack(slots, name: "invalid-slots-\(index)")
  check(FanLevelLibrary.entries(in: invalid).isEmpty, "invalid slot mapping cannot enter catalogue")
  do {
    _ = try FanLevelLibrary.level(oldQueue[0], in: invalid)
    preconditionFailure("invalid mapping selected directly")
  } catch { check(true, "invalid saved slot mapping is rejected") }
}

// A root under /private (App Translocation, /tmp) must give the same folder
// fingerprint, with the same "/relative" keys, as the unprefixed path.
let fingerprintRoot = FileManager.default.temporaryDirectory.appendingPathComponent("fingerprint-\(UUID())")
try FileManager.default.createDirectory(at: fingerprintRoot.appendingPathComponent("LEVELS"), withIntermediateDirectories: true)
try Data("main".utf8).write(to: fingerprintRoot.appendingPathComponent("MAIN.DAT"))
try Data("level".utf8).write(to: fingerprintRoot.appendingPathComponent("LEVELS/LEVEL000.DAT"))
try Data("hidden".utf8).write(to: fingerprintRoot.appendingPathComponent(".hidden"))
try Data("music".utf8).write(to: fingerprintRoot.appendingPathComponent("LEVELS/song.mod"))
defer { try? FileManager.default.removeItem(at: fingerprintRoot) }
let plainPath = fingerprintRoot.resolvingSymlinksInPath().path
let privatePath = plainPath.hasPrefix("/private/") ? plainPath : "/private" + plainPath
let expectedEntries = [
  "/LEVELS/LEVEL000.DAT": FanLevelLibrary.archiveFingerprint(fingerprintRoot.appendingPathComponent("LEVELS/LEVEL000.DAT"))!,
  "/MAIN.DAT": FanLevelLibrary.archiveFingerprint(fingerprintRoot.appendingPathComponent("MAIN.DAT"))!,
]
let fingerprintEncoder = JSONEncoder(); fingerprintEncoder.outputFormatting = [.sortedKeys]
let expectedFingerprint = SHA256.hash(data: try fingerprintEncoder.encode(expectedEntries))
  .map { String(format: "%02x", $0) }.joined()
check(FanLevelLibrary.directoryFingerprint(URL(fileURLWithPath: plainPath)) == expectedFingerprint,
      "folder fingerprint keys files by their path inside the folder")
check(FanLevelLibrary.directoryFingerprint(URL(fileURLWithPath: privatePath)) == expectedFingerprint,
      "a folder under /private keeps its fingerprint")

let lateExitPack = root.appendingPathComponent("Content/LevelPacks/0308-TWPAK06.zip")
let lateExitEntry = try FanLevelLibrary.validatedEntries(in: lateExitPack).first {
  $0.file == "TWPAK06.dat" && $0.section == 9
}!
let (lateExitLevel, lateExitStyle) = try FanLevelLibrary.level(lateExitEntry, in: lateExitPack)
let lateExitGround = try FanLevelLibrary.groundSet(for: lateExitLevel, styleName: lateExitStyle,
  portsRoot: ports, pack: lateExitPack, entry: lateExitEntry)
check(ClassicObjectSemantics.forFanLevel(lateExitLevel, groundSet: lateExitGround) == .golems,
      "fan level with only a later exit selects all 32 object slots")
let lateExitScene = try ClassicLevelRenderer.render(lateExitLevel, groundSet: lateExitGround,
  objectSemantics: .forFanLevel(lateExitLevel, groundSet: lateExitGround))
check(lateExitScene.triggers.contains { $0.effect == 1 },
      "bundled fan level has a functional exit")
let officialFirst = try ClassicDataSet.detect(directory: originalStyles).campaign.levels[0].level
let officialGround = try ClassicGroundSet.load(style: officialFirst.groundStyle, from: originalStyles)
check(ClassicObjectSemantics.forFanLevel(officialFirst, groundSet: officialGround) == .dos,
      "level with an ordinary exit retains DOS object slots")
