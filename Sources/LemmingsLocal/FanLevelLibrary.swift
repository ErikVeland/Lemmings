import Foundation
import NxlvKit

/// Reads the fan level packs a player has downloaded.
///
/// A pack is a zip holding levels in one of three shapes. A `.lvl` file is one
/// level. A `.ini` file is one level written as text. A `.dat` file is a DOS
/// archive of many levels, and it is the commonest of the three, so a browser
/// that ignores it shows most packs as empty.
///
/// The zips are read with the system `unzip` rather than an archive library.
/// Browsing reads a file per keypress, which is not worth a dependency.
enum FanLevelLibrary {
  /// Where the chosen folder is remembered between runs.
  static let folderKey = "FanLevelFolder"

  static var folder: URL? {
    UserDefaults.standard.string(forKey: folderKey).map { URL(fileURLWithPath: $0) }
  }

  /// One playable level inside a pack.
  ///
  /// `section` names which level inside a DOS archive, and is nil for the
  /// shapes that keep one level per file.
  struct Entry {
    let file: String
    let section: Int?
    let label: String
  }

  // MARK: - Progress

  /// What the player has passed, and how big each pack is.
  ///
  /// Fan levels are not part of the campaign flow, which is saved per release
  /// and tracks a run in order. These are hundreds of unrelated packs played in
  /// any order, so progress is just a set of levels passed.
  ///
  /// Counting a pack means opening it and decoding its archives, which is far
  /// too slow to do while drawing a menu. Counts are therefore remembered once
  /// found, and the total on the front screen counts the packs measured so far.
  enum Progress {
    private static let passedKey = "FanLevelsPassed"
    private static let countsKey = "FanLevelCounts"

    /// A stable name for one level, so a pack can be renamed on disk without
    /// losing its record.
    static func identifier(pack: URL, label: String) -> String {
      "\(displayName(of: pack))|\(label)"
    }

    static var passed: Set<String> {
      Set(UserDefaults.standard.stringArray(forKey: passedKey) ?? [])
    }

    static func record(pack: URL, label: String) {
      var all = passed
      guard all.insert(identifier(pack: pack, label: label)).inserted else { return }
      UserDefaults.standard.set(Array(all).sorted(), forKey: passedKey)
    }

    static func hasPassed(pack: URL, label: String) -> Bool {
      passed.contains(identifier(pack: pack, label: label))
    }

    static var counts: [String: Int] {
      UserDefaults.standard.dictionary(forKey: countsKey) as? [String: Int] ?? [:]
    }

    static func setCount(_ count: Int, for pack: URL) {
      var all = counts
      let key = displayName(of: pack)
      guard all[key] != count else { return }
      all[key] = count
      UserDefaults.standard.set(all, forKey: countsKey)
    }

    /// Levels in the packs measured so far.
    static var knownTotal: Int { counts.values.reduce(0, +) }
    static var passedTotal: Int { passed.count }

    /// Whether every pack in the folder has been measured.
    static func isComplete(for packs: [URL]) -> Bool {
      let known = counts
      return packs.allSatisfy { known[displayName(of: $0)] != nil }
    }

    /// Measures any pack not yet counted. Slow, so it runs off the main thread.
    static func measure(
      _ packs: [URL], onProgress: @escaping @MainActor @Sendable () -> Void
    ) {
      DispatchQueue.global(qos: .utility).async {
        for pack in packs where counts[displayName(of: pack)] == nil {
          let total = entries(in: pack).count
          DispatchQueue.main.async {
            MainActor.assumeIsolated {
              setCount(total, for: pack)
              onProgress()
            }
          }
        }
      }
    }
  }

  /// Every pack in the chosen folder, by name.
  static func packs() -> [URL] {
    guard let folder else { return [] }
    return ((try? FileManager.default.contentsOfDirectory(
      at: folder, includingPropertiesForKeys: nil)) ?? [])
      .filter { $0.pathExtension.lowercased() == "zip" }
      .sorted { $0.lastPathComponent < $1.lastPathComponent }
  }

  /// A pack's name without the filing number the mirror gives it.
  static func displayName(of pack: URL) -> String {
    let stem = pack.deletingPathExtension().lastPathComponent
    let withoutNumber = stem.drop { $0.isNumber }.drop { $0 == "-" }
    return withoutNumber.replacingOccurrences(of: "-", with: " ")
  }

  /// The levels inside one pack.
  static func entries(in pack: URL) -> [Entry] {
    let names = shell(["/usr/bin/unzip", "-Z1", pack.path])
      .split(separator: "\n").map(String.init).sorted()
    var found: [Entry] = []
    for name in names {
      let lower = name.lowercased()
      let base = (name as NSString).lastPathComponent.lowercased()
      if lower.hasSuffix(".lvl")
        || (lower.hasSuffix(".ini") && !lower.hasSuffix("levelpack.ini")) {
        found.append(Entry(
          file: name, section: nil, label: (name as NSString).lastPathComponent))
      } else if lower.hasSuffix(".dat") {
        // Graphics archives sit beside the levels and hold no level records.
        guard !base.hasPrefix("vgaspec"), !base.hasPrefix("vgagr"),
          !base.hasPrefix("ground"), let raw = contents(of: name, in: pack),
          let sections = try? ClassicDATArchive.decode(raw)
        else { continue }
        for (index, section) in sections.enumerated() {
          guard section.data.count >= ClassicLevel.recordSize,
            let level = try? ClassicLevel(
              data: section.data.prefix(ClassicLevel.recordSize))
          else { continue }
          let title = level.title.isEmpty ? "\(base) \(index + 1)" : level.title
          found.append(Entry(file: name, section: index, label: title))
        }
      }
    }
    return found
  }

  /// Reads one level, and the style name when the level carries one.
  static func level(_ entry: Entry, in pack: URL) throws -> (ClassicLevel, String?) {
    guard let raw = contents(of: entry.file, in: pack) else {
      throw FanLevelError.wrongSize(bytes: 0)
    }
    if let section = entry.section {
      let sections = try ClassicDATArchive.decode(raw)
      guard sections.indices.contains(section) else {
        throw FanLevelError.wrongSize(bytes: 0)
      }
      return (
        try ClassicLevel(data: sections[section].data.prefix(ClassicLevel.recordSize)),
        nil)
    }
    if entry.file.lowercased().hasSuffix(".lvl") {
      return (try FanLevelReader.level(fromLVL: raw), nil)
    }
    let text = String(decoding: raw, as: UTF8.self)
    return (try FanLevelReader.level(fromINI: text), FanLevelReader.styleName(fromINI: text))
  }

  // MARK: - Reading zips

  private static func contents(of entry: String, in pack: URL) -> Data? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
    process.arguments = ["-p", pack.path, entry]
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice
    guard (try? process.run()) != nil else { return nil }
    let out = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return out.isEmpty ? nil : out
  }

  private static func shell(_ arguments: [String]) -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: arguments[0])
    process.arguments = Array(arguments.dropFirst())
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice
    guard (try? process.run()) != nil else { return "" }
    let out = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return String(decoding: out, as: UTF8.self)
  }
}
