import Foundation
import Darwin
import NxlvKit

struct TestFailure: Error { let message: String }
func check(_ condition: Bool, _ message: String) throws {
    if !condition { throw TestFailure(message: message) }
}
func rejects(_ message: String, _ operation: () throws -> Void) throws {
    do { try operation() } catch { return }
    throw TestFailure(message: message)
}
let root = FileManager.default.temporaryDirectory.appendingPathComponent("LemmingsSaveTests-\(UUID().uuidString)")
try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: root) }

func testBackups() throws {
    let url = root.appendingPathComponent("records.json")
    let file = ArcadeRecordFile(url: url)
    try check(try file.load() == nil, "New player unexpectedly has records")
    let first = ArcadeRecords()
    try file.save(first)
    let firstData = try Data(contentsOf: url)
    try check(try Data(contentsOf: file.backupURL) == firstData, "First save has no recovery copy")
    var second = first
    _ = second.addProfile(initials: "NEW", portrait: 2)
    try file.save(second)
    try check(try Data(contentsOf: file.backupURL) == firstData, "Backup did not retain the prior good version")
    let broken = Data("unreadable records".utf8)
    try broken.write(to: url)
    let restored = ArcadeRecordFile(url: url)
    try check(try restored.load() == first, "Corrupt primary did not recover a validated backup")
    try check(restored.recovered, "Recovery was not reported")
    try check(try Data(contentsOf: restored.preservedURL!) == broken, "Unreadable primary was discarded")
    try restored.save(second)
    try check(try ArcadeRecordFile(url: url).load() == second, "Recovered records cannot be saved again")
    try FileManager.default.removeItem(at: url)
    let missing = ArcadeRecordFile(url: url)
    try check(try missing.load() == first && missing.recovered && missing.preservedURL == nil, "Missing primary did not recover")
    print("PASS initial backup, previous generation, corruption preservation, recovery and subsequent saves")
}

func testUnknownAndBrokenFiles() throws {
    let url = root.appendingPathComponent("unknown.json")
    let file = ArcadeRecordFile(url: url)
    _ = try file.load()
    try file.save(ArcadeRecords())
    let backup = try Data(contentsOf: file.backupURL)
    for version in ["3", "0", "9999999999999999999999999999999999", "\"future\""] {
        let future = Data("{\"version\":\(version)}".utf8)
        try future.write(to: url)
        let reader = ArcadeRecordFile(url: url)
        try rejects("Unsupported version was replaced with an old backup") { _ = try reader.load() }
        try check(try Data(contentsOf: url) == future && Data(contentsOf: file.backupURL) == backup,
                  "Unsupported records or backup changed")
    }
    try Data("bad primary".utf8).write(to: url)
    try Data("bad backup".utf8).write(to: file.backupURL)
    try rejects("Two corrupt files loaded") { _ = try ArcadeRecordFile(url: url).load() }
    try check(try Data(contentsOf: url) == Data("bad primary".utf8), "Failed recovery overwrote the primary")
    try FileManager.default.removeItem(at: file.backupURL)
    try rejects("Corrupt primary without backup loaded") { _ = try ArcadeRecordFile(url: url).load() }
    print("PASS unsupported versions, invalid backups and unreadable-file preservation")
}

func testWriteFailuresAndConflicts() throws {
    let url = root.appendingPathComponent("conflicts.json")
    let writer = ArcadeRecordFile(url: url)
    _ = try writer.load()
    let first = ArcadeRecords()
    try writer.save(first)
    let stale = ArcadeRecordFile(url: url)
    _ = try stale.load()
    var second = first
    _ = second.addProfile(initials: "TWO", portrait: 1)
    try writer.save(second)
    let descriptor = open(url.appendingPathExtension("lock").path, O_RDWR)
    try check(descriptor >= 0 && flock(descriptor, LOCK_EX | LOCK_NB) == 0, "Cannot hold fixture save lock")
    do {
        defer { flock(descriptor, LOCK_UN); close(descriptor) }
        try rejects("Save ignored another writer's lock") { try writer.save(first) }
    }
    let current = try Data(contentsOf: url)
    let backup = try Data(contentsOf: writer.backupURL)
    try rejects("A stale app overwrote newer records") { try stale.save(first) }
    try check(try Data(contentsOf: url) == current && Data(contentsOf: writer.backupURL) == backup,
              "Conflict changed a saved file")
    try FileManager.default.removeItem(at: writer.backupURL)
    try FileManager.default.createDirectory(at: writer.backupURL, withIntermediateDirectories: false)
    try rejects("Failed backup was ignored") { try writer.save(first) }
    try check(try Data(contentsOf: url) == current, "Backup failure damaged the primary")
    try FileManager.default.removeItem(at: writer.backupURL)
    try writer.save(first)
    try check(try ArcadeRecordFile(url: url).load() == first, "Failed save left the lock or state unusable")
    print("PASS stale-writer rejection, backup failure, primary preservation and retry")
}

