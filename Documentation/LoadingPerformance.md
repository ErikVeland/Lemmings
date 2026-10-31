# Loading and transition latency

Measured on the local Apple Silicon development Mac on 25 September 2026.

## Causes fixed

- Level Select rebuilt every game's catalogue on each visit. Chronicles also constructed all 90 runtimes to check availability. Bundled identities and decoded metadata now stay in bounded process caches.
- Catalogue discovery starts after the first visible frame. A prepared catalogue opens directly. Classic Start also bypasses the loading page when its verified bundled artwork is already installed.
- Classic Start rebuilt the current campaign, picker and native menus. It now reuses the current bundled campaign.
- A forced checkpoint meant both “capture now” and “wait for disk.” Level starts and retries now capture immediately and use the serial background writer. Exit still waits for pending saves.
- Music recordings were decoded into a full-length PCM buffer on the main actor. They now stream, with two consecutive passes scheduled ahead for looping.
- Completed replay movies were copied and hashed on the main actor. Retention now holds an open source file and streams it to storage on a background task. Recorder cleanup can remove its temporary path without losing the open recording.

Bundled-resource caches apply only inside an application bundle. Imported game data and fan archives still receive fresh content checks. Content identities and replay checksums retain their existing formats.

## Local measurements

| Operation | Before | After |
| --- | ---: | ---: |
| Repeat Lemmings 2 catalogue | 60.0 ms | 0.1 ms |
| Repeat Lemmings 3 catalogue | 303.2 ms | below 0.1 ms |
| Prepared Classic browser | — | 55–71 ms |
| Prepared Classic Start | 418.3 ms before campaign/save fix | 13.6 ms |
| Repeat Classic retry | 24–52 ms before save fix | 10.7–11.2 ms |
| Dispatch retention of a 32 MB replay | — | 0.2 ms |

Catalogue baseline used optimized builds. The final Start/save checks used the integration executable with an optimized simulation library and unoptimized app code. These are local observations, not universal deadlines.

Cold work still exists: initial Classic content preparation measured 0.85–0.93 seconds, and the first Chronicles catalogue scan measured 0.48–0.69 seconds. The latter runs in the background during normal launch. New imports and changed archives must still be read and validated. No artificial delay was added, and the requested fresh-level countdown remains separate from loading.

## iPad loading

### First visible screen — 30 October 2026

iOS uses a bundled `LaunchScreen.storyboard` with a literal opaque black
background and the small, pre-exported Ultimate Lemmings logo. Its launch
configuration also requests Dark appearance so system-background fallback is
black. Both mobile application windows start black. The shared iOS/tvOS root first presents that logo and the existing pixel
hourglass; its pulse honours Reduce Motion and adds no input targets or sound.
It does not decode the Macintosh artwork banks to draw this surface.

Disk-backed library controller construction waits until the loading surface
has submitted a frame. Catalogue discovery, including bundled exclusion archive
fingerprints, then runs on the existing serial preparation worker and transfers
the new catalogue once to the menu. It no longer runs in the library's
`viewDidLoad`. Player, save, sync and authentication setup follows the visible
loading surface. Widget Desk Clock links received during startup remain queued
until the library is attached. TV retains its existing save migration before
opening the library. No artificial minimum loading duration was added.

Both simulator-SDK module compilations and application entry points pass.
Seven windowless captures cover phone portrait/landscape, folded/opened/tabletop
Duo, iPad and TV; artwork stays inside the supplied safe pane and adds no action
targets. Folded and opened Duo captures were inspected. An isolated native
probe confirms catalogue discovery uses the off-main, 8 MiB-stack worker and
retains 535 fan packs from an existing archived iOS bundle. This does not measure
full startup or demonstrate a physical-Duo speed-up. The iOS asset catalogue
compiles; its tool reports unavailable CoreSimulator services. Native launch
composition, animation, system launch-image sizing, widget delivery and actual
cold-launch timing remain device checks. Mac startup is unchanged. Engine
suites and release audits were skipped for this startup/presentation change.
Local evidence is under `.build/startup-loading/`.

Inner-screen follow-up: the prior packaged device app contained both named
launch assets and the launch dictionary, but the user still observed a long
white pre-loading interval. The explicit storyboard replaces that dictionary
on iOS and is registered in the app resource build phase. The first app-frame
layout now uses UIKit's safe-area frame directly, and localisation of the
hourglass accessibility label waits until the first submitted frame. This
removes custom reserved-region discovery and localisation storage from that
first-frame path. These changes do not measure or promise a shorter debugger
or pre-main launch interval.

`ibtool` compiles the storyboard without warnings, notices or errors. The final
shared core, artwork, UIKit and app-entry SDK checks pass for iOS and tvOS.
A full unsigned iOS Xcode build could not resolve the local package in this
sandbox: the first attempt required a blocked remote fetch, the cached retry
hit protected manifest diagnostics, and the local-cache retry reported missing
local package products. These are build-environment limits, not a completed app
package. Physical cold launch and system launch-snapshot behaviour remain open.
TV retains its existing black launch dictionary; it uses the shared first-frame
controller changes. No save was deleted or reset. Follow-up evidence is under
`.build/duo-correction/`.

