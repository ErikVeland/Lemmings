import Foundation
import NxlvKit

private struct Failure: Error, CustomStringConvertible {
    let description: String
}

private func require(
    _ condition: @autoclosure () -> Bool, _ message: @autoclosure () -> String
) throws {
    guard condition() else { throw Failure(description: message()) }
}

private let movieDirectory = URL(fileURLWithPath: "Sources/Ports/LEM3CD/MOVIE")

/// What the files themselves say, read once with an independent tool.
private let expected: [(name: String, frames: Int, jiffies: Int)] = [
    ("SHA-WALK.FLI", 91, 5),
    ("C-LEV15.FLI", 121, 5),
    ("E-LEV10.FLI", 121, 5),
    ("THE-END.FLI", 1713, 8),
    ("INTRO.FLI", 1282, 7),
]

private func testHeadersMatchTheFiles() throws {
    for entry in expected {
        let movie = try FLICMovie(contentsOf: movieDirectory.appendingPathComponent(entry.name))
        try require(movie.width == 320, "\(entry.name) width was \(movie.width)")
        try require(movie.height == 200, "\(entry.name) height was \(movie.height)")
        try require(
            movie.frameCount == entry.frames,
            "\(entry.name) declared \(movie.frameCount) frames, expected \(entry.frames)")
        let duration = Double(entry.jiffies) / 70.0
        try require(
            abs(movie.frameDuration - duration) < 0.0001,
            "\(entry.name) frame duration was \(movie.frameDuration)")
        // Every file in the game ends with a ring frame back to the first.
        try require(
            movie.hasRingFrame,
            "\(entry.name) has no ring frame, so it cannot loop without a jump")
        try require(
            movie.frameOffsets.count == entry.frames + 1,
            "\(entry.name) indexed \(movie.frameOffsets.count) frame chunks")
    }
    print("PASS all five movies report the size, length and speed the files declare")
}

private func testEveryFrameDecodes() throws {
    for entry in expected {
        let movie = try FLICMovie(contentsOf: movieDirectory.appendingPathComponent(entry.name))
        var decoder = movie.makeDecoder()
        var count = 0
        var lastFrame: FLICFrame?
        while let frame = try decoder.nextFrame() {
            try require(
                frame.indexes.count == 320 * 200,
                "\(entry.name) frame \(count) held \(frame.indexes.count) pixels")
            try require(
                frame.palette.count == 768, "\(entry.name) frame \(count) palette was short")
            count += 1
            lastFrame = frame
        }
        try require(
            count == entry.frames + 1,
            "\(entry.name) decoded \(count) frames, expected \(entry.frames + 1)")
        try require(lastFrame != nil, "\(entry.name) produced no frames")
    }
    print("PASS every frame of all five movies decodes, including the ring frame")
}

private func testFirstFrameIsARealPicture() throws {
    let movie = try FLICMovie(contentsOf: movieDirectory.appendingPathComponent("SHA-WALK.FLI"))
    var decoder = movie.makeDecoder()
    guard let first = try decoder.nextFrame() else {
        throw Failure(description: "The first frame is missing")
    }
    // A decoder that silently does nothing returns a blank canvas that still
    // has the right size, so check the picture actually holds a range of
    // values and the palette holds a range of colors.
    let distinctPixels = Set(first.indexes).count
    try require(distinctPixels > 16, "The first frame used only \(distinctPixels) colors")
    let distinctColors = Set(stride(from: 0, to: 768, by: 3).map {
        [first.palette[$0], first.palette[$0 + 1], first.palette[$0 + 2]]
    }).count
    try require(distinctColors > 16, "The palette held only \(distinctColors) colors")
    print("PASS the first frame decodes to a picture with a full palette")
}

