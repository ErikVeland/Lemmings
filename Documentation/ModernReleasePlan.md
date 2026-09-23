# Modern Lemmings release plan

Updated 11 September 2026. This is the current engineering plan, not an announcement of an official release.

The objective is an official-quality edition that preserves the original puzzles and makes them comfortable to play on modern devices. The strongest route is to finish and prove the Mac reference build, bring the same rules and replay fixtures to iPhone and iPad, then reach Windows and Linux. Consoles are not a current target; see the platform plan below.

## What exists

| Area | Current implementation | Evidence and limits |
| --- | --- | --- |
| Original Lemmings | All 120 levels, replayable solutions, rewind, achievements and rescue records | Strict winning-replay gate, including rejection of invalid evidence. Original-engine equivalence is a separate claim. |
| Other classic campaigns | Oh No!, Xmas and Holiday campaigns in the unified library | 103 preserved winning routes: Oh No! 66/100, Xmas 1991 4/4, Xmas 1992 3/4, Holiday 1993 14/32, Holiday 1994 16/32. Load/render coverage is broader than solution coverage. |
| Lemmings 2 | Twelve tribes, native skills, original interfaces, music and campaign progression | Native beta. Existing runtime tests cover 64 standalone level completions. Remaining routes, carry-over campaigns and fidelity comparisons need evidence. |
| Lemmings 3 | Three tribes, tools, reserves, original music, voices and movie gallery | Native preview. 16/90 preserved winning routes. Several mechanics and original-media transitions remain provisional. |
| Modern play | HD explosions, directional speed ghosts, smooth 2/3/5/10× speed, hold/release and rapid exits | Shared clocks preserve whole simulation ticks. Effects, keyboard routing and recorded presentation have separate checks. |
| Mouse and controller | Multiscreen pointer capture, gamepad skill/focus controls, hints, settings, retry and supported rewind/step | Automated button input is covered. Physical device models, remapping and complete controller-only journeys remain to be tested. |
| Novice help | Three hint tiers for all 120 original levels, matched to verified routes | Other campaigns receive labelled general coaching. These are not claimed as level-specific solutions. |
| Preferences | Modern defaults, first-launch choice, OG reset and individual settings | Saves and explicit opt-outs persist. Independent added-motion and added-flash reductions preserve modern gameplay. Broader accessibility validation remains open. |
| Progress and replay | Local profiles, records, achievements, replay review and movie export | In-progress crash recovery and cross-device save conflicts remain open. Game Center needs provisioned service testing. |

Campaign counts come from the committed [campaign evidence](CampaignCompletion/evidence.json), [original completion gate](ClassicCompletion/README.md) and sequel tests. Archived beta reports do not certify the current effects, input or 1.1 build.

## Gaps closed in this audit

- Classic and L3 now pause when their window or app loses focus. L2 uses the same preference. Returning to the game requires an explicit resume.
- Disconnecting a controller that has been used pauses play. An idle, unused controller does not interrupt a keyboard player. Speed holds are cleared.
- Closing hints, controls help or a replay cannot undo a pause caused by an interruption while the page was open.
- **Settings → Gameplay → Pause** controls this behaviour. It defaults on, persists, and follows modern/OG presets. Machine artwork and audio presets preserve it.
- Controller navigation skips disabled entries in settings lists in both directions.
- The default app integration suite now includes the recent controller, variable-speed, hint and interruption checks.

## Release gates

[gates.json](ReleaseReadiness/gates.json) is the checklist with priorities, current status and concrete exit criteria. A passing regression suite does not close untested gates.

The next Mac milestone is a reproducible evaluation build with these requirements:

