import Foundation
import Darwin

func check(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
    guard try condition() else { fatalError(message) }
}
func rejects(_ body: () throws -> Void) throws {
    do { try body() } catch { return }
    fatalError("Expected rejection")
}
let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: root) }
let recovery = RunRecovery(engine: "test", profileID: "player", runID: UUID(), dataSetID: "lemmings",
    levelIndex: 0, levelFingerprint: "level", initialStateHash: "initial", tick: 10, events: [],
    stateHash: "current", usedRewind: false, nukeCount: 0, rewindCount: 0, undoCount: 0,
    selectedSkill: 0, scrollX: 0, scrollY: 0)
func seeded(_ name: String) throws -> RunRecoveryFile {
    let file = RunRecoveryFile(url: root.appendingPathComponent(name))
    _ = try file.load()
    try file.save(recovery)
    return file
}
func oversized(_ url: URL) throws {
    let file = try FileHandle(forWritingTo: url)
    defer { try? file.close() }
    try file.truncate(atOffset: 64 * 1024 * 1024 + 1)
}

let large = try seeded("large.json")
try oversized(large.url)
try check(try large.load()?.runID == recovery.runID, "Oversized primary did not recover")
try check(large.recoveredBackup, "Recovery was not reported")
let preserved = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
    .filter { $0.lastPathComponent.hasPrefix("large.json.unreadable-") }
try check(preserved.count == 1, "Oversized primary was not preserved")
try check(try preserved[0].resourceValues(forKeys: [.fileSizeKey]).fileSize == 64 * 1024 * 1024 + 1,
    "Preserved file was truncated")
_ = try large.load()
try check(!large.recoveredBackup, "Recovery flag leaked into a normal load")
try large.save(recovery)
print("PASS oversized-primary recovery, preservation and subsequent save")

let both = try seeded("both.json")
try oversized(both.url)
let badBackup = Data("bad backup".utf8)
try badBackup.write(to: both.backupURL)
try rejects { _ = try both.load() }
try check(try both.url.resourceValues(forKeys: [.fileSizeKey]).fileSize == 64 * 1024 * 1024 + 1,
    "Failed recovery changed primary")
try check(try Data(contentsOf: both.backupURL) == badBackup, "Failed recovery changed backup")
try FileManager.default.removeItem(at: both.backupURL)
try rejects { _ = try both.load() }
print("PASS invalid or missing backup preserves oversized primary")

let future = try seeded("future.json")
let unknown = Data("{\"version\":2,\"payload\":null,\"checksum\":\"future\"}".utf8)
try unknown.write(to: future.url)
try rejects { _ = try future.load() }
try check(try Data(contentsOf: future.url) == unknown, "Unsupported document was overwritten")
print("PASS future-version protection")

let conflict = try seeded("conflict.json")
let stale = RunRecoveryFile(url: conflict.url)
_ = try stale.load()
var newer = recovery
newer.savedAt = recovery.savedAt.addingTimeInterval(1)
try conflict.save(newer)
try rejects { try stale.save(recovery) }
let lock = open(conflict.url.appendingPathExtension("lock").path, O_RDWR)
try check(lock >= 0, "Cannot open test lock")
try check(flock(lock, LOCK_EX | LOCK_NB) == 0, "Cannot lock fixture")
try rejects { _ = try conflict.load() }
flock(lock, LOCK_UN)
close(lock)
try conflict.save(nil)
try Data("broken".utf8).write(to: conflict.url)
try check(try RunRecoveryFile(url: conflict.url).load() == nil, "Backup revived a cleared run")
print("PASS stale writer, busy lock and cleared-run protection")
