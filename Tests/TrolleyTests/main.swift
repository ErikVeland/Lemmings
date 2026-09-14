import AppKit
import NxlvKit

func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw SequelDataError.invalid(message) }
}
func conditions(game: String = "lemmings", pack: String = "original", level: String = "fun-1", fingerprint: String = "fixture-a",
                rules: String = "classic-dos-v1", total: Int = 60, required: Int = 40,
                skills: [String: Int] = ["builder": 20, "digger": 10], time: Double? = 300,
                modifiers: [String: String] = [:]) -> TrolleyConditions {
    .init(gameID: game, packID: pack, levelID: level, levelFingerprint: fingerprint, rulesetVersion: rules,
          physicsMode: rules, population: total, rescueRequirement: required, startingSkills: skills,
          timeLimitSeconds: time, modifiers: modifiers)
}
func level(_ c: TrolleyConditions) -> ArcadeLevel {
    .init(id: c.levelID, title: "A choice of rescuers", game: c.gameID, rules: c.rulesetVersion,
          total: c.population, required: c.rescueRequirement, conditions: c)
}
func run(_ saved: Int, c: TrolleyConditions = conditions(), owner: String = ArcadeProfile.legacyID,
         win: Bool? = nil, used: [String: Int] = ["builder": 8], released: Int? = nil, nuke: Int = 0,
         rewinds: Int = 0, undo: Int = 0, seconds: Double = 120, date: Date = Date(timeIntervalSince1970: 1_000),
         id: UUID = UUID(), extra: [String: Double] = [:]) -> ArcadeRun {
    .init(id: id, profileID: owner, level: level(c), saved: saved, didWin: win ?? (saved >= c.rescueRequirement),
          skills: used, seconds: seconds, assisted: rewinds > 0 || undo > 0, date: date,
          telemetry: .init(released: released ?? c.population, nukeCount: nuke, rewindCount: rewinds, undoCount: undo,
                           destructiveSkillCount: used["digger", default: 0], buildVersion: "test-1", additionalStatistics: extra))
}
func evidence(_ value: Int) -> TrolleyMaximum {
    .init(value: value, status: .verified, source: "Trusted test proof", date: Date(timeIntervalSince1970: 500), buildVersion: "test-1")
}
func verifiedRecords(_ c: TrolleyConditions = conditions(), maximum: Int = 58) throws -> ArcadeRecords {
    var records = ArcadeRecords()
    try records.acceptTrolleyMaximum(evidence(maximum), conditions: c, assisted: false)
    return records
}

