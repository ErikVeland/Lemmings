import CryptoKit
import Foundation
import NxlvKit

private enum DiagnosticError: Error, CustomStringConvertible {
    case failed(String)

    var description: String {
        switch self {
        case let .failed(message): return message
        }
    }
}

private func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    guard condition() else { throw DiagnosticError.failed(message) }
}

private func sha256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func joined(_ values: [Data]) -> Data {
    var result = Data()
    result.reserveCapacity(values.reduce(0) { $0 + $1.count })
    for value in values { result.append(value) }
    return result
}

private func bitCount(_ values: [Data]) -> Int {
    values.reduce(0) { total, data in
        total + data.reduce(0) { $0 + Int($1) }
    }
}

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: MainDATDiagnostics <DOS-data-directory>\n".utf8))
    Foundation.exit(64)
}

do {
    let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
    let files = try FileManager.default.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles]
    )
    guard let mainURL = files.first(where: { $0.lastPathComponent.lowercased() == "main.dat" }) else {
        throw DiagnosticError.failed("MAIN.DAT is missing.")
    }

    let archiveData = try Data(contentsOf: mainURL, options: .mappedIfSafe)
    try require(
        sha256(archiveData) == "2aec688c334e60322998811a8b6f9d5c13f8090b46ca6c2a6cb1c8db3b733545",
        "The local MAIN.DAT does not match the audited DOS Lemmings fixture."
    )

    let sections = try ClassicDATArchive.decode(archiveData)
    let expectedSectionSizes = [21_104, 388, 8_384, 61_968, 36_080, 758, 8_224]
    let expectedSectionHashes = [
        "959341d6dd9e51cfa9877f510909b417c1b4266e3a051742cddc7cf85cd7ad44",
        "91071cc7578e3ce8f5f6e692537c230dadde7f564ce7e8d8a14f2f789ee4ab27",
        "7e1b6a0a63f88c37bb9bb6b40d2d4889862ece61aceffc2b6c19961436b9cadd",
        "05fa1758775e601d38b00c6120cc597ffae6c598b04caac921bb59d76a80c805",
        "6880c756be51fd97314e8f2c615baef9218134c58e66eff25a6e3dbab6f0a5f7",
        "bdc1da6ea085bd247ab3060dfc78f522f7b447dcffe7235a3e19bf9938731287",
        "0fea37bb7811ab6968bf26fcb22a6b2f5cafd60690386435a69aa35bf05bc6b9",
    ]
    try require(sections.map(\.decompressedSize) == expectedSectionSizes, "Unexpected MAIN.DAT section sizes.")
    try require(sections.map { sha256($0.data) } == expectedSectionHashes, "Unexpected MAIN.DAT section hash.")

    let assets = try ClassicMainDATAssets(archiveData: archiveData)
    try require(assets.animations.count == 30, "Expected 30 directional animation sequences.")
    try require(assets.totalSpriteFrameCount == 337, "Expected 337 sprite frames.")
    try require(assets.unsupportedSectionIndices == [2, 3, 4, 5, 6], "Unexpected unsupported section list.")

    let indexedFrames = joined(assets.animations.flatMap { $0.frames.map(\.indexedPixels) })
    try require(indexedFrames.count == 63_488, "Unexpected indexed sprite byte count.")
    try require(
        sha256(indexedFrames) == "857a88b9f03347bc247b2869cc996756245ad699b20c86c1100bf9f1e98f6cc9",
        "Decoded sprite pixels do not match the independent decoder."
    )

    let walkRight = try requireAnimation(assets, pose: .walking, direction: .right)
    try require(
        sha256(joined(walkRight.frames.map(\.indexedPixels))) == "3b727b5f6a5e033a26145509fdc7706e37eec03703ffe90c642979caa343cb13",
        "Right-walker pixels do not match the independent decoder."
    )
    let frying = try requireAnimation(assets, pose: .frying, direction: .none)
    var highestFryingIndex: Int?
    for frame in frying.frames {
        for pixel in frame.indexedPixels where pixel & 0x80 == 0 {
            highestFryingIndex = max(highestFryingIndex ?? 0, Int(pixel & 0x0F))
        }
    }
    try require(highestFryingIndex == 13, "The frying animation must retain style-dependent palette indices.")

    let masks = assets.destructionMasks
    let expandedMasks = joined(
        masks.bashRight.map(\.bits)
            + masks.bashLeft.map(\.bits)
            + masks.mineRight.map(\.bits)
            + masks.mineLeft.map(\.bits)
            + [masks.explosion.bits]
            + assets.countdownGlyphs.map(\.bitmap.bits)
    )
    try require(expandedMasks.count == 3_104, "Unexpected expanded mask byte count.")
    try require(
        sha256(expandedMasks) == "dbd47acd7e4fcb04d2856b72ce91ac0552474b5aad9275831dbd19dd6abe399b",
        "Decoded masks do not match the independent decoder."
    )
    try require(bitCount(masks.bashRight.map(\.bits)) == 129, "Unexpected right-bash mask bits.")
    try require(bitCount(masks.bashLeft.map(\.bits)) == 129, "Unexpected left-bash mask bits.")
    try require(bitCount(masks.mineRight.map(\.bits)) == 124, "Unexpected right-mine mask bits.")
    try require(bitCount(masks.mineLeft.map(\.bits)) == 124, "Unexpected left-mine mask bits.")
    try require(bitCount([masks.explosion.bits]) == 279, "Unexpected explosion mask bits.")
    try require(assets.countdownGlyphs.map(\.digit) == Array((0...9).reversed()), "Countdown glyph order changed.")

    let groundSet = try ClassicGroundSet.load(style: 0, from: directory)
    let palette = try ClassicLemmingPalette.inLevelVGA(terrainPalette: groundSet.terrainPalette)
    try require(palette.count == 16, "The in-level sprite palette must contain 16 colors.")
    try require(palette[4] == ClassicRGBColor(red: 243, green: 243, blue: 0), "The fixed VGA yellow is incorrect.")
    let fryingRGBA = try joined(frying.frames.map { try $0.rgba(using: palette) })
    try require(fryingRGBA.count == 14 * 16 * 14 * 4, "Unexpected frying RGBA byte count.")
    try require(
        sha256(fryingRGBA) == "166ab1fa83f854b327daed3b706d621c0f13bc24e1ffbe39022f862246aa3ebb",
        "Frying RGBA pixels do not match the independent decoder."
    )
    var rgbaFrames: [Data] = []
    for animation in assets.animations {
        for frame in animation.frames {
            rgbaFrames.append(try frame.rgba(using: palette))
        }
    }
    let allRGBA = joined(rgbaFrames)
    try require(allRGBA.count == 253_952, "Unexpected RGBA sprite byte count.")
    try require(
        sha256(allRGBA) == "9dd04c4759fcad6325153790109eed5a59467e445b6acbd24c2441c4f56f4f28",
        "RGBA sprite pixels do not match the independent decoder."
    )

    do {
        _ = try ClassicMainDATAssets(decompressedSections: [Data(count: 21_103), Data(count: 388)])
        throw DiagnosticError.failed("A truncated sprite section was accepted.")
    } catch let error as ClassicMainDATError {
        guard case .outOfBounds(section: 0, _, _, _, _) = error else { throw error }
    }
    do {
        _ = try ClassicMainDATAssets(decompressedSections: [Data(count: 21_104), Data(count: 387)])
        throw DiagnosticError.failed("A truncated mask section was accepted.")
    } catch let error as ClassicMainDATError {
        guard case .outOfBounds(section: 1, _, _, _, _) = error else { throw error }
    }

    print("MAIN.DAT verified: 7 sections, 30 animation sequences, 337 sprite frames, 13 destruction-mask frames, and 10 countdown glyphs.")
} catch {
    FileHandle.standardError.write(Data("MAIN.DAT diagnostic failed: \(error)\n".utf8))
    Foundation.exit(1)
}

private func requireAnimation(
    _ assets: ClassicMainDATAssets,
    pose: ClassicLemmingPose,
    direction: ClassicSpriteDirection
) throws -> ClassicLemmingAnimation {
    guard let animation = assets.animation(for: pose, direction: direction) else {
        throw DiagnosticError.failed("Missing \(pose.rawValue) \(direction.rawValue) animation.")
    }
    return animation
}
