import Foundation
import NxlvKit

// Verifies the OPL2 synthesizer against the hardware's own frequency formula
// and envelope behavior. Without these, a wrong table or shift would only show
// up as music that sounds subtly off.

private struct Failure: Error, CustomStringConvertible {
    let description: String
}

private func require(
    _ condition: @autoclosure () -> Bool, _ message: @autoclosure () -> String
) throws {
    guard condition() else { throw Failure(description: message()) }
}

/// Configures channel 0 as a plain carrier sine, with the modulator muted.
private func makeToneChip(frequencyNumber: Int, block: Int) -> OPL2 {
    var chip = OPL2()
    chip.write(register: 0x20, value: 0x01)  // modulator, multiplier 1
    chip.write(register: 0x23, value: 0x01)  // carrier, multiplier 1
    chip.write(register: 0x40, value: 0x3F)  // modulator silent
    chip.write(register: 0x43, value: 0x00)  // carrier at full level
    chip.write(register: 0x60, value: 0xF0)  // fast attack, no decay
    chip.write(register: 0x63, value: 0xF0)
    chip.write(register: 0x80, value: 0x05)  // sustain at full, medium release
    chip.write(register: 0x83, value: 0x05)
    chip.write(register: 0xC0, value: 0x00)  // FM, no feedback
    chip.write(register: 0xA0, value: UInt8(frequencyNumber & 0xFF))
    chip.write(
        register: 0xB0,
        value: UInt8(0x20 | (block << 2) | ((frequencyNumber >> 8) & 0x03)))
    return chip
}

private func countZeroCrossings(_ samples: [Float]) -> Int {
    var crossings = 0
    var previous: Float = 0
    for sample in samples {
        if previous <= 0, sample > 0 { crossings += 1 }
        previous = sample
    }
    return crossings
}

private func testFrequencyAccuracy() throws {
    // The hardware formula is f = fnum * rate / 2^(20 - block).
    let cases: [(fnum: Int, block: Int)] = [
        (512, 4), (400, 5), (700, 3), (300, 6),
    ]
    for item in cases {
        var chip = makeToneChip(frequencyNumber: item.fnum, block: item.block)
        // Let the attack settle before measuring.
        for _ in 0..<2000 { _ = chip.nextSample() }
        var samples = [Float](repeating: 0, count: 40000)
        chip.render(into: &samples)

        let seconds = Double(samples.count) / OPL2.nativeSampleRate
        let measured = Double(countZeroCrossings(samples)) / seconds
        let expected = Double(item.fnum) * OPL2.nativeSampleRate
            / pow(2.0, Double(20 - item.block))
        let error = abs(measured - expected) / expected
        try require(
            error < 0.02,
            "fnum \(item.fnum) block \(item.block): expected \(Int(expected)) Hz,"
                + " measured \(Int(measured)) Hz")
        print(
            String(
                format: "PASS frequency fnum=%d block=%d — expected %.1f Hz, measured %.1f Hz",
                item.fnum, item.block, expected, measured))
    }
}

private func testEnvelopeRisesAndFalls() throws {
    var chip = makeToneChip(frequencyNumber: 512, block: 4)
    var early = [Float](repeating: 0, count: 4000)
    chip.render(into: &early)
    let attackPeak = early.map { abs($0) }.max() ?? 0
    try require(attackPeak > 0.01, "the attack produced no output: peak \(attackPeak)")
    print(String(format: "PASS attack — peak %.4f", attackPeak))

    // Key off, then let the release run.
    chip.write(register: 0xB0, value: UInt8((4 << 2) | 0x02))
    var tail = [Float](repeating: 0, count: 200_000)
    chip.render(into: &tail)
    let finalPeak = tail.suffix(20000).map { abs($0) }.max() ?? 0
    try require(
        finalPeak < attackPeak / 4,
        "the release did not decay: peak went from \(attackPeak) to \(finalPeak)")
    print(String(format: "PASS release — decayed to %.5f", finalPeak))
}

private func testSilentUntilKeyOn() throws {
    var chip = OPL2()
    try require(chip.isSilent, "a fresh chip reports sound")
    var samples = [Float](repeating: 0, count: 4000)
    chip.render(into: &samples)
    try require(samples.allSatisfy { $0 == 0 }, "a fresh chip produced output")
    print("PASS silence before key-on")
}

