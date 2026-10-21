import Darwin
import Foundation
import NxlvKit

/// Stores one player's playlists and active level sequence outside campaign progress.
@MainActor public final class LevelPlaylistStore {
    public struct SavedRun: Codable, Sendable {
        public let run: LevelSequenceRun
        public let hotSeatID: String?
        public var l2Progress: [String: Data]?
    }
    public enum Failure: Error, LocalizedError {
        case unsupportedVersion
        case changedOnDisk
        case busy
        case tooManyPlaylists
        case missingPlaylist
        case duplicatePlaylist
        case invalidDocument

        public var errorDescription: String? {
            switch self {
            case .unsupportedVersion:
                L10n.text("Playlists need a different app version. Existing files were preserved.")
            case .changedOnDisk:
                L10n.text("Playlists changed in another app. Close and reopen this app.")
            case .busy:
                L10n.text("Another app is saving playlists. Try again after it finishes.")
            case .tooManyPlaylists:
                L10n.text("The player has reached the playlist limit.")
            case .missingPlaylist:
                L10n.text("The selected playlist is no longer available.")
            case .duplicatePlaylist:
                L10n.text("A playlist with this identity already exists.")
            case .invalidDocument:
                L10n.text("The playlist file contains invalid data. Existing files were preserved.")
            }
        }
    }

    private struct Document: Codable {
        static let currentVersion = 3
        static let maximumPlaylists = 200

        var version: Int
        var playlists: [LevelPlaylist]
        var selectedPlaylistID: UUID?
        var activeRun: LevelSequenceRun?
        var activeRunHotSeatID: String?
        var activeRunL2Progress: [String: Data]?
        var savedRuns: [SavedRun]?
        var learningProgress: LearningJourneyProgress?
        var hotSeatLearningProgress: [String: LearningJourneyProgress]?
        var recoveredLegacyHotSeatLearning: Bool?
        var journeySessions: [String: JourneySessionSnapshot]?
        var favourites: [LevelPlaylistEntry]?
        var recentlyPlayed: [LevelPlaylistEntry]?

        init(
            playlists: [LevelPlaylist] = [],
            selectedPlaylistID: UUID? = nil,
            activeRun: LevelSequenceRun? = nil
        ) {
            version = Self.currentVersion
            recoveredLegacyHotSeatLearning = true
            self.playlists = playlists
            self.selectedPlaylistID = selectedPlaylistID
            self.activeRun = activeRun
        }

        func validated() throws -> Self {
            guard (1...Self.currentVersion).contains(version) else { throw Failure.unsupportedVersion }
            guard playlists.count <= Self.maximumPlaylists else {
                throw Failure.tooManyPlaylists
            }
            guard Set(playlists.map(\.id)).count == playlists.count else {
                throw Failure.invalidDocument
            }
            guard selectedPlaylistID == nil
                    || playlists.contains(where: { $0.id == selectedPlaylistID }) else {
                throw Failure.missingPlaylist
            }
            if case let .playlist(playlistID)? = activeRun?.source,
               !playlists.contains(where: { $0.id == playlistID }) {
                throw Failure.missingPlaylist
            }
            let saved = savedRuns ?? []
            guard (recentlyPlayed?.count ?? 0) <= 50 else { throw Failure.invalidDocument }
            for entries in [favourites ?? [], recentlyPlayed ?? []] {
                guard entries.count <= LevelPlaylist.maximumEntries,
                      Set(entries.map(\.identity)).count == entries.count,
                      Set(entries.map(\.id)).count == entries.count else {
                    throw Failure.invalidDocument
                }
            }
            let ids = saved.map { $0.run.id } + (activeRun.map { [$0.id] } ?? [])
            guard Set(ids).count == ids.count,
                  activeRun != nil || activeRunHotSeatID == nil,
                  activeRunHotSeatID?.isEmpty != true,
                  saved.allSatisfy({ $0.hotSeatID?.isEmpty != true }) else {
                throw Failure.invalidDocument
            }
            for value in saved {
                if case let .playlist(id) = value.run.source,
                   !playlists.contains(where: { $0.id == id }) { throw Failure.missingPlaylist }
            }
            return self
        }
    }

    private struct VersionHeader: Decodable {
        let version: Int
    }

