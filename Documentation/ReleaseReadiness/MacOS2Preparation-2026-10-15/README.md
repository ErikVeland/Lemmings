# macOS 2.0 preparation

Status: journey checkpoint resume implemented. Release closure remains open.
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
Version 2.0 now chooses `macos-2.0`. Its relevant Mac P0 gates include bundled
engine/content closure; iOS device gates remain separate. Unknown unclassified
gates still block closure. [Release-tooling checks](release-tooling.log) pass
77 tests. The full Mac audit requires official Classic/conversion routes,
bundled fan winning routes, strict L3 standalone/carried campaigns and L2 ark
prerequisites. It also includes the new sequence recovery check.

The [resource manifest](bundle-inputs.json) hashes 18,371 files, totalling
2,284,443,803 bytes, from the retained full 1.9.7 build-82 content package.
This is a proposed content baseline, not a macOS 2.0 app candidate. All 535 fan
archive hashes match the 15 October bundle audit. The existing route audit still
records 2,399 wins and 3,621 route gaps. Fixture hash checks pass for the 120
original routes, 322 additional campaign fixtures, 120 L2 routes and 70 L2
carry-over witnesses. Those checks do not replay campaigns on a new candidate.

The [native NeoLemmix inventory](neo-style-inventory.json) discovers 788 levels.
Seventy-five reference missing style directories under the native decoder's
rules. [The retained inventory source](neo-style-inventory.swift) checks names;
it does not verify each graphic, rendering, mechanics, replays or distribution
rights. A preliminary raw text count included a grouping marker and is not the
accepted dependency result.

## Open release work

- Repair the affected L3 standalone and carried routes. The current strict gate
  stops at Shadow 7; prior 90/90 proof belongs to the earlier engine state.
- Prove L2 golden talismans and ark prerequisites, then verify ending playback.
- Close all bundled fan routes and source-behaviour comparisons.
- Supply approved NeoLemmix dependencies and exact-version winning evidence for
  every included level. Keep imported content's separate support claims.
- Close source-engine fidelity, exposed story/media transitions and endings.
- Verify physical controllers, VoiceOver, minimum-OS/Intel hardware, sustained
  performance and prior-release save upgrades on the eventual candidate.
- Freeze the final source and content, build universal, sign, notarise and verify
  the downloaded package and update path.

[Preflight](preflight.json) records the package rejection and exact content
baseline. No 2.0 version bump, public archive, update-feed change or publication
was performed. After the gates close, run the fresh candidate audit:

```sh
python3 Tools/ReleaseReadiness/audit.py --scope macos-2.0 --require-closure --app \
  --app-bundle "/absolute/path/inside/this/checkout/Ultimate Lemmings.app"
```
