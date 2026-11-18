import Foundation
import NxlvKit

@MainActor final class ArcadeStore {
  static let shared = ArcadeStore()
  func progressKey(_ key: String) -> String { "FanOwnedRootsTests." + key }
}
func check(_ condition: Bool, _ message: String) {
  guard condition else {
    FileHandle.standardError.write(Data("FAIL \(message)\n".utf8))
    exit(1)
  }
  print("PASS \(message)")
}
func level(style: Int = 0, special: Int = 0) throws -> ClassicLevel {
  var data = Data(repeating: 0, count: ClassicLevel.recordSize)
  data[0x1B] = UInt8(style)
  data[0x1D] = UInt8(special)
  return try ClassicLevel(data: data)
}
let project = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let missing = project.appendingPathComponent(".build/fan-owned-roots-tests/no-bundled-ports")
let original = project.appendingPathComponent("Sources/Ports/lemmings_dos_1991-07-30")
let onml = project.appendingPathComponent("Sources/Ports/oh_no_more_lemmings_dos-1991-11-14_2232")
let holiday = project.appendingPathComponent(".build/local/Ultimate Lemmings.app/Contents/Resources/Ports/holiday_native_1994")
let owned = [holiday, onml, original]
check(try FanLevelLibrary.groundSet(for: level(), styleName: "dirt", portsRoot: missing, ownedClassicRoots: owned)
  == ClassicGroundSet.load(style: 0, from: original), "named dirt uses the owned Original release")
check(try FanLevelLibrary.groundSet(for: level(), styleName: "brick", portsRoot: missing, ownedClassicRoots: owned)
  == ClassicGroundSet.load(style: 0, from: onml), "named brick uses the owned ONML release")
check(try FanLevelLibrary.groundSet(for: level(style: 5), styleName: nil, portsRoot: missing, ownedClassicRoots: owned)
  == ClassicGroundSet.load(style: 0, from: onml), "combined editor slots retain release-local numbering")
check(try FanLevelLibrary.groundSet(for: level(style: 9), styleName: nil, portsRoot: missing, ownedClassicRoots: owned)
  == ClassicGroundSet.load(style: 2, from: holiday), "the Xmas slot uses owned Holiday snow")
let remake = project.appendingPathComponent("Content/LevelPacks/0530-Oh-No-More-cLemmings-Tame.zip")
check(try FanLevelLibrary.groundSet(for: level(), styleName: nil, portsRoot: missing, pack: remake, ownedClassicRoots: owned)
  == ClassicGroundSet.load(style: 0, from: onml), "pinned fan remake archives retain local ONML slots")
check(try FanLevelLibrary.specialGraphic(for: level(special: 1), portsRoot: missing, ownedClassicRoots: owned)
  == ClassicSpecialGraphic.load(index: 0, from: original), "stock special pictures resolve from the owned Original release")
check(try FanLevelLibrary.mainDATAssets(portsRoot: missing, ownedClassicRoots: owned)
  == ClassicMainDATAssets.load(from: original), "fan simulations prefer owned Original masks when available")
check(try FanLevelLibrary.mainDATAssets(portsRoot: missing, ownedClassicRoots: [onml])
  == ClassicMainDATAssets.load(from: onml), "an ONML-only owner can load that release's valid Classic masks")
check(try ClassicMainDATAssets.load(from: onml).destructionMasks
  == ClassicMainDATAssets.load(from: original).destructionMasks,
  "the supported Original and ONML mask sources preserve the same destruction geometry")
do {
  _ = try FanLevelLibrary.groundSet(for: level(), styleName: "dirt", portsRoot: missing, ownedClassicRoots: [onml])
  check(false, "ONML is not substituted for a missing Original style")
} catch { print("PASS ONML is not substituted for a missing Original style") }
let ports = project.appendingPathComponent("Sources/Ports")
check(try FanLevelLibrary.groundSet(for: level(), styleName: "dirt", portsRoot: ports, ownedClassicRoots: [onml])
  == ClassicGroundSet.load(style: 0, from: original), "existing bundled style lookup retains priority")
check(try FanLevelLibrary.mainDATAssets(portsRoot: ports, ownedClassicRoots: [onml])
  == ClassicMainDATAssets.load(from: original), "existing bundled simulation assets retain priority")