    public let file: URL
    public var backupFile: URL { file.appendingPathExtension("backup") }
    private var document = Document()
    private var expectedData: Data?
    public private(set) var recovered = false

    public var playlists: [LevelPlaylist] { document.playlists }
    public var selectedPlaylistID: UUID? { document.selectedPlaylistID }
    public var activeRun: LevelSequenceRun? { document.activeRun }
    public var activeRunHotSeatID: String? { document.activeRunHotSeatID }
    public var activeRunL2Progress: [String: Data] { document.activeRunL2Progress ?? [:] }
    public var savedRuns: [SavedRun] { document.savedRuns ?? [] }
    /// Find the saved queue without changing its session or turn ownership.
    public func resumableRun(id: UUID) -> SavedRun? {
        if let run = document.activeRun, run.id == id {
            return SavedRun(run: run, hotSeatID: document.activeRunHotSeatID,
                l2Progress: document.activeRunL2Progress)
        }
        return savedRuns.first { $0.run.id == id }
    }

    /// A map belongs only to the selected session; saved-session browsing is explicit.
    public func resumableLearningJourney(hotSeatID: String?) -> SavedRun? {
        func isJourney(_ run: LevelSequenceRun) -> Bool {
            run.source == .playlist(LearningJourney.playlistID) && run.pool.id == LearningJourney.version
        }
        if let snapshot = document.journeySessions?[hotSeatID ?? "solo"], snapshot.run == nil { return nil }
        let active = document.activeRun.flatMap { isJourney($0) ? resumableRun(id: $0.id) : nil }
        if document.activeRun != nil, document.activeRunHotSeatID == hotSeatID { return active }
        let saved = savedRuns.filter { isJourney($0.run) }
        return saved.first { $0.hotSeatID == hotSeatID }
    }

    public var learningProgress: LearningJourneyProgress { document.learningProgress ?? .init() }
    public var onChange: (() -> Void)?
    public var journeySessions: [String: JourneySessionSnapshot] { document.journeySessions ?? [:] }
    public func ensureJourneySnapshots() throws {
        let previous = document
        refreshJourneySnapshots()
        guard document.journeySessions != previous.journeySessions else { return }
        do { try save(refreshJourneySnapshots: false) } catch { document = previous; throw error }
    }
    public func importJourneySession(_ incoming: JourneySessionSnapshot, hotSeatID: String?) throws {
        let scope = hotSeatID ?? "solo"
        guard incoming.updatedAt > (document.journeySessions?[scope]?.updatedAt ?? .distantPast) else { return }
        let previous = document
        var archived = savedRuns.filter { $0.run.id != incoming.run?.id }
        let replacesActive = document.activeRunHotSeatID == hotSeatID
            && document.activeRun?.source == .playlist(LearningJourney.playlistID)
        if let run = incoming.run {
            if playlist(id: LearningJourney.playlistID) == nil {
                document.playlists.append(try LevelPlaylist(id: LearningJourney.playlistID, name: LearningJourney.title, entries: run.entries))
            }
            if replacesActive || document.activeRun == nil {
                if let active = document.activeRun, active.id != run.id {
                    archived.insert(SavedRun(run: active, hotSeatID: document.activeRunHotSeatID, l2Progress: document.activeRunL2Progress), at: 0)
                }
                document.activeRun = run; document.activeRunHotSeatID = hotSeatID
                document.activeRunL2Progress = incoming.l2Progress
            } else { archived.insert(SavedRun(run: run, hotSeatID: hotSeatID, l2Progress: incoming.l2Progress), at: 0) }
        } else if replacesActive {
            document.activeRun = nil; document.activeRunHotSeatID = nil; document.activeRunL2Progress = nil
        }
        document.savedRuns = archived
        if document.journeySessions == nil { document.journeySessions = [:] }
        document.journeySessions?[scope] = incoming
        do { try save(refreshJourneySnapshots: false) } catch { document = previous; throw error }
    }
    private func refreshJourneySnapshots() {
        let previous = document.journeySessions ?? [:]
        let scopes = Set(previous.keys).union(savedRuns.map { $0.hotSeatID ?? "solo" })
            .union(document.activeRun.map { _ in [document.activeRunHotSeatID ?? "solo"] } ?? [])
        for scope in scopes {
            let sessionID = scope == "solo" ? nil : scope
            let selected: SavedRun?
            if let active = document.activeRun, document.activeRunHotSeatID == sessionID {
                selected = active.source == .playlist(LearningJourney.playlistID)
                    ? SavedRun(run: active, hotSeatID: sessionID, l2Progress: document.activeRunL2Progress) : nil
            } else if let snapshot = previous[scope], snapshot.run == nil {
                selected = nil
            } else {
                selected = savedRuns.first { $0.hotSeatID == sessionID && $0.run.source == .playlist(LearningJourney.playlistID) }
            }
            let run = selected?.run, l2 = selected?.l2Progress ?? [:]
            guard previous[scope]?.run != run || (previous[scope]?.l2Progress ?? [:]) != l2 else { continue }
            if document.journeySessions == nil { document.journeySessions = [:] }
            document.journeySessions?[scope] = .init(run: run, l2Progress: l2)
        }
    }
    public var learningHotSeatIDs: [String] { Array((document.hotSeatLearningProgress ?? [:]).keys) }
    public func learningProgress(hotSeatID: String?) -> LearningJourneyProgress {
        hotSeatID.map { document.hotSeatLearningProgress?[$0] ?? .init() } ?? learningProgress
    }
    private func setLearningProgress(_ progress: LearningJourneyProgress, hotSeatID: String?) {
        if let hotSeatID {
            if document.hotSeatLearningProgress == nil { document.hotSeatLearningProgress = [:] }
            document.hotSeatLearningProgress?[hotSeatID] = progress
        } else { document.learningProgress = progress }
    }
    public func mergeLearningProgress(_ incoming: LearningJourneyProgress, hotSeatID: String? = nil) throws {
        let current = learningProgress(hotSeatID: hotSeatID)
        let merged = GameProgressValue.mergeLearning(current, incoming)
        guard merged != current else { return }
        let previous = document
        setLearningProgress(merged, hotSeatID: hotSeatID)
        do { try save() } catch { document = previous; throw error }
    }
    public var favourites: [LevelPlaylistEntry] { document.favourites ?? [] }
    public var recentlyPlayed: [LevelPlaylistEntry] { document.recentlyPlayed ?? [] }

