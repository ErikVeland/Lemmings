#if os(tvOS)
import Foundation
import LemmingsMobileCore
import LemmingsTVCore
import UIKit

extension MobileLibraryViewController {
    private var tvSaveRoot: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("Ultimate Lemmings")
    }
    func handleTVSaveBackup(_ id: String) -> Bool {
        switch id {
        case "syncTVBackup":
            guard game == nil, !syncBusy else { return true }
            syncBusy = true; rebuild()
            Task { [weak self] in
                guard let self else { return }
                do {
                    let preferences = try TVSaveBackup.capturePreferences(defaults: .standard)
                    let root = tvSaveRoot
                    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("TVBackup-" + UUID().uuidString)
                    let file = try await Task.detached(priority: .utility) {
                        let saved = try TVSaveBackup.capture(root: root, preferences: preferences)
                        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                        let file = folder.appendingPathComponent("Ultimate Lemmings TV.lemmingstv")
                        try saved.encoded().write(to: file, options: .atomic)
                        return file
                    }.value
                    if route == .cloudSaves, game == nil {
                        MobileTVFileTransfer.exportFile(file, from: self) { try? FileManager.default.removeItem(at: folder) }
                    } else { try? FileManager.default.removeItem(at: folder) }
                } catch { syncMessage = error.localizedDescription }
                syncBusy = false; rebuild()
            }
        case "syncTVRestore":
            guard game == nil else { return true }
            MobileTVFileTransfer.importFiles(from: self, directory: false, name: "TV saves") { [weak self] file in
                defer { MobileTVFileTransfer.removeImportedFiles(file) }
                guard let self else { return }
                do {
                    let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? TVSaveBackup.maximumBytes + 1
                    guard size <= TVSaveBackup.maximumBytes else { throw MobileCheckpointError.tooLarge }
                    tvBackupDraft = try TVSaveBackup.decode(Data(contentsOf: file))
                } catch { syncMessage = error.localizedDescription }
                rebuild()
            }
        case "syncTVRestoreCancel": tvBackupDraft = nil; rebuild()
        case "syncTVRestoreConfirm":
            guard game == nil, let backup = tvBackupDraft else { return true }
            do {
                try backup.restore(root: tvSaveRoot, defaults: .standard)
                tvBackupDraft = nil
                view.window?.rootViewController = LemmingsMobileApplication.makeRootViewController()
            } catch { syncMessage = error.localizedDescription; tvBackupDraft = nil; rebuild() }
        default: return false
        }
        return true
    }
}
#endif
