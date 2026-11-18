import Foundation
import NxlvKit

func check(_ condition: Bool, _ message: String) {
  guard condition else {
    FileHandle.standardError.write(Data("FAIL \(message)\n".utf8))
    exit(1)
  }
  print("PASS \(message)")
}

let project = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let cases: [(String, String, String)] = [
  ("Sources/Ports/lemmings_dos_1991-07-30", "lemmings-LEVEL-120", "2e3e67e01c0e9d75a45354f53504d6f6c47a54da0e32b340ae0c08ba2bf247d7"),
  ("Sources/Ports/oh_no_more_lemmings_dos-1991-11-14_2232", "ohNoMoreLemmings-DLVEL-100", "6dad75cd5148ba209afd886fd0c7e6dc4d6d3d92ea17eb05c98fbecc8778ac25"),
  ("Sources/Ports/xmas_dos_XmasLemmingsV1.9", "xmasLemmings1991-LEVEL-4", "b8bf363cf18f1d91186c626d8056bfc0aeaf1d1a8e789f83b2579958902089e8"),
  ("Sources/Ports/xmas_dos_XmasLemmingsV1.9a1", "xmasLemmings1992-LEVEL-4", "62b793ae53f30cb131b2693f3383d550635425461187352fc7a500435284c7b7"),
  (".build/local/Ultimate Lemmings.app/Contents/Resources/Ports/holiday_native_1993", "holidayLemmings1993-MACLEVL-32", "9b8270f81c049e91081141c6091a69a62cb8610a45c023152015d74876ada07e"),
  (".build/local/Ultimate Lemmings.app/Contents/Resources/Ports/holiday_native_1994", "holidayLemmings1994-MACLEVL-32", "e8253af9f5c99eebba38cb4a1211c3dfd0a8264dc22c94a13e6218fddbb65484"),
]
for (path, packID, revision) in cases {
  let directory = project.appendingPathComponent(path, isDirectory: true)
  let set = try ClassicDataSet.detect(directory: directory)
  let alias = ClassicSourceIdentity.canonicalAlias(for: set, directory: directory)
  check(alias?.packID == packID && alias?.sourceRevision == revision,
    "a complete verified \(packID) import resolves its authored metadata")
}

let source = project.appendingPathComponent(cases[0].0, isDirectory: true)
let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("ClassicSourceIdentity-\(UUID().uuidString)")
try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: temporary) }
let imported = temporary.appendingPathComponent("My moved owned game", isDirectory: true)
try FileManager.default.createDirectory(at: imported, withIntermediateDirectories: true)
for file in try FileManager.default.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)
  where file.pathExtension.lowercased() == "dat" {
  try FileManager.default.copyItem(at: file, to: imported.appendingPathComponent(file.lastPathComponent.lowercased()))
}
try Data("Player notes".utf8).write(to: imported.appendingPathComponent("notes.txt"))
let unchanged = try ClassicDataSet.detect(directory: imported)
check(ClassicSourceIdentity.canonicalAlias(for: unchanged, directory: imported)?.packID == "lemmings-LEVEL-120",
  "moving an import, filename case and player notes do not change canonical identity")

let ground = imported.appendingPathComponent("ground0o.dat")
let originalGround = try Data(contentsOf: ground)
var changedGround = originalGround
changedGround[0] ^= 1
try changedGround.write(to: ground)
check(ClassicSourceIdentity.canonicalAlias(for: unchanged, directory: imported) == nil,
  "changed collision or object assets cannot inherit a checked campaign revision")
try originalGround.write(to: ground)

let oddTable = imported.appendingPathComponent("oddtable.dat")
let originalOddTable = try Data(contentsOf: oddTable)
var changedOddTable = originalOddTable
for index in stride(from: 0, to: changedOddTable.count, by: 56) { changedOddTable[index] ^= 1 }
try changedOddTable.write(to: oddTable)
let modified = try ClassicDataSet.detect(directory: imported)
check(modified.campaign != unchanged.campaign, "the altered campaign fixture changes decoded level properties")
check(ClassicSourceIdentity.canonicalAlias(for: modified, directory: imported) == nil,
  "a recognised title and level count cannot grant canonical identity to changed levels")
check(ClassicSourceIdentity.canonicalAlias(for: unchanged, directory: imported) == nil,
  "a stale decoded campaign cannot mask changed source files")
try originalOddTable.write(to: oddTable)

try FileManager.default.removeItem(at: imported.appendingPathComponent("main.dat"))
check(ClassicSourceIdentity.canonicalAlias(for: unchanged, directory: imported) == nil,
  "missing simulation masks prevent a historical checked revision")
check(ClassicSourceIdentity.canonicalAlias(for: unchanged, directory: temporary.appendingPathComponent("missing")) == nil,
  "an unavailable source directory has no canonical alias")