    /// Saves an existing mobile collection as one transaction. Ownership stays with the file's profile ID.
    public func importMobileCollections(playlists: [LevelPlaylist], favourites: [LevelPlaylistEntry],
                                        recents: [LevelPlaylistEntry], run: LevelSequenceRun?, hotSeatID: String? = nil) throws {
        let previous = document
        let resumed = run.flatMap { resumableRun(id: $0.id) }
        document.playlists = playlists
        document.selectedPlaylistID = playlists.first?.id
        document.favourites = favourites
        document.recentlyPlayed = recents
        func available(_ sequence: LevelSequenceRun) -> Bool {
            if case let .playlist(id) = sequence.source { return playlists.contains { $0.id == id } }
            return true
        }
        let endingID = run == nil
            ? (document.activeRunHotSeatID == hotSeatID ? document.activeRun?.id : savedRuns.first { $0.hotSeatID == hotSeatID }?.run.id)
            : nil
        var archived = savedRuns.filter {
            $0.run.id != run?.id && $0.run.id != endingID && available($0.run)
        }
        if let active = document.activeRun, active.id != run?.id, available(active),
           run != nil || document.activeRunHotSeatID != hotSeatID {
            archived.insert(SavedRun(run: active, hotSeatID: document.activeRunHotSeatID,
                                    l2Progress: document.activeRunL2Progress), at: 0)
        }
        document.savedRuns = archived
        document.activeRun = run
        document.activeRunHotSeatID = run == nil ? nil : hotSeatID
        document.activeRunL2Progress = resumed?.l2Progress
        do { document = try document.validated(); try save() }
        catch { document = previous; throw error }
    }

    public func toggleFavourite(_ entry: LevelPlaylistEntry) throws {
        let previous = document
        var entries = favourites
        if entries.contains(where: { $0.identity == entry.identity }) {
            entries.removeAll { $0.identity == entry.identity }
        } else {
            guard entries.count < LevelPlaylist.maximumEntries else { throw Failure.invalidDocument }
            entries.insert(entry, at: 0)
        }
        document.favourites = entries
        do { try save() } catch { document = previous; throw error }
    }

