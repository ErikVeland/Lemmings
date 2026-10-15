# macOS 2.0 preparation

Status: journey checkpoint resume implemented. Bundled closure remains open.
Updated 15 October 2026. This record covers Mac preparation, separately from
the iOS 2.0 launch gates.

## Macintosh 2.0 release request

The owner requested Macintosh 2.0 and announcement posts on 15 October.
The proposed [build-83 release notes](../../ReleaseNotes-2.0-build83.md) lead
with the original 1-bit graphics and cover changes since 1.9.6. The BBCode and
new-player Reddit drafts are saved outside the repository in
`~/Documents/Ultimate Lemmings/Posts`.

The [announcement preflight](announcement-preflight.json) records the current
source and the package-scope rejection. Sequel fidelity, save recovery, input
and accessibility, performance and hardware, release packaging, and bundled
engine/content closure remain open or partial. That preflight preceded the
owner's scope decision. The owner then approved using the existing
classifications and documenting limits. See the
[build-83 acceptance record](../2.0-build83/acceptance.json) and
[candidate evidence](../2.0-build83/README.md). The posts contain release-day
wording and must wait until the final release and download link are verified.

## Journey and playlist recovery

Mac sequences now save their attempts instead of suppressing checkpoint writes.
A checkpoint identifies the queue, level, source revision, player and Hot Seat.
Catalogue captions and entry labels can change without stranding the same level.
A changed source revision, different queue or different player cannot borrow it.
Standalone checkpoints remain separate.

Home and the journey hub offer Resume when a matching checkpoint exists.
Older queues without one retain Continue and start at their saved level.
Restoration retains the attempt ID, simulation tick, state, selected action and
camera. Play remains paused, and Hot Seat retains its explicit Ready handover.
Native sequel playlists retain their campaign-progress isolation and callbacks.

The [journey-flow rerun](journey-flow-runtime.log) passes all 227 lesson
preflights, unopened-pack continuation, saved-session migration, confirmed
Solo/Hot Seat resumption and the six checkpoint paths. It explicitly checks
camera position and each engine's paused state. The
[native validation record](native-validation.json) and
[UI input hashes](native-ui-inputs.json) identify the frozen run. Concurrent Home
backdrop edits are outside this snapshot and require the final integrated audit.

[Native checks](journey-resume-runtime.log) pass all six Solo/Hot Seat paths
across Classic, Lemmings 2 and Lemmings 3 with real bundled game data. The
required runner uses offscreen windows and muted audio. Seventeen captures
cover Home, journey Resume, native restored scenes and Ready states; these stay
in `.build/journey-resume-renders` with the commercial artwork. The Resume and
Ready bounds were checked, and captures were inspected.

[Storage checks](checkpoint-storage.log) pass exact queue/content matching,
caption changes, player/Hot Seat separation, legacy saves, backup recovery,
writer conflicts and ten abrupt process terminations. Initial native attempts
stopped at sandboxed macOS registration, missing test-window setup, an old
installed journey catalogue and a generic test pool ID. Corrected runs use the
retained current content baseline. Raw attempts remain in `.build/journey-resume-*`.

## Release gate and content baseline

The packager previously chose `classic-1.0` for every version from 1.0 onward.
Version 2.0 now chooses `macos-2.0`. The full Mac closure audit includes
official Classic/conversion routes, bundled fan winning routes, strict L3
standalone/carried campaigns and L2 ark prerequisites. It also includes the
new sequence recovery check. The owner later approved build 83 with existing
classifications and documented limits. This leaves bundled closure open as an
engineering goal but defers it as a release prerequisite for build 83. iOS
device gates remain separate. [Release-tooling checks](release-tooling.log)
pass 77 tests.

The [resource manifest](bundle-inputs.json) hashes 18,371 files, totalling
2,284,443,803 bytes, from the retained full 1.9.7 build-82 content package.
This is a proposed content baseline, not a macOS 2.0 app candidate. All 535 fan
archive hashes match the 15 October bundle audit. The existing route audit still
records 2,399 wins and 3,621 route gaps. Fixture hash checks pass for the 120
original routes, 322 additional campaign fixtures, 120 L2 routes and 70 L2
carry-over witnesses. Those checks do not replay campaigns on a new candidate.

A current-host recheck ties the Classic routes to this content baseline. All
1,307 `Ports` files and all 537 `LevelPacks` files match their recorded hashes.
The strict current-source gate passed all 292 official routes and 60 Oh Yes!
conversions. The full quest passed 1,056 recoveries, 352 progress resumes and
six chapter transitions. See the [Classic content recheck](classic-content-recheck.json)
and the updated [quest evidence](../ClassicConversionQuest.json).

The initial replay run records source revision `41b7b0f5`. Current `main` is
`eb6d58d7`. I reran the prebuilt route and quest verifiers on current `main`;
all 352 routes, the full quest and its negative checks pass. The generated quest
JSON matches the committed evidence. No `Sources/NxlvKit/*.swift` files or
Classic verifier files changed between the binary source revision and current
`main`. The host still cannot rebuild these tools because its Swift compiler and
SDK versions do not match. The [current-main replay record](classic-content-recheck.json)
keeps the run and binary source revisions separate.

The host app used for this check identifies as 1.9.1 build 76. Its full
`Resources` tree differs from the 1.9.7 build 82 baseline: 14,507 files match,
3,830 are missing, 34 differ and one extra file is present. The game data in
`Ports` and `LevelPacks` matches exactly. The host app is not a 2.0 candidate.

The [native NeoLemmix inventory](neo-style-inventory.json) discovers 788 levels.
Seventy-five reference missing style directories under the native decoder's
rules. [The retained inventory source](neo-style-inventory.swift) checks names;
it does not verify each graphic, rendering, mechanics, replays or distribution
rights. A preliminary raw text count included a grouping marker and is not the
accepted dependency result.

## Open bundled-closure work

- Repair the affected L3 standalone and carried routes. The current strict gate
  stops at Shadow 7; prior 90/90 proof belongs to the earlier engine state.
- Prove L2 golden talismans and ark prerequisites, then verify ending playback.
- Close all bundled fan routes and source-behaviour comparisons.
- Supply approved NeoLemmix dependencies and exact-version winning evidence for
  every included level. Keep imported content's separate support claims.
- Close source-engine fidelity, exposed story/media transitions and endings.
- Keep these bundled-content and engine-fidelity gaps open in release claims
  until their evidence passes. Build 83 retains the existing Complete/Beta
  classifications and does not claim full bundle closure.

## Build 83 candidate checks

Fresh candidate regression, universal packaging, signing, notarisation,
Gatekeeper and downloaded update verification remain required. Physical and
accessibility checks that the acceptance record defers remain open. Use the
build-83 acceptance record for the release boundary. A future full-closure run
can use the strict audit below; it is not the build-83 acceptance gate.

[Preflight](preflight.json) records the package rejection and exact content
baseline. No 2.0 version bump, public archive, update-feed change or publication
was performed in that preflight. After a candidate is available, run the fresh
candidate audit under its accepted release scope:

```sh
python3 Tools/ReleaseReadiness/audit.py --scope macos-2.0 --app \
  --app-bundle "/absolute/path/inside/this/checkout/Ultimate Lemmings.app"
```
