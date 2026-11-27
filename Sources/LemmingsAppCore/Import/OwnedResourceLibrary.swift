import CryptoKit
import Foundation
import NxlvKit

/**
 * Keeps player-owned presentation data outside the installed application.
 */
public struct OwnedResourceLibrary: Sendable {
  public struct Installation: Sendable {
    public let resourcesDirectory: URL
    public let bundleURL: URL
    public let contentID: String
    public let fileCount: Int
    public let bytes: Int64
    public let omittedSourceFiles: [String]
  }

  public typealias Validator = @Sendable (URL) throws -> Void
  private struct Entry: Codable, Equatable {
    let path: String
    let bytes: Int64
    let sha256: String
  }
  private struct Manifest: Codable {
    let schemaVersion: Int
    let kind: String
    let files: [Entry]
    let baseFiles: [Entry]
    let ownedFiles: [Entry]
    let omittedSourceFiles: [String]
  }
  private struct TrustedBaseInventory: Decodable {
    let schemaVersion: Int
    let kind: String
    let files: [Entry]
  }
  private struct Activation: Codable { let schemaVersion: Int; let contentID: String }
  private struct Inventory { var files: [Entry]; var omissions: [String] }
  private enum Payload { case file(URL); case bytes(Data) }
  private struct Identity: Codable { let files: [Entry]; let baseFiles: [Entry]; let ownedFiles: [Entry] }

  static let assetFamilies: Set<String> = ["Ports", "MacArtwork", "AmigaArtwork", "NeoLemmix",
    "Music", "Sounds", "LevelPacks", "About", "MenuArtwork", "MacMusic", "Localization.bundle", "Cursors"]
  private static let protectedNames: Set<String> = ["Hints", "Progression", "Trolley", "GameCenter",
    "AlternativeAssets", "Provenance", "Licences", "OpenStarter", "Integration", "AppIcon.icns",
    "AppIcon.png", "PrivacyInfo.xcprivacy", "store-resources-manifest.json", "personal-preview-resources.json",
    "PERSONAL-PREVIEW-NOTICE.txt", ".DS_Store", ".owned-resource-export.json",
    "ultimate-lemmix-mobile-resources.json", "ultimate-lemmix-data-inventory.json"]
  private static let codeExtensions: Set<String> = ["exe", "com", "bat", "cmd", "sh", "bash", "zsh",
    "py", "pyc", "js", "mjs", "swift", "dylib", "dll", "so", "jar", "class", "wasm", "xpc"]
  private static let manifestName = ".owned-resource-manifest.json"
  private static let activationName = ".active-resource-bundle.json"
  private static let bundleName = "PreservationResources.bundle"
  public static let trustedBaseInventoryName = "ultimate-lemmix-data-inventory.json"
  private static var usesFlatBundle: Bool {
    #if os(iOS) || os(tvOS)
    true
    #else
    false
    #endif
  }
  private static let bundleInfo: [String: String] = ["CFBundleIdentifier": "academy.glasscode.ultimatelemmix.owned-resources",
    "CFBundleName": "Owned preservation resources", "CFBundlePackageType": "BNDL", "CFBundleVersion": "1"]

  let root: URL
  let bundledResources: URL
  private let limits: BYOImportLimits
  private let fileManagerProvider: BYOFileManagerProvider
  private let validator: Validator
  private let bundledResourceInventory: URL?
  private var fileManager: FileManager { fileManagerProvider() }
  private var versions: URL { root.appendingPathComponent("Versions", isDirectory: true) }

  public init(root: URL, bundledResources: URL,
       limits: BYOImportLimits = BYOImportLimits(maximumBytes: 8 * 1_024 * 1_024 * 1_024,
         maximumFileBytes: 1_024 * 1_024 * 1_024, maximumFiles: 50_000),
       fileManager: @escaping BYOFileManagerProvider = { .default },
       validator: @escaping Validator = OwnedResourceLibrary.validateAssets,
       bundledResourceInventory: URL? = nil) {
    self.root = root.standardizedFileURL
    self.bundledResources = bundledResources.standardizedFileURL
    self.limits = limits
    fileManagerProvider = fileManager
    self.validator = validator
    self.bundledResourceInventory = bundledResourceInventory?.standardizedFileURL
  }

