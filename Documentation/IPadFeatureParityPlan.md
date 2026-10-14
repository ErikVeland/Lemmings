# iPad Feature Parity Implementation Plan

> Historical implementation checklist. The current source coverage is recorded in
> [iOS interface parity](IOSInterfaceParity.md) and the
> [2.0 release gate](ReleaseReadiness/2.0ReleaseGate-2026-10-14.md).
> Earlier unchecked implementation tasks are not a current feature inventory.
> Apple TV now uses the shared frontend; its adaptations and acceptance are in
> [TV parity](../Apps/UltimateLemmingsTV/IOSParity.md).

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the iPad app the same feature set as the Mac app for the Classic engine family, NeoLemmix excepted, with shared code and no lost saves.

**Architecture:** Most Mac feature logic does not use AppKit, but it is in the `LemmingsLocal` executable target, which iOS cannot link. Phase 0 moves this logic into a new library target, `LemmingsAppCore`. The Mac imports it and keeps its file paths. Each later phase adds UIKit pages and input adapters on top of the shared logic. These pages use the shared bitmap renderer (`GameFrontEnd`, `MobileMenuCanvas`).

**Tech Stack:** Swift 6 package (`Package.swift`), UIKit (iOS 16), AppKit (macOS 12.3), GameKit, GameController, Metal, AVFoundation, XCTest.

**Spec:** This document and [IOSInterfaceParity.md](IOSInterfaceParity.md). Feature behaviour comes from the Mac docs that each phase names, for example [HotSeat.md](HotSeat.md).

## Implementation status, 12 October 2026

The Classic implementation is present across phases 1–9. The current feature
matrix and engine-specific limits are in [IOSInterfaceParity.md](IOSInterfaceParity.md).
Validation is recorded in [Classic port evidence](ReleaseReadiness/2.0IOSParity-2026-10-12/README.md).
The task checklists below retain the original implementation procedure. They do
not claim device acceptance or completion of the owner's App Store Connect
configuration. Changes remain in the workspace for review; phase commit steps
have not been performed.

## Scope

In scope: every Mac feature that is available for Classic-engine content (Lemmings, Oh No!, Holiday, Oh Yes! and fan packs).

Deferred by the owner on 12 October 2026:

- Lemmings 2 and Lemmings 3 renderers, campaigns and libraries.
- `OriginalMoviePlayer`, `Lemmings3StoryFlow` and the sequel artwork renderers.

Deferred work does not remove the cross-game rule. Each phase must keep its shared code engine-neutral. Each phase also records its L2/L3 gap in [IOSInterfaceParity.md](IOSInterfaceParity.md).

Not applicable on iPad (record these, do not port them):

| Mac feature | Reason |
| --- | --- |
| `AppUpdates` (Sparkle) | The App Store installs updates. |
| Menu bar (`buildMenu`) | iPad uses pages and `UIKeyCommand` discovery. |
| `GamePointerCapture`, "Keep pointer inside the game" | iPadOS has no pointer lock for this use. |
| Full-screen window handling | iPad apps are always full screen or in a system split. |
| `LegacySaveMigration` | Old Mac save formats never existed on iPad. |

Uncommitted work: `MobilePlaylists.swift`, `MobileLibraryCollections.swift` and their edits belong to work in progress. Do not edit or rebase over them. Phase 2 starts after this work is committed, and it migrates the data that it stores.

## Global Constraints

- Saved runs, checkpoints, favourites, playlists and settings must survive every build. Each format change needs a migration test with real stored data. See the `saves-survive-builds` rule.
- The Mac keeps its current Application Support paths and `UserDefaults` keys byte for byte.
- Game UI must match the shipped pixel artwork. Reuse `GameFrontEnd`, `MobileMenuCanvas`, `GameStoneArt`, `GameMenuTypography` and the bitmap renderers. Do not use stock UIKit controls in game pages.
- Follow [UIPrinciples.md](UIPrinciples.md): clear icons and state shapes, one primary action, no sentences that repeat a visible state.
- Touch targets are at least 44 points. Every control keeps an accessibility label.
- Handovers stay paused until the player selects Ready.
- All automated tests run headless and muted (`LEMMINGS_TEST_AUDIO=muted`). Do not launch foreground windows or simulators that take focus.
- Add each new source folder to `source_manifest()` in `Tools/IOSBeta/build.py` and to the iOS Xcode project.
- Prose in docs, comments and errors uses STE-flavored English (strict for procedures and error messages).

