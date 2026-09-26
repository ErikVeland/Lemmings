import Foundation
import NxlvKit

private struct Failure: Error, CustomStringConvertible { let description: String }
private func require(
    _ condition: @autoclosure () -> Bool, _ message: @autoclosure () -> String
) throws {
    guard condition() else { throw Failure(description: message()) }
}

private func sample(
    name: String, count: Int = 1200, loops: Bool = false, decaying: Bool = true
) -> ProTrackerSample {
    var data = [Int8](repeating: 0, count: count)
    for index in 0..<count {
        let progress = Double(index) / Double(count)
        // A hit is loud at the start and gone by the end; a held note is not.
        let envelope = decaying ? max(0, 1 - progress * 4) : 1
        let wave = sin(Double(index) * 0.35)
        data[index] = Int8(max(-127, min(127, wave * envelope * 120)))
    }
    return ProTrackerSample(
        name: name, data: data, finetune: 0, volume: 64,
        repeatStart: 0, repeatLength: loops ? 400 : 1)
}

private func testDrumNamesAreRecognised() throws {
    for name in ["BeefySnare", "bd", "kick", "drum2", "CYMBAL1.IFF", "hihat", "closedhat"] {
        try require(
            ProTrackerPercussion.nameSuggestsPercussion(name),
            "\"\(name)\" was not recognised as percussion")
    }
    print("PASS drum names are recognised")
}

private func testInstrumentsAreNotMistakenForDrums() throws {
    // "bass" alone names a bass line far more often than a bass drum, and
    // "marimba" contains "rim", which is why that word is not matched alone.
    for name in ["bass", "bassline", "MARIMBA1.IFF", "organ2", "strings2", "piano"] {
        try require(
            !ProTrackerPercussion.nameSuggestsPercussion(name),
            "\"\(name)\" was wrongly called percussion")
    }
    print("PASS melodic instruments are not mistaken for drums")
}

private func testShapeOnlySpeaksWhenTheNameDoesNot() throws {
    // Same waveform, two names. The named one must be left alone.
    let unnamed = sample(name: "")
    let named = sample(name: "organ2")
    try require(
        ProTrackerPercussion.evidence(for: unnamed) == .shape,
        "an unnamed hit was not caught by its shape")
    try require(
        ProTrackerPercussion.evidence(for: named) == nil,
        "a named instrument was centred on the strength of its shape alone")
    print("PASS shape is only consulted when the name says nothing")
}

private func testHeldAndLoopedSoundsAreNotHits() throws {
    try require(
        ProTrackerPercussion.evidence(for: sample(name: "", decaying: false)) == nil,
        "a sustained sound was called a hit")
    try require(
        ProTrackerPercussion.evidence(for: sample(name: "", loops: true)) == nil,
        "a looping sound was called a hit")
    try require(
        ProTrackerPercussion.evidence(for: sample(name: "", count: 9000)) == nil,
        "a long sample was called a hit")
    print("PASS held, looping and long samples are not hits")
}

/// Loads a real module that names a drum, so the tuning is built from data the
/// game actually ships rather than from something invented here.
private func moduleNamingADrum() -> (ProTrackerModule, Int)? {
    let root = URL(fileURLWithPath: "Sources/Music", isDirectory: true)
    let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
    for case let url as URL in walker ?? FileManager.DirectoryEnumerator()
    where url.pathExtension.lowercased() == "mod" {
        guard let data = try? Data(contentsOf: url),
            let module = try? ProTrackerModule(data: data) else { continue }
        for (index, sample) in module.samples.enumerated()
        where !sample.data.isEmpty
            && ProTrackerPercussion.nameSuggestsPercussion(sample.name) {
            return (module, index)
        }
    }
    return nil
}

