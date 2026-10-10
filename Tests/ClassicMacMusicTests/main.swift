import Foundation
import NxlvKit

private struct Failure: Error { let message: String }
private func require(_ value: @autoclosure () -> Bool, _ message: String) throws {
    if !value() { throw Failure(message: message) }
}

do {
    let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? ".build/mac-music-export", isDirectory: true)
    guard let bank = ClassicMacMusicLibrary(root: root) else { throw Failure(message: "Prepare the Macintosh music bank first") }
    try require(bank.songCount == 31, "Incomplete native bank")
    for (index, name) in LevelMusicSelection.classic.enumerated() {
        try require(bank.track(index: index, levelTitle: "Ordinary level", title: .lemmings)?.lastPathComponent == name + ".m4a",
            "Classic composition mismatch at \(index)")
    }
    for index in 0..<6 {
        try require(bank.track(index: index, levelTitle: "Ordinary level", title: .ohNoMoreLemmings)?.lastPathComponent == "tune\(index + 1).m4a",
            "Oh No! composition mismatch at \(index)")
    }
    for (title, name) in [("What an AWESOME level", "awesome"), ("A Beast of a level", "beasti"),
        ("A Beast II of a level", "beastii"), ("A MENACING level", "menace")] {
        try require(bank.track(index: 0, levelTitle: title, title: .lemmings)?.lastPathComponent == name + ".m4a", "Special theme mismatch")
    }
    for title in [ClassicTitle.xmasLemmings1991, .xmasLemmings1992, .holidayLemmings1993, .holidayLemmings1994] {
        for (index, name) in ClassicMacMusicLibrary.seasonal.enumerated() {
            try require(bank.track(index: index, levelTitle: "Ordinary level", title: title)?.lastPathComponent == name + ".m4a", "Mac seasonal score mismatch")
        }
    }
    try require(bank.track(index: 0, levelTitle: "Professor Mariarti", title: .lemmings) == nil, "Unrelated native tune substituted for a missing exclusive theme")
    let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("mac-music-bank-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporary) }
    for family in ["classic", "ohno", "xmas"] {
        try FileManager.default.createSymbolicLink(at: temporary.appendingPathComponent(family),
            withDestinationURL: root.appendingPathComponent(family).standardizedFileURL)
    }
    let data = try Data(contentsOf: root.appendingPathComponent("manifest.json"))
    let manifest = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    let path = temporary.appendingPathComponent("manifest.json")
    try data.write(to: path)
    try require(ClassicMacMusicLibrary(root: temporary) != nil, "Valid native bank was rejected")
    for variant in 0..<4 {
        var changed = manifest
        var songs = changed["songs"] as! [[String: Any]]
        switch variant {
        case 0: changed["version"] = 2
        case 1: songs.removeLast()
        case 2: songs[0]["path"] = "../outside.m4a"
        default: songs[0]["frames"] = 0
        }
        changed["songs"] = songs
        try JSONSerialization.data(withJSONObject: changed).write(to: path)
        try require(ClassicMacMusicLibrary(root: temporary) == nil, "Invalid bank was offered: \(variant)")
    }
    print("PASS all 31 native composition selections, four seasonal campaigns, exclusive fallback and invalid/incomplete bank rejection")
} catch {
    FileHandle.standardError.write(Data("FAIL Macintosh music tests: \(error)\n".utf8)); exit(1)
}
