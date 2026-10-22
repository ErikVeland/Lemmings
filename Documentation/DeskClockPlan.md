# Desk Clock Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the Desk Clock: an idle Lemmings clock with the next calendar event, opened from Duo poses, a Home entry and a widget.

**Architecture:** A pure simulation and trigger in `LemmingsMobileCore` hold all behavior and run headless in tests. `GameDeskClockArt` in `LemmingsGameArt` draws one simulation state with the shipped Mac frames, for both the app view and the widget. `LemmingsMobileUI` hosts the view, the Home entry, the settings group and the triggers. A new WidgetKit extension renders still frames.

**Tech Stack:** Swift 6 package, UIKit (iOS 16), WidgetKit, EventKit, CoreGraphics, Swift Testing, XCUITest, Ruby `xcodeproj` 1.27 for the new target.

**Spec:** [DeskClock.md](DeskClock.md). Prototype reference: [Tent Clock](https://claude.ai/artifact/XvvA8foJYF5WLBMR3kLArH), version 3.

## Global Constraints

- Branch: `feature/desk-clock` from `main`, in its own worktree. Ships in a 2.2.x update. Do not touch the 2.2 Duo launch candidate.
- Minimum iOS stays 16.0. Gate iOS 17 APIs with `#available`.
- Scene size 208 × 149 classic pixels. Ground row 128. Digit top 32. Block 5. Digit x 41, 71, 113, 143. Colon x 101. Spawn (63, 15). Exit trigger x 185.
- Mac art draws two pixels per classic pixel. Frames come only through `ClassicMacArtwork`.
- Walk 14 px/s (22 px/s during the event start). Fall 60 px/s. Umbrella after 26 px of fall, then 20 px/s. Step up at most 6 px, down at most 3 px.
- Spawn every 7 s while fewer than 6 walk (2 with Reduce Motion). Blocker 10 minutes before an event. Event start lasts 2 minutes and releases 10 lemmings 0.45 s apart.
- Idle trigger delay 60 s. Burn-in shift every 180 s, at most 2 pt. Night dim 22:00–07:00.
- Events: next 24 hours, skip all-day and declined events.
- Countdown: the event's minute minus the current minute. Never round seconds.
- Rebuilds: each changed digit starts early enough that its last block lands at the start of the minute, never before.
- Nuke: one event in three (stable hash). Fuses 6 s before the start, 80 ms apart, workers excepted. Countdown 5 to 1 over each head. "Oh no!" (frames 337–352) in the last second. Explosion frame 75 for 0.2 s. Blast ellipse 10 × 13 classic px around the block centers, centered 3 px above the feet. Spawns pause until 1.5 s after the start. The parade starts 1.6 s after the start. No nuke with Reduce Motion or Reduce flashes.
- Copy (exact): `NEXT`, `LET'S GO!`, `IN n MINUTE` / `IN n MINUTES`, `IN nH MMM` for an hour or more, `OUT n`, `IN n`, `Desk Clock`. Put every string through `L10n.text`.
- Tests: `LEMMINGS_TEST_AUDIO=muted`. Native UI tests only through `Tools/UITestRunner/run.py` in its default offscreen mode. No foreground windows.
- UIKit tests (`#if os(iOS)`) compile out under `swift test` on the Mac. Run them in the isolated native harness that the Duo launch uses for `MobilePoseTransitionTests` (see `ReleaseReadiness/2.4Preparation-2026-10-21/README.md`): add the new test files to its copied list, then run `xcodebuild test-without-building` with the `DuoMuted` test plan on the iPhone Duo Simulator. A pass needs a non-zero executed count for the new suites.
- Saves survive builds: new settings decode with defaults when absent.
- Prose in docs: STE-flavored (`~/.claude/skills/ste-writing`).

## Review Focus

1. **A time jump while the clock shows** (app returns from background after hours, or the clock changes): the digits match the new time at once, with no workers left mid-job. Test in Task 3.
2. **The next minute arrives while a worker is still busy:** the old job finishes at once, then the new job starts. No block is left from either digit. Test in Task 3.
3. **The event moves or disappears while the blocker stands:** the blocker walks off and the phase returns to calm. Test in Task 3.
4. **The pose changes from Stacked to book while the clock shows:** the clock closes and the idle timer returns to the system. Test in Task 8.
5. **Calendar access is revoked while the clock shows:** no crash, and the event text disappears at the next refresh. Test in Task 5.

---

### Task 1: Desk Clock settings

**Files:**
- Create: `Sources/LemmingsMobileCore/DeskClockSettings.swift`
- Modify: `Sources/LemmingsMobileCore/MobileSettings.swift` (property, init parameter, `CodingKeys`, `init(from:)`)
- Modify: `Sources/LemmingsMobileCore/MobileSettings.swift:122` (`MobileSettingsGroup` gets `case deskClock`, title `Desk Clock`)
- Test: `Tests/LemmingsMobileCoreTests/DeskClockSettingsTests.swift`

**Interfaces:**
- Produces: `public struct DeskClockSettings: Codable, Equatable, Sendable { var openWhenStacked = true; var openWhenCharging = true; var showNextEvent = true; var calendarRequested = false }` and `MobileSettings.deskClock: DeskClockSettings`.

- [ ] **Step 1: Write the failing tests**
  - `defaultsAreOn`: `DeskClockSettings()` has the three toggles `true` and `calendarRequested == false`.
  - `oldSettingsDecodeWithDefaults`: decode the JSON of a `MobileSettings` encoded without `deskClock`. Expect `deskClock == DeskClockSettings()` and every other field unchanged.
  - `roundTrip`: set `openWhenCharging = false`, encode, decode, expect equal.
- [ ] **Step 2:** Run `LEMMINGS_TEST_AUDIO=muted swift test --filter DeskClockSettingsTests`. Expected: FAIL, type not defined.
- [ ] **Step 3:** Add the struct and the field. Decode with `decodeIfPresent(...) ?? DeskClockSettings()`.
- [ ] **Step 4:** Run the same command. Expected: PASS. Also run `swift test --filter LemmingsMobileCoreTests`. Expected: no new failures.
- [ ] **Step 5:** Commit: `feat(desk-clock): add Desk Clock settings`.

### Task 2: Clock digits and event phase

**Files:**
- Create: `Sources/LemmingsMobileCore/DeskClockFace.swift`
- Test: `Tests/LemmingsMobileCoreTests/DeskClockFaceTests.swift`

**Interfaces:**
- Produces:
  - `public enum DeskClockFace { static let glyphs: [Character: [String]] }`: the 5 × 7 glyphs for `0`–`9` and blank, copied from the prototype.
  - `static func digits(for: Date, uses24Hour: Bool, calendar: Calendar) -> String`: always four characters. In 12-hour time a single-digit hour has a leading space.
  - `static func uses24Hour(locale: Locale) -> Bool`: from `DateFormatter.dateFormat(fromTemplate: "j", ...)` containing `H` or `k`.
  - `public struct DeskClockEvent: Equatable, Sendable { var start: Date; var title: String; var nuke: Bool }`
  - `static func isNuke(identifier: String, start: Date) -> Bool`: FNV-1a of `identifier` and the start minute, modulo 3, equals 0.
  - `public enum DeskClockPhase: Equatable, Sendable { case calm, soon, start }`
  - `static func phase(event: DeskClockEvent?, now: Date) -> DeskClockPhase`: `soon` when 0 < start − now ≤ 600 s. `start` when 0 ≥ start − now > −120 s. Else `calm`.
  - `static func countdown(to: Date, now: Date) -> String`: the exact copy in Global Constraints. The count is the whole minutes between the two clock minutes.
  - `static func isNight(_ date: Date, calendar: Calendar) -> Bool`: true from 22:00 to 06:59.
  - `static func burnInOffset(at date: Date) -> (x: Int, y: Int)`: in points. It changes once per 180 s slot and stays in −2...2 on both axes.

- [ ] **Step 1: Write the failing tests**
  - `twentyFourHour`: 09:05 gives `"0905"`. 23:59 gives `"2359"`.
  - `twelveHour`: 09:05 gives `" 905"`. 00:30 gives `"1230"`. 13:00 gives `" 100"`.
  - `phaseBoundaries`: start − now of 601 s gives `calm`, 600 s gives `soon`, 0 s gives `start`, −120 s gives `start`, −121 s gives `calm`, and `nil` gives `calm`.
  - `countdownCopy`: with the event at 12:40:00, now 12:33:00 gives `"IN 7 MINUTES"`, 12:33:59.9 gives `"IN 7 MINUTES"`, 12:34:00 gives `"IN 6 MINUTES"`, 12:39:00 gives `"IN 1 MINUTE"`, 12:40:00 gives `"LET'S GO!"`. Event at 13:41 and now 12:40 gives `"IN 1H 01M"`.
  - `nukeIsStableAndOneInThree`: the same identifier and start give the same answer twice. Over 3,000 generated identifiers, the share of nukes is between 0.30 and 0.37.
  - `glyphShapes`: each glyph has 7 rows of 5 characters, and blank has no `1`.
  - `nightWindow`: 21:59 gives false, 22:00 gives true, 06:59 gives true, 07:00 gives false.
  - `burnInShift`: two dates in the same 180 s slot give the same offset. Every offset over 24 hours is in −2...2, and at least two slots differ.
- [ ] **Step 2:** Run `swift test --filter DeskClockFaceTests`. Expected: FAIL.
- [ ] **Step 3:** Implement in `DeskClockFace.swift`.
- [ ] **Step 4:** Run again. Expected: PASS.
- [ ] **Step 5:** Commit: `feat(desk-clock): add clock digits and event phases`.

### Task 3: Desk Clock simulation

**Files:**
- Create: `Sources/LemmingsMobileCore/DeskClockSimulation.swift`
- Test: `Tests/LemmingsMobileCoreTests/DeskClockSimulationTests.swift`

**Interfaces:**
- Consumes: `DeskClockFace`, `DeskClockEvent`, `DeskClockPhase` (Task 2).
- Produces:
  - `public struct DeskClockLemming: Equatable, Sendable` with `x: Int`, `y: Int`, `facingLeft: Bool`, `state: State`, `tick: Int`, `umbrellaTick: Int?`, `fuse: Date?`. `State` is `walk, fall, block, exit, dig, build, descend, ohNo`.
  - `public struct DeskClockBlast: Equatable, Sendable { var x: Int; var y: Int; var until: Date }` and `private(set) var blasts: [DeskClockBlast]` for the explosion frame.
  - `public struct DeskClockSimulation: Sendable`:
    - `init(now: Date, uses24Hour: Bool, reduceMotion: Bool, seed: UInt64, calendar: Calendar = .current)`. The digits start complete, with no workers.
    - `mutating func advance(to now: Date, event: DeskClockEvent?)`
    - `private(set) var lemmings: [DeskClockLemming]`, `blocks: [[[Bool]]]` (digit, row, column), `saved: Int`, `phase: DeskClockPhase`, `shownDigits: String`, `hatchOpenedAt: Date`
    - `func isSolid(x: Int, y: Int) -> Bool`
    - `static func still(at: Date, event: DeskClockEvent?, uses24Hour: Bool) -> DeskClockSimulation`: complete digits, seed from the minute, three walkers at seeded positions on the ground or digit tops, and the blocker when the phase is `soon`.
- Behavior: follow the prototype's rules and the values in Global Constraints. Use fixed sub-steps of 1/70 s inside `advance`. Use a seeded generator (SplitMix64) so tests repeat. The `exit` state lasts 8 frames at 10 fps, then the lemming leaves and `saved` goes up by 1.
- Rebuild timing: for each digit that changes at the next minute, estimate the job with the worker speeds (descent 30 px/s, moves 50 px/s, 0.45 s per dig, 0.55 s per build, plus 0.4 s). Start the worker when the time left is less than that estimate. The worker holds its last block until the minute starts.
- Repair: when a digit's blocks differ from its glyph and no worker is busy, send a worker without a deadline.
- Large gaps: if `now` moves more than 60 s past the last `advance`, or moves backward, rebuild the digits at once. Remove workers and keep the walkers.

- [ ] **Step 1: Write the failing tests**
  - `initialDigitsAreComplete`: at 12:34 in 24-hour time, `blocks` match the glyphs for `1`, `2`, `3`, `4`.
  - `workerStartsBeforeTheMinute`: advance in 1/30 s steps from 12:34:30. Expect a worker for digit 3 before 12:35:00, and no other worker.
  - `lastBlockLandsOnTheMinute`: in the same run, `blocks[3]` still equals glyph `4` at 12:34:59.99, and equals glyph `5` at the first step at or after 12:35:00.
  - `nukeCountsDownAndBlasts`: with a nuke event at 12:40:00 and four walkers, advance from 12:39:50. At 12:39:54.5 every walker has a `fuse`. At 12:39:59.5 every walker is `ohNo`. At 12:40:00.4 no walker is left, `blasts` is not empty, and at least one digit block is gone. The worker count stays the same.
  - `nukeDigitsAreRepaired`: after the blast, advance 40 s. Every digit equals its glyph.
  - `nukeIsSkippedWithReduceMotion`: with `reduceMotion: true`, the same event gives no fuses and the normal parade.
  - `hourRolloverChangesFourDigits`: 09:59 to 10:00 in 24-hour time gives four workers. After 60 s, the digits are `1000`.
  - `digOrderTopDownBuildBottomUp`: record each block change for one digit. Removals have rising row numbers. Additions have falling row numbers.
  - `walkerStepsAndFalls`: put a walker on the ground facing a 6 px step and a 7 px step. Expect a climb and a turn. Walk off a digit edge. Expect `fall`, then an umbrella after 26 px, then `walk` on the ground.
  - `exitCountsSaved`: put a walker at x 184 facing right on the ground. After 1 s, `saved == 1`.
  - `blockerHoldsExit`: with an event 9 minutes ahead, after 10 s one lemming is `block` near x 175, and no walker reaches x 185.
  - `eventStartParade`: at the event start, 10 spawns happen within 5 s, and the blocker becomes `walk` facing right.
  - Review Focus 1, `timeJumpRebuildsAtOnce`: advance from 12:34 to 15:10 in one call. Expect digits `1510` at once and no workers.
  - Review Focus 2, `busyWorkerFinishesBeforeNextJob`: advance to 12:35:00, then 0.5 s later to 12:36:00. Expect `blocks[3]` to equal glyph `6` after 30 s, with no stray blocks.
  - Review Focus 3, `blockerLeavesWhenEventDisappears`: in `soon`, pass `event: nil`. Expect `phase == .calm`, and the blocker becomes `walk`.
  - `reduceMotionHasNoWorkers`: with `reduceMotion: true`, a minute change updates `blocks` at once, and at most 2 walkers exist.
  - `stillIsDeterministic`: two calls to `still(at:)` for the same minute are equal.
- [ ] **Step 2:** Run `swift test --filter DeskClockSimulationTests`. Expected: FAIL.
- [ ] **Step 3:** Implement `DeskClockSimulation`. The terrain mask is a `[UInt8]` of 208 × 149. The ground and colon blocks are always solid. When a block is set under a walker's body, lift the walker onto it.
- [ ] **Step 4:** Run again. Expected: PASS.
- [ ] **Step 5:** Commit: `feat(desk-clock): add the lemming clock simulation`.

### Task 4: Trigger decision

**Files:**
- Create: `Sources/LemmingsMobileCore/DeskClockTrigger.swift`
- Test: `Tests/LemmingsMobileCoreTests/DeskClockTriggerTests.swift`

**Interfaces:**
- Consumes: `MobileReservedRegion`, `MobileRect`, `MobileDisplayRegions.tablePanes` (existing), `DeskClockSettings` (Task 1).
- Produces:
  - `public enum DeskClockScreen: Sendable { case menu, level, replay, pause, handover, modal }`
  - `public struct DeskClockTriggerInput: Sendable { var foldable: Bool; var regions: [MobileReservedRegion]; var safe: MobileRect; var idle: TimeInterval; var charging: Bool; var screen: DeskClockScreen; var settings: DeskClockSettings }`
  - `public enum DeskClockTrigger: Equatable, Sendable { case none, stacked, closedCharging; static let idleDelay: TimeInterval = 60; static func evaluate(_ input: DeskClockTriggerInput) -> DeskClockTrigger }`

- [ ] **Step 1: Write the failing tests:** one test for each row of the design's trigger table, and one for each blocked screen. Required cases:
  - `stackedIdleOpens`: foldable, a full-width horizontal division, idle 60 s, screen `menu` gives `.stacked`.
  - `stackedTooSoon`: idle 59 s gives `.none`.
  - `closedChargingOpens`: foldable, no division, charging, idle 60 s gives `.closedCharging`.
  - `notFoldableNeverOpens`: not foldable, charging, idle 600 s gives `.none`.
  - `blockedScreens`: each of `level`, `replay`, `pause`, `handover`, `modal` gives `.none` for both poses.
  - `settingsOff`: `openWhenStacked = false` blocks `.stacked`. `openWhenCharging = false` blocks `.closedCharging`.
  - `bookPoseIsNotStacked`: a full-height vertical division gives `.none` when not charging.
- [ ] **Step 2:** Run `swift test --filter DeskClockTriggerTests`. Expected: FAIL.
- [ ] **Step 3:** Implement `evaluate`. Stacked means `tablePanes(in:avoiding:)` returns two panes. Closed means no `.division` region.
- [ ] **Step 4:** Run again. Expected: PASS.
- [ ] **Step 5:** Commit: `feat(desk-clock): decide when the clock opens`.

### Task 5: Next event from the calendar

**Files:**
- Create: `Sources/LemmingsMobileCore/DeskClockEvents.swift` (protocol, filter, EventKit adapter under `#if os(iOS) && canImport(EventKit)`)
- Modify: `Apps/UltimateLemmingsIOS/Info.plist` (add `NSCalendarsFullAccessUsageDescription` and `NSCalendarsUsageDescription`)
- Modify: `Apps/UltimateLemmingsIOS/PrivacyInfo.xcprivacy` (add calendar data, used for app functionality, not linked or tracked)
- Test: `Tests/LemmingsMobileCoreTests/DeskClockEventsTests.swift`

**Interfaces:**
- Produces:
  - `public struct DeskClockCandidate: Sendable { var identifier: String; var start: Date; var title: String; var allDay: Bool; var declined: Bool }`. The adapter uses `eventIdentifier`. A recurring event shares it, so the start minute is part of the hash.
  - `public enum DeskClockEvents { static func next(from: [DeskClockCandidate], now: Date) -> DeskClockEvent? }`: skip all-day, declined, and events that started more than 120 s ago or start more than 24 h ahead. Choose the earliest start. Set `nuke` with `DeskClockFace.isNuke(identifier:start:)`.
  - `public protocol DeskClockEventSource: Sendable { func authorization() -> DeskClockCalendarAccess; func requestAccess() async -> Bool; func nextEvent(now: Date) async -> DeskClockEvent? }`
  - `public enum DeskClockCalendarAccess: Sendable { case notDetermined, granted, denied }`
  - `public final class EventKitDeskClockSource: DeskClockEventSource` (iOS only). Use `requestFullAccessToEvents` on iOS 17 and later, `requestAccess(to: .event)` on iOS 16. When the store sends `.EKEventStoreChanged`, the next call reads the store again.
- Usage string (exact): `The Desk Clock shows your next event on the signpost. Lemmings cannot change your calendar.`

- [ ] **Step 1: Write the failing tests** for `next(from:now:)`: `skipsAllDay`, `skipsDeclined`, `skipsBeyond24Hours`, `keepsJustStarted` (−60 s is kept, −121 s is dropped), `choosesEarliest`, `emptyGivesNil`.
- [ ] **Step 2:** Run `swift test --filter DeskClockEventsTests`. Expected: FAIL.
- [ ] **Step 3:** Implement the filter, the protocol and the adapter. The adapter returns `nil` when access is not `granted` (Review Focus 5). Never call `requestAccess` from a trigger.
- [ ] **Step 4:** Run again. Expected: PASS. Run `plutil -lint Apps/UltimateLemmingsIOS/Info.plist Apps/UltimateLemmingsIOS/PrivacyInfo.xcprivacy`. Expected: OK.
- [ ] **Step 5:** Commit: `feat(desk-clock): read the next calendar event`.

### Task 6: Desk Clock art

**Files:**
- Create: `Sources/LemmingsGameArt/GameDeskClockArt.swift`
- Create: `Tools/DeskClock/prune_artwork.py` (copies only the frames the clock uses into a smaller manifest directory)
- Modify: `Package.swift` (add `LemmingsGameArt` to the `LemmingsMobileUITests` dependencies)
- Test: `Tests/LemmingsMobileUITests/DeskClockArtTests.swift` (not inside `#if os(iOS)`, so that it runs on the Mac)

**Interfaces:**
- Consumes: `DeskClockSimulation`, `DeskClockEvent`, `DeskClockFace` (Tasks 2–3), `ClassicMacArtwork`, `ClassicMacUserInterface` fonts.
- Produces:
  - `public final class GameDeskClockArt { public init?(directory: URL); public static let sceneSize = CGSize(width: 208, height: 149); public func draw(_ sim: DeskClockSimulation, event: DeskClockEvent?, now: Date, time: TimeInterval, in context: CGContext, rect: CGRect, nightDim: Bool) }`
  - `prune_artwork.py --source <MacArtwork/lemmings> --destination <dir>`: keeps bank 1400 frames 0–41, 75, 77–109, 127–142, 215–230, 299–306 and 337–352, bank 1500 pieces 3, 9, 10 and 36–39, bank 1600 frames 0–16, and all of Charset1 and Charset2. It writes a `manifest.json` that `ClassicMacArtwork(directory:)` loads.
- Art rules: use the element table in the design. The exit top is frames 10–15, drawn 6 classic pixels above the arch origin. Keep grass out of the exit span. Digit terrain uses piece 10 as a pattern, with a light top edge and dark bottom and right edges, as in the prototype. Draw `ohNo` lemmings with frames 337–352, each blast with frame 75 centered 16 px left and 26 px above the feet, and each fuse's number in white Charset1, 20 classic px above the feet. Scale with whole pixels when `rect` allows it, centered.

- [ ] **Step 1: Write the failing tests**
  - `loadsShippedArtwork`: `GameDeskClockArt(directory: <repo>/.build/mac-artwork/export/lemmings)` is not nil. Skip with a recorded reason when the directory is absent.
  - `loadsPrunedArtwork`: run the prune tool into a temporary directory. Expect `init` to succeed, and the directory to be less than 10% of the source size.
  - `rendersExitTop`: render `still(at:)` into an 832 × 596 bitmap. Expect non-transparent pixels 24 to 2 canvas pixels above the arch top at the exit x (the torches).
  - `rendersWithoutEvent`: rendering with `event: nil` succeeds, and the event text rows (canvas y 296–400) are empty.
- [ ] **Step 2:** Run `swift test --filter DeskClockArtTests`. Expected: FAIL.
- [ ] **Step 3:** Implement the art and the prune tool.
- [ ] **Step 4:** Run again. Expected: PASS. Write the four renders to `.build/desk-clock/renders/` and inspect them against the prototype.
- [ ] **Step 5:** Commit: `feat(desk-clock): draw the clock with Macintosh artwork`.

### Task 7: The clock in the app

**Files:**
- Create: `Sources/LemmingsMobileUI/MobileDeskClockView.swift` (display link at 30 fps, `GameDeskClockArt`, burn-in shift, night dim, accessibility)
- Create: `Sources/LemmingsMobileUI/MobileDeskClockController.swift` (show and close, music, idle timer, calendar request, layout per pose)
- Modify: `Sources/LemmingsGameArt/MobileHomeArt.swift:42-45` (footer action `deskClock` before `settings`, iOS only)
- Modify: `Sources/LemmingsGameArt/MobileSettingsArt.swift` (`case .deskClock` rows: `deskClockStacked` and `deskClockCharging`, shown only when foldable, plus `deskClockEvents`)
- Modify: `Sources/LemmingsMobileUI/MobileSettingsPages.swift:180-205` (toggle cases, and a calendar row that opens iOS Settings when access is denied)
- Modify: `Sources/LemmingsMobileUI/MobileLibraryViewController.swift:780` (`case "deskClock": presentDeskClock(reason: .menu)`)
- Modify: `Tools/IOSMenuAudit/duo.swift` (add the Desk Clock screen)
- Test: `Tests/LemmingsMobileUITests/DeskClockPresentationTests.swift`

**Interfaces:**
- Consumes: Tasks 1–6. `MobileMusic.shared.suspend()` and `resume()`. `MobileSystemRegions.read(in:)`.
- Produces: `enum DeskClockReason { case menu, widget, stacked, closedCharging }`, `MobileLibraryViewController.presentDeskClock(reason:)` and `dismissDeskClock()`.
- Behavior:
  - With `.menu` or `.widget` as the reason, `showNextEvent` on, and access `notDetermined`, request access once and set `calendarRequested`.
  - In Stacked pose, the scene fills the top pane. The bottom pane shows the event lines and a close control made with `GameStoneButton`.
  - In other poses, a touch shows the close control for 4 s.
  - Set `isIdleTimerDisabled` to true only while `batteryState` is `.charging` or `.full`. Set it back to false when the clock closes.
  - Call `MobileMusic.shared.suspend()` on show and `resume()` on close.
  - The accessibility label is the time, then `Next: <title> at <time>, <countdown>`.

- [ ] **Step 1: Write the failing tests:** `menuOpensClock`, `closeRestoresMusicAndIdleTimer`, `stackedUsesTopPane` (a fake region set gives a top-pane frame), `accessibilityLabelReadsTimeAndEvent`, and `noCalendarPromptForAutomaticReasons` (a fake source records zero `requestAccess` calls for `.stacked` and `.closedCharging`).
- [ ] **Step 2:** Run the native harness (Global Constraints) with `DeskClockPresentationTests` added. Expected: FAIL, the types are not defined.
- [ ] **Step 3:** Implement the view, the controller, the Home action, the settings group and the audit screen.
- [ ] **Step 4:** Run the native harness again. Expected: PASS, with 5 tests executed in `DeskClockPresentationTests`. Run the menu audit `--duo` for book, stacked, compact-stacked, closed-landscape and closed-portrait. Inspect one render for each, and check the close control's target.
- [ ] **Step 5:** Commit: `feat(desk-clock): show the clock from Home`.

### Task 8: Automatic triggers

**Files:**
- Modify: `Sources/LemmingsMobileUI/MobileLibraryViewController.swift` (input time stamp, a 5 s check timer, battery monitoring, the current `DeskClockScreen`)
- Modify: `Sources/LemmingsMobileUI/MobileReservedRegions.swift` (`static func isFoldable(in view: UIView) -> Bool` with `.includeInactive`)
- Modify: `Apps/UltimateLemmingsIOS/UITests/MobileCoreIOSSmokeTests.swift` (launch argument `--ui-test-desk-clock-stacked`)
- Test: `Tests/LemmingsMobileUITests/DeskClockTriggerWiringTests.swift`

**Interfaces:**
- Consumes: `DeskClockTrigger.evaluate` (Task 4), `presentDeskClock(reason:)` and `dismissDeskClock()` (Task 7).
- Behavior: every input event resets the idle time stamp. Every 5 s and on each layout change, build `DeskClockTriggerInput` and present on `.stacked` or `.closedCharging`. While an automatic clock shows, close it when `evaluate` no longer returns its trigger with the idle time ignored (pose change, charger removed).

- [ ] **Step 1: Write the failing tests:**
  - `idleStackedPresents`: inject a clock and regions, and advance the idle time 60 s. Expect a presentation with the reason `.stacked`.
  - `levelBlocksTrigger`: with screen `.level`, nothing presents.
  - Review Focus 4, `poseChangeClosesAutomaticClock`: change the regions from stacked to book while the clock shows. Expect `dismissDeskClock()` and `isIdleTimerDisabled == false`.
  - `chargerRemovedClosesChargingClock`.
- [ ] **Step 2:** Run the native harness with `DeskClockTriggerWiringTests` added. Expected: FAIL.
- [ ] **Step 3:** Implement the wiring. The launch argument starts a Stacked-pose clock for the UI test.
- [ ] **Step 4:** Run the native harness again. Expected: PASS, with 4 tests executed in `DeskClockTriggerWiringTests`. Run `python3 Tools/UITestRunner/run.py` for the Desk Clock smoke test (offscreen, muted). Expected: PASS. Record the log in `Documentation/ReleaseReadiness/` for the 2.2.x release.
- [ ] **Step 5:** Commit: `feat(desk-clock): open the clock from Duo poses`.

### Task 9: Widget

**Files:**
- Create: `Apps/UltimateLemmingsIOS/DeskClockWidget/DeskClockWidget.swift` (widget bundle, provider, view)
- Create: `Apps/UltimateLemmingsIOS/DeskClockWidget/Info.plist`
- Create: `Tools/DeskClock/add_widget_target.rb` (adds the extension target with `xcodeproj`, embeds it, links `LemmingsGameArt` and `LemmingsMobileCore`, and adds a build phase that runs `prune_artwork.py` into the extension's resources)
- Modify: `Apps/UltimateLemmingsIOS/Info.plist` (URL scheme `ultimatelemmings`)
- Modify: `Apps/UltimateLemmingsIOS/AppDelegate.swift` (handle `ultimatelemmings://desk-clock` with `presentDeskClock(reason: .widget)`)
- Test: `Tests/LemmingsMobileUITests/DeskClockWidgetTimelineTests.swift`

**Interfaces:**
- Consumes: `DeskClockSimulation.still(at:event:uses24Hour:)`, `GameDeskClockArt.draw`, `EventKitDeskClockSource.nextEvent(now:)`.
- Produces: `struct DeskClockTimeline { static func entryDates(from: Date) -> [Date] }`: 60 dates on whole minutes, the first one being the current minute. The policy is `.after(last)`.
- In the start minute of a nuke event, the still's lemming uses the `ohNo` pose.
- Families: `.systemSmall`, `.systemMedium`, `.systemLarge`, `.accessoryRectangular`. On iOS 17 and later, use `containerBackground(for: .widget)` and support StandBy. The Lock Screen family draws only the time and the next event, in Charset1, as a template image.
- Bundle ID: `<app bundle id>.DeskClockWidget`. The widget needs no app group.

- [ ] **Step 1: Write the failing tests:** `entriesAreWholeMinutes` (60 entries, seconds are 0, 60 s apart) and `firstEntryIsCurrentMinute` (12:34:40 gives 12:34:00).
- [ ] **Step 2:** Run `swift test --filter DeskClockWidgetTimelineTests`. Expected: FAIL.
- [ ] **Step 3:** Put `DeskClockTimeline` in `LemmingsMobileCore`, then write the widget and run the Ruby script. Commit the changed `project.pbxproj`.
- [ ] **Step 4:** Run the tests. Expected: PASS. Run `xcodebuild -project Apps/UltimateLemmingsIOS/UltimateLemmingsIOS.xcodeproj -scheme UltimateLemmingsIOS -destination 'generic/platform=iOS Simulator' build`. Expected: BUILD SUCCEEDED, with `DeskClockWidget.appex` in the app's `PlugIns`. The pruned artwork in the appex is under 2 MB.
- [ ] **Step 5:** Commit: `feat(desk-clock): add the Desk Clock widget`.

### Task 10: Release record

**Files:**
- Modify: `Documentation/DeskClock.md` (status, verification results, and the art-source change from an atlas to a pruned manifest)
- Modify: `Documentation/2.2Roadmap.md` (a short "after the candidate: 2.2.x Desk Clock" note with a link)
- Modify: the What's New source used by `Tools/` for the 2.2.x release, and the Localisation catalogue for the new strings

- [ ] **Step 1:** Run `LEMMINGS_TEST_AUDIO=muted swift test`. Expected: no new failures against `main`. Record any existing failures by name.
- [ ] **Step 2:** Update the documents. Lint them with `python3 ~/.claude/skills/ste-writing/ste-lint.py Documentation/DeskClock.md`.
- [ ] **Step 3:** List the open device checks in `DeskClock.md`: real fold events, calendar access in the widget extension, StandBy on a device, OLED shift on a device, and widget renders in the system gallery (a foreground check that needs a separate request from the owner).
- [ ] **Step 3a:** Add Desk Clock rows to the Duo coverage matrix for the release, one for each pose in Task 7, with their audit evidence.
- [ ] **Step 4:** Commit: `docs(desk-clock): record verification and open device checks`.
