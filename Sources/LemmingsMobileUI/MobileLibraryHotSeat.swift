#if os(iOS)
import LemmingsGameArt
import LemmingsMobileCore
import UIKit

/// Hot Seat: two or more players take turns in one shared campaign.
extension MobileLibraryViewController {
    var hotSeat: MobileHotSeat? { hotSeats.current }

    /// Appended to a progress key. A shared campaign has its own, apart from every solo player.
    var progressSuffix: String { hotSeat.map { "." + $0.scope } ?? profiles.suffix }

    func saveHotSeats() { try? hotSeats.save(to: MobileStorage.standard(profile: "_players")) }

    func playerName(_ id: String) -> String { profiles.players.first { $0.id == id }?.name ?? "Player" }

    /// Names the player on a result button. The bitmap lettering is wide, so long names are clipped.
    private func short(_ id: String) -> String { String(playerName(id).prefix(9)) }

    /// The turn a level is played under, or nil in solo play.
    func currentTurn() -> MobileGameTurn? {
        guard let seat = hotSeat else { return nil }
        return MobileGameTurn(scope: seat.scope, owner: seat.turn, ownerName: playerName(seat.turn)) { [weak self] win in
            seat.choices(didWin: win).map { choice in
                let name = self?.short(choice.player) ?? ""
                let label = choice.kind == .next ? "Next: \(name)" : "Retry: \(name)"
                return (label, choice)
            }
        }
    }

    /// Hands the turn to a player and saves it, so a relaunch resumes with them.
    func handOver(to player: String) {
        guard var seat = hotSeat else { return }
        seat.pass(to: player)
        hotSeats.update(seat)
        saveHotSeats()
    }

    // MARK: - Pages

    func hotSeatPage(subtitle: String) -> GameFrontEnd.Page {
        let roster = hotSeatRoster ?? MobileHotSeatRoster(host: profiles.activeID, players: hotSeat?.players ?? [])
        var rows = profiles.players.map { player in
            GameFrontEnd.Action("seat." + player.id, player.name, selected: roster.contains(player.id))
        }
        rows.append(.init("seatNew", "New player", enabled: profiles.players.count < MobileProfiles.maximum))
        rows.append(.init("seatRule", "Turns: \(hotSeats.policy.title)"))
        if !hotSeats.resumable(host: profiles.activeID).isEmpty {
            rows.append(.init("seatSaved", "Saved Hot Seats"))
        }
        if hotSeat != nil {
            rows.append(.init("seatRestart", confirmingRestart ? "Confirm new Hot Seat" : "New Hot Seat", selected: confirmingRestart))
            rows.append(.init("seatSolo", "Return to solo"))
        }
        return .init(title: "Hot Seat", subtitle: subtitle, rows: rows,
                     footer: [.init("settings", "Back"),
                              .init("seatStart", "Choose a game", enabled: roster.canStart, primary: roster.canStart)])
    }

    func savedHotSeatsPage(subtitle: String) -> GameFrontEnd.Page {
        let rows = hotSeats.resumable(host: profiles.activeID).map { seat -> GameFrontEnd.Action in
            let names = seat.players.map { String(playerName($0).prefix(6)) }.joined(separator: " ")
            return .init("seatResume." + seat.id, names)
        }
        return .init(title: "Saved Hot Seats", subtitle: subtitle, rows: rows, footer: [.init("hotSeat", "Back")])
    }

    // MARK: - Actions

    /// Handles the Hot Seat actions. Returns false for any other action.
    func handleHotSeat(_ id: String) -> Bool {
        switch id {
        case "hotSeat":
            if hotSeatRoster == nil { hotSeatRoster = MobileHotSeatRoster(host: profiles.activeID, players: hotSeat?.players ?? []) }
            confirmingRestart = false
            navigate(.hotSeat)
        case "seatNew":
            guard let created = profiles.add(name: "Player \(profiles.players.count + 1)") else { break }
            saveProfiles()
            hotSeatRoster?.toggle(created)
            rebuild()
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
            saveHotSeats()
            leaveHotSeatPage()
        case "seatSolo":
            hotSeats.endSession()
            saveHotSeats()
            hotSeatRoster = nil
            activeRun = nil
            navigate(.home)
        case "seatOther": resumeOtherSession()
        default:
            if id.hasPrefix("seat."), case let key = String(id.dropFirst(5)), profiles.players.contains(where: { $0.id == key }) {
                hotSeatRoster?.toggle(key)
                confirmingRestart = false
                rebuild()
            } else if id.hasPrefix("seatResume."), hotSeats.resume(id: String(id.dropFirst(11))) != nil {
                saveHotSeats()
                hotSeatRoster = nil
                leaveHotSeatPage()
            } else { return false }
        }
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
        saveHotSeats()
        leaveHotSeatPage()
    }

    private func leaveHotSeatPage() {
        hotSeatRoster = nil
        activeRun = nil
        pendingCheckpoint = nil
        loadCheckpoint()
        navigate(.home)
    }

    /// A saved level belongs to another session. Switching to that session lets it resume.
    private func resumeOtherSession() {
        guard let checkpoint = pendingCheckpoint else { return }
        if let scope = checkpoint.scope, scope.hasPrefix("hotseat.") {
            guard hotSeat?.scope == scope || hotSeats.resume(id: String(scope.dropFirst(8))) != nil else {
                notice = "That Hot Seat is no longer saved."; rebuild(); return
            }
        } else {
            hotSeats.endSession()
        }
        saveHotSeats()
        activeRun = nil
        rebuild()
    }

    /// True when a saved level can resume in the session that is open now.
    func checkpointMatchesSession(_ checkpoint: MobileCheckpointEnvelope) -> Bool {
        checkpoint.scope == hotSeat?.scope
    }

    func otherSessionTitle(for checkpoint: MobileCheckpointEnvelope) -> String {
        checkpoint.scope == nil ? "Resume solo run" : "Resume Hot Seat run"
    }

    /// Players who were deleted leave the sessions they were in.
    func removeFromHotSeats(_ player: String) {
        hotSeats.removePlayer(player)
        hotSeatRoster = nil
        saveHotSeats()
    }
}
#endif
