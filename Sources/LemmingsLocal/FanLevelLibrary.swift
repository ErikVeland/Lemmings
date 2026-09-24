import Foundation
import CryptoKit
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
    private static let identifierVersion = "v2"

    /// A stable level identity. Catalogue numbers survive descriptive filename
    /// changes and keep packs with the same display name separate.
    static func identifier(pack: URL, label: String) -> String {
      stablePrefix(pack) + label
    }

    static func legacyIdentifier(pack: URL, label: String) -> String {
      "\(displayName(of: pack))|\(label)"
    }

    private static func stablePrefix(_ pack: URL) -> String {
      "\(identifierVersion)|\(countKey(pack))|"
    }

    @MainActor private static func savePassed(_ values: Set<String>) {
      UserDefaults.standard.set(
        Array(values).sorted(),
        forKey: ArcadeStore.shared.progressKey(passedKey))
    }

    @MainActor static var passed: Set<String> {
      Set(UserDefaults.standard.stringArray(forKey: ArcadeStore.shared.progressKey(passedKey)) ?? [])
    }

    @MainActor static func record(pack: URL, label: String) {
      var all = passed
      let removedLegacy = all.remove(
        legacyIdentifier(pack: pack, label: label)) != nil
      let inserted = all.insert(identifier(pack: pack, label: label)).inserted
      guard removedLegacy || inserted else { return }
      savePassed(all)
    }

    @MainActor static func hasPassed(pack: URL, label: String) -> Bool {
      let current = identifier(pack: pack, label: label)
      var all = passed
      if all.contains(current) { return true }
      guard all.remove(legacyIdentifier(pack: pack, label: label)) != nil else {
        return false
      }
      all.insert(current)
      savePassed(all)
      return true
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

    static func removeCount(for pack: URL) {
      var all = counts
      guard all.removeValue(forKey: countKey(pack)) != nil else { return }
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
    /**
     * Returns passes that belong to packs currently installed.
     */
    @MainActor static func passedCount(for packs: [URL]) -> Int {
      let all = passed
      let stablePrefixes = Set(packs.map(stablePrefix))
      let currentCount = all.count { saved in
        stablePrefixes.contains { saved.hasPrefix($0) }
      }
      let legacyPacks = Dictionary(
        grouping: packs,
        by: { legacyIdentifier(pack: $0, label: "") })
      let legacyCount = all.count { saved in
        guard !saved.hasPrefix(identifierVersion + "|"),
              let match = legacyPacks.first(where: {
                saved.hasPrefix($0.key)
              }) else { return false }
        let label = String(saved.dropFirst(match.key.count))
        return !match.value.contains { pack in
          all.contains(identifier(pack: pack, label: label))
        }
      }
      return currentCount + legacyCount
    }

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

  /// A stable catalogue identity for a pack, independent of its local folder.
  static func catalogueID(_ url: URL) -> String {
    packID(url).map { "lldb-\($0)" }
      ?? "file-" + url.lastPathComponent.lowercased()
  }

  /// Bundled packs have corpus load, render and run evidence. Other archives
  /// stay explicit and unverified until they gain the same evidence.
  static func catalogueStatus(_ url: URL) -> LevelContentStatus {
    guard let bundledFolder else { return .unverified }
    return url.deletingLastPathComponent().standardizedFileURL == bundledFolder.standardizedFileURL
      ? .playable : .unverified
  }

  /// Identifies the exact archive bytes selected by the browser.
  static func archiveFingerprint(_ url: URL) -> String? {
    guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return nil }
    return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }

  static func archiveMatches(_ url: URL, fingerprint: String) -> Bool {
    archiveFingerprint(url) == fingerprint
  }

  /// Hashes game data by relative path and bytes. Moving an unchanged import
  /// keeps its content fingerprint, while any source change invalidates it.
  static func directoryFingerprint(_ root: URL) -> String? {
    let root = root.resolvingSymlinksInPath().standardizedFileURL
    guard let enumerator = FileManager.default.enumerator(
      at: root,
      includingPropertiesForKeys: [.isRegularFileKey],
      options: [.skipsHiddenFiles]) else { return nil }
    let ignored = Set(["sav", "mp4", "m4a", "wav", "ogg", "mp3", "mod", "mid", "png", "jpg"])
    var entries: [String: String] = [:]
    for case let url as URL in enumerator {
      if Task.isCancelled { return nil }
      if ignored.contains(url.pathExtension.lowercased()) { continue }
      guard (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true,
            let fingerprint = archiveFingerprint(url) else { continue }
      entries[String(url.path.dropFirst(root.path.count))] = fingerprint
    }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    guard !entries.isEmpty, let data = try? encoder.encode(entries) else { return nil }
    return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }

  static func knownLevelCount(in pack: URL) -> Int? {
    Progress.counts[Progress.countKey(pack)]
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
    guard !Task.isCancelled else { return [] }
    let listing = shellResult(["/usr/bin/unzip", "-Z1", pack.path])
    guard listing.status == 0 else { return [] }
    return entries(in: pack, names: listing.output
      .split(separator: "\n").map(String.init).sorted())
  }

  /**
   * Returns decoded entries only after `unzip` verifies the complete archive.
   */
  static func validatedEntries(in pack: URL) throws -> [Entry] {
    try Task.checkCancellation()
    let validation = shellResult(["/usr/bin/unzip", "-tqq", pack.path])
    guard validation.status == 0 else {
      throw NSError(
        domain: "FanLevelLibrary",
        code: 3,
        userInfo: [NSLocalizedDescriptionKey: "The fan level archive could not be verified."])
    }
    try Task.checkCancellation()
    let listing = shellResult(["/usr/bin/unzip", "-Z1", pack.path])
    guard listing.status == 0 else {
      throw NSError(
        domain: "FanLevelLibrary",
        code: 4,
        userInfo: [NSLocalizedDescriptionKey: "The fan level archive could not be listed."])
    }
    return entries(in: pack, names: listing.output
      .split(separator: "\n").map(String.init).sorted())
  }

  private static func entries(in pack: URL, names: [String]) -> [Entry] {
    guard !Task.isCancelled else { return [] }
    var found: [Entry] = []
    for name in names {
      if Task.isCancelled { return [] }
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
          let sections = try? ClassicDATArchive.decode(raw),
          let slots = try? sectionSlots(for: name, count: sections.count, in: pack)
        else { continue }
        for (index, section) in sections.enumerated() {
          if Task.isCancelled { return [] }
          guard section.data.count >= ClassicLevel.recordSize,
            let level = try? ClassicLevel(
              data: section.data.prefix(ClassicLevel.recordSize))
          else { continue }
          let title = level.title.isEmpty ? "\(base) \(index + 1)" : level.title
          found.append(Entry(file: name, section: slots[index], label: title))
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
      let slots = try sectionSlots(for: entry.file, count: sections.count, in: pack)
      guard let index = slots.firstIndex(of: section) else {
        throw FanLevelError.wrongSize(bytes: 0)
      }
      return (
        try ClassicLevel(data: sections[index].data.prefix(ClassicLevel.recordSize)),
        nil)
    }
    return try singleLevel(raw, name: entry.file, includeTextSteel: includeTextSteel)
  }

  /// Pruned DAT archives retain original slot identities for saved queues.
  private static func sectionSlots(for member: String, count: Int, in pack: URL) throws -> [Int] {
    let name = "classic-section-slots.json"
    guard graphicArchiveIndex.files(in: pack).contains(name) else { return Array(0..<count) }
    guard let raw = contents(of: name, in: pack),
          let mappings = try? JSONDecoder().decode([String: [Int]].self, from: raw),
          let slots = mappings[member], slots.count == count,
          Set(slots).count == slots.count, slots.allSatisfy({ (0..<10_000).contains($0) }) else {
      throw NSError(domain: "FanLevelLibrary", code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid archived level slot mapping."])
    }
    return slots
  }

  static func restoredQueue(_ queue: [Entry], index: Int, in pack: URL) throws -> (entries: [Entry], index: Int) {
    let available = Set(entries(in: pack).map { $0.file + "#\($0.section ?? -1)" })
    let retained = queue.enumerated().filter { available.contains($0.element.file + "#\($0.element.section ?? -1)") }
    guard let current = retained.firstIndex(where: { $0.offset == index }) else {
      throw FanLevelError.wrongSize(bytes: 0)
    }
    return (retained.map(\.element), current)
  }

  private static func singleLevel(_ raw: Data, name: String, includeTextSteel: Bool = true) throws -> (ClassicLevel, String?) {
    // Some archived binary levels were given an .ini extension by their author.
    if name.lowercased().hasSuffix(".lvl") || (raw.count == ClassicLevel.recordSize && raw.prefix(32).contains(0)) {
      return (try FanLevelReader.level(fromLVL: raw), nil)
    }
    let text = String(data: raw, encoding: .utf8) ?? (String(data: raw, encoding: .isoLatin1) ?? String(decoding: raw, as: UTF8.self))
    return (try FanLevelReader.level(fromINI: text, includeSteel: includeTextSteel), FanLevelReader.styleName(fromINI: text))
  }

  /// Verified archives that retain release-local graphics slots. Names are not identities.
  /// See Documentation/ReleaseReadiness/FanStyleConventions.md for evidence and scope.
  private static let localStylePacks: [String: (bytes: Int, directory: String)] = [
    "4657df879d7b2e81e52d0f5e5f2d2d15d8d31176be4628dcfa67366c9c1450bc": (8375, "oh_no_more_lemmings_dos-1991-11-14_2232"), // 0477-DOS-Amiga-Tame.zip
    "8d65d85e93e941b486e9543d3b6d4435495d2e56eadb53d744bd1782eb051da6": (10596, "oh_no_more_lemmings_dos-1991-11-14_2232"), // 0478-DOS-Amiga-Crazy.zip
    "9447da45833dc536df6fb4e25fd7dff06423ae5e67a769a9c9e94c9416ba439a": (10598, "oh_no_more_lemmings_dos-1991-11-14_2232"), // 0479-DOS-Amiga-Wild.zip
    "63ab956e498283467aba9a3dd87680abe43f00fd07ae16279a6bfd950c54a0a2": (10497, "oh_no_more_lemmings_dos-1991-11-14_2232"), // 0480-DOS-Amiga-Wicked.zip
    "575f71040f97db65494e2fd5ab5b3a4351fa43073677480e9af4a9881b02d997": (11089, "oh_no_more_lemmings_dos-1991-11-14_2232"), // 0481-DOS-Amiga-Havoc.zip
    "fd76e9ca94eeb1d7a54ca3ae0861efecc9541422a9972c39376d40795b7258be": (2523, "xmas_dos_XmasLemmingsV1.9"), // 0486-DOS-Xmas-1991.zip
    "4361935304ac1fd403c4a5ea63b0a4be415117ff601841b501bac0130e946a91": (2124, "xmas_dos_XmasLemmingsV1.9a1"), // 0487-DOS-Xmas-1992.zip
    "b4cce71d3c06d23b8211c86de6f76ff300331d8adc0c121d3f0924ce4a23037a": (3830, "oh_no_more_lemmings_dos-1991-11-14_2232"), // 0530-Oh-No-More-cLemmings-Tame.zip
    "e7eb1cb2ed4152fe7d0b78cfcfca504b5e526cb53dc1287672410afce8f08585": (5187, "oh_no_more_lemmings_dos-1991-11-14_2232"), // 0531-Oh-No-More-cLemmings-Crazy.zip
    "06cc76ea462e87444c3294ca16d48b06d6df24af0d6e6825df4012b79e26ea5e": (6091, "oh_no_more_lemmings_dos-1991-11-14_2232"), // 0532-Oh-No-More-cLemmings-Wild.zip
    "8473c39f4bf9a6cc9b19dd6d27633e8fa7ccb8e70c52210758f6211bde8f22ba": (5576, "oh_no_more_lemmings_dos-1991-11-14_2232"), // 0533-Oh-No-More-cLemmings-Wicked.zip
    "64cd29e779476667eeb9b20370f45d6c39626711de511685c2ddf354ccd93456": (8316, "oh_no_more_lemmings_dos-1991-11-14_2232"), // 0534-Oh-No-More-cLemmings-Havoc.zip
    "1331231b1a47cc1c92aaa411bbfd05bbabe9b122406c6ab79cc673b8ed23dfd8": (5434, "oh_no_more_lemmings_dos-1991-11-14_2232"), // 0583-Amiga-Oh-No-More-Lemmings-Two-Player.zip
  ]

  private static let holidayStylePacks: [String: (bytes: Int, directory: String)] = [
    "9f0b55e9f63bc1d3b5f931af6cd9881f439aba28aa939e4dd79e74c8e4b847a0": (4533, "holiday_native_1994"), // 0482-DOS-Frost.zip
    "0543b9c913b9999d82112c55561fc37b9e765a299c6dc4ee7dbea6c1db569d9e": (6221, "holiday_native_1994"), // 0483-DOS-Hail.zip
    "e0b4def872bc847330ee71afc5a6e602c97aaefe65f5b0f86d28af0145245339": (2802, "holiday_native_1994"), // 0535-Holiday-cLemmings-Frost.zip
    "982bcf92e698b395415cb59da56b5ad4ac3e4f6224163e64920f0a55218b74a2": (3815, "holiday_native_1994"), // 0536-Holiday-cLemmings-Hail.zip
  ]

  static func localStyleDirectory(in pack: URL, includeHoliday: Bool = false) -> String? {
    let conventions = includeHoliday ? localStylePacks.merging(holidayStylePacks) { current, _ in current } : localStylePacks
    guard let size = (try? pack.resourceValues(forKeys: [.fileSizeKey]))?.fileSize,
          conventions.values.contains(where: { $0.bytes == size }),
          let data = try? Data(contentsOf: pack, options: .mappedIfSafe), data.count == size else { return nil }
    let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    return conventions[hash]?.directory
  }

  /// Custom-level slots span the original five styles, Oh No's four, then Xmas.
  /// Resolve them independently of whichever campaign the player last opened.
  static func groundSet(for level: ClassicLevel, styleName: String?, portsRoot: URL,
                        pack: URL? = nil, entry: Entry? = nil, useLocalStyles: Bool = true, useHolidayStyles: Bool = true) throws -> ClassicGroundSet {
    let names = ["dirt", "fire", "marble", "pillar", "crystal", "brick", "rock", "snow", "bubble", "xmas"]
    let named = styleName?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let name = named ?? (names.indices.contains(level.groundStyle) ? names[level.groundStyle] : "slot \(level.groundStyle)")
    let directory: URL, index: Int
    if named == nil, useLocalStyles, let pack, let local = localStyleDirectory(in: pack, includeHoliday: useHolidayStyles) {
      directory = portsRoot.appendingPathComponent(local); index = level.groundStyle
    } else if name == "xmas" || name == "christmas" {
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
    // unzip treats member arguments as patterns, even without a shell.
    // Duplicate names would concatenate records instead of selecting one file.
    guard graphicArchiveIndex.files(in: pack).filter({ $0 == entry }).count == 1 else { return nil }
    let literal = entry.reduce(into: "") { result, character in
      if "*?[]\\".contains(character) { result.append("\\") }
      result.append(character)
    }
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
    process.arguments = ["-p", pack.path, literal]
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

  private struct ShellResult {
    let output: String
    let status: Int32?
  }

  private static func shellResult(_ arguments: [String]) -> ShellResult {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: arguments[0])
    process.arguments = Array(arguments.dropFirst())
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice
    guard (try? process.run()) != nil else { return ShellResult(output: "", status: nil) }
    let out = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return ShellResult(
      output: String(decoding: out, as: UTF8.self),
      status: process.terminationStatus)
  }

  private static func shell(_ arguments: [String]) -> String {
    shellResult(arguments).output
  }
}
