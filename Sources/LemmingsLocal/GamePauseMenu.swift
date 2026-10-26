#if os(macOS)
import AppKit
import LemmingsAppCore
import NxlvKit

/// Pause and results charge the attempt owner, including during Hot Seat play.
@MainActor struct PauseLevelSkip {
    let level: ArcadeLevel
    let profileID: String
    var prepare: (() throws -> Void)?
    var handlesHandover = false
    let advance: () -> Void

    var balance: Int { ArcadeStore.shared.records.levelSkips(profileID: profileID).available }
    var title: String {
        let store = ArcadeStore.shared
        if store.hotSeatIsActive, let player = store.records.profile(profileID) {
            return L10n.text("Skip as \(player.initials) (\(balance))")
        }
        return L10n.text("Skip level (\(balance))")
    }
    var enabled: Bool {
        let store = ArcadeStore.shared
        return balance > 0 && store.profilesAreWritable && store.storageError == nil
            && !store.records.hasSkipped(level, profileID: profileID)
    }
    func perform(owner: NSWindow?, dismiss: () -> Void) throws {
        guard enabled else { return }
        let store = ArcadeStore.shared
        guard store.spendLevelSkip(on: level, profileID: profileID) else { return }
        do { try prepare?() }
        catch {
            _ = store.returnLevelSkip(on: level, profileID: profileID)
            throw error
        }
        let hotSeat = store.hotSeatIsActive
        if hotSeat { _ = store.passSessionTurn(after: profileID) }
        let next = hotSeat ? store.records.profile(store.playingProfileID) : nil
        dismiss()
        advance()
        if let next, !handlesHandover {
            ArcadeWindow.shared.arcadeView.showHandover(next, owner: owner)
        }
    }
}

@MainActor enum GamePauseMenu {
    static func page(title: String, resume: @escaping () -> Void, retry: @escaping () -> Void,
                     hints: @escaping () -> Void, later: (() -> Void)? = nil,
                     skip: PauseLevelSkip? = nil, leave: @escaping () -> Void) -> GameMenuPage {
        let page = GameMenuPage(title: L10n.text("Paused"), subtitle: title)
        let close = { [weak page] in if let page { GameScreen.shared.dismiss(page) } }
        page.addListAction(L10n.text("Retry level"), at: 0, section: L10n.text("Level")) { close(); retry() }
        page.addListAction(L10n.text("Hints"), at: 1) { close(); hints() }
        if let later { page.addListAction(L10n.text("Try later"), at: 2) { close(); later() } }
        if let skip {
            let button = page.addListAction(skip.title, at: 3) { [weak page] in
                guard let page else { return }
                do { try skip.perform(owner: page.window) { GameScreen.shared.dismiss(page) } }
                catch { page.setDetail(error.localizedDescription) }
            }
            button.isEnabled = skip.enabled
        }
        page.backTitle = L10n.text("Back to library")
        let resumeAction = { close(); resume() }
        page.addPrimaryAction(L10n.text("Resume"), action: resumeAction)
        page.onBack = { close(); leave() }
        return page
    }
}
#endif
