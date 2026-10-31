#if os(macOS) || os(iOS)
import Foundation
@preconcurrency import GameKit
#if os(iOS)
import UIKit
public typealias GameProgressAuthenticationController = UIViewController
#else
import AppKit
public typealias GameProgressAuthenticationController = NSViewController
#endif

// GameKit's read-only saved-game handles cross its callback queue once. All
// access to these handles, including loadData, stays on the main actor.
private struct SavedGameHandles: @unchecked Sendable { let games: [GKSavedGame] }

@MainActor public final class AppleGameProgressTransport: NSObject, GameProgressTransport, GKLocalPlayerListener {
    nonisolated public static let containerIdentifier = "iCloud.academy.glasscode.lemmings"
    public let available: Bool
    public var onChange: (@MainActor () -> Void)?
    public var onAuthenticationChange: (@MainActor (Bool) -> Void)?
    public private(set) var isAuthenticating = false
    private var versions: [String: [GKSavedGame]] = [:]
    private var conflicts: [String: [GKSavedGame]] = [:]
    private var authenticationObserver: NSObjectProtocol?
    public var accountID: String? {
        let player = GKLocalPlayer.local
        guard available, player.isAuthenticated, player.scopedIDsArePersistent() else { return nil }
        return player.teamPlayerID
    }
    public override init() {
        available = Bundle.main.object(forInfoDictionaryKey: "LemmingsCloudProgressEnabled") as? Bool == true
            && ProcessInfo.processInfo.environment["LEMMINGS_TEST_AUDIO"] != "muted"
        super.init()
    }
    public func start(present: @escaping @MainActor (GameProgressAuthenticationController) -> Void = { _ in }) {
        guard available, authenticationObserver == nil else { return }
        isAuthenticating = true
        onAuthenticationChange?(true)
        GKLocalPlayer.local.register(self)
        authenticationObserver = NotificationCenter.default.addObserver(forName: .GKPlayerAuthenticationDidChangeNotificationName,
            object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.versions.removeAll(); self?.conflicts.removeAll(); self?.onChange?() }
            }
        GKLocalPlayer.local.authenticateHandler = { [weak self] controller, _ in
            Task { @MainActor in
                if let controller { present(controller) }
                else {
                    if self?.isAuthenticating == true {
                        self?.isAuthenticating = false
                        self?.onAuthenticationChange?(false)
                    }
                    self?.onChange?()
                }
            }
        }
        onChange?()
    }
    public func load(name: String) async throws -> [Data] {
        guard let owner = accountID else { throw URLError(.userAuthenticationRequired) }
        let fetched = try await GKLocalPlayer.local.fetchSavedGames().filter { $0.name == name }
        guard accountID == owner else { throw URLError(.cancelled) }
        let saved = fetched + (conflicts[name] ?? []).filter { candidate in
            !fetched.contains { $0.name == candidate.name && $0.deviceName == candidate.deviceName && $0.modificationDate == candidate.modificationDate }
        }
        versions[name] = saved
        var data: [Data] = []
        for game in saved {
            data.append(try await game.loadData())
            guard accountID == owner else { throw URLError(.cancelled) }
        }
        return data
    }
    public func save(_ data: Data, name: String) async throws {
        guard let owner = accountID else { throw URLError(.userAuthenticationRequired) }
        let saved = versions[name] ?? []
        if saved.count > 1 {
            // Keep GameKit handles on the main actor. Only completion crosses its callback queue.
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                GKLocalPlayer.local.resolveConflictingSavedGames(saved, with: data) { _, error in
                    if let error { continuation.resume(throwing: error) }
                    else { continuation.resume() }
                }
            }
        } else { _ = try await GKLocalPlayer.local.saveGameData(data, withName: name) }
        guard accountID == owner else { throw URLError(.cancelled) }
        conflicts[name] = nil; versions[name] = nil
    }
    nonisolated public func player(_ player: GKPlayer, didModifySavedGame savedGame: GKSavedGame) {
        let owner = player.teamPlayerID, name = savedGame.name
        Task { @MainActor [weak self] in
            guard let self, self.accountID == owner else { return }
            if let name { self.conflicts[name] = nil }
            self.onChange?()
        }
    }
    nonisolated public func player(_ player: GKPlayer, hasConflictingSavedGames savedGames: [GKSavedGame]) {
        let handles = SavedGameHandles(games: savedGames), owner = player.teamPlayerID
        Task { @MainActor [weak self] in
            guard let self, self.accountID == owner else { return }
            self.conflicts.merge(Dictionary(grouping: handles.games, by: { $0.name ?? "" }), uniquingKeysWith: { _, new in new })
            self.onChange?()
        }
    }
}
#endif