1. All current regression checks pass against a recorded source and fixture manifest.
2. Every campaign advertised as complete has a winning route for every level and verified progression. Continue to label incomplete sequel support accurately.
3. Novice players can start, select skills, pause, request a nudge, retry and finish using each supported input device.
4. Focus loss, disconnected controllers, audio interruptions, sleep, failed saves and restored sessions cannot silently lose a run.
5. Run an extended hardware matrix: physical Intel, the minimum macOS version, current Apple Silicon, multiple screens, SDR/HDR, 60/120 Hz, Bluetooth/USB controllers and repeated engine switching.
6. Measure full-frame p50/p95/p99 timings, input latency, memory growth, audio underruns and thermal behaviour. Include 10× crowds, mass nukes, replay export and long sessions. Sprite-only benchmarks are insufficient.
7. Validate the independent added-motion and added-flash controls. Add scalable text, accessible menu navigation and device-appropriate button prompts. Preserve modern gameplay controls when presentation effects are reduced.
8. Freeze, sign, notarise and verify the actual candidate archive. Confirm save upgrades using installed earlier releases. Preserve a rollback package.

Additional product work includes input remapping, left-handed touch layouts, localisation, offline/service failure handling, profile switching, checkpoint schema migration, privacy review and crash diagnostics with a clear consent model. These are recorded as delivery work, not implied by the current Mac feature set.

## Platform plan

| Platform | Starting point | Next demonstrable result |
| --- | --- | --- |
| macOS | Running AppKit/Metal app, universal arm64/x86_64 binaries targeting macOS 13 | Signed reference candidate with hardware and novice-play evidence. |
| iPhone/iPad | `NxlvKit` declares iOS 16 support and has no AppKit imports. It still uses Apple graphics, image and hashing frameworks. There is no iOS app target. | Compile the library with the iOS SDK, then a playable UIKit/Metal shell that runs the same replay fixtures. Validate direct touch, precise crowd selection, zoom/pan, safe areas and app suspension on devices. |
| Windows/Linux | `Package.swift` declares only macOS and iOS. `NxlvKit` imports CoreGraphics, ImageIO and CryptoKit, all Apple-only. There is no Windows or Linux target. | Replace the Apple-only graphics, image and hashing dependencies with portable equivalents, then build a non-AppKit interface that runs the same replay fixtures. |

Consoles (Switch, PlayStation, Xbox) are not a current target. This repository has no console target, no approved SDK integration and no relationship with a console platform owner. Revisit this only after a decision to pursue it.

Do not rewrite the simulation before proving a need. Keep simulation ticks, replay commands, deterministic outcomes and data formats as the reference contract. Extract rendering, input, audio, files, clocks and account services behind platform adapters when implementing each shell. A portable data model does not imply that this Swift executable runs on every platform.

The current workstation has Command Line Tools but no usable iOS SDK. No iOS compilation or device result is claimed. Install and select a full Xcode toolchain before the first iOS build. Apple documents [virtual controls for controller-based iOS games](https://developer.apple.com/documentation/gamecontroller/adding-virtual-controls-to-games-that-support-game-controllers-in-ios); touch precision for this game still needs its own design and tests.

## Repeatable verification

Run from the repository:

```sh
python3 Tools/ReleaseReadiness/audit.py --app
```

The audit creates a new directory under `.build/release-audit`, compiles the shared library from copied sources, runs 28 engine/data suites, verifies original, additional classic-family and L3 campaign routes, and checks controller, variable-speed, pointer and HDR behaviour. `--app` also runs the full app and sequel view suites. Runs preserve logs, source, fixture and asset hashes, JSON results and a readable report. Hashes include the resource bundle used by app tests. Source changes during a run are reported as drift and cause failure. Failed checks never become passes through a cached result.

Without `--app`, the app suites are explicitly **not run**. This is useful during engine work but is not a complete application check. `--require-closure` also fails because hardware, publishing and other platform gates remain open. The tool deliberately does not issue a release-ready certificate.

The September 11 hardening results are recorded in [the handoff](ReleaseReadiness/2026-09-11.md). Keep those results distinct from future builds.

## Partner evaluation

Prepare the [evaluation brief](PartnerEvaluation.md) with an approved demonstration build. The pitch is preservation plus usability, backed by repeatable evidence. A rights holder should be able to inspect the feature set, original behaviour, source and asset provenance, platform plan and unresolved work without relying on marketing claims.

Agree the official product scope and asset distribution with the rights holder before a public release. Keep the original asset inventory and third-party notices separate from claims about the port's own code. No outreach, store submission or public publishing is part of this audit.
