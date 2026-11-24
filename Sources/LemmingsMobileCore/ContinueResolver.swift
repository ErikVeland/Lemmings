import Foundation

/// Home shows one Continue action. This type chooses it from the resumable
/// things that already exist for the selected solo or Hot Seat session.
///
/// The caller supplies only candidates that belong to the selected session.
/// The resolver never reads storage, so it cannot change or delete a save.
public enum ContinueResolver {
    public enum Candidate: Equatable, Sendable {
        /// A saved mid-level attempt that does not belong to a route below.
        case savedLevel(savedAt: Date, owner: String)
        /// The curated Journey. `attemptSavedAt` is set when a mid-level
        /// checkpoint for the Journey's current entry exists.
        case journey(position: Int, total: Int, attemptSavedAt: Date?)
        /// A technique, progression or shuffle run that is not the Journey.
        case sequence(title: String, position: Int, total: Int, attemptSavedAt: Date?)
        /// A favourites or playlist run.
        case playlist(name: String, position: Int, total: Int)

        /// When the player last stopped inside a level of this candidate.
        var attemptSavedAt: Date? {
            switch self {
            case let .savedLevel(savedAt, _): savedAt
            case let .journey(_, _, date), let .sequence(_, _, _, date): date
            case .playlist: nil
            }
        }

        /// Order when no attempt date decides. Lower comes first.
        var rank: Int {
            switch self {
            case .journey: 0
            case .sequence: 1
            case .playlist: 2
            case .savedLevel: 3
            }
        }

        /// The existing action ID that resumes this candidate.
        public var actionID: String {
            switch self {
            case .savedLevel: "resume"
            case .journey: "journey"
            case .sequence: "learningRunResume"
            case .playlist: "runResume"
            }
        }
    }

    public enum Resolution: Equatable, Sendable {
        case resume(Candidate)
        /// No resumable thing exists. Home offers Start journey.
        case startJourney
        /// No resumable thing exists and the Journey is unavailable.
        case none
    }

    /// Chooses the one thing a returning player most likely wants to continue.
    ///
    /// - Parameters:
    ///   - candidates: every resumable thing in the selected session, in any order.
    ///   - journeyAvailable: whether the bundled Journey can start.
    public static func resolve(_ candidates: [Candidate], journeyAvailable: Bool) -> Resolution {
        // A mid-level attempt is the strongest signal: the newest one wins.
        // Without one, the Journey leads, then other routes, then a lone saved level.
        let chosen = candidates.min { lhs, rhs in
            switch (lhs.attemptSavedAt, rhs.attemptSavedAt) {
            case let (l?, r?) where l != r: return l > r
            case (_?, nil): return true
            case (nil, _?): return false
            default: return lhs.rank < rhs.rank
            }
        }
        if let chosen { return .resume(chosen) }
        return journeyAvailable ? .startJourney : .none
    }
}