private func testOutputStaysBounded() throws {
    // Drive every channel at once and confirm the mix never clips out of range.
    var chip = OPL2()
    for channel in 0..<9 {
        let slot = [0x00, 0x01, 0x02, 0x08, 0x09, 0x0A, 0x10, 0x11, 0x12][channel]
        chip.write(register: UInt8(0x20 + slot), value: 0x01)
        chip.write(register: UInt8(0x23 + slot), value: 0x01)
        chip.write(register: UInt8(0x40 + slot), value: 0x00)
        chip.write(register: UInt8(0x43 + slot), value: 0x00)
        chip.write(register: UInt8(0x60 + slot), value: 0xF0)
        chip.write(register: UInt8(0x63 + slot), value: 0xF0)
        chip.write(register: UInt8(0x80 + slot), value: 0x00)
        chip.write(register: UInt8(0x83 + slot), value: 0x00)
        chip.write(register: UInt8(0xC0 + channel), value: 0x01)
        chip.write(register: UInt8(0xA0 + channel), value: 0x80)
        chip.write(register: UInt8(0xB0 + channel), value: UInt8(0x20 | (4 << 2) | 0x01))
    }
    var samples = [Float](repeating: 0, count: 60000)
    chip.render(into: &samples)
    let peak = samples.map { abs($0) }.max() ?? 0
    try require(peak <= 1.0, "output exceeded full scale: \(peak)")
    try require(peak > 0.05, "nine channels produced almost nothing: \(peak)")
    print(String(format: "PASS nine-channel mix — peak %.4f", peak))
}

private func testPatchLoadMapsRegisters() throws {
    // The byte order inside an ADLIB.DAT patch is not established yet, so this
    // uses a patch with known-good values to prove the register mapping and
    // the channel slot table are right.
    let patch: [UInt8] = [
        0x01,  // modulator: multiplier 1
        0x01,  // carrier: multiplier 1
        0x3F,  // modulator level: silent
        0x00,  // carrier level: full
        0xF0,  // modulator attack fast
        0xF0,  // carrier attack fast
        0x05,  // modulator sustain and release
        0x05,  // carrier sustain and release
        0x00,  // modulator waveform
        0x00,  // carrier waveform
    ]
    for channel in 0..<9 {
        var chip = OPL2()
        chip.loadPatch(patch, channel: channel)
        chip.write(register: UInt8(0xC0 + channel), value: 0x00)
        chip.write(register: UInt8(0xA0 + channel), value: 0x00)
        chip.write(register: UInt8(0xB0 + channel), value: UInt8(0x20 | (4 << 2) | 0x02))
        var samples = [Float](repeating: 0, count: 20000)
        chip.render(into: &samples)
        let peak = samples.map { abs($0) }.max() ?? 0
        try require(peak > 0.01, "channel \(channel) produced no sound from a loaded patch")
    }
    print("PASS patch load — all nine channels sound")
}

private func testRealPatchesDecodeToSilentAttack() throws {
    // Every ADLIB.DAT patch read under the assumed layout gives attack rate 0,
    // which the hardware renders as silence. That is evidence the layout is
    // wrong, so this records the fact rather than asserting sound.
    let patches: [[UInt8]] = [
        [0xb9, 0xc9, 0x05, 0x06, 0x01, 0x00, 0x00, 0x02, 0x0c, 0x01],
        [0x99, 0x59, 0x09, 0x02, 0x01, 0x01, 0x01, 0x03, 0x00, 0x0a],
        [0xa9, 0x99, 0x03, 0x08, 0x01, 0x01, 0x02, 0x00, 0x18, 0x0e],
    ]
    for patch in patches {
        let modulatorAttack = Int(patch[4]) >> 4
        let carrierAttack = Int(patch[5]) >> 4
        try require(
            modulatorAttack == 0 && carrierAttack == 0,
            "a patch decoded to a nonzero attack, so the layout may now be known")
    }
    print("PASS ADLIB.DAT layout is still undecoded — every patch reads attack 0")
}

do {
    try testSilentUntilKeyOn()
    try testFrequencyAccuracy()
    try testEnvelopeRisesAndFalls()
    try testOutputStaysBounded()
    try testPatchLoadMapsRegisters()
    try testRealPatchesDecodeToSilentAttack()
    print("OPL2 tests passed.")
} catch {
    FileHandle.standardError.write(Data("OPL2 tests failed: \(error)\n".utf8))
    exit(1)
}
