# Developer handover

This is the entry point for a developer evaluating or taking over the project.
It describes the engineering handover, not permission to distribute the games.
Read [third-party notices](../THIRD_PARTY_NOTICES.md) before sharing a package.

## Implementation plan

The first cleanup is deliberately bounded. Establish a reproducible source
baseline before changing engine behaviour or reorganising working modules.

| Work | Acceptance condition | Status |
| --- | --- | --- |
| Onboarding | One documented path from checkout to source tests, without private assets or signing | Implemented below |
| Reproducibility | A separate source snapshot, input hashes, toolchain record and retained test log | `Tools/DeveloperHandover/verify.py` |
| Repository hygiene | Compiler products leave the source tree and maintenance rejects their return | See the verification record below |
| Engineering map | A developer can locate an engine, a command, a save and the relevant checks | Ownership and change guide below |
| Rights and services | Code, assets, optional services and unconfirmed ownership are distinguished | [Handover dependencies](HandoverDependencies.md) |
| Verification | Run the source workflow without ignored content and record failures honestly | See the verification record below |

This pass does not claim engine fidelity, commercial clearance or a finished
cross-platform release. Those have their own gates. Further extraction of large
types should follow a measured maintenance problem and a passing regression
baseline, rather than file-size targets.

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

On 19 October 2026, isolated verification passed on Apple silicon with Xcode
27.2 (27B5019j) and Swift 6.4. It copied the working source, including existing
uncommitted work, without ignored content or application build caches. Its four
Swift Testing runs passed 123 engine, 176 mobile-core, 16 TV-core and 57 app-core
tests: 372 tests in total. The three handover-tool tests and three repository
maintenance tests also pass. Repository syntax, metadata and local-link checks
pass. No app, Simulator or audible test was launched.

The source report, input hashes and logs are retained locally under
`.build/developer-handover/2026-10-19-verified/`. The run required network access
for pinned Sparkle inputs. The initial restricted attempt failed during cache
creation, and the next attempt failed during dependency fetching. Both remain
recorded as failures in their local reports.

The first compiled snapshot exposed two artwork suites missing from the source
gate exclusions and two stale tests. The source gate now excludes
`MacArrowWrapTests` and `MacExitDoorTests`, whose generated artwork is absent in
a source-only checkout. The exact-aim regression now aims at each actor rather
than expecting its neighbour. The attempt-start test waits for the documented
background-write flush before reopening records. No runtime rule changed.

Root `crowd-1` compiler products and the fingerprinted fan audit's intermediate
`build/` directory were preserved in
`.archive/developer-handover-2026-10-19/compiler-output/` and removed from tracked
source. The audit results, manifests and replay witnesses remain in place.
Ignore rules and repository maintenance now reject those compiler products.
Generated snapshots and archives are local storage, not transferable packages.

The run does not execute XCTest cases, data-dependent suites, native UI journeys,
full content replays or signed-package acceptance. Existing deprecation warnings
remain, including AppKit warnings in the Mac shell. The checked-in CI workflow
selects an older Xcode version; this local result does not certify that runner.
Its new handover-tool step has been tested locally, not on GitHub Actions.

Before a developer assumes production ownership, complete a source/asset rights
review, agree support and service responsibilities, and let that developer
reproduce the build and make a small change. Use the existing platform and
content gates for broader acceptance. Reports under `.build/` are disposable
local evidence. Rerun verification for a new source or toolchain.

## Repository cleanup follow-up

The 19 October cleanup moved 13 superseded root release notes into ignored local
storage. The [release-note index](ReleaseNotes.md) and existing citations now
link to their exact Git revision. Historical packaged notes, input manifests
and replay evidence remain in place.

Repository checks and handover snapshots now share exclusions in
`Tools/RepositoryMaintenance/repository_policy.py`. The policy covers local game
data, compiler output, private signing inputs and user state. Checks reject
symlinks before reading their targets and handle deleted tracked files and
empty shell scripts. Four handover tests and 92 release-tooling tests pass.
Repository hygiene and isolated snapshot preparation also pass. The source
suite above was not rerun for this Python and documentation cleanup.

About 3.5 GiB of this cleanup's earlier temporary verification output was
removed. The reports, logs and input manifests remain. The passing source
snapshot remains without its regenerable build cache. These operations did
not remove the original checkout's asset caches, signing inputs or feature work.