## Review Focus

1. **Existing iPad data on first launch after an update.** A player who has `mobile.fastSpeed`, `mobile.continuousSkillSelection`, favourites, recents and playlists in `UserDefaults` must see all of them after migration. The test is in Task 1.2 and Task 2.2.
2. **A checkpoint from build N restored in build N+1.** A Classic run saved before the rewind change (Task 3.1) must restore to the same tick and the same lemming states. The test is in Task 3.1.
3. **Hot Seat handover while the app goes to the background.** The Ready page must still block play after a return from the background or after the app relaunches from a checkpoint. The test is in Task 5.2.
4. **Two profiles with the same initials.** Records, achievements and collections must stay with the profile ID, not the display name. The test is in Task 2.1.
5. **Mac regressions from the Phase 0 move.** After the move, the Mac must read the same files at the same paths. The test is in Task 0.2.

---

## Phase 0: Shared app core

This phase is a prerequisite for every other phase. It makes no visible change.

### Task 0.1: Create the `LemmingsAppCore` target

**Files:**
- Modify: `Package.swift` (add the library product and target, add the dependency to `LemmingsLocal` and `LemmingsMobileUI`, add the `LemmingsAppCoreTests` test target)
- Create: `Sources/LemmingsAppCore/AppStorage.swift`
- Test: `Tests/LemmingsAppCoreTests/AppStorageTests.swift`
- Modify: `Tools/IOSBeta/build.py` (`source_manifest`), `Apps/UltimateLemmingsIOS/UltimateLemmingsIOS.xcodeproj/project.pbxproj`

**Interfaces:**
- Produces:

```swift
/// The storage locations for one app installation. Tests inject a temporary root.
public struct AppStorage: Sendable {
    public let applicationSupport: URL      // Mac: ~/Library/Application Support/<existing folder>
    public let resources: URL               // Bundle.main.resourceURL
    public let defaults: UserDefaults       // marked @unchecked Sendable by wrapper
    public let isPreviewBuild: Bool         // bundle ID contains "preview"
    public static func current(bundle: Bundle = .main) -> AppStorage
    public static func temporary(named: String) throws -> AppStorage
}
```

- [ ] **Step 1:** Write `AppStorageTests.testMacPathsAreUnchanged`. It builds `AppStorage.current()` on macOS and compares `applicationSupport` with the paths that `ArcadeStore.init`, `RunRecoveryStore.init` and `LevelPlaylistStore` compute today (`ArcadeStore.swift:179`, `RunRecovery.swift:242`, `LevelPlaylistStore.swift:175`).
- [ ] **Step 2:** Run `swift test --filter LemmingsAppCoreTests`. Expected: the build fails because the target does not exist.
- [ ] **Step 3:** Add the target and `AppStorage`. The target depends on `NxlvKit` only.
- [ ] **Step 4:** Run the test again. Expected: PASS.
- [ ] **Step 5:** Commit: `Add the LemmingsAppCore target for logic that the Mac and iPad share`.

### Task 0.2: Move the AppKit-free stores

Move these files without behaviour changes. Remove `#if os(macOS)`. Replace direct `FileManager` application-support lookups, `Bundle.main` and `UserDefaults.standard` with an injected `AppStorage`. Make the types and the members that the Mac uses `public`.

| From `Sources/LemmingsLocal/` | To `Sources/LemmingsAppCore/` |
| --- | --- |
| `ArcadeStore.swift`, `ArcadeRecordFile.swift` | `Profiles/` |
| `TrolleyBundledProofs.swift`, `TrolleyCapture.swift` | `Records/` |
| `RunRecovery.swift` | `Recovery/` |
| `LevelPlaylistStore.swift`, `RecordLevelNavigation.swift` | `Collections/` |
| `LevelHints.swift`, `DifficultyLibrary.swift`, `ClassicRouteRecorder.swift` | `Hints/` |
| `AnonymousTelemetry.swift` | `Privacy/` |

`SoundEffectPlayer.swift` moves to `Sources/LemmingsAudio/` instead, beside the other shared audio code.

