import Foundation

/// One lemming on the Desk Clock. `y` is the ground row it stands on; that pixel is solid and the body is above it.
public struct DeskClockLemming: Equatable, Sendable {
    public enum State: Equatable, Sendable {
        case walk, fall, block, exit, dig, build, descend, ohNo
    }

    public internal(set) var x: Int
    public internal(set) var y: Int
    public internal(set) var facingLeft: Bool
    public internal(set) var state: State
    public internal(set) var tick: Int
    /// Frames since the umbrella opened, or `nil` while the lemming has no umbrella.
    public internal(set) var umbrellaTick: Int?
    public internal(set) var fuse: Date?

    var id: Int
    /// The digit this lemming rebuilds, or `nil` for every lemming that is not a worker.
    var workerDigit: Int?
    var fallDistance = 0
    var stepCarry = 0.0
    var age = 0.0
    var tickClock = 0.0
    var umbrellaClock = 0.0
    var gone = false

    init(id: Int, x: Int, y: Int, facingLeft: Bool, state: State, tick: Int = 0, workerDigit: Int? = nil) {
        self.id = id
        self.x = x
        self.y = y
        self.facingLeft = facingLeft
        self.state = state
        self.tick = tick
        self.workerDigit = workerDigit
    }
}

/// One explosion frame, shown until `until`.
public struct DeskClockBlast: Equatable, Sendable {
    public var x: Int
    public var y: Int
    public var until: Date
}

/// The idle Lemmings clock: workers rebuild terrain digits, walkers wander, a blocker holds the exit
/// before an event, and an event starts with a parade or a nuke. Every timing comes from the `now`
/// values passed in; nothing reads the wall clock.
public struct DeskClockSimulation: Equatable, Sendable {
    public static let width = 208
    public static let height = 149
    public static let groundY = 128
    public static let digitTop = 32
    public static let blockSize = 5
    public static let digitX = [41, 71, 113, 143]
    public static let colonX = 101
    public static let spawnX = 63
    public static let spawnY = 15
    public static let exitX = 185
    public static let blockerX = 175

    static let stepsPerSecond = 70.0
    /// Tolerance for comparing simulated times with deadlines and fuses.
    static let timeTolerance = 1e-6

    public private(set) var lemmings: [DeskClockLemming] = []
    /// Digit, row, column.
    public private(set) var blocks: [[[Bool]]]
    public private(set) var blasts: [DeskClockBlast] = []
    public private(set) var saved = 0
    public private(set) var phase: DeskClockPhase = .calm
    public private(set) var shownDigits = "    "
    public private(set) var hatchOpenedAt: Date

    public let uses24Hour: Bool
    let reduceMotion: Bool
    let reduceFlashes: Bool
    public let calendar: Calendar
    private var random: SplitMix64
    private var mask: [UInt8]
    private var jobs: [Job?] = [nil, nil, nil, nil]
    private var nextID = 0
    private(set) var blockerID: Int?
    private var origin: Date
    private var stepCount = 0
    private var lastAdvance: Date
    private var spawnTimer = 0.0
    private(set) var paradeLeft = 0
    private var paradeTimer = 0.0
    /// Lemmings released from the trapdoor so far.
    private(set) var spawned = 0
    private var fusedEventStart: Date?

    public init(
        now: Date, uses24Hour: Bool, reduceMotion: Bool, reduceFlashes: Bool = false,
        seed: UInt64, calendar: Calendar = .current
    ) {
        self.uses24Hour = uses24Hour
        self.reduceMotion = reduceMotion
        self.reduceFlashes = reduceFlashes
        self.calendar = calendar
        random = SplitMix64(state: seed)
        hatchOpenedAt = now
        origin = now
        lastAdvance = now
        blocks = Array(repeating: Array(repeating: Array(repeating: false, count: 5), count: 7), count: 4)
        mask = Array(repeating: 0, count: Self.width * Self.height)
        fillMask(x: 0, y: Self.groundY, width: Self.width, height: Self.height - Self.groundY, solid: true)
        fillMask(x: Self.colonX, y: Self.digitTop + 10, width: Self.blockSize, height: Self.blockSize, solid: true)
        fillMask(x: Self.colonX, y: Self.digitTop + 20, width: Self.blockSize, height: Self.blockSize, solid: true)
        let digits = Array(DeskClockFace.digits(for: now, uses24Hour: uses24Hour, calendar: calendar))
        for digit in 0..<4 {
            retarget(digit, to: digits[digit], instant: true, deadline: nil)
        }
    }

