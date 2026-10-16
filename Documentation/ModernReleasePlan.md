# Modern Lemmings release plan

Updated 16 October 2026. This plan records the published Mac release and the remaining platform and fidelity work.

The next platform milestone is a full 2.0 iOS release for iPad, iPhone and
iPhone Duo, with Classic, Lemmings 2 and Lemmings 3 at launch. Macintosh
2.0.3 build 86 is public, with the language-picker fix and repository maintenance.
The earlier 1.3 mobile work remains historical development evidence. See [release scope](ReleaseScope.md) for current
release claims and the [2.0 roadmap](2.0Roadmap.md) for the delivery sequence.

The objective is an official-quality edition that preserves the original puzzles and makes them comfortable to play on modern devices. The strongest route is to finish and prove the Mac reference build, bring the same rules and replay fixtures to iPhone and iPad, then reach Windows and Linux. Consoles are not a current target; see the platform plan below.

## What exists

| Area | Current implementation | Evidence and limits |
| --- | --- | --- |
| Original Lemmings | All 120 levels, replayable solutions, rewind, achievements and rescue records | Strict winning-replay gate, including rejection of invalid evidence. Original-engine equivalence is a separate claim. |
| Other classic campaigns | Oh No!, Xmas and Holiday campaigns in the unified library | The combined official Classic and conversion gate passes all 352 routes and the full quest. Fan and imported levels retain separate route and source-fidelity limits. |
| Lemmings 2 | Twelve tribes, native skills, original interfaces, music and campaign progression | Published Complete classification. Checks cover 120 routes, 70 carry-over variants and twelve chains. The accepted chains end with one survivor and Bronze talismans. The golden ending and source fidelity remain open. |
| Lemmings 3 | Three tribes, tools, reserves, original music, voices and movie gallery | Published Beta classification. The current fixture audit passes 399 of 416 cases; four standalone outcomes and thirteen carried schedules remain open. Source fidelity and original-media acceptance remain separate. |
| Modern play | HD explosions, directional speed ghosts, smooth 2/3/5/10× speed, hold/release and rapid exits | Shared clocks preserve whole simulation ticks. Effects, keyboard routing and recorded presentation have separate checks. |
| Mouse and controller | Multiscreen pointer capture, gamepad skill/focus controls, hints, settings, retry and supported rewind/step | Automated button input is covered. Physical device models, remapping and complete controller-only journeys remain to be tested. |
| Novice help | Verified Classic hints, labelled coaching and optional solution ghosts | Exact level and condition matching hides stale hints. Complete novice journeys across input devices remain separate acceptance work. |
| Preferences | Modern defaults, first-launch choice, OG reset and individual settings | Saves and explicit opt-outs persist. Independent added-motion and added-flash reductions preserve modern gameplay. Broader accessibility validation remains open. |
| Progress and replay | Local profiles, records, achievements, replay review and movie export | Checkpoint recovery and merge scenarios have automated evidence. Live cross-device synchronisation, physical recovery journeys and provisioned Game Center remain separate acceptance checks. |

Current route counts and their exact source limits are recorded in [release scope](ReleaseScope.md), [campaign evidence](CampaignCompletion/evidence.json) and the [original completion gate](ClassicCompletion/README.md). Earlier beta reports do not certify the current candidate.

## Retained input and interruption behaviour

- Classic and L3 now pause when their window or app loses focus. L2 uses the same preference. Returning to the game requires an explicit resume.
- Disconnecting a controller that has been used pauses play. An idle, unused controller does not interrupt a keyboard player. Speed holds are cleared.
- Closing hints, controls help or a replay cannot undo a pause caused by an interruption while the page was open.
- **Settings → Gameplay → Pause** controls this behaviour. It defaults on, persists, and follows modern/OG presets. Machine artwork and audio presets preserve it.
- Controller navigation skips disabled entries in settings lists in both directions.
- The default app integration suite now includes the recent controller, variable-speed, hint and interruption checks.

## Release gates

[gates.json](ReleaseReadiness/gates.json) is the checklist with priorities, current status and concrete exit criteria. A passing regression suite does not close untested gates.

Maintenance candidates need exact-source checks and distribution evidence. The broader evaluation milestone retains these requirements:

