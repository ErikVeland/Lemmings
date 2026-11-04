# Developer handover

This is the entry point for a developer evaluating or taking over the project.
It describes the engineering handover, not permission to distribute the games.
Read [third-party notices](../THIRD_PARTY_NOTICES.md) before sharing a package.

## First hour

Use a Mac with Git, Python 3, zsh and an Apple Swift 6 toolchain. The package
requires Apple frameworks. Windows and Linux are not supported build hosts.
Full Xcode is needed for iOS/tvOS compilation. Simulator and device acceptance
are separate from the source tests below.
The verified source baseline below uses Xcode 27.2 and Swift 6.4. The manifest's
Swift 6.0 minimum does not establish that every older SDK builds current source.

From the repository root:

```sh
xcode-select -p
swift --version
python3 Tools/RepositoryMaintenance/check.py
zsh Scripts/run-source-tests.sh
```

The source test command forces muted audio and offscreen windows. It selects
shared engine, mobile-core, TV-core and app-core Swift Testing suites and prints
the data-dependent exclusions. It is not a packaged-app launch or an all-platform
acceptance test.
`run-swift-tests.sh` currently disables XCTest execution. XCTest fixtures are
compiled but are not counted as executed coverage by this command. Extending
the runner to XCTest requires a separate asset and toolchain compatibility pass.
SwiftPM may need network access to resolve the pinned Sparkle dependency.
No Apple account, provisioning profile, collector or commercial game files are
needed for this route. Do not start with `build-local-app.sh`: that packaging
path requires ignored content and additional asset tools.

For a stronger check, use the isolated verification command:

```sh
python3 Tools/DeveloperHandover/verify.py
```

It copies the current Git-visible working files, including uncommitted edits
and non-ignored new files, into a new directory under
`.build/developer-handover/`. It does not copy `.git`, ignored content, local
build caches or signing keys. It records each input's SHA-256, the base commit,
working-tree status and toolchain, then runs the same source tests there.
It neither launches the app nor changes the original checkout or player data.
Its report distinguishes preparation from a completed test run. A timeout,
dependency-fetch failure or failing test is a failed check, not a pass.

Use `--prepare-only` to inspect the snapshot without running Swift tests.
Use `--output /absolute/new/directory` to retain it elsewhere. The destination
must not already exist. Generated snapshots are local review material, not
rights-cleared distributions. Do not send one without reviewing its contents.

## Ownership and change guide

The detailed module contracts live in [architecture](../ARCHITECTURE.md).
Use this smaller map to choose a starting point:

| Task | Starting point | Validation |
| --- | --- | --- |
| Classic parsing or simulation | `Sources/NxlvKit/Classic*` | Source tests, then [Classic completion](ClassicCompletion/README.md) with the required data |
| Lemmings 2 rules or campaign | `Sources/NxlvKit/Lemmings2*` | Source tests, then [L2 completion](Lemmings2Completion/README.md) |
| Lemmings 3 rules or campaign | `Sources/NxlvKit/Lemmings3*` | Source tests, then [campaign completion](CampaignCompletion/README.md) and current release gates |
| NeoLemmix compatibility | `Sources/NxlvKit/NeoLemmix*` and `Nxlv*` | [Pinned oracle and limits](1.7Roadmap.md) |
| Shared stores, progress and services | `Sources/LemmingsAppCore` | `Tests/LemmingsAppCoreTests`, especially store round trips and recovery |
| Mobile input, geometry and checkpoints | `Sources/LemmingsMobileCore` | `Tests/LemmingsMobileCoreTests` |
| Shared pixel controls and drawing | `Sources/LemmingsGameArt` | [UI principles](UIPrinciples.md), focused rendered-state tests |
| Mac lifecycle, menus and input adapters | `Sources/LemmingsLocal/main.swift` and adjacent types | Focused scripts in `Scripts/`, native tests through `Tools/UITestRunner/run.py` |
| iOS/tvOS services and views | `Sources/LemmingsMobileUI`, `Sources/LemmingsTVUI`, `Apps/` | [Mobile gate](ReleaseReadiness/2.0ReleaseGate-2026-10-14.md) and [TV parity](../Apps/UltimateLemmingsTV/IOSParity.md) |
| Translation | `InterfaceLocalisation.swift`, `Tools/Localisation` | [Localisation handover](Localisation.md#translation-handover) |

Follow one change across parser or input, simulation, state, storage and
presentation. Keep the deterministic engine independent of display timing.
Preserve replay and checkpoint identities when changing rules or formats.
Controls, Hot Seat, hints and recovery require Classic/L2/L3 parity checks.
Native UI checks remain offscreen and muted. Report checks that cannot run in
that mode instead of opening windows.

## A useful engineering evaluation

Ask the receiving developer to build the source, trace one gameplay command,
inspect a replay and explain a store round trip. Let them choose a small defect
or change and identify the owning module and regression. That exercise is more
useful than a walkthrough that only the original author can repeat.

Do not claim that a winning route establishes original-engine fidelity, or
that a source test pass certifies a distributed binary. Start release questions
with [release scope](ReleaseScope.md) and the exact candidate's evidence.

## Verification record

The 19 October 2026 isolated source run passed 372 Swift Testing tests on
Apple silicon with Xcode 27.2 and Swift 6.4. Its source snapshot, hashes and
logs remain under `.build/developer-handover/2026-10-19-verified/` locally.
That historical result does not certify later source or another toolchain.
The [original handover record](https://github.com/ErikVeland/Lemmings/blob/75fc1f34508d379baced019796cee48ff8ec0e27/Documentation/DeveloperHandover.md#verification-record)
preserves the run details and exclusions.

Source tests do not establish signed-package acceptance, physical input,
VoiceOver, HDR appearance, audible playback or sustained device performance.
Use the current platform and content gates for those checks. Rerun isolated
verification when the source or toolchain changes.