**Interfaces:**
- Consumes: `AppStorage` (Task 0.1).
- Produces: `public final class ArcadeStore` with `init(storage: AppStorage, bundledProofs:)`, and the same member names as today. Do the same for `RunRecoveryStore`, `LevelPlaylistStore`, `LevelHintCatalogue.load(storage:)` and `DifficultyLibrary`.

- [ ] **Step 1:** Write `Tests/LemmingsAppCoreTests/StoreRoundTripTests.swift`. For each store, write a fixture file in `AppStorage.temporary`, then read, change and write it again. Assert that the file bytes match the Mac encoder output. Use the existing fixtures in `Tests/LemmingsLocalTests` where they exist.
- [ ] **Step 2:** Run the tests. Expected: FAIL (types not found).
- [ ] **Step 3:** Move the files with `git mv`, so that history follows them. Add `import LemmingsAppCore` to the Mac files that use them.
- [ ] **Step 4:** Run `swift build`, `swift test --filter LemmingsAppCoreTests` and `swift test --filter LemmingsLocalTests`. Expected: all pass.
- [ ] **Step 5:** Run `Tools/UITestRunner/run.py` with its defaults (offscreen and muted). Expected: no new failures.
- [ ] **Step 6:** Commit: `Move profiles, records, recovery, playlists and hints into LemmingsAppCore`.

---

## Phase 1: Settings

Reference: `SettingsWindow.swift` (seven tabs), `NxlvKit/ClassicSettings.swift`.

### Task 1.1: Settings model on iPad

**Files:**
- Create: `Sources/LemmingsMobileCore/MobileSettings.swift`
- Test: `Tests/LemmingsMobileCoreTests/MobileSettingsTests.swift`

**Interfaces:**
- Produces:

```swift
public struct MobileSettings: Codable, Equatable, Sendable {
    public var classic: ClassicSettings          // shared with the Mac, same JSON
    public var pauseToAssign: Bool               // iPad only, from mobile.continuousSkillSelection (inverted)
    public var fastSpeed: Int                    // 2, 3, 5 or 10, from mobile.fastSpeed
    public var musicEnabled: Bool
    public var soundtrack: String
    public static let defaultsKey = "mobile.settings.v1"
    public static func load(from: UserDefaults) -> MobileSettings   // migrates the legacy keys once
    public func save(to: UserDefaults)
}
```

- [ ] Write `testLegacyKeysMigrate`. Set the four legacy keys, load, and assert each value. Then assert that a second load does not read the legacy keys again.
- [ ] Write `testUnknownFastSpeedFallsBackToTwo`.
- [ ] Implement, run, commit.

### Task 1.2: Settings pages

**Files:**
- Create: `Sources/LemmingsMobileUI/MobileSettingsPages.swift` (an extension of `MobileLibraryViewController`, in the same style as `MobileLibraryCollections.swift`)
- Modify: `Sources/LemmingsMobileUI/MobileLibraryViewController.swift` (the `.settings` route opens the group list)
- Test: `Tools/IOSMenuAudit` page captures for each group at all six geometries

The groups follow the Mac tabs. Rows that do not apply on iPad are left out, and the parity doc records them.

| Group | Rows |
| --- | --- |
| Gameplay | Preset, Pause to assign, Fast speed, Pause on interruption, Targeting (3 toggles), Skill icon size, Reticule count, Selection effect, Skill backpacks, Level selection |
| Controller | Enable, Tap RT for fast-forward, Swap sticks, Remap buttons |
| Graphics | Machine preset, Artwork, Colour depth, Shuffle, Counters |
| Display | Screen (CRT mode), Tube strength, Whole pixels, HD effects, Cinematic explosions |
| Audio | Music, Music style, Music volume, Effects volume, Fall sounds, Soundtrack, Soundtrack libraries, DJ uses other soundtracks |
| Accessibility | UI size, Reduce motion, Reduce flashes |
| Privacy | Anonymous telemetry, Play Insights |

- [ ] Add the group list and one page for each group. A toggle row uses `selected:`. A choice row cycles on tap and shows its value.
- [ ] Add page captures to `Tools/IOSMenuAudit`, then run the audit headless.
- [ ] Commit.

The Display rows have an effect only after Phase 8. Until then, show them disabled. Do not hide them.

---

## Phase 2: Profiles, records and achievements