private func testCentringKeepsExistingTuning() throws {
    guard let (module, drumIndex) = moduleNamingADrum() else {
        throw Failure(description: "no shipped module names a drum sample")
    }
    let existing = [drumIndex: ProTrackerVoiceTuning(gain: 0.5, reverbSend: 0.2)]
    let tuning = ProTrackerPercussion.centering(
        for: module, amount: 0.85, existing: existing)

    try require(tuning[drumIndex]?.centering == 0.85, "the drum was not pulled inward")
    try require(tuning[drumIndex]?.gain == 0.5, "an existing gain was discarded")
    try require(tuning[drumIndex]?.reverbSend == 0.2, "an existing send was discarded")

    // Nothing that the classifier rejected may have been given a pull.
    for (index, entry) in tuning where entry.centering > 0 {
        try require(
            ProTrackerPercussion.evidence(for: module.samples[index]) != nil,
            "sample \(index) was centred without being judged percussion")
    }
    print("PASS centring adds to existing tuning rather than replacing it")
}

private func testAskingForNoCentringChangesNothing() throws {
    guard let (module, _) = moduleNamingADrum() else {
        throw Failure(description: "no shipped module names a drum sample")
    }
    let tuning = ProTrackerPercussion.centering(for: module, amount: 0, existing: [:])
    try require(tuning.isEmpty, "centring was applied when none was asked for")
    print("PASS asking for no centring leaves every sample alone")
}

private func testModernCentresPercussionAndFaithfulDoesNot() throws {
    try require(
        ProTrackerEnhancements.modern.percussionCentering > 0,
        "the modern setting does not centre percussion")
    try require(
        ProTrackerEnhancements.faithful.percussionCentering == 0,
        "the faithful setting centres percussion, which the Amiga did not")
    print("PASS modern centres the beat and faithful leaves it where it was")
}

private func testRhythmStemKeepsTheClockAndRejectsMelody() throws {
    var bytes = [UInt8](repeating: 0, count: 1084 + 1024 + 128)
    bytes[950] = 1
    for (index, value) in "M.K.".utf8.enumerated() { bytes[1080 + index] = value }
    for (sample, name) in ["kick", "organ"].enumerated() {
        let header = 20 + sample * 30
        for (index, value) in name.utf8.enumerated() { bytes[header + index] = value }
        bytes[header + 23] = 32; bytes[header + 25] = 64; bytes[header + 29] = 32
        let period = sample == 0 ? 428 : 214
        let note = 1084 + sample * 4
        bytes[note] = UInt8(period >> 8); bytes[note + 1] = UInt8(period & 255)
        bytes[note + 2] = UInt8((sample + 1) << 4)
        for frame in 0..<64 { bytes[2108 + sample * 64 + frame] = UInt8(bitPattern: frame < 32 ? 100 : -100) }
    }
    let module = try ProTrackerModule(data: Data(bytes))
    var full = ProTrackerEnhancedPlayer(module: module), rhythm = ProTrackerEnhancedPlayer(module: module)
    var melodyEnergy: Float = 0, drumEnergy: Float = 0
    for _ in 0..<4410 {
        let mixed = full.nextFrame(), drums = rhythm.nextFrame(rhythmAmount: 1)
        try require(drums.right == 0, "Melody leaked into the native rhythm channel")
        try require(abs(mixed.left - drums.left) < 0.000001, "Rhythm isolation altered the drum samples")
        melodyEnergy += abs(mixed.right); drumEnergy += abs(drums.left)
    }
    try require(drumEnergy > 1 && melodyEnergy > 1, "Rhythm fixture did not render both instruments")
    try require(full.player.secondsUntilNextBeat == rhythm.player.secondsUntilNextBeat, "Rhythm isolation moved the tracker clock")
    print("PASS native rhythm keeps exact drum samples and clock, with no melodic voice")
}

do {
    try testDrumNamesAreRecognised()
    try testInstrumentsAreNotMistakenForDrums()
    try testShapeOnlySpeaksWhenTheNameDoesNot()
    try testHeldAndLoopedSoundsAreNotHits()
    try testCentringKeepsExistingTuning()
    try testAskingForNoCentringChangesNothing()
    try testModernCentresPercussionAndFaithfulDoesNot()
    try testRhythmStemKeepsTheClockAndRejectsMelody()
    print("Percussion tests passed.")
} catch {
    FileHandle.standardError.write(Data("Percussion tests failed: \(error)\n".utf8))
    exit(1)
}
