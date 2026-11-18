import Foundation
import NxlvKit

/// Optional five-level campaign routes separate from the Classic Journey.
public struct ShortPlaySequence: Identifiable, Sendable {
    public struct Level: Sendable {
        public let identity: LevelCatalogueIdentity
        public let sourceRevision: String?
        public let fixture: String
        public let witnessSHA256: String
        public let levelSHA256: String?

        public func matches(_ entry: LevelPlaylistEntry) -> Bool {
            entry.identity == identity && (sourceRevision == nil || entry.sourceRevision == sourceRevision)
        }
    }

    public let id: String
    public let engine: LevelSourceEngine
    public let levels: [Level]
    public var poolID: String { "short-play-v1:" + id }
    public var title: String {
        switch engine {
        case .classic: return id == "classic" ? L10n.text("Classic opening") : L10n.text("Classic follow-up")
        case .lemmings2: return L10n.text("The Tribes opening")
        case .lemmings3: return L10n.text("Chronicles opening")
        case .neolemmix: return L10n.text("Opening")
        }
    }
    public var caption: String {
        if engine == .classic { return id == "classic" ? L10n.text("Fun 1–5") : L10n.text("Fun 6–10") }
        return L10n.text("Classic tribe 1–5")
    }
    /// L3 playlists need isolated reserve carry-over before this opening can start.
    public var supportsCarriedSequence: Bool { engine != .lemmings3 }

    public func entries(resolving resolve: (LevelCatalogueIdentity) -> LevelPlaylistEntry?) -> [LevelPlaylistEntry]? {
        var entries: [LevelPlaylistEntry] = []
        for level in levels {
            guard let entry = resolve(level.identity), level.matches(entry) else { return nil }
            entries.append(entry)
        }
        return entries
    }

    public func matches(_ entries: [LevelPlaylistEntry]) -> Bool {
        entries.count == levels.count && zip(levels, entries).allSatisfy { $0.matches($1) }
    }

    public func run(playlist: LevelPlaylist) throws -> LevelSequenceRun {
        guard supportsCarriedSequence, matches(playlist.entries) else { throw LevelPlaylistError.invalidSequence }
        return try LevelSequenceRun.playlist(playlist, pool: .init(id: poolID, summary: title))
    }
}

public enum ShortPlayCatalogue {
    /// Original DOS game data with executables and documents excluded from the revision.
    public static let classicDataRevision = "e0cecc54d0821ee15e640d4a0878633638a7de75403362ca341502cc10c2d4f3"

    private static func classicLevel(_ number: Int, archive: Int, section: Int, witness: String) -> ShortPlaySequence.Level {
        .init(identity: .init(engine: .classic, packID: "lemmings-LEVEL-120", levelID: "\(number - 1):Fun:\(number):\(archive):\(section)"),
              sourceRevision: "2e3e67e01c0e9d75a45354f53504d6f6c47a54da0e32b340ae0c08ba2bf247d7",
              fixture: String(format: "Tests/ClassicDOSCompletionTests/Fixtures/fun-%02d.json", number),
              witnessSHA256: witness, levelSHA256: nil)
    }

