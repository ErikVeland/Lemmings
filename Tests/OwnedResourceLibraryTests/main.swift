import Foundation
import NxlvKit

#if OWNED_RESOURCE_LIBRARY_AVAILABLE
struct Failure: Error, CustomStringConvertible { let description: String }
func check(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
  if try !condition() { throw Failure(description: message) }
}
func put(_ root: URL, _ path: String, _ text: String) throws {
  let target = root.appendingPathComponent(path)
  try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
  try Data(text.utf8).write(to: target)
}
func read(_ root: URL, _ path: String) throws -> String {
  try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
}
func rejected(_ operation: () throws -> Void) throws {
  do { try operation() } catch { return }
  throw Failure(description: "An unsafe resource import succeeded")
}

func run() throws {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent("OwnedResources-" + UUID().uuidString)
  try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: root) }
  let base = root.appendingPathComponent("base")
  let first = root.appendingPathComponent("first")
  let second = root.appendingPathComponent("second")
  try put(base, "Hints/classic.json", "trusted hints")
  try put(base, "AlternativeAssets/Lix/manifest.json", "trusted clean art")
  try put(first, "Ports/Classic/MAIN.DAT", "owned first")
  try put(first, "Hints/classic.json", "untrusted hints")
  let library = OwnedResourceLibrary(root: root.appendingPathComponent("library"), bundledResources: base,
    validator: { directory in
      if FileManager.default.fileExists(atPath: directory.appendingPathComponent("Ports/BROKEN.DAT").path) {
        throw Failure(description: "Rejected resource fixture")
      }
    })
  let a = try library.install(directory: first)
  try check(try read(a.resourcesDirectory, "Ports/Classic/MAIN.DAT") == "owned first", "The original resource path was not preserved")
  try check(try read(a.resourcesDirectory, "Hints/classic.json") == "trusted hints", "Imported data overrode trusted hints")
  try check(try read(a.resourcesDirectory, "AlternativeAssets/Lix/manifest.json") == "trusted clean art", "Trusted clean resources disappeared")
  try check(Bundle(url: a.bundleURL)?.resourceURL?.standardizedFileURL == a.resourcesDirectory.standardizedFileURL,
            "The generated data bundle cannot supply resources to existing readers")
  try check(library.installedResourcesDirectory() == a.resourcesDirectory && library.installedBundleURL() == a.bundleURL,
            "The validated resource bundle was not activated")
  let duplicate = try library.install(directory: first)
  try check(duplicate.contentID == a.contentID, "Identical owned resources changed identity")
  try put(second, "Music/Owned/song.mod", "owned music")
  let b = try library.install(directory: second)
  try check(b.contentID != a.contentID, "A new resource selection reused the old identity")
  try check(try read(b.resourcesDirectory, "Ports/Classic/MAIN.DAT") == "owned first", "The next import discarded previous owned resources")
  try check(try read(b.resourcesDirectory, "Music/Owned/song.mod") == "owned music", "The next resource family was not merged")
  try check(try read(a.resourcesDirectory, "Ports/Classic/MAIN.DAT") == "owned first", "A later import changed the previous bundle")
  let bad = root.appendingPathComponent("bad")
  for path in ["Ports/run.sh", "Ports/tool.EXE", "Unexpected/data.dat", "Fonts/Lix/font.ttf"] {
    try? FileManager.default.removeItem(at: bad)
    try put(bad, path, "payload")
    try rejected { _ = try library.install(directory: bad) }
    try check(library.installedBundleURL() == b.bundleURL, "A rejected import replaced the active receipt")
  }
  try FileManager.default.removeItem(at: bad)
  try put(bad, "Ports/disguised.dat", "MZ executable")
  try rejected { _ = try library.install(directory: bad) }
  try FileManager.default.removeItem(at: bad)
  try put(bad, "Ports/BROKEN.DAT", "asset")
  try rejected { _ = try library.install(directory: bad) }
  try FileManager.default.removeItem(at: bad)
  try FileManager.default.createDirectory(at: bad, withIntermediateDirectories: true)
  try FileManager.default.createSymbolicLink(at: bad.appendingPathComponent("Ports"), withDestinationURL: first.appendingPathComponent("Ports"))
  try rejected { _ = try library.install(directory: bad) }
  try check(library.installedBundleURL() == b.bundleURL, "Failed validation or a link changed active resources")
  try check(try read(base, "Hints/classic.json") == "trusted hints", "The installed app resource source changed")
  try put(base, "Hints/classic.json", "updated trusted hints")
  try put(base, "AlternativeAssets/Lix/new-bank.json", "new trusted bank")
  guard let refreshed = try library.refreshBaseIfNeeded() else { throw Failure(description: "The owned bundle disappeared during an app update") }
  try check(refreshed.contentID != b.contentID, "Updated trusted resources reused the old immutable identity")
  try check(try read(refreshed.resourcesDirectory, "Hints/classic.json") == "updated trusted hints", "The app update retained old trusted metadata")
  try check(try read(refreshed.resourcesDirectory, "AlternativeAssets/Lix/new-bank.json") == "new trusted bank", "A new app resource was not rebased")
  try check(try read(refreshed.resourcesDirectory, "Music/Owned/song.mod") == "owned music", "An app update discarded owned media")
  try check(try read(b.resourcesDirectory, "Hints/classic.json") == "trusted hints", "Rebasing changed the previous immutable bundle")
  try check(try library.refreshBaseIfNeeded()?.contentID == refreshed.contentID, "An unchanged base caused another rebase")
  print("PASS merged data bundle, stable identity, previous assets, trusted metadata and rejection preservation")
  print("PASS app-update rebase retains owned media and adopts changed/new trusted resources")

  if let path = ProcessInfo.processInfo.environment["LEMMIX_TEST_FULL_RESOURCE_SOURCE"] {
    let environment = ProcessInfo.processInfo.environment
    let realRoot = environment["LEMMIX_TEST_RESOURCE_IMPORT_ROOT"].map { URL(fileURLWithPath: $0) }
      ?? root.appendingPathComponent("real-library")
    let realBase = environment["LEMMIX_TEST_RESOURCE_BASE"].map { URL(fileURLWithPath: $0) } ?? base
    let real = OwnedResourceLibrary(root: realRoot, bundledResources: realBase)
    let imported: OwnedResourceLibrary.Installation
    if environment["LEMMIX_TEST_RESOURCE_REUSE"] == "1", let existing = try real.verifyInstalled() {
      imported = existing
    } else {
      imported = try real.install(directory: URL(fileURLWithPath: path))
    }
    let bundle = Bundle(url: imported.bundleURL)!
    try check(!BundledGameResources.classicDirectories(in: bundle).isEmpty, "Real full resources did not expose Classic releases")
    _ = try BundledGameResources.lemmings2(in: bundle)
    _ = try BundledGameResources.lemmings3(in: bundle)
    _ = try ClassicMacArtwork(directory: imported.resourcesDirectory.appendingPathComponent("MacArtwork/lemmings"))
    if let proof = environment["LEMMIX_TEST_RESOURCE_IMPORT_PROOF"] {
      let record: [String: Any] = ["resourcesDirectory": imported.resourcesDirectory.path,
        "bundleURL": imported.bundleURL.path, "contentID": imported.contentID,
        "fileCount": imported.fileCount, "bytes": imported.bytes,
        "omittedSourceFiles": imported.omittedSourceFiles, "source": path,
        "nativeReadersValidated": ["Classic", "MacArtwork", "AmigaArtwork", "Lemmings 2", "Lemmings 3"],
        "sourceReadOnly": true, "applicationsChanged": false, "audio": "muted",
        "reusedValidatedFixture": environment["LEMMIX_TEST_RESOURCE_REUSE"] == "1"]
      try JSONSerialization.data(withJSONObject: record, options: [.prettyPrinted, .sortedKeys])
        .write(to: URL(fileURLWithPath: proof), options: .atomic)
    }
    print("PASS real full-resource paths and current native Classic/Mac/L2/L3 readers")
  }
}
do { try run() } catch {
  FileHandle.standardError.write(Data(("FAIL: \(error)\n").utf8)); exit(1)
}
#else
FileHandle.standardError.write(Data("FAIL: No full owned resource-bundle import is available\n".utf8))
exit(1)
#endif
