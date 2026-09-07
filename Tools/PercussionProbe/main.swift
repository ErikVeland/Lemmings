import Foundation
import NxlvKit

// Reports which samples the percussion classifier picks out of the real
// modules, and on what grounds, so the heuristic can be judged rather than
// assumed.

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1
    ? CommandLine.arguments[1] : "Sources/Music", isDirectory: true)

var modules = 0, samples = 0, byName = 0, byShape = 0
var namedHits: [String] = []
var shapeHits: [String] = []
var missedLooking: [String] = []

let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
for case let url as URL in walker ?? FileManager.DirectoryEnumerator()
where url.pathExtension.lowercased() == "mod" {
    guard let data = try? Data(contentsOf: url),
        let module = try? ProTrackerModule(data: data) else { continue }
    modules += 1
    for sample in module.samples where !sample.data.isEmpty {
        samples += 1
        let name = sample.name.trimmingCharacters(in: .whitespaces)
        switch ProTrackerPercussion.evidence(for: sample) {
        case .name:
            byName += 1
            if namedHits.count < 14 { namedHits.append(name) }
        case .shape:
            byShape += 1
            if shapeHits.count < 14 {
                shapeHits.append("\(name.isEmpty ? "(unnamed)" : name) [\(sample.data.count)]")
            }
        case nil:
            // Anything short and unlooped that was not caught is worth seeing.
            if !sample.loops, sample.data.count <= 4000, missedLooking.count < 14 {
                missedLooking.append("\(name.isEmpty ? "(unnamed)" : name) [\(sample.data.count)]")
            }
        }
    }
}

print("modules: \(modules)   samples with data: \(samples)")
print("classified as percussion: \(byName + byShape)  (by name \(byName), by shape \(byShape))")
let percent = samples > 0 ? Double(byName + byShape) / Double(samples) * 100 : 0
print(String(format: "that is %.1f%% of all samples", percent))
print("\nmatched by name:");  for n in namedHits { print("   \(n)") }
print("\nmatched by shape:"); for n in shapeHits { print("   \(n)") }
print("\nshort, unlooped, NOT matched:"); for n in missedLooking { print("   \(n)") }
