# Apple TV / iOS parity acceptance gate

**Status: shared frontend connected; acceptance gate open.**

## Gameplay status parity with Mac

The normal TV frontend reserves a top strip for player identity, released/total,
rescued/required and whole-percent rescued, time, actual deaths and the Mac's
shared deaths-before-failure counter. The counter changes to SAFE when the
rescue target is met. Release rate appears only on engines that expose it.
Speed, planning pause, nuke and completion/failure states stay in that strip.
L3 also shows its reserve and moves its status above the playfield. Its death
count includes extra lemmings that started on the map. Rewind refreshes counts
from the restored runtime. Existing HUD controls retain their bounds, and iOS
retains its existing compact status presentation.

Baseline: the local iOS and tvOS source on 14 October 2026. The checkout has
uncommitted changes. This record describes the current implementation and its
validation boundaries, rather than a shipped TV release.

Full applicable iOS parity remains required. The normal TV entry point now uses
`LemmingsMobileApplication` and `MobileLibraryViewController`. It shares the
mobile game controller, native libraries, models, bitmap pages, settings,
collections, records, teaching, audio and service orchestration. Supplying
explicit `TVLibrarySource` fixtures still opens the original TV development
shell. That diagnostic path is not the normal application or the parity baseline.

## Current source coverage

| Area | Shared implementation and TV adaptation | Remaining acceptance |
| --- | --- | --- |
| Content | Shared official Classic releases, Holiday, Oh No, Oh Yes, fan catalogue and updates. Both platforms bundle the Mac L2/L3 data and prepared NeoLemmix packs, styles and sounds in Debug and Release. Imports take precedence through the shared native factories. TV imports folders through a temporary token-protected LAN transfer. | Physical import, unavailable data, update and full-pack journeys. Signed release packaging still needs candidate acceptance. |
| Browsing | Shared search, progress, source identity, previews, favourites and playlist actions. TV carousel supports focused left/right selection and Select. | UIKit focus delivery, system keyboard and large catalogues on TV. |
| Learning and hints | Shared Journey, progression, techniques, saved-run lookup, actual progressive hints and matching verified Classic solutions. Hints no longer opens the old Controls deck. | Physical navigation and recovery. Journeys currently accept Classic entries, as on iOS. Sequel hints remain general coaching. |
| Collections | Shared favourites, recents, editable playlists, random/shuffle and queue resume, with the same profile/Hot Seat scope. | Complete controller-only editing and resume journeys. |
| Profiles and Hot Seat | Shared profile editor and portraits. TV holds a player to edit without switching ownership. Keyboard opens from Initials. Editor deletion confirms before removing solo saves, backups, records and Hot Seat membership and requesting cloud sync. Both house rules, saved sessions, restart, solo/shared switching, roster recall, attempt-owner records and paused Ready handovers remain shared. Save failures retain the transition screen. | Native focus, held-input transitions, keyboard return, VoiceOver, live cloud deletion and physical cross-engine handovers. |
| Gameplay | Shared Classic, L2, L3 and supported NeoLemmix sessions, retry/continue, end/undo, supported rate, speed, step and rewind. A TV Game controls page exposes touch HUD capabilities to the remote. L2 has shared fan mode; fan inputs replay in checkpoints and rewind. L3 uses the shared eight-direction tool picker. | Full native game journeys, controller/remote precision and engine fidelity. L2/L3 expose no release rate. L3 has no nuke. |
| Targeting and ownership | TV retains its gameplay controller through pause menus. Planning pauses retain gamepad aim and refresh targets while physics stays paused. Deliberate actor cycling locks the actor ID until aiming or another deliberate selection. Missing/offscreen actors cannot silently retarget a neighbour. Held Select cannot accept a new page before neutral input. | Physical paused-stick timing, multi-controller and Siri Remote generations, including the virtual iPhone remote. |
| Pause/results | Shared frozen overview, counts, loss allowance, time, supplies, track identity, results, awards and named next actions. Resume remains pinned on the shared pause page. | UIKit scrolling/focus, result variants and VoiceOver. |
| Replay | Shared supported recording, read-only playback, skill-use history and movie export. TV exports movies through the LAN transfer instead of a share sheet. | Physical playback, movie download and cancellation. Sequel verified-solution/movie capabilities remain bounded by the shared session APIs. |
| Records/services | Shared records, achievements, community boards, Game Center adapter, telemetry consent and Play Insights. TV declares the Game Center entitlement. | TV App Store Connect/provisioning, production boards, account consent and live service journeys. No production account settings were changed. |
| Settings | Shared groups, presets, graphics, display/effects, accessibility, soundtrack and controller remapping. TV retains sensitivity/dead-zone choices. Standard/Large/Extra Large use distinct whole-pixel menu scales. New TV preferences select continuous skill changes. | Physical runtime effects and accessible focus. |
| Audio | Shared Adaptive DJ, soundtrack selection/downloads, native sound banks, track notices, pause/speed/rewind and interruption rules. TV builds bundle all soundtrack libraries by default. | Audible comparison needs an explicit request. Engine/data limits remain shared with iOS. |
| Recovery/cloud | Shared owner/session-scoped checkpoints and session navigation. Legacy TV profiles, portraits, solo/shared completion, rosters, exact turns, preferences and the surviving checkpoint migrate once. Old data is retained, and an existing shared run is not overwritten. Shared cloud-library/recovery-code routes are available; TV transfers recovery keys over LAN. | Live cloud linking and purge recovery. Cloud library sync does not back up complete checkpoint payloads or all local collection files. TV adds an explicit off-device save backup/restore adapter; transfer and purge recovery need physical acceptance. |
| Accessibility/lifecycle | Shared accessible action names, interruption pause and explicit Resume. TV uses native focus over the same bitmap targets. Large transfer pages scroll to keep Back reachable. | Physical VoiceOver, system keyboard, background/termination/reconnect and sofa readability. |

