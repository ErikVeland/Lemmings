# Ultimate Lemmings

The 21 October merge combines the two Mole runtime changes. Earlier L3 trace
scores describe their recorded source snapshots. See the [merge validation](Documentation/ReleaseReadiness/Release211ProgressionMerge-2026-10-21.md)
for the combined runtime and replay identities.

Ultimate Lemmings is an unofficial native Swift port of the 2D Lemmings games.
Start with the [developer handover](Documentation/DeveloperHandover.md) to build
and test the source without private game data. Current feed versions, package
evidence and completion limits are recorded in
[release scope](Documentation/ReleaseScope.md). An update-feed entry is not
acceptance evidence for its binary.
Version 1.3 added an iPhone/iPad development target. The separate mobile 2.0
work targets a full iOS release for iPad, iPhone and iPhone Duo,
including Classic, Lemmings 2 and Lemmings 3. The app uses
native interpreters and does not run DOS code through an emulator. Commercial
game data is not committed to this repository;
local builds use the assets supplied in `Sources/Ports`, `Sources/Music` and
`Content/` when present.

The project is not affiliated with, endorsed by or licensed by Sony
Interactive Entertainment. Read [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md)
before distributing a build.

## Download

Find published downloads on the
[releases page](https://github.com/ErikVeland/Lemmings/releases).
Installed Mac copies use the [update feed](appcast.xml). The
[release-note index](Documentation/ReleaseNotes.md) links current and earlier
notes. Read [release scope](Documentation/ReleaseScope.md) for the distinction
between advertised versions and retained acceptance evidence, and the
[tester guide](Documentation/BetaTesting.md) for manual testing.

Use this repository for project source, bug reports and release downloads,
including supplemental artwork handoffs. See the
[repository layout](Documentation/RepositoryLayout.md) for the archived download
repository and the pending private artwork migration.

[Collections](Documentation/LevelCollections.md) keeps each player's favourite
levels and the last 50 distinct levels played. Bookmark levels from Level Select
or their result screens across Classic, fan packs, NeoLemmix, Lemmings 2 and 3.

## Start here

- [Roadmap through 3.0](Documentation/Roadmap.md) — historical milestones, the current baseline and proposed delivery gates through 3.0.
- [2.2 Duo launch plan](Documentation/2.2Roadmap.md) — Thursday release target, launch priorities and device acceptance.
- [Developer handover](Documentation/DeveloperHandover.md) — start without private assets, verify an isolated source snapshot, and find the code and checks for a change.
- [Handover dependencies](Documentation/HandoverDependencies.md) — code ownership, asset rights, optional services and signing inputs still to establish.
- [Development workflow](Documentation/Development.md) — the combined branch, unfinished work and shared build modules.
- [Architecture](ARCHITECTURE.md) — module boundaries, runtime flow and release packaging.
- [Localisation and translation handover](Documentation/Localisation.md#translation-handover) — eight translated languages, review workflow and remaining validation.
- [Project overview](Documentation/Overview.md) — player-facing status and roadmap.
- [2.1 roadmap](Documentation/2.1Roadmap.md) — access, teaching, optional inspection and current acceptance limits.
- [2.0 mobile roadmap](Documentation/2.0Roadmap.md) — three-game iOS scope, Duo layouts, delivery sequence and release gates.
- [1.7 NeoLemmix roadmap](Documentation/1.7Roadmap.md) — pinned oracle, executable gates and compatibility limits.
- [1.9 sequel gate](Documentation/ContentUniverseRoadmap.md#19--the-tribes-complete-chronicles-beta) — winning routes, engine fidelity and campaign evidence.
- [1.5 NeoLemmix source handoff](Documentation/ReleaseReadiness/1.5NeoLemmixHandoff.md) — verified source and corpus evidence, open release gates and non-claims.
- [Precision Zoom](Documentation/PrecisionZoom.md) — Z, Shift-Z and scroll controls, earnings and retry rules.
- [Play insights](Documentation/PlayInsights.md) — home-screen saved counts, consent and collector setup.
- [Release scope](Documentation/ReleaseScope.md) — the meaning of Complete, Playable, Beta and Preview.
- [Content roadmap](Documentation/ContentUniverseRoadmap.md) — the path towards broader 2D content.
- [Level browser](Documentation/LevelBrowser.md) — CoverFlow controls, content boundaries and current evidence.
- [Beta testing](Documentation/BetaTesting.md) — local package and validation procedure.
- [Release evidence](Documentation/ReleaseReadiness/) — current gate records and manifests.
- [1.7 distribution](Documentation/ReleaseReadiness/1.7Build53Distribution.md) — the 1.7.0 release record and its gates.
- [1.3 mobile handoff](Documentation/ReleaseReadiness/1.3MobileHandoff.md) — iOS source evidence and remaining device checks.
- [2.0 device beta](Documentation/ReleaseReadiness/2.0DeviceBeta.md) — bundled Classic content, signed archives, device installation and TestFlight preparation.
- [Automatic updates](#automatic-updates) — Sparkle feed and release requirements.
- [Music timing audit](Documentation/MusicTiming.md) — measured beats, bar estimates and DJ fallback rules.
- [Automatic update evidence](Documentation/AutomaticUpdates.md) — release checks and records.

Historical iPhone/iPad 1.3 source and Simulator gates pass for their recorded
commits. The 2.0 source connects Classic, Lemmings 2, Lemmings 3 and supported
NeoLemmix packs to mobile libraries and sessions. L2 and L3 have native scene
renderers, campaign records and checkpoint routes. NeoLemmix import validates
styles, sprites, rendering and supported simulation features. The 2.0 source
snapshot at `c7305724` passes the Xcode 27.2 source gate, the Mac workflow and
the NeoLemmix gate. Its iPhone and iPad layout and lifecycle tests pass. That
record also describes the older Xcode 26.6 SDK and Simulator limitations. The
[handover verification](Documentation/DeveloperHandover.md#verification-record)
records the newer source-test toolchain separately. Real-data parity,
physical-device and accessibility acceptance, audio, controller, Duo and
distribution gates remain open. See the
[2.0 release gate](Documentation/ReleaseReadiness/2.0ReleaseGate-2026-10-14.md).
The 1.9 release marks Lemmings 2: The Tribes Complete and Lemmings 3:
Chronicles Beta. L2 records 120/120 standalone routes, 70 carry-over variants
and 12 chains. Its Gold Ark and original-engine parity remain open. The
20 October current-source L3 audit on `4bf3bddc` passes 399/416 exact double
replays against installed build 76 resources. Four levels lack a verified
route: 107, 206, 213 and 229. Coverage is 86/90 standalone levels and 313/326
carried fixtures. Mole parity, other source rules, media and transitions remain
open. The build 76 resources have not been directly hash-linked to the 2.1
package. See the [current-source audit](Documentation/ReleaseReadiness/L3MoleVerification-2026-10-15/current-cycle12-audit-4bf3bddc-2026-10-20.json).

The latest full strict audit covers all 6,020 source rows across 535 bundled
fan packs. One exact no-exit level is excluded from playable bundled scope by
owner decision, leaving 6,019 playable levels. The accepted count is 2,404
(39.9%), including one targeted route closure on 21 October. The full audit has
not been rerun. Its historical rows include 3,599 levels without matching
candidates and 18 failed candidate replays. The audit reports no load, decode
or render failures. The audit evidence records identities and verified replays
for 2,755 Classic routes. The new targeted replay is stored separately. This
audit used the installed 1.9.1
build 76 resources. Its 535
`LevelPacks` archives match build 85, and build 86 records no non-localisation
resource-index changes. It does not certify a 2.0.3 app binary. Imported levels
remain outside the bundle and open-ended. See
the [current-main audit](Documentation/ReleaseReadiness/2.0-build83/classic-fan-current-main-audit-2026-10-16/audit.json),
[exit-structure audit](Documentation/ReleaseReadiness/ClassicFanExitStructure-2026-10-20.json),
[build 85 content comparison](Documentation/ReleaseReadiness/2.0.2-build85/bundled-content-equivalence-recheck-2026-10-16.json)
and [2.0.3 release record](Documentation/ReleaseReadiness/2.0.3-build86/README.md).
See the [incremental route record](Documentation/ReleaseReadiness/ClassicFanPropersisionZeroClosure-2026-10-21.json)
and [bundled closure velocity](Documentation/ReleaseReadiness/BundledClosureVelocity.md).
The [playable-scope decision](Documentation/ReleaseReadiness/ClassicFanPlayableScopeExclusion-2026-10-21.json)
retains the source row and excludes only the exact bundled archive member.

The pinned NeoLemmix runnable gate passed 794 levels. Macintosh 2.0.2 build 85
passes the bundled-resource check for all 794 indexed levels and resolves all
719 levels supported by the 26 bundled DMA styles. The other 75 need 44
community styles whose rights remain unresolved. All 794 levels stay in
bundled closure scope. Build 85 includes the packaging fix that links the
existing Xmas group into the parent index. Exact-version winning replay
evidence covers 158 levels; route and source-rule closure remain open. See the
[2.0.2 release evidence](Documentation/ReleaseReadiness/2.0.2-build85/README.md),
[2.0.1 content audit](Documentation/ReleaseReadiness/2.0.1-build84/neo-content.json),
[NeoLemmix package audit](Documentation/ReleaseReadiness/2.0-build83/neolemmix-bundle-audit.json),
[style rights inventory](Documentation/ReleaseReadiness/2.0-build83/neolemmix-style-rights-inventory.json)
and [release scope](Documentation/ReleaseScope.md).

## Translation work

English, Spanish (Latin America), German, French, Brazilian Portuguese,
Italian, Dutch, Norwegian Bokmål and Tamil are included in the current Mac app.
The eight translated language packs are AI-assisted drafts. Human language review and complete
translated-screen and device validation remain open.

Start with the [translation handover](Documentation/Localisation.md#translation-handover)
and the [localisation architecture](ARCHITECTURE.md#localisation).
Review the locale checkpoint files under `Tools/Localisation/drafts/` before
editing. Use `python3 Tools/Localisation/install_drafts_for_testing.py
--for-in-app-testing` to refresh the runtime bundle. The owner approved inclusion in Macintosh 2.0.
Complete the linguistic, font, layout and cross-platform checks before claiming
fully reviewed language support. Structural coverage alone does not establish it.

## Requirements

- macOS 12.3 or later to run the distributed macOS app;
- Apple Command Line Tools with Swift 6 support;
- full Xcode with an iOS Simulator runtime for the 1.3 mobile build and tests;
- Python 3;
- ImageMagick (`magick`) for asset preparation;
- `unar` for the supplied Holiday installer;
- local game data for builds that package commercial content.

The repository's source and tests remain useful without the commercial data,
but data-dependent build and evidence gates report their missing inputs.
Use `TEST_COMPILE_ONLY=1 TEST_SCOPE=dialogs zsh Scripts/run-app-integration-tests.sh`
to compile the dialog harness without running it. This does not validate a
bundled app or any gameplay flow.
Run `zsh Scripts/run-dialog-cursor-tests.sh` for the data-independent focus-order
and cursor-policy checks.

Native UI tests use offscreen windows by default. They still render captures
and exercise controls without covering the game. They need a logged-in macOS
desktop. This is not a WindowServer-free CI mode.
Mechanical tests also default to `LEMMINGS_TEST_AUDIO=muted`. The runner silences
music, effects, replay audio and alert beeps without changing system volume or
saved preferences. Playback clocks still run. Keep audio muted in every window
mode. Use `LEMMINGS_TEST_AUDIO=audible` only for an explicitly requested listening
test. Run `zsh Scripts/run-ui-test-runner-tests.sh` to check these safeguards.
Keep automated runs headless while the user tests gameplay. Report failures and
checks that require visible windows in the test output. Never switch to a visible
mode automatically. The following visible modes require an explicit user request.
Set `LEMMINGS_TEST_WINDOWS=secondary` to show test windows on the second display
(offscreen if there is only one display or the window is too large).
This mode allows composited captures and may activate the test app at launch.
Set `LEMMINGS_TEST_WINDOWS=foreground`
for desktop focus checks or manual inspection. The arcade suite reports its
desktop focus check as skipped unless foreground mode is selected.
Offscreen mode preserves bitmap rendering and responder-chain checks. Use
`TEST_SCOPE=selection-raster` for selection checks across all three engines. Metal/HDR
window-composition checks (`TEST_SCOPE=selection-hdr`) need secondary or foreground mode.
The runner applies this policy to test processes only. Packaged-app launch smoke
tests require `LEMMINGS_TEST_WINDOWS=foreground` because they exercise the signed
app's real launch and full-screen presentation.

The iOS source target supports iOS 16 or later. The 2.0 source supports
player-owned Classic, Lemmings 2, Lemmings 3 and supported NeoLemmix imports
through the system document picker. It does not package commercial game data.
Historical signed build 12 evidence covers Classic only. It does not certify
later three-game packages. See the
[2.0 release gate](Documentation/ReleaseReadiness/2.0ReleaseGate-2026-10-14.md)
for current source evidence and open device and distribution checks.

## Build and run

Build a universal arm64/x86_64 local application:

```sh
zsh Scripts/build-local-app.sh
open ".build/local/Ultimate Lemmings.app"
```

The finished bundle contains the resources required by the app. It must not
depend on the source checkout, current working directory, Homebrew or a
developer-only data path after it is copied.

For a fast local Game Center snapshot, run:

```sh
zsh Scripts/build-game-center-snapshot.sh
```

This builds only the current Mac architecture, signs with the matching Apple
Development provisioning profile, and writes an app plus ZIP to the build and
Downloads directories. Local builds include the full soundtrack, using the
converted AAC cache in `.build/music-aac`; only an explicitly slim release build
uses the smaller main soundtrack. The snapshot does not notarise or run release
gates.

Build and test the iPhone and iPad source target:

```sh
zsh Scripts/check-1.3-mobile.sh --require-sdk
```

The required gate needs an installed iOS Simulator runtime. Physical touch,
audio interruption, thermal, accessibility, signing and device journeys remain
separate acceptance evidence.

Run the data-independent NeoLemmix 1.5 source gate:

```sh
zsh Scripts/check-1.5-neolemmix.sh
```

Pass a checkout of the pinned NeoLemmix Community Edition oracle to add the
real level-corpus gate. See the [1.7 roadmap](Documentation/1.7Roadmap.md) for
the strict runnable and replay commands. A source-gate pass is not a full
NeoLemmix compatibility claim.

## Verification

Run the repository and language checks before preparing a release:

```sh
python3 Tools/RepositoryMaintenance/check.py
zsh Scripts/run-localisation-tests.sh
```

Run the routine minor-release audit for the current source and fixture set:

```sh
python3 Tools/ReleaseReadiness/audit.py --app
```

This checks preserved solution fixture hashes and focused engine regressions.
It does not replay every campaign route. Use `--scope all` after changes that
can alter campaign outcomes. See the [release replay policy](Documentation/ReleaseScope.md#release-replay-policy).

Run the principal deterministic gates when working on the engines:

```sh
zsh Scripts/verify-classic-completion.sh
zsh Scripts/verify-lemmings2-completion.sh
```

Run the focused regression suites with the repository scripts. For example:

```sh
zsh Scripts/run-classic-dos-simulation-regressions.sh
zsh Scripts/run-neolemmix-end-to-end.sh
zsh Scripts/run-nxlv-renderer-tests.sh
```

The audit and completion documents define what each gate proves. A passing
load or smoke test does not prove a winning route or source-engine fidelity.

## Local release packaging

The release script performs the source-change, release-notes, build, signing,
notarisation and archive checks. It creates three timestamped ZIP files in
`~/Downloads`: the standard Developer ID build, a macOS 12 Monterey build and
the development-signed Game Center build.

```sh
SIGNING_IDENTITY="Developer ID Application: Example (TEAMID)" \
NOTARY_PROFILE="lemmings-notary" \
RELEASE_BASE=v2.0.2 RELEASE_TAG=v2.0.3 \
zsh Scripts/build-and-notarise.sh
```

The profile name is the name supplied to `xcrun notarytool
store-credentials`; storing a profile does not make its name discoverable to
the script. If the profile is in a non-default keychain, also set
`NOTARY_KEYCHAIN=/path/to/keychain-db`, or pass `--notary-keychain`.

For a machine with no shared profile name, use Apple ID authentication. The
Apple ID and team ID are passed to `notarytool`; its secure prompt requests the
app-specific password:

```sh
APPLE_ID="developer@example.com" APPLE_TEAM_ID="TEAMID" \
zsh Scripts/build-and-notarise.sh
```

An App Store Connect API key is also supported with `ASC_KEY_PATH`,
`ASC_KEY_ID` and `ASC_ISSUER_ID`. Passwords and private key contents are never
accepted as command-line or environment arguments.

The Monterey worktree must be clean and use the exact release commit. Set
`MONTEREY_WORKTREE` when it is not at `.claude/worktrees/macos12`. Set
`DOWNLOADS_DIR` to use another output directory. Use `--dry-run` to exercise
the gates without building or contacting Apple services.

The release source must be clean. Set `RELEASE_BASE` to the previous release tag
and `RELEASE_TAG` to the candidate version. The script checks a reviewed notes draft, then adds the frozen commit to
the packaged copy. Update the notes draft when the build number changes.

Run the data-independent release checks before using the notarisation
script:

```sh
zsh Scripts/check-release-inputs.sh --allow-empty-appcast
```

The release script runs the same check after it generates a signed appcast.

### Automatic updates

The Mac app uses Sparkle 2.7.3. It checks the signed appcast once per hour and
downloads and installs signed updates in the background. The appcast is
[`appcast.xml`](appcast.xml), and the app embeds its public Ed25519 key.

The release script creates a clean update ZIP from the notarised standard app,
signs its entry with the Sparkle private key in the login Keychain, and writes
the appcast. It does not publish. After the package and hardware checks pass,
the release owner can use `Scripts/publish-github-release.sh` to upload the ZIP
and publish `appcast.xml` to `main` through the GitHub API. Set
`DOWNLOAD_URL_PREFIX` when the release asset URL differs from the default
GitHub URL. Follow the [update procedure](Documentation/AutomaticUpdates.md)
for the required publication inputs.

Keep the Sparkle private key out of Git and out of command arguments. A release
must not proceed when the appcast entry is unsigned or its download URL is not
HTTPS.

Game Center is a separate development-signed archive for registered devices;
Apple does not accept that entitlement in a Developer ID notarisation.

## Repository map

| Path | Role |
| --- | --- |
| `Sources/NxlvKit` | Shared format, rendering and simulation library |
| `Sources/LemmingsLocal` | Native macOS application shell |
| `Sources/LemmingsAppCore` | Shared profiles, records, collections and persistence |
| `Sources/LemmingsAudio` | Shared music, sound effects and playback |
| `Sources/LemmingsGameArt` | Shared bitmap controls, fonts and menu artwork |
| `Sources/LemmingsMobileCore` | Platform-neutral mobile sessions, input, recovery and performance policy |
| `Sources/LemmingsMobileUI` | UIKit, Metal, audio, import and mobile flow adapters |
| `Apps/UltimateLemmingsIOS` | iPhone/iPad application and UI-test target |
| `Sources/LemmingsTVCore` and `Sources/LemmingsTVUI` | TV preferences, controllers and presentation |
| `Apps/UltimateLemmingsTV` | Apple TV application target and assets |
| `Sources/LemmingsDataTool` | Development data inspection utility |
| `Tests` | Focused engine, data, app and evidence suites |
| `Scripts` | Repeatable build and validation gates |
| `Tools` | Probes, catalogues, solvers and evidence generators |
| `Resources` | Repository-owned application resources |
| `Documentation` | Product status, scope, operations and evidence |
| `docs/superpowers` | Retained targeting design and implementation history |

Generated `.build` output, application bundles, local commercial assets,
credentials and worktrees are ignored. `.archive/` is an intentionally ignored
local archive of superseded release records; it is not evidence for the
current build line.

## Input and player-facing behaviour

The app supports keyboard, mouse and supported extended controllers. Shared
QoL behaviour must remain aligned across Classic, Lemmings 2 and Lemmings 3
where their rules allow it. Engine-specific limits stay visible in the
release-scope and overview documents.

See [controller QoL](Documentation/ControllerQoL.md),
[speed controls](Documentation/SuperSpeed.md),
[level hints](Documentation/LevelHints.md) and
[save recovery](Documentation/SaveRecovery.md) for focused behaviour notes.

Audio source coverage and the soundtrack import layout are maintained in
[Audio coverage](Documentation/AudioCoverage.md).

### Controller controls

The complete binding table and validation boundary are maintained in
[Controller QoL](Documentation/ControllerQoL.md). The in-game help and
Settings pages expose the current bindings for the connected device.
