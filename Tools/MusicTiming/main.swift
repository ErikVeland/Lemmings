import Foundation
import CryptoKit

// Uses the shipped decoder and renderer. Row timing mirrors its Fxx/Bxx/Dxx clock.
struct TempoSegment: Codable {
    let seconds: Double
    let order: Int
    let row: Int
    let ticksPerRow: Int
    let tickBPM: Int
    let fourRowBPM: Double
}
struct ModuleTiming: Codable {
    let sourceSHA256: String
    let rendererSHA256: String
    let durationSeconds: Double
    let loopStartSeconds: Double?
    let segments: [TempoSegment]
    let unsupportedTimingEffects: [String]
}

let root = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let catalogue = try JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("catalogue.json"))) as! [String: Any]
let tracks = catalogue["tracks"] as! [[String: Any]]
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
let project = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
var rendererData = try Data(contentsOf: project.appendingPathComponent("Sources/NxlvKit/ProTrackerModule.swift"))
rendererData.append(try Data(contentsOf: URL(fileURLWithPath: #filePath)))
func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
let rendererSHA256 = digest(rendererData)
for variant in tracks.flatMap({ $0["variants"] as! [[String: Any]] }) {
    let path = variant["path"] as! String, id = variant["id"] as! String
    guard path.lowercased().hasSuffix(".mod") else { continue }
    let data = try Data(contentsOf: root.appendingPathComponent(path))
    let module = try ProTrackerModule(data: data)
    var order = 0, row = 0, speed = 6, bpm = 125
    var time = 0.0, loop: Double?
    var visited: [String: Double] = [:], segments: [TempoSegment] = []
    var unsupported = Set<String>()
    while order < module.songLength && time < 600 {
        let notes = module.patterns[module.order[order]][row]
        var nextOrder: Int?, nextRow = 0, stopped = false
        for note in notes {
            switch note.effect {
            case 0xF:
                if note.parameter == 0 { stopped = true }
                else if note.parameter < 32 { speed = note.parameter }
                else { bpm = note.parameter }
            case 0xB: nextOrder = note.parameter; nextRow = 0
            case 0xD: nextOrder = order + 1; nextRow = (note.parameter >> 4) * 10 + (note.parameter & 15)
            case 0xE where [6, 14].contains(note.parameter >> 4):
                unsupported.insert(String(format: "E%02X", note.parameter))
            default: break
            }
        }
        if stopped { break }
        let key = "\(order):\(row):\(speed):\(bpm)"
        if let previous = visited[key] { loop = previous; break }
        visited[key] = time
        if segments.last?.ticksPerRow != speed || segments.last?.tickBPM != bpm {
            segments.append(.init(seconds: time, order: order, row: row,
                ticksPerRow: speed, tickBPM: bpm, fourRowBPM: Double(bpm) * 6 / Double(speed)))
        }
        time += Double(speed) * 2.5 / Double(bpm)
        if let nextOrder { order = nextOrder; row = min(63, nextRow) }
        else { row += 1; if row == 64 { row = 0; order += 1 } }
    }
    guard time < 600 else { fatalError("Module exceeds the 600-second analysis limit: \(path)") }
    let timing = ModuleTiming(sourceSHA256: digest(data), rendererSHA256: rendererSHA256,
        durationSeconds: time, loopStartSeconds: loop, segments: segments,
        unsupportedTimingEffects: unsupported.sorted())
    try encoder.encode(timing).write(to: output.appendingPathComponent(id + ".json"))
    let sampleRate = 22050
    var player = ProTrackerPlayer(module: module, sampleRate: Double(sampleRate))
    var samples = [Int16](repeating: 0, count: max(1, Int(ceil(time * Double(sampleRate)))))
    for index in samples.indices {
        samples[index] = Int16(max(-1, min(1, player.nextSample())) * 30000).littleEndian
    }
    var wav = Data()
    func append<T: FixedWidthInteger>(_ value: T) { withUnsafeBytes(of: value.littleEndian) { wav.append(contentsOf: $0) } }
    wav.append(contentsOf: "RIFF".utf8); append(UInt32(36 + samples.count * 2))
    wav.append(contentsOf: "WAVEfmt ".utf8); append(UInt32(16)); append(UInt16(1)); append(UInt16(1))
    append(UInt32(sampleRate)); append(UInt32(sampleRate * 2)); append(UInt16(2)); append(UInt16(16))
    wav.append(contentsOf: "data".utf8); append(UInt32(samples.count * 2))
    samples.withUnsafeBytes { wav.append(contentsOf: $0) }
    try wav.write(to: output.appendingPathComponent(id + ".wav"))
    print("\(path): \(String(format: "%.2f", time)) s, \(segments.count) tempo segments")
}