/// Builds the smallest valid FLIC file, so the reader has a test that does not
/// depend on game data being installed.
///
/// The picture is four by two. The palette sets three entries, and the two rows
/// are each one run of a repeated index.
private func makeTinyMovie(
    paletteBytes: [UInt8], topIndex: UInt8, bottomIndex: UInt8
) -> Data {
    func word(_ value: Int) -> [UInt8] { [UInt8(value & 0xFF), UInt8((value >> 8) & 0xFF)] }
    func long(_ value: Int) -> [UInt8] {
        [UInt8(value & 0xFF), UInt8((value >> 8) & 0xFF),
         UInt8((value >> 16) & 0xFF), UInt8((value >> 24) & 0xFF)]
    }

    // One packet, no entries skipped, three colors.
    let colorBody = word(1) + [0, 3] + paletteBytes
    let colorChunk = long(6 + colorBody.count) + word(11) + colorBody

    // Each row is one packet: a run of four pixels of one index.
    let runBody: [UInt8] = [1, 4, topIndex, 1, 4, bottomIndex]
    let runChunk = long(6 + runBody.count) + word(15) + runBody

    let frameBody = colorChunk + runChunk
    let frameChunk = long(16 + frameBody.count) + word(0xF1FA) + word(2)
        + [UInt8](repeating: 0, count: 8) + frameBody

    var header = [UInt8](repeating: 0, count: 128)
    let total = 128 + frameChunk.count
    header.replaceSubrange(0..<4, with: long(total))
    header.replaceSubrange(4..<6, with: word(0xAF11))
    header.replaceSubrange(6..<8, with: word(1))
    header.replaceSubrange(8..<10, with: word(4))
    header.replaceSubrange(10..<12, with: word(2))
    header.replaceSubrange(12..<14, with: word(8))
    header.replaceSubrange(16..<18, with: word(5))
    return Data(header + frameChunk)
}

private func testPaletteScalingAndRuns() throws {
    // Entry 0 is black, entry 1 is the brightest a six bit component reaches,
    // and entry 2 is halfway. The reader must widen 63 to 255, not to 252.
    let movie = try FLICMovie(
        data: makeTinyMovie(
            paletteBytes: [0, 0, 0, 63, 63, 63, 32, 16, 8],
            topIndex: 1, bottomIndex: 2))
    try require(movie.width == 4 && movie.height == 2, "The tiny movie is the wrong size")

    var decoder = movie.makeDecoder()
    guard let frame = try decoder.nextFrame() else {
        throw Failure(description: "The tiny movie produced no frame")
    }
    try require(
        frame.palette[0...2] == [0, 0, 0], "Black did not stay black")
    try require(
        frame.palette[3...5] == [255, 255, 255],
        "63 scaled to \(frame.palette[3]) instead of 255")
    try require(
        frame.palette[6...8] == [130, 65, 32],
        "Midtones scaled to \(Array(frame.palette[6...8])) instead of [130, 65, 32]")
    // The top row is index 1 and the bottom row is index 2, four pixels each.
    try require(
        frame.indexes == [1, 1, 1, 1, 2, 2, 2, 2],
        "Run length rows decoded to \(frame.indexes)")
    print("PASS six bit palette components widen to eight bits and runs fill their rows")
}

private func testDeltaFramesChangeThePicture() throws {
    let movie = try FLICMovie(contentsOf: movieDirectory.appendingPathComponent("SHA-WALK.FLI"))
    let frames = try movie.decodeAllFrames()
    var changed = 0
    for index in 1..<frames.count where frames[index].indexes != frames[index - 1].indexes {
        changed += 1
    }
    // A delta decoder that drops its chunks leaves every frame identical.
    try require(changed > 40, "Only \(changed) of \(frames.count) frames differed from the one before")
    print("PASS delta frames change the picture, so the movie animates")
}

private func testDecodingIsRepeatable() throws {
    let movie = try FLICMovie(contentsOf: movieDirectory.appendingPathComponent("C-LEV15.FLI"))
    let first = try movie.decodeAllFrames()
    let second = try movie.decodeAllFrames()
    try require(first == second, "Two runs over the same file produced different frames")
    print("PASS decoding the same movie twice gives the same frames")
}

