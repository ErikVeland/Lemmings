import CryptoKit
import Foundation
import NxlvKit

/**
 * Keeps validated player-owned installations alongside the former single roots.
 */
struct OwnedGameLibrary: Sendable {
  struct Installation: Sendable {
    let game: BYOGame
    let directory: URL
    let fileCount: Int
    let bytes: Int64
    let contentID: String
  }

  private struct Manifest: Codable {
    struct Entry: Codable {
      let path: String
      let bytes: Int64
      let sha256: String
    }
    let schemaVersion: Int
    let game: BYOGame
    var files: [Entry]
  }

  let root: URL
  private let limits: BYOImportLimits
  private let fileManagerProvider: BYOFileManagerProvider
  private let validator: BYOContentValidator
  private var fileManager: FileManager { fileManagerProvider() }
  private var installations: URL { root.appendingPathComponent("Installations", isDirectory: true) }

  init(root: URL, limits: BYOImportLimits = BYOImportLimits(),
       fileManager: @escaping BYOFileManagerProvider = { .default },
       validator: @escaping BYOContentValidator = BYOIntegration.validateGame) {
    self.root = root.standardizedFileURL
    self.limits = limits
    fileManagerProvider = fileManager
    self.validator = validator
  }

  /**
   * Lists recorded locations without hashing all commercial files during launch.
   */
  func directories(for game: BYOGame) -> [URL] {
    recordedRoots(for: game).compactMap { integration(at: $0).installedDirectory(for: game) }
  }

  /**
   * Validates a staged import before publishing it under its verified content key.
   */
  @discardableResult
  func install(directory source: URL, game: BYOGame) throws -> Installation {
    let sourceParts = source.resolvingSymlinksInPath().pathComponents
    let rootParts = root.resolvingSymlinksInPath().pathComponents
    guard !sourceParts.starts(with: rootParts), !rootParts.starts(with: sourceParts) else {
      throw BYOIntegrationError.unsafePath
    }
    if fileManager.fileExists(atPath: root.path) { try requireDirectory(root) }
    try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
    let stagedRoot = root.appendingPathComponent(".Incoming-" + UUID().uuidString, isDirectory: true)
    defer { try? fileManager.removeItem(at: stagedRoot) }
    let staged = try integration(at: stagedRoot).install(directory: source, game: game)
    let key = try contentID(directory: staged.directory, game: game)

    for container in recordedRoots(for: game) {
      let store = integration(at: container)
      guard let directory = store.installedDirectory(for: game),
        (try? contentID(directory: directory, game: game)) == key else { continue }
      if let verified = try? store.verifyInstalled(game: game) {
        return receipt(verified, contentID: key)
      }
      // An explicit reimport repairs only this recorded installation.
      return receipt(try store.install(directory: staged.directory, game: game), contentID: key)
    }

    if fileManager.fileExists(atPath: installations.path) { try requireDirectory(installations) }
    try fileManager.createDirectory(at: installations, withIntermediateDirectories: true)
    let destination = installations.appendingPathComponent(key, isDirectory: true)
    if fileManager.fileExists(atPath: destination.path) {
      try requireDirectory(destination)
      return receipt(try integration(at: destination).install(directory: staged.directory, game: game), contentID: key)
    }
    do {
      try fileManager.moveItem(at: stagedRoot, to: destination)
    } catch {
      // A concurrent identical import may have published this key first.
      if let verified = try? integration(at: destination).verifyInstalled(game: game),
        (try? contentID(directory: verified.directory, game: game)) == key {
        return receipt(verified, contentID: key)
      }
      throw error
    }
    return Installation(game: game, directory: destination.appendingPathComponent(game.rawValue, isDirectory: true),
      fileCount: staged.fileCount, bytes: staged.bytes, contentID: key)
  }

  private func integration(at directory: URL) -> BYOIntegration {
    BYOIntegration(root: directory, limits: limits, fileManager: fileManagerProvider, validator: validator)
  }

  private func recordedRoots(for game: BYOGame) -> [URL] {
    guard (try? requireDirectory(root)) != nil else { return [] }
    var result: [URL] = integration(at: root).installedDirectory(for: game) == nil ? [] : [root]
    guard (try? requireDirectory(installations)) != nil,
      let candidates = try? fileManager.contentsOfDirectory(at: installations,
        includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey], options: [.skipsHiddenFiles]) else { return result }
    for directory in candidates.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
      let key = directory.lastPathComponent
      guard key.count == 64, key.allSatisfy({ "0123456789abcdef".contains($0) }),
        (try? requireDirectory(directory)) != nil,
        let installed = integration(at: directory).installedDirectory(for: game),
        (try? contentID(directory: installed, game: game)) == key else { continue }
      result.append(directory)
    }
    return result
  }

  private func contentID(directory: URL, game: BYOGame) throws -> String {
    let url = directory.appendingPathComponent(BYOIntegration.manifestName)
    let properties = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
    guard properties.isRegularFile == true, properties.isSymbolicLink != true,
      let size = properties.fileSize, size <= 32 * 1_024 * 1_024 else { throw BYOIntegrationError.invalidManifest }
    var manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: url))
    guard manifest.schemaVersion == 1, manifest.game == game, !manifest.files.isEmpty,
      manifest.files.count <= limits.maximumFiles else { throw BYOIntegrationError.invalidManifest }
    manifest.files.sort { $0.path < $1.path }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return SHA256.hash(data: try encoder.encode(manifest)).map { String(format: "%02x", $0) }.joined()
  }

  private func requireDirectory(_ directory: URL) throws {
    let values = try directory.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
    guard values.isSymbolicLink != true else { throw BYOIntegrationError.symbolicLink }
    guard values.isDirectory == true else { throw BYOIntegrationError.notDirectory }
  }

  private func receipt(_ value: BYOInstalledContent, contentID: String) -> Installation {
    Installation(game: value.game, directory: value.directory, fileCount: value.fileCount,
      bytes: value.bytes, contentID: contentID)
  }
}
