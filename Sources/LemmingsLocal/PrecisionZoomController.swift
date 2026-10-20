#if os(macOS)
import Foundation
import LemmingsAppCore
import NxlvKit

enum PrecisionZoomScrollOutcome: Equatable {
    case unchanged
    case changed
    case unavailable
}

/**
 * Keeps free Zoom state and earned Superzoom uses with the player profile.
 */
@MainActor final class PrecisionZoomController {
    static let shared = PrecisionZoomController()
    private let defaults: UserDefaults
    private let suppliedEarnings: ((String) -> PrecisionZoomEarnings)?
    private var profileID: String?
    private var ledger = PrecisionZoomLedger()
    private(set) var storageError: String?

    init(defaults: UserDefaults = .standard,
         earnings: ((String) -> PrecisionZoomEarnings)? = nil) {
        self.defaults = defaults
        suppliedEarnings = earnings
    }

    private static func key(_ profileID: String) -> String { L10n.text("PrecisionZoom.v1.\(profileID)") }

    private var earnings: PrecisionZoomEarnings {
        guard let profileID else { return .init(threeStarLevels: 0) }
        if let suppliedEarnings { return suppliedEarnings(profileID) }
        let score = TrolleyCareerScore(profileID: profileID,
            attempts: ArcadeStore.shared.records.trolley.attempts, assisted: false)
        return .init(threeStarLevels: score.threeStarLevels)
    }

    func start(attemptID: UUID, profileID: String) {
        if self.profileID != profileID {
            self.profileID = profileID
            if let data = defaults.data(forKey: Self.key(profileID)) {
                do { ledger = try JSONDecoder().decode(PrecisionZoomLedger.self, from: data); storageError = nil }
                catch { ledger = PrecisionZoomLedger(); storageError = L10n.text("Could not read saved Superzoom uses.") }
            } else { ledger = PrecisionZoomLedger(); storageError = nil }
        }
        ledger.start(attemptID: attemptID)
        if storageError == nil { persist() }
    }

    var active: PrecisionZoomKind? { (ledger.active == .zoom || storageError == nil) ? ledger.active : nil }
    func remainingSuperzoom() -> Int {
        storageError == nil ? ledger.remainingSuperzoom(earnings: earnings) : 0
    }
    /// Read another result owner's balance without changing the active attempt.
    func remainingSuperzoom(profileID: String) -> Int {
        if self.profileID == profileID { return remainingSuperzoom() }
        let saved: PrecisionZoomLedger
        if let data = defaults.data(forKey: Self.key(profileID)) {
            guard let decoded = try? JSONDecoder().decode(PrecisionZoomLedger.self, from: data) else { return 0 }
            saved = decoded
        } else { saved = PrecisionZoomLedger() }
        let score = TrolleyCareerScore(profileID: profileID,
            attempts: ArcadeStore.shared.records.trolley.attempts, assisted: false)
        let earned = suppliedEarnings?(profileID) ?? .init(threeStarLevels: score.threeStarLevels)
        return saved.remainingSuperzoom(earnings: earned)
    }
    @discardableResult func toggle(_ kind: PrecisionZoomKind) -> Bool {
        guard kind == .zoom || storageError == nil,
              ledger.toggle(kind, earnings: kind == .superzoom ? earnings : .init(superzoomUses: 0)) else { return false }
        if storageError == nil { persist() }
        return kind == .zoom || storageError == nil
    }
    func applyScroll(_ action: PrecisionZoomScrollAction) -> PrecisionZoomScrollOutcome {
        switch action {
        case .zoomIn:
            guard active == nil else { return .unchanged }
            return toggle(.zoom) ? .changed : .unavailable
        case .zoomOut:
            guard let active else { return .unchanged }
            return toggle(active) ? .changed : .unavailable
        }
    }
    func finish(attemptID: UUID, didWin: Bool) {
        guard ledger.attemptID == attemptID else { return }
        ledger.finish(didWin: didWin)
        if storageError == nil { persist() }
    }
    func removeProfile(_ profileID: String) {
        defaults.removeObject(forKey: Self.key(profileID))
        if self.profileID == profileID { self.profileID = nil; ledger = PrecisionZoomLedger(); storageError = nil }
    }
    private func persist() {
        guard let profileID else { return }
        do { defaults.set(try JSONEncoder().encode(ledger), forKey: Self.key(profileID)) }
        catch { storageError = L10n.text("Could not save Superzoom uses.") }
    }
}
#endif
