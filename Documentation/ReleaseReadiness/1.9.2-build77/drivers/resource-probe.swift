import Foundation
import NxlvKit
let bundle = Bundle(path: "/Users/veland/Lemmings/.build/release-1.9.2/standard/Ultimate Lemmings.app")!
let root = bundle.resourceURL!
let journey = try JSONDecoder().decode(LearningJourney.self, from: Data(contentsOf: root.appendingPathComponent("Progression/learning.json"))).validated()
precondition(journey.lessons.count == 294 && journey.lessons[1].entry.levelNameSnapshot == "Cellbash")
precondition(journey.version == "learning-17" && journey.lessons[70].entry.levelNameSnapshot == "Come back!" && journey.lessons[70].stage == .intermediate)
let classic = try BundledGameResources.classicDirectories(in: bundle).map { try ClassicDataSet.detect(directory: $0) }
precondition(classic.contains { $0.title == .lemmings && $0.campaign.levels.count == 120 })
_ = try BundledGameResources.lemmings2(in: bundle)
_ = try BundledGameResources.lemmings3(in: bundle)
for family in ["lemmings", "ohno", "xmas", "holiday"] {
 _ = try ClassicMacArtwork(directory: root.appendingPathComponent("MacArtwork/"+family))
}
print("PASS packaged Classic, Lemmings 2 and Lemmings 3 data, all four RGBA artwork banks, and 294-lesson learning-17 journey with Cellbash second")
