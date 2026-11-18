import Foundation
import CryptoKit

/**
 * Recovers exact cursor resources from a selected local app without executing it.
 */
enum NativeCursorRecovery: Sendable {
    enum RecoveryError: Error, LocalizedError, Sendable {
        case missingPair, tooLarge, unsafeFile
        var errorDescription: String? {
            switch self {
            case .missingPair: "Both original cursors were not found. Choose the full preservation app or its prepared cursor files."
            case .tooLarge: "The selected executable exceeds the cursor recovery size limit."
            case .unsafeFile: "Cursor recovery requires regular files without symbolic links."
            }
        }
    }

    private static let pins = [
        "Cursors/original-cross.png": "68d2bea78b11e2a115cdb4b752ff8e96d773419910874401d3a76e853d52d200",
        "Cursors/original-reticule.png": "5985e79a9f75434962a8a5bafef576cfb78d625dc4ffdd74a02cc3b78fbd03aa",
    ]
    private static let png = Data([137, 80, 78, 71, 13, 10, 26, 10])
    private static let encodedPNG = Data("iVBORw0KGgo".utf8)
    private static let maximumImage = 2_000_000
    private static let maximumExecutable = 512 * 1024 * 1024

    static func collect(from selected: URL) throws -> [String: Data] {
        let (resources, executable) = try sourcePaths(selected.standardizedFileURL)
        var found: [String: Data] = [:]
        for path in pins.keys {
            let file = resources.appendingPathComponent(path)
            if FileManager.default.fileExists(atPath: file.path) {
                try requireContained(file, within: resources)
                accept(try read(file, maximum: maximumImage), into: &found)
            }
        }
        if found.count != pins.count, let executable, FileManager.default.fileExists(atPath: executable.path) {
            found.merge(extract(from: try read(executable, maximum: maximumExecutable)), uniquingKeysWith: { current, _ in current })
        }
        guard found.count == pins.count else { throw RecoveryError.missingPair }
        return found
    }

    static func extract(from binary: Data) -> [String: Data] {
        guard binary.count <= maximumExecutable else { return [:] }
        var found: [String: Data] = [:]
        var search = 0
        while search < binary.count, let match = binary.range(of: png, in: search..<binary.count) {
            let start = match.lowerBound
            search = match.upperBound
            var offset = search
            while offset + 12 <= binary.count && offset - start <= maximumImage {
                let length = word(binary, at: offset)
                let end = offset + length + 12
                guard length <= maximumImage, end <= binary.count, end - start <= maximumImage else { break }
                let isEnd = binary[offset + 4] == 73 && binary[offset + 5] == 69
                    && binary[offset + 6] == 78 && binary[offset + 7] == 68
                offset = end
                if isEnd {
                    accept(binary.subdata(in: start..<end), into: &found)
                    break
                }
            }
        }
        search = 0
        while search < binary.count, let match = binary.range(of: encodedPNG, in: search..<binary.count) {
            let start = match.lowerBound
            search = match.upperBound
            var end = start
            while end < min(binary.count, start + 16_384), isBase64(binary[end]) { end += 1 }
            var encoded = Data(binary[start..<end].filter { ![UInt8(9), 10, 13, 32].contains($0) })
            if let padding = encoded.firstIndex(of: 61) {
                let count = padding + (padding + 1 < encoded.count && encoded[padding + 1] == 61 ? 2 : 1)
                encoded = encoded.prefix(count)
            }
            if let data = Data(base64Encoded: encoded) { accept(data, into: &found) }
        }
        return found
    }

    private static func accept(_ data: Data, into found: inout [String: Data]) {
        guard (24...maximumImage).contains(data.count), data.starts(with: png),
              data[12..<16] == Data("IHDR".utf8), word(data, at: 16) == 28, word(data, at: 20) == 28 else { return }
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        for (path, expected) in pins where digest == expected { found[path] = data }
    }

    private static func word(_ data: Data, at offset: Int) -> Int {
        (0..<4).reduce(0) { ($0 << 8) | Int(data[offset + $1]) }
    }

    private static func isBase64(_ byte: UInt8) -> Bool {
        (65...90).contains(byte) || (97...122).contains(byte) || (48...57).contains(byte)
            || [UInt8(43), 47, 61, 9, 10, 13, 32].contains(byte)
    }

    private static func read(_ url: URL, maximum: Int) throws -> Data {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else { throw RecoveryError.unsafeFile }
        guard let size = values.fileSize, size <= maximum else { throw RecoveryError.tooLarge }
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        guard data.count <= maximum else { throw RecoveryError.tooLarge }
        return data
    }

    private static func requireContained(_ url: URL, within root: URL) throws {
        guard url.path == root.path || url.path.hasPrefix(root.path + "/") else { throw RecoveryError.unsafeFile }
        var current = url
        while true {
            let values = try? current.resourceValues(forKeys: [.isSymbolicLinkKey])
            guard values?.isSymbolicLink != true else { throw RecoveryError.unsafeFile }
            if current.path == root.path { return }
            current.deleteLastPathComponent()
        }
    }

    private static func sourcePaths(_ selected: URL) throws -> (URL, URL?) {
        let values = try selected.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isSymbolicLink != true else { throw RecoveryError.unsafeFile }
        if values.isRegularFile == true { return (selected.deletingLastPathComponent(), selected) }
        let app: URL?
        if selected.pathExtension.lowercased() == "app" { app = selected }
        else if selected.lastPathComponent == "Resources", selected.deletingLastPathComponent().lastPathComponent == "Contents",
                selected.deletingLastPathComponent().deletingLastPathComponent().pathExtension.lowercased() == "app" {
            app = selected.deletingLastPathComponent().deletingLastPathComponent()
        } else { app = nil }
        guard let app else { return (selected, nil) }
        let resources = app.appendingPathComponent("Contents/Resources")
        let info = app.appendingPathComponent("Contents/Info.plist")
        try requireContained(resources, within: app)
        try requireContained(info, within: app)
        guard let data = try? read(info, maximum: 1_000_000),
              let properties = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let name = properties["CFBundleExecutable"] as? String, !name.isEmpty,
              name != ".", name != "..", !name.contains("/"), !name.contains("\\"), !name.contains("\0") else {
            return (resources, nil)
        }
        let executable = app.appendingPathComponent("Contents/MacOS/" + name)
        try requireContained(executable, within: app)
        return (resources, executable)
    }
}