Reference: `ArcadeStore`, `ArcadeWindow.swift`, `AchievementsWindow.swift`, `NxlvKit/ArcadeRecords.swift`, `NxlvKit/ClassicAchievements.swift`, [ArcadeRecords.md](ArcadeRecords.md).

### Task 2.1: Profiles on iPad

**Files:**
- Create: `Sources/LemmingsMobileUI/MobileProfilePages.swift`
- Modify: `Sources/LemmingsMobileUI/MobileLibraryViewController.swift` (home badge and Profiles row)
- Test: `Tests/LemmingsAppCoreTests/ProfileIdentityTests.swift`

- [ ] Write `testSameInitialsKeepSeparateRecords`. Make two profiles with the initials "AB", record a run for each, and assert that the records and achievements stay apart.
- [ ] Add pages: profile list with portraits, New player (initials and portrait), Edit, Delete (blocked while a run is in progress, as `canDeleteProfile` does).
- [ ] Use the existing portrait artwork from `LemmingsGameArt`.
- [ ] Commit.

### Task 2.2: Per-profile collections and the playlist migration

Start this task only after the uncommitted collections work is committed.

- [ ] Write `testMobileCollectionsMigrateToActiveProfile`. Put `mobile.favourites`, `mobile.recents` and `MobilePlaylistStore` data into `UserDefaults`. Run the migration. Assert that `LevelPlaylistStore` for the default profile has every entry in the same order. Assert that the playlist run position is kept.
- [ ] Map `MobileFavourites.Entry` to `LevelPlaylistEntry`. Keep the old keys until the next major version, so that a downgrade does not lose data.
- [ ] Point the iPad collection pages at `LevelPlaylistStore`.
- [ ] Commit.

### Task 2.3: Records, achievements and result outcomes

- [ ] Record each finished run through `ArcadeStore.record(_:)`. The run uses the same `ArcadeRun` fields as `main.swift:7194` (`recordCompletion`).
- [ ] Add an Achievements page and a Records page (level records, best saved count, best time, trolley maximum).
- [ ] Extend the result page with new records and new achievements, as `ResultCelebrationView` shows them. The animated celebration comes in Phase 8.
- [ ] Add level skips (`NxlvKit/LevelSkips.swift`, [LevelSkips.md](LevelSkips.md)) to the loss result.
- [ ] Test: a run that beats a record produces one `ArcadeReport` with the new record. A second identical run produces none.
- [ ] Commit.

---

## Phase 3: Rewind, step and replays

Reference: `main.swift` "Rewind" section (8425–8620), `ReplayWindow.swift`, `ReplayMovie.swift`, `SolutionReplay.swift`, `LeaderboardActionReplay.swift`, `TimelinePanelControls.swift`, `NxlvKit/ClassicDOSRewind.swift`.

### Task 3.1: Rewind in the Classic session

**Files:**
- Modify: `Sources/LemmingsMobileCore/ClassicMobileSession.swift` (hold a `ClassicDOSRewind`, not a raw `ClassicDOSSimulation`)
- Modify: `Sources/LemmingsMobileCore/MobileGameSession.swift`
- Test: `Tests/LemmingsMobileCoreTests/MobileRewindTests.swift`

**Interfaces:**
- Produces, with default implementations that return `false` so that the L2/L3 sessions still compile:

```swift
public protocol MobileGameSession {
    // existing members …
    var supportsRewind: Bool { get }
    @discardableResult func rewind(seconds: Double) -> Bool
    @discardableResult func stepBackward() -> Bool
    @discardableResult func stepForward() -> Bool
    func replayDocument() throws -> Data?        // ClassicDOSRewind.replay(...) encoded
}
```

- [ ] Write `testOldCheckpointRestoresAfterRewindChange`. Save a checkpoint with today's code into a fixture file. Restore it with the new session. Assert the same tick, the same lemming states and the same frame hash.
- [ ] Write `testRewindThenAssignDropsTheFuture`. Assign, rewind past the assignment, assign again, and assert that the log has only the new command.
- [ ] Implement. The checkpoint payload gets a new version that stores the command log. Version 1 payloads still load, with an empty log.
- [ ] Commit.

### Task 3.2: Rewind and step controls

- [ ] Add rewind, step-back and step-forward targets to `MobileHUDLayout` and `MobileHUDView`. Reuse `TimelinePanelControls` glyphs through `PanelGlyphs`.
- [ ] Add hold-to-rewind with the same audio duck as the Mac (`setRewindAudioDucked`).
- [ ] Add the HUD states to the 40-state HUD capture set.
- [ ] Commit.

