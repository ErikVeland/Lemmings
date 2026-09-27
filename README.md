# Ultimate Lemmings

Ultimate Lemmings is an unofficial native Swift port of the 2D Lemmings games.
The current release shell is for macOS, and version 1.3 adds an iPhone/iPad
development target. It uses native interpreters and does not run DOS code
through an emulator. Commercial game data is not committed to this repository;
local builds use the assets supplied in `Sources/Ports`, `Sources/Music` and
`Content/` when present.

The project is not affiliated with, endorsed by or licensed by Sony
Interactive Entertainment. Read [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md)
before distributing a build.

## Download

The [1.2 build 41 release](https://github.com/ErikVeland/Lemmings/releases/tag/v1.2-build41)
is the latest verified public download.

A universal macOS 1.5 candidate has been built locally for Intel and Apple
silicon, macOS 12.3 or later. Publication is pending a source decision because
another release process is using build number 50. Read the
[draft release notes](Documentation/ReleaseNotes-1.5-build50.md),
[tester guide](Documentation/BetaTesting.md), and
[validation record](Documentation/ReleaseReadiness/1.5PublicRelease.md).
The matching [BBCode draft](Documentation/ReleaseNotes-1.5-build50.bbcode.txt)
will be ready to post when the final build number and download are confirmed.

## Start here

- [Architecture](ARCHITECTURE.md) — module boundaries, runtime flow and release packaging.
- [Project overview](Documentation/Overview.md) — player-facing status and roadmap.
- [1.3 mobile roadmap](Documentation/1.3Roadmap.md) — iPhone/iPad scope, source state and device gates.
- [1.5 NeoLemmix roadmap](Documentation/1.5Roadmap.md) — pinned oracle, executable gates and compatibility limits.
- [1.5 NeoLemmix source handoff](Documentation/ReleaseReadiness/1.5NeoLemmixHandoff.md) — verified source and corpus evidence, open release gates and non-claims.
- [QoL roadmap](docs/superpowers/plans/2026-09-23-qol-roadmap.md) — target selection and rewind priorities.
- [Precision Zoom](Documentation/PrecisionZoom.md) — Z, Shift-Z and scroll controls, earnings and retry rules.
- [Play insights](Documentation/PlayInsights.md) — home-screen saved counts, consent and collector setup.
- [Release scope](Documentation/ReleaseScope.md) — the meaning of Complete, Playable and Preview.
- [Content roadmap](Documentation/ContentUniverseRoadmap.md) — the path towards broader 2D content.
- [Level browser](Documentation/LevelBrowser.md) — CoverFlow controls, content boundaries and current evidence.
- [Beta testing](Documentation/BetaTesting.md) — local package and validation procedure.
- [Release evidence](Documentation/ReleaseReadiness/) — current gate records and manifests.
- [1.5 public release readiness](Documentation/ReleaseReadiness/1.5PublicRelease.md) — current candidate gates and handoff conditions.
- [1.2 handoff](Documentation/ReleaseReadiness/1.2DataIndependentHandoff.md) — data-independent release work and Mac checks.
- [1.3 mobile handoff](Documentation/ReleaseReadiness/1.3MobileHandoff.md) — iOS source evidence and remaining device checks.
- [Automatic updates](#automatic-updates) — Sparkle feed and release requirements.
- [Music timing audit](Documentation/MusicTiming.md) — measured beats, bar estimates and DJ fallback rules.
- [Automatic update evidence](Documentation/AutomaticUpdates.md) — release checks and records.

The iPhone and iPad 1.3 source and Simulator gates pass. Physical-device,
VoiceOver, thermal, signing and distribution evidence remain open. The macOS
local candidate is version 1.5 build 50. Publication is pending. Active NeoLemmix work remains a separate
compatibility lane. Classic content is the completed reference engine.
Lemmings 2 and Lemmings 3 are labelled Preview. The bundled corpus contains
6,020 Classic-format fan levels in 535 packs; this is not a claim of NeoLemmix
fan-pack compatibility. NeoLemmix support remains Beta or Preview until its
real-pack and reference-replay gates pass.

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

The iOS source target supports iOS 16 or later. Its first player-facing slice
imports a player-owned Classic DOS folder through the system document picker.
It does not package commercial game data.

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
real level-corpus gate. See the [1.5 roadmap](Documentation/1.5Roadmap.md) for
the strict runnable and replay commands. A source-gate pass is not a full
NeoLemmix compatibility claim.

## Verification

Run the release audit for the current source and fixture set:

```sh
python3 Tools/ReleaseReadiness/audit.py --app
```

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

The release source must be clean. The script uses `v1.2-build41` as the 1.5
release base. It checks a reviewed notes draft, then adds the frozen commit to
the packaged copy. Update the notes draft when the build number changes.

Run the data-independent 1.5 release checks before using the notarisation
script:

```sh
zsh Scripts/check-release-inputs.sh --allow-empty-appcast
```

The release script runs the same check after it generates a signed appcast.

### Automatic updates

The 1.5 app uses Sparkle 2.7.3. It checks the signed appcast once per day and
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
| `Sources/LemmingsMobileCore` | Platform-neutral mobile sessions, input, recovery and performance policy |
| `Sources/LemmingsMobileUI` | UIKit, Metal, audio, import and mobile flow adapters |
| `Apps/UltimateLemmingsIOS` | iPhone/iPad application and UI-test target |
| `Sources/LemmingsDataTool` | Development data inspection utility |
| `Tests` | Focused engine, data, app and evidence suites |
| `Scripts` | Repeatable build and validation gates |
| `Tools` | Probes, catalogues, solvers and evidence generators |
| `Resources` | Repository-owned application resources |
| `Documentation` | Product status, scope, operations and evidence |
| `docs/superpowers` | Active design specifications and implementation plans |

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