## TV effect budget

The user's 14 October performance instruction removes completion glow on TV.
The shared TV playfield creates no completion transition timer or scenery-glow
renderer, and draws no golden border or rescued-sprite auras. It also disables
the extra speed/cinematic explosion surface and added explosion flash cores.
Original explosion spray, actor selection and assignment feedback remain.
These presentation limits apply to Classic, L2 and L3 through the same controller.
They do not change game rules, results, saved-run ownership or Ready handovers.

TV starts at balanced CRT quality, or minimal on two-core devices. The playfield
drawable stays at most one pixel per point. Menu/HUD lettering retains native
scale. Minimal CPU/GPU quality disables the three CRT bloom passes and releases
their scratch textures. Recovery requires measured spare capacity. Bloom also
stays off while the presentation target is below 60 Hz. The focused
headless policy checks cover startup, cost limits, pressure, recovery and thermal
restriction. Physical TV frame timing and native UIKit/Metal rendered output
remain open validation requirements.

## Storage and migration boundaries

The 14 October profile/cloud follow-up moves Edit into the player list, retains
native focus targets during redraws, and marks the Hot Seat host as locked.
Guests can be deselected before Choose a game starts or continues a session.
All engines use this shared roster flow. Shared cloud progress now has a CloudKit
adapter for TV, Mac and iOS. GameKit saved games are unavailable on TV. CloudKit
provisioning, production schema deployment and physical device sync remain open.
See [cloud progress](../../Documentation/CloudProgress.md) for the setup limits.

TV uses Caches for larger local files, including content, collections, records,
journeys, soundtrack downloads and checkpoints. Small profile/Hot Seat metadata
is retained in UserDefaults, with a bounded document size. tvOS may evict cached
files. A recovery key links cloud library progress; it does not restore every
local file or a mid-level checkpoint. Cloud saves also offers Back up TV saves
and Restore TV saves. The bounded `.lemmingstv` archive includes checkpoint JSON,
player/session metadata, collections, playlists, learning state, native campaign
records and applicable preferences. It excludes commercial data, soundtrack
files, exported movies and service credentials. Restore stages files, focuses
Cancel in its confirmation, retains the previous folders and recreates stores
only after the transaction succeeds. Backups are explicit and must be downloaded
to another device. They are not an automatic cloud checkpoint service. Reimport
compatible player-owned game data if TV evicts it before resuming. Do not promise
automatic or cross-device mid-level Resume without separate validation.

The old `tv.localState` defaults and original checkpoint files are retained.
Migration markers advance only after successful migration. A completed migrated
run cannot be reimported on the next launch. Existing shared-frontend preferences
and current runs take precedence. Old completion marks do not invent historical
scores, times or achievements. Unknown legacy source progress remains in the
retained original document. Corrupt/future checkpoints are kept and reported.