### Task 3.3: Review, solutions and replay movies

- [ ] Add Review last game to the result page. It plays the replay document in a read-only session.
- [ ] Move the AppKit-free part of `SolutionReplay.swift` (`VerifiedSolution` and its loader) into `LemmingsAppCore/Hints/`. Add Watch solution where the Mac offers it.
- [ ] Split `ReplayMovie.swift`. Keep the AVFoundation writer in `LemmingsAppCore` and give each platform its own frame drawer. On iPad, share the movie through `UIActivityViewController`.
- [ ] Test: a replay document of a won level, played back, ends in a win with the same saved count.
- [ ] Commit.

---

## Phase 4: Hints, learning journey and progression

Reference: `LevelHintWindow.swift`, `LearningJourneyMenu.swift`, `ProgressionMenu.swift`, `NxlvKit/LearningJourney.swift`, `NxlvKit/ProgressionPlaylist.swift`, [LevelHints.md](LevelHints.md).

- [ ] **Task 4.1 Hints:** A Hint action on the pause page opens the `LevelHintDeck` pages, one hint at a time. Bundle `Hints/` in the iOS app through `Tools/IOSBeta/content.py`. Test: each bundled Classic level has a hint deck or is in the known-gap list.
- [ ] **Task 4.2 Learning journey:** Add the Journey row to home. Use `LearningJourney` for the order, revisits and deferrals. Reuse the Mac journey music rule (`playLearningJourneyMusic`). Test with `LearningJourneyTests` fixtures.
- [ ] **Task 4.3 Progression playlists:** Add the policy and technique pages from `presentProgressionPolicies` and `presentProgressionTechniques`. They generate a `LevelSequenceRun` through `ProgressionPlaylist`.
- [ ] **Task 4.4 Shuffle all fan levels:** Add the confirm page and run from `prepareShuffleAllFanLevels`.

---

## Phase 5: Hot Seat

Reference: [HotSeat.md](HotSeat.md), `ArcadeStore` (roster, turn policy, saved sessions), `GameplayPresentation.swift` (`TurnBadgeView`), `main.swift` `HandoverRetry` and `presentSequenceHandover`.

### Task 5.1: Roster and saved sessions

- [ ] Add the Hot Seat page: player tiles, New player, Choose a game, house rule, Saved Hot Seats, Return to solo.
- [ ] Choose a game is enabled only with two or more players. The host stays in the roster.
- [ ] Test (in `LemmingsAppCoreTests`): roster rules from HotSeat.md. One player is not a Hot Seat. A player who leaves loses the turn. A resumed session keeps its policy.

### Task 5.2: Turn ownership, results and handovers

- [ ] Show the attempt owner on the HUD with the `TurnBadgeView` artwork.
- [ ] Use the HotSeat.md results table for the result page actions. The buttons name the player who will act.
- [ ] After a handover, show the Ready page. Play stays paused until Ready. A return from the background and a checkpoint restore show the Ready page again.
- [ ] Shared checkpoints resume only in their matching session. A mismatch keeps the run and asks the player to resume its session.
- [ ] Test `testHandoverSurvivesBackgroundAndRelaunch` with `MobileLifecycleState`: after background, foreground and checkpoint restore, the state is still awaiting Ready.
- [ ] Test: a failed records save blocks the handover.
- [ ] Commit, then record in IOSInterfaceParity.md that L2/L3 Hot Seat waits on the deferred engines.

---

## Phase 6: Game Center, arcade and hosted rankings

Reference: `GameCenterScores.swift`, `ArcadeWindow.swift`, `HostedRankings.swift`, `LeaderboardReplayWindow.swift`, [GameCenterSetup.md](GameCenterSetup.md), [HostedRankings.md](HostedRankings.md).

- [ ] **Task 6.1:** Move the GameKit logic out of `GameCenterScores.swift` into `LemmingsAppCore/Records/`. Keep authentication presentation per platform: an `NSWindow` sheet on the Mac and a presented view controller on iPad.
- [ ] **Task 6.2:** Add the Game Center capability and entitlement to the iOS target. Use the same leaderboard and achievement IDs. Add an iOS bundle to the App Store Connect app record (owner action).
- [ ] **Task 6.3:** Add the arcade, worldwide board and hosted ranking pages. Add leaderboard replays through the Phase 3 replay player.
- [ ] Test: score submission uses the same leaderboard IDs and score encoding as the Mac (pure function test, no network).