    /// One still frame for a widget entry: complete digits, three walkers placed from the minute,
    /// and the blocker while the event is near.
    public static func still(
        at date: Date, event: DeskClockEvent?, uses24Hour: Bool, calendar: Calendar = .current
    ) -> DeskClockSimulation {
        let minute = Int64((date.timeIntervalSince1970 / 60).rounded(.down))
        let minuteStart = Date(timeIntervalSince1970: Double(minute) * 60)
        var simulation = DeskClockSimulation(
            now: minuteStart, uses24Hour: uses24Hour, reduceMotion: false,
            seed: UInt64(bitPattern: minute), calendar: calendar
        )
        simulation.phase = DeskClockFace.phase(event: event, now: date)
        let nukeMinute = event.map {
            $0.nuke && Int64(($0.start.timeIntervalSince1970 / 60).rounded(.down)) == minute
        } ?? false
        for index in 0..<3 {
            let x = 8 + Int(simulation.random.next() % 192)
            let onTop = simulation.random.next() % 2 == 0
            let y = onTop ? simulation.surface(at: x) : groundY
            let facingLeft = simulation.random.next() % 2 == 0
            let tick = Int(simulation.random.next() % 8)
            let state: DeskClockLemming.State = index == 0 && nukeMinute ? .ohNo : .walk
            simulation.addLemming(x: x, y: y, facingLeft: facingLeft, state: state, tick: tick)
        }
        if simulation.phase == .soon {
            simulation.blockerID = simulation.addLemming(x: blockerX, y: groundY, facingLeft: true, state: .block)
        }
        return simulation
    }

    public func isSolid(x: Int, y: Int) -> Bool {
        x >= 0 && x < Self.width && y >= 0 && y < Self.height && mask[y * Self.width + x] == 1
    }

    public mutating func advance(to now: Date, event: DeskClockEvent?) {
        let gap = now.timeIntervalSince(lastAdvance)
        if gap < 0 || gap > 60 {
            jump(to: now, event: event)
            return
        }
        lastAdvance = now
        // Dates near today carry about 1e-7 s of rounding, so a step that ends on `now` still counts.
        let target = Int((now.timeIntervalSince(origin) * Self.stepsPerSecond + 1e-3).rounded(.down))
        while stepCount < target {
            stepCount += 1
            step(at: origin.addingTimeInterval(Double(stepCount) / Self.stepsPerSecond), dt: 1 / Self.stepsPerSecond, event: event)
        }
    }

    // MARK: - Test hooks

    /// Puts a lemming in the scene. Tests use this to start a walker at a known spot.
    @discardableResult
    mutating func placeLemming(x: Int, y: Int, facingLeft: Bool, state: DeskClockLemming.State = .walk) -> Int {
        addLemming(x: x, y: y, facingLeft: facingLeft, state: state)
    }

    /// Fills or clears terrain outside the digits. Tests use this to build steps.
    mutating func setTerrain(x: Int, y: Int, width: Int, height: Int, solid: Bool = true) {
        fillMask(x: x, y: y, width: width, height: height, solid: solid)
    }

    /// Knocks one block out of a digit. Tests use this to start a repair job.
    mutating func removeBlock(digit: Int, column: Int, row: Int) {
        setBlock(digit, column: column, row: row, on: false)
    }

    // MARK: - Steps

    private mutating func jump(to now: Date, event: DeskClockEvent?) {
        lastAdvance = now
        origin = now
        stepCount = 0
        let workerIDs = Set(jobs.compactMap { $0?.lemmingID })
        jobs = [nil, nil, nil, nil]
        lemmings.removeAll { workerIDs.contains($0.id) }
        // Old fuses would all go off at once after the gap.
        fusedEventStart = nil
        for index in lemmings.indices {
            lemmings[index].fuse = nil
            if lemmings[index].state == .ohNo { lemmings[index].state = .walk }
        }
        let digits = Array(DeskClockFace.digits(for: now, uses24Hour: uses24Hour, calendar: calendar))
        for digit in 0..<4 {
            retarget(digit, to: digits[digit], instant: true, deadline: nil)
        }
        // Every other stored time is relative or dropped above. After a backward jump the hatch must
        // already be open, and no blast may stay on screen for the whole jump.
        hatchOpenedAt = min(hatchOpenedAt, now.addingTimeInterval(-1))
        blasts.removeAll()
        updatePhase(event: event, at: now)
    }

