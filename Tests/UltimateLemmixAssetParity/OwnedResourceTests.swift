import Foundation
import LemmingsAppCore
import Darwin

private enum CheckError: Error { case failed(String), rejected }

@main struct OwnedResourceTests {
    static func require(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
        if try !condition() { throw CheckError.failed(message) }
    }

    static func write(_ text: String, _ url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: url)
    }

    static func fixture(_ name: String) throws -> (URL, URL, URL) {
        let root = URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent(name + "-" + UUID().uuidString)
        let base = root.appendingPathComponent("Base")
        let source = root.appendingPathComponent("Source")
        try write("base", base.appendingPathComponent("Hints/current.json"))
        try write("owned", source.appendingPathComponent("Sounds/effect.dat"))
        return (root.appendingPathComponent("Library"), base, source)
    }

    static func library(_ root: URL, _ base: URL) -> OwnedResourceLibrary {
        OwnedResourceLibrary(root: root, bundledResources: base, validator: { _ in })
    }

    static func synthetic() throws {
        var failures = 0
        func check(_ name: String, _ body: () throws -> Void) {
            do { try body(); print("PASS " + name) }
            catch { failures += 1; print("FAIL \(name): \(error)") }
        }
        check("detached resources omit source drivers without rejecting data") {
            let (root, base, source) = try fixture("detached")
            try write("driver", source.appendingPathComponent("Ports/Lemm2/MUSIC/ADLIB.BIN"))
            let receipt = try library(root, base).install(directory: source)
            try require(receipt.omittedSourceFiles == ["Ports/Lemm2/MUSIC/ADLIB.BIN"], "driver omission missing")
            try require(receipt.fileCount == 1, "data file was omitted")
            let app = source.deletingLastPathComponent().appendingPathComponent("Preservation.app")
            let resources = app.appendingPathComponent("Contents/Resources")
            try FileManager.default.createDirectory(at: resources.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: source, to: resources)
            let appReceipt = try library(root.appendingPathComponent("AppImport"), base).install(directory: app)
            try require(appReceipt.contentID == receipt.contentID, "app and detached data identities differ")
        }
        for missing in [false, true] {
            check("complete reimport repairs " + (missing ? "missing" : "corrupt") + " owned data at the same content ID") {
                let (root, base, source) = try fixture("repair")
                let store = library(root, base)
                let first = try store.install(directory: source)
                let target = first.resourcesDirectory.appendingPathComponent("Sounds/effect.dat")
                if missing { try FileManager.default.removeItem(at: target) }
                else { try write("wrong", target) }
                let repaired = try store.install(directory: source)
                try require(repaired.contentID == first.contentID, "repair changed content identity")
                try require(try String(contentsOf: target, encoding: .utf8) == "owned", "data was not repaired")
                _ = try store.verifyInstalled()
            }
        }
        check("cold restore rejects corrupt data when the base is unchanged") {
            let (root, base, source) = try fixture("cold-corrupt")
            let first = try library(root, base).install(directory: source)
            try write("wrong", first.resourcesDirectory.appendingPathComponent("Sounds/effect.dat"))
            do {
                _ = try library(root, base).refreshBaseIfNeeded()
                throw CheckError.failed("cold restore accepted corrupt data")
            } catch BYOIntegrationError.invalidManifest { }
        }
        check("cold restore reports a damaged activation manifest") {
            let (root, base, source) = try fixture("cold-manifest")
            _ = try library(root, base).install(directory: source)
            try write("damaged", root.appendingPathComponent(".active-resource-bundle.json"))
            do {
                _ = try library(root, base).refreshBaseIfNeeded()
                throw CheckError.failed("cold restore silently ignored damaged activation")
            } catch BYOIntegrationError.invalidManifest { }
        }
        check("failed replacement retains the valid active receipt") {
            let (root, base, source) = try fixture("failed-replacement")
            let first = try library(root, base).install(directory: source)
            try write("new", source.appendingPathComponent("Sounds/effect.dat"))
            let rejecting = OwnedResourceLibrary(root: root, bundledResources: base, validator: { _ in throw CheckError.rejected })
            do {
                _ = try rejecting.install(directory: source)
                throw CheckError.failed("replacement unexpectedly passed")
            } catch CheckError.rejected { }
            let current = try library(root, base).verifyInstalled()
            try require(current?.contentID == first.contentID, "failed replacement changed activation")
        }
        check("base refresh retains owned bytes across cold restoration") {
            let (root, base, source) = try fixture("rebase")
            let first = try library(root, base).install(directory: source)
            try write("new-base", base.appendingPathComponent("Hints/current.json"))
            let refreshed = try library(root, base).refreshBaseIfNeeded()
            try require(refreshed?.contentID != first.contentID, "base change did not create a version")
            let current = try library(root, base).verifyInstalled()
            try require(current?.contentID == refreshed?.contentID, "cold restore lost activation")
            try require(try String(contentsOf: current!.resourcesDirectory.appendingPathComponent("Sounds/effect.dat"), encoding: .utf8) == "owned", "base refresh lost owned data")
        }
        if failures > 0 { throw CheckError.failed("\(failures) importer checks failed") }
    }

    static func realSource() throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1])
        let base = URL(fileURLWithPath: CommandLine.arguments[3])
        let source = URL(fileURLWithPath: CommandLine.arguments[4])
        let start = Date()
        let store = OwnedResourceLibrary(root: root, bundledResources: base)
        let installed = try store.install(directory: source)
        print("REAL importSeconds=\(Date().timeIntervalSince(start))")
        print("REAL bundleURL=\(installed.bundleURL.path)")
        fflush(nil)
        let verification = Date()
        let cold = OwnedResourceLibrary(root: root, bundledResources: base)
        let verified = try cold.verifyInstalled()
        let restored = try cold.refreshBaseIfNeeded()
        try require(verified?.contentID == installed.contentID && restored?.contentID == installed.contentID, "cold restoration changed identity")
        print("REAL verifyAndColdRestoreSeconds=\(Date().timeIntervalSince(verification))")
        let rebase = Date()
        let nextBase = root.deletingLastPathComponent().appendingPathComponent("RebaseResources-" + UUID().uuidString)
        try FileManager.default.copyItem(at: base, to: nextBase)
        try write("isolated trusted metadata rebase", nextBase.appendingPathComponent("Hints/importer-parity-rebase.json"))
        let updated = OwnedResourceLibrary(root: root, bundledResources: nextBase)
        let rebased = try updated.refreshBaseIfNeeded()
        try require(rebased?.contentID != installed.contentID, "real base refresh kept the old version")
        _ = try updated.verifyInstalled()
        let final = try cold.refreshBaseIfNeeded()
        try require(final?.contentID == installed.contentID, "restoring the actual base changed original identity")
        _ = try cold.verifyInstalled()
        print("REAL rebaseAndRestoreSeconds=\(Date().timeIntervalSince(rebase))")
        print("REAL contentID=\(installed.contentID) files=\(installed.fileCount) bytes=\(installed.bytes) omissions=\(installed.omittedSourceFiles.count)")
    }

    static func main() {
        do {
            if CommandLine.arguments.count > 2 && CommandLine.arguments[2] == "real" { try realSource() }
            else { try synthetic() }
        } catch {
            print("FAIL \(error)")
            exit(1)
        }
    }
}
