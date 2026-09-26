import Foundation
import NxlvKit

enum PrecisionZoomScrollOutcome: Equatable {
    case unchanged
    case changed
    case unavailable
}

/**
 * Keeps earned precision uses with the player profile across game modes.
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

    private static func key(_ profileID: String) -> String { "PrecisionZoom.v1.\(profileID)" }

    private var earnings: PrecisionZoomEarnings {
        guard let profileID else { return .init(careerStars: 0, threeStarLevels: 0) }
        if let suppliedEarnings { return suppliedEarnings(profileID) }
        let score = TrolleyCareerScore(profileID: profileID,
            attempts: ArcadeStore.shared.records.trolley.attempts, assisted: false)
        return .init(careerStars: score.stars, threeStarLevels: score.threeStarLevels)
    }

    func start(attemptID: UUID, profileID: String) {
        if self.profileID != profileID {
            self.profileID = profileID
            if let data = defaults.data(forKey: Self.key(profileID)) {
                do { ledger = try JSONDecoder().decode(PrecisionZoomLedger.self, from: data); storageError = nil }
                catch { ledger = PrecisionZoomLedger(); storageError = "Could not read saved Zoom uses." }
            } else { ledger = PrecisionZoomLedger(); storageError = nil }
        }
        guard storageError == nil else { return }
        ledger.start(attemptID: attemptID)
        persist()
    }

    var active: PrecisionZoomKind? { storageError == nil ? ledger.active : nil }
    func remaining(_ kind: PrecisionZoomKind) -> Int {
        storageError == nil ? ledger.remaining(kind, earnings: earnings) : 0
    }
    @discardableResult func toggle(_ kind: PrecisionZoomKind) -> Bool {
        guard storageError == nil, ledger.toggle(kind, earnings: earnings) else { return false }
        persist()
        return storageError == nil
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
        guard storageError == nil, ledger.attemptID == attemptID else { return }
        ledger.finish(didWin: didWin)
        persist()
    }
    func removeProfile(_ profileID: String) {
        defaults.removeObject(forKey: Self.key(profileID))
        if self.profileID == profileID { self.profileID = nil; ledger = PrecisionZoomLedger(); storageError = nil }
    }
    private func persist() {
        guard let profileID else { return }
        do { defaults.set(try JSONEncoder().encode(ledger), forKey: Self.key(profileID)) }
        catch { storageError = "Could not save Zoom uses." }
    }
}
