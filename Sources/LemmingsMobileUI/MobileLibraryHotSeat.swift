#if os(iOS) || os(tvOS)
import LemmingsGameArt
import NxlvKit
import LemmingsMobileCore
import UIKit

/// Hot Seat: two or more players take turns in one shared campaign.
extension MobileLibraryViewController {
    var hotSeat: MobileHotSeat? { hotSeats.current }

    var defaultHotSeatPlayers: [String] {
        hotSeat?.players ?? [profiles.activeID] + profiles.players.filter { $0.id != profiles.activeID }.prefix(1).map(\.id)
    }

    /// Appended to a progress key. A shared campaign has its own, apart from every solo player.
    var progressSuffix: String { hotSeat.map { "." + $0.scope } ?? profiles.suffix }

    @discardableResult func saveHotSeats() -> Bool {
        let storage = MobileStorage.standard(profile: "_players")
        do { try hotSeats.save(to: storage); arcadeStore.notifyProgressChanged(); return true }
        catch {
            hotSeats = MobileHotSeatStore.load(from: storage)
            notice = error.localizedDescription
            return false
        }
    }

    func playerName(_ id: String) -> String { profiles.players.first { $0.id == id }?.name ?? L10n.text("Player") }

    /// Names the player on a result button. The bitmap lettering is wide, so long names are clipped.
    private func short(_ id: String) -> String { String(playerName(id).prefix(9)) }

    /// The turn a level is played under, or nil in solo play.
    func currentTurn() -> MobileGameTurn? {
        guard let seat = hotSeat else { return nil }
        return MobileGameTurn(scope: seat.scope, owner: seat.turn, ownerName: playerName(seat.turn),
                              ownerPortrait: profiles.players.first { $0.id == seat.turn }?.portrait ?? 0) { [weak self] win in
            seat.choices(didWin: win).map { choice in
                let name = self?.short(choice.player) ?? ""
                let label = choice.kind == .next ? L10n.text("Next: \(name)") : L10n.text("Retry: \(name)")
                return (label, choice)
            }
        }
    }

    /// Hands the turn to a player and saves it, so a relaunch resumes with them.
    @discardableResult func handOver(to player: String) -> Bool {
        guard arcadeStore.storageError == nil, var seat = hotSeat else { return false }
        seat.pass(to: player)
        hotSeats.update(seat)
        guard saveHotSeats() else { return false }
        MobileSettings.activateProfile(seat.turn, in: .standard)
        libraryInput.reset()
        return true
    }

    // MARK: - Pages

    func hotSeatPage(subtitle: String) -> GameFrontEnd.Page {
        let roster = hotSeatRoster ?? MobileHotSeatRoster(host: profiles.activeID, players: defaultHotSeatPlayers)
        return MobileCareerArt.hotSeat(profiles, subtitle: subtitle, roster: roster, policy: hotSeats.policy,
            active: hotSeat != nil, hasSaved: !hotSeats.sharedSessions(player: profiles.activeID).isEmpty,
            confirmingRestart: confirmingRestart)
    }

    func savedHotSeatsPage(subtitle: String) -> GameFrontEnd.Page {
        let rows = hotSeats.sharedSessions(player: profiles.activeID).map { seat -> GameFrontEnd.Action in
            let names = seat.players.map { String(playerName($0).prefix(6)) }.joined(separator: " ")
            return .init("seatResume." + seat.id, names)
        }
        return .init(title: L10n.text("Saved Hot Seats"), subtitle: subtitle, rows: rows, footer: [.init("hotSeat", L10n.text("Back"))])
    }

    // MARK: - Actions