    public static let sequences: [ShortPlaySequence] = [
        .init(id: "classic", engine: .classic, levels: [
            classicLevel(1, archive: 9, section: 1, witness: "2465bd0927556f786e0804f86d4884c105bbdd03043684163ed4bbe5851817a1"),
            classicLevel(2, archive: 9, section: 5, witness: "af565532453e78c49449688a9b375b5a62e298ae683f770794a1afb2504f90c6"),
            classicLevel(3, archive: 9, section: 6, witness: "5a5de0d60caeb6318b00ea76c5e2d35d804457958e8f1edf4bfe679dca4bb042"),
            classicLevel(4, archive: 9, section: 2, witness: "3093c495b7b9e04aa1cacdd1a56064c2fdde339e5a0dfcaed67f58c5e0c7bca9"),
            classicLevel(5, archive: 9, section: 3, witness: "1081f365263b5e98fdf3bac9c7f54f9f95cb5c4f5a51c258869e6f1d302fe3e0"),
        ]),
        .init(id: "classic-follow-up", engine: .classic, levels: [
            classicLevel(6, archive: 9, section: 4, witness: "50c19af4e7be89ce7e81be7394c8e074c22ea85e9aa2fa4c87ac614e6032a01f"),
            classicLevel(7, archive: 9, section: 7, witness: "482793d74cdd349dc82f469ec1e2a7caa6cd698dc3eacdf1a1de5073eb8d62fc"),
            classicLevel(8, archive: 0, section: 6, witness: "1187207f784b0490d83b358ae9e43cc8a2c5a8165ca7672532a44755af2f0e80"),
            classicLevel(9, archive: 1, section: 2, witness: "806b6420ecbfc7325529efc40eb646680d5423745342f6f895c5233ebb1e5488"),
            classicLevel(10, archive: 3, section: 2, witness: "ceaa9e1aa054b9a6ec4c1d8378a63bec389653a63a0f0281275842d498086ed7"),
        ]),
        .init(id: "lemmings2", engine: .lemmings2, levels: [
            .init(identity: .init(engine: .lemmings2, packID: "tribes-0", levelID: "0:2be6334f0423ee3ac635946ee855aa8caa4bc8cdd53190c6f16d8cc7d806cc8e"),
                  sourceRevision: nil, fixture: "Tests/Lemmings2CompletionTests/Fixtures/classic-01.json",
                  witnessSHA256: "4950ae7dd93071d00fd2aa80022d2e9cd75af13bb9b2f4b8472e9017e192d5ba", levelSHA256: "2be6334f0423ee3ac635946ee855aa8caa4bc8cdd53190c6f16d8cc7d806cc8e"),
            .init(identity: .init(engine: .lemmings2, packID: "tribes-0", levelID: "1:2fe29f898f471ef8507f7f1bbe4a21fd167e7d808cdff12b6e4ffad39d0d801c"),
                  sourceRevision: nil, fixture: "Tests/Lemmings2CompletionTests/Fixtures/classic-02.json",
                  witnessSHA256: "3e7f3d5fa75ab09c632e40c2858c85d416ef170928e85cd235b3b03ae2cf93e5", levelSHA256: "2fe29f898f471ef8507f7f1bbe4a21fd167e7d808cdff12b6e4ffad39d0d801c"),
            .init(identity: .init(engine: .lemmings2, packID: "tribes-0", levelID: "2:83d3536c2857760ee78ed0d1993d39fdbdd4f4bba40ac7541e2d3050a65e5fe9"),
                  sourceRevision: nil, fixture: "Tests/Lemmings2CompletionTests/Fixtures/classic-03.json",
                  witnessSHA256: "97fbb962b32cbe05d139b77b3cfada7f3bbde874f53c7d2abd968b5f82bf87b0", levelSHA256: "83d3536c2857760ee78ed0d1993d39fdbdd4f4bba40ac7541e2d3050a65e5fe9"),
            .init(identity: .init(engine: .lemmings2, packID: "tribes-0", levelID: "3:2ad1c0b8ed788a76a4f6ebabe7623005b8225d9c3584b68a844614520d931c51"),
                  sourceRevision: nil, fixture: "Tests/Lemmings2CompletionTests/Fixtures/classic-04.json",
                  witnessSHA256: "4de7ab230b880d3c05db0c38c3e9ec3bd14283afe4499311075fa4309b19ed55", levelSHA256: "2ad1c0b8ed788a76a4f6ebabe7623005b8225d9c3584b68a844614520d931c51"),
            .init(identity: .init(engine: .lemmings2, packID: "tribes-0", levelID: "4:68abf1d6cd8206beb398c4da3c3963786c245b1f5070cbf83596865a763f9c07"),
                  sourceRevision: nil, fixture: "Tests/Lemmings2CompletionTests/Fixtures/classic-05.json",
                  witnessSHA256: "c4a567176d7bf8965a0743351639f7f5554a33d3dbf6b648e7d30b9609299d1d", levelSHA256: "68abf1d6cd8206beb398c4da3c3963786c245b1f5070cbf83596865a763f9c07"),
        ]),
        .init(id: "lemmings3", engine: .lemmings3, levels: [
            .init(identity: .init(engine: .lemmings3, packID: "chronicles-1", levelID: "0:7f4e6fd9b04f6fbcfa4fe3fa6a563458d928ea3ce08f1664a2d633767b5e8c96"),
                  sourceRevision: nil, fixture: "Tests/Lemmings3CompletionTests/Fixtures/001.json",
                  witnessSHA256: "5ac07c6d2841583d3112544bceb401f70c791b4a146891964c84b6d33b595841", levelSHA256: "7f4e6fd9b04f6fbcfa4fe3fa6a563458d928ea3ce08f1664a2d633767b5e8c96"),
            .init(identity: .init(engine: .lemmings3, packID: "chronicles-1", levelID: "1:bc269a77ebb2d145ee18b0cf2a6b03d6019043c35094dfd57f879e1da0bf92f2"),
                  sourceRevision: nil, fixture: "Tests/Lemmings3CompletionTests/Fixtures/002.json",
                  witnessSHA256: "4a97d0e7512723eacdaffcdcb0614f905bac7721b55f4ce1d5359e28e827e517", levelSHA256: "bc269a77ebb2d145ee18b0cf2a6b03d6019043c35094dfd57f879e1da0bf92f2"),
            .init(identity: .init(engine: .lemmings3, packID: "chronicles-1", levelID: "2:a8c0df1b5a2754a8ec452652dae5ceb63d75e53f1b2dc57af3b3af2a5d7f12fa"),
                  sourceRevision: nil, fixture: "Tests/Lemmings3CompletionTests/Fixtures/003.json",
                  witnessSHA256: "36770f30c0e1129942193b5468b97b5f0b3363319b4c0ef9e96fbccf638064fb", levelSHA256: "a8c0df1b5a2754a8ec452652dae5ceb63d75e53f1b2dc57af3b3af2a5d7f12fa"),
            .init(identity: .init(engine: .lemmings3, packID: "chronicles-1", levelID: "3:ab8f2a2df7b601243cf044f2601cb599c12c973635daedbba1c6cbb915500697"),
                  sourceRevision: nil, fixture: "Tests/Lemmings3CompletionTests/Fixtures/004.json",
                  witnessSHA256: "e8af8b7fdeaa501438240f46a7a6477768fff9a9a59a3bd39eaf096b68a6a26a", levelSHA256: "ab8f2a2df7b601243cf044f2601cb599c12c973635daedbba1c6cbb915500697"),
            .init(identity: .init(engine: .lemmings3, packID: "chronicles-1", levelID: "4:2248e31f97d606cb06a4fb80cccbd798dc6a4218188e83838f37a05f60959910"),
                  sourceRevision: nil, fixture: "Tests/Lemmings3CompletionTests/Fixtures/005.json",
                  witnessSHA256: "85c49cef9535c9e61e59f99bfd640fc3e3898b0125e823999f37edc85d636c02", levelSHA256: "2248e31f97d606cb06a4fb80cccbd798dc6a4218188e83838f37a05f60959910"),
        ]),
    ]

    public static func sequence(id: String) -> ShortPlaySequence? { sequences.first { $0.id == id } }

    /// A locked level is allowed only inside the exact, unshuffled route snapshot.
    public static func permitsLocked(_ entry: LevelPlaylistEntry, in run: LevelSequenceRun) -> Bool {
        guard case .playlist = run.source, run.algorithm == nil, run.seed == nil,
              let sequence = sequences.first(where: { $0.poolID == run.pool.id }),
              sequence.supportsCarriedSequence, sequence.matches(run.entries) else { return false }
        return sequence.levels.contains { $0.matches(entry) }
    }
}
