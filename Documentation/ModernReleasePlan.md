# Modern Lemmings release plan

Engineering snapshot: 5 October 2026. App Store content decision: 12 November
2026. This plan does not announce an official release.

The [release schedule](ReleaseSchedule.md), adopted 26 October 2026, supersedes
older delivery orders and routine Mac test requirements: Mac first, then iOS,
tvOS and sideloading stores. Ship Mac quickly and skip tests unless engines change.

Updated 19 October 2026. This plan records package evidence and the remaining platform and fidelity work.

Current source candidates, published feed versions and retained package evidence
are recorded in [release scope](ReleaseScope.md). Those records remain separate.
The mobile 2.0 milestone covers iPad, iPhone and iPhone Duo with the three native
games. The [2.1 delivery plan](2.1Roadmap.md#priorities-and-acceptance) now sets the
product priority: free basic magnification, independent original presentation and
modern conveniences, honest hints, newcomer teaching, quiet results, campaign
closure, accessibility and device acceptance. Optional character/review expansion
follows those foundations. The owner authorised the work on 19 October 2026.

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
| Novice help | Checked Classic hints, clearly separate general coaching and optional solution ghosts | Exact level and condition matching hides stale hints. Complete novice journeys across input devices remain separate acceptance work. |
| Preferences | Independent presentation and convenience choices, restrained defaults and individual settings | Saves and explicit opt-outs persist. Independent added-motion and added-flash reductions preserve modern gameplay. Broader accessibility validation remains open. |
| Progress and replay | Local profiles, records, achievements, replay review and movie export | Checkpoint recovery and merge scenarios have automated evidence. Live cross-device synchronisation, physical recovery journeys and provisioned Game Center remain separate acceptance checks. |

Current route counts and their exact source limits are recorded in [release scope](ReleaseScope.md), [campaign evidence](CampaignCompletion/evidence.json) and the [original completion gate](ClassicCompletion/README.md). Earlier beta reports do not certify the current candidate.

## Retained input and interruption behaviour

- Classic and L3 now pause when their window or app loses focus. L2 uses the same preference. Returning to the game requires an explicit resume.
- Disconnecting a controller that has been used pauses play. An idle, unused controller does not interrupt a keyboard player. Speed holds are cleared.
- Closing hints, controls help or a replay cannot undo a pause caused by an interruption while the page was open.
- **Settings → Gameplay → Pause** controls this behaviour. It defaults on and persists independently of presentation. Original presentation, machine artwork and audio presets preserve the player's interruption preference.
- Controller navigation skips disabled entries in settings lists in both directions.
- The default app integration suite now includes the recent controller, variable-speed, hint and interruption checks.

## Release gates

[gates.json](ReleaseReadiness/gates.json) is the checklist with priorities, current status and concrete exit criteria. A passing regression suite does not close untested gates.

Maintenance candidates follow the release schedule's engine-change test policy
and retain source identity and distribution evidence. The broader evaluation
milestone retains these requirements:

1. All current regression checks pass against a recorded source and fixture manifest.
2. Preserve winning routes and their solvability and difficulty evidence for every campaign advertised as complete. Use the [release replay policy](ReleaseScope.md#release-replay-policy) to choose between the minor audit and full campaign replay gates. Continue to label incomplete sequel support accurately.
3. Novice players can start, select skills, pause, request a nudge, retry and finish using each supported input device.
4. Focus loss, disconnected controllers, audio interruptions, sleep, failed saves and restored sessions cannot silently lose a run.
5. Run an extended hardware matrix: physical Intel, the minimum macOS version, current Apple Silicon, multiple screens, SDR/HDR, 60/120 Hz, Bluetooth/USB controllers and repeated engine switching.
6. Measure full-frame p50/p95/p99 timings, input latency, memory growth, audio underruns and thermal behaviour. Include 10× crowds, mass nukes, replay export and long sessions. Sprite-only benchmarks are insufficient.
7. Validate the independent added-motion and added-flash controls. Add scalable text, accessible menu navigation and device-appropriate button prompts. Preserve modern gameplay controls when presentation effects are reduced.
8. Freeze, sign, notarise and verify the actual candidate archive. Confirm save upgrades using installed earlier releases. Preserve a rollback package.

The source includes remapping, language preview, profile switching, checkpoint recovery and privacy consent. Remaining acceptance includes human language review, physical input, accessibility, service failures, migration and device journeys. Implementation alone does not close those checks.

## App Store content distribution

Decision recorded 12 November 2026. The release objective is both lawful
distribution and zero configuration. Existing reference archives, including
Archive.org downloads, remain feasible candidates for assessment. This decision
does not establish legal clearance or App Store acceptance.

Zero configuration means a fresh install reaches advertised gameplay without
manual file selection, folder selection, URL entry, browser visits, extra
accounts or extraction. One Download action that shows the size and asks for
consent is acceptable. A manual-import workflow can remain available, but cannot
satisfy this release objective.

### Candidate routes

| Route | Player journey | Required evidence |
| --- | --- | --- |
| Bundled original content | Install, then play. | A legal basis covering the store bundle and all included material. |
| Bundled open replacement content | Install, then play. | Verified asset terms, independent branding and cleared levels. See the [Lix preparation](AlternativeAssets.md). |
| Direct original-archive download | Install, choose Download, then play. The app fetches and imports the original archive. | A legal basis covering the exact source, retrieval and intended use, plus applicable source-service terms. |
| Original demo or freeware download | Install, choose Download, then play the cleared demo or freeware scope. | Original release terms or another reviewed legal basis covering the intended use. Demo or freeware labels alone do not establish this. |

The bundled open-content route now has a separate local
[Ultimate Lemmix candidate](UltimateLemmix.md), with character selection,
three original starter levels and an asset-free BYO helper. Its build and
resource evidence do not establish store acceptance. Original-archive download
routes remain candidates pending review.

A review can establish an
applicable licence, rights-holder permission, public-domain status or another
specific legal basis. Missing permission evidence is an unresolved question,
not a finding that an archive is unlawful. Public availability, prior research
use and player consent do not establish rights by themselves.

The locally retained sources identify the Archive.org items
[`XmasLemmings`](https://archive.org/details/XmasLemmings) and
[`Xmas_Lemmings`](https://archive.org/details/Xmas_Lemmings). These are source
locators, not clearance records. Exact Archive.org acquisition links for the
full Classic, Lemmings 2 and Lemmings 3 reference inputs remain unverified.

### Release conditions

1. Record each proposed pack's exact source item, file, version, download size,
   archive hash, installed-content hashes and compatible engine. Keep licence
   evidence and the legal review outcome with that record.
2. Review the intended retrieval, local copying, extraction, conversion and
   content use. Record any platform, territory, monetisation or demo limits.
   Check compositions, recordings and community contributions separately where
   required. Do not infer full-campaign rights from a demo release.
3. Clear the app name, icon, store media and bundled launch interface separately.
   Optional content downloads do not resolve rights in those materials.
4. Reuse typed content boundaries and staged installation with validation and
   rollback. Keep native engine updates in App Store builds. Original archive
   executables remain inert and are not executed by the native interpreter.
5. Reject changed or corrupt content. Do not silently switch to an unreviewed
   mirror. Verify cancellation, interruption, retry, low storage and host
   failure without losing installed content or saved progress.
6. Verify the complete fresh-install journey on each advertised platform and
   engine. State any first-download network requirement. Installed content must
   remain playable offline. An offline first launch must retain a clear retry
   action without requiring manual configuration.
7. Keep one primary next action, accessible download states and concise failure
   actions. Reuse the shipped pixel controls. Verify the rendered states and
   input targets before accepting the flow.
8. Give App Review access through the normal player journey to every advertised
   content route. Record rights review, technical verification and store
   acceptance separately. Each must pass before release.

Classic, Lemmings 2 and Lemmings 3 share the installation requirements when
advertised. Their engine and platform limits still apply. Shared mobile
contracts do not establish player-facing sequel support. The
[2.0 mobile gates](2.0Roadmap.md#external-acceptance-gates) remain required.

A Mac App Store edition needs a separate configuration with sandboxing and
App Store updates instead of Sparkle. Existing Developer ID notarisation does
not establish store acceptance. Explain the native interpreter and its content
download routes in the review notes.

These remain release conditions. The local store candidate implements bundled
open content and player-owned folder import. It does not download original game
data. No clearance decision, physical-device acceptance or store submission is
claimed by this plan update.
Use [Apple's App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
sections 2.4.5, 4.2.3(ii), 4.7 and 5.2, and the
[Internet Archive rights guidance](https://archivesupport.zendesk.com/hc/en-us/articles/360014759692-Rights)
as review inputs. Archive.org does not guarantee an item's copyright status.

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

Establish lawful product scope and asset distribution before a public release.
Record the basis under the [content-distribution conditions](#release-conditions).
Keep the original asset inventory and third-party notices separate from claims
about the port's own code. This plan update does not include outreach, store
submission or public publishing.