    private var nukeAllowed: Bool { !reduceMotion && !reduceFlashes }

    private mutating func step(at time: Date, dt: Double, event: DeskClockEvent?) {
        updatePhase(event: event, at: time)
        scheduleDigits(at: time)

        if let event, event.nuke, nukeAllowed, fusedEventStart != event.start,
           time.timeIntervalSince(event.start) >= -6, time < event.start {
            lightFuses(start: event.start)
        }
        let nuking = event.map { fusedEventStart == $0.start && time.timeIntervalSince($0.start) < 1.5 } ?? false
        blasts.removeAll { $0.until <= time }

        let walkers = lemmings.filter { $0.workerDigit == nil && $0.id != blockerID }.count
        spawnTimer -= dt
        if spawnTimer <= 0 && walkers < (reduceMotion ? 2 : 6) && time.timeIntervalSince(hatchOpenedAt) > 1 && !nuking {
            spawn()
            spawnTimer = 7
        }
        if paradeLeft > 0 {
            paradeTimer -= dt
            if paradeTimer <= 0 {
                spawn()
                paradeLeft -= 1
                paradeTimer = 0.45
            }
        }

        for index in lemmings.indices where !lemmings[index].gone {
            updateLemming(index, at: time, dt: dt)
        }
        if let blockerID, lemmings.contains(where: { $0.id == blockerID && $0.gone }) {
            self.blockerID = nil
        }
        lemmings.removeAll { $0.gone }
    }

    private mutating func updatePhase(event: DeskClockEvent?, at time: Date) {
        let next = DeskClockFace.phase(event: event, now: time)
        guard next != phase else { return }
        phase = next
        if next == .soon && blockerID == nil {
            blockerID = addLemming(x: Self.blockerX, y: 0, facingLeft: true, state: .fall)
        }
        if next != .soon, let blockerID {
            if let index = lemmings.firstIndex(where: { $0.id == blockerID }), lemmings[index].state == .block {
                lemmings[index].state = .walk
                lemmings[index].facingLeft = false
                lemmings[index].age = 0
                lemmings[index].tick = 0
            }
            self.blockerID = nil
        }
        if next == .start {
            // After a nuke, the parade waits for the smoke to clear.
            paradeLeft = 10
            paradeTimer = event?.nuke == true && nukeAllowed ? 1.6 : 0
        }
    }

    private mutating func spawn() {
        addLemming(x: Self.spawnX, y: Self.spawnY, facingLeft: false, state: .fall)
        spawned += 1
    }

    @discardableResult
    private mutating func addLemming(
        x: Int, y: Int, facingLeft: Bool, state: DeskClockLemming.State, tick: Int = 0, workerDigit: Int? = nil
    ) -> Int {
        let id = nextID
        nextID += 1
        lemmings.append(DeskClockLemming(
            id: id, x: x, y: y, facingLeft: facingLeft, state: state, tick: tick, workerDigit: workerDigit
        ))
        return id
    }

    // MARK: - Lemmings

    private mutating func updateLemming(_ index: Int, at time: Date, dt: Double) {
        if let digit = lemmings[index].workerDigit {
            lemmings[index].age += dt
            updateWorker(digit, at: time, dt: dt)
            return
        }
        var lemming = lemmings[index]
        lemming.age += dt
        defer { lemmings[index] = lemming }

        if let fuse = lemming.fuse {
            let left = fuse.timeIntervalSince(time)
            if left <= Self.timeTolerance {
                lemming.gone = true
                explode(lemming, at: time)
                return
            }
            if left <= 1 && (lemming.state == .walk || lemming.state == .block) {
                lemming.state = .ohNo
                lemming.tickClock = 0
            }
        }
        switch lemming.state {
        case .ohNo:
            lemming.tickClock += dt * 16
            lemming.tick = Int(lemming.tickClock)
            return
        case .block:
            lemming.tickClock += dt * 12
            lemming.tick = Int(lemming.tickClock)
            return
        case .exit:
            lemming.tickClock += dt * 10
            lemming.tick = min(Int(lemming.tickClock), 7)
            if lemming.tickClock >= 8 {
                lemming.gone = true
                saved += 1
            }
            return
        default:
            break
        }

        if lemming.umbrellaTick != nil {
            lemming.umbrellaClock += dt * 10
            lemming.umbrellaTick = Int(lemming.umbrellaClock)
        }
        let blocker = blockerID.flatMap { id in lemmings.first { $0.id == id && $0.state == .block } }
        lemming.stepCarry += dt
        while !lemming.gone && (lemming.state == .walk || lemming.state == .fall) {
            let rate: Double = lemming.state == .fall
                ? (lemming.umbrellaTick != nil ? 20 : 60)
                : (phase == .start ? 22 : 14)
            guard lemming.stepCarry >= 1 / rate - 1e-9 else { break }
            lemming.stepCarry -= 1 / rate
            if lemming.state == .fall {
                stepFall(&lemming)
            } else {
                stepWalk(&lemming, blocker: blocker)
            }
        }
        // A walker stuck on the digits for a long time leaves, so the trapdoor keeps releasing new ones.
        if lemming.state == .walk && lemming.age > 80 && lemming.id != blockerID && lemming.y != Self.groundY {
            lemming.gone = true
        }
    }

