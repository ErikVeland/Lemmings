import CryptoKit
import Foundation

/// A stable, cross-engine description of the gameplay state at replay completion.
/// CE oracle exporters can emit this schema without reproducing Swift's Codable layout.
public struct NeoLemmixFinalState: Codable, Equatable, Sendable {
    public static let format = "neolemmix-final-state-v1"

    public struct Skill: Codable, Equatable, Sendable {
        public let name: String
        /// `nil` means an infinite supply.
        public let count: Int?
    }

    public struct Lemming: Codable, Equatable, Sendable {
        public let id: Int
        public let x: Int
        public let y: Int
        public let direction: Int
        public let action: String
        public let animationFrame: Int
        public let actionProgress: Int
        public let fallDistance: Int
        public let trueFallDistance: Int
        public let traits: [String]
        public let bomberCountdown: Int?
        public let pendingExplosionSkill: String?
        public let bricksRemaining: Int
        public let placedBrick: Bool?
        public let targetZoneID: Int?
        public let laserHitX: Int?
        public let laserHitY: Int?
        public let lastSplitterZoneID: Int?
        public let teleportTargetZoneID: Int?
        public let teleportTicksRemaining: Int?
        public let teleportReturnAction: String?
        public let portalTargetZoneID: Int?
        public let portalWarpFrame: Int?
        public let lastPortalZoneID: Int?
        public let dehoistPinY: Int?
        public let cloneParentID: Int?
        public let pendingRemovalReason: String?
        public let removalReason: String?
        public let isStartingAction: Bool
        public let hasBeenOhNo: Bool?
    }

    public struct IntegerValue: Codable, Equatable, Sendable {
        public let id: Int
        public let value: Int
    }

    public struct SecondaryAnimation: Codable, Equatable, Sendable {
        public let gadgetID: Int
        public let index: Int
        public let frame: Int
        public let state: String
        public let isVisible: Bool
    }

    public struct Terrain: Codable, Equatable, Sendable {
        public let width: Int
        public let height: Int
        public let solidSHA256: String
        public let steelSHA256: String
        public let oneWaySHA256: String
        public let visualOpaqueSHA256: String
        public let constructionShadeSHA256: String?
        public let stonerOwnerSHA256: String?
        public let stonerSourceSHA256: String?
    }

    public let format: String
    public let tick: Int
    public let released: Int
    public let saved: Int
    public let lost: Int
    public let cloned: Int
    public let remainingTimeTicks: Int?
    public let spawnInterval: Int
    public let entrancesAreOpen: Bool
    public let isNuking: Bool
    public let isComplete: Bool
    public let didWin: Bool
    public let skills: [Skill]
    public let lemmings: [Lemming]
    public let disabledZoneIDs: [Int]
    public let splitterDirections: [IntegerValue]
    public let remainingZoneLemmingCounts: [IntegerValue]
    public let gadgetAnimationFrames: [IntegerValue]
    public let secondaryAnimations: [SecondaryAnimation]
    public let terrain: Terrain

    public init(_ simulation: NeoLemmixSimulation) {
        let snapshot = simulation.snapshot()
        format = Self.format
        tick = simulation.tickCount
        released = simulation.releasedCount
        saved = simulation.savedCount
        lost = simulation.lostCount
        cloned = simulation.clonedCount
        remainingTimeTicks = simulation.remainingTimeTicks
        spawnInterval = simulation.spawnInterval
        entrancesAreOpen = simulation.entrancesAreOpen
        isNuking = simulation.isNuking
        isComplete = simulation.isComplete
        didWin = simulation.didWin
        skills = simulation.skills.map {
            Skill(name: $0.key.rawValue, count: $0.value.availableCount)
        }.sorted { $0.name < $1.name }
        lemmings = simulation.lemmings.sorted { $0.id < $1.id }.map {
            Lemming(
                id: $0.id,
                x: $0.position.x,
                y: $0.position.y,
                direction: $0.direction.rawValue,
                action: $0.action.rawValue,
                animationFrame: $0.animationFrame,
                actionProgress: $0.actionProgress,
                fallDistance: $0.fallDistance,
                trueFallDistance: $0.trueFallDistance,
                traits: $0.traits.map(\.rawValue).sorted(),
                bomberCountdown: $0.bomberCountdown,
                pendingExplosionSkill: $0.pendingExplosionSkill?.rawValue,
                bricksRemaining: $0.bricksRemaining,
                placedBrick: $0.placedBrick,
                targetZoneID: $0.targetZoneID,
                laserHitX: $0.laserHitPoint?.x,
                laserHitY: $0.laserHitPoint?.y,
                lastSplitterZoneID: $0.lastSplitterZoneID,
                teleportTargetZoneID: $0.teleportTargetZoneID,
                teleportTicksRemaining: $0.teleportTicksRemaining,
                teleportReturnAction: $0.teleportReturnAction?.rawValue,
                portalTargetZoneID: $0.portalTargetZoneID,
                portalWarpFrame: $0.portalWarpFrame,
                lastPortalZoneID: $0.lastPortalZoneID,
                dehoistPinY: $0.dehoistPinY,
                cloneParentID: $0.cloneParentID,
                pendingRemovalReason: $0.pendingRemovalReason?.rawValue,
                removalReason: $0.removalReason?.rawValue,
                isStartingAction: $0.isStartingAction,
                hasBeenOhNo: $0.hasBeenOhNo)
        }
        disabledZoneIDs = simulation.disabledZoneIDs.sorted()
        splitterDirections = Self.integerValues(simulation.splitterDirections) { $0.rawValue }
        remainingZoneLemmingCounts = Self.integerValues(snapshot.remainingZoneLemmingCounts) { $0 }
        gadgetAnimationFrames = Self.integerValues(simulation.gadgetAnimationFrames) { $0 }
        secondaryAnimations = (simulation.secondaryAnimationStates ?? [:]).flatMap { gadgetID, states in
            states.enumerated().map { index, state in
                SecondaryAnimation(
                    gadgetID: gadgetID,
                    index: index,
                    frame: state.frame,
                    state: state.state.rawValue,
                    isVisible: state.isVisible)
            }
        }.sorted {
            ($0.gadgetID, $0.index) < ($1.gadgetID, $1.index)
        }
        terrain = Terrain(
            width: simulation.terrain.width,
            height: simulation.terrain.height,
            solidSHA256: Self.digest(simulation.terrain.solidMask),
            steelSHA256: Self.digest(simulation.terrain.steelMask),
            oneWaySHA256: Self.digest(simulation.terrain.oneWayMask),
            visualOpaqueSHA256: Self.digest(simulation.terrain.visualOpaqueMask),
            constructionShadeSHA256: simulation.terrain.constructionShadeMask.map(Self.digest),
            stonerOwnerSHA256: simulation.terrain.stonerOwnerMask.map(Self.digest),
            stonerSourceSHA256: simulation.terrain.stonerSourceMask.map(Self.digest))
    }

