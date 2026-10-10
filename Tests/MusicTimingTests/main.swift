import Foundation

func require(_ value: Bool, _ message: String) {
    precondition(value, message)
}
func fixture(bpm: Double = 120, first: Double = 0, status: String = "estimated-stable",
             loopStart: Double? = nil, downbeats: [Double]? = nil) throws -> MusicTimingCatalogue.Entry {
    var entry: [String: Any] = ["variantID": "test", "path": "test.wav", "sourceSHA256": String(repeating: "a", count: 64),
        "durationSeconds": 40, "baseBPM": bpm, "bpmStatus": status, "barStatus": status, "beatsPerBar": 4,
        "beats": stride(from: first, to: 40, by: 60 / bpm).map { $0 },
        "downbeats": downbeats ?? stride(from: first, to: 40, by: 240 / bpm).map { $0 }]
    if let loopStart { entry["tracker"] = ["loopStartSeconds": loopStart] }
    let data = try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "variants": [entry]])
    return try MusicTimingCatalogue(data: data).variants[0]
}
let outgoing = try fixture(), incoming = try fixture(first: 0.3)
let beat = outgoing.nextBeat(at: 0.7, rate: 1)!
require(abs(beat.delay - 0.3) < 0.001 && beat.bpm == 120, "Beat did not use measured source position")
require(abs(outgoing.nextBeat(at: 0.7, rate: 0.75)!.delay - 0.4) < 0.001, "Slowdown did not scale beat timing")
require(outgoing.nextBeat(at: 39.9, rate: 1) == nil, "The outro invented an extrapolated beat")
require(abs(outgoing.position(at: 40.25) - 0.25) < 0.001, "A recording loop lost its source position")
require(abs(try fixture(loopStart: 2).position(at: 42.25) - 4.25) < 0.001, "A module loop ignored its intro")
let plan = outgoing.barTransition(to: incoming, at: 0.7, outgoingRate: 1, incomingRate: 1, minimumDuration: 2.6)!
require(abs(plan.delay - 1) < 0.001 && plan.preRoll == 0.3, "Incoming pickup missed the outgoing downbeat")
require(plan.bars == 2 && plan.duration == 4, "The fade did not cover whole measured bars")
require(outgoing.barTransition(to: try fixture(bpm: 125), at: 0, outgoingRate: 1, incomingRate: 1, minimumDuration: 2.6) == nil,
        "Mismatched tempos claimed bar alignment")
require(outgoing.barTransition(to: try fixture(bpm: 125), at: 0, outgoingRate: 1, incomingRate: 0.96, minimumDuration: 2.6) != nil,
        "Matched tempos could not align")
require(outgoing.barTransition(to: try fixture(status: "needs-review"), at: 0, outgoingRate: 1, incomingRate: 1, minimumDuration: 2.6) == nil,
        "An uncertain grid entered bar mixing")
require(outgoing.barTransition(to: try fixture(first: 6), at: 0, outgoingRate: 1, incomingRate: 1, minimumDuration: 2.6) == nil,
        "A long intro delayed a game cue")
let missingBar = try fixture(downbeats: [0, 4, 6, 8, 10, 12, 14, 16, 18, 20])
require(outgoing.barTransition(to: missingBar, at: 0, outgoingRate: 1, incomingRate: 1, minimumDuration: 2.6) == nil,
        "A missed incoming downbeat entered bar mixing")
require(missingBar.barTransition(to: outgoing, at: 0, outgoingRate: 1, incomingRate: 1, minimumDuration: 6) == nil,
        "A missed outgoing downbeat entered bar mixing")
print("PASS measured beats, tempo scaling, loops, pickups, complete bars and safe fallbacks")

let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
let timing = try MusicTimingCatalogue(data: data)
require(timing.variants.count == 495, "Music timing omitted a playable version")
require(timing.variants.allSatisfy { $0.beats.isEmpty || $0.durationSeconds > $0.beats.last! - 0.02 }, "Beat escaped source duration")
var invalid = try JSONSerialization.jsonObject(with: data) as! [String: Any]
var rows = invalid["variants"] as! [[String: Any]]
rows[0]["beats"] = [1.0, 0.5]
invalid["variants"] = rows
var rejected = false
 do { _ = try MusicTimingCatalogue(data: JSONSerialization.data(withJSONObject: invalid)) }
 catch { rejected = true }
require(rejected, "An unordered grid passed validation")
print("PASS full timing catalogue coverage and malformed-grid rejection")