    public func recordVisit(_ entry: LevelPlaylistEntry) throws {
        let previous = document
        document.recentlyPlayed = [entry] + recentlyPlayed.filter { $0.identity != entry.identity }.prefix(49)
        do { try save() } catch { document = previous; throw error }
    }

    /// Save a win before the player leaves the result. Keep the current turn in place.
    public func recordLearningWin(runID: UUID, level: LevelCatalogueIdentity) throws {
        guard let run = document.activeRun, run.id == runID,
              run.source == .playlist(LearningJourney.playlistID),
              run.currentEntry.identity == level else { throw Failure.invalidDocument }
        guard !learningProgress(hotSeatID: document.activeRunHotSeatID).completed.contains(level) else { return }
        let previous = document
        var progress = learningProgress(hotSeatID: document.activeRunHotSeatID)
        progress.record(level, won: true)
        setLearningProgress(progress, hotSeatID: document.activeRunHotSeatID)
        do { try save() } catch { document = previous; throw error }
    }

    /// Save the visit and next position together. A deferred level is never a win.
    @discardableResult public func advanceLearningJourney(runID: UUID, won: Bool) throws -> Bool {
        guard var run = document.activeRun, run.id == runID,
              run.source == .playlist(LearningJourney.playlistID) else { throw Failure.invalidDocument }
        let previous = document
        var progress = learningProgress(hotSeatID: document.activeRunHotSeatID)
        progress.record(run.currentEntry.identity, won: won)
        setLearningProgress(progress, hotSeatID: document.activeRunHotSeatID)
        let advanced = run.advance()
        document.activeRun = run
        do { try save() } catch { document = previous; throw error }
        return advanced
    }

    nonisolated public static func fileURL(profileID: String, storage: AppStorage = .current()) -> URL {
        let root = storage.applicationSupport
            .appendingPathComponent("Playlists", isDirectory: true)
        let identity = ArcadeStore.fingerprint(Data(profileID.utf8))
        return root.appendingPathComponent(identity + ".json")
    }

    public static func removeData(profileID: String, storage: AppStorage = .current()) {
        removeData(at: fileURL(profileID: profileID, storage: storage))
    }

    public static func removeData(at file: URL) {
        try? removeDataChecked(at: file)
    }

