import Foundation
import NxlvKit

// Reports the MAIN.DAT sections so the panel graphics can be located.

let directory = URL(
    fileURLWithPath: CommandLine.arguments.count > 1
        ? CommandLine.arguments[1] : "Content/lemming1.pc",
    isDirectory: true)

let files = try FileManager.default.contentsOfDirectory(
    at: directory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
guard let url = files.first(where: { $0.lastPathComponent.lowercased() == "main.dat" }) else {
    FileHandle.standardError.write(Data("MAIN.DAT not found\n".utf8))
    exit(1)
}

let sections = try ClassicDATArchive.decode(try Data(contentsOf: url))
print("MAIN.DAT: \(sections.count) sections")
for (index, section) in sections.enumerated() {
    let data = section.data
    let head = data.prefix(16).map { String(format: "%02x", $0) }.joined(separator: " ")
    let unique = Set(data.prefix(4096)).count
    print(String(
        format: "  [%d] %7d bytes  unique(4k)=%3d  %@",
        index, data.count, unique, head))
}

let assets = try ClassicMainDATAssets.load(from: directory)
print("")
print("decoded: \(assets.animations.count) animations, \(assets.countdownGlyphs.count) glyphs")
print("unsupported section indices: \(assets.unsupportedSectionIndices)")