    private func stepWalk(_ lemming: inout DeskClockLemming, blocker: DeskClockLemming?) {
        let direction = lemming.facingLeft ? -1 : 1
        let nextX = lemming.x + direction
        lemming.tick += 1
        if nextX < 4 || nextX > Self.width - 5 {
            lemming.facingLeft.toggle()
            return
        }
        if let blocker, blocker.id != lemming.id, lemming.y == blocker.y, abs(nextX - blocker.x) < 4,
           (blocker.x - lemming.x).signum() == direction {
            lemming.facingLeft.toggle()
            return
        }
        if isSolid(x: nextX, y: lemming.y) {
            // Climb at most 6 px: the first free pixel above must be within 7 rows.
            var height = 1
            while height <= 7 && isSolid(x: nextX, y: lemming.y - height) { height += 1 }
            if height > 7 {
                lemming.facingLeft.toggle()
                return
            }
            lemming.x = nextX
            lemming.y -= height - 1
        } else {
            var drop = 1
            while drop <= 3 && !isSolid(x: nextX, y: lemming.y + drop) { drop += 1 }
            lemming.x = nextX
            if drop <= 3 {
                lemming.y += drop
            } else {
                lemming.state = .fall
                lemming.fallDistance = 0
            }
        }
        if lemming.state == .walk && lemming.y == Self.groundY && lemming.x == Self.exitX
            && (blocker == nil || blocker?.id == lemming.id) {
            lemming.state = .exit
            lemming.tick = 0
            lemming.tickClock = 0
        }
    }

    private func stepFall(_ lemming: inout DeskClockLemming) {
        lemming.tick += 1
        if isSolid(x: lemming.x, y: lemming.y) {
            lemming.state = lemming.id == blockerID && phase == .soon ? .block : .walk
            lemming.umbrellaTick = nil
            lemming.tick = 0
            lemming.tickClock = 0
            return
        }
        lemming.y += 1
        lemming.fallDistance += 1
        if lemming.fallDistance > 26 && lemming.umbrellaTick == nil {
            lemming.umbrellaTick = 0
            lemming.umbrellaClock = 0
        }
        if lemming.y >= Self.height { lemming.gone = true }
    }

    private mutating func becomeWalker(_ index: Int) {
        var lemming = lemmings[index]
        lemming.workerDigit = nil
        lemming.state = isSolid(x: lemming.x, y: lemming.y) ? .walk : .fall
        lemming.fallDistance = 0
        lemming.umbrellaTick = nil
        lemming.facingLeft = random.next() % 2 == 0
        lemming.age = 0
        lemming.tick = 0
        lemming.tickClock = 0
        lemming.stepCarry = 0
        lemmings[index] = lemming
    }

    // MARK: - Nuke

    private mutating func lightFuses(start: Date) {
        fusedEventStart = start
        var order = 0
        for index in lemmings.indices
        where lemmings[index].workerDigit == nil && lemmings[index].state != .exit && !lemmings[index].gone {
            lemmings[index].fuse = start.addingTimeInterval(0.08 * Double(order))
            order += 1
        }
    }

    private mutating func explode(_ lemming: DeskClockLemming, at time: Date) {
        blasts.append(DeskClockBlast(x: lemming.x, y: lemming.y, until: time.addingTimeInterval(0.2)))
        let centerX = Double(lemming.x)
        let centerY = Double(lemming.y - 3)
        for digit in 0..<4 {
            for row in 0..<7 {
                for column in 0..<5 where blocks[digit][row][column] {
                    let blockX = Double(Self.digitX[digit] + column * Self.blockSize) + 2.5
                    let blockY = Double(Self.digitTop + row * Self.blockSize) + 2.5
                    let dx = (blockX - centerX) / 10
                    let dy = (blockY - centerY) / 13
                    if dx * dx + dy * dy <= 1 {
                        setBlock(digit, column: column, row: row, on: false)
                    }
                }
            }
        }
    }