func testMigration() throws {
    let suite = "SaveMigrationTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    defaults.set(false, forKey: "AudioMuted")
    defaults.register(defaults: ["ClassicSettings": Data("registered defaults".utf8)])
    let currentID = LegacySaveMigration.currentIdentifier
    let profileKey = "ArcadeProfile.player-two.ClassicGameProgress.lemmings"
    let sources: [String: [String: Any]] = [
        LegacySaveMigration.previousIdentifier: [
            "AudioMuted": true, "ClassicSettings": Data("saved preferences".utf8),
            "SequelMacArtworkEnabledV2": false, "HDEffectsChoiceV1": true, "FanLevelsPassed": ["pack/level"],
            "ClassicGameProgress.lemmings": Data("classic progress".utf8),
            "nativeL2Campaign.v1.bundled": Data("unified progress".utf8),
            profileKey: Data("profile progress".utf8), "UnrelatedPreference": "skip"
        ],
        "org.lemmingslocal.NativeL2": [
            "nativeL2Campaign.v1.bundled": Data("older standalone progress".utf8),
            "nativeL2Campaign.v1./external/path": "skip",
            "nativeL2Campaign.v1.bundled.slot.3": Data("manual save".utf8),
            "nativeL2Campaign.v1.bundled.soundsMuted": false,
            "nativeL2Campaign.v1.bundled.slot.99": "skip"
        ],
        "org.lemmingslocal.NativeL3Preview": ["nativeL3ClassicPreview.v1.bundled": Data("L3 progress".utf8)]
    ]
    let reader: (String) -> [String: Any] = { name in
        name == currentID ? defaults.persistentDomain(forName: suite) ?? [:] : sources[name] ?? [:]
    }
    for identifier in [nil, "academy.glasscode.lemmings.integration-tests.arm64", "org.lemmingslocal.NativeL2"] {
        try check(LegacySaveMigration.migrate(bundleIdentifier: identifier, defaults: defaults, readDomain: reader) == 0,
                  "A non-production app imported personal saves")
    }
    try check(defaults.object(forKey: LegacySaveMigration.marker) == nil, "Skipped migration wrote a marker")
    try check(LegacySaveMigration.migrate(bundleIdentifier: currentID, defaults: defaults, readDomain: reader) == 10, "Wrong migration count")
    try check(!defaults.bool(forKey: "AudioMuted"), "Migration overwrote an explicit false choice")
    try check(defaults.data(forKey: "ClassicSettings") == Data("saved preferences".utf8), "Registered defaults blocked older saved choices")
    try check(defaults.data(forKey: "nativeL2Campaign.v1.bundled") == Data("unified progress".utf8), "Standalone progress replaced unified progress")
    try check(defaults.data(forKey: profileKey) == Data("profile progress".utf8), "Profile namespace was lost")
    try check(defaults.object(forKey: "UnrelatedPreference") == nil && defaults.object(forKey: "nativeL2Campaign.v1./external/path") == nil,
              "Migration copied unsupported preferences")
    try check(defaults.object(forKey: "SequelMacArtworkEnabledV2") as? Bool == false
              && defaults.bool(forKey: "HDEffectsChoiceV1")
              && defaults.stringArray(forKey: "FanLevelsPassed") == ["pack/level"], "Migration lost artwork, first-launch choice or fan progress")
    try check(defaults.data(forKey: "nativeL2Campaign.v1.bundled.slot.3") == Data("manual save".utf8)
              && defaults.object(forKey: "nativeL2Campaign.v1.bundled.soundsMuted") as? Bool == false
              && defaults.object(forKey: "nativeL2Campaign.v1.bundled.slot.99") == nil, "Manual slots or standalone sound choices were lost")
    defaults.removeObject(forKey: "ClassicGameProgress.lemmings")
    try check(LegacySaveMigration.migrate(bundleIdentifier: currentID, defaults: defaults, readDomain: reader) == 0
              && defaults.object(forKey: "ClassicGameProgress.lemmings") == nil, "Migration resurrected reset progress")
    let info = try PropertyListSerialization.propertyList(from: Data(contentsOf: URL(fileURLWithPath: "Resources/Info.plist")), format: nil) as! [String: Any]
    try check(info["CFBundleIdentifier"] as? String == currentID, "Migration does not accept the shipping app identifier")
    print("PASS shipping identifier, domain priority, profile isolation, explicit choices, registered defaults and one-time migration")
}

do {
    try testBackups()
    try testUnknownAndBrokenFiles()
    try testWriteFailuresAndConflicts()
    try testMigration()
    print("Save recovery tests passed.")
} catch { print("FAIL: \(error)"); exit(1) }
