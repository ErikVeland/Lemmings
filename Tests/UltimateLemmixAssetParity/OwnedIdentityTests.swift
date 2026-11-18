import CryptoKit
import Darwin
import Foundation
import LemmingsAppCore
import LemmingsMobileCore
import NxlvKit

private enum IdentityCheckError: Error { case failed(String) }

@main struct OwnedIdentityTests {
    static func require(_ value: @autoclosure () throws -> Bool, _ message: String) throws {
        if try !value() { throw IdentityCheckError.failed(message) }
    }

    static func campaignDigest(_ campaign: ClassicCampaign) throws -> String {
        let rows = try campaign.levels.map { entry -> [String: Any] in
            var row = try JSONSerialization.jsonObject(with: JSONEncoder().encode(entry)) as! [String: Any]
            var level = row["level"] as! [String: Any]
            level["skills"] = ClassicSkill.allCases.map { [$0.rawValue, entry.level.skills[$0] ?? 0] as [Any] }
            row["level"] = level
            return row
        }
        return SHA256.hash(data: try JSONSerialization.data(withJSONObject: rows,
            options: [.sortedKeys, .withoutEscapingSlashes])).map { String(format: "%02x", $0) }.joined()
    }

    static func main() {
        do { try run() }
        catch { print("FAIL \(error)"); exit(1) }
    }

    static func run() throws {
        let output = URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent(UUID().uuidString)
        let source = URL(fileURLWithPath: "/Applications/Ultimate Lemmings.app/Contents/Resources/Ports")
        let imported = URL(fileURLWithPath: CommandLine.arguments[2]).appendingPathComponent("Contents/Resources/Ports")
        let nativeFixture = URL(fileURLWithPath: CommandLine.arguments[3])
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        var failures = 0
        func check(_ name: String, _ body: () throws -> Void) {
            do { try body(); print("PASS " + name) }
            catch { failures += 1; print("FAIL \(name): \(error)") }
        }
        func library(_ engine: String, _ root: URL, _ scope: String) throws -> any MobileGameLibrary {
            let storage = MobileStorage(directory: output.appendingPathComponent(scope))
            if engine == "l2" { return try Lemmings2MobileLibrary(directory: root, storage: storage) }
            return try Lemmings3MobileLibrary(directory: root, storage: storage)
        }
        for (engine, folder) in [("l2", "Lemm2"), ("l3", "LEM3CD")] {
            let payload = try Data(contentsOf: nativeFixture.appendingPathComponent("parity-mobile-\(engine)/parity-checkpoint.bin"))
            check(engine + " restores the native reference checkpoint after sanitised import") {
                let reference = try library(engine, source.appendingPathComponent(folder), engine + "-source").loadLevel(at: 0).session
                try reference.restoreCheckpointPayload(payload)
                let restored = try library(engine, imported.appendingPathComponent(folder), engine + "-owned").loadLevel(at: 0).session
                try restored.restoreCheckpointPayload(payload)
                try require(restored.snapshot == reference.snapshot, "restored state differs from the native reference")
                try require(restored.levelIdentifier == reference.levelIdentifier, "checkpoint level identity differs")
            }
            check(engine + " rejects a changed asset set") {
                let changed = output.appendingPathComponent(folder)
                try FileManager.default.copyItem(at: imported.appendingPathComponent(folder), to: changed)
                try Data("changed asset set".utf8).write(to: changed.appendingPathComponent("identity-change.txt"))
                let restored = try library(engine, changed, engine + "-changed").loadLevel(at: 0).session
                let raw = ClassicSourceRevision.directory(changed)!
                try require(OwnedContentIdentity.canonicalDirectoryRevision(raw: raw) == raw,
                    "changed desktop content acquired a canonical revision")
                do {
                    try restored.restoreCheckpointPayload(payload)
                    throw IdentityCheckError.failed("changed content accepted the reference checkpoint")
                } catch MobileSessionError.changedLevel { }
            }
            check(engine + " keeps the native desktop directory revision") {
                let reference = ClassicSourceRevision.directory(source.appendingPathComponent(folder))!
                let raw = ClassicSourceRevision.directory(imported.appendingPathComponent(folder))!
                try require(OwnedContentIdentity.canonicalDirectoryRevision(raw: raw) == reference,
                    "sanitised desktop directory lost its native revision")
                try require(OwnedContentIdentity.canonicalDirectoryRevision(raw: reference) == reference,
                    "original desktop directory revision changed")
            }
            print("DIRECTORY \(engine) source=\(ClassicSourceRevision.directory(source.appendingPathComponent(folder)) ?? "missing") owned=\(ClassicSourceRevision.directory(imported.appendingPathComponent(folder)) ?? "missing")")
        }
        for (name, root) in [("source", source), ("owned", imported)] {
            let dataSet = try PortExclusivePack.dataSet(amigaRoot: root.appendingPathComponent("amiga_extracted"), portsRoot: root)!
            print("OHYES \(name) campaign=\(try campaignDigest(dataSet.campaign)) scoped=\(ClassicSourceRevision.campaign(.ohYesMoreLemmings, root: root) ?? "missing")")
            check("Oh Yes \(name) keeps its canonical metadata identity") {
                let alias = ClassicSourceIdentity.canonicalAlias(for: dataSet, directory: root)
                try require(alias?.packID == "ohYesMoreLemmings-OHYES-60", "canonical Oh Yes pack ID missing")
                try require(alias?.sourceRevision == "fc020d72e88706953d4737e1b5fa09f5b653d7a70e4e1c1fa1cfa5546a24a908", "canonical Oh Yes revision differs")
            }
        }
        check("Oh Yes refuses modified stock assets") {
            let root = output.appendingPathComponent("OhYes")
            try FileManager.default.createDirectory(at: root.appendingPathComponent("amiga_extracted"), withIntermediateDirectories: true)
            for folder in ["amiga_extracted/lemmings", "amiga_extracted/ohno", "Genesis-Sunsoft",
                           "lemmings_dos_1991-07-30", "oh_no_more_lemmings_dos-1991-11-14_2232"] {
                try FileManager.default.copyItem(at: imported.appendingPathComponent(folder), to: root.appendingPathComponent(folder))
            }
            try Data("modified stock set".utf8).write(to: root.appendingPathComponent("Genesis-Sunsoft/identity-change.txt"))
            let dataSet = try PortExclusivePack.dataSet(amigaRoot: root.appendingPathComponent("amiga_extracted"), portsRoot: root)!
            try require(ClassicSourceIdentity.canonicalAlias(for: dataSet, directory: root) == nil, "modified assets acquired canonical metadata")
        }
        if failures > 0 { throw IdentityCheckError.failed("\(failures) identity checks failed") }
    }
}
