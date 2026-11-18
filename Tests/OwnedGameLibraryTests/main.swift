import Foundation
import NxlvKit

struct CheckFailure: Error, CustomStringConvertible {
    let description: String
}

func check(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
    if try !condition() { throw CheckFailure(description: message) }
}

let validator: BYOContentValidator = { directory, game in
    let bytes = try Data(contentsOf: directory.appendingPathComponent("MAIN.DAT"))
    guard String(decoding: bytes, as: UTF8.self).hasPrefix("VALID-") else {
        throw CheckFailure(description: "Rejected synthetic game data")
    }
}

#if OWNED_LIBRARY_AVAILABLE
typealias Library = OwnedGameLibrary
#else
// Characterises the previous single-install behaviour before the new library exists.
struct Library {
    let integration: BYOIntegration
    init(root: URL, validator: @escaping BYOContentValidator) {
        integration = BYOIntegration(root: root, validator: validator)
    }
    func directories(for game: BYOGame) -> [URL] { [integration.installedDirectory(for: game)].compactMap { $0 } }
    func install(directory: URL, game: BYOGame) throws -> BYOInstalledContent {
        try integration.install(directory: directory, game: game)
    }
}
#endif

func fixture(_ root: URL, name: String, bytes: String) throws -> URL {
    let directory = root.appendingPathComponent(name)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try Data(bytes.utf8).write(to: directory.appendingPathComponent("MAIN.DAT"))
    return directory
}

func payload(_ directory: URL) throws -> String {
    try String(contentsOf: directory.appendingPathComponent("MAIN.DAT"), encoding: .utf8)
}

func run() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("OwnedLibrary-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let first = try fixture(root, name: "first", bytes: "VALID-A")
    let second = try fixture(root, name: "second", bytes: "VALID-B")
    let duplicate = try fixture(root, name: "another-name", bytes: "VALID-A")
    let invalid = try fixture(root, name: "invalid", bytes: "BROKEN")
    let libraryRoot = root.appendingPathComponent("owned")
    let library = Library(root: libraryRoot, validator: validator)
    let a = try library.install(directory: first, game: .classic)
    let b = try library.install(directory: second, game: .classic)
    let all = library.directories(for: .classic)
    try check(all.count == 2, "Two distinct Classic imports must remain installed; found \(all.count)")
    let values = try Set(all.map(payload))
    try check(values == Set(["VALID-A", "VALID-B"]), "A later import replaced an earlier game")
    let again = try library.install(directory: duplicate, game: .classic)
    try check(again.directory == a.directory, "Identical bytes from another folder did not reuse their installation")
    try check(library.directories(for: .classic).count == 2, "A duplicate import created an extra installation")
    do {
        _ = try library.install(directory: invalid, game: .classic)
        throw CheckFailure(description: "Invalid import unexpectedly succeeded")
    } catch let error as CheckFailure where error.description == "Invalid import unexpectedly succeeded" {
        throw error
    } catch { }
    try check(try payload(a.directory) == "VALID-A", "A failed import changed the first installation")
    try check(try payload(b.directory) == "VALID-B", "A failed import changed the second installation")

    let legacyRoot = root.appendingPathComponent("legacy")
    let legacy = BYOIntegration(root: legacyRoot, validator: validator)
    let old = try legacy.install(directory: first, game: .classic)
    let upgraded = Library(root: legacyRoot, validator: validator)
    _ = try upgraded.install(directory: second, game: .classic)
    try check(upgraded.directories(for: .classic).count == 2, "Legacy single imports disappeared after upgrade")
    try check(upgraded.directories(for: .classic).first == old.directory, "Legacy default location changed")
    let oldAgain = try upgraded.install(directory: duplicate, game: .classic)
    try check(oldAgain.directory == old.directory, "A legacy duplicate created another installation")

    try Data("CHANGED".utf8).write(to: a.directory.appendingPathComponent("MAIN.DAT"))
    let repaired = try library.install(directory: first, game: .classic)
    try check(repaired.directory == a.directory, "Repair changed a content-addressed installation identity")
    try check(try payload(repaired.directory) == "VALID-A", "Reimport did not repair changed bytes")
    try check(try payload(b.directory) == "VALID-B", "Repair changed an unrelated installation")
    let malformed = libraryRoot.appendingPathComponent("Installations/" + String(repeating: "0", count: 64))
    try FileManager.default.createDirectory(at: malformed.appendingPathComponent("classic"), withIntermediateDirectories: true)
    try Data("{}".utf8).write(to: malformed.appendingPathComponent("classic/" + BYOIntegration.manifestName))
    let linked = libraryRoot.appendingPathComponent("Installations/" + String(repeating: "f", count: 64))
    try FileManager.default.createSymbolicLink(at: linked, withDestinationURL: first)
    try check(library.directories(for: .classic).count == 2, "Malformed or linked entries entered the installed library")
    let sourceLink = root.appendingPathComponent("source-link")
    try FileManager.default.createSymbolicLink(at: sourceLink, withDestinationURL: first)
    do {
        _ = try library.install(directory: sourceLink, game: .classic)
        throw CheckFailure(description: "Linked import unexpectedly succeeded")
    } catch let error as CheckFailure where error.description == "Linked import unexpectedly succeeded" {
        throw error
    } catch { }
    try check(library.directories(for: .classic).count == 2, "A linked import changed installed entries")
    print("PASS two Classic installs, duplicate reuse, rejection preservation, legacy compatibility, repair and unsafe-entry rejection")

    if let path = ProcessInfo.processInfo.environment["LEMMIX_TEST_REAL_PORTS_ROOT"] {
        let sources = URL(fileURLWithPath: path, isDirectory: true)
        let real = OwnedGameLibrary(root: root.appendingPathComponent("real-owned"))
        let classic = try real.install(directory: sources.appendingPathComponent("lemmings_dos_1991-07-30"), game: .classic)
        let ohno = try real.install(directory: sources.appendingPathComponent("oh_no_more_lemmings_dos-1991-11-14_2232"), game: .classic)
        try check(real.directories(for: .classic).count == 2, "Native-reader validation did not retain both real Classic releases")
        try check(classic.directory != ohno.directory, "Real Classic releases share an import identity")
        for directory in real.directories(for: .classic) {
            try BYOIntegration.validateGame(directory: directory, game: .classic)
        }
        print("PASS native-reader import and independent enumeration of real Classic and Oh No releases")
    }
}

do { try run() }
catch {
    FileHandle.standardError.write(Data(("FAIL: \(error)\n").utf8))
    exit(1)
}
