import Foundation

@main struct Checks {
  @MainActor static func main() throws {
    let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: temporary) }
    let original = GameResources.resourceURL
    func fixture(_ name: String, text: String) throws -> URL {
      let bundle = temporary.appendingPathComponent(name + ".bundle")
      let resources = bundle.appendingPathComponent("Contents/Resources/MacArtwork")
      try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
      try Data(text.utf8).write(to: resources.appendingPathComponent("sample.txt"))
      let info: [String: Any] = ["CFBundleIdentifier": "test.resources." + name,
        "CFBundlePackageType": "BNDL", "CFBundleVersion": "1"]
      try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
        .write(to: bundle.appendingPathComponent("Contents/Info.plist"))
      return bundle
    }
    let first = try fixture("First", text: "first")
    let second = try fixture("Second", text: "second")
    try GameResources.activate(bundleURL: first)
    let revision = GameResources.revision
    let firstText = try String(contentsOf: GameResources.file("MacArtwork/sample.txt")!, encoding: .utf8)
    precondition(firstText == "first")
    precondition(GameResources.bundle.resourceURL == GameResources.resourceURL)
    precondition(GameResources.directory("MacArtwork") != nil)
    precondition(GameResources.directory("MacArtwork/sample.txt") == nil)
    precondition(GameResources.file("../Contents/Info.plist") == nil)
    precondition(GameResources.file("/MacArtwork/sample.txt") == nil)
    precondition(GameResources.file("MacArtwork//sample.txt") == nil)
    try GameResources.activate(bundleURL: first)
    precondition(GameResources.revision == revision)
    try GameResources.activate(bundleURL: second)
    precondition(GameResources.revision != revision)
    let secondText = try String(contentsOf: GameResources.file("MacArtwork/sample.txt")!, encoding: .utf8)
    precondition(secondText == "second")
    do {
      try GameResources.activate(bundleURL: temporary.appendingPathComponent("missing.bundle"))
      preconditionFailure("Missing resource bundle was accepted")
    } catch {}
    precondition(GameResources.bundle.bundleURL.standardizedFileURL.path == second.standardizedFileURL.path)
    try GameResources.activate(bundleURL: nil)
    precondition(GameResources.resourceURL == original)
    print("PASS shared resource selection, original/fallback reset, generation changes and invalid-path rejection")
  }
}
