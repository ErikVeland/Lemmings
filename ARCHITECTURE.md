# Architecture

This document describes the maintained shape of Ultimate Lemmings. It is the
technical source of truth for module boundaries, runtime flow, data ownership
and release packaging. Start with the
[developer handover](Documentation/DeveloperHandover.md) for setup and checks.
Product status belongs in
[Documentation/Overview.md](Documentation/Overview.md); release claims belong
in [Documentation/ReleaseScope.md](Documentation/ReleaseScope.md).

## Purpose and boundaries

Ultimate Lemmings is a native game application with separate interpreters for
different 2D Lemmings engine families. It preserves the source rules and data
model of each family. It does not turn every format into Classic rules and call
the result universal compatibility.

The repository contains source code, tests, tools, documentation and resources
with different ownership and licence terms. Git tracking does not establish
commercial clearance. Commercial game data, local signing credentials and
generated application bundles stay outside Git. See the
[handover dependency inventory](Documentation/HandoverDependencies.md).

## System shape

```text
             +----------------------+   +----------------------+
             |   LemmingsLocal      |   | UltimateLemmingsIOS  |
             |  macOS app shell     |   | UIKit/Metal app      |
             +----------+-----------+   +----------+-----------+
                        |                          |
             macOS platform services      LemmingsMobileUI
                                                   |
                                          LemmingsMobileCore
                        |                          |
                        +------------+-------------+
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

The diagram is a high-level runtime view. The shared modules below sit between
the shells and `NxlvKit`; their exact dependencies are in `Package.swift`.
It is not a promise that every current type is portable. `NxlvKit` still uses
selected Apple frameworks for image, graphics and hashing work. The macOS,
iOS and tvOS shells adapt platform services.

### Shared service and presentation modules

| Module | Responsibility | Direct project dependencies |
| --- | --- | --- |
| `LemmingsAppCore` | Shared storage, records, recovery, privacy and online-service models | `NxlvKit` |
| `LemmingsMobileCore` | Typed sessions, input and layout contracts, checkpoints | `LemmingsAppCore`, `NxlvKit` |
| `LemmingsTVCore` | TV controller, activation, transport and migration policies | `LemmingsMobileCore`, `NxlvKit` |
| `LemmingsGameArt` | Shared pixel menus, controls, typography and presentation effects | `NxlvKit`, `LemmingsMobileCore`, `LemmingsTVCore` |
| `LemmingsAudio` | Sound and music playback, decks and playback transitions | `NxlvKit` |
| `LemmingsTVUI` | TV platform adapters around the mobile flow | `LemmingsTVCore`, `LemmingsMobileUI`, `LemmingsMobileCore`, `LemmingsGameArt`, `LemmingsAudio`, `NxlvKit` |

Keep simulation rules in `NxlvKit`. Shared services do not belong in a shell
merely because the Mac implemented them first. Platform event recognition and
view lifecycle remain in the corresponding shell or UI module. Consult
`Package.swift` before introducing a dependency back toward a shell.

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
| Audio and media | Model and decoding logic for supported source formats; playback lives in `LemmingsAudio` and platform adapters |

An engine decides its own rules. A recognised file format does not select an
engine by itself. The content catalogue and import boundary must record both
the format and the source engine family.

### `Sources/LemmingsLocal`

`LemmingsLocal` is the macOS front end. It owns AppKit, GameController,
AVFoundation, Metal, QuartzCore, menus, windows, input routing, audio output,
save locations, bundled-resource discovery, Game Center integration and the
unified game library. It uses `LemmingsAppCore`, `LemmingsAudio` and
`LemmingsGameArt` for shared services, playback and presentation. It adapts those
services to `NxlvKit` rather than placing them in shared engine code.

The application presents content according to the release gate. Complete
content is normal library content. Playable content states its limits. Preview
and beta content are labelled. Unverified content is not shown in the normal
library; it remains available only through an explicit import or developer
path. See [the content roadmap](Documentation/ContentUniverseRoadmap.md).

### `Sources/LemmingsMobileCore`

`LemmingsMobileCore` is the platform-neutral boundary for the iPhone and iPad
shell. It owns geometry, safe-area layout decisions, viewport transforms,
stable touch targeting, input routing, lifecycle state, fixed-tick clocks,
thermal presentation budgets, versioned checkpoints and typed engine sessions.
It does not import UIKit, Metal or AVFoundation.

For 2.0, keep gameplay actions behind one typed input contract. The UIKit
adapters detect touch, Apple Pencil, pointer, keyboard and accessibility input;
the core resolves target selection and eligibility; each source then invokes
the same gameplay action. Add Game Controller routing at the platform boundary.
Input-source details must not change engine rules or deterministic tick order.

Classic, Lemmings 2 and Lemmings 3 sessions implement the same contract. The
Classic session includes the current player-facing pixel renderer. The 2.0
source connects L2 and L3 libraries, native scene renderers, campaign records
and checkpoint routes to the mobile session flow. Supported NeoLemmix packs use
the same flow with native style rendering and validated simulation features.
Real-data fidelity and device acceptance remain separate release gates.

### `Sources/LemmingsMobileUI` and `Apps/UltimateLemmingsIOS`

`LemmingsMobileUI` owns UIKit, MetalKit, AVFAudio, the system document picker,
application support paths and mobile view-controller flow. It converts typed
mobile-core state into pixel controls and a nearest-neighbour Metal playfield.
It must not own engine rules. Its 2.0 input adapters translate UIKit and Game
Controller events to the shared mobile-core input contract. Platform event
recognition stays here; target preference, eligibility and action semantics stay
in `LemmingsMobileCore`.

`Apps/UltimateLemmingsIOS` is the thin iOS executable, metadata, asset catalogue
and UI-test target. Version 1.3 imports a player-owned Classic DOS folder into a
staged application-support location. The 2.0 source adds separate import paths
for L2, L3 and supported NeoLemmix data. Each import validates the staged copy
before replacing installed data and restores the prior copy on failure.

### Localisation

Localisation is shared presentation infrastructure in `NxlvKit`. Classic,
Lemmings 2 and Lemmings 3 use it through the Mac and shared iOS/tvOS front ends.
The normal TV app reuses the mobile application flow. Its separate development
shell also needs translated captions. See the
[TV parity contract](Apps/UltimateLemmingsTV/IOSParity.md) before changing either.

```text
Swift L10n.text / L10n.plural calls + original L2 text inventory
                         |
             Tools/Localisation/catalogue.py
                         |
         English tables + source-reference catalogue
                         |
       staged locale JSON + plural JSON + language review
                         |
     coverage / grammar / fonts / rendered flows / platform checks
                         |
       approved .lproj tables in Localization.bundle
                         |
       InterfaceLocalisation -> bitmap layout and accessibility