---

## Phase 7: Keyboard, controller and pointer

Reference: `GameplayKeyboard.swift`, `KeyboardCommandsView.swift`, `KeyboardOverlayView.swift`, `ControllerMenuNavigator.swift`, `ControllerDevicePresentation.swift`, `NxlvKit/ControllerBindings.swift`, [ControllerQoL.md](ControllerQoL.md).

- [ ] **Task 7.1 Command table:** Move the key-to-command table out of `GameplayKeyboard.swift` into `LemmingsAppCore/Input/GameplayCommands.swift` as data (`[KeyChord: GameplayCommand]`). The Mac keeps its `NSEvent` handling and reads the table.
- [ ] **Task 7.2 Hardware keyboard:** Map the table to `UIKeyCommand` and `pressesBegan` in `MobileGameViewController`. Add the keyboard commands overlay page. Test: each Mac command has an iPad binding or is in the documented exclusion list.
- [ ] **Task 7.3 Controller:** Use `GCController` with `ControllerBindings` during play. Add menu focus to `MobileMenuCanvas` (the selected row moves with the D-pad, A activates, B goes back). Back must not skip a Ready page.
- [ ] **Task 7.4 Pointer:** Add `UIPointerInteraction` hover to the playfield so that a trackpad shows the skill cursor and the target highlight, as the Mac cursor does.

---

## Phase 8: Audio and effects

Reference: `AdaptiveDJPlayer.swift`, `NxlvKit/AdaptiveDJEngine.swift`, `ResultChimes.swift`, `NowPlayingNotice.swift`, `FailureMood.swift`, `CRTView.swift`, `CRTShaders.swift`, `ExplosionHDR.swift`, `LemmingSelectionHDR.swift`, `LemmingAssignmentPulse.swift`, `LemmingFocusHighlight.swift`, `ClassicSkillBackpack.swift`, `ResultCelebrationView.swift`, [AudioCoverage.md](AudioCoverage.md), [ExplosionHDR.md](ExplosionHDR.md).

- [ ] **Task 8.1 Adaptive DJ:** Move the AppKit-free part of `AdaptiveDJPlayer` into `LemmingsAudio`. Connect the pause beat, variable-speed pitch, the vinyl brake on retry and the failure mood music.
- [ ] **Task 8.2 Sound effects:** Use the shared `SoundEffectPlayer` with the sound source setting. Add result chimes and the now-playing notice.
- [ ] **Task 8.3 CRT display:** Port `CRTView` to an `MTKView` that uses the shared `CRTShaders` source. Enable the Display settings rows.
- [ ] **Task 8.4 HDR and highlights:** Port explosion and selection HDR with EDR on displays that support it. Add the assignment pulse, focus highlight and skill backpacks. All effects obey Reduce motion and Reduce flashes.
- [ ] **Task 8.5 Celebrations:** Port `ResultCelebrationView` and the failure mood visuals.
- [ ] Tests: offline audio scripts cover the iOS paths, muted. Effect frames are compared headless, as the HUD captures are.

---

## Phase 9: Remaining pages

- [ ] What's New (`ReleaseWelcome`) and the effects welcome (`EffectsWelcome`).
- [ ] Play Insights (`TelemetryDashboard`) and the anonymous telemetry opt-in.
- [ ] Fan pack level-count measuring (`measureFanPacks`) and the shared updater rule set (see the browser increment open items).
- [ ] NeoLemmix single levels and packs, if the owner wants them on iPad. NeoLemmix has its own engine. Treat it as a separate decision.

---

## Verification for each phase

1. Run `swift build` and `swift test` (muted).
2. Run `Tools/UITestRunner/run.py` with its defaults for Mac regressions.
3. Run the iOS menu audit and HUD captures headless.
4. Build the unsigned iOS app with `Tools/IOSBeta/build.py`.
5. Update [IOSInterfaceParity.md](IOSInterfaceParity.md): what passed, what needs a device, and the L2/L3 gap.
6. List the checks that need the owner's device: UIKit event delivery, VoiceOver, controller, keyboard, Game Center sign-in and audible audio.