    /// Handles the Hot Seat actions. Returns false for any other action.
    func handleHotSeat(_ id: String) -> Bool {
        switch id {
        case "hotSeat":
            if route != .hotSeat && route != .hotSeats { hotSeatBackRoute = route }
            if hotSeat == nil, let saved = hotSeats.sharedSessions(player: profiles.activeID).first {
                guard resumeSharedSeat(saved.id) else { rebuild(); return true }
            }
            confirmingRestart = false
            navigate(.hotSeat)
        case "seatBack":
            hotSeatRoster = nil
            confirmingRestart = false
            navigate(hotSeatBackRoute)
        case "seatNew":
            newPlayer()
        case "seatRule":
            hotSeats.policy = hotSeats.policy.other
            if var seat = hotSeat { seat.policy = hotSeats.policy; hotSeats.update(seat) }
            saveHotSeats()
            rebuild()
        case "seatSaved": navigate(.hotSeats)
        case "seatStart": startHotSeat()
        case "seatRestart":
            if !confirmingRestart { confirmingRestart = true; rebuild(); break }
            confirmingRestart = false
            _ = hotSeats.restart()
            guard saveHotSeats() else { rebuild(); break }
            leaveHotSeatPage()
        case "seatSolo":
            hotSeats.endSession()
            guard saveHotSeats() else { rebuild(); break }
            hotSeatRoster = nil
            reloadPlayerData()
            navigate(.home)
        case "seatOther": resumeOtherSession()
        default:
            if id.hasPrefix("seat."), case let key = String(id.dropFirst(5)), profiles.players.contains(where: { $0.id == key }) {
                if hotSeatRoster == nil {
                    hotSeatRoster = MobileHotSeatRoster(host: profiles.activeID, players: defaultHotSeatPlayers)
                }
                hotSeatRoster?.toggle(key)
                confirmingRestart = false
                rebuild()
            } else if id.hasPrefix("seatResume.") {
                guard resumeSharedSeat(String(id.dropFirst(11))) else { rebuild(); return true }
                hotSeatRoster = nil
                leaveHotSeatPage()
            } else { return false }
        }
        return true
    }
    func resumeSharedSeat(_ id: String) -> Bool {
        let previousSeats = hotSeats, previousProfiles = profiles
        guard let seat = hotSeat?.id == id ? hotSeat : hotSeats.resume(id: id) else { return false }
        profiles.select(seat.host)
        guard saveProfiles(), saveHotSeats() else {
            hotSeats = previousSeats; profiles = previousProfiles
            _ = saveProfiles()
            return false
        }
        reloadPlayerData()
        return true
    }

    /// Keeps the running session when the roster is unchanged. Otherwise a new shared campaign starts.
    private func startHotSeat() {
        guard let roster = hotSeatRoster, roster.canStart else { return }
        if let seat = hotSeat, Set(seat.players) == Set(roster.players) {
            // The same players continue where they stopped.
        } else {
            guard hotSeats.start(roster: roster) != nil else { return }
        }
        guard saveHotSeats() else { rebuild(); return }
        leaveHotSeatPage()
    }

    private func leaveHotSeatPage() {
        hotSeatRoster = nil
        pendingCheckpoint = nil
        reloadPlayerData()
        navigate(.home)
    }

    /// A saved level belongs to another session. Switching to that session lets it resume.
    private func resumeOtherSession() {
        guard let checkpoint = pendingCheckpoint else { return }
        if let scope = checkpoint.scope, scope.hasPrefix("hotseat.") {
            guard resumeSharedSeat(String(scope.dropFirst(8))) else {
                if notice.isEmpty { notice = L10n.text("That Hot Seat is no longer saved.") }
                rebuild(); return
            }
        } else {
            hotSeats.endSession()
            let owner = checkpoint.owner ?? MobileProfiles.defaultID
            guard profiles.players.contains(where: { $0.id == owner }) else {
                notice = L10n.text("That player is no longer saved."); rebuild(); return
            }
            profiles.select(owner)
            guard saveProfiles() else { rebuild(); return }
        }
        guard saveHotSeats() else { rebuild(); return }
        reloadPlayerData()
        pendingCheckpoint = checkpoint
        resumeSavedRun()
    }

    /// True when a saved level can resume in the session that is open now.
    func checkpointMatchesSession(_ checkpoint: MobileCheckpointEnvelope) -> Bool {
        guard checkpoint.scope == hotSeat?.scope else { return false }
        if let seat = hotSeat { return checkpoint.owner.map(seat.players.contains) ?? true }
        return checkpoint.owner.map { $0 == profiles.activeID } ?? (profiles.activeID == MobileProfiles.defaultID)
    }

    func otherSessionTitle(for checkpoint: MobileCheckpointEnvelope) -> String {
        checkpoint.scope == nil ? L10n.text("Resume solo run") : L10n.text("Resume Hot Seat run")
    }

    /// Players who were deleted leave the sessions they were in.
    func removeFromHotSeats(_ player: String) {
        hotSeats.removePlayer(player)
        hotSeatRoster = nil
        saveHotSeats()
    }
}
#endif
