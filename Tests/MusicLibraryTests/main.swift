import Foundation
import NxlvKit

func check(_ value: Bool, _ message: String) throws {
    if !value { throw NSError(domain: "MusicLibraryTests", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
}

let root = URL(fileURLWithPath: CommandLine.arguments[1])
let data = try Data(contentsOf: root.appendingPathComponent("Resources/Music/libraries.json"))
let catalogue = try MusicLibraryCatalogue(data: data)
try check(catalogue.packs.count == 18, "The optional library index is incomplete")
let pack = catalogue.packs.first { $0.id == "demos" }!
let archive = root.appendingPathComponent(".build/music-libraries/1.6/demos.zip")
let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("music-libraries-" + UUID().uuidString)
try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)

Task {
    do {
        defer { try? FileManager.default.removeItem(at: temporary) }
        let installer = MusicLibraryInstaller()
        let installed = temporary.appendingPathComponent("Installed")
        try await installer.install(pack, archive: archive, to: installed)
        try check(MusicLibrary.isInstalled(pack, in: installed), "Verified pack did not become installed")
        try check(MusicLibrary.installedRoots(in: installed).count == 1, "Installed music was not discoverable")
        for file in pack.files {
            let hash = try MusicLibrary.hash(installed.appendingPathComponent(pack.id).appendingPathComponent(file.path))
            try check(hash == file.sha256, "Installed file differs from its manifest")
        }
        try await installer.install(pack, archive: archive, to: installed)
        try check(MusicLibrary.isInstalled(pack, in: installed), "Atomic replacement lost the installed pack")
        let corrupt = temporary.appendingPathComponent("corrupt.zip")
        var corruptData = try Data(contentsOf: archive); corruptData[0] ^= 1
        try corruptData.write(to: corrupt)
        var rejected = false
        do { try await installer.install(pack, archive: corrupt, to: installed) } catch { rejected = true }
        try check(rejected && MusicLibrary.isInstalled(pack, in: installed), "A corrupt update damaged the installed library")
        var payload = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        var packs = payload["packs"] as! [[String: Any]]
        var files = packs[0]["files"] as! [[String: Any]]
        for bad in ["../outside", "Music/../../outside", "Music/a/../b", "Music//b", "/absolute", "Music/a\\b"] {
            files[0]["path"] = bad; packs[0]["files"] = files; payload["packs"] = packs
            rejected = false
            do { _ = try MusicLibraryCatalogue(data: JSONSerialization.data(withJSONObject: payload)) } catch { rejected = true }
            try check(rejected, "Unsafe library path was accepted: \(bad)")
        }
        print("PASS complete index, verified installation, source hashes, atomic replacement and corrupt-update preservation")
        print("PASS unsafe path rejection and installed-library discovery")
        exit(0)
    } catch {
        FileHandle.standardError.write(Data("FAIL: \(error)\n".utf8)); exit(1)
    }
}
dispatchMain()
