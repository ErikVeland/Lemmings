import Darwin
import Foundation

// Signed app resources cannot carry Macintosh resource-fork attributes.
// Preserve their bytes as ordinary files instead of dropping the best assets.
do {
    guard CommandLine.arguments.count == 3 else {
        throw NSError(domain: "BundleGameAssets", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "Expected source Ports and embedded Ports directories."])
    }
    let source = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true).standardizedFileURL
    let destination = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true).standardizedFileURL
    let keys: [URLResourceKey] = [.isRegularFileKey, .isSymbolicLinkKey]
    guard let walker = FileManager.default.enumerator(at: source, includingPropertiesForKeys: keys) else {
        throw NSError(domain: "BundleGameAssets", code: 2)
    }
    var copied = 0
    for case let file as URL in walker {
        let properties = try file.resourceValues(forKeys: Set(keys))
        guard properties.isRegularFile == true, properties.isSymbolicLink != true else { continue }
        let size = getxattr(file.path, "com.apple.ResourceFork", nil, 0, 0, 0)
        if size < 0 {
            guard errno == ENOATTR || errno == ENOTSUP else {
                throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
            }
            continue
        }
        guard size > 0 else { continue }
        var bytes = Data(count: size)
        let count = bytes.withUnsafeMutableBytes {
            getxattr(file.path, "com.apple.ResourceFork", $0.baseAddress, size, 0, 0)
        }
        guard count == size else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        let relative = String(file.path.dropFirst(source.path.count + 1))
        let output = destination.appendingPathComponent("MacResourceForks").appendingPathComponent(relative + ".rsrc")
        try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
        try bytes.write(to: output, options: .atomic)
        copied += 1
    }
    print("Embedded \(copied) Macintosh resource forks as data files.")
} catch {
    FileHandle.standardError.write(Data("Cannot embed Macintosh resource data: \(error)\n".utf8)); exit(1)
}
