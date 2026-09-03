import Foundation
import NxlvKit

// Builds a module by hand, then parses and renders it. No module file exists on
// this machine, so a synthetic one is the only way to prove the path works.

private struct Failure: Error, CustomStringConvertible {
    let description: String
}

private func require(
    _ condition: @autoclosure () -> Bool, _ message: @autoclosure () -> String
) throws {
    guard condition() else { throw Failure(description: message()) }
}

private let sampleFrames = 64

/// One cycle of a square wave, which makes zero crossings easy to count.
private func squareCycle() -> [UInt8] {
    (0..<sampleFrames).map { index in
        UInt8(bitPattern: Int8(index < sampleFrames / 2 ? 100 : -100))
    }
}

private struct ModuleBuilder {
    var title = "test module"
    var rows: [[(sample: Int, period: Int, effect: Int, parameter: Int)]] = []

    func build() -> Data {
        var data = Data()

        var name = Array(title.utf8.prefix(20))
        name += [UInt8](repeating: 0, count: 20 - name.count)
        data.append(contentsOf: name)

        // 31 sample headers. Only the first carries audio.
        for index in 0..<31 {
            data.append(contentsOf: [UInt8](repeating: 0, count: 22))
            if index == 0 {
                let words = sampleFrames / 2
                data.append(contentsOf: [UInt8(words >> 8), UInt8(words & 0xFF)])
                data.append(0)  // finetune
                data.append(64)  // volume
                data.append(contentsOf: [0, 0])  // repeat start
                data.append(contentsOf: [UInt8(words >> 8), UInt8(words & 0xFF)])
            } else {
                data.append(contentsOf: [UInt8](repeating: 0, count: 8))
            }
        }

        data.append(1)  // song length
        data.append(0)  // restart
        data.append(contentsOf: [UInt8](repeating: 0, count: 128))  // order, all pattern 0
        data.append(contentsOf: Array("M.K.".utf8))

        for rowIndex in 0..<ProTrackerModule.rowsPerPattern {
            for channel in 0..<4 {
                let cell = rowIndex < rows.count && channel < rows[rowIndex].count
                    ? rows[rowIndex][channel]
                    : (sample: 0, period: 0, effect: 0, parameter: 0)
                let b0 = UInt8((cell.sample & 0xF0) | ((cell.period >> 8) & 0x0F))
                let b1 = UInt8(cell.period & 0xFF)
                let b2 = UInt8(((cell.sample & 0x0F) << 4) | (cell.effect & 0x0F))
                let b3 = UInt8(cell.parameter & 0xFF)
                data.append(contentsOf: [b0, b1, b2, b3])
            }
        }

        data.append(contentsOf: squareCycle())
        return data
    }
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

private func testParsing() throws {
    var builder = ModuleBuilder()
    builder.rows = [[(sample: 1, period: 428, effect: 0, parameter: 0)]]
    let module = try ProTrackerModule(data: builder.build())

    try require(module.title == "test module", "title did not parse: '\(module.title)'")
    try require(module.channelCount == 4, "expected 4 channels, got \(module.channelCount)")
    try require(module.songLength == 1, "expected song length 1, got \(module.songLength)")
    try require(module.patterns.count == 1, "expected 1 pattern, got \(module.patterns.count)")
    try require(
        module.samples[0].data.count == sampleFrames,
        "sample PCM is \(module.samples[0].data.count) frames, expected \(sampleFrames)")
    try require(module.samples[0].volume == 64, "sample volume did not parse")
    try require(module.samples[0].loops, "sample should loop")

    let note = module.patterns[0][0][0]
    try require(note.sample == 1, "note sample was \(note.sample)")
    try require(note.period == 428, "note period was \(note.period)")
    print("PASS parse — '\(module.title)', \(module.channelCount)ch, \(module.patterns.count) pattern")
}

private func testPlaybackFrequency() throws {
    // A looping single-cycle sample means output pitch follows the period
    // directly: rate = clock / (2 * period), pitch = rate / cycle length.
    for period in [428, 214, 856] {
        var builder = ModuleBuilder()
        builder.rows = [[(sample: 1, period: period, effect: 0, parameter: 0)]]
        let module = try ProTrackerModule(data: builder.build())
        var player = ProTrackerPlayer(module: module, sampleRate: 44100)

        var samples = [Float](repeating: 0, count: 44100)
        player.render(into: &samples)

        let measured = Double(countZeroCrossings(samples))
        let rate = ProTrackerModule.palClock / (2.0 * Double(period))
        let expected = rate / Double(sampleFrames)
        let error = abs(measured - expected) / expected
        try require(
            error < 0.03,
            "period \(period): expected \(Int(expected)) Hz, measured \(Int(measured)) Hz")
        print(String(
            format: "PASS playback period %d — expected %.1f Hz, measured %.1f Hz",
            period, expected, measured))
    }
}

private func testVolumeEffect() throws {
    var loud = ModuleBuilder()
    loud.rows = [[(sample: 1, period: 428, effect: 0x0C, parameter: 64)]]
    var quiet = ModuleBuilder()
    quiet.rows = [[(sample: 1, period: 428, effect: 0x0C, parameter: 16)]]

    func peak(_ data: Data) throws -> Float {
        let module = try ProTrackerModule(data: data)
        var player = ProTrackerPlayer(module: module, sampleRate: 44100)
        var samples = [Float](repeating: 0, count: 20000)
        player.render(into: &samples)
        return samples.map { abs($0) }.max() ?? 0
    }

    let loudPeak = try peak(loud.build())
    let quietPeak = try peak(quiet.build())
    try require(loudPeak > 0.01, "full volume produced nothing: \(loudPeak)")
    try require(
        quietPeak < loudPeak / 2,
        "volume 16 was not quieter than 64: \(quietPeak) vs \(loudPeak)")
    print(String(format: "PASS volume effect — %.4f at 64, %.4f at 16", loudPeak, quietPeak))
}

private func testRejectsBadInput() throws {
    do {
        _ = try ProTrackerModule(data: Data(repeating: 0, count: 100))
        throw Failure(description: "a 100-byte file was accepted")
    } catch let error as ProTrackerError {
        guard case .tooShort = error else {
            throw Failure(description: "wrong error for a short file: \(error)")
        }
    }

    var builder = ModuleBuilder()
    builder.rows = [[(sample: 1, period: 428, effect: 0, parameter: 0)]]
    var corrupt = builder.build()
    corrupt.replaceSubrange(1080..<1084, with: Array("ZZZZ".utf8))
    do {
        _ = try ProTrackerModule(data: corrupt)
        throw Failure(description: "an unknown format tag was accepted")
    } catch let error as ProTrackerError {
        guard case .unknownFormat = error else {
            throw Failure(description: "wrong error for a bad tag: \(error)")
        }
    }
    print("PASS malformed modules are rejected")
}

do {
    try testParsing()
    try testPlaybackFrequency()
    try testVolumeEffect()
    try testRejectsBadInput()
    print("ProTracker tests passed.")
} catch {
    FileHandle.standardError.write(Data("ProTracker tests failed: \(error)\n".utf8))
    exit(1)
}
