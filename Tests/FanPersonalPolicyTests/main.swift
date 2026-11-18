import Foundation
import NxlvKit

@MainActor final class ArcadeStore {
  static let shared = ArcadeStore()
  func progressKey(_ key: String) -> String { "FanPersonalPolicyTests." + key }
}

func check(_ condition: Bool, _ message: String) {
  guard condition else {
    FileHandle.standardError.write(Data("FAIL \(message)\n".utf8))
    exit(1)
  }
  print("PASS \(message)")
}

let external = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let previous = UserDefaults.standard.object(forKey: FanLevelLibrary.folderKey)
defer {
  if let previous { UserDefaults.standard.set(previous, forKey: FanLevelLibrary.folderKey) }
  else { UserDefaults.standard.removeObject(forKey: FanLevelLibrary.folderKey) }
}
UserDefaults.standard.set(external.path, forKey: FanLevelLibrary.folderKey)
let bundled = FanLevelLibrary.bundledFolder!
let externalPack = external.appendingPathComponent("9001-selected.zip")
check(FanLevelLibrary.packs().contains(externalPack), "personal preview discovers an explicitly selected external pack")
check(try FanLevelLibrary.validatedEntries(in: externalPack).count == 10,
  "external archives do not need a bundled corpus manifest row")
let sameName = external.appendingPathComponent("0001-pinned.zip")
check(try FanLevelLibrary.validatedEntries(in: sameName).count == 10,
  "an external archive with a bundled basename keeps its own levels")
let pinned = bundled.appendingPathComponent("0001-pinned.zip")
let selected = try FanLevelLibrary.validatedEntries(in: pinned)
check(selected.count == 9 && !selected.contains { $0.file == "level[1].ini" },
  "the pinned bundled archive hides its exact excluded member")
do {
  _ = try FanLevelLibrary.level(.init(file: "level[1].ini", section: nil, label: "Hidden"), in: pinned)
  check(false, "an excluded member cannot be opened directly")
} catch { print("PASS an excluded member cannot be opened directly") }
check(!FanLevelLibrary.packs().contains(bundled.appendingPathComponent("9002-unlisted.zip")),
  "unlisted bundled archives stay outside the corpus")
check(FanLevelLibrary.entries(in: bundled.appendingPathComponent("0002-changed.zip")).isEmpty,
  "a changed bundled archive cannot reuse a pinned manifest row")
check(FanLevelLibrary.entries(in: bundled.appendingPathComponent("linked-bundle.zip")).isEmpty,
  "a bundled symlink cannot bypass the pinned corpus list")
check(try FanLevelLibrary.validatedEntries(in: externalPack).contains { $0.file == "level[1].ini" },
  "bundled exclusions do not affect an external player's copy")

let overlay = external.appendingPathComponent("OwnedResources.bundle", isDirectory: true)
let overlayResources = overlay.appendingPathComponent("Contents/Resources", isDirectory: true)
let overlayPacks = overlayResources.appendingPathComponent("LevelPacks", isDirectory: true)
try FileManager.default.createDirectory(at: overlayPacks, withIntermediateDirectories: true)
let ownedPack = overlayPacks.appendingPathComponent("0001-pinned.zip")
try Data(contentsOf: externalPack).write(to: ownedPack)
let info: [String: Any] = ["CFBundleIdentifier": "academy.glasscode.lemmix.owned-resources-tests",
  "CFBundleName": "Owned Resources", "CFBundleVersion": "1", "CFBundlePackageType": "BNDL"]
try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
  .write(to: overlay.appendingPathComponent("Contents/Info.plist"))
try GameResources.activate(bundleURL: overlay)
check(FanLevelLibrary.bundledFolder?.standardizedFileURL == overlayPacks.standardizedFileURL,
  "the active owned resource bundle supplies its LevelPacks directory")
check(FanLevelLibrary.packs().contains(ownedPack), "owned full-bundle packs enter the normal fan library")
check(try FanLevelLibrary.validatedEntries(in: ownedPack).count == 10,
  "the private bundled corpus manifest does not filter the player's owned resource bundle")
try GameResources.activate(bundleURL: nil)
check(try FanLevelLibrary.validatedEntries(in: pinned).count == 9,
  "restoring bundled resources retains the hash-bound personal exclusions")
