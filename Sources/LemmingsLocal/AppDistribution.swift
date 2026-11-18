#if os(macOS)
import Foundation
import NxlvKit
import LemmingsAppCore
import LemmingsGameArt
import WidgetKit
import os

/**
 * Keeps the store edition's identity and imported files separate.
 */
enum AppDistribution {
  static var isStore: Bool {
    #if ULTIMATE_LEMMIX_STORE
    true
    #else
    false
    #endif
  }

  static var name: String { isStore ? "Ultimate Lemmix" : "Ultimate Lemmings" }

  /**
   * Shares the selected clock artwork with the separately hosted widget.
   */
  @MainActor static func publishDeskClockArtwork() {
    #if !APP_INTEGRATION_TESTS
    guard isStore else { return }
    do {
      let changed = try GameDeskClockResources.publish(
        resourceURL: GameArtworkSkin.usesLixInterface ? nil : GameResources.resourceURL,
        containerURL: GameDeskClockResources.sharedContainerURL)
      if changed { WidgetCenter.shared.reloadTimelines(ofKind: "DeskClock") }
    } catch {
      Logger(subsystem: "academy.glasscode.ultimatelemmix", category: "resources")
        .error("Could not share Desk Clock artwork: \(error.localizedDescription)")
    }
    #endif
  }

  static var isPersonalPreview: Bool {
    isStore && (Bundle.main.object(forInfoDictionaryKey: "UltimateLemmixPersonalPreview") as? Bool == true)
  }

  static var ownedGamesDirectory: URL {
    #if APP_INTEGRATION_TESTS
    if let path = ProcessInfo.processInfo.environment["LEMMIX_TEST_OWNED_GAMES_DIRECTORY"] {
      return URL(fileURLWithPath: path, isDirectory: true)
    }
    #endif
    return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("Ultimate Lemmix/OwnedGames", isDirectory: true)
  }

  static func ownedDirectory(for game: BYOGame) -> URL? {
    ownedDirectories(for: game).first
  }

  static func ownedDirectories(for game: BYOGame) -> [URL] {
    OwnedGameLibrary(root: ownedGamesDirectory).directories(for: game)
  }

  static var ownedResourceLibrary: OwnedResourceLibrary {
    OwnedResourceLibrary(root: ownedGamesDirectory.appendingPathComponent("ResourceBundles", isDirectory: true),
      bundledResources: Bundle.main.resourceURL ?? Bundle.main.bundleURL)
  }

  static var hasOwnedGames: Bool {
    BYOGame.allCases.contains { ownedDirectory(for: $0) != nil }
      || !BundledGameResources.classicDirectories(in: GameResources.bundle).isEmpty
      || (try? BundledGameResources.lemmings2(in: GameResources.bundle)) != nil
      || (try? BundledGameResources.lemmings3(in: GameResources.bundle)) != nil
  }

  static func lemmings2() throws -> URL {
    if isStore {
      guard let directory = ownedDirectory(for: .lemmings2)
        ?? (try? BundledGameResources.lemmings2(in: GameResources.bundle)) else {
        throw NSError(domain: "UltimateLemmix", code: 2,
          userInfo: [NSLocalizedDescriptionKey: "Import your Lemmings 2 folder from Import Owned Games."])
      }
      return directory
    }
    return try BundledGameResources.lemmings2(in: GameResources.bundle)
  }

  static func lemmings3() throws -> URL {
    if isStore {
      guard let directory = ownedDirectory(for: .lemmings3)
        ?? (try? BundledGameResources.lemmings3(in: GameResources.bundle)) else {
        throw NSError(domain: "UltimateLemmix", code: 3,
          userInfo: [NSLocalizedDescriptionKey: "Import your Lemmings 3 folder from Import Owned Games."])
      }
      return directory
    }
    return try BundledGameResources.lemmings3(in: GameResources.bundle)
  }
}

#endif
