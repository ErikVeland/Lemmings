import Foundation
import CryptoKit

private struct ExportError: Error { let message: String }
private func require(_ value: Bool, _ message: String) throws {
    if !value { throw ExportError(message: message) }
}
private func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
private func run() throws {
    let arguments = Array(CommandLine.arguments.dropFirst())
    func value(_ name: String) throws -> URL {
        guard let index = arguments.firstIndex(of: name), arguments.indices.contains(index + 1) else {
            throw ExportError(message: "Supply --font, --licence and --output.")
        }
        return URL(fileURLWithPath: arguments[index + 1])
    }
    let source = try value("--font"), licence = try value("--licence"), output = try value("--output")
    let data = try Data(contentsOf: source), notice = try Data(contentsOf: licence)
    try require(digest(data) == "5cde0409cd6f6dff89fefb5349c90b92b62fd27de0fe3a577fb4036d5eeb4f71", "The Lix font differs from its pinned source.")
    try require(digest(notice) == "6b07a2a6b192d39baeca18f3491d7c25a1999ba11384588e0ed0f063a856bfb8", "The full Lix font notice differs from its pinned source.")
    let font = try LixInterfaceText(data: data)
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    func glyph(_ character: String, size: Int, width: Int, height: Int, black: Bool = false) throws -> Data {
        guard let frame = font.frame(character, pixelSize: size, red: black ? 0 : 48,
            green: black ? 0 : 128, blue: black ? 0 : 208) else { throw ExportError(message: "The Lix typeface does not cover a required glyph.") }
        let dx = Int(floor(Double(width - frame.width) / 2)), dy = Int(floor(Double(height - frame.height) / 2))
        var pixels = Data(repeating: 0, count: width * height * 4)
        for y in 0..<frame.height { for x in 0..<frame.width {
            let offset = (y * frame.width + x) * 4
            guard frame.rgba[offset + 3] != 0 else { continue }
            let tx = x + dx, ty = y + dy
            try require((0..<width).contains(tx) && (0..<height).contains(ty), "The authored Lix glyph exceeds its fixed interface cell.")
            let target = (ty * width + tx) * 4
            pixels.replaceSubrange(target..<(target + 4), with: frame.rgba[offset..<(offset + 4)])
        } }
        return pixels
    }
    var banks: [String: [Any]] = [:], names: [String: String] = [:], hashes: [String: String] = [:]
    func record(_ name: String, _ pixels: Data, width: Int, height: Int) throws -> [String: Any] {
        try pixels.write(to: output.appendingPathComponent(name), options: .atomic)
        hashes[name] = digest(pixels)
        return ["x": 0, "y": 0, "width": width, "height": height, "file": name]
    }
    for (bank, face, size, width, height) in [("1", "Charset1", 12, 12, 18), ("2", "Charset2", 16, 16, 20)] {
        var frames: [Any] = [NSNull()]
        for scalar in 33...126 {
            let pixels = try glyph(String(Unicode.Scalar(scalar)!), size: size, width: width, height: height)
            frames.append(try record("\(face)-\(scalar).rgba", pixels, width: width, height: height))
        }
        frames.append(NSNull())
        for digit in 0...9 {
            let pixels = try glyph(String(digit), size: 8, width: 6, height: 9, black: true)
            frames.append(try record("\(face)-digit-\(digit).rgba", pixels, width: 6, height: 9))
        }
        frames.append(try record("\(face)-digit-blank.rgba", Data(repeating: 0, count: 6 * 9 * 4), width: 6, height: 9))
        banks[bank] = frames; names[bank] = face
    }
    let manifest: [String: Any] = ["version": 1, "monochrome": false, "names": names, "banks": banks, "objects": [:]]
    try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
        .write(to: output.appendingPathComponent("manifest.json"), options: .atomic)
    try notice.write(to: output.appendingPathComponent("FONT-LICENSE.txt"), options: .atomic)
    let provenance: [String: Any] = ["schemaVersion": 1, "sourceFontSHA256": digest(data),
        "sourceTypeface": "DejaVuSansCondensed-Bold", "licence": "Bitstream-Vera AND LicenseRef-Arev-Fonts",
        "originalGameAssets": false, "method": "Actual pinned Lix font glyphs rasterised by CoreText without antialiasing; fixed interface cells and counter glyphs.", "files": hashes]
    try JSONSerialization.data(withJSONObject: provenance, options: [.prettyPrinted, .sortedKeys])
        .write(to: output.appendingPathComponent("provenance.json"), options: .atomic)
    print("Prepared licensed Lix interface: 12x18 and 16x20 glyphs plus 6x9 digits; no original game images.")
}
do { try run() }
catch { FileHandle.standardError.write(Data(("\(error)\n").utf8)); exit(1) }