```

| Owner | Contract |
| --- | --- |
| `Sources/NxlvKit/InterfaceLocalisation.swift` | Language matching, English fallback, complete-message interpolation, native plurals and test text expansion. Resolve captions before layout. |
| `SkillVocabulary`, `DifficultyTechniques`, `LearningJourney` | Translate display names while retaining canonical engine, shortcut and saved-journey identities. |
| `BitmapLatinGlyphs`, `BitmapTamilGlyphs`, `SequelBitmapFont`, shared bitmap renderers | Preserve original Latin pixels and advances. Measure complete Tamil sequences, variable widths and mark overhang. Keep full Unicode accessibility text. |
| `Tools/Localisation/catalogue.py` and `extract.swift` | Parse Swift syntax, collect message keys, generate English tables and source references, reject known technical-data mistakes. The scan does not prove coverage of computed captions. |
| `Tools/Localisation/l2-original-text.json` | Explicit inventory of translatable text from original L2 banks. Binary-file references use line 1 as a locator, not a Swift source line. |
| `Tools/Localisation/drafts/` | Staged translations, plural forms and per-locale review checkpoints. These files are not runtime resources. |
| `Tools/Localisation/captions.tsv` | Shared action and skill vocabulary for seven locales. Neither the runtime nor validator applies it automatically. |
| `Tools/Localisation/validate.py` | Structural completeness, placeholder, count-format and unchanged-English checks. Its `complete` field does not certify linguistic or device acceptance. |
| `Sources/NxlvKit/Resources/Localization.bundle` | Runtime translation tables, candidate packs and bundled font pixels with their notices. SwiftPM, Mac packaging and the iOS/tvOS asset packager copy this bundle. Installed locales appear in the in-app language selector. |

`InterfaceMessage` separates numbered `{0}` arguments from the English message
key. Translations can reorder arguments without interpreting player data as a
second template. Count-dependent messages use `.stringsdict`, with `%ld` and
Apple's plural categories. Blank or damaged text falls back to English.
That fallback is a runtime safeguard, not evidence that a pack is complete.

Eight translation locales share the English message catalogue and eight
plural keys. The seven existing AI packs remain drafts. The complete
Tamil candidate pack is installed for in-app testing. Human linguistic, accessibility and
device acceptance remain separate gates.

Language selection lives under **Settings > Gameplay**. Settings previews the
selected language through the shared resolver immediately. **Back** cancels
the preview and restores the previous language. **Apply** persists the choice.
**System default** follows the device language. Preview state and persisted
preferences remain separate so cancelled changes do not replace the saved choice.

`BitmapTamilGlyphs` loads 399 complete forms and the SA-based shrii alias from
`Localization.bundle/Fonts/TamilPixelFont.json`. Three source body heights feed
shared and native Classic/L2/L3 rendering. NFC and longest-sequence matching
keep conjuncts intact through measurement, wrapping and truncation. Frames retain
negative bearings and marks, align with source baselines and use bounded caches.
Sequel conversion retains each bank's shade indices. Runtime drawing uses packed
pixels and needs no Core Text or installed font. The Noto/OFL and Unicode notices
travel beside the resource. Rebuild and export remain developer tooling in
`Tools/TamilPixelFont`.

Keep action IDs, keyboard bindings, artwork lookup tables, paths, HTTP headers,
MIME types and JavaScript outside translation. Translate only their interface
captions. Keyboard help uses structured key/action/category rows. Never recover
command identity by parsing translated prose. The TV transfer page escapes
translated HTML captions and quotes JavaScript messages separately from code.

Original L2 bank text passes through `L10n.originalL2Text`. Its current inventory
contains line fragments, so sentence grouping, credit-name protection and script
layout still need review. Baked-in artwork is a separate content task. Do not
infer that translating the string catalogue translates every original picture.

Translation models, Python packages, downloaded weights and candidate output
are optional developer tools under `.build/`. They are not app dependencies and
do not establish language quality. The maintained workflow, current checkpoint,
known defects and exact validation commands belong in
[Interface localisation](Documentation/Localisation.md#translation-handover).

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

`Package.swift` defines `NxlvKit`, the mobile core and UI libraries, the native
macOS executables and package test targets. `Scripts/build-local-app.sh` builds
universal arm64/x86_64 Mac bundles and embeds the supplied local game data. It
targets macOS 12.3 or later.

The macOS app keeps aggregate play counts locally. With consent and a configured
HTTPS address, it sends fixed-schema count events to the optional collector in
`Tools/Telemetry/`. The collector stores daily totals and one lifetime rescued
total. The home screen reads that shared total without an owner token; the
in-app dashboard needs a token for detailed counts. See
[`Documentation/PlayInsights.md`](Documentation/PlayInsights.md) for the data
boundary, deployment requirements and count limits.

`Apps/UltimateLemmingsIOS/UltimateLemmingsIOS.xcodeproj` builds the iOS 16
application. `Scripts/check-1.3-mobile.sh` validates the metadata and source,
runs focused mobile tests and builds against the iOS Simulator SDK. The iOS app
supports importing commercial data at runtime. The beta packaging tools can
also include configured local game data. Source-only gates do not establish
content rights or certify a signed beta bundle. See the
[mobile content boundary](Documentation/2.0Roadmap.md).

The release path is deliberately separate from the local build:

1. `Scripts/build-and-notarise.sh` checks that source changed since the chosen
   previous release commit.
2. It requires tracked, reviewed notes for the exact build. It stamps the
   frozen commit into the packaged copy.
3. It builds and signs the standard and Monterey reference targets.
4. It builds the development-signed Game Center target as a separate archive.
5. It notarises the two distributable Developer ID archives and verifies them
   with Gatekeeper tooling.
6. It writes all three timestamped ZIP files to the configured Downloads
   directory.
7. It writes a separate Sparkle update ZIP containing only the notarised
   standard app and regenerates the signed `appcast.xml`.
8. Publication is a separate, reviewed step through
   `Scripts/publish-github-release.sh`. The packaging script rejects
   `PUBLISH_GITHUB_RELEASE=1`.

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
| How does a receiving developer evaluate and maintain it? | [`Documentation/DeveloperHandover.md`](Documentation/DeveloperHandover.md) |
| Which assets, accounts and ownership questions need a transfer decision? | [`Documentation/HandoverDependencies.md`](Documentation/HandoverDependencies.md) |
| How is the code and release system shaped? | `ARCHITECTURE.md` |
| How do I complete, review and enable a translation pack? | [`Documentation/Localisation.md`](Documentation/Localisation.md#translation-handover) and the per-locale review checkpoints |
| What does a player see today? | [`Documentation/Overview.md`](Documentation/Overview.md) |
| What does Complete, Playable or Preview mean? | [`Documentation/ReleaseScope.md`](Documentation/ReleaseScope.md) |
| Where are current and historical release notes? | [`Documentation/ReleaseNotes.md`](Documentation/ReleaseNotes.md) |
| What is in the iPhone/iPad milestone? | [`Documentation/2.0Roadmap.md`](Documentation/2.0Roadmap.md) |
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

The iOS shell now uses a tested engine contract. Future Windows and Linux
shells, and further mobile engine work, should reuse deterministic simulation,
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