    // MARK: - Terrain

    private mutating func fillMask(x: Int, y: Int, width: Int, height: Int, solid: Bool) {
        for row in max(0, y)..<min(Self.height, y + height) {
            for column in max(0, x)..<min(Self.width, x + width) {
                mask[row * Self.width + column] = solid ? 1 : 0
            }
        }
    }

    /// The first solid row from the top at `x`.
    private func surface(at x: Int) -> Int {
        (0..<Self.height).first { isSolid(x: x, y: $0) } ?? Self.groundY
    }

    private mutating func setBlock(_ digit: Int, column: Int, row: Int, on: Bool) {
        blocks[digit][row][column] = on
        let x = Self.digitX[digit] + column * Self.blockSize
        let y = Self.digitTop + row * Self.blockSize
        fillMask(x: x, y: y, width: Self.blockSize, height: Self.blockSize, solid: on)
        guard on else { return }
        // A new block under a walker's body lifts the walker onto it.
        for index in lemmings.indices where lemmings[index].workerDigit == nil {
            let lemming = lemmings[index]
            if lemming.x >= x && lemming.x < x + Self.blockSize && lemming.y - 1 >= y && lemming.y - 1 < y + Self.blockSize {
                lemmings[index].y = y
            }
        }
    }
}

// MARK: - Workers

extension DeskClockSimulation {
    struct Operation: Equatable, Sendable {
        var column: Int
        var row: Int
        var add: Bool
    }

    struct Job: Equatable, Sendable {
        var lemmingID: Int
        var operations: [Operation]
        var index = 0
        var x: Double
        var y: Double
        var acting = false
        var timer = 0.0
        var first = true
        /// The last block waits for this moment. A repair job has none.
        var deadline: Date?
    }

    static func glyph(_ character: Character) -> [[Bool]] {
        (DeskClockFace.glyphs[character] ?? DeskClockFace.glyphs[" "]!).map { row in row.map { $0 == "1" } }
    }

    private static func target(_ digit: Int, _ operation: Operation) -> (x: Double, y: Double) {
        (Double(digitX[digit] + operation.column * blockSize + 2), Double(digitTop + operation.row * blockSize))
    }

    /// A digger removes old blocks top-down, then a builder adds new ones bottom-up.
    func operations(_ digit: Int, to character: Character) -> [Operation] {
        let glyph = Self.glyph(character)
        var removals: [Operation] = []
        var additions: [Operation] = []
        for row in 0..<7 {
            for column in 0..<5 {
                if blocks[digit][row][column] && !glyph[row][column] {
                    removals.append(Operation(column: column, row: row, add: false))
                }
                if !blocks[digit][row][column] && glyph[row][column] {
                    additions.append(Operation(column: column, row: row, add: true))
                }
            }
        }
        additions.sort { $0.row != $1.row ? $0.row > $1.row : $0.column < $1.column }
        return removals + additions
    }

    /// Seconds a worker needs at the worker speeds, plus a 0.4 s margin.
    static func jobSeconds(_ digit: Int, _ operations: [Operation]) -> Double {
        var x = Double(digitX[digit] + 12)
        var y = -4.0
        var seconds = 0.4
        for (index, operation) in operations.enumerated() {
            let point = target(digit, operation)
            seconds += hypot(point.x - x, point.y - y) / (index == 0 ? 30 : 50) + (operation.add ? 0.55 : 0.45)
            x = point.x
            y = point.y
        }
        return seconds
    }

    /// Each digit starts its rebuild early enough that the last block lands as the minute turns.
    mutating func scheduleDigits(at time: Date) {
        let minuteStart = ((time.timeIntervalSince1970 + Self.timeTolerance) / 60).rounded(.down) * 60
        let next = Date(timeIntervalSince1970: minuteStart + 60)
        let current = Array(DeskClockFace.digits(for: Date(timeIntervalSince1970: minuteStart), uses24Hour: uses24Hour, calendar: calendar))
        let upcoming = Array(DeskClockFace.digits(for: next, uses24Hour: uses24Hour, calendar: calendar))
        for digit in 0..<4 {
            let shown = Array(shownDigits)[digit]
            var want = current[digit]
            var deadline: Date?
            if !reduceMotion && upcoming[digit] != current[digit]
                && (shown == upcoming[digit]
                    || time.timeIntervalSince(next) >= -Self.jobSeconds(digit, operations(digit, to: upcoming[digit]))) {
                want = upcoming[digit]
                deadline = next
            }
            if want != shown {
                retarget(digit, to: want, instant: false, deadline: deadline)
            } else if jobs[digit] == nil && !operations(digit, to: shown).isEmpty {
                // Repair: no deadline, the worker places each block as soon as it can.
                retarget(digit, to: shown, instant: false, deadline: nil)
            }
        }
    }