    private static func integerValues<Value>(
        _ values: [Int: Value]?,
        transform: (Value) -> Int
    ) -> [IntegerValue] {
        (values ?? [:]).map { IntegerValue(id: $0.key, value: transform($0.value)) }
            .sorted { $0.id < $1.id }
    }

    private static func digest(_ values: [UInt8]) -> String {
        digest(Data(values))
    }

    private static func digest(_ values: [Int32]) -> String {
        var data = Data(capacity: values.count * 4)
        for value in values {
            var bytes = value.littleEndian
            withUnsafeBytes(of: &bytes) { data.append(contentsOf: $0) }
        }
        return digest(data)
    }

    private static func digest(_ values: [UInt16]) -> String {
        var data = Data(capacity: values.count * 2)
        for value in values {
            var bytes = value.littleEndian
            withUnsafeBytes(of: &bytes) { data.append(contentsOf: $0) }
        }
        return digest(data)
    }

    private static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

public struct NeoLemmixFinalStateManifest: Codable, Equatable, Sendable {
    public struct Record: Codable, Equatable, Sendable {
        public let replaySHA256: String
        public let levelID: String
        public let levelVersion: String
        public let state: NeoLemmixFinalState

        public init(
            replaySHA256: String,
            levelID: String,
            levelVersion: String,
            state: NeoLemmixFinalState
        ) {
            self.replaySHA256 = replaySHA256
            self.levelID = levelID
            self.levelVersion = levelVersion
            self.state = state
        }
    }

    public let format: String
    public let producer: String
    public let records: [Record]

    public init(records: [Record], producer: String = "native") {
        format = NeoLemmixFinalState.format
        self.producer = producer
        self.records = records.sorted { $0.replaySHA256 < $1.replaySHA256 }
    }

    /// Returns stable, bounded diagnostics for comparing a native manifest to
    /// an independently produced CE oracle manifest.
    public func comparisonIssues(against oracle: Self, limit: Int = 100) -> [String] {
        let maximum = max(1, limit)
        var issues: [String] = []
        func append(_ issue: String) {
            if issues.count < maximum { issues.append(issue) }
        }
        guard format == NeoLemmixFinalState.format,
              oracle.format == NeoLemmixFinalState.format else {
            return ["unsupported manifest format"]
        }
        guard producer == "native" else {
            return ["comparison input is not a native manifest"]
        }
        guard oracle.producer.hasPrefix("ce:") else {
            return ["oracle manifest is not marked as CE-produced"]
        }
        let nativeGroups = Dictionary(grouping: records, by: \.replaySHA256)
        let oracleGroups = Dictionary(grouping: oracle.records, by: \.replaySHA256)
        for hash in nativeGroups.keys.sorted() where nativeGroups[hash]?.count != 1 {
            append("duplicate native replay \(hash)")
        }
        for hash in oracleGroups.keys.sorted() where oracleGroups[hash]?.count != 1 {
            append("duplicate oracle replay \(hash)")
        }
        let nativeHashes = Set(nativeGroups.keys)
        let oracleHashes = Set(oracleGroups.keys)
        for hash in nativeHashes.subtracting(oracleHashes).sorted() {
            append("oracle replay missing \(hash)")
        }
        for hash in oracleHashes.subtracting(nativeHashes).sorted() {
            append("unexpected oracle replay \(hash)")
        }
        for hash in nativeHashes.intersection(oracleHashes).sorted() {
            guard nativeGroups[hash]?.count == 1, oracleGroups[hash]?.count == 1 else { continue }
            if nativeGroups[hash]![0] != oracleGroups[hash]![0] {
                append("final state differs \(hash)")
            }
        }
        return issues
    }
}
