import Foundation
import Testing
@testable import LemmingsMobileCore

@Suite("Desk Clock simulation")
struct DeskClockSimulationTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ hour: Int, _ minute: Int, second: Double = 0) -> Date {
        let base = calendar.date(from: DateComponents(year: 2026, month: 10, day: 22, hour: hour, minute: minute))!
        return base.addingTimeInterval(second)
    }

    private func glyph(_ character: Character) -> [[Bool]] {
        DeskClockFace.glyphs[character]!.map { row in row.map { $0 == "1" } }
    }

    private func simulation(at start: Date, reduceMotion: Bool = false, reduceFlashes: Bool = false) -> DeskClockSimulation {
        DeskClockSimulation(
            now: start, uses24Hour: true, reduceMotion: reduceMotion, reduceFlashes: reduceFlashes,
            seed: 42, calendar: calendar
        )
    }

    /// Advances in 1/30 s steps from `start` up to `end` and calls `check` after each step.
    private func run(
        _ simulation: inout DeskClockSimulation, from start: Date, to end: Date, event: DeskClockEvent? = nil,
        check: (DeskClockSimulation, Date) -> Void = { _, _ in }
    ) {
        let steps = Int((end.timeIntervalSince(start) * 30 + 1e-6).rounded(.down))
        guard steps > 0 else { return }
        for index in 1...steps {
            let now = start.addingTimeInterval(Double(index) / 30)
            simulation.advance(to: now, event: event)
            check(simulation, now)
        }
    }

    private func workers(_ simulation: DeskClockSimulation) -> [DeskClockLemming] {
        simulation.lemmings.filter { $0.workerDigit != nil }
    }

    private func digitsMatch(_ simulation: DeskClockSimulation, _ text: String) -> Bool {
        Array(text).enumerated().allSatisfy { simulation.blocks[$0.offset] == glyph($0.element) }
    }

    @Test func initialDigitsAreComplete() {
        let simulation = simulation(at: date(12, 34))
        #expect(simulation.shownDigits == "1234")
        #expect(digitsMatch(simulation, "1234"))
        #expect(workers(simulation).isEmpty)
    }

    @Test func workerStartsBeforeTheMinute() {
        var simulation = simulation(at: date(12, 34, second: 30))
        var digit3WorkerAt: Date?
        var otherDigits = Set<Int>()
        run(&simulation, from: date(12, 34, second: 30), to: date(12, 35)) { simulation, now in
            for worker in workers(simulation) {
                if worker.workerDigit == 3 {
                    if digit3WorkerAt == nil { digit3WorkerAt = now }
                } else {
                    otherDigits.insert(worker.workerDigit!)
                }
            }
        }
        #expect(digit3WorkerAt != nil)
        #expect(digit3WorkerAt.map { $0 < date(12, 35) } == true)
        #expect(otherDigits.isEmpty)
    }

    @Test func lastBlockLandsOnTheMinute() {
        var simulation = simulation(at: date(12, 34, second: 30))
        run(&simulation, from: date(12, 34, second: 30), to: date(12, 34, second: 59.99))
        simulation.advance(to: date(12, 34, second: 59.99), event: nil)
        // The worker holds the last block, so the new digit is not complete before the minute.
        let differences = (0..<7).flatMap { row in (0..<5).filter { simulation.blocks[3][row][$0] != glyph("5")[row][$0] } }
        #expect(simulation.blocks[3] != glyph("5"))
        #expect(differences.count == 1)
        simulation.advance(to: date(12, 35), event: nil)
        #expect(simulation.blocks[3] == glyph("5"))
    }

    /// Four walkers: two on the ground, and two penned on top of the `2`, which stays the same at 12:40.
    private func nukeSetUp() -> (DeskClockSimulation, [Int], DeskClockEvent) {
        var simulation = simulation(at: date(12, 39, second: 50))
        simulation.setTerrain(x: 69, y: 20, width: 2, height: 21)
        simulation.setTerrain(x: 96, y: 20, width: 2, height: 21)
        let placed = [
            simulation.placeLemming(x: 20, y: 128, facingLeft: true),
            simulation.placeLemming(x: 100, y: 128, facingLeft: true),
            simulation.placeLemming(x: 75, y: 32, facingLeft: false),
            simulation.placeLemming(x: 90, y: 32, facingLeft: true)
        ]
        return (simulation, placed, DeskClockEvent(start: date(12, 40), title: "Review", nuke: true))
    }

    @Test func nukeCountsDownAndBlasts() {
        var (simulation, placed, event) = nukeSetUp()
        var workerFused = false
        let watchWorkers: (DeskClockSimulation, Date) -> Void = { simulation, _ in
            if workers(simulation).contains(where: { $0.fuse != nil }) { workerFused = true }
        }
        run(&simulation, from: date(12, 39, second: 50), to: date(12, 39, second: 54.5), event: event, check: watchWorkers)
        let walkers = simulation.lemmings.filter { $0.workerDigit == nil }
        #expect(walkers.count >= 4)
        #expect(walkers.allSatisfy { $0.fuse != nil })
        #expect(placed.allSatisfy { id in simulation.lemmings.contains { $0.id == id && $0.fuse != nil } })

        run(&simulation, from: date(12, 39, second: 54.5), to: date(12, 39, second: 59.5), event: event, check: watchWorkers)
        #expect(simulation.lemmings.filter { $0.workerDigit == nil }.allSatisfy { $0.state == .ohNo })
        let workerIDs = workers(simulation).map(\.id)
        #expect(!workerIDs.isEmpty)

        run(&simulation, from: date(12, 39, second: 59.5), to: date(12, 40, second: 0.4), event: event, check: watchWorkers)
        #expect(!simulation.lemmings.contains { $0.fuse != nil })
        #expect(!simulation.lemmings.contains { placed.contains($0.id) })
        #expect(!simulation.blasts.isEmpty)
        #expect(!digitsMatch(simulation, "1240"))
        // The blast spares the workers: every lemming that was a worker is still here.
        #expect(workerIDs.allSatisfy { id in simulation.lemmings.contains { $0.id == id } })
        #expect(!workerFused)
    }

    @Test func nukeDigitsAreRepaired() {
        var (simulation, _, event) = nukeSetUp()
        run(&simulation, from: date(12, 39, second: 50), to: date(12, 40, second: 0.4), event: event)
        #expect(!digitsMatch(simulation, "1240"))
        run(&simulation, from: date(12, 40, second: 0.4), to: date(12, 40, second: 40.4), event: event)
        #expect(simulation.shownDigits == "1240")
        #expect(digitsMatch(simulation, "1240"))
    }

    @Test func nukeIsSkippedWithReduceMotion() {
        for (reduceMotion, reduceFlashes) in [(true, false), (false, true)] {
            var simulation = simulation(at: date(12, 39, second: 50), reduceMotion: reduceMotion, reduceFlashes: reduceFlashes)
            simulation.placeLemming(x: 20, y: 128, facingLeft: true)
            let event = DeskClockEvent(start: date(12, 40), title: "Review", nuke: true)
            var fused = false
            let watch: (DeskClockSimulation, Date) -> Void = { simulation, _ in
                if simulation.lemmings.contains(where: { $0.fuse != nil }) || !simulation.blasts.isEmpty { fused = true }
            }
            run(&simulation, from: date(12, 39, second: 50), to: date(12, 39, second: 59.9), event: event, check: watch)
            let before = simulation.spawned
            run(&simulation, from: date(12, 39, second: 59.9), to: date(12, 40, second: 0.1), event: event, check: watch)
            #expect(simulation.paradeLeft == 9, "The parade starts at once, without the nuke delay")
            run(&simulation, from: date(12, 40, second: 0.1), to: date(12, 40, second: 5), event: event, check: watch)
            #expect(simulation.spawned - before >= 10)
            #expect(simulation.paradeLeft == 0)
            #expect(!fused)
        }
    }

    @Test func hourRolloverChangesFourDigits() {
        var simulation = simulation(at: date(9, 59))
        var most = 0
        run(&simulation, from: date(9, 59), to: date(10, 0)) { simulation, _ in
            most = max(most, workers(simulation).count)
        }
        #expect(most == 4)
        #expect(simulation.shownDigits == "1000")
        #expect(digitsMatch(simulation, "1000"))
    }

    @Test func digOrderTopDownBuildBottomUp() {
        var simulation = simulation(at: date(9, 59))
        var previous = simulation.blocks[0]
        var removals: [Int] = []
        var additions: [Int] = []
        run(&simulation, from: date(9, 59), to: date(10, 0)) { simulation, _ in
            for row in 0..<7 {
                for column in 0..<5 where simulation.blocks[0][row][column] != previous[row][column] {
                    if simulation.blocks[0][row][column] { additions.append(row) } else { removals.append(row) }
                }
            }
            previous = simulation.blocks[0]
        }
        #expect(!removals.isEmpty)
        #expect(!additions.isEmpty)
        #expect(removals == removals.sorted())
        #expect(additions == additions.sorted(by: >))
    }

    @Test func walkerStepsAndFalls() {
        var simulation = simulation(at: date(12, 34))
        // A 6 px step at x 30 and a 7 px step above it at x 40.
        simulation.setTerrain(x: 30, y: 122, width: 10, height: 6)
        simulation.setTerrain(x: 40, y: 115, width: 10, height: 13)
        let climber = simulation.placeLemming(x: 20, y: 128, facingLeft: false)
        var climbed = false
        var turned = false
        var furthest = 0
        run(&simulation, from: date(12, 34), to: date(12, 34, second: 2)) { simulation, _ in
            guard let lemming = simulation.lemmings.first(where: { $0.id == climber }) else { return }
            if lemming.y == 122 { climbed = true }
            if lemming.y == 122 && lemming.facingLeft { turned = true }
            furthest = max(furthest, lemming.x)
        }
        #expect(climbed)
        #expect(turned)
        #expect(furthest <= 39)

        // Off the right edge of the `2`, which stands on row 32.
        let faller = simulation.placeLemming(x: 94, y: 32, facingLeft: false)
        var fell = false
        var earlyUmbrella = false
        var umbrellaAt: Int?
        run(&simulation, from: date(12, 34, second: 2), to: date(12, 34, second: 8)) { simulation, _ in
            guard let lemming = simulation.lemmings.first(where: { $0.id == faller }) else { return }
            if lemming.state == .fall { fell = true }
            if lemming.umbrellaTick != nil {
                if lemming.y - 32 <= 26 { earlyUmbrella = true }
                if umbrellaAt == nil { umbrellaAt = lemming.y }
            }
        }
        let landed = simulation.lemmings.first { $0.id == faller }
        #expect(fell)
        #expect(!earlyUmbrella)
        #expect(umbrellaAt == 59)
        #expect(landed?.state == .walk)
        #expect(landed?.y == 128)
    }

    @Test func exitCountsSaved() {
        var simulation = simulation(at: date(12, 34))
        let walker = simulation.placeLemming(x: 184, y: 128, facingLeft: false)
        run(&simulation, from: date(12, 34), to: date(12, 34, second: 1))
        #expect(simulation.saved == 1)
        #expect(!simulation.lemmings.contains { $0.id == walker })
    }

    @Test func blockerHoldsExit() {
        var simulation = simulation(at: date(12, 34))
        let event = DeskClockEvent(start: date(12, 43), title: "Review", nuke: false)
        var reached = false
        let watch: (DeskClockSimulation, Date) -> Void = { simulation, _ in
            if simulation.lemmings.contains(where: { $0.x >= 185 && $0.workerDigit == nil }) { reached = true }
        }
        run(&simulation, from: date(12, 34), to: date(12, 34, second: 10), event: event, check: watch)
        #expect(simulation.phase == .soon)
        let blockers = simulation.lemmings.filter { $0.state == .block }
        #expect(blockers.count == 1)
        #expect(blockers.allSatisfy { abs($0.x - 175) <= 2 })
        run(&simulation, from: date(12, 34, second: 10), to: date(12, 35, second: 30), event: event, check: watch)
        #expect(!reached)
        #expect(simulation.saved == 0)
    }

    @Test func eventStartParade() {
        var simulation = simulation(at: date(12, 39, second: 50))
        let event = DeskClockEvent(start: date(12, 40), title: "Review", nuke: false)
        run(&simulation, from: date(12, 39, second: 50), to: date(12, 39, second: 59.9), event: event)
        let blocker = simulation.blockerID
        #expect(blocker.flatMap { id in simulation.lemmings.first { $0.id == id } }?.state == .block)
        let before = simulation.spawned
        simulation.advance(to: date(12, 40), event: event)
        #expect(simulation.phase == .start)
        let walked = blocker.flatMap { id in simulation.lemmings.first { $0.id == id } }
        #expect(walked?.state == .walk)
        #expect(walked?.facingLeft == false)
        run(&simulation, from: date(12, 40), to: date(12, 40, second: 5), event: event)
        #expect(simulation.spawned - before >= 10)
        #expect(simulation.paradeLeft == 0)
    }

    @Test func timeJumpRebuildsAtOnce() {
        var simulation = simulation(at: date(12, 34, second: 30))
        run(&simulation, from: date(12, 34, second: 30), to: date(12, 34, second: 58))
        #expect(!workers(simulation).isEmpty)
        let walkers = simulation.lemmings.filter { $0.workerDigit == nil }.map(\.id)
        simulation.advance(to: date(15, 10), event: nil)
        #expect(simulation.shownDigits == "1510")
        #expect(digitsMatch(simulation, "1510"))
        #expect(workers(simulation).isEmpty)
        #expect(simulation.lemmings.map(\.id) == walkers)
    }

    @Test func busyWorkerFinishesBeforeNextJob() {
        var simulation = simulation(at: date(12, 34, second: 30))
        run(&simulation, from: date(12, 34, second: 30), to: date(12, 34, second: 58))
        let busy = workers(simulation).first { $0.workerDigit == 3 }
        #expect(busy != nil)
        #expect(simulation.blocks[3] != glyph("5"))

        simulation.retarget(3, to: "6", instant: false, deadline: date(12, 36))
        #expect(simulation.blocks[3] == glyph("5"), "The old job finishes before the replacement starts")
        #expect(simulation.lemmings.contains { $0.id == busy?.id && $0.workerDigit == nil })
        #expect(workers(simulation).filter { $0.workerDigit == 3 }.count == 1)
        #expect(workers(simulation).allSatisfy { $0.id != busy?.id })

        simulation.retarget(3, to: "6", instant: true, deadline: nil)
        #expect(digitsMatch(simulation, "1236"))
        #expect(workers(simulation).isEmpty)
    }

    @Test func backwardClockChangeKeepsTheHatchRunning() {
        var simulation = simulation(at: date(12, 34))
        simulation.advance(to: date(11, 34), event: nil)
        #expect(digitsMatch(simulation, "1134"))
        run(&simulation, from: date(11, 34), to: date(11, 34, second: 2))
        #expect(simulation.spawned == 1)
        #expect(!simulation.lemmings.isEmpty)
        let before = simulation.lemmings
        run(&simulation, from: date(11, 34, second: 2), to: date(11, 34, second: 3))
        #expect(simulation.lemmings != before)
    }

    @Test func backwardClockChangeCancelsWorkersAndKeepsMinuteUpdates() {
        var simulation = simulation(at: date(12, 34, second: 30))
        run(&simulation, from: date(12, 34, second: 30), to: date(12, 34, second: 58))
        #expect(!workers(simulation).isEmpty)
        simulation.advance(to: date(11, 34, second: 58), event: nil)
        #expect(digitsMatch(simulation, "1134"))
        #expect(workers(simulation).isEmpty)
        run(&simulation, from: date(11, 34, second: 58), to: date(11, 35))
        #expect(digitsMatch(simulation, "1135"))
    }

    @Test func blockerLeavesWhenEventDisappears() {
        var simulation = simulation(at: date(12, 34))
        let event = DeskClockEvent(start: date(12, 43), title: "Review", nuke: false)
        run(&simulation, from: date(12, 34), to: date(12, 34, second: 10), event: event)
        let blocker = simulation.blockerID
        #expect(blocker.flatMap { id in simulation.lemmings.first { $0.id == id } }?.state == .block)
        simulation.advance(to: date(12, 34, second: 10.1), event: nil)
        #expect(simulation.phase == .calm)
        #expect(blocker.flatMap { id in simulation.lemmings.first { $0.id == id } }?.state == .walk)
        #expect(simulation.blockerID == nil)
    }

    @Test func reduceMotionHasNoWorkers() {
        var simulation = simulation(at: date(12, 34, second: 50), reduceMotion: true)
        var sawWorker = false
        var mostWalkers = 0
        let watch: (DeskClockSimulation, Date) -> Void = { simulation, _ in
            if !workers(simulation).isEmpty { sawWorker = true }
            mostWalkers = max(mostWalkers, simulation.lemmings.count)
        }
        run(&simulation, from: date(12, 34, second: 50), to: date(12, 34, second: 59.95), check: watch)
        #expect(simulation.blocks[3] == glyph("4"))
        simulation.advance(to: date(12, 35), event: nil)
        #expect(simulation.blocks[3] == glyph("5"))
        run(&simulation, from: date(12, 35), to: date(12, 36, second: 30), check: watch)
        #expect(!sawWorker)
        #expect(mostWalkers <= 2)
    }

    @Test func stillIsDeterministic() {
        let first = DeskClockSimulation.still(at: date(12, 34, second: 20), event: nil, uses24Hour: true, calendar: calendar)
        let second = DeskClockSimulation.still(at: date(12, 34, second: 20), event: nil, uses24Hour: true, calendar: calendar)
        let later = DeskClockSimulation.still(at: date(12, 34, second: 50), event: nil, uses24Hour: true, calendar: calendar)
        #expect(first == second)
        #expect(first.lemmings == later.lemmings)
        #expect(first.lemmings.count == 3)
        #expect(digitsMatch(first, "1234"))
        #expect(first.lemmings.allSatisfy { first.isSolid(x: $0.x, y: $0.y) && !first.isSolid(x: $0.x, y: $0.y - 1) })

        let nuke = DeskClockEvent(start: date(12, 34), title: "Review", nuke: true)
        let nuking = DeskClockSimulation.still(at: date(12, 34, second: 20), event: nuke, uses24Hour: true, calendar: calendar)
        #expect(nuking.lemmings.first?.state == .ohNo)
        let soon = DeskClockEvent(start: date(12, 40), title: "Review", nuke: false)
        let waiting = DeskClockSimulation.still(at: date(12, 34, second: 20), event: soon, uses24Hour: true, calendar: calendar)
        #expect(waiting.phase == .soon)
        #expect(waiting.lemmings.contains { $0.state == .block && $0.x == 175 })
    }
}