private func testRGBAConversion() throws {
    let movie = try FLICMovie(contentsOf: movieDirectory.appendingPathComponent("SHA-WALK.FLI"))
    var decoder = movie.makeDecoder()
    guard let frame = try decoder.nextFrame() else {
        throw Failure(description: "The first frame is missing")
    }
    let rgba = frame.rgbaBytes()
    try require(rgba.count == 320 * 200 * 4, "RGBA output was \(rgba.count) bytes")
    let index = Int(frame.indexes[0]) * 3
    try require(rgba[0] == frame.palette[index], "Red did not follow the palette")
    try require(rgba[1] == frame.palette[index + 1], "Green did not follow the palette")
    try require(rgba[2] == frame.palette[index + 2], "Blue did not follow the palette")
    try require(rgba[3] == 255, "Alpha was not opaque")
    print("PASS palette indexes convert to opaque RGBA pixels")
}

private func testBadFilesAreReported() throws {
    do {
        _ = try FLICMovie(data: Data([0, 1, 2]))
        throw Failure(description: "A three byte file was accepted")
    } catch let error as FLICError {
        try require(error == .truncatedHeader(size: 3), "Wrong error: \(error)")
    }

    var notAMovie = Data(repeating: 0, count: 128)
    notAMovie[4] = 0x22
    notAMovie[5] = 0x33
    do {
        _ = try FLICMovie(data: notAMovie)
        throw Failure(description: "A file with the wrong marker was accepted")
    } catch let error as FLICError {
        try require(error == .notFLIC(magic: 0x3322), "Wrong error: \(error)")
    }
    print("PASS a file that is not a FLIC is reported rather than decoded")
}

/// Compares every decoded frame against a decoder written separately.
///
/// The other decoder is a short Python script written from the format
/// description rather than from this code, so the two are unlikely to share a
/// mistake. That matters most for the sign of the packet counts: `BYTE_RUN`
/// treats a positive count as a repeated run, and `DELTA_FLI` treats a positive
/// count as literal bytes. Swapping them still decodes without an error and
/// still produces frames that differ from each other. It just produces noise.
///
/// The numbers below are what the other decoder produced. A change here means
/// either a real fix, which needs new numbers, or a mistake.
private func testFramesMatchAnIndependentDecoder() throws {
    let golden: [(name: String, frames: Int, digest: UInt64)] = [
        ("SHA-WALK.FLI", 92, 8_902_023_615_160_621_900),
        ("C-LEV15.FLI", 122, 15_551_501_477_668_196_368),
        ("E-LEV10.FLI", 122, 5_042_335_752_065_689_028),
        ("THE-END.FLI", 1714, 10_498_501_605_821_679_372),
        ("INTRO.FLI", 1283, 6_223_452_314_935_730_036),
    ]

    /// FNV-1a, which both decoders use so their numbers can be compared.
    func hash<S: Sequence>(_ bytes: S) -> UInt64 where S.Element == UInt8 {
        var value: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in bytes {
            value ^= UInt64(byte)
            value = value &* 0x0000_0100_0000_01b3
        }
        return value
    }

    for entry in golden {
        let movie = try FLICMovie(contentsOf: movieDirectory.appendingPathComponent(entry.name))
        var decoder = movie.makeDecoder()
        var perFrame: [UInt8] = []
        var count = 0
        while let frame = try decoder.nextFrame() {
            let digest = hash(frame.indexes + frame.palette)
            withUnsafeBytes(of: digest.littleEndian) { perFrame.append(contentsOf: $0) }
            count += 1
        }
        try require(
            count == entry.frames,
            "\(entry.name) decoded \(count) frames, the other decoder produced \(entry.frames)")
        let combined = hash(perFrame)
        try require(
            combined == entry.digest,
            "\(entry.name) decoded differently from the other decoder "
                + "(\(combined) against \(entry.digest))")
    }
    print("PASS all 3333 frames match a decoder written separately from this one")
}

do {
    try testHeadersMatchTheFiles()
    try testFirstFrameIsARealPicture()
    try testPaletteScalingAndRuns()
    try testDeltaFramesChangeThePicture()
    try testRGBAConversion()
    try testBadFilesAreReported()
    try testDecodingIsRepeatable()
    try testEveryFrameDecodes()
    try testFramesMatchAnIndependentDecoder()
    print("FLIC tests passed.")
} catch {
    FileHandle.standardError.write(Data("FLIC tests failed: \(error)\n".utf8))
    exit(1)
}