    /// One worker per changed digit. A worker still busy on this digit finishes at once first.
    mutating func retarget(_ digit: Int, to character: Character, instant: Bool, deadline: Date?) {
        finishWorker(digit)
        let operations = operations(digit, to: character)
        var shown = Array(shownDigits)
        shown[digit] = character
        shownDigits = String(shown)
        if instant || reduceMotion {
            for operation in operations {
                setBlock(digit, column: operation.column, row: operation.row, on: operation.add)
            }
            return
        }
        guard !operations.isEmpty else { return }
        let startX = Self.digitX[digit] + 12
        let id = addLemming(x: startX, y: -4, facingLeft: false, state: .descend, workerDigit: digit)
        jobs[digit] = Job(lemmingID: id, operations: operations, x: Double(startX), y: -4, deadline: deadline)
    }

    private mutating func finishWorker(_ digit: Int) {
        guard let job = jobs[digit] else { return }
        for operation in job.operations[job.index...] {
            setBlock(digit, column: operation.column, row: operation.row, on: operation.add)
        }
        jobs[digit] = nil
        if let index = lemmings.firstIndex(where: { $0.id == job.lemmingID }) {
            lemmings[index].x = Int(job.x.rounded())
            lemmings[index].y = Int(job.y.rounded())
            becomeWalker(index)
        }
    }

    /// Moves the worker through its job. Time left over from one move or block carries into the next,
    /// so the job takes the time `jobSeconds` predicts.
    private mutating func updateWorker(_ digit: Int, at time: Date, dt: Double) {
        guard var job = jobs[digit], let index = lemmings.firstIndex(where: { $0.id == job.lemmingID }) else {
            jobs[digit] = nil
            return
        }
        var budget = dt
        var finished = false
        var facingLeft = lemmings[index].facingLeft
        while budget > 1e-12 {
            let operation = job.operations[job.index]
            let point = Self.target(digit, operation)
            if !job.acting {
                let speed = job.first ? 30.0 : 50.0
                let dx = point.x - job.x
                let dy = point.y - job.y
                let distance = hypot(dx, dy)
                if abs(dx) > 0.5 { facingLeft = dx < 0 }
                if distance <= speed * budget {
                    budget -= distance / speed
                    job.x = point.x
                    job.y = point.y
                    job.acting = true
                    job.timer = operation.add ? 0.55 : 0.45
                    job.first = false
                    lemmings[index].tickClock = 0
                } else {
                    job.x += dx / distance * speed * budget
                    job.y += dy / distance * speed * budget
                    budget = 0
                }
            } else if job.timer > budget {
                job.timer -= budget
                budget = 0
            } else {
                // The last block waits for the minute.
                if job.index == job.operations.count - 1, let deadline = job.deadline,
                   time.timeIntervalSince(deadline) < -Self.timeTolerance {
                    job.timer = 0
                    break
                }
                budget -= job.timer
                setBlock(digit, column: operation.column, row: operation.row, on: operation.add)
                job.index += 1
                job.acting = false
                if job.index >= job.operations.count {
                    finished = true
                    break
                }
            }
        }
        var lemming = lemmings[index]
        lemming.x = Int(job.x.rounded())
        lemming.y = Int(job.y.rounded())
        lemming.facingLeft = facingLeft
        lemming.tickClock += dt * 14
        lemming.tick = Int(lemming.tickClock)
        if job.first {
            lemming.state = .descend
        } else {
            lemming.state = job.operations[min(job.index, job.operations.count - 1)].add ? .build : .dig
        }
        lemmings[index] = lemming
        if finished {
            jobs[digit] = nil
            becomeWalker(index)
        } else {
            jobs[digit] = job
        }
    }
}

/// SplitMix64, so a seed gives the same lemmings on every run and platform.
struct SplitMix64: Equatable, Sendable {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}
