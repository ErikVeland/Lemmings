import Foundation
import Testing
@testable import NxlvKit

struct ZipArchiveTests {
    private static let packs = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Content/LevelPacks")

    private static func unzip(_ arguments: [String]) -> Data? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return nil }
        let out = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return process.terminationStatus == 0 ? out : nil
    }

    @Test func everyBundledPackDecodesLikeUnzip() throws {
        let files = try FileManager.default.contentsOfDirectory(at: Self.packs, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "zip" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        try #require(files.count > 500)
        var members = 0
        for file in files {
            let archive = try ZipArchive(contentsOf: file)
            let listing = try #require(Self.unzip(["-Z1", file.path]))
            let expected = String(decoding: listing, as: UTF8.self).split(separator: "\n")
                .map(String.init).filter { !$0.hasSuffix("/") }
            #expect(archive.names.sorted() == expected.sorted(), "\(file.lastPathComponent) member list")
            for member in archive.members where archive.members.filter({ $0.name == member.name }).count == 1 {
                let ours = try archive.contents(of: member)
                let literal = member.name.reduce(into: "") { result, character in
                    if "*?[]\\".contains(character) { result.append("\\") }
                    result.append(character)
                }
                // unzip prints nothing for an empty member and rejects the call.
                if member.uncompressedSize == 0 { #expect(ours.isEmpty); continue }
                let theirs = try #require(Self.unzip(["-p", file.path, literal]), "\(file.lastPathComponent) \(member.name)")
                #expect(ours == theirs, "\(file.lastPathComponent) \(member.name)")
                members += 1
            }
        }
        #expect(members > 1_000)
    }

    @Test func rejectsDamagedAndNonArchives() throws {
        #expect(throws: ZipArchiveError.self) { try ZipArchive(data: Data("not a zip".utf8)) }
        // A small deflated member keeps corruption coverage independent of bundled game data.
        var bytes = try #require(Data(base64Encoded:
            "UEsDBBQAAAAIAHW3TV2kcnBrLAAAAPwIAAAIAAAAdGVzdC50eHSL8gxQyMwrSU0vyiypVEjLrCgpLUrVU4gaFR4VHhUeFR4VHhUeFR4VHo7CAFBLAQIUAxQAAAAIAHW3TV2kcnBrLAAAAPwIAAAIAAAAAAAAAAAAAACAAQAAAAB0ZXN0LnR4dFBLBQYAAAAAAQABADYAAABSAAAAAAA="))
        let archive = try ZipArchive(data: bytes)
        let member = try #require(archive.members.first { $0.uncompressedSize > 0 && $0.method == 8 })
        // Flip a byte inside the packed data: the checksum or inflate must fail.
        let target = member.localHeaderOffset + 30 + member.name.utf8.count + 4
        bytes[target] ^= 0xFF
        let damaged = try ZipArchive(data: bytes)
        #expect(throws: ZipArchiveError.self) { try damaged.contents(of: member.name) }
    }
}
