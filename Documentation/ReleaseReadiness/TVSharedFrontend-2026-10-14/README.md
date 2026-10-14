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
