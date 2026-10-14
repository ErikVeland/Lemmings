# TV shared frontend — 14 October 2026

**Source connected; full TV acceptance remains open.** The normal TV app now
opens the shared iOS frontend through a migration bootstrap. The original
explicit-source TV frontend remains a diagnostic fixture path.

## Implemented source

Shared official/fan libraries and updates, imported L2/L3 and supported
NeoLemmix Preview, search/previews, learning/hints, collections/playlists,
profiles/Hot Seat, pause/results, records/achievements, supported replay,
settings/effects, audio and services now use the mobile implementation.
TV adds native focus, remote/controller input, remote-accessible game controls,
L3 direction focus and LAN import/export. L2 fan mode belongs to the shared
controller and records its native input in checkpoints/rewind.

Migration imports existing profile IDs, portraits, progress, exact Hot Seat turns,
preferences and the surviving checkpoint before creating the shared library.
Old data is retained. An existing shared run takes precedence. Corrupt migration
data produces a reachable Retry page and is not marked complete.

Held Select cannot activate the next page before neutral input. A gameplay
controller keeps its ownership through pause menus. Deliberate target cycling
locks an actor ID, including unavailable/missing/offscreen states. TV main-menu sizes
use distinct 2x/3x/4x bitmap scales. Landscape pause caps its whole-pixel scale
to fit the action shelf. Large transfer and migration error pages scroll.

Larger TV data uses Caches. Small roster metadata remains in bounded defaults.
Cloud saves also offers explicit off-device `.lemmingstv` backup/restore for
checkpoint, collection, learning, campaign, record and roster JSON. It excludes
game content and credentials. Restore stages data and retains previous folders.
The 64 MiB archive is a manual file adapter, not automatic cloud checkpoint sync.
Imported game content must still be available and match the saved fingerprint.

## Checks

| Check | Result and scope |
| --- | --- |
| Offscreen, muted TV experience suite | 121 passed across native Classic/L2/L3 fixtures, migration/bootstrap, Ready/recovery, held activation, stable target IDs, fan history and backup validation/restore. |
| Historical TV bitmap audit | 76 menu captures plus six native Classic playfield captures. It remains evidence for the original frontend. |
| Shared frontend bitmap audit | 66 captures/target checks: 22 states at Standard, Large and Extra Large. Uses the shared bitmap page composers and menu scale function. |
| Xcode iOS Debug app | Unsigned arm64 iOS Simulator build passed with SDK 27.2. This checks shared-source compatibility, without a Simulator launch. |
| Xcode TV Debug app | Passed, unsigned arm64 TV Simulator, tvOS 16 baseline, SDK 27.2. See final build log and source manifest. |
| TV SDK gate | Passed. Compiles every dependency including MobileUI, then typechecks the TV entry point. See final log. |

Local logs: `.build/tv-parity-experience.log`, `.build/tv-parity-xcode.log`,
`.build/tv-parity-ios.log`, `.build/tv-parity-sdk.log`. A final MobileUI SDK
recompile also passes (`.build/tv-parity-final-ui.log`), including the later
read-only replay Hint guard. Shared captures are in
`.build/tv-experience/shared-frontend`. The SDK snapshot is isolated in
`.build/tv-parity-sdk-final` so concurrent SDK checks cannot replace its files. The [source manifest](source-manifest.json) records the exact
files inspected, so a moving branch name is not substituted for source evidence.

The visual review covered shared Home, large Hot Seat, largest transfer address,
pause overview, largest backup menu and restore confirmation. Long pages are full-content captures; they do not prove
native scroll/focus delivery. Review led to scrolling for the transfer and
migration pages. Other shared bitmap states have geometry checks; this record
does not claim a complete manual visual review of every state.

The backup regression initially found that Foundation enumerated `/private/var`
for a root expressed as `/var`. Export now derives relative paths from the
directory enumerator depth, as the shared source-revision reader does. The
regression verifies exact save bytes and rejects traversal and credential keys.

## Remaining acceptance

### Profile and cloud follow-up

Edit now appears in the player list. Menu redraws reuse UIKit targets and retain
focus. Guest roster rows remain toggleable, while the host is labelled and
disabled. Bitmap focus uses a white outline. The green fill and underline no
longer make a focused, deselected guest appear selected.

The follow-up passed 21 cloud tests, including four fake-database CloudKit
checks, 121 Classic/L2/L3 core checks and 78 shared bitmap renders with target
geometry checks at the three TV sizes. The final TV SDK gate and the iOS SDK
gate passed. Logs are `.build/tv-cloud-tests.log`, `.build/tv-profile-core.log`,
`.build/tv-profile-bitmap.log`, `.build/tv-cloud-final-sdk.log` and
`.build/tv-cloud-ios-sdk.log`. Visual review includes the player list, editing,
new players, the locked host and focused guests after deselection.

