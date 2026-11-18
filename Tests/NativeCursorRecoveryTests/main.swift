import Foundation
import CryptoKit

private struct Failure: Error { let message: String }
private func check(_ value: @autoclosure () throws -> Bool, _ message: String) throws {
    guard try value() else { throw Failure(message: message) }
}

private func run() throws {
    let project = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let fixtures = project.appendingPathComponent("Tests/DialogCursorTests/Fixtures")
    let cross = try Data(contentsOf: fixtures.appendingPathComponent("amiga-cursor.png"))
    let target = try Data(contentsOf: fixtures.appendingPathComponent("amiga-reticule.png"))
    let expected = ["Cursors/original-cross.png": cross, "Cursors/original-reticule.png": target]
    var binary = Data("MachO-fixture\0".utf8)
    binary.append(cross.base64EncodedData(options: .lineLength64Characters)); binary.append(0)
    binary.append(target.base64EncodedData()); binary.append(0)
    try check(NativeCursorRecovery.extract(from: binary) == expected, "Native recovery did not decode the pinned embedded constants")
    var changed = cross
    changed[changed.count - 1] ^= 1
    try check(NativeCursorRecovery.extract(from: changed).isEmpty, "Native recovery accepted a changed original image")
    try check(NativeCursorRecovery.extract(from: cross) == ["Cursors/original-cross.png": cross],
              "Native recovery did not decode a pinned raw PNG")
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("NativeCursorRecovery-\(UUID())")
    defer { try? FileManager.default.removeItem(at: root) }
    let app = root.appendingPathComponent("Full.app")
    let resources = app.appendingPathComponent("Contents/Resources")
    let executable = app.appendingPathComponent("Contents/MacOS/Full")
    try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: executable.deletingLastPathComponent(), withIntermediateDirectories: true)
    let info = app.appendingPathComponent("Contents/Info.plist")
    try PropertyListSerialization.data(fromPropertyList: ["CFBundleExecutable": "Full"], format: .xml, options: 0).write(to: info)
    try binary.write(to: executable)
    try check(try NativeCursorRecovery.collect(from: app) == expected, "Native app import did not recover its embedded cursor pair")
    try check(try NativeCursorRecovery.collect(from: resources) == expected, "Native Resources selection lost its app's cursor pair")
    try PropertyListSerialization.data(fromPropertyList: ["CFBundleExecutable": "../../outside"], format: .xml, options: 0).write(to: info)
    var traversalRejected = false
    do { _ = try NativeCursorRecovery.collect(from: app) } catch { traversalRejected = true }
    try check(traversalRejected, "Native recovery accepted an executable path outside the selected app")
    let cursorDirectory = resources.appendingPathComponent("Cursors")
    try FileManager.default.createDirectory(at: cursorDirectory, withIntermediateDirectories: true)
    try cross.write(to: cursorDirectory.appendingPathComponent("original-cross.png"))
    var incompleteRejected = false
    do { _ = try NativeCursorRecovery.collect(from: app) } catch { incompleteRejected = true }
    try check(incompleteRejected, "Native recovery accepted an incomplete resource cursor pair")
    try target.write(to: cursorDirectory.appendingPathComponent("original-reticule.png"))
    try check(try NativeCursorRecovery.collect(from: app) == expected, "Native recovery did not preserve an existing resource pair")
    let linkedApp = root.appendingPathComponent("Linked.app")
    let linkedContents = linkedApp.appendingPathComponent("Contents")
    try FileManager.default.createDirectory(at: linkedContents.appendingPathComponent("Resources"), withIntermediateDirectories: true)
    let outside = root.appendingPathComponent("outside")
    try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
    try binary.write(to: outside.appendingPathComponent("Full"))
    try FileManager.default.createSymbolicLink(at: linkedContents.appendingPathComponent("MacOS"), withDestinationURL: outside)
    try PropertyListSerialization.data(fromPropertyList: ["CFBundleExecutable": "Full"], format: .xml, options: 0)
        .write(to: linkedContents.appendingPathComponent("Info.plist"))
    var linkedExecutableRejected = false
    do { _ = try NativeCursorRecovery.collect(from: linkedApp) } catch { linkedExecutableRejected = true }
    try check(linkedExecutableRejected, "Native recovery followed an executable directory outside the selected app")
    let installed = URL(fileURLWithPath: "/Applications/Ultimate Lemmings.app")
    if FileManager.default.fileExists(atPath: installed.path) {
        try check(try NativeCursorRecovery.collect(from: installed) == expected,
                  "The installed full 2.4.2 app did not restore its exact original cursors natively")
        print("PASS native cursor recovery from the actual installed full app, with exact original source bytes")
    }
    print("PASS native cursor recovery: base64/raw pins, changed-image rejection, app/Resources lookup, path containment and incomplete-pair rejection")
}

do { try run() }
catch {
    FileHandle.standardError.write(Data(("FAIL \(error)\n").utf8))
    exit(1)
}
