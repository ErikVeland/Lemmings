import Foundation
import Darwin

func check(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
    guard try condition() else { fatalError(message) }
}
func rejects(_ body: () throws -> Void) throws {
    do { try body() } catch { return }
    fatalError("Expected rejection")
}
let writerMode = CommandLine.arguments.count == 3 && CommandLine.arguments[1] == "--write-loop"
let root = writerMode ? URL(fileURLWithPath: CommandLine.arguments[2])
    : FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
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

if writerMode {
    let file = RunRecoveryFile(url: root.appendingPathComponent("interrupted.json"))
    _ = try file.load()
    for tick in 0..<10_000 {
        let checkpoint = RunRecovery(engine: "test", profileID: "player", runID: recovery.runID,
            dataSetID: "lemmings", levelIndex: 0, levelFingerprint: "level", initialStateHash: "initial",
            tick: tick, events: [], stateHash: "state-\(tick)", usedRewind: false,
            nukeCount: 0, rewindCount: 0, undoCount: 0, selectedSkill: 0, scrollX: 0, scrollY: 0)
        try file.save(checkpoint)
        if tick == 0 { FileHandle.standardOutput.write(Data("READY".utf8)) }
    }
    exit(0)
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

var fanCheckpoint = recovery
fanCheckpoint = RunRecovery(engine: "test", profileID: "player", runID: UUID(), dataSetID: "fan-classic",
    levelIndex: 0, levelFingerprint: "level", initialStateHash: "initial", tick: 10, events: [],
    stateHash: "current", usedRewind: false, nukeCount: 0, rewindCount: 0, undoCount: 0,
    selectedSkill: 0, scrollX: 0, scrollY: 0)
fanCheckpoint.sourcePath = "/test.zip"
let validEntry = FanRunRecovery.Entry(file: "levels/test.lvl", section: nil, label: "Test")
fanCheckpoint.fan = FanRunRecovery(queue: [validEntry], index: 0)
_ = try fanCheckpoint.validated()
for invalid in [FanRunRecovery(queue: [], index: 0), .init(queue: [validEntry], index: 1),
                .init(queue: [.init(file: "../test.lvl", section: nil, label: "Test")], index: 0),
                .init(queue: [.init(file: "test.dat", section: -1, label: "Test")], index: 0)] {
    fanCheckpoint.fan = invalid
    try rejects { _ = try fanCheckpoint.validated() }
}
print("PASS fan checkpoint queue bounds and archive-member validation")

for trial in 0..<10 {
    let directory = root.appendingPathComponent("process-\(trial)")
    let process = Process()
    process.executableURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
    process.arguments = ["--write-loop", directory.path]
    let ready = Pipe(); process.standardOutput = ready
    try process.run()
    let signal = try ready.fileHandleForReading.read(upToCount: 5)
    try check(signal == Data("READY".utf8), "Checkpoint writer did not become ready")
    usleep(useconds_t(1000 + trial * 1300))
    try check(kill(process.processIdentifier, SIGKILL) == 0, "Could not interrupt test writer")
    process.waitUntilExit()
    try check(process.terminationReason == .uncaughtSignal && process.terminationStatus == SIGKILL,
        "Writer did not terminate abruptly")
    let checkpoint = try RunRecoveryFile(url: directory.appendingPathComponent("interrupted.json")).load()
    try check(checkpoint != nil && checkpoint!.stateHash == "state-\(checkpoint!.tick)",
        "Interrupted write left a torn or missing checkpoint")
}
print("PASS ten abrupt process terminations during checkpoint writes, with verified recovery")
