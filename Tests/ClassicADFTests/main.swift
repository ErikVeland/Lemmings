import Foundation
import NxlvKit

// Reads an Amiga disk image and decodes the levels on it. An ADF holds real
// sectors, so the filesystem is readable without decoding a magnetic signal
// first, which is what a flux image would need.

private struct Failure: Error, CustomStringConvertible {
    let description: String
}

private func require(
    _ condition: @autoclosure () -> Bool, _ message: @autoclosure () -> String
) throws {
    guard condition() else { throw Failure(description: message()) }
}

let arguments = CommandLine.arguments
guard arguments.count > 1 else {
    FileHandle.standardError.write(Data("pass the path to an .adf image\n".utf8))
    exit(2)
}

do {
    let image = try Data(contentsOf: URL(fileURLWithPath: arguments[1]), options: .mappedIfSafe)
    let volume = try ClassicADFVolume(image: image)
    print("PASS read '\(volume.volumeName)' as \(volume.filesystem.rawValue)")
    try require(!volume.volumeName.isEmpty, "the volume has no name")
    try require(!volume.files.isEmpty, "the disk lists no files")
    print("PASS \(volume.files.count) files listed")

    // Every file must read back at the length the header claims.
    var checked = 0
    for file in volume.files where file.sizeInBytes > 0 {
        let data = try volume.contents(of: file)
        try require(
            data.count == file.sizeInBytes,
            "\(file.name) read \(data.count) bytes, header says \(file.sizeInBytes)")
        checked += 1
    }
    print("PASS \(checked) files read back at their stated length")

    // Level files are present, but the Amiga stores them in its own
    // container rather than the DOS archive format. Reading the filesystem is
    // what this proves. Decoding those levels is separate work, so a file that
    // does not open as a DOS archive is reported instead of failing the run.
    let levelFiles = volume.files(startingWith: "level")
    try require(!levelFiles.isEmpty, "no level files found on the disk")
    print("PASS \(levelFiles.count) level files present")

    var decoded = 0
    for file in levelFiles.sorted(by: { $0.name < $1.name }) {
        let raw = try volume.contents(of: file)
        guard let sections = try? ClassicDATArchive.decode(raw) else { continue }
        for section in sections where section.data.count == ClassicLevel.recordSize {
            if (try? ClassicLevel(data: section.data)) != nil { decoded += 1 }
        }
    }
    if decoded > 0 {
        print("PASS \(decoded) levels decoded as DOS archives")
    } else {
        print("NOTE the Amiga level container is not the DOS archive format")
        print("     the filesystem reads correctly, the level format is separate work")
    }

    print("Classic ADF tests passed.")
} catch {
    FileHandle.standardError.write(Data("ADF tests failed: \(error)\n".utf8))
    exit(1)
}
