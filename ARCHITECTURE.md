# Architecture

This document describes the maintained shape of Ultimate Lemmings. It is the
technical source of truth for module boundaries, runtime flow, data ownership
and release packaging. Product status belongs in
[Documentation/Overview.md](Documentation/Overview.md); release claims belong
in [Documentation/ReleaseScope.md](Documentation/ReleaseScope.md).

## Purpose and boundaries

Ultimate Lemmings is a native game application with separate interpreters for
different 2D Lemmings engine families. It preserves the source rules and data
model of each family. It does not turn every format into Classic rules and call
the result universal compatibility.

The repository contains source code, tests, tools, documentation and public
non-commercial resources. Commercial game data, local signing credentials and
generated application bundles stay outside Git.

## System shape

```text
                         +----------------------+
                         |   LemmingsLocal      |
                         |  macOS app shell      |
                         +----------+-----------+
                                    |
                         platform services and UI
                                    |
                         +----------v-----------+
                         |       NxlvKit        |
                         | formats, engines,     |
                         | rendering primitives, |
                         | replay contracts      |
                         +----------+-----------+
                                    |
                 +------------------+------------------+
                 |                  |                  |
             Classic           NeoLemmix              L2 / L3
             engine            engine family          engines

        LemmingsDataTool      Tests / Scripts / Tools
        data inspection        evidence and validation
```

The diagram shows ownership, not a promise that every current type is already
portable. `NxlvKit` still uses selected Apple frameworks for image, graphics
and hashing work. The application shell is macOS-specific.

### `Sources/NxlvKit`

`NxlvKit` is the shared library. It owns typed data, decoders, rendering
primitives, simulation state, replay inputs and deterministic engine behaviour.
It must not own an application window, menu, file picker, Game Center session,
global input state or a platform-specific event loop.

Its main areas are:

| Area | Responsibility |
| --- | --- |
| Classic | DOS archives, levels, campaigns, graphics, sprites and `ClassicDOSSimulation` |
| NeoLemmix | `.nxlv` parsing, typed level data, styles, rendering and `NeoLemmixSimulation` |
| Lemmings 2 | Native level data, styles, masks, runtime, skills and campaign state |
| Lemmings 3 | Native level data, tools, tribes, runtime and media-facing models |
| Shared runtime | Replay, save/recovery contracts, campaign progress, records and common value types |
| Audio and media | Portable model and decoding logic for supported source formats; playback remains a shell concern |

An engine decides its own rules. A recognised file format does not select an
engine by itself. The content catalogue and import boundary must record both
the format and the source engine family.

### `Sources/LemmingsLocal`

`LemmingsLocal` is the macOS front end. It owns AppKit, GameController,
AVFoundation, Metal, QuartzCore, menus, windows, input routing, audio output,
save locations, bundled-resource discovery, Game Center and the unified game
library. It adapts those services to `NxlvKit` rather than placing them in the
shared engine code.

The application presents content according to the release gate. Complete
content is normal library content. Playable content states its limits. Preview
and beta content are labelled. Unverified content is not shown in the normal
library; it remains available only through an explicit import or developer
path. See [the content roadmap](Documentation/ContentUniverseRoadmap.md).

### `Sources/LemmingsDataTool`

`LemmingsDataTool` is a command-line utility for inspecting and transforming
local data during development. It is not part of the shipped app and must not
become a hidden runtime dependency.

### Tests, scripts and tools

- `Tests/` contains focused executable suites, fixtures and app-level checks.
- `Scripts/` contains repeatable developer and release gates.
- `Tools/` contains evidence generators, probes, solvers and audit utilities.
- `Resources/` contains repository-owned public resources used by the app.

Tests may use local commercial assets when a test explicitly needs them. They
must report missing local inputs clearly and must not silently substitute a
different engine or fixture.

## Runtime flow

1. The app discovers bundled resources and optional imported content.
2. The content catalogue identifies the source engine, format and dependencies.
3. The appropriate engine parser imports typed data and reports diagnostics.
4. The engine resolves styles, graphics and rules without changing the source
   level into another engine's representation.
5. The app supplies platform input, clock, audio and persistence services.
6. The engine advances deterministic logic ticks and emits state for rendering.
7. Replay, save and completion evidence record the engine identity and the
   relevant fixture or manifest version.

The Classic engine uses fixed 17 Hz logic ticks. Display refresh, animation and
input presentation must not change the simulation tick contract. Other engines
may have different rules, but each must define its tick, input and replay
contract before it can claim compatibility.

## Data and persistence

The source of truth for a level remains its source-format representation. A
derived index, catalogue or rendered cache is disposable and must be
rebuildable. Generated caches do not replace source data or evidence.

Save and replay records are engine-specific at the rule boundary and shared at
the storage boundary. A record must retain enough identity to reject an
incompatible engine, level revision, fixture version or state hash. Migration
must preserve current player choices and must fail visibly when it cannot
prove safe recovery.