The UI runner queue was occupied by other local work. The completed follow-up
render/engine programs allocate bitmap buffers and core sessions only, with
muted audio and no windows. Native UIKit focus events and keyboard presentation
were not tested. No foreground or secondary-display fallback was used.

The configured hosted cloud health URL returned HTTP 404. A private CloudKit
adapter is in source for TV/Mac/iOS, with account checks and conditional device
writes. Signed provisioning, production schema deployment and live device sync
remain open. See [cloud progress](../../CloudProgress.md).

### Controller, cursor and performance follow-up

TV uses the requested Square pause/play, Triangle nuke/undo, D-pad minimum/maximum
rate and Options menu layout. Select, Back and skill cycling retain their roles.
L2 holds rewind and leaves a planning pause on release. R2 resumes that pause
before its usual tap/hold speed behaviour. A fresh R2 press takes over a held
L2; a fresh L2 press can start rewind again. Ready and interruption boundaries
still require their normal resume action. Create/View retains extra actions,
including step, repeat, hints and retry. Game controls puts Resume at bottom-right.

DualSense touchpad click now requests DJ shuffle. Optional R2 resistance follows the speed
tier and clears outside active gameplay. TV cursor assignments refresh the
target for the actual skill and clear stale locks after assignment/rewind/pan.
Input polling batches frame updates and reuses target queries. Under GPU pressure,
CRT playfield resolution can fall while HUD/menu lettering stays native.

The follow-up passed 22 focused controller, planning, selection and pacing tests,
121 Classic/L2/L3 core experience checks, and 87 offscreen, muted bitmap renders
with input-target geometry checks at all three TV sizes. TV and iOS SDK compilation
passed after the R2 change. Logs are `.build/tv-controller-tests.log`,
`.build/tv-controller-core.log`, `.build/tv-controller-render.log` and
`.build/tv-controller-transport-sdk/compile.log`. Reviewed renders include
controller mappings/help, adaptive trigger settings and the transport footer.

Physical DualSense feedback, native menu focus/scroll delivery, the intermittent
Classic cursor failure and actual Apple TV 4K frame-time improvement remain
device acceptance checks. L2/L3 release rate and L3 nuke remain engine limits.

### Per-player settings and manual DJ shuffle

The shared TV/iOS frontend saves controller and accessibility choices per player.
Hot Seat settings resolve the current turn owner. TV aim sensitivity, dead zone
and adaptive feedback also have individual profile keys. Legacy settings seed
each profile once. Saving personal edits retains the baseline for other players.
UI size, motion, flashes and song notices read the selected profile in menus and
gameplay. These new preferences persist locally; cloud transfer is not part of
this follow-up.

Touchpad click requests DJ shuffle. Square retains pause/play. Create/View + L3
provides the same request on other gamepads. Audio settings select Same track
(the default) or All tracks. The selector excludes the current recording,
unavailable files and unverified/event-only tracks. Mixing reuses the existing
beat-matched crossfade without changing the selected soundtrack or level state.
Paused, muted, interrupted and Ready states do not start the mix.

The follow-up passed 23 focused migration, profile isolation, shuffle-candidate,
controller and all-engine planning checks. The TV and iOS SDK gates passed.
The offscreen, muted bitmap program passed 96 renders/input-target checks.
Reviewed captures include All tracks, reduced motion/flashes, song notices off,
controller choices and updated help. Logs are `.build/tv-player-shuffle-tests.log`,
`.build/tv-player-shuffle-sdk/appletvsimulator.log`,
`.build/tv-player-shuffle-sdk/iphonesimulator.log` and
`.build/tv-player-shuffle-render-run.log`.

The native muted playback probe initially could not instantiate Core Audio EQ
components in the sandbox. The same offscreen check passed with system component
access, including same-track/all-track selection, crossfade retargeting, mute and
suspension boundaries. See `.build/tv-player-shuffle-playback-run.log` and
`Tests/ManualDJShuffleTests/main.swift`. No audible or foreground fallback was used.
Physical controller delivery, full device Hot Seat journeys and listening
acceptance remain open.

No foreground Simulator, physical device or audible test was launched.
Native UIKit focus/activation, system keyboard, VoiceOver, Siri Remote generations,
virtual iPhone remote, multi-controller journeys, all-engine session round trips,
file-transfer permission/cancellation, live cloud linking and rankings, signed
installation, real game artwork, 1080p/4K performance, memory/thermal behaviour,
listening acceptance and physical cache eviction/backup recovery remain open.

The shared engines retain their fidelity and content limits. Journeys currently
accept Classic entries. L2/L3 have no release rate; L3 has no nuke. Verified
solutions/movie playback depend on each shared session API. The TV Game Center
entitlement is in source; production provisioning and boards were not changed.

See [TV parity](../../../Apps/UltimateLemmingsTV/IOSParity.md),
[TV experience](../../AppleTVExperience.md) and
[mobile release gates](../2.0ReleaseGate-2026-10-14.md).