  public func installedResourcesDirectory() -> URL? { activeInstallation()?.resourcesDirectory }
  public func installedBundleURL() -> URL? { activeInstallation()?.bundleURL }
  public func installedInstallation() -> Installation? { activeInstallation() }

  /**
   * Checks an existing fixture without copying its media again.
   */
  public func verifyInstalled() throws -> Installation? {
    guard let installation = activeInstallation() else { return nil }
    let manifest = try readManifest(installation.bundleURL.deletingLastPathComponent())
    try verify(installation.resourcesDirectory, files: manifest.files)
    for entry in manifest.ownedFiles {
      try Self.checkAssetFile(installation.resourcesDirectory.appendingPathComponent(entry.path),
        relative: entry.path.split(separator: "/").map(String.init))
    }
    try validator(installation.resourcesDirectory)
    return installation
  }

  /**
   * Rebases retained owned data once when an app update changes trusted assets.
   */
  @discardableResult
  public func refreshBaseIfNeeded() throws -> Installation? {
    guard let (previous, manifest) = activeInstallationAndManifest() else {
      guard !fileManager.fileExists(atPath: root.appendingPathComponent(Self.activationName).path) else {
        throw BYOIntegrationError.invalidManifest
      }
      return nil
    }
    try verify(previous.resourcesDirectory, files: manifest.files)
    let base = try trustedBaseFiles()
    guard base.files != manifest.baseFiles else { return previous }
    return try publish(incoming: [:], omissions: [], base: base)
  }

  /**
   * Merges trusted base data and verified owned selections before activation.
   */
  @discardableResult
  public func install(directory selected: URL) throws -> Installation {
    let source = try sourceResources(selected)
    let sourceParts = source.directory.resolvingSymlinksInPath().pathComponents
    let rootParts = root.resolvingSymlinksInPath().pathComponents
    guard !sourceParts.starts(with: rootParts), !rootParts.starts(with: sourceParts) else {
      throw BYOIntegrationError.unsafePath
    }
    let incoming = try inventory(source.directory, assetsOnly: true, existingApp: source.existingApp)
    guard !incoming.files.isEmpty else { throw BYOIntegrationError.emptyFolder }
    var payloads: [String: (Entry, Payload)] = [:]
    for entry in incoming.files { payloads[entry.path] = (entry, .file(source.directory.appendingPathComponent(entry.path))) }
    if source.existingApp && incoming.files.contains(where: { $0.path == "MacArtwork/lemmings/manifest.json" }) {
      for (name, data) in try NativeCursorRecovery.collect(from: selected) {
        let digest = Self.hex(SHA256.hash(data: data))
        payloads[name] = (Entry(path: name, bytes: Int64(data.count), sha256: digest), .bytes(data))
      }
    }
    return try publish(incoming: payloads, omissions: incoming.omissions)
  }