Startup artwork source integration: `GameStartupArt` lives beside its hourglass
pixels in the established `PanelGlyphArt.swift` source. A retained iOS Simulator
package source list omitted the new `GameStartupArt.swift` file, causing the
startup controller's unresolved-name error. The original path remains as a
comment-only compatibility file for source lists that already include it. This
changes source discovery only; startup artwork and behaviour are unchanged.

An isolated public-interface compilation passes for iOS and tvOS using only
`PanelGlyphArt.swift`, with the standalone startup source deliberately omitted.
This verifies both startup layout and hourglass calls under retained source
lists. All eight shared SDK modules and both application entry points also
compile for iOS and tvOS. This is compiler validation, not a signed app-package
build or a physical-device check. The current version-history gate passes. Engine suites, UI tests and
release audits were skipped for this source-integration fix.

### Saved-level preparation — 30 October 2026

Library opening, level previews and checkpoint preparation use one serial actor
executor backed by an 8 MiB-stack thread. Native L2 stepping exhausted the
cooperative pool's smaller stack in the isolated Beach resume regression
(`Lemmings2Runtime.step`, stack-guard SIGBUS). The larger worker preserves actor
isolation, cancellation and off-main preparation without reserving a new stack
for every preview. Classic, L2, L3 and supported NeoLemmix share this worker.

Resume now uses a loading page while preparing, with no level-selection or Play
targets. Fixed Back/Home navigation retains cancellation. This includes wide Duo
layouts whose carousel artwork is suspended during preparation. Ready remains a
separate paused step. The owner reported the earlier detail page looked interactive
during Gen8 build-41 acceptance. The replacement needs device acceptance.

The Gen8 build-41 trace also captures a 4.95-second Journey Resume pause. The
browser reloaded and decoded the saved Journey inside its per-level filter.
Build 42 reads that run once per browser configuration and keeps the existing
current-position and unlock rules. It does not cache state between rebuilds.
Device timing for this correction remains pending.
The 31 October recovery restores 2.3's direct checkpoint preparation. It retains an existing
preview but does not render a new preview before restoration. Leaving cancels the
request; L2, L3 and Neo reconstruction check cancellation between ticks. Results
from obsolete requests cannot replace the current screen. L2/L3 locate saved
levels by identity before relying on their old catalogue position. Saved queues
are resolved before standalone engine routes. Save formats and identities stay
unchanged.

The muted offscreen regression reopens a 2,000-tick save of **Quad Quirks on the
Quay!**, with and without a cached preview, restores its exact state hash, then rewinds and
returns to that state. It checks retained attempt ID, owner, scope, camera and
selected control using isolated files. Native sequel cancellation and existing
Classic/L2/L3/Neo checkpoint and rewind checks pass. This is local source
validation; physical Duo timing and the user's exact save remain device checks.

The mobile shell opens Classic packs, Lemmings 2, Lemmings 3, NeoLemmix and collection libraries on a content actor. Library construction includes file reads, campaign decoding and imported-content fingerprints. Results transfer to the menu only if the request is still current. Saved runs start after their library has opened.

The wide carousel requests the selected preview before its two neighbours. Its three requests fit the prepared-session cache, so neighbouring covers do not evict the selected session before Play. Leaving the browser, changing its library or starting a level cancels its artwork tasks and stops its animation clock. Gameplay never requests menu previews.

Play cancels fan counts, shuffle scans and progression preparation, then waits for those workers before presenting gameplay. Cancelled preview requests stop at decoding boundaries and cannot cache or publish stale sessions. Classic, Lemmings 2, Lemmings 3 and NeoLemmix all check cancellation during preparation. A decoder already inside one synchronous operation must return before cancellation takes effect.

Bundled sequel fingerprints stay in a process cache because the app bundle is immutable. Imported directories are hashed again, so changed player content still invalidates saved runs. Hot Seat restoration prepares artwork with the saved owner's settings on the worker. It retains the existing paused handover.

These changes have no physical-iPad timing measurement yet. Validate cold launch, carousel browsing, Play during preview loading, Retry, Continue and saved-run restoration on the device. Headless preparation tests cover off-main library construction, cancellation, bounded caches and checkpoint restoration.

## Validation

Run the focused latency and route checks:

```sh
TEST_SCOPE=loading-latency TEST_OPTIMIZE=1 zsh Scripts/run-app-integration-tests.sh
zsh Scripts/run-adaptive-dj-playback-tests.sh Sources/Music
zsh Scripts/run-fan-library-tests.sh
```

The latency harness checks that prepared browsing and Start avoid loading pages and retain the selected level. It also verifies byte-for-byte replay retention and its checksum after deleting the recorder's temporary source. The playback test exercises repeated streamed loops, suspend/resume and stale callbacks after stop. The rendered prepared browser was inspected at `.build/loading-browser.png`.

Streaming uses consecutive file scheduling provided by [AVAudioPlayerNode](https://developer.apple.com/documentation/avfaudio/avaudioplayernode).

The Hot Seat/recovery suite passed against an immutable resource bundle, including exact checkpoint restoration, legacy fan graphics upgrades, paused handovers and Escape saves. An initial run against `.build/local` failed while a separate build was updating that resource directory; use a completed app bundle through `LEMMINGS_TEST_APP` for repeatable checks.

Local test release: version 1.5, build 45. The Apple Development signature and ZIP integrity were verified. This local build is not notarised.