@MainActor func testBundledMaximumProofs() throws {
    let c = conditions(), engine = String(repeating: "a", count: 64)
    let conditionJSON = try JSONSerialization.jsonObject(with: JSONEncoder().encode(c))
    let witness: [String: Any] = ["path": "witnesses/test.json", "sha256": String(repeating: "b", count: 64),
        "saved": 60, "released": 60, "lost": 0, "retainedReserves": 0, "completed": true, "didWin": true]
    let row: [String: Any] = ["conditions": conditionJSON, "status": "VERIFIED", "population": 60,
                            "maximumSaveable": 60, "minimumSacrifices": 0, "witness": witness]
    func decode(_ rows: [[String: Any]], version: Int = 1) throws -> TrolleyProofCatalogue {
        let data = try JSONSerialization.data(withJSONObject: ["schemaVersion": version,
            "generatedAt": "2026-09-09T00:00:00Z", "engineSourceFingerprint": engine, "levels": rows])
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(TrolleyProofCatalogue.self, from: data)
    }
    let catalogue = try decode([row])
    let proof = catalogue.maximum(for: c, engineFingerprint: engine)!
    try require(proof.status == .verified && proof.value == 60, "Full-population proof was not accepted")
    try require(catalogue.maximum(for: c, engineFingerprint: String(repeating: "c", count: 64)) == nil,
                "Changed engine inherited a rescue target")
    for altered in [conditions(fingerprint: "other"), conditions(rules: "new-physics"), conditions(total: 59),
                    conditions(required: 41), conditions(skills: ["builder": 19, "digger": 10]),
                    conditions(time: 301), conditions(modifiers: ["practice": "true"]),
                    conditions(pack: "custom"), conditions(level: "fun-2"), conditions(game: "other")] {
        try require(catalogue.maximum(for: altered, engineFingerprint: engine) == nil, "Changed conditions inherited a rescue target")
    }
    for (key, value) in [("status", "OBSERVED" as Any), ("population", 59), ("maximumSaveable", 59), ("minimumSacrifices", 1)] {
        var changed = row; changed[key] = value
        let invalid = try decode([changed])
        try require(invalid.maximum(for: c, engineFingerprint: engine) == nil, "Invalid bound accepted: \(key)")
    }
    for (key, value) in [("saved", 59 as Any), ("released", 59), ("lost", 1), ("retainedReserves", 1),
                         ("completed", false), ("didWin", false), ("sha256", "not-a-digest")] {
        var changed = row, changedWitness = witness
        changedWitness[key] = value; changed["witness"] = changedWitness
        let invalid = try decode([changed])
        try require(invalid.maximum(for: c, engineFingerprint: engine) == nil, "Invalid witness accepted: \(key)")
    }
    let duplicate = try decode([row, row]), future = try decode([row], version: 2)
    try require(duplicate.maximum(for: c, engineFingerprint: engine) == nil, "Duplicate proof conditions accepted")
    try require(future.maximum(for: c, engineFingerprint: engine) == nil, "Unknown proof schema accepted")
    let unlimited = conditions(skills: ["cloner": -1])
    var cloneRow = row; cloneRow["conditions"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(unlimited))
    let cloneProof = try decode([cloneRow])
    try require(cloneProof.maximum(for: unlimited, engineFingerprint: engine) == nil, "Unlimited population certified")

    let temp = FileManager.default.temporaryDirectory.appendingPathComponent("trolley-proofs-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temp) }
    let file = temp.appendingPathComponent("records.json")
    let bundled = TrolleyBundledProofs(catalogue: catalogue, engineFingerprint: engine)
    let store = ArcadeStore(file: file, bundledProofs: bundled)
    store.beginAttempt(id: UUID(), profileID: store.records.activeProfileID, level: level(c), previousID: nil)
    for assisted in [false, true] {
        try require(store.records.trolley.maximum(conditions: c, assisted: assisted) == proof, "Proof absent at level start")
    }
    let snapshot = store.record(run(60))!.trolley!.attempt
    let unchanged = ArcadeStore(file: file, bundledProofs: bundled)
    try require(unchanged.records.trolley.maximum(conditions: c, assisted: false) == proof, "Current proof expired on reload")
    let expired = ArcadeStore(file: file, bundledProofs: nil)
    try require(expired.records.trolley.maximum(conditions: c, assisted: false).status == .observed,
                "Removed or outdated bundled proof survived reload")
    try require(expired.records.trolley.maximum(conditions: c, assisted: true).status == .unknown,
                "Expired proof invented an observation")
    try require(expired.records.trolley.attempts.first == snapshot, "Retiring proof changed historical stars or metrics")
    var manual = try verifiedRecords()
    manual.retainBundledTrolleyMaxima([:])
    try require(manual.trolley.maximum(conditions: c, assisted: false) == evidence(58), "Manual evidence was retired as bundled evidence")

    let source = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Resources/Trolley")
    let copy = temp.appendingPathComponent("Trolley")
    try FileManager.default.copyItem(at: source, to: copy)
    guard let shipped = TrolleyBundledProofs.load(from: copy), let first = shipped.catalogue.levels.first,
          let shippedConditions = first.conditions, let shippedWitness = first.witness else {
        throw SequelDataError.invalid("Shipped catalogue or witness integrity failed")
    }
    try require(shipped.maximum(for: shippedConditions) != nil, "Shipped proof did not validate")
    let replayFile = copy.appendingPathComponent(shippedWitness.path), original = try Data(contentsOf: replayFile)
    try (original + Data("corrupt".utf8)).write(to: replayFile)
    try require(TrolleyBundledProofs.load(from: copy) == nil, "Corrupt bundled replay accepted")
    try original.write(to: replayFile)
    try "outdated".write(to: copy.appendingPathComponent("engine-fingerprint.txt"), atomically: true, encoding: .utf8)
    try require(TrolleyBundledProofs.load(from: copy) == nil, "Outdated engine stamp accepted")
    print("PASS bundled rescue proofs, exact conditions, corrupt witnesses, expired evidence and immutable history")
}

func testMetricsAndClassification() throws {
    var records = try verifiedRecords()
    let exact = records.record(run(40))!.trolley!
    try require(exact.attempt.run.didWin && exact.attempt.metrics.moralSurplus == 0, "Exact clear metrics")
    try require(exact.attempt.philosophy.primaryID == "bureaucrat", "Exact requirement affinity")
    try require(exact.attempt.achievements.contains(.perfectlyAdequate), "Adequacy achievement")
    let surplus = records.record(run(57))!.trolley!
    let m = surplus.attempt.metrics
    try require(m.lost == 3 && m.unavoidableLosses == 2 && m.avoidableLosses == 1, "Verified loss accounting")
    try require(m.moralSurplus == 17 && m.requirementSurplus == 17, "Surplus calculation")
    let dimensions = surplus.attempt.philosophy.dimensions
    let expectedPreservation = 57.0 / 58
    let expectedUtility = expectedPreservation * (0.6 * 57.0 / 65 + 0.4 * (1 - 8.0 / 30))
    try require(abs(dimensions[.preservation]! - expectedPreservation) < 0.000001, "Preservation scoring")
    try require(abs(dimensions[.sacrifice]! - 1.0 / 58) < 0.000001, "Sacrifice scoring")
    try require(abs(dimensions[.utility]! - expectedUtility) < 0.000001, "Resource efficiency scoring")
    try require(abs(dimensions[.pragmatism]! - 0.15) < 0.000001, "Pragmatism scoring")
    try require(abs(dimensions[.intervention]! - 8.0 / 65) < 0.000001, "Intervention scoring")
    try require(abs(m.rescuePotential! - 57.0 / 58) < 0.000001, "Potential used the requirement denominator")
    try require(surplus.retry.label == "Save one more" && surplus.retry.targetSaved == 58, "Last Lemming retry")
    try require(surplus.attempt.philosophy.titles.contains(.lastLemming) && surplus.attempt.achievements.contains(.oneMore), "Last Lemming title/achievement")
    let perfect = records.record(run(58, used: ["builder": 14]))!.trolley!
    try require(perfect.attempt.metrics.avoidableLosses == 0 && perfect.attempt.philosophy.titles.contains(.absolutist), "Perfect rescue")
    try require(perfect.attempt.philosophy.primaryID == "kant", "Specific deontologist affinity is unreachable behind a generic affinity")
    try require(perfect.attempt.achievements.contains(.noLemmingLeftBehind), "Perfect achievement")
    try require(!perfect.attempt.achievements.contains(.greaterGood), "Invented causal sacrifice")
    let failed = records.record(run(34, win: false, used: [:]))!.trolley!
    try require(!failed.attempt.run.didWin && failed.attempt.metrics.requirementSurplus == -6 && failed.attempt.metrics.moralSurplus == 0, "Failed requirement surplus")
    try require(failed.attempt.metrics.avoidableLosses == 24 && !failed.attempt.philosophy.primaryID.isEmpty, "Failure lost philosophy")
    let partial = records.record(run(12, win: false, released: 20, nuke: 1))!.trolley!
    try require(partial.attempt.metrics.lost == 8 && partial.attempt.metrics.unreleased == 40 && partial.attempt.metrics.unavoidableLosses == nil,
                "Partial release invented unavoidable deaths")
    let emptyMaximum = TrolleyMaximum()
    let unknownRun = run(34)
    let unknown = TrolleyMetrics(run: unknownRun, telemetry: unknownRun.telemetry!, maximum: emptyMaximum)
    try require(unknown.rescuePotential == nil && unknown.avoidableLosses == nil && unknown.unavoidableLosses == nil, "Unknown maximum fabricated statistics")
    let unknownPhilosophy = TrolleyAnalyser.analyse(run: unknownRun, metrics: unknown, maximum: emptyMaximum)
    try require(!unknownPhilosophy.measuredDimensions.contains(.sacrifice), "Unknown sacrifice marked measured")
    for _ in 0..<40 {
        let analysis = TrolleyAnalyser.analyse(run: surplus.attempt.run, metrics: m, maximum: surplus.attempt.maximum)
        try require(analysis == surplus.attempt.philosophy, "Classification is nondeterministic")
    }
    try require(Set(perfect.attempt.philosophy.dimensions.keys) == Set(TrolleyDimension.allCases), "Missing dimension")
    try require(perfect.attempt.philosophy.dimensions.values.allSatisfy { (0...1).contains($0) }, "Dimensions not normalised")
    let destructive = records.record(run(58, used: ["digger": 10]))!.trolley!
    try require(destructive.attempt.philosophy.primaryID != "kant", "Kant assigned solely for 100 percent")
    try require(!["sartre", "bentham", "trolley_operator"].contains(surplus.attempt.philosophy.primaryID), "Unsupported causal or unconventional affinity")
    var singerRecords = try verifiedRecords(conditions(), maximum: 60)
    let efficient = singerRecords.record(run(60, used: [:]))!.trolley!
    try require(efficient.attempt.philosophy.primaryID == "singer", "Very high resource efficiency did not select effective altruism")
    let zeroC = conditions(total: 2, required: 1)
    var zero = try verifiedRecords(zeroC, maximum: 0)
    let zeroRun = zero.record(run(0, c: zeroC, win: false))!.trolley!
    try require(zeroRun.attempt.metrics.rescuePotential == nil, "Zero maximum divided by zero")
    let failC = conditions(total: 55, required: 50)
    var failRecords = try verifiedRecords(failC, maximum: 52)
    let fail = failRecords.record(run(48, c: failC, win: false))!.trolley!
    try require(abs(fail.attempt.metrics.rescuePotential! - 48.0 / 52) < 0.000001 && fail.attempt.metrics.avoidableLosses == 4, "Failed 48/52 example")
    print("PASS exact clear, surplus, verified perfect, last Lemming, failed and partial attempts, six dimensions, deterministic evidence-gated philosophy")
}

func testRescueGoals() throws {
    let unknown = TrolleyMaximum()
    for maximum in [unknown, TrolleyMaximum(value: 40, status: .observed), evidence(58)] {
        try require(TrolleyRescueGoals(run: run(40), maximum: maximum).stars == 1, "Minimum clear must earn one star")
        try require(TrolleyRescueGoals(run: run(41), maximum: maximum).stars == 2, "Extra rescue must earn two stars")
    }
    let perfect = TrolleyRescueGoals(run: run(58), maximum: evidence(58))
    try require(perfect.stars == 3 && perfect.fullSaved == 58, "Verified unavoidable losses must not prevent three stars")
    let observed = TrolleyRescueGoals(run: run(58), maximum: .init(value: 58, status: .observed))
    try require(observed.stars == 2 && observed.fullSaved == nil, "Best known was treated as a perfect rescue")
    try require(TrolleyRescueGoals(run: run(60), maximum: unknown).stars == 3, "Everyone home should earn three stars without changing evidence")
    let allRequired = conditions(total: 10, required: 10)
    try require(TrolleyRescueGoals(run: run(10, c: allRequired), maximum: unknown).stars == 3, "An all-required level created an impossible extra goal")
    let minimumPerfect = TrolleyRescueGoals(run: run(40), maximum: evidence(40))
    try require(minimumPerfect.stars == 3 && minimumPerfect.extraSaved == 40, "Minimum equals verified maximum must satisfy all goals")
    try require(TrolleyRescueGoals(run: run(60, win: false), maximum: evidence(60)).stars == 0, "Stars overrode the engine failure")
    let clones = conditions(total: 5, required: 5, skills: ["cloner": 5])
    let unused = TrolleyRescueGoals(run: run(5, c: clones), maximum: unknown)
    try require(unused.stars == 1 && unused.fullSaved == nil, "Unused cloners were ignored by full rescue")
    try require(TrolleyRescueGoals(run: run(10, c: clones, released: 10, extra: ["cloned": 5]), maximum: unknown).stars == 3, "Full finite clone cohort not recognised")
    let unlimited = conditions(total: 5, required: 1, skills: ["cloner": -1])
    try require(TrolleyRescueGoals(run: run(5, c: unlimited), maximum: unknown).stars == 2, "Unlimited cloners created a false finite maximum")
    var records = try verifiedRecords()
    let snapshot = records.record(run(57))!.trolley!.attempt
    try records.acceptTrolleyMaximum(evidence(59), conditions: conditions(), assisted: false)
    try require(snapshot.goals.fullSaved == 58, "New evidence moved historical star targets")
    let data = try JSONEncoder().encode(snapshot)
    let decoded = try JSONDecoder().decode(TrolleyAttempt.self, from: data)
    try require(decoded.goals == snapshot.goals, "Stars did not survive reload")
    var old = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    old.removeValue(forKey: "rescueGoals")
    let migrated = try JSONDecoder().decode(TrolleyAttempt.self, from: JSONSerialization.data(withJSONObject: old))
    try require(migrated.rescueGoals == nil && migrated.goals == snapshot.goals, "Older attempts lost their immutable goal basis")
    print("PASS optional stars, exact clear, surplus, unavoidable losses, unverified evidence, clones, failures and goal migration")
}

func testEvidenceAndHistory() throws {
    let c = conditions()
    var records = ArcadeRecords()
    try require(records.trolley.maximum(conditions: c, assisted: false).status == .unknown, "Unknown metadata default")
    let observed = records.record(run(40))!.trolley!.attempt
    try require(observed.maximum.status == .observed && observed.maximum.value == 40, "First observed rescue")
    try require(observed.metrics.avoidableLosses == nil && observed.metrics.unavoidableLosses == nil, "Observed result claimed losses were avoidable")
    try require(observed.philosophy.dimensions[.preservation]! < 0.7, "Weak first result treated as optimal")
    _ = records.record(run(60))
    try require(records.trolley.maximum(conditions: c, assisted: false).status == .observed, "Population ceiling automatically verified")
    try records.acceptTrolleyMaximum(evidence(60), conditions: c, assisted: false)
    try require(records.trolley.attempts[0] == observed, "Verification rewrote history")
    try require(records.trolley.leaderboard(conditions: c, assisted: false, board: .rescuePotential).first?.metrics.rescuePotential == 1, "Existing attempts did not use the current target")
    let perfect = records.record(run(60))!.trolley!.attempt
    try require(records.trolley.leaderboard(conditions: c, assisted: false, board: .zeroAvoidableLosses).first?.run.saved == perfect.run.saved, "Verified perfect board")
    for _ in 0..<100 { _ = records.record(run(1, win: false)) }
    try require(records.trolley.attempts.count == 103 && records.trolley.attempts[0] == observed, "Immutable history was pruned")
    try require(records.record(observed.run) == nil, "Pruned legacy cache allowed duplicate historical attempt")
    try require(records.trolley.personal(profileID: ArcadeProfile.legacyID).bestSaved == 60, "Worse run replaced best")
    var contradicted = try verifiedRecords(maximum: 57)
    let old = contradicted.record(run(56))!.trolley!.attempt
    _ = contradicted.record(run(58))
    try require(contradicted.trolley.maximum(conditions: c, assisted: false).status == .observed, "Contradicted proof remained verified")
    try require(contradicted.trolley.attempts[0] == old, "Contradiction rewrote historical evidence")
    try require(contradicted.trolley.leaderboard(conditions: c, assisted: false, board: .rescuePotential).isEmpty, "Revoked proof stayed on current verified boards")
    do { try contradicted.acceptTrolleyMaximum(evidence(50), conditions: c, assisted: false); throw SequelDataError.invalid("Accepted proof below observation") }
    catch { try require(contradicted.trolley.maximum(conditions: c, assisted: false).value == 58, "Invalid proof changed maximum") }
    let damagedData = try JSONEncoder().encode(records)
    var damaged = try JSONSerialization.jsonObject(with: damagedData) as! [String: Any]
    var damagedHistory = damaged["trolley"] as! [String: Any]
    var damagedAttempts = damagedHistory["attempts"] as! [[String: Any]]
    var damagedRun = damagedAttempts[1]["run"] as! [String: Any]
    var damagedLevel = damagedRun["level"] as! [String: Any]
    damagedLevel.removeValue(forKey: "conditions"); damagedRun["level"] = damagedLevel
    damagedAttempts[1]["run"] = damagedRun; damagedHistory["attempts"] = damagedAttempts; damaged["trolley"] = damagedHistory
    var rejected = false
    do { _ = try JSONDecoder().decode(ArcadeRecords.self, from: JSONSerialization.data(withJSONObject: damaged)).validated() }
    catch { rejected = true }
    try require(rejected, "Malformed attempt conditions were accepted")
    var missingHistory = try JSONSerialization.jsonObject(with: damagedData) as! [String: Any]
    missingHistory.removeValue(forKey: "trolley"); rejected = false
    do { _ = try JSONDecoder().decode(ArcadeRecords.self, from: JSONSerialization.data(withJSONObject: missingHistory)).validated() }
    catch { rejected = true }
    try require(rejected, "Version 2 silently discarded missing history")
    try require(records.record(run(80)) == nil, "Impossible rescue silently clamped into legitimate history")
    let restored = try JSONDecoder().decode(ArcadeRecords.self, from: JSONEncoder().encode(records)).validated()
    try require(restored == records, "Full history failed to round-trip")
    print("PASS observed/verified discovery, proof conflicts, immutable snapshots, 103 retained attempts, duplicate prevention, save/reload")
}

func testBoardsProfilesAndMigration() throws {
    let c = conditions()
    var records = try verifiedRecords()
    let a = records.activeProfileID, b = records.addProfile(initials: "ACE", portrait: 3)!.id
    let first = records.record(run(57, owner: a, seconds: 100))!.trolley!.attempt
    let second = records.record(run(57, owner: b, seconds: 110))!.trolley!.attempt
    try require(TrolleyLeaderboards.precedes(first, second, board: .mostSaved), "Time tie breaker")
    let earlier = records.record(run(57, owner: b, seconds: 100, date: Date(timeIntervalSince1970: 900)))!.trolley!.attempt
    try require(TrolleyLeaderboards.precedes(earlier, first, board: .mostSaved), "Timestamp tie breaker")
    let lowID = records.record(run(57, owner: b, seconds: 100, id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!))!.trolley!.attempt
    let highID = records.record(run(57, owner: a, seconds: 100, id: UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")!))!.trolley!.attempt
    try require(TrolleyLeaderboards.precedes(lowID, highID, board: .mostSaved), "UUID tie breaker")
    _ = records.record(run(1, owner: a, win: false, used: [:]))
    try require(records.trolley.leaderboard(conditions: c, assisted: false, board: .leastSkills).allSatisfy { $0.run.didWin }, "Failure won least skills")
    for other in [conditions(fingerprint: "b"), conditions(rules: "different-physics"), conditions(total: 59),
                  conditions(skills: ["builder": 21]), conditions(time: 200), conditions(modifiers: ["easy": "true"]),
                  conditions(pack: "different-pack"), conditions(game: "another-game")] {
        try require(records.trolley.leaderboard(conditions: other, assisted: false, board: .mostSaved).isEmpty, "Incompatible conditions shared a board")
    }
    let canonical = conditions(skills: ["digger": 10, "builder": 20])
    try require(canonical.fingerprint == c.fingerprint, "Dictionary order changed identity")
    _ = records.record(run(60, owner: a, rewinds: 1))
    try require(records.trolley.leaderboard(conditions: c, assisted: false, board: .mostSaved).first?.run.saved == 57, "Rewind leaked into direct board")
    try require(records.trolley.personal(profileID: b).attempts == 3 && records.trolley.personal(profileID: a).bestSaved == 60, "Profile isolation")
    let startID = UUID()
    records.beginTrolleyAttempt(.init(id: startID, profileID: a, conditions: c, parentAttemptID: first.id, kind: .retryAfterSuccess))
    let conflicting = run(57, c: conditions(fingerprint: "changed-after-start"), owner: a, id: startID)
    try require(records.record(conflicting) == nil, "Completion changed its starting configuration identity")
    try require(records.trolley.personal(profileID: a).retriesAfterSuccessfulClears == 1, "Retry intent was lost before completion")
    try require(records.trolley.personal(profileID: a).totalSaved > 60, "Historical rescue total retained only records")
    try require(records.trolley.personal(profileID: a).skillUsage["builder"]! > 8, "Historical skill usage missing")
    let encoded = try JSONEncoder().encode(records)
    var legacy = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
    legacy["version"] = 1; legacy.removeValue(forKey: "trolley")
    let migrated = try JSONDecoder().decode(ArcadeRecords.self, from: JSONSerialization.data(withJSONObject: legacy)).validated()
    try require(migrated.profiles == records.profiles && migrated.statistics == records.statistics && migrated.runs == records.runs,
                "Legacy profile records or achievements changed")
    try require(migrated.trolley.attempts.isEmpty && migrated.trolley.starts.isEmpty, "Migration invented attempts")
    let payload = TrolleySubmission(attempt: first, anonymousPlayerID: "test-player", publicInitials: "LEM", spritePortrait: 3)
    let decodedPayload = try JSONDecoder().decode(TrolleySubmission.self, from: JSONEncoder().encode(payload))
    try require(decodedPayload == payload, "Submission did not round-trip")
    let exported = records.trolley.submission(attemptID: first.id)!
    let reloaded = try JSONDecoder().decode(ArcadeRecords.self, from: JSONEncoder().encode(records))
    try require(exported.anonymousPlayerID == reloaded.trolley.submission(attemptID: first.id)?.anonymousPlayerID,
                "Anonymous submission identity changed on reload")
    try require(exported.anonymousPlayerID != first.run.profileID, "Global identity reused the non-unique legacy profile ID")
    try require(payload.verification == .local && payload.submissionTimestamp == nil, "Export claimed online verification")
    print("PASS all identity dimensions, profile isolation, deterministic tie breakers, skill and personal records, retry history, legacy migration, submission model")
}

func testEngineFamilies() throws {
    for family in ["lemmings", "oh-no", "xmas-1991", "holiday-1994", "lemmings2", "lemmings3", "custom-neolemmix"] {
        let c = conditions(game: family, pack: family, rules: family + "-rules", required: family == "lemmings2" || family == "lemmings3" ? 1 : 40)
        var records = ArcadeRecords()
        let result = records.record(run(5, c: c, win: family == "lemmings2" || family == "lemmings3"))!.trolley!
        try require(result.attempt.run.level.conditions!.gameID == family && result.attempt.metrics.lost == 55, "Family adapter model lost data")
    }
    let c = conditions(game: "custom-neolemmix", total: 5, required: 5, skills: ["cloner": 5])
    var records = ArcadeRecords()
    let clone = records.record(run(8, c: c, used: ["cloner": 3], released: 8, extra: ["cloned": 3]))!.trolley!
    try require(clone.attempt.run.saved == 8 && clone.attempt.metrics.lost == 0 && clone.attempt.metrics.unreleased == 0, "Cloned population was truncated")
    try require(clone.retry.targetSaved == 9, "Clone retry used starting population as a false ceiling")
    try require(clone.attempt.run.level.conditions!.population == 5, "Starting population mutated with clones")
    print("PASS classic, Oh No, Xmas/Holiday, sequel and custom family identities; cloned population accounting")
}

@MainActor func testStoreAndVisuals() async throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".build/trolley")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let file = root.appendingPathComponent("test-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: file) }
    let store = ArcadeStore(file: file); ArcadeStore.shared = store
    let c = conditions()
    try store.acceptMaximum(evidence(58), conditions: c, assisted: false)
    let first = UUID()
    store.beginAttempt(id: first, profileID: ArcadeProfile.legacyID, level: level(c), previousID: nil)
    let report = store.record(run(57, id: first))!
    let retry = UUID()
    store.beginAttempt(id: retry, profileID: ArcadeProfile.legacyID, level: level(c), previousID: first)
    try require(store.records.trolley.starts.last?.kind == .retryAfterSuccess, "Store retry path")
    try require(store.progressKey("ClassicGameProgress.lemmings") == "ClassicGameProgress.lemmings", "Legacy campaign namespace moved")
    try require(ArcadeStore(file: file).records == store.records, "Store did not persist history")
    let artwork = try ClassicMacArtwork(directory: URL(fileURLWithPath: ".build/local/Ultimate Lemmings.app/Contents/Resources/MacArtwork/lemmings"))
    let view = ArcadeView(frame: CGRect(x: 0, y: 0, width: 1120, height: 720)); view.useArtwork(artwork)
    let menuLabel = MacInterfaceRenderer.menuText("Lémmings — retry ×2 ↵")
    try require(menuLabel == "LEMMINGS - RETRY X2 ENTER" && view.font?.font(.small)?.covers(menuLabel) == true,
                "Menu punctuation lost glyphs from the shipped bitmap font")
    let window = NSWindow(contentRect: view.frame, styleMask: [.titled, .resizable], backing: .buffered, defer: false)
    window.contentView = view
    view.mode = .result; view.level = report.run.level; view.report = report
    func shot(_ name: String, size: CGSize = CGSize(width: 1120, height: 720)) throws {
        window.setContentSize(size); view.frame = CGRect(origin: .zero, size: size)
        view.needsDisplay = true; view.layoutSubtreeIfNeeded()
        let pixels = CGSize(width: size.width * 2, height: size.height * 2)
        let image = ReplayFrameCapture.image(size: pixels) {
            NSGraphicsContext.current!.cgContext.scaleBy(x: 2, y: 2)
            ReplayFrameCapture.draw(view, in: view.bounds)
        }!
        let bitmap = NSBitmapImageRep(cgImage: image)
        try bitmap.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent(name + ".png"))
    }
    for size in [CGSize(width: 1120, height: 720), CGSize(width: 960, height: 600), CGSize(width: 640, height: 400), CGSize(width: 1280, height: 960)] {
        try shot("last-lemming-\(Int(size.width))", size: size)
        try require(view.accessibilityLabel()?.contains("Required: 40") == true, "Rescue requirement not accessible")
    }
    var retries = 0, continues = 0
    view.onRetry = { retries += 1 }; view.onContinue = { continues += 1 }
    func key(_ value: String, code: UInt16 = 0) {
        view.keyDown(with: NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: window.windowNumber, context: nil, characters: value, charactersIgnoringModifiers: value,
            isARepeat: false, keyCode: code)!)
    }
    key("r"); key("\r", code: 36)
    try require(retries == 1 && continues == 1, "Trolley keyboard retry/continue")
    try shot("last-lemming")
    func click(_ x: CGFloat, _ y: CGFloat = 597) {
        let point = view.convert(CGPoint(x: x, y: y), to: nil)
        view.mouseDown(with: NSEvent.mouseEvent(with: .leftMouseDown, location: point, modifierFlags: [], timestamp: 0,
            windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!)
    }
    func clickButton(_ label: String) throws {
        let elements = (view.accessibilityChildren() ?? []).compactMap { $0 as? GameAccessibleElement }
        guard let element = elements.first(where: { $0.accessibilityRole() == .button && $0.accessibilityLabel() == label }) else {
            throw SequelDataError.invalid("Missing rendered button: \(label)")
        }
        let frame = element.accessibilityFrame()
        let point = window.convertPoint(fromScreen: CGPoint(x: frame.midX, y: frame.midY))
        view.mouseDown(with: NSEvent.mouseEvent(with: .leftMouseDown, location: point, modifierFlags: [], timestamp: 0,
            windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!)
    }
    try clickButton("Next level")
    try require(continues == 2 && retries == 1, "Successful primary mouse action must advance")
    try clickButton("Retry")
    try require(retries == 2, "Optional mouse retry is unavailable")
    for saved in [40, 41, 58] {
        view.report = store.record(run(saved, used: ["builder": saved == 58 ? 9 : 8])); try shot("stars-\(saved)")
        try require(view.primaryResultTitle == "Next level", "Stars changed the successful primary action")
        let before = continues
        key("\r", code: 36)
        try require(continues == before + 1 && retries == 2, "A successful clear forced a retry")
    }
    view.report = store.record(run(34, win: false)); try shot("failed-default")
    let beforeFailure = continues
    key("\r", code: 36); try clickButton("Try again")
    try require(retries == 4 && continues == beforeFailure, "Failure primary mouse and Enter must retry")
    view.report = report; try shot("last-lemming")
    let newAwards = Set(report.trolley!.attempt.achievements)
    try require(newAwards.count > 1, "New-award navigation needs a result with several awards")
    func hasAwardHighlight(_ name: String) -> Bool {
        guard let data = try? Data(contentsOf: root.appendingPathComponent(name + ".png")),
              let image = NSBitmapImageRep(data: data) else { return false }
        return (256..<608).filter { y in
            guard let color = image.colorAt(x: 132, y: y * 2)?.usingColorSpace(.deviceRGB) else { return false }
            return color.redComponent > 0.9 && color.greenComponent > 0.6 && color.blueComponent < 0.45
        }.count > 16
    }
    try clickButton("\(newAwards.count) new awards >")
    var visitedAwards = Set<TrolleyAchievement>()
    for index in 0..<newAwards.count {
        let name = "new-awards-\(index + 1)"
        try shot(name)
        guard let focused = view.focusedNewAward else { throw SequelDataError.invalid("New award was not focused") }
        try require(view.mode == .awards && newAwards.contains(focused) && visitedAwards.insert(focused).inserted,
                    "Next new repeated or opened an unrelated award")
        try require(view.accessibilityLabel()?.contains("NEW - Earned: \(focused.title).") == true && hasAwardHighlight(name),
                    "The new award lacks its label or visible highlight")
        click(730, 228)
    }
    try require(visitedAwards == newAwards, "Next new did not reach every award from the result")
    view.report = nil
    try shot("new-awards-cleared")
    try require(view.accessibilityLabel()?.contains("NEW - ") == false && !hasAwardHighlight("new-awards-cleared"),
                "New-award highlights leaked into normal records browsing")
    view.report = report; view.mode = .result; try shot("last-lemming")
    key(" ", code: 49)
    try require(continues == beforeFailure + 1, "Space did not follow the visible successful default")
    for (name, saved, used) in [("perfect", 58, ["builder": 10]), ("failed", 34, ["digger": 3]), ("bureaucrat", 40, ["builder": 8])] {
        view.report = store.record(run(saved, used: used)); try shot(name)
    }
    var unknownRecords = ArcadeRecords()
    view.report = unknownRecords.record(run(12, win: false)); try shot("observed")
    view.report = report
    key("b"); key("2"); try shot("verified-board")
    try require(view.trolleyBoard == .rescuePotential, "Seven-board keyboard selection")
    click(985, 232)
    try require(view.assisted && view.mode == .records, "Rewind filter navigated instead of filtering")
    try shot("rewind-used")
    click(985, 232)
    try require(view.assisted, "Selecting the active rewind filter toggled it off")
    click(850, 232)
    try require(!view.assisted && view.mode == .records, "Unused rewind filter failed")
    key("w")
    try require(view.assisted, "Keyboard rewind filter failed")
    key("d"); try shot("filtered-run-details")
    try require(view.accessibilityLabel()?.contains("Personal best: 58") == true,
                "The records filter changed the original run's personal history")
    view.assisted = false
    view.mode = .details; try shot("affinity-details")
    window.makeKeyAndOrderFront(nil)
    let affinity = TrolleyAnalyser.archetype(report.trolley!.attempt.philosophy.primaryID)
    try clickButton(affinity.name)
    try require(view.affinityPopover?.isShown == true && view.mode == .details, "Affinity did not open a popover")
    let popup = view.affinityPopover!.contentViewController!.view
    let popupBitmap = popup.bitmapImageRepForCachingDisplay(in: popup.bounds)!
    popup.cacheDisplay(in: popup.bounds, to: popupBitmap)
    try popupBitmap.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent("affinity-popover.png"))
    let beforePopoverClose = continues
    key("", code: 53)
    try require(view.affinityPopover?.isShown == false && view.mode == .details && continues == beforePopoverClose,
                "Closing the affinity popover left the result or advanced play")
    key("a"); view.awardPage = 0; key("", code: 124)
    try require(view.awardPage == 1, "Award pages lacked keyboard navigation")
    try shot("philosophical-awards")
    for page in 0..<view.awardPageCount {
        view.awardPage = page; try shot("awards-\(page + 1)")
    }
    key("", code: 124)
    try require(view.awardPage == 0, "Award navigation did not wrap at the last page")
    key("", code: 123)
    try require(view.awardPage == view.awardPageCount - 1, "Award navigation did not wrap to the last page")
    key("d"); try shot("details")
    try require(view.accessibilityLabel()?.contains("Still in hatch") == false, "A zero hatch count cluttered the run details")
    try require(view.accessibilityLabel()?.contains("Rescued / required") == false, "Details combine distinct stats")
    let savedReport = view.report
    view.report = store.record(run(12, win: false, released: 20, nuke: 1))
    try shot("partial-run-details")
    try require(view.accessibilityLabel()?.contains("Still in hatch: 40") == true,
                "An ended partial run lost its hatch count")
    view.report = savedReport
    let beforeBack = continues
    key("\r", code: 36)
    try require(continues == beforeBack && view.mode == .result, "Records navigation advanced the game")
    view.mode = .profiles; view.selectProfile(store.records.activeProfile); try shot("profiles")
    for mode in [ArcadeView.Mode.records, .awards, .details, .profiles] {
        view.mode = mode
        try shot("page-\(mode)-640", size: CGSize(width: 640, height: 400))
    }
    view.report = report; view.mode = .result
    try shot("reward-overview")
    let actionsBeforeGoals = continues
    key("g"); try shot("reward-level-goals")
    try require(view.mode == .goals && view.accessibilityLabel()?.contains("Target met") == true, "Level goal link is missing")
    key("\r", code: 36); key("c"); try shot("reward-career-progress")
    try require(view.mode == .career && view.accessibilityLabel()?.contains("distinct levels") == true, "Career progress omitted level totals")
    key("", code: 124); try shot("reward-career-page-2")
    try require(view.careerPage == 1 && continues == actionsBeforeGoals, "Career paging advanced the campaign")
    key("\r", code: 36)
    view.mode = .records; view.boardScope = .career; try shot("reward-career-board")
    view.openWorldwideBoard(); try shot("reward-worldwide-unavailable")
    try require(view.accessibilityLabel()?.contains("not enabled") == true, "Unavailable worldwide service was not explained")
    for (mode, scope) in [(ArcadeView.Mode.goals, ArcadeView.BoardScope.level), (.career, .level), (.records, .career), (.records, .worldwide)] {
        view.mode = mode; view.boardScope = scope
        try shot("reward-\(mode)-\(scope)-640", size: CGSize(width: 640, height: 400))
    }
    view.boardScope = .level; view.mode = .result; view.report = report
    try shot("reward-sequence-before")
    view.startCelebration(reduceMotion: false)
    try require(view.revealedStars == 0, "Reward sequence did not start with empty stars")
    for _ in 0..<150 where view.revealedStars == 0 { try await Task.sleep(for: .milliseconds(10)) }
    try require(view.revealedStars == 1, "First star was not revealed separately: stars=\(view.revealedStars), hidden=\(view.isHidden), window=\(view.window != nil), mode=\(view.mode)")
    try shot("reward-first-star")
    view.page(.goals)
    try require(view.celebrationTask == nil && view.revealedStars == 3, "Leaving results did not cancel the sequence")
    view.mode = .result; view.startCelebration(reduceMotion: true)
    try require(view.revealedStars == 3 && view.celebrationTask == nil, "Reduced Motion still animated rewards")
    view.startCelebration(reduceMotion: false)
    for _ in 0..<200 where view.celebrationTask != nil { try await Task.sleep(for: .milliseconds(10)) }
    try require(view.revealedStars == 3 && view.celebrationTask == nil, "Reward sequence did not finish")
    let windows = NSApp.windows.count
    let backdrop = ArcadeWindow.captureScene(view)
    ArcadeWindow.shared.showResult(report, owner: window, retry: {}, next: {}, replay: { _ in }, background: backdrop)
    try require(ArcadeWindow.shared.arcadeView.window === window && NSApp.windows.count == windows, "Trolley opened another window")
    try require(backdrop != nil && ArcadeWindow.shared.arcadeView.background === backdrop, "Result lost its game backdrop")
    ArcadeWindow.shared.close()
    // Preserve evidence through an immediate retry while the asynchronous encoder finishes.
    let movie = RunMovie(); movie.begin(ticksPerSecond: 17, title: "Trolley test")
    let image = ReplayFrameCapture.image(size: CGSize(width: 64, height: 48)) { NSColor.blue.setFill(); NSBezierPath(rect: CGRect(x: 0, y: 0, width: 64, height: 48)).fill() }!
    for _ in 0..<8 { movie.capture(image) }
    movie.finish(); movie.preserveRecord(report)
    movie.begin(ticksPerSecond: 17, title: "Immediate retry")
    for _ in 0..<100 where store.records.trolley.replays.isEmpty { try await Task.sleep(for: .milliseconds(100)) }
    try require(store.records.trolley.replays.first?.attemptID == first, "Record movie lost on immediate retry")
    try require(store.records.trolley.replays.first?.verification == .local, "Movie claimed verified replay")
    try store.acceptMaximum(.init(value: 58, status: .record, source: "Native test record", date: Date(), buildVersion: "test-1"), conditions: c, assisted: false)
    view.report = store.record(run(58))!; view.mode = .result
    try shot("best-known-result")
    try require(view.accessibilityLabel()?.contains("Best known: 58") == true, "Best-known target not accessible")
    try shot("best-known-result-640", size: CGSize(width: 640, height: 400))
    view.mode = .records; view.trolleyBoard = .zeroAvoidableLosses
    try shot("best-known-board")
    view.mode = .details; try shot("best-known-details")
    view.report = store.record(run(59))!; view.mode = .result
    try shot("falsifier-result")
    try require(view.accessibilityLabel()?.contains("Karl Popper") == true, "Falsifier is not accessible")
    try shot("falsifier-result-640", size: CGSize(width: 640, height: 400))
    view.mode = .awards
    for (index, group) in TrolleyAchievementGroup.allCases.enumerated() {
        key(String(index + 1))
        try require(view.awardGroup == group && view.awardPage == 0, "Collection shortcut failed")
        for page in 0..<view.awardPageCount {
            view.awardPage = page
            try shot("collection-\(group.rawValue)-\(page + 1)")
        }
        view.awardPage = 0
        try shot("collection-\(group.rawValue)-640", size: CGSize(width: 640, height: 400))
    }
    view.mode = .records; view.trolleyBoard = .cleanRescue
    try shot("collection-board-link")
    click(400, 565)
    try require(view.mode == .awards && view.awardGroup == .rivalries, "Leaderboard did not open its achievement")
    window.orderOut(nil)
    print("PASS store, clean retry provenance, movie retention across retry, in-game hierarchy, keyboard/mouse, accessibility and four render sizes")
}

@MainActor func testBestKnownTargets() throws {
    let root = URL(fileURLWithPath: "Resources/Trolley")
    let shipped = TrolleyBundledProofs.load(from: root)!
    let classic = shipped.catalogue.levels.filter { $0.conditions?.gameID == "lemmings" }
    try require(classic.count == 120, "Not all Classic targets were bundled")
    try require(classic.filter { $0.status == "REPLAY_RECORD" }.count == 17, "Missing sacrifice records")
    for entry in classic {
        let c = entry.conditions!, target = shipped.maximum(for: c)!
        try require(target.value == entry.witness?.saved, "Target differs from replay")
        if target.status == .record {
            try require(shipped.catalogue.maximum(for: c, engineFingerprint: shipped.engineFingerprint) == nil,
                        "Record promoted to upper-bound proof")
        }
    }
    let c = conditions()
    var records = ArcadeRecords()
    let old = records.record(run(58))!.trolley!.attempt
    let target = TrolleyMaximum(value: 58, status: .record, source: TrolleyProofCatalogue.recordPrefix + "test",
                                date: Date(timeIntervalSince1970: 500), buildVersion: "test-1")
    try records.acceptTrolleyMaximum(target, conditions: c, assisted: false)
    let board = records.trolley.leaderboard(conditions: c, assisted: false, board: .zeroAvoidableLosses)
    try require(board.count == 1 && board[0].goals.stars == 3 && board[0].targetSacrifices == 2,
                "Existing rescue was not assessed against the record")
    try require(board[0].metrics.unavoidableLosses == nil && records.trolley.attempts[0] == old,
                "Reassessment invented proof or rewrote history")
    let short = records.record(run(57))!.trolley!.attempt
    try require(short.philosophy.preservationBasis == "best-known-record", "Utility did not use the rescue target")
    try require(short.goals.stars == 2 && short.rescueShortfall == 1, "Record shortfall is wrong")
    try require(TrolleyRetryTarget.suggest(board[0], previousBest: nil, localBest: nil).targetSaved == 58,
                "Matched record demanded another rescue")
    let improved = records.record(run(59))!.trolley!.attempt
    try require(improved.goals.stars == 3 && improved.maximum.value == 59, "Better rescue lost its stars")
    _ = try JSONDecoder().decode(ArcadeRecords.self, from: JSONEncoder().encode(records)).validated()
    records.retainBundledTrolleyMaxima([:])
    try require(records.trolley.maximum(conditions: c, assisted: false).status == .observed,
                "Expired record remained a target")
    print("PASS all 120 targets, record stars, current leaderboards, immutable history, improvements and expiry")
}

func testFalsifierAward() throws {
    let c = conditions()
    for status in [TrolleyMaximumStatus.record, .verified] {
        var records = ArcadeRecords()
        let target = TrolleyMaximum(value: 58, status: status, source: "Test estimate", date: Date(), buildVersion: "test-1")
        try records.acceptTrolleyMaximum(target, conditions: c, assisted: false)
        let match = records.record(run(58))!.trolley!.attempt
        try require(!match.achievements.contains(.falsifier), "Matching the target earned Falsifier")
        let beaten = records.record(run(59))!.trolley!.attempt
        try require(beaten.achievements.contains(.falsifier) && beaten.philosophy.primaryID == "popper"
                    && beaten.surpassedTarget == target, "Beaten estimate lost its philosopher award or evidence")
        try require(beaten.philosophy.contextualLine.contains("58") && beaten.philosophy.contextualLine.contains("59"), "Award lacks the previous count")
        let later = beaten.assessed(using: evidence(60))
        try require(later.philosophy.primaryID == "popper" && later.surpassedTarget == target,
                    "Reassessment erased the discovery")
        let repeated = records.record(run(59))!.trolley!.attempt
        try require(!repeated.achievements.contains(.falsifier), "The achievement was awarded twice")
        let restored = try JSONDecoder().decode(ArcadeRecords.self, from: JSONEncoder().encode(records)).validated()
        try require(restored.trolley.attempts == records.trolley.attempts, "Discovery failed to survive reload")
    }
    var observed = ArcadeRecords()
    _ = observed.record(run(40))
    try require(!observed.record(run(59))!.trolley!.attempt.achievements.contains(.falsifier), "Personal best earned Falsifier")
    var failed = try verifiedRecords(maximum: 58)
    try require(!failed.record(run(59, win: false))!.trolley!.attempt.achievements.contains(.falsifier), "Failed run earned Falsifier")
    try require(failed.record(run(61)) == nil, "Impossible population earned Falsifier")
    var other = try verifiedRecords(maximum: 58)
    try require(!other.record(run(59, c: conditions(fingerprint: "other")))!.trolley!.attempt.achievements.contains(.falsifier), "Different level inherited an estimate")
    try require(!other.record(run(59, rewinds: 1))!.trolley!.attempt.achievements.contains(.falsifier), "Different assistance conditions inherited an estimate")
    print("PASS Falsifier for beaten records and proofs, strict thresholds, history, expiry and invalid runs")
}

func testAchievementCollections() throws {
    let c = conditions()
    try require([TrolleyAchievement.bentham, .sartre, .operator, .greaterGood, .trolleyProblem].allSatisfy { !$0.isOffered },
                "Unsupported evidence objectives are offered as achievements")
    var career = ArcadeRecords()
    _ = career.record(run(60, c: conditions(level: "career-first"), used: ["builder": 1]))
    _ = career.record(run(40, c: conditions(level: "career-second"), used: [:]))
    let careerAwards = career.careerAchievements(profileID: ArcadeProfile.legacyID)
    try require(careerAwards.contains(.allHome) && careerAwards.contains(.noSkills) && careerAwards.contains(.oneSkill),
                "Career achievements are still restricted to one level")
    try require(career.careerAchievements(profileID: "another-player").isEmpty, "Career awards leaked across profiles")
    try require(TrolleyAnalyser.archetypes.allSatisfy { !$0.philosophySummary.isEmpty && !$0.affinityDescription.contains("The game asked") },
                "Affinity explanations contain result narration")
    for philosopher in TrolleyAnalyser.archetypes {
        let award = TrolleyAchievement.forPhilosopher(philosopher.id)
        try require(award != nil && philosopher.achievementHooks.contains(award!), "Philosopher is disconnected from achievements")
    }
    for board in TrolleyBoard.allCases {
        try require(TrolleyAchievement.forBoard(board).group == .rivalries, "Board is disconnected from its trophy")
    }
    var empty = try verifiedRecords()
    let first = empty.record(run(58))!.trolley!.attempt
    try require(first.achievements.contains(.recordMatched) && first.achievements.contains(TrolleyAchievement.forPhilosopher(first.philosophy.primaryID)!), "First clear missed rescue or philosophy awards")
    try require(!first.achievements.contains(.rescueRival) && !first.achievements.contains(.cleanSweep) && !first.achievements.contains(.tripleCrown), "Empty board granted rivalry trophies")
    let rivalID = empty.addProfile(initials: "ACE", portrait: 2)!.id
    let tie = empty.record(run(58, owner: rivalID, date: Date(timeIntervalSince1970: 100)))!.trolley!.attempt
    try require(!tie.achievements.contains(.cleanSweep) && !tie.achievements.contains(.tripleCrown), "Timestamp tie earned a rivalry trophy")
    var contest = try verifiedRecords()
    let rival = contest.addProfile(initials: "RIV", portrait: 1)!.id
    _ = contest.record(run(50, owner: rival, used: ["builder": 10], seconds: 150))
    let champion = contest.record(run(58, used: ["builder": 8], seconds: 120))!.trolley!.attempt
    try require([TrolleyAchievement.rescueRival, .cleanSweep, .tripleCrown].allSatisfy(champion.achievements.contains), "Real rival takeover missed trophies")
    var efficiency = try verifiedRecords()
    _ = efficiency.record(run(50, used: ["builder": 10]))
    let improvement = efficiency.record(run(58, used: ["builder": 8]))!.trolley!.attempt
    try require(improvement.achievements.contains(.economist) && improvement.achievements.contains(.potentialRival), "Meaningful efficiency and rescue improvement missed awards")
    try require(!improvement.achievements.contains(.rescueRival), "Own record counted as a rival")
    var tradeoff = try verifiedRecords()
    _ = tradeoff.record(run(50, used: ["builder": 10]))
    try require(!tradeoff.record(run(49, used: ["builder": 1]))!.trolley!.attempt.achievements.contains(.economist), "Fewer rescues earned efficiency trophy")
    var retry = try verifiedRecords()
    let loss = retry.record(run(39, win: false))!.trolley!.attempt
    let retryID = UUID()
    retry.beginTrolleyAttempt(.init(id: retryID, profileID: ArcadeProfile.legacyID, conditions: c, parentAttemptID: loss.id, kind: .retryAfterFailure))
    let recovered = retry.record(run(40, id: retryID))!.trolley!.attempt
    try require(recovered.achievements.contains(.comeback), "Linked recovery missed its award")
    let successID = UUID()
    retry.beginTrolleyAttempt(.init(id: successID, profileID: ArcadeProfile.legacyID, conditions: c, parentAttemptID: recovered.id, kind: .retryAfterSuccess))
    try require(retry.record(run(41, id: successID))!.trolley!.attempt.achievements.contains(.secondThoughts), "Optional improved retry missed its award")
    var mastery = ArcadeRecords()
    for number in 1...30 {
        let current = conditions(level: "level-\(number)")
        try mastery.acceptTrolleyMaximum(evidence(58), conditions: current, assisted: false)
        let a = mastery.record(run(58, c: current))!.trolley!.attempt
        if number == 3 { try require(a.achievements.contains(.targetApprentice), "Three-level milestone missed") }
        if number == 5 { try require(a.achievements.contains(.unbrokenArgument) && a.achievements.contains(.schoolOfThought), "Distinct streak or affinity mastery missed") }
        if number == 10 { try require(a.achievements.contains(.targetScholar), "Ten-level milestone missed") }
        if number == 29 { try require(TrolleyAchievement.targetSage.progress(attempts: mastery.trolley.attempts, profileID: ArcadeProfile.legacyID).value == 29, "Progress counter is inaccurate") }
        if number == 30 { try require(a.achievements.contains(.targetSage), "Thirty-level milestone missed") }
    }
    var repeats = try verifiedRecords()
    for _ in 0..<5 { _ = repeats.record(run(58)) }
    try require(TrolleyAchievement.targetApprentice.progress(attempts: repeats.trolley.attempts, profileID: ArcadeProfile.legacyID).value == 1, "Repeated level farmed mastery")
    try require(!repeats.trolley.personal(profileID: ArcadeProfile.legacyID).achievements.contains(.unbrokenArgument), "Repeated level farmed streak")
    try require(TrolleyAchievement.targetSage.progress(attempts: mastery.trolley.attempts, profileID: "another-player").value == 0, "Achievement progress crossed profiles")
    let restored = try JSONDecoder().decode(ArcadeRecords.self, from: JSONEncoder().encode(mastery)).validated()
    try require(restored == mastery, "Collections did not survive reload")
    print("PASS philosophy hooks, seven boards, real rivalries, ties, efficiency, retries, mastery, progress and profile isolation")
}

func testCelebrationProgress() throws {
    var records = try verifiedRecords()
    let first = records.record(run(40))!
    let a = TrolleyCelebration(report: first, history: records.trolley)
    try require(a.goals.stars == 1 && a.addedStars == 1 && a.nextGoal.contains("1 more"), "First clear must show its first star and next rescue")
    let second = records.record(run(57))!
    let b = TrolleyCelebration(report: second, history: records.trolley)
    try require(b.goals.stars == 2 && b.career.stars == 2 && b.addedStars == 1 && b.nextGoal.contains("SO CLOSE! 1 more"), "Near miss or career star delta is wrong")
    try require(b.recordMessage.contains("40 > 57") && b.newAwards.allSatisfy { $0.isNew }, "Result did not explain the personal record")
    let third = records.record(run(58))!
    let c = TrolleyCelebration(report: third, history: records.trolley)
    try require(c.goals.stars == 3 && c.career.stars == 3 && c.addedStars == 1 && c.career.threeStarLevels == 1, "Three-star clear did not upgrade one level")
    let repeatRun = records.record(run(58))!
    let repeated = TrolleyCelebration(report: repeatRun, history: records.trolley)
    try require(repeated.addedStars == 0 && repeated.newAwards.isEmpty && repeated.career.clearedLevels == 1, "Repeated run farmed stars or repeated awards")
    try require(TrolleyCelebration(report: first, history: records.trolley).career.stars == 1, "A previous result included later progress")
    let loss = records.record(run(58, win: false))!
    let failed = TrolleyCelebration(report: loss, history: records.trolley)
    try require(failed.goals.stars == 0 && failed.bestStars == 3 && failed.career.stars == 3 && failed.nextGoal.contains("Complete the level"), "Failed clear awarded stars or erased bests")
    let other = conditions(level: "fun-2")
    try records.acceptTrolleyMaximum(evidence(58), conditions: other, assisted: false)
    let next = records.record(run(58, c: other))!
    let nextResult = TrolleyCelebration(report: next, history: records.trolley)
    try require(nextResult.career.stars == 6 && nextResult.career.clearedLevels == 2, "Distinct levels failed to add stars")
    let assisted = records.record(run(60, rewinds: 1))!
    let assistedResult = TrolleyCelebration(report: assisted, history: records.trolley)
    try require(assistedResult.career.stars == 3 && assistedResult.careerBefore.stars == 0, "Rewind stars mixed with unassisted stars")
    let moral = TrolleyAchievement.moralSurplus.progress(attempts: records.trolley.attempts, profileID: ArcadeProfile.legacyID)
    try require(moral.goal == 100 && moral.value > 1, "Cumulative rescue progress still uses a binary counter")
    let absolute = TrolleyAchievement.absoluteMaximum.progress(attempts: records.trolley.attempts, profileID: ArcadeProfile.legacyID)
    try require(absolute.goal == 10 && absolute.value == 2, "Verified distinct-level progress is wrong")
    var rivals = try verifiedRecords()
    let rival = rivals.addProfile(initials: "RIV", portrait: 1)!
    _ = rivals.record(run(57, owner: rival.id))
    _ = rivals.record(run(40))
    let takeover = rivals.record(run(58))!
    let change = TrolleyCelebration(report: takeover, history: rivals.trolley).ranks.first!
    try require(change.before == 2 && change.after == 1 && change.players == 2 && change.label.contains("#2 > #1"), "Local rank change is not backed by the board")
    var unknown = ArcadeRecords()
    let unknownRun = unknown.record(run(41))!
    try require(TrolleyCelebration(report: unknownRun, history: unknown.trolley).nextGoal.contains("unknown"), "Unknown maximum invented a three-star target")
    let config = TrolleyOnlineConfiguration(enabled: true, starsID: "stars", clearsID: "clears", perfectID: "perfect",
        levels: [.init(conditions: conditions(), maximum: evidence(58), leaderboardID: "level")])
    try require(config.isValid, "Test online catalogue is invalid")
    let scores = config.scores(attempts: records.trolley.attempts, profileID: ArcadeProfile.legacyID)
    try require(scores == ["stars": 3, "clears": 1, "perfect": 1, "level": 58], "Online score accepted rewinds, an unlisted level, or duplicate stars")
    _ = records.record(run(60, c: conditions(fingerprint: "modified")))
    try require(config.scores(attempts: records.trolley.attempts, profileID: ArcadeProfile.legacyID) == scores, "Changed level entered a worldwide board")
    try require(config.scores(attempts: records.trolley.attempts, profileID: "other").isEmpty, "Online submissions crossed player profiles")
    let catalogue = try JSONDecoder().decode(TrolleyOnlineConfiguration.self, from: Data(contentsOf: URL(fileURLWithPath: "Resources/GameCenter/leaderboards.json")))
    try require(catalogue.isValid && !catalogue.enabled && catalogue.levels.count == 178, "Release catalogue is invalid or enabled without Apple setup")
    print("PASS reward deltas, near misses, persistent bests, local rank changes, career deduplication and exact online conditions")
}

@MainActor final class TestGameCenterTransport: GameCenterTransport {
    var account: GameCenterAccount? = .init(id: "apple-player", name: "Test Player")
    var submissions: [(String, Int)] = []
    var offline = true
    var loads = 0
    func authenticate(window: NSWindow?, completion: @escaping @MainActor (Result<GameCenterAccount, Error>) -> Void) {
        completion(.success(account!))
    }
    func submit(_ score: Int, boardID: String) async throws {
        if offline { throw SequelDataError.invalid("offline") }
        submissions.append((boardID, score))
    }
    func load(_ boardID: String) async throws -> WorldwideBoard {
        loads += 1
        if offline { throw SequelDataError.invalid("offline") }
        return .init(entries: [.init(rank: 1, name: "Test Player", score: 3)],
                     personal: .init(rank: 1, name: "Test Player", score: 3), players: 1)
    }
}
@MainActor func testGameCenterSync() async throws {
    let suite = "Lemmings.GameCenter.Tests." + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let transport = TestGameCenterTransport()
    let config = TrolleyOnlineConfiguration(enabled: true, starsID: "stars", clearsID: "clears", perfectID: "perfect",
        levels: [.init(conditions: conditions(), maximum: evidence(58), leaderboardID: "level")])
    var records = try verifiedRecords(); _ = records.record(run(58))
    let service = GameCenterScores(configuration: config, transport: transport, defaults: defaults)
    func settle() async throws {
        for _ in 0..<100 where service.busy { try await Task.sleep(for: .milliseconds(10)) }
        try require(!service.busy, "Game Center operation failed to settle")
    }
    service.connect(profileID: ArcadeProfile.legacyID, window: nil, boardID: "stars", history: records.trolley)
    try await settle()
    try require(service.board == nil && service.status.contains("saved") && transport.submissions.isEmpty, "Offline Game Center invented a score or lost local status")
    transport.offline = false
    service.refresh(profileID: ArcadeProfile.legacyID, boardID: "stars", history: records.trolley)
    try await settle()
    try require(transport.submissions.count == 4 && service.board?.personal?.rank == 1, "Reconnection did not submit retained history and load a real rank")
    service.refresh(profileID: ArcadeProfile.legacyID, boardID: "stars", history: records.trolley)
    try await settle()
    try require(transport.submissions.count == 4, "Refreshing repeated already synced scores")
    service.refresh(profileID: "another-profile", boardID: "stars", history: records.trolley)
    try await settle()
    try require(transport.submissions.count == 4 && service.status.contains("different local player"), "Game Center merged local players")
    let disabled = TrolleyOnlineConfiguration(enabled: false, starsID: "stars", clearsID: "clears", perfectID: "perfect", levels: config.levels)
    let unavailable = GameCenterScores(configuration: disabled, transport: transport, defaults: defaults)
    let loads = transport.loads
    unavailable.connect(profileID: ArcadeProfile.legacyID, window: nil, boardID: "stars", history: records.trolley)
    try require(!unavailable.busy && unavailable.board == nil && transport.loads == loads, "Disabled Game Center called the network")
    print("PASS Game Center transport: offline recovery, real rank display, duplicate suppression and local-player ownership")
}

let app = NSApplication.shared; app.setActivationPolicy(.accessory)
Task { @MainActor in
    do {
        try testBundledMaximumProofs(); try testBestKnownTargets(); try testFalsifierAward(); try testAchievementCollections()
        try testMetricsAndClassification(); try testRescueGoals(); try testEvidenceAndHistory(); try testBoardsProfilesAndMigration(); try testEngineFamilies()
        try testCelebrationProgress(); try await testGameCenterSync()
        try await testStoreAndVisuals()
        print("PASS THE TROLLEY"); exit(0)
    } catch { print("FAIL: \(error)"); exit(1) }
}
app.run()
