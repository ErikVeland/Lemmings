import CryptoKit
import Foundation
import Testing
@testable import NxlvKit

struct MusicLibraryInstallerTests {
    private struct Fixture {
        let directory: URL
        let archive: URL
        let pack: MusicLibraryCatalogue.Pack
    }

    private static func sha(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }

    private static func run(_ tool: String, _ arguments: [String], in directory: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        process.currentDirectoryURL = directory
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run(); process.waitUntilExit()
        #expect(process.terminationStatus == 0)
    }

    /// A pack with one large incompressible file, one compressible file and a stored file.
    private static func makeFixture(extra: Bool = false, symlink: Bool = false) throws -> Fixture {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("music-test-" + UUID().uuidString)
        let source = root.appendingPathComponent("source/Music/Remix")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        let big = Data((0..<6_000_000).map { _ in UInt8.random(in: 0...255) })
        let text = Data(String(repeating: "pixel lemmings ", count: 40_000).utf8)
        try big.write(to: source.appendingPathComponent("big.bin"))
        try text.write(to: source.appendingPathComponent("text.txt"))
        try Data("x".utf8).write(to: source.deletingLastPathComponent().appendingPathComponent("tiny.txt"))
        if extra { try Data("surprise".utf8).write(to: source.appendingPathComponent("extra.txt")) }
        if symlink { try FileManager.default.createSymbolicLink(
            at: source.appendingPathComponent("link.txt"), withDestinationURL: URL(fileURLWithPath: "/etc/hosts")) }
        let archive = root.appendingPathComponent("pack.zip")
        try run("/usr/bin/zip", ["-q", "-X", "-y", "-r", archive.path, "Music"], in: root.appendingPathComponent("source"))
        let files: [(String, Data)] = [("Music/Remix/big.bin", big), ("Music/Remix/text.txt", text), ("Music/tiny.txt", Data("x".utf8))]
        let list = files.map { #"{"path":"\#($0.0)","bytes":\#($0.1.count),"sha256":"\#(sha($0.1))"}"# }.joined(separator: ",")
        let bytes = try Data(contentsOf: archive)
        let json = #"{"id":"test","title":"Test","url":"https://example.com/test.zip","bytes":\#(bytes.count),"sha256":"\#(sha(bytes))","trackCount":1,"files":[\#(list)]}"#
        return Fixture(directory: root, archive: archive,
                       pack: try JSONDecoder().decode(MusicLibraryCatalogue.Pack.self, from: Data(json.utf8)))
    }

    @Test func installsVerifiesAndReplaces() async throws {
        let fixture = try Self.makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let target = fixture.directory.appendingPathComponent("libraries")
        let installer = MusicLibraryInstaller()
        try await installer.install(fixture.pack, archive: fixture.archive, to: target, validate: { _ in true })
        #expect(MusicLibraryStore.isInstalled(fixture.pack, in: target))
        #expect(MusicLibraryStore.installedRoots(in: target).count == 1)
        // Installing again replaces in place.
        try await installer.install(fixture.pack, archive: fixture.archive, to: target, validate: { _ in true })
        #expect(MusicLibraryStore.isInstalled(fixture.pack, in: target))
        try MusicLibraryStore.remove(fixture.pack, in: target)
        #expect(!MusicLibraryStore.isInstalled(fixture.pack, in: target))
    }

    @Test func rejectsTamperedAndUnexpectedArchives() async throws {
        let installer = MusicLibraryInstaller()
        let good = try Self.makeFixture()
        defer { try? FileManager.default.removeItem(at: good.directory) }
        var bytes = try Data(contentsOf: good.archive)
        bytes[bytes.count / 2] ^= 0xFF
        let damaged = good.directory.appendingPathComponent("damaged.zip")
        try bytes.write(to: damaged)
        await #expect(throws: MusicLibraryInstaller.Failure.self) {
            try await installer.install(good.pack, archive: damaged, to: good.directory.appendingPathComponent("a"), validate: { _ in true })
        }
        for extra in [true, false] {
            let bad = try Self.makeFixture(extra: extra, symlink: !extra)
            defer { try? FileManager.default.removeItem(at: bad.directory) }
            // The catalogue lists three files; the archive holds a fourth.
            await #expect(throws: MusicLibraryInstaller.Failure.self) {
                try await installer.install(bad.pack, archive: bad.archive, to: bad.directory.appendingPathComponent("b"), validate: { _ in true })
            }
        }
        // A failed validation leaves nothing installed.
        let target = good.directory.appendingPathComponent("c")
        await #expect(throws: MusicLibraryInstaller.Failure.self) {
            try await installer.install(good.pack, archive: good.archive, to: target, validate: { _ in false })
        }
        #expect(!MusicLibraryStore.isInstalled(good.pack, in: target))
    }
}
