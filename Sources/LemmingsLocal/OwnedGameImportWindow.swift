#if os(macOS)
import AppKit
import NxlvKit
import LemmingsAppCore
import LemmingsGameArt
import UniformTypeIdentifiers

/**
 * Presents player-owned file import and exports the asset-free helper.
 */
@MainActor final class OwnedGameImportWindow {
  var onInstalled: ((BYOGame, URL) -> Void)?
  var onResourcesInstalled: ((OwnedResourceLibrary.Installation) -> Void)?
  private let library: OwnedGameLibrary
  private let resourceLibrary: OwnedResourceLibrary?
  private var page: GameMenuPage?
  private var task: Task<Void, Never>?

  init(library: OwnedGameLibrary, resourceLibrary: OwnedResourceLibrary? = nil) {
    self.library = library
    self.resourceLibrary = resourceLibrary
  }

  func show(owner: NSWindow) {
    if let page, GameScreen.shared.contains(page) {
      GameScreen.shared.present(page, owner: owner)
      return
    }
    let next = GameMenuPage(title: L10n.text("Import owned games"))
    page = next
    let choice = GamePopUpButton(frame: CGRect(x: 0, y: 290, width: 560, height: 40))
    for game in BYOGame.allCases { choice.addItem(withTitle: game.displayName) }
    choice.setAccessibilityLabel(L10n.text("Game to import"))
    next.body.addSubview(choice)
    let status = GameLabel(wrappingLabelWithString: "")
    status.frame = CGRect(x: 0, y: 170, width: 900, height: 100)
    next.body.addSubview(status)
    var action: NSButton?
    action = next.addPrimaryAction(L10n.text("Choose game folder")) { [weak self, weak next] in
      guard let self, self.task == nil,
        BYOGame.allCases.indices.contains(choice.indexOfSelectedItem) else { return }
      let game = BYOGame.allCases[choice.indexOfSelectedItem]
      let picker = NSOpenPanel()
      picker.canChooseDirectories = true
      picker.canChooseFiles = false
      picker.allowsMultipleSelection = false
      picker.message = L10n.text("Choose your \(game.displayName) folder.")
      self.task = Task { @MainActor [weak self, weak next] in
        guard let self else { return }
        defer { self.task = nil; action?.isEnabled = true }
        guard let source = await GameScreen.shared.chooseFile(picker) else { return }
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        status.stringValue = L10n.text("Importing")
        choice.isEnabled = false
        action?.isEnabled = false
        let store = self.library
        do {
          let installed = try await Task.detached(priority: .userInitiated) {
            try store.install(directory: source, game: game)
          }.value
          if let next { GameScreen.shared.dismiss(next) }
          self.page = nil
          self.onInstalled?(game, installed.directory)
        } catch {
          status.stringValue = error.localizedDescription
          choice.isEnabled = true
        }
      }
    }
    action?.setAccessibilityLabel(L10n.text("Choose a player-owned game folder"))
    if let resourceLibrary {
      next.addSecondaryAction(L10n.text("Restore original assets…")) { [weak self, weak next] in
        guard let self, self.task == nil else { return }
        let picker = NSOpenPanel()
        picker.canChooseDirectories = true
        picker.canChooseFiles = true
        picker.allowsMultipleSelection = false
        picker.message = L10n.text("Choose Ultimate Lemmings.app or a prepared asset folder.")
        self.task = Task { @MainActor [weak self, weak next] in
          guard let self else { return }
          defer { self.task = nil; action?.isEnabled = true; choice.isEnabled = true }
          guard let source = await GameScreen.shared.chooseFile(picker) else { return }
          let scoped = source.startAccessingSecurityScopedResource()
          defer { if scoped { source.stopAccessingSecurityScopedResource() } }
          status.stringValue = L10n.text("Importing resources")
          action?.isEnabled = false
          choice.isEnabled = false
          do {
            let installed = try await Task.detached(priority: .userInitiated) {
              try resourceLibrary.install(directory: source)
            }.value
            if let next { GameScreen.shared.dismiss(next) }
            self.page = nil
            self.onResourcesInstalled?(installed)
          } catch {
            status.stringValue = error.localizedDescription
          }
        }
      }
    }
    next.addSecondaryAction(L10n.text("Get BYO bundle")) { [weak self] in self?.exportBundle() }
    next.onBack = { [weak self, weak next] in
      guard self?.task == nil, let next else { return }
      GameScreen.shared.dismiss(next)
      self?.page = nil
    }
    GameScreen.shared.present(next, owner: owner)
  }

  func exportBundle() {
    guard let source = Bundle.main.resourceURL?
      .appendingPathComponent("Integration/Ultimate-Lemmix-BYO.zip"),
      FileManager.default.isReadableFile(atPath: source.path) else {
      GameScreen.shared.message(L10n.text("BYO bundle unavailable"), detail: L10n.text("This build has no integration guide."))
      return
    }
    let destination = NSSavePanel()
    destination.nameFieldStringValue = source.lastPathComponent
    destination.allowedContentTypes = [.zip]
    guard let owner = GameScreen.shared.gameWindow else { return }
    destination.beginSheetModal(for: owner) { response in
      guard response == .OK, let target = destination.url else { return }
      do {
        try Data(contentsOf: source).write(to: target, options: .atomic)
      } catch {
        GameScreen.shared.message(L10n.text("Cannot save BYO bundle"), detail: error.localizedDescription)
      }
    }
  }
}

#endif