Completion evidence has a strict meaning:

- **Recognised:** the format is identified.
- **Imported:** required data is retained by the parser.
- **Rendered:** terrain, objects, sprites and masks are available.
- **Runnable:** the engine starts and accepts input.
- **Replay-compatible:** a reference replay reproduces the result.
- **Behaviour-compatible:** source rules match within an agreed tolerance.
- **Complete:** every advertised level has verified completion evidence.

Passing one stage never implies that a later stage passed. The release scope
document is the canonical place for the user-facing wording.

## Build and distribution

`Package.swift` defines the Swift package, the `NxlvKit` library, the native
macOS executables and the package test target. `Scripts/build-local-app.sh`
builds universal arm64/x86_64 local bundles and embeds the supplied local game
data. It targets macOS 13 or later.

The release path is deliberately separate from the local build:

1. `Scripts/build-and-notarise.sh` checks that source changed since the last
   release notes commit.
2. It verifies current release notes, creating them from the recent source
   history when they are absent.
3. It builds and signs the standard and Monterey reference targets.
4. It builds the development-signed Game Center target as a separate archive.
5. It notarises the two distributable Developer ID archives and verifies them
   with Gatekeeper tooling.
6. It writes all three timestamped ZIP files to the configured Downloads
   directory.
7. It writes a separate Sparkle update ZIP containing only the notarised
   standard app and regenerates the signed `appcast.xml`.
8. When `PUBLISH_GITHUB_RELEASE=1`, it uploads that ZIP, creates or updates
   the tagged GitHub Release, and publishes the appcast to `main`.

The Game Center archive is intentionally not submitted to Apple notarisation:
Apple's Developer ID distribution rules reject that entitlement. Its separate
development-signed status must remain visible in release notes and beta
instructions.

The app embeds Sparkle 2.7.3 in `Contents/Frameworks`. Sparkle uses the HTTPS
appcast in the app's `Contents/Info.plist` and verifies update archives with the
public Ed25519 key in that file. The private key stays in the release operator's
login Keychain. A release archive with a missing or unsigned appcast entry is
not an update candidate.

The packaged app uses only resources inside its bundle at runtime. A copied
bundle must not depend on the source checkout, the current working directory,
Homebrew or a developer-only data path.

## Documentation ownership

Each document should answer one question and link to the owner of adjacent
questions.

| Question | Canonical document |
| --- | --- |
| What is the project and how do I build it? | [`README.md`](README.md) |
| How is the code and release system shaped? | `ARCHITECTURE.md` |
| What does a player see today? | [`Documentation/Overview.md`](Documentation/Overview.md) |
| What does Complete, Playable or Preview mean? | [`Documentation/ReleaseScope.md`](Documentation/ReleaseScope.md) |
| What content is planned and how is it gated? | [`Documentation/ContentUniverseRoadmap.md`](Documentation/ContentUniverseRoadmap.md) |
| What evidence closes a campaign or release gate? | [`Documentation/ReleaseReadiness/`](Documentation/ReleaseReadiness/) and the relevant completion README |
| How is local beta packaging run? | [`Documentation/BetaTesting.md`](Documentation/BetaTesting.md) |
| What design decisions are active? | [`docs/superpowers/`](docs/superpowers/) |
| What third-party material and rights limits apply? | [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) |

Do not copy a status table into another document. Link to the canonical table
and add only the context needed for that document's audience. Evidence files
must state scope, validation method, remaining risk and the build or source
revision they describe.

## Portability seams

The first portability target is a tested engine contract, not a second UI.
Future iOS, Windows and Linux shells should reuse deterministic simulation,
level data, replay fixtures and release gates. Platform work should introduce
small adapters for:

- rendering and image decoding;
- input and controller events;
- clocks and display timing;
- audio output;
- file and save locations;
- notifications, accounts and platform services.

Do not import AppKit or Game Center into `NxlvKit`. Do not replace a source
engine with a lowest-common-denominator ruleset to make a port appear broader.
The current platform plan and known Apple-only dependencies are recorded in
[`Documentation/ModernReleasePlan.md`](Documentation/ModernReleasePlan.md).

## Repository hygiene

- Keep generated `.build` output, app bundles, commercial assets, credentials
  and local worktrees out of Git.
- Keep historical release records in the explicitly labelled ignored archive;
  do not use them as evidence for a newer build.
- Prefer one canonical document, manifest or fixture for each claim.
- Name tests and tools after the gate they prove.
- Keep fixtures close to the suite that owns them and hash any fixture set used
  for release evidence.
- Make failures actionable. A missing asset, stale manifest or unsupported
  platform must fail with the next required action.
- Before a release claim, run the relevant gate from a clean source revision
  and record the resulting evidence.
