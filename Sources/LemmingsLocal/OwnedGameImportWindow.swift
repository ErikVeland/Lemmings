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
  private weak var downloadButton: NSButton?
  private var page: GameMenuPage?
  private var task: Task<Void, Never>?

  init(library: OwnedGameLibrary, resourceLibrary: OwnedResourceLibrary? = nil) {
    self.library = library
    self.resourceLibrary = resourceLibrary
  }

  func show(owner: NSWindow, promptForDownload: Bool = false) {
    if let page, GameScreen.shared.contains(page) {
      GameScreen.shared.present(page, owner: owner)
      if promptForDownload { downloadButton?.performClick(nil) }
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
    weak var action: NSButton?
    var canCancelDownload = false
    let chooseGameFolder: () -> Void = { [weak self, weak next] in
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
    if let resourceLibrary {
      let folder = GameActionButton(title: L10n.text("Choose game folder"), primary: false, onPress: chooseGameFolder)
      folder.frame = CGRect(x: 580, y: 290, width: 380, height: 40)
      next.body.addSubview(folder)
      action = folder
      let startDownload = { [weak self, weak next] in
        guard let self, let next, self.task == nil else { return }
        self.task = Task { @MainActor in
          let controls = DialogKeyboardNavigation().controls(in: next).compactMap { $0 as? NSControl }
          defer {
            self.task = nil
            canCancelDownload = false
            next.backTitle = L10n.text("Back")
            for control in controls { control.isEnabled = true }
          }
          for control in controls where control !== next.controllerBackButton { control.isEnabled = false }
          do {
            let installed = try await GameAssetPack.shared.downloadAndInstall(progress: { phase in
              status.stringValue = phase.title
              if phase.canCancel {
                canCancelDownload = true
                next.backTitle = L10n.text("Cancel")
              } else {
                canCancelDownload = false
                next.controllerBackButton.isEnabled = false
              }
            }) { try resourceLibrary.install(directory: $0) }
            GameScreen.shared.dismiss(next)
            self.page = nil
            self.onResourcesInstalled?(installed)
          } catch {
            status.stringValue = Task.isCancelled ? "" : error.localizedDescription
          }
        }
      }
      let download = next.addPrimaryAction(GameAssetPack.actionTitle) { [weak self, weak next, weak owner] in
        guard let self, self.task == nil, let next, let owner,
          GameScreen.shared.controllerPage(in: owner) === next else { return }
        GameScreen.shared.confirm(GameAssetPack.Licence.title, detail: GameAssetPack.Licence.detail,
          actionTitle: GameAssetPack.Licence.accept, cancelTitle: L10n.text("Cancel"), owner: owner, action: startDownload)
      }
      downloadButton = download
      download.setAccessibilityIdentifier("download.gameAssets")
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
    } else {
      action = next.addPrimaryAction(L10n.text("Choose game folder"), action: chooseGameFolder)
    }
    action?.setAccessibilityLabel(L10n.text("Choose a player-owned game folder"))
    next.addSecondaryAction(L10n.text("Get BYO bundle")) { [weak self] in self?.exportBundle() }
    next.onBack = { [weak self, weak next] in
      if canCancelDownload { self?.task?.cancel(); return }
      guard self?.task == nil, let next else { return }
      GameScreen.shared.dismiss(next)
      self?.page = nil
    }
    GameScreen.shared.present(next, owner: owner)
    if promptForDownload { downloadButton?.performClick(nil) }
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
