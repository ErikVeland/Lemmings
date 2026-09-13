import Foundation
import NxlvKit

func check(_ condition: Bool, _ message: String) {
    guard condition else {
        FileHandle.standardError.write(Data("FAIL: \(message)\n".utf8)); exit(1)
    }
}

// The planted level must be proven before a search result on it means anything.
func testPlantedLevel() throws {
    var passive = try fixture(wall: true)
    while !passive.isComplete { passive.step() }
    check(passive.saved == 0, "The synthetic wall level saves \(passive.saved) lemmings without input")
    var planted = try fixture(wall: true)
    let basher = planted.configuration.skills.firstIndex(of: .basher)!
    while planted.tick < 62 { planted.step() }
    check(planted.assign(slot: basher, to: 0), "The planted basher assignment was refused")
    while !planted.isComplete { planted.step() }
    check(planted.saved == 3, "The planted basher route saved \(planted.saved) of 3")
    print("PASS synthetic wall level: 0 of 3 without input, 3 of 3 with a basher on tick 62")
}
try testPlantedLevel()