  private func publish(incoming: [String: (Entry, Payload)], omissions: [String], base preparedBase: Inventory? = nil) throws -> Installation {
    let base = try preparedBase ?? trustedBaseFiles()
    var owned: [String: (Entry, Payload)] = [:]
    var omittedFiles = Set(omissions)
    if let previous = activeInstallation() {
      let manifest = try readManifest(previous.bundleURL.deletingLastPathComponent())
      omittedFiles.formUnion(manifest.omittedSourceFiles)
      for entry in manifest.ownedFiles where incoming[entry.path] == nil {
        guard try Self.isAsset(entry.path) else { throw BYOIntegrationError.invalidManifest }
        let file = previous.resourcesDirectory.appendingPathComponent(entry.path)
        try requireRegularContainedFile(file, within: previous.resourcesDirectory)
        try Self.checkAssetFile(file, relative: entry.path.split(separator: "/").map(String.init))
        guard try hash(file, expectedBytes: entry.bytes) == entry.sha256 else {
          throw BYOIntegrationError.invalidManifest
        }
        owned[entry.path] = (entry, .file(file))
      }
    }
    for (name, value) in incoming { owned[name] = value }
    var effective: [String: (Entry, Payload)] = Dictionary(uniqueKeysWithValues: base.files.map {
      ($0.path, ($0, .file(bundledResources.appendingPathComponent($0.path))))
    })
    for (name, value) in owned { effective[name] = value }
    let files = effective.values.map(\.0).sorted { $0.path < $1.path }
    try checkLimits(files)
    let manifest = Manifest(schemaVersion: 1, kind: "player-owned-preservation-resources", files: files,
      baseFiles: base.files, ownedFiles: owned.values.map(\.0).sorted { $0.path < $1.path }, omittedSourceFiles: omittedFiles.sorted())
    let identity = try contentID(manifest)
    if fileManager.fileExists(atPath: root.path) { try requireDirectory(root) }
    try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
    if fileManager.fileExists(atPath: versions.path) { try requireDirectory(versions) }
    try fileManager.createDirectory(at: versions, withIntermediateDirectories: true)
    let staged = root.appendingPathComponent(".Incoming-" + UUID().uuidString, isDirectory: true)
    defer { try? fileManager.removeItem(at: staged) }
    let bundle = staged.appendingPathComponent(Self.bundleName, isDirectory: true)
    let resources = Self.resourcesDirectory(in: bundle)
    try fileManager.createDirectory(at: resources, withIntermediateDirectories: true)
    for entry in files {
      let target = resources.appendingPathComponent(entry.path)
      try fileManager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
      switch effective[entry.path]!.1 {
      case .file(let origin): try fileManager.copyItem(at: origin, to: target)
      case .bytes(let data): try data.write(to: target, options: .atomic)
      }
      try fileManager.setAttributes([.posixPermissions: 0o644], ofItemAtPath: target.path)
    }
    try PropertyListSerialization.data(fromPropertyList: Self.bundleInfo, format: .xml, options: 0)
      .write(to: Self.infoURL(in: bundle), options: .atomic)
    try verify(resources, files: files)
    try validator(resources)
    let manifestData = try encode(manifest)
    guard manifestData.count <= 32 * 1_024 * 1_024 else { throw BYOIntegrationError.exceedsLimits }
    try manifestData.write(to: staged.appendingPathComponent(Self.manifestName), options: .atomic)
    let destination = versions.appendingPathComponent(identity, isDirectory: true)
    var replacedVersion: URL?
    if fileManager.fileExists(atPath: destination.path) {
      try requireDirectory(destination)
      let existingBundle = destination.appendingPathComponent(Self.bundleName, isDirectory: true)
      do {
        try verifyBundleInfo(existingBundle)
        try verify(Self.resourcesDirectory(in: existingBundle), files: files)
        guard try contentID(readManifest(destination)) == identity else {
          throw BYOIntegrationError.invalidManifest
        }
      } catch {
        let backup = versions.appendingPathComponent(".Previous-" + UUID().uuidString, isDirectory: true)
        try fileManager.moveItem(at: destination, to: backup)
        do { try fileManager.moveItem(at: staged, to: destination) }
        catch {
          do { try fileManager.moveItem(at: backup, to: destination) }
          catch { throw BYOIntegrationError.rollbackFailed(backup.path) }
          throw error
        }
        replacedVersion = backup
      }
    } else {
      try fileManager.moveItem(at: staged, to: destination)
    }
    let activation = Activation(schemaVersion: 1, contentID: identity)
    do {
      try encode(activation).write(to: root.appendingPathComponent(Self.activationName), options: .atomic)
    } catch {
      if let backup = replacedVersion {
        do {
          try fileManager.removeItem(at: destination)
          try fileManager.moveItem(at: backup, to: destination)
        } catch { throw BYOIntegrationError.rollbackFailed(backup.path) }
      }
      throw error
    }
    if let backup = replacedVersion { try? fileManager.removeItem(at: backup) }
    return receipt(destination, id: identity, manifest: manifest)
  }