    public static func removeDataChecked(at file: URL) throws {
        let manager = FileManager.default
        try manager.createDirectory(
            at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let lockFile = file.appendingPathExtension("lock")
        let descriptor = open(
            lockFile.path,
            O_CREAT | O_RDWR,
            S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        defer { close(descriptor) }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else { throw Failure.busy }
        defer { flock(descriptor, LOCK_UN) }
        let prefix = file.lastPathComponent + ".unreadable-"
        let preserved = try manager.contentsOfDirectory(
            at: file.deletingLastPathComponent(),
            includingPropertiesForKeys: nil).filter {
                $0.lastPathComponent.hasPrefix(prefix)
        }
        for target in [file, file.appendingPathExtension("backup")] + preserved where manager.fileExists(atPath: target.path) {
            try manager.removeItem(at: target)
        }
    }

    /// `won` reports wins outside this file, such as campaign wins. A journey revision skips them.
    public convenience init(profileID: String, storage: AppStorage = .current(),
                            won: (LevelCatalogueIdentity) -> Bool = { _ in false }) throws {
        try self.init(file: Self.fileURL(profileID: profileID, storage: storage), won: won)
    }

    public init(file: URL, won: (LevelCatalogueIdentity) -> Bool = { _ in false }) throws {
        self.file = file
        try load()
        try recoverLegacyHotSeatLearning()
        try removeExcludedLearningLessons(LearningJourneyLibrary.excludedIdentities)
        if let journey = LearningJourneyLibrary.journey { try migrateLearningJourney(journey, won: won) }
    }

    /// Older Mac builds shared lesson outcomes across solo and Hot Seat play.
    /// Restore only recorded outcomes for the saved session's past visits.
    private func recoverLegacyHotSeatLearning() throws {
        guard document.recoveredLegacyHotSeatLearning != true else { return }
        let previous = document
        var legacy: Document?
        if document.hotSeatLearningProgress == nil, document.journeySessions == nil {
            legacy = document
        } else if let data = try? Data(contentsOf: backupFile),
                  let backup = try? decode(data),
                  backup.hotSeatLearningProgress == nil, backup.journeySessions == nil,
                  backup.recoveredLegacyHotSeatLearning != true {
            // 2.1 may already have saved an empty scoped history. Its retained
            // pre-upgrade backup can still identify the older shared outcomes.
            legacy = backup
        }
        if let legacy {
            let runs = (legacy.savedRuns ?? []) + (legacy.activeRun.map {
                [SavedRun(run: $0, hotSeatID: legacy.activeRunHotSeatID)]
            } ?? [])
            let history = legacy.learningProgress ?? .init()
            for saved in runs {
                guard let seat = saved.hotSeatID,
                      saved.run.source == .playlist(LearningJourney.playlistID),
                      let current = resumableRun(id: saved.run.id), current.hotSeatID == seat else { continue }
                var progress = learningProgress(hotSeatID: seat)
                for entry in saved.run.entries.prefix(saved.run.currentIndex) {
                    if history.completed.contains(entry.identity) { progress.record(entry.identity, won: true) }
                    else if history.later.contains(entry.identity) { progress.record(entry.identity, won: false) }
                }
                setLearningProgress(progress, hotSeatID: seat)
            }
        }
        document.recoveredLegacyHotSeatLearning = true
        do { try save(refreshJourneySnapshots: false) } catch { document = previous; throw error }
    }

    /// Snapshots supply labels for display counts without changing campaign saves.
    public func completedLearningEntries(hotSeatID: String?) -> [LevelPlaylistEntry] {
        let completed = learningProgress(hotSeatID: hotSeatID).completed
        let entries = document.playlists.flatMap(\.entries)
            + (document.activeRun?.entries ?? []) + savedRuns.flatMap { $0.run.entries }
            + (LearningJourneyLibrary.journey?.lessons.map(\.entry) ?? [])
        var seen: Set<LevelCatalogueIdentity> = []
        return entries.filter { completed.contains($0.identity) && seen.insert($0.identity).inserted }
    }

    /// Classic campaign wins as journey identities. `cleared` returns the won campaign
    /// indices of one release, such as "lemmings" for "lemmings-LEVEL-120".
    nonisolated public static func classicCampaignWins(
        _ cleared: @escaping (String) -> Set<Int>) -> (LevelCatalogueIdentity) -> Bool {
        var cache: [String: Set<Int>] = [:]
        return { identity in
            guard identity.engine == .classic, !identity.packID.hasPrefix("fan:"),
                  let release = identity.packID.split(separator: "-").first.map(String.init) else { return false }
            let parts = identity.levelID.split(separator: ":", omittingEmptySubsequences: false)
            guard parts.count == 5, let index = Int(parts[0]) else { return false }
            if cache[release] == nil { cache[release] = cleared(release) }
            return cache[release]?.contains(index) == true
        }
    }

    /// Retain run identity, owner and completed visits when an editorial lesson is withdrawn.
    public func removeExcludedLearningLessons(_ excluded: Set<LevelCatalogueIdentity>) throws {
        guard !excluded.isEmpty else { return }
        func revised(_ run: LevelSequenceRun) throws -> LevelSequenceRun? {
            guard run.source == .playlist(LearningJourney.playlistID) else { return run }
            let kept = run.entries.enumerated().filter { !excluded.contains($0.element.identity) }
            guard !kept.isEmpty else { return nil }
            let next = kept.firstIndex { $0.offset >= run.currentIndex } ?? kept.count - 1
            return try LevelSequenceRun(id: run.id, source: run.source, pool: run.pool,
                entries: kept.map(\.element), currentIndex: next, seed: run.seed,
                algorithm: run.algorithm, createdAt: run.createdAt)
        }
        let previous = document
        let active = try document.activeRun.flatMap(revised)
        var changed = active != document.activeRun
        document.activeRun = active
        if active == nil { document.activeRunHotSeatID = nil; document.activeRunL2Progress = nil }
        document.savedRuns = try savedRuns.compactMap { saved in
            guard let run = try revised(saved.run) else { changed = true; return nil }
            changed = changed || run != saved.run
            return SavedRun(run: run, hotSeatID: saved.hotSeatID, l2Progress: saved.l2Progress)
        }
        guard changed else { document = previous; return }
        do { try save() } catch { document = previous; throw error }
    }

    public func migrateLearningJourney(_ journey: LearningJourney,
                                       won: (LevelCatalogueIdentity) -> Bool = { _ in false }) throws {
        let previous = document
        func migrated(_ run: LevelSequenceRun, hotSeatID: String?) throws -> LevelSequenceRun? {
            var progress = learningProgress(hotSeatID: hotSeatID)
            let completed = progress.completed
            let migration = try journey.migration(of: run) { completed.contains($0) || (hotSeatID == nil && won($0)) }
            for identity in migration.deferred { progress.record(identity, won: false) }
            setLearningProgress(progress, hotSeatID: hotSeatID)
            return migration.run
        }
        let active = try document.activeRun.flatMap { try migrated($0, hotSeatID: document.activeRunHotSeatID) }
        var changed = active != document.activeRun
        document.activeRun = active
        if active == nil { document.activeRunHotSeatID = nil; document.activeRunL2Progress = nil }
        document.savedRuns = try savedRuns.compactMap { saved in
            guard let run = try migrated(saved.run, hotSeatID: saved.hotSeatID) else { changed = true; return nil }
            changed = changed || run != saved.run
            return SavedRun(run: run, hotSeatID: saved.hotSeatID, l2Progress: saved.l2Progress)
        }
        changed = changed || document.learningProgress != previous.learningProgress
            || document.hotSeatLearningProgress != previous.hotSeatLearningProgress
        guard changed else { document = previous; return }
        do { try save() } catch { document = previous; throw error }
    }

    public func playlist(id: UUID) -> LevelPlaylist? {
        document.playlists.first { $0.id == id }
    }

    public func selectedPlaylist() -> LevelPlaylist? {
        selectedPlaylistID.flatMap { playlist(id: $0) }
    }

    public func add(_ playlist: LevelPlaylist, select: Bool = true) throws {
        guard document.playlists.count < Document.maximumPlaylists else {
            throw Failure.tooManyPlaylists
        }
        guard !document.playlists.contains(where: { $0.id == playlist.id }) else {
            throw Failure.duplicatePlaylist
        }
        let previous = document
        document.playlists.append(playlist)
        if select { document.selectedPlaylistID = playlist.id }
        do { try save() } catch { document = previous; throw error }
    }

    public func update(_ playlist: LevelPlaylist, select: Bool = true) throws {
        guard let index = document.playlists.firstIndex(where: { $0.id == playlist.id }) else {
            throw Failure.missingPlaylist
        }
        let previous = document
        document.playlists[index] = playlist
        if select { document.selectedPlaylistID = playlist.id }
        do { try save() } catch { document = previous; throw error }
    }

    public func removePlaylist(id: UUID) throws {
        guard document.playlists.contains(where: { $0.id == id }) else { return }
        let previous = document
        document.playlists.removeAll { $0.id == id }
        if document.selectedPlaylistID == id {
            document.selectedPlaylistID = document.playlists.last?.id
        }
        if case let .playlist(activePlaylistID)? = document.activeRun?.source,
           activePlaylistID == id {
            document.activeRun = nil
            document.activeRunHotSeatID = nil
            document.activeRunL2Progress = nil
        }
        document.savedRuns = savedRuns.filter {
            if case let .playlist(playlistID) = $0.run.source { return playlistID != id }
            return true
        }
        do { try save() } catch { document = previous; throw error }
    }

    public func selectPlaylist(id: UUID?) throws {
        guard id == nil || document.playlists.contains(where: { $0.id == id }) else {
            throw Failure.missingPlaylist
        }
        let previous = document
        document.selectedPlaylistID = id
        do { try save() } catch { document = previous; throw error }
    }

    public func setActiveRun(_ run: LevelSequenceRun?) throws {
        let run = try run?.removingMultiplayerLevels()
        if case let .playlist(playlistID)? = run?.source,
           !document.playlists.contains(where: { $0.id == playlistID }) {
            throw Failure.missingPlaylist
        }
        let previous = document
        if run?.id != document.activeRun?.id {
            document.activeRunHotSeatID = nil
            document.activeRunL2Progress = nil
        }
        document.activeRun = run
        do { try save() } catch { document = previous; throw error }
    }

    /// Keep the previous sequence and its turn ownership when starting another session.
    public func startRun(_ run: LevelSequenceRun, hotSeatID: String?, l2Progress: [String: Data]? = nil) throws {
        guard let run = try run.removingMultiplayerLevels() else { throw LevelPlaylistError.emptyPool }
        if case let .playlist(id) = run.source, playlist(id: id) == nil { throw Failure.missingPlaylist }
        let previous = document
        var saved = savedRuns.filter { $0.run.id != run.id }
        if let active = document.activeRun, active.id != run.id {
            saved.insert(SavedRun(run: active, hotSeatID: document.activeRunHotSeatID,
                l2Progress: document.activeRunL2Progress), at: 0)
        }
        document.savedRuns = saved
        document.activeRun = run
        document.activeRunHotSeatID = hotSeatID
        document.activeRunL2Progress = l2Progress
        do { try save() } catch { document = previous; throw error }
    }

    public func resumeRun(id: UUID) throws {
        guard let saved = savedRuns.first(where: { $0.run.id == id }) else { throw Failure.invalidDocument }
        try startRun(saved.run, hotSeatID: saved.hotSeatID, l2Progress: saved.l2Progress)
    }

    @discardableResult public func advanceActiveRun() throws -> Bool {
        guard var run = document.activeRun else { return false }
        guard run.advance() else { return false }
        let previous = document
        document.activeRun = run
        do { try save() } catch { document = previous; throw error }
        return true
    }

    private func decode(_ data: Data) throws -> Document {
        let decoder = JSONDecoder()
        let header = try decoder.decode(VersionHeader.self, from: data)
        guard (1...Document.currentVersion).contains(header.version) else {
            throw Failure.unsupportedVersion
        }
        var loaded = try decoder.decode(Document.self, from: data).validated()
        loaded.activeRun = try loaded.activeRun?.removingMultiplayerLevels()
        if loaded.activeRun == nil {
            loaded.activeRunHotSeatID = nil
            loaded.activeRunL2Progress = nil
        }
        loaded.savedRuns = try loaded.savedRuns?.compactMap { saved in
            guard let run = try saved.run.removingMultiplayerLevels() else { return nil }
            return SavedRun(run: run, hotSeatID: saved.hotSeatID, l2Progress: saved.l2Progress)
        }
        return try loaded.validated()
    }

    private func load() throws {
        let manager = FileManager.default
        guard manager.fileExists(atPath: file.path) else {
            guard manager.fileExists(atPath: backupFile.path) else { return }
            try recover(preserving: nil)
            return
        }
        let data = try Data(contentsOf: file)
        do {
            document = try decode(data)
            expectedData = data
        } catch Failure.unsupportedVersion {
            throw Failure.unsupportedVersion
        } catch {
            guard manager.fileExists(atPath: backupFile.path) else { throw error }
            try recover(preserving: data)
        }
    }

    private func withLock<T>(_ operation: () throws -> T) throws -> T {
        try FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let descriptor = open(
            file.appendingPathExtension("lock").path,
            O_CREAT | O_RDWR,
            S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
        defer { close(descriptor) }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            if errno == EWOULDBLOCK { throw Failure.busy }
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
        defer { flock(descriptor, LOCK_UN) }
        return try operation()
    }

    private func recover(preserving original: Data?) throws {
        try withLock {
            let current = FileManager.default.fileExists(atPath: file.path)
                ? try Data(contentsOf: file) : nil
            guard current == original else { throw Failure.changedOnDisk }
            let data = try Data(contentsOf: backupFile)
            let recoveredDocument = try decode(data)
            if let original {
                let preserved = file.deletingLastPathComponent().appendingPathComponent(
                    file.lastPathComponent + ".unreadable-" + UUID().uuidString)
                try original.write(to: preserved, options: .atomic)
            }
            try data.write(to: file, options: .atomic)
            document = recoveredDocument
            expectedData = data
            recovered = true
        }
    }

    private func save(refreshJourneySnapshots: Bool = true) throws {
        if refreshJourneySnapshots { self.refreshJourneySnapshots() }
        try withLock {
            document.version = Document.currentVersion
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(try document.validated())
            let manager = FileManager.default
            let current = manager.fileExists(atPath: file.path)
                ? try Data(contentsOf: file) : nil
            guard current == expectedData else { throw Failure.changedOnDisk }
            try (current ?? data).write(to: backupFile, options: .atomic)
            try data.write(to: file, options: .atomic)
            expectedData = data
        }
        onChange?()
    }
}