Apple documents TV storage in [iCloud Storage](https://developer.apple.com/library/archive/documentation/General/Conceptual/AppleTV_PG/iCloudStorage.html).

## Validation

See [shared frontend evidence](../../Documentation/ReleaseReadiness/TVSharedFrontend-2026-10-14/README.md).
The prior 94 core checks and 76 menu renders covered the original TV frontend.
They cannot close this gate. Current checks compile the shared UI and cover the
migration, input gates, actor lock, fan state and shared bitmap targets. They do
not dispatch native UIKit focus events or establish physical TV acceptance.

Use `Tools/UITestRunner/run.py` in offscreen, muted mode for native checks.
Do not launch a foreground/secondary-display test or audible playback as a
fallback. SDK compilation and the Xcode app build do not establish parity alone.

## Graphics changes

Graphics choices refresh the active shared game controller, playfield display,
HUD skill artwork, minimap and retained solution view immediately, including
while paused. Classic previews use the selected artwork and its render scale.
Artwork packaging resolves a linked Macintosh family before finding sibling
families and monochrome banks. L2, L3 and NeoLemmix retain their native mobile
artwork renderers. Shared display settings refresh across those engines, but
Classic machine artwork substitution remains a Classic-engine feature.
Physical TV graphics switching and CRT compositing still require device checks.

The focused muted checks pass 29 Swift tests and six packaging/build-tool tests.
Four inspected gameplay captures switch artwork at tick 120 without changing
the simulation. HUD targets retain their bounds without overlap across all four
artwork choices at 720p, 1080p and 4K. iOS/tvOS modules and entry points compile, and the tvOS UIKit
settings regression typechecks. That UIKit regression has not run on a device.
The broader `--current-fixes` menu audit fails its replay-overlay target overlap
check at `Tools/IOSMenuAudit/current-fixes.swift:79`. It is not a passing gate.

## Home scenery

The 15 October Home update shares the iPad menu box, scenery reference and camera
with the normal TV app. TV now fits Home to its safe viewport at a whole-pixel scale, with saved
play on the left, libraries on the right and a fixed footer. Native focus uses
the same target geometry. The backdrop has no input surface. It retains one
bitmap and moves its layer with nearest-neighbour sampling through the existing
menu clock. System/game Reduce Motion and inactive scenes hold the camera.
Scenery references follow the selected profile and solo/Hot Seat scope. They do
not restore or mutate a saved run. Classic, L2 and L3 supply their actual exits;
NeoLemmix uses the resolved session zones. Missing scenery falls back to a random
installed level. The original fixture-only TV development shell is unchanged.

Windowless, muted Home checks pass for 126 iPad/TV captures at three interface
sizes, including TV safe areas and scrolling footer targets. They exercise full
Classic/L2/L3 scenery, scoped references, missing/random fallback, reduced-motion
and inactive clocks, camera bounds and exit return. iOS/tvOS SDK modules and app
entry points compile. Native UIKit focus delivery, physical remote/VoiceOver,
layer compositing and frame timing remain open device acceptance checks.

## Fixed TV menus and transport

The normal TV frontend uses a fixed Home board with saved play on the left,
libraries on the right, full-width player identity and build/status text, and a
fixed footer. It selects the largest fitting whole-pixel scale and disables Home
scrolling. Settings groups, controls, remapping and soundtrack libraries use a
paged two-column grid, with Back at bottom-left and Previous/Next in fixed slots.
All shared iOS settings and Reset remain reachable.

Circle toggles planning pause/play directly. Its native Back press and release
cannot also open the pause menu. Menu owns that menu. R2 uses fast-forward and
resumes an existing planning pause, including after held rewind. It never parks
play and cannot accept Ready or another menu. DualSense trigger resistance follows
the selected speed tier. L2 retains backward step/rewind and neutral-input gates.
These paths use the shared Classic/L2/L3 game controller.

The muted, offscreen console gate passes 250 bitmap captures, controller
regressions and 153 native-engine experience checks. Both SDK source/module and
app entry-point checks pass. Run `Scripts/run-tv-console-checks.sh` for the native
render/input gate. Physical controller resistance, UIKit focus/VoiceOver and
television compositing remain open acceptance checks. The fixture-only diagnostic
shell retains its separate input and layout implementation.

The crowd/input follow-up routes gameplay exclusively through
`GCEventViewController` and restores UIKit focus synchronously for menus and the
L3 direction picker. Gameplay claims its controller's system gestures, then
restores their previous settings. The TV Run scheme selects Release optimisation.
Shared Classic sprite caching, L2 batch eligibility, L3 read-only eligibility
and reused bitmap/target data reduce crowd work without changing input targets,
physics, ownership or handovers. Both iOS and tvOS SDK checks pass. The 181 TV
experience checks, native sequel rule suites, 80-actor fixtures and exact pixel
comparisons pass offscreen and muted. Host timings do not establish sustained
Apple TV 4K frame rate. Physical Circle/Back routing, VoiceOver, controller
reconnection and CPU/GPU timing remain device acceptance checks. See
[Apple TV experience](../../Documentation/AppleTVExperience.md) for measurements.