  /**
   * Checks formats through the readers used by the preservation frontend.
   */
  public static func validateAssets(_ directory: URL) throws {
    let manager = FileManager.default
    for name in ["MacArtwork", "AmigaArtwork"] {
      let base = directory.appendingPathComponent(name)
      guard manager.fileExists(atPath: base.path) else { continue }
      guard let walker = manager.enumerator(at: base, includingPropertiesForKeys: [.isRegularFileKey]) else {
        throw BYOIntegrationError.invalidManifest
      }
      var manifests = 0
      for case let file as URL in walker where file.lastPathComponent == "manifest.json" {
        _ = try ClassicMacArtwork(directory: file.deletingLastPathComponent())
        manifests += 1
      }
      guard manifests > 0 else { throw BYOIntegrationError.invalidManifest }
    }
    let font = directory.appendingPathComponent("Fonts/OriginalLemmings")
    if manager.fileExists(atPath: font.path) {
      let art = try ClassicMacArtwork(directory: font)
      guard Set(art.banks.keys) == Set([1301, 1302]), art.objects.isEmpty,
        art.banks.values.allSatisfy({ $0.count == 95 }),
        art.banks.values.flatMap({ $0 }).compactMap({ $0 }).count == 188 else {
        throw BYOIntegrationError.invalidManifest
      }
    }
    let ports = directory.appendingPathComponent("Ports")
    if manager.fileExists(atPath: ports.path) {
      for game in try manager.contentsOfDirectory(at: ports, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
        guard (try game.resourceValues(forKeys: [.isDirectoryKey])).isDirectory == true else { continue }
        if manager.fileExists(atPath: game.appendingPathComponent("MAIN.DAT").path),
          let names = try? manager.contentsOfDirectory(atPath: game.path),
          names.contains(where: { $0.uppercased().hasPrefix("LEVEL") || $0.uppercased().hasPrefix("DLVEL") || $0.uppercased().hasSuffix(".RSRC") }) {
          try BYOIntegration.validateGame(directory: game, game: .classic)
        }
      }
      if manager.fileExists(atPath: ports.appendingPathComponent("Lemm2").path) {
        try BYOIntegration.validateGame(directory: ports.appendingPathComponent("Lemm2"), game: .lemmings2)
      }
      if manager.fileExists(atPath: ports.appendingPathComponent("LEM3CD").path) {
        try BYOIntegration.validateGame(directory: ports.appendingPathComponent("LEM3CD"), game: .lemmings3)
      }
    }
  }

  private func activeInstallation() -> Installation? { activeInstallationAndManifest()?.0 }

  private func activeInstallationAndManifest() -> (Installation, Manifest)? {
    do {
      try requireDirectory(root); try requireDirectory(versions)
      let url = root.appendingPathComponent(Self.activationName)
      let activation = try JSONDecoder().decode(Activation.self, from: smallData(url))
      guard activation.schemaVersion == 1, Self.validID(activation.contentID) else { return nil }
      let directory = versions.appendingPathComponent(activation.contentID)
      try requireDirectory(directory)
      let manifest = try readManifest(directory)
      guard try contentID(manifest) == activation.contentID,
        manifest.ownedFiles.allSatisfy({ (try? Self.isAsset($0.path)) == true }) else { return nil }
      let receipt = receipt(directory, id: activation.contentID, manifest: manifest)
      try verifyBundleInfo(receipt.bundleURL)
      return (receipt, manifest)
    } catch { return nil }
  }

  private func readManifest(_ directory: URL) throws -> Manifest {
    let value = try JSONDecoder().decode(Manifest.self, from: smallData(directory.appendingPathComponent(Self.manifestName)))
    guard value.schemaVersion == 1, value.kind == "player-owned-preservation-resources" else {
      throw BYOIntegrationError.invalidManifest
    }
    try checkLimits(value.files)
    return value
  }

  private func sourceResources(_ selected: URL) throws -> (directory: URL, existingApp: Bool) {
    let directory = selected.standardizedFileURL
    try requireDirectory(directory)
    if directory.pathExtension.lowercased() == "app" {
      let contents = directory.appendingPathComponent("Contents")
      try requireDirectory(contents)
      let resources = contents.appendingPathComponent("Resources")
      try requireDirectory(resources)
      return (resources, true)
    }
    return (directory, directory.lastPathComponent == "Resources" && directory.deletingLastPathComponent().lastPathComponent == "Contents"
      && directory.deletingLastPathComponent().deletingLastPathComponent().pathExtension.lowercased() == "app")
  }