1. All current regression checks pass against a recorded source and fixture manifest.
2. Preserve winning routes and their solvability and difficulty evidence for every campaign advertised as complete. Use the [release replay policy](ReleaseScope.md#release-replay-policy) to choose between the minor audit and full campaign replay gates. Continue to label incomplete sequel support accurately.
3. Novice players can start, select skills, pause, request a nudge, retry and finish using each supported input device.
4. Focus loss, disconnected controllers, audio interruptions, sleep, failed saves and restored sessions cannot silently lose a run.
5. Run an extended hardware matrix: physical Intel, the minimum macOS version, current Apple Silicon, multiple screens, SDR/HDR, 60/120 Hz, Bluetooth/USB controllers and repeated engine switching.
6. Measure full-frame p50/p95/p99 timings, input latency, memory growth, audio underruns and thermal behaviour. Include 10× crowds, mass nukes, replay export and long sessions. Sprite-only benchmarks are insufficient.
7. Validate the independent added-motion and added-flash controls. Add scalable text, accessible menu navigation and device-appropriate button prompts. Preserve modern gameplay controls when presentation effects are reduced.
8. Freeze, sign, notarise and verify the actual candidate archive. Confirm save upgrades using installed earlier releases. Preserve a rollback package.

The source includes remapping, language preview, profile switching, checkpoint recovery and privacy consent. Remaining acceptance includes human language review, physical input, accessibility, service failures, migration and device journeys. Implementation alone does not close those checks.

## Platform plan

| Platform | Starting point | Next demonstrable result |
| --- | --- | --- |
| macOS | Running AppKit/Metal app with universal arm64/x86_64 binaries targeting macOS 12.3 | Signed reference candidate with hardware and novice-play evidence. |
| iPad/iPhone/iPhone Duo | The 2.0 UIKit/Metal source connects Classic, Lemmings 2, Lemmings 3 and supported NeoLemmix content. Shared core and presentation layers provide libraries, native scenes, progression and recovery. Real-data parity and physical-device acceptance remain open. | Complete real-data parity and verify audio, controller input, shared QoL and Hot Seat. Validate Duo poses, touch, recovery, thermal behaviour, accessibility, signing, TestFlight and App Store journeys. Preserve current completion claims and fidelity limits. See [2.0 roadmap](2.0Roadmap.md). |
| Apple TV | A separate 2.0 tvOS target reuses mobile sessions and bitmap menus, with TV input and console layouts. | Verify iOS parity, physical remote/controller input, native focus, VoiceOver, display performance and distribution. See the [TV parity record](../Apps/UltimateLemmingsTV/IOSParity.md). |
| Windows/Linux | The source depends on Apple graphics, image and cryptography frameworks. There is no Windows or Linux application target. | Replace the Apple-only graphics, image and hashing dependencies with portable equivalents, then build a non-AppKit interface that runs the same replay fixtures. |

Consoles (Switch, PlayStation, Xbox) are not a current target. This repository has no console target, no approved SDK integration and no relationship with a console platform owner. Revisit this only after a decision to pursue it.

Do not rewrite the simulation before proving a need. Keep simulation ticks, replay commands, deterministic outcomes and data formats as the reference contract. Extract rendering, input, audio, files, clocks and account services behind platform adapters when implementing each shell. A portable data model does not imply that this Swift executable runs on every platform.

Historical workstation and Simulator results remain tied to their recorded
commits. The [14 October mobile gate](ReleaseReadiness/2.0ReleaseGate-2026-10-14.md)
records Xcode 27.2 source and iPhone/iPad lifecycle results. SDK compilation does
not establish physical-device acceptance. See the
[2.0 verification record](2.0Roadmap.md#source-verification) for current limits.

## Repeatable verification

Run the routine minor-release audit from the repository:

```sh
python3 Tools/ReleaseReadiness/audit.py --app
```

This checks preserved solution fixture hashes and runs focused engine
regressions. It does not replay every campaign route. Run the full replay audit
after a change listed in the [release replay policy](ReleaseScope.md#release-replay-policy):

```sh
python3 Tools/ReleaseReadiness/audit.py --app --scope all
```

The audit creates a new directory under `.build/release-audit`, compiles the shared library from copied sources, runs engine and data suites, and checks controller, variable-speed, pointer and HDR behaviour. The default `minor` scope checks preserved route manifests without replaying every campaign route. The `all` scope also verifies every campaign route. `--app` runs the full app and sequel view suites. Runs preserve logs, source, fixture and asset hashes, JSON results and a readable report. Hashes include the resource bundle used by app tests. Source changes during a run are reported as drift and cause failure. Failed checks never become passes through a cached result.

Without `--app`, the app suites are explicitly **not run**. This is useful during engine work but is not a complete application check. `--require-closure` also fails because hardware, publishing and other platform gates remain open. The tool deliberately does not issue a release-ready certificate.

The September 11 hardening results remain dated evidence. Keep them distinct
from future builds and use [release scope](ReleaseScope.md) for current claims.

## Partner evaluation

Prepare the [evaluation brief](PartnerEvaluation.md) with an approved demonstration build. The pitch is preservation plus usability, backed by repeatable evidence. A rights holder should be able to inspect the feature set, original behaviour, source and asset provenance, platform plan and unresolved work without relying on marketing claims.

Agree the official product scope and asset distribution with the rights holder before a public release. Keep the original asset inventory and third-party notices separate from claims about the port's own code. No outreach, store submission or public publishing is part of this audit.
