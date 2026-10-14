# iOS and tvOS pause overview

The pause menu shows the current level, attempt owner and frozen playfield.
It groups rescue progress, population, time, controls and music in the shipped
bitmap lettering and stone artwork. Resume remains the primary action at the
bottom or right. The action shelf stays visible while the information scrolls.
The opening fade respects Reduce Motion, Reduce Flashes and the system setting.
Ready handovers retain their existing paused boundary.

Library, Restart level, Game controls and Resume share the action shelf.
Restart level opens a confirmation with Cancel focused. Confirmation retires
the old checkpoint and starts a fresh attempt with the current owner.
Hot Seat waits at Ready. Replays omit Restart level. Hints, settings, control
help and L2 fan mode remain available through Game controls.
The TV Game controls overview lets the remote scroll all level and music details.
Large lettering adapts in landscape to keep the action targets within the viewport.

## Rescue and run details

The overview shows saved and required counts, active lemmings, waiting lemmings,
losses, further permitted losses, time left, elapsed simulation time, speed,
release rate, population, skill assignments, rewind use and remaining skill stock.
Long level names, pack names and track titles wrap at the font's fixed size.
All text retains its full accessibility label.

`Lost = released - saved - active`.
`Can lose = max(0, saved + active + waiting - required)`.
A zero margin differs from an unreachable rescue target. Target reached,
run ending and replay states have separate labels. The audio group uses the
actual announced track and soundtrack, including an Original fallback, and
shows paused/beat-only/disabled music and sound-effect volume.

Classic supplies its live simulation count. L2 and L3 count active native actors
and successful action records. L2/L3 retain their shared adapter's one-survivor
rescue requirement and fixed release rate. Both support rewind. L3 has no shared
skill stock, so the screen omits an aggregate stock list. These counts do not
represent tribe medals or per-actor tool stock.

## Journey placement

Let's be careful out there, retail Fun 27, moves from journey lesson 32 to
lesson 94 in Intermediate. Its placement is 287.5, between The Strange Relict
of Rhodes and Take care, Sweetie. The original source and winning witness stay
unchanged. This is an editorial correction from the user's 14 October 2026
playtest. The generator records the correction and route validation enforces
its placement floor.

The journey version is `learning-22`. Migration preserves the run ID, visits,
owner and Hot Seat state. A pending attempt on this level moves later in the
queue. Completed visits retain their history.

The Crankshaft moves from the early Fun lessons, reported at lesson 34, to
lesson 126 in Difficult. Its placement is 377.5, after more worker-coordination
practice. The original source and exact winning witness stay unchanged.
Pending saved attempts move later while past visits and ownership remain intact.

## Replay identity

The replay pause overview retains the full level caption and title. Playback
also shows the level number and full name in a persistent stone panel. Long
names wrap in the shipped bitmap font. This panel accepts no input. TV uses
2x lettering. Exported replay movies include the same identity above the
playfield, preserving the complete gameplay image.

## Validation

14 October 2026:

- 26 muted background tests pass: journey validation/migration, loss margins,
  rescue states, native actor losses in all three engines, planning assignments
  and assignment counts.
- 216 windowless bitmap and target checks pass across six rescue states,
  six phone/iPad geometries, three interface sizes and both scroll endpoints.
  Checks cover complete action captions, stock names, target sizes, overlap,
  gap input and pinned Resume reachability. Representative renders were inspected.
- The arm64 iOS `LemmingsMobileUI` target compiles against the iPhoneOS SDK.
- The journey generator's reproducibility check and whitespace check pass.

The renderer checks use fixture rescue counts and track names. Native UIKit
scrolling, VoiceOver dispatch and the opening fade still need a device check.
L2/L3 session adapters were checked headlessly. Native sequel campaigns and
imports still need device checks. No test window or audible playback was used.

The focused render check is `LemmingsMobileMenuAudit ARTWORK CLASSIC_DATA OUTPUT --pause`,
run through `Tools/UITestRunner/run.py` with its default offscreen, muted settings.

Restart and replay follow-up, 14 October 2026:

- 40 focused background checks pass for journey migration, Hot Seat state,
  fresh retry preparation, rescue margins and native losses across all three engines.
- 252 muted, windowless pause render and target checks pass across phone,
  iPad and TV geometries. Four replay-title and restart-confirmation widths
  check complete captions and action targets. Representative images were inspected.
- The journey generator reproduces its outputs.
- The final shared artwork and mobile UI compile against the arm64 iOS and TV SDKs.
- Full SwiftPM test compilation encountered an unrelated stored-property
  override error in MusicTitleCardTests. The focused suites ran in an isolated
  package using the current shared sources and original test files.
- Native UIKit scrolling, VoiceOver, Siri Remote focus, physical restart journeys
  and movie playback remain manual device checks.