  private static func isAsset(_ name: String) throws -> Bool {
    let parts = name.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
    guard !parts.isEmpty, !parts.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." || $0.contains("\\")
      || $0.unicodeScalars.contains(where: { $0.value < 32 }) }) else { throw BYOIntegrationError.unsafePath }
    if protectedNames.contains(parts[0]) { return false }
    if parts.count >= 2, parts[0].lowercased() == "ports",
      parts[1].lowercased() == "ultimate_lemmix_starter" { return false }
    if parts[0] == "Fonts" {
      if parts.count == 1 { return true }
      guard parts[1] == "OriginalLemmings" else { throw BYOIntegrationError.unsupportedEntry }
      return true
    }
    guard assetFamilies.contains(parts[0]) else { throw BYOIntegrationError.unsupportedEntry }
    return true
  }

  private func inventory(_ directory: URL, assetsOnly: Bool, existingApp: Bool = false,
                         baseDataOnly: Bool = false, excludingFixedInfo: Bool = false) throws -> Inventory {
    try requireDirectory(directory)
    let keys: Set<URLResourceKey> = [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]
    var failure: Error?
    guard let walker = fileManager.enumerator(at: directory, includingPropertiesForKeys: Array(keys), options: [],
      errorHandler: { _, error in failure = error; return false }) else { throw BYOIntegrationError.notDirectory }
    var files: [Entry] = []; var omissions: [String] = []; var names = Set<String>(); var count = 0
    var total: Int64 = 0
    let base = directory.pathComponents
    for case let file as URL in walker {
      let values = try file.resourceValues(forKeys: keys)
      guard values.isSymbolicLink != true else { throw BYOIntegrationError.symbolicLink }
      let components = file.standardizedFileURL.pathComponents
      guard components.starts(with: base) else { throw BYOIntegrationError.unsafePath }
      let relative = Array(components.dropFirst(base.count)); let name = relative.joined(separator: "/")
      guard relative.count <= limits.maximumDepth else { throw BYOIntegrationError.exceedsLimits }
      if excludingFixedInfo && name == "Info.plist" { continue }
      if baseDataOnly, try !Self.isTrustedBaseData(name) {
        if values.isDirectory == true { walker.skipDescendants() }
        continue
      }
      if assetsOnly && values.isRegularFile == true && Self.omittedSourceFile(name) {
        omissions.append(name); continue
      }
      if assetsOnly, try !Self.isAsset(name) {
        if values.isDirectory == true { walker.skipDescendants() }
        continue
      }
      count += 1
      guard count <= limits.maximumFiles, names.insert(name.lowercased()).inserted else { throw BYOIntegrationError.exceedsLimits }
      if values.isDirectory == true { continue }
      guard values.isRegularFile == true else { throw BYOIntegrationError.unsupportedEntry }
      if baseDataOnly && Self.omittedSourceFile(name) { continue }
      if assetsOnly || baseDataOnly {
        try Self.checkAssetFile(file, relative: relative)
      }
      let size = Int64(values.fileSize ?? 0)
      guard size >= 0, size <= limits.maximumFileBytes, size <= limits.maximumBytes - total else {
        throw BYOIntegrationError.exceedsLimits
      }
      total += size
      files.append(Entry(path: name, bytes: size, sha256: try hash(file, expectedBytes: size)))
    }
    if let failure { throw failure }
    return Inventory(files: files.sorted { $0.path < $1.path }, omissions: omissions.sorted())
  }

  private static func omittedSourceFile(_ path: String) -> Bool {
    let lower = path.lowercased()
    let utilities = ["echo", "why", "iconx", "failat", "holidaylemmings1994", "type", "cd", "run"]
    return utilities.contains(where: { lower == "ports/amiga_extracted/holiday/" + $0 })
      || lower.hasPrefix("ports/lemm2/music/") && lower.hasSuffix(".bin")
      || lower.hasPrefix("ports/lem3cd/") && lower.hasSuffix(".drv")
      || lower.hasPrefix("ports/") && ["icon\r", "openfolderlistdf\r", "icon\r.rsrc", "openfolderlistdf\r.rsrc"]
        .contains(path.split(separator: "/").last.map(String.init)?.lowercased() ?? "")
  }

  private static func checkAssetFile(_ url: URL, relative: [String]) throws {
    guard !omittedSourceFile(relative.joined(separator: "/")), !codeExtensions.contains(url.pathExtension.lowercased()),
      !relative.dropLast().contains(where: { ["app", "framework", "xpc"].contains(URL(fileURLWithPath: $0).pathExtension.lowercased()) }) else {
      throw BYOIntegrationError.unsupportedEntry
    }
    let handle = try FileHandle(forReadingFrom: url)
    defer { try? handle.close() }
    let header = try handle.read(upToCount: 32) ?? Data()
    let signatures: [[UInt8]] = [[0x7f,0x45,0x4c,0x46], [0xfe,0xed,0xfa,0xce], [0xce,0xfa,0xed,0xfe],
      [0xfe,0xed,0xfa,0xcf], [0xcf,0xfa,0xed,0xfe], [0xca,0xfe,0xba,0xbe], [0xbe,0xba,0xfe,0xca],
      [0xca,0xfe,0xba,0xbf], [0xbf,0xba,0xfe,0xca], [0,0,3,0xf3]]
    guard !header.starts(with: [0x4d,0x5a]), !header.starts(with: [0x23,0x21]),
      !signatures.contains(where: { header.starts(with: $0) }) else { throw BYOIntegrationError.unsupportedEntry }
    if relative.first == "Cursors" {
      let pins = ["original-cross.png": "68d2bea78b11e2a115cdb4b752ff8e96d773419910874401d3a76e853d52d200",
        "original-reticule.png": "5985e79a9f75434962a8a5bafef576cfb78d625dc4ffdd74a02cc3b78fbd03aa"]
      guard relative.count == 2, ["original-cross.png", "original-reticule.png"].contains(relative[1]),
        header.starts(with: [137,80,78,71,13,10,26,10]),
        ((try url.resourceValues(forKeys: [.fileSizeKey])).fileSize ?? Int.max) <= 2_000_000,
        hex(SHA256.hash(data: try Data(contentsOf: url))) == pins[relative[1]] else {
        throw BYOIntegrationError.unsupportedEntry
      }
    }
    if relative.prefix(2) == ["Fonts", "OriginalLemmings"] {
      let allowed = ["manifest.json", "NOTICE.txt", "provenance.json"]
      let glyph = url.lastPathComponent.range(of: "^130[12]-([1-9]|[1-8][0-9]|9[0-4])\\.rgba$", options: .regularExpression) != nil
      guard relative.count == 3, allowed.contains(url.lastPathComponent) || glyph else {
        throw BYOIntegrationError.unsupportedEntry
      }
    }
    if relative.first == "Localization.bundle" {
      guard ["strings", "stringsdict", "plist", "json", "png", "rgba", "icns", "txt"].contains(url.pathExtension.lowercased()) else {
        throw BYOIntegrationError.unsupportedEntry
      }
      if url.lastPathComponent == "Info.plist" {
        let info = try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: Any]
        guard info?["CFBundleExecutable"] == nil else { throw BYOIntegrationError.unsupportedEntry }
      }
    }
  }

  private func verify(_ directory: URL, files: [Entry]) throws {
    guard try inventory(directory, assetsOnly: false, excludingFixedInfo: Self.usesFlatBundle).files == files else {
      throw BYOIntegrationError.invalidManifest
    }
  }

  private func checkLimits(_ files: [Entry]) throws {
    var total: Int64 = 0
    guard files.count <= limits.maximumFiles else { throw BYOIntegrationError.exceedsLimits }
    for entry in files {
      guard entry.bytes >= 0, entry.bytes <= limits.maximumFileBytes, entry.bytes <= limits.maximumBytes - total else {
        throw BYOIntegrationError.exceedsLimits
      }
      total += entry.bytes
    }
  }

  /**
   * Uses a signed app-owned data inventory on mobile; code and app identity stay outside the overlay.
   */
  private func trustedBaseFiles() throws -> Inventory {
    guard Self.usesFlatBundle else { return try inventory(bundledResources, assetsOnly: false) }
    let inventoryURL = bundledResourceInventory
      ?? bundledResources.appendingPathComponent(Self.trustedBaseInventoryName)
    if fileManager.fileExists(atPath: inventoryURL.path) {
      let baseParts = bundledResources.pathComponents
      guard inventoryURL.standardizedFileURL.pathComponents.starts(with: baseParts) else {
        throw BYOIntegrationError.unsafePath
      }
      let manifest = try JSONDecoder().decode(TrustedBaseInventory.self, from: smallData(inventoryURL))
      guard manifest.schemaVersion == 1, manifest.kind == "ultimate-lemmix-trusted-base-data" else {
        throw BYOIntegrationError.invalidManifest
      }
      try checkLimits(manifest.files)
      var seen = Set<String>()
      var checkedAncestors = Set<String>()
      for entry in manifest.files {
        guard entry.path.split(separator: "/").count <= limits.maximumDepth else {
          throw BYOIntegrationError.exceedsLimits
        }
        guard try Self.isTrustedBaseData(entry.path), seen.insert(entry.path.lowercased()).inserted else {
          throw BYOIntegrationError.invalidManifest
        }
        let url = bundledResources.appendingPathComponent(entry.path)
        try requireRegularContainedFile(url, within: bundledResources, checkedAncestors: &checkedAncestors)
        try Self.checkAssetFile(url, relative: entry.path.split(separator: "/").map(String.init))
        guard try hash(url, expectedBytes: entry.bytes) == entry.sha256 else {
          throw BYOIntegrationError.invalidManifest
        }
      }
      try checkLimits(manifest.files)
      return Inventory(files: manifest.files.sorted { $0.path < $1.path }, omissions: [])
    }
    return try inventory(bundledResources, assetsOnly: false, baseDataOnly: true)
  }

  private static func isTrustedBaseData(_ name: String) throws -> Bool {
    let parts = name.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
    guard !parts.isEmpty, !parts.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." || $0.contains("\\")
      || $0.unicodeScalars.contains(where: { $0.value < 32 }) }) else { throw BYOIntegrationError.unsafePath }
    let excludedExtensions: Set<String> = ["entitlements", "mobileprovision", "provisionprofile", "xcent", "p12", "key"]
    if excludedExtensions.contains(URL(fileURLWithPath: name).pathExtension.lowercased()) { return false }
    let dataFolders = assetFamilies.union(["Fonts", "Hints", "Progression", "Trolley", "GameCenter",
      "AlternativeAssets", "Provenance", "Licences", "OpenStarter", "Integration", "FanRuntime"])
    let dataFiles: Set<String> = ["AppIcon.png", "AppIcon.icns", "Assets.car", "PrivacyInfo.xcprivacy",
      "store-resources-manifest.json", "personal-preview-resources.json", "PERSONAL-PREVIEW-NOTICE.txt",
      "ultimate-lemmix-mobile-resources.json"]
    if dataFolders.contains(parts[0]) { return true }
    return parts.count == 1 && dataFiles.contains(parts[0])
  }

  private static func resourcesDirectory(in bundle: URL) -> URL {
    usesFlatBundle ? bundle : bundle.appendingPathComponent("Contents/Resources", isDirectory: true)
  }

  private static func infoURL(in bundle: URL) -> URL {
    bundle.appendingPathComponent(usesFlatBundle ? "Info.plist" : "Contents/Info.plist")
  }

  private func verifyBundleInfo(_ bundle: URL) throws {
    try requireDirectory(bundle)
    if !Self.usesFlatBundle { try requireDirectory(bundle.appendingPathComponent("Contents")) }
    try requireDirectory(Self.resourcesDirectory(in: bundle))
    let info = try PropertyListSerialization.propertyList(from: smallData(Self.infoURL(in: bundle)), format: nil)
    guard info as? [String: String] == Self.bundleInfo else { throw BYOIntegrationError.invalidManifest }
  }

  // The signed app base is immutable during this pass. Still check every file independently,
  // and check every ancestor, but do not re-stat the same folders for each contained asset.
  private func requireRegularContainedFile(_ file: URL, within directory: URL,
                                           checkedAncestors: inout Set<String>) throws {
    let file = file.standardizedFileURL
    guard file.pathComponents.starts(with: directory.pathComponents) else { throw BYOIntegrationError.unsafePath }
    let tags = try file.resourceValues(forKeys: [.isSymbolicLinkKey, .isRegularFileKey])
    guard tags.isSymbolicLink != true else { throw BYOIntegrationError.symbolicLink }
    guard tags.isRegularFile == true else { throw BYOIntegrationError.unsupportedEntry }
    var parent = file.deletingLastPathComponent()
    while parent.path != directory.path, !checkedAncestors.contains(parent.path) {
      let tags = try parent.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey])
      guard tags.isSymbolicLink != true else { throw BYOIntegrationError.symbolicLink }
      guard tags.isDirectory == true else { throw BYOIntegrationError.notDirectory }
      checkedAncestors.insert(parent.path)
      parent.deleteLastPathComponent()
    }
  }

  private func requireRegularContainedFile(_ file: URL, within directory: URL) throws {
    guard file.standardizedFileURL.pathComponents.starts(with: directory.pathComponents) else {
      throw BYOIntegrationError.unsafePath
    }
    var current = file
    while current.standardizedFileURL.path != directory.standardizedFileURL.path {
      let values = try current.resourceValues(forKeys: [.isSymbolicLinkKey])
      guard values.isSymbolicLink != true else { throw BYOIntegrationError.symbolicLink }
      current.deleteLastPathComponent()
    }
    let values = try file.resourceValues(forKeys: [.isRegularFileKey])
    guard values.isRegularFile == true else { throw BYOIntegrationError.unsupportedEntry }
  }

  private func requireDirectory(_ directory: URL) throws {
    let values = try directory.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
    guard values.isSymbolicLink != true else { throw BYOIntegrationError.symbolicLink }
    guard values.isDirectory == true else { throw BYOIntegrationError.notDirectory }
  }

  private func smallData(_ url: URL) throws -> Data {
    let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
    guard values.isRegularFile == true, values.isSymbolicLink != true, let size = values.fileSize,
      size <= 32 * 1_024 * 1_024 else { throw BYOIntegrationError.invalidManifest }
    return try Data(contentsOf: url)
  }

  private func hash(_ url: URL, expectedBytes: Int64) throws -> String {
    guard expectedBytes >= 0, expectedBytes <= limits.maximumFileBytes else { throw BYOIntegrationError.exceedsLimits }
    let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
    var value = SHA256(); var count: Int64 = 0
    // Request only the remaining bytes plus an EOF probe, capped at 1 MiB. Most resources are
    // small; avoid allocating a 1 MiB buffer for each small file and its end-of-file check.
    while let data = try handle.read(upToCount: Int(min(1_024 * 1_024, expectedBytes - count + 1))), !data.isEmpty {
      count += Int64(data.count)
      guard count <= expectedBytes else { throw BYOIntegrationError.changedFile(url.lastPathComponent) }
      value.update(data: data)
    }
    guard count == expectedBytes else { throw BYOIntegrationError.changedFile(url.lastPathComponent) }
    return Self.hex(value.finalize())
  }

  private func contentID(_ manifest: Manifest) throws -> String {
    let identity = Identity(files: manifest.files, baseFiles: manifest.baseFiles, ownedFiles: manifest.ownedFiles)
    return Self.hex(SHA256.hash(data: try encode(identity)))
  }
  private static let hexDigits = Array("0123456789abcdef".utf8)
  private static func hex(_ digest: SHA256.Digest) -> String {
    String(unsafeUninitializedCapacity: SHA256.Digest.byteCount * 2) { output in
      var index = 0
      for byte in digest {
        output.initializeElement(at: index, to: hexDigits[Int(byte >> 4)])
        output.initializeElement(at: index + 1, to: hexDigits[Int(byte & 0x0f)])
        index += 2
      }
      return index
    }
  }

  private static func validID(_ id: String) -> Bool { id.count == 64 && id.allSatisfy { "0123456789abcdef".contains($0) } }
  private func encode<T: Encodable>(_ value: T) throws -> Data {
    let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]; return try encoder.encode(value)
  }
  private func receipt(_ directory: URL, id: String, manifest: Manifest) -> Installation {
    let bundle = directory.appendingPathComponent(Self.bundleName, isDirectory: true)
    return Installation(resourcesDirectory: Self.resourcesDirectory(in: bundle),
      bundleURL: bundle, contentID: id, fileCount: manifest.ownedFiles.count,
      bytes: manifest.ownedFiles.reduce(0) { $0 + $1.bytes }, omittedSourceFiles: manifest.omittedSourceFiles)
  }
}
