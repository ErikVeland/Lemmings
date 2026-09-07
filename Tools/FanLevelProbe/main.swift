import Foundation
import NxlvKit

// Parses every level file extracted from the fan packs and reports what worked.

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1
    ? CommandLine.arguments[1] : ".", isDirectory: true)

func files(_ folder: String) -> [URL] {
    let dir = root.appendingPathComponent(folder, isDirectory: true)
    return ((try? FileManager.default.contentsOfDirectory(
        at: dir, includingPropertiesForKeys: nil)) ?? []).sorted { $0.path < $1.path }
}

var okLVL = 0, failLVL = 0
var lvlFailures: [String] = []
for url in files("lvl") {
    guard let data = try? Data(contentsOf: url) else { continue }
    do {
        let level = try FanLevelReader.level(fromLVL: data)
        if level.terrain.isEmpty && level.specialStyle == 0 {
            lvlFailures.append("\(url.lastPathComponent): no terrain")
        }
        okLVL += 1
    } catch {
        failLVL += 1
        if lvlFailures.count < 5 { lvlFailures.append("\(url.lastPathComponent): \(error)") }
    }
}

var okINI = 0, failINI = 0, mismatch = 0
var iniFailures: [String] = []
for url in files("ini") {
    guard let text = try? String(contentsOf: url, encoding: .isoLatin1) else { continue }
    do {
        let level = try FanLevelReader.level(fromINI: text)
        // The record we built has to report back the numbers the text declared.
        let fields = FanLevelReader.parse(text)
        let declaredLemmings = try? fields.integer("numLemmings")
        let declaredRescue = try? fields.integer("numToRescue")
        if level.lemmingCount != declaredLemmings || level.saveRequirement != declaredRescue {
            mismatch += 1
            if iniFailures.count < 5 {
                iniFailures.append("\(url.lastPathComponent): "
                    + "lemmings \(level.lemmingCount) vs \(declaredLemmings ?? -1)")
            }
        }
        okINI += 1
    } catch {
        failINI += 1
        if iniFailures.count < 5 { iniFailures.append("\(url.lastPathComponent): \(error)") }
    }
}

print("binary .lvl : \(okLVL) parsed, \(failLVL) failed")
print("text .ini   : \(okINI) parsed, \(failINI) failed, \(mismatch) with mismatched parameters")
for line in (lvlFailures + iniFailures).prefix(8) { print("   \(line)") }
