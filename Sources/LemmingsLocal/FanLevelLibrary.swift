import Foundation
import NxlvKit

/// Combines embedded packs, automatic downloads and optional local packs.
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
  struct Entry: Sendable {
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
    private static let countsKey = "FanLevelCountsV2"

    /// A stable name for one level, so a pack can be renamed on disk without
    /// losing its record.
    static func identifier(pack: URL, label: String) -> String {
      "\(displayName(of: pack))|\(label)"
    }

    @MainActor static var passed: Set<String> {
      Set(UserDefaults.standard.stringArray(forKey: ArcadeStore.shared.progressKey(passedKey)) ?? [])
    }

    @MainActor static func record(pack: URL, label: String) {
      var all = passed
      guard all.insert(identifier(pack: pack, label: label)).inserted else { return }
      UserDefaults.standard.set(Array(all).sorted(), forKey: ArcadeStore.shared.progressKey(passedKey))
    }

    @MainActor static func hasPassed(pack: URL, label: String) -> Bool {
      passed.contains(identifier(pack: pack, label: label))
    }

    static func countKey(_ pack: URL) -> String {
      packID(pack).map { "catalogue:\($0)" } ?? "file:" + pack.lastPathComponent.lowercased()
    }

    static var counts: [String: Int] {
      UserDefaults.standard.dictionary(forKey: countsKey) as? [String: Int] ?? [:]
    }

    static func setCount(_ count: Int, for pack: URL) {
      var all = counts
      let key = countKey(pack)
      guard all[key] != count else { return }
      all[key] = count
      UserDefaults.standard.set(all, forKey: countsKey)
    }

    /// Levels in the packs measured so far.
    static func total(for packs: [URL]) -> Int {
      let known = counts
      return packs.reduce(0) { $0 + (known[countKey($1)] ?? 0) }
    }

    static func mergeCounts(_ measured: [String: Int]) {
      var all = counts
      all.merge(measured) { _, new in new }
      UserDefaults.standard.set(all, forKey: countsKey)
    }

    static func seedBundledCounts() {
      guard let folder = bundledFolder,
        let data = try? Data(contentsOf: folder.appendingPathComponent("level-counts.json")),
        let index = try? JSONDecoder().decode([String: Int].self, from: data) else { return }
      var all = counts
      for (filename, count) in index where count >= 0 {
        let pack = folder.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: pack.path) { all[countKey(pack)] = count }
      }
      UserDefaults.standard.set(all, forKey: countsKey)
    }
    @MainActor static var passedTotal: Int { passed.count }

    /// Whether every pack in the folder has been measured.
    static func isComplete(for packs: [URL]) -> Bool {
      let known = counts
      return packs.allSatisfy { known[countKey($0)] != nil }
    }

    /// Measures any pack not yet counted. Slow, so it runs off the main thread.
    static func measure(
      _ packs: [URL], onProgress: @escaping @MainActor @Sendable () -> Void
    ) {
      DispatchQueue.global(qos: .utility).async {
        for pack in packs where counts[countKey(pack)] == nil {
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

  static var bundledFolder: URL? { Bundle.main.resourceURL?.appendingPathComponent("LevelPacks") }
  static var downloadFolder: URL {
    FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("Ultimate Lemmings/Fan Levels", isDirectory: true)
  }

  static func packID(_ url: URL) -> Int? {
    let prefix = url.lastPathComponent.prefix { $0.isNumber }
    guard url.lastPathComponent.dropFirst(prefix.count).first == "-" else { return nil }
    return Int(prefix)
  }

  /// Embedded packs stay available even when a chosen folder is missing.
  static func packs() -> [URL] {
    packs(in: [bundledFolder, downloadFolder, folder].compactMap { $0 })
  }

  static func packs(in folders: [URL]) -> [URL] {
    var result: [String: URL] = [:]
    for folder in folders {
      let files = (try? FileManager.default.contentsOfDirectory(at: folder,
        includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])) ?? []
      for file in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
        where file.pathExtension.lowercased() == "zip"
          && (try? file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true {
        let key = packID(file).map { "id:\($0)" } ?? "file:" + file.lastPathComponent.lowercased()
        if result[key] == nil { result[key] = file }
      }
    }
    return result.values.sorted { $0.lastPathComponent < $1.lastPathComponent }
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
        guard let raw = contents(of: name, in: pack) else { continue }
        guard (try? singleLevel(raw, name: name)) != nil else { continue }
        found.append(Entry(file: name, section: nil, label: (name as NSString).lastPathComponent))
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
  static func level(_ entry: Entry, in pack: URL, includeTextSteel: Bool = true) throws -> (ClassicLevel, String?) {
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
    return try singleLevel(raw, name: entry.file, includeTextSteel: includeTextSteel)
  }

  private static func singleLevel(_ raw: Data, name: String, includeTextSteel: Bool = true) throws -> (ClassicLevel, String?) {
    // Some archived binary levels were given an .ini extension by their author.
    if name.lowercased().hasSuffix(".lvl") || (raw.count == ClassicLevel.recordSize && raw.prefix(32).contains(0)) {
      return (try FanLevelReader.level(fromLVL: raw), nil)
    }
    let text = String(data: raw, encoding: .utf8) ?? (String(data: raw, encoding: .isoLatin1) ?? String(decoding: raw, as: UTF8.self))
    return (try FanLevelReader.level(fromINI: text, includeSteel: includeTextSteel), FanLevelReader.styleName(fromINI: text))
  }

  /// Custom-level slots span the original five styles, Oh No's four, then Xmas.
  /// Resolve them independently of whichever campaign the player last opened.
  static func groundSet(for level: ClassicLevel, styleName: String?, portsRoot: URL,
                        pack: URL? = nil, entry: Entry? = nil) throws -> ClassicGroundSet {
    let names = ["dirt", "fire", "marble", "pillar", "crystal", "brick", "rock", "snow", "bubble", "xmas"]
    let named = styleName?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let name = named ?? (names.indices.contains(level.groundStyle) ? names[level.groundStyle] : "slot \(level.groundStyle)")
    let directory: URL, index: Int
    if name == "xmas" || name == "christmas" {
      directory = portsRoot.appendingPathComponent("holiday_native_1994"); index = 2
    } else {
      switch ClassicStyleResolver(portsRoot: portsRoot).resolve(styleNamed: name == "special" ? "dirt" : name) {
      case let .found(root, slot), let .packSupplied(root, slot): directory = root; index = slot
      default: throw NSError(domain: "FanLevelLibrary", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unsupported or missing fan graphics style: \(name)"])
      }
    }
    if let pack, let entry {
      let slot = named == nil ? level.groundStyle : index
      let ground = try graphicData("ground\(slot)o.dat", entry: entry, pack: pack)
      let graphics = try graphicData("vgagr\(slot).dat", entry: entry, pack: pack)
      if ground != nil || graphics != nil {
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        func fallback(_ name: String) throws -> Data {
          guard let file = files.first(where: { $0.lastPathComponent.lowercased() == name }) else { throw ClassicGraphicsError.missingFile(name) }
          return try Data(contentsOf: file)
        }
        return try ClassicGroundSet(style: index, groundData: ground ?? fallback("ground\(index)o.dat"),
          graphicsArchiveData: graphics ?? fallback("vgagr\(index).dat"))
      }
    }
    return try ClassicGroundSet.load(style: index, from: directory)
  }

  static func specialGraphic(for level: ClassicLevel, entry: Entry, pack: URL, portsRoot: URL) throws -> ClassicSpecialGraphic? {
    guard level.specialStyle != 0 else { return nil }
    let index = level.specialStyle - 1
    if let data = try graphicData("vgaspec\(index).dat", entry: entry, pack: pack) {
      return try ClassicSpecialGraphic(archiveData: data)
    }
    // Some older packs encode a single filename character relative to ASCII zero.
    if (17...42).contains(index), let letter = UnicodeScalar(48 + index),
      let data = try graphicData("vgaspec\(Character(letter)).dat", entry: entry, pack: pack) {
      return try ClassicSpecialGraphic(archiveData: data)
    }
    return try ClassicSpecialGraphic.load(index: index, from: portsRoot.appendingPathComponent("lemmings_dos_1991-07-30"))
  }

  private final class GraphicArchiveIndex: @unchecked Sendable {
    private let lock = NSLock()
    private var cached: [String: (Date?, Int?, [String])] = [:]
    func files(in pack: URL) -> [String] {
      lock.lock(); defer { lock.unlock() }
      let metadata = try? pack.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
      if let saved = cached[pack.path], saved.0 == metadata?.contentModificationDate, saved.1 == metadata?.fileSize {
        return saved.2
      }
      let files = FanLevelLibrary.shell(["/usr/bin/unzip", "-Z1", pack.path]).split(separator: "\n").map(String.init)
      cached[pack.path] = (metadata?.contentModificationDate, metadata?.fileSize, files)
      return files
    }
  }
  private static let graphicArchiveIndex = GraphicArchiveIndex()

  /// Read only assets beside the level or at the archive root. Never extract paths.
  private static func graphicData(_ name: String, entry: Entry, pack: URL) throws -> Data? {
    let parent = (entry.file as NSString).deletingLastPathComponent
    let candidates = parent.isEmpty ? [name] : [parent + "/" + name, name]
    let files = graphicArchiveIndex.files(in: pack)
    for candidate in candidates {
      let matches = files.filter { $0.lowercased() == candidate.lowercased() }
      guard matches.count <= 1 else { throw ClassicGraphicsError.missingFile("Unambiguous " + candidate) }
      if let path = matches.first {
        guard let data = contents(of: path, in: pack) else { throw ClassicGraphicsError.missingFile(path) }
        return data
      }
    }
    return nil
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
    var out = Data()
    while let chunk = try? pipe.fileHandleForReading.read(upToCount: 64 * 1024), !chunk.isEmpty {
      guard out.count + chunk.count <= 4 * 1024 * 1024 else {
        process.terminate(); try? pipe.fileHandleForReading.close(); process.waitUntilExit()
        return nil
      }
      out.append(chunk)
    }
    process.waitUntilExit()
    return process.terminationStatus == 0 && !out.isEmpty ? out : nil
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
