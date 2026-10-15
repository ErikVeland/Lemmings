# Release scope

Classic 1.0 is the historical macOS release baseline, confirmed on 13 September 2026.
The README lists 1.9.7 build 82 as the current public Mac release. The latest
tracked distribution record in this checkout is 1.9.6 build 81. The 1.9.7
publication record is not present here, so this document does not claim that
build 82 passed the distribution gates.

The owner set a stricter bundled-content closure rule on 15 October 2026. Every
bundled level needs a verified winning replay, and every bundled engine needs
source-behaviour evidence for its advertised rules. See the [content roadmap](ContentUniverseRoadmap.md).

Automated evidence supports the recorded native routes. Original-engine
fidelity, high-survivor endings and hardware acceptance retain their recorded
limits. See the [gate register](ReleaseReadiness/gates.json).

## Bundled content closure

On 15 October 2026, the owner set a stricter rule for bundled content. The
release must freeze an exact content manifest. Every included level must load,
render, run and have a verified winning replay. Each engine must also pass
source-behaviour comparisons for its advertised rules. Campaign transitions,
endings, media, saves and recovery must pass when the bundle exposes them.
Imported content remains open-ended and uses per-engine, per-version support
claims. See the [content roadmap](ContentUniverseRoadmap.md).

| Bundled set | Current evidence | Open closure work |
| --- | --- | --- |
| Official Classic and Oh Yes! | 352/352 winning routes. | Tie the frozen bundle manifest to the source-engine evidence for each included variant. |
| Classic fan packs | The 15 October audit freezes 6,020 levels in 535 packs. All 535 archive hashes match the retained 1.9.7 build 82 resource manifest. Current native audit: 2,399 winning routes, 3,600 levels without a matching candidate and 21 candidate or historical replay failures. The two extra October CSV entries are imported `fan:lldb-595` levels outside the bundle. | Resolve the 3,621 route gaps, close source-behaviour checks for bundled content, then freeze and verify the final release manifest. |
| Lemmings 2 | 120/120 routes, 70 carry-over variants and twelve full chains pass. A new Cavelems sequence saves 59, 36, 17, 4, 2, 2, 1, 1, 1 and 1. All tribes end with one survivor and a Bronze talisman. | Raise each chain to 30 final survivors, verify the golden talisman ending and close source-engine comparisons. |
| Lemmings 3 | Strict current audit: 394/416 fixtures double-replay. Four standalone outcomes and 18 carried identities fail. Five Shadow 13 inputs still win when rebased; 13 carried schedules do not. Source evidence has 673 repeatable samples for left-facing burrowing and a fall into an open gap. An isolated prototype matches 53 sampled positions, but four terrain-edge samples contradict its rectangular carve. | Recover four standalone routes and 13 carried schedules; refresh five winnable Shadow 13 fixture identities, then rerun the full 90-route and campaign gates. Verify the exact excavation mask, built-brick trigger and remaining source rules. Close environmental effects, movie audio, story transitions, recovery and release checks. |
| NeoLemmix CE | The pinned runnable gate passed 794 levels. The bundle lists 788 levels, but 75 lack bundled community styles. Exact-version winning replay evidence covers 158 levels. | Freeze a supported bundle manifest. Supply licensed styles or remove dependent levels, then prove a winning route for every included level and source behaviour for each advertised feature. |

The table tracks engine and content closure. It does not certify a specific
app archive. Release packaging, platform acceptance and distribution need their
own records.

The October CSV is a discovered-content inventory, not the bundle manifest. Its
two `fan:lldb-595` levels (`LEVELPAK.DAT#0` and `LEVELPAK.DAT#1`) are imported
and outside the 535-pack bundle. The nine saved-count mismatches are stale
candidate replay records. Although the candidate archive labels matching
inputs as wins, those labels are not proof: the strict native audit found 21
candidate or historical replay witnesses that did not reproduce a win. The
September 344-witness count is historical. The current audit raises verified
bundled fan routes to 2,399 but does not close the remaining 3,621 levels.

The 1.9.4 build 79 macOS maintenance release is a historical record.
Its full updater, slim download and signed build-78 delta pass publication
checks. It softens golden effects, caches gameplay rendering, restores saved
Golden Path sessions, adds exact replay skill ticks and places identified
engine-quirk routes late in Expert. Current game classifications and limits
remain in force. See the
[1.9.4 distribution record](ReleaseReadiness/1.9.4Build79Distribution.md) and
[release notes](ReleaseNotes-1.9.4-build79.md).

The macOS 1.9.7 build 82 release consolidates the current shared controls,
performance, rewind audio, recovery and lettering improvements. Its universal
build and 53 release checks pass after the recorded repairs. Both public
packages are Developer ID signed, notarised and accepted by Gatekeeper. The
signed automatic-update feed and delta from build 81 are live and verified.
The owner explicitly approved the Apple and GitHub uploads on 15 October 2026.
Existing game classifications and the separate mobile/TV gates remain in force.
See the [release evidence](ReleaseReadiness/1.9.7-build82/README.md) and
[1.9.7 notes](ReleaseNotes-1.9.7-build82.md).

## macOS 2.0 preparation

For Macintosh 2.0 build 83, the owner approved using the existing release
classifications and documenting limits on 15 October 2026. This supersedes
the stricter bundled-content closure prerequisite for this release only.
Classic and The Tribes retain Complete. Chronicles and NeoLemmix remain Beta.
The six deferred milestone areas retain their recorded open or partial status.
Fresh candidate regressions, universal packaging and distribution verification
remain required. See the [acceptance record](ReleaseReadiness/2.0-build83/acceptance.json)
and [candidate evidence](ReleaseReadiness/2.0-build83/README.md).

The owner requested macOS 2.0 journey checkpoint resume and campaign/bundle
release readiness on 15 October 2026. Mac release acceptance is separate from
the iOS launch gates. The new `macos-2.0` audit and packaging scope requires
the relevant Mac P0 gates, including bundled engine and content closure.
It requires all official Classic and conversion routes, bundled fan winning
routes, strict L3 standalone and carried campaigns, and L2 ark prerequisites.
NeoLemmix dependencies, exact-version routes, source-engine fidelity and ending
playback remain part of the open bundle gate.

The retained full 1.9.7 resource bundle provides a hashed content baseline, not
an application candidate for 2.0. All 535 fan archive hashes match the 15 October
bundle audit. This inventory match does not close the 3,621 fan route gaps.
See [Mac preparation evidence](ReleaseReadiness/MacOS2Preparation-2026-10-15/README.md).
Keep version/build changes, source freeze, final candidate checks, universal
packaging, signing, notarisation, downloaded update and save migration tied to
the eventual 2.0 candidate.

## iOS 2.0 launch scope

On 10 October 2026, the owner confirmed a full iOS release for iPad, iPhone and
iPhone Duo, including Classic, Lemmings 2 and Lemmings 3. The source connects
all three engines and supported NeoLemmix imports to mobile sessions. The signed
build 12 remains Classic-only. A three-game candidate still needs native
rendering, content, campaign, recovery, audio, controller, shared QoL and Hot
Seat checks. Duo support is a launch gate, including folded and resized play.

Keep the current game-completion claims and remaining fidelity limits.
Mobile acceptance does not turn L3 Beta into Complete. Freeze distribution
inputs and prove the signed iOS package separately from Mac release evidence.
See the [2.0 roadmap](2.0Roadmap.md) and [gate register](ReleaseReadiness/gates.json).

## Wording

Three words carry the claims, and they mean different things.

**Complete.** Every level has a preserved winning replay that the native engine
reproduces. The gate fails if a replay is missing, altered, or stops winning.

**Playable.** Every level loads, renders and runs. Some levels have a preserved
winning replay and some do not. A level without one is not a broken level. It is
a level nobody has recorded a win for yet.

**Beta.** The game is available for broader testing, with remaining compatibility,
campaign and fidelity checks stated. Beta does not claim a winning route for
every level.

**Preview.** The game runs and is enjoyable, and its rules are not yet proven
against the original engine. Expect differences.

## Release replay policy

Winning replays and their solvability and difficulty evidence are durable
release evidence. A routine minor release keeps this evidence and does not
replay every level again. It checks the stored fixture manifests and runs the
focused engine regression suites.

Run the full campaign replay gates when a change can alter outcomes across a
campaign. This includes changes to simulation ticks, movement or collision,
terrain or skill rules, replay decoding or execution, level data, or a broad
engine rewrite. Re-run affected routes for local engine changes that do not
meet this threshold. Do not replace a winning route or recalculate a difficulty
score unless the route no longer wins or a full campaign change requires a new
baseline.

The minor audit proves that preserved fixture files match their recorded
hashes. It does not prove that every route still wins on the new engine. The
full audit provides that proof. Record the chosen scope and any affected-route
checks with the release evidence.

## macOS 1.5 public scope

The 1.5 release targets Intel and Apple silicon Macs running macOS 12.3 or
later. The completed 352-level Classic campaign is the primary release claim.
Lemmings 2 and Lemmings 3 remain Preview. NeoLemmix import remains Beta or
Preview until the real-pack, runnable, replay and behaviour gates pass.

The 1.5 crash, startup, input and gameplay-cursor fixes are release changes.
See the [1.5 distribution record](ReleaseReadiness/1.5Build50Distribution.md).
The 1.6 candidate needs signing, notarisation, Gatekeeper and live-update
evidence for its final commit. See the [1.6 validation record](ReleaseReadiness/1.6LocalValidation.md).

## Classic

| Release | Levels | Proven routes | Claim |
| --- | ---: | ---: | --- |
| Lemmings | 120 | 120 | **Complete** |
| Xmas Lemmings 1991 | 4 | 4 | **Complete** |
| Oh No! More Lemmings | 100 | 100 | **Complete** |
| Holiday Lemmings 1994 | 32 | 32 | **Complete** |
| Holiday Lemmings 1993 | 32 | 32 | **Complete** |
| Xmas Lemmings 1992 | 4 | 4 | **Complete** |
| **Official Classic total** | **292** | **292** | **Complete** |
| Oh Yes! conversions | 60 | 60 | **Complete** |
| **Classic release total** | **352** | **352** | **Complete** |

The original campaign is the claim that matters most, and it is complete. All 120
levels replay to a win, 103 of them rescuing every lemming. The engine also
applies the original steel-probe rules, so destructive skills behave as the
original does rather than as an approximation.

The official-only quest passes all 292 wins through the app session, with 876
saved-run restores, 292 progress resumes and the final quest result. Run
`zsh Scripts/verify-official-classic.sh` to reproduce it. This isolates the six
official Classic releases; it does not certify the full installed library.

Oh Yes! More Lemmings contains 60 port-exclusive conversions: Amiga versus
levels and Mega Drive Sunsoft levels. These are separate from the 292 official
DOS campaign levels. All 60 now have strictly verified winning evidence.

## Fan levels and conversions

The 22 September record covers 6,020 retained bundled fan levels, with load and
render evidence and 344 winning witnesses. This met the earlier community
content rule. The current native audit verifies 2,399 bundled fan routes and
does not meet the closure rule adopted on 15 October. The October audit
artifact discovers two additional imported levels outside the bundle and has
nine stale saved-count mismatches. The native audit reports 3,600 bundled
levels without a winning route and 21 failed replay witnesses. Freeze and hash
the exact bundle inventory, then close every bundled level route and
source-behaviour gap. See [current Classic validation](ReleaseReadiness/ClassicValidation-current.md)
and the [October audit](../Artifacts/ClassicProgression/README.md). The
[15 October bundle audit record](ReleaseReadiness/ClassicFanBundleAudit-2026-10-15.json)
captures every audited archive hash and its route totals.
The current audit accepts `--require-fan-routes`; use it for bundled closure so
the report fails when any bundled fan level lacks a winning replay. The
default mode retains the historical load-and-render community check.
The expanded Classic quest passes all 352 levels, including conversions, through
the app session and recovery code. It checks 1,056 run restores, 352 progress
resumes, six release transitions and the final quest result. Reproduce it with
`zsh Scripts/verify-official-classic.sh --include-conversions`.
See [combined quest evidence](ReleaseReadiness/ClassicConversionQuest.json).

The removed records are listed in [the pruning manifest](FanLevelPruning.json).
Surviving DAT slots retain their original identities for saved attempts.
See [the current campaign closure evidence](ReleaseReadiness/CampaignClosure-2026-09-22.md) for the retained baseline.

## Sequels

| Release | Levels | Current route evidence | 1.9 claim |
| --- | ---: | ---: | --- |
| Lemmings 2: The Tribes | 120 | 120/120 pass, 70 carry-over variants and 12 full chains pass | **Complete** |
| Lemmings 3: The Chronicles | 90 | 90 retained fixtures from the prior engine state, current strict replay fails at Shadow 7 | **Beta (route gate open)** |

The strict native L2 gate passes all 120 standalone routes, 70 carry-over variants
and twelve continuous tribe chains. Every witness reproduces its win twice with
matching saved counts, ticks and state hashes. These chains finish with one
lemming. The ark ending requires a golden talisman and at least 30 survivors
from each tribe, and remains unproved.
See [L2 completion evidence](Lemmings2Completion/README.md).

The 13 October strict native L3 evidence records 90 of 90 standalone wins, 326
carried fixtures replayed twice and all 90 linked campaign results. Classic,
Shadow and Egyptian each finish with 50 survivors on that engine state. The 15
October Mole direction and patrol corrections invalidate route witnesses. The
current strict rerun stops at Shadow 7. Route repair, original DOS parity,
media, release-candidate recovery and package validation remain open. See the
[campaign evidence](CampaignCompletion/README.md) and
[sequel verification record](ReleaseReadiness/1.8SequelVerification.md).

Both play through their campaigns with original artwork, music and interfaces.
Lemmings 3 keeps provisional rules in several areas, and its environmental
effects, movie soundtracks and story transitions are incomplete.

The owner approved these 1.9 release classifications on 10 October 2026. The
current native evidence has all 120 L2 routes. L2's twelve chains end with one
lemming, below the 30 needed per tribe for the golden-talisman ark ending. The
prior L3 engine state passed all 90 routes and finished each chain with 50
survivors. L3 route repair, source-engine fidelity, media and release checks
remain open. These results do not close the bundled-engine gate.

## Existing iOS source baseline

The repository contains an iOS 16 UIKit/Metal application target. Its current
prototype imports a player-owned Classic DOS folder. It uses the same
deterministic Classic simulation as the Mac application and adds direct touch,
pan, zoom, safe-area controls, interruption recovery and thermal presentation
budgets.

The 2.0 source connects Classic, L2, L3 and supported NeoLemmix imports to the
mobile library and session flow. The signed build 12 contains Classic only.
Real-data parity, full campaign runs, physical-device, accessibility, signing
and distribution gates remain open. See the [2.0 roadmap](2.0Roadmap.md) and
[release gate](ReleaseReadiness/2.0ReleaseGate-2026-10-14.md).

## Not in this release

The macOS 1.5 release does not include iPhone, iPad or consoles. Mobile 2.0 is a
separate release gate. Consoles have no application target. A Mac
release does not imply support for either platform group.

## Retained validation limits

- The `Oh My! ALL Lemmings!` run across the sequel campaigns remains outside the
  completed 352-level Classic campaign gate.
- L2 is Complete and L3 is Beta for 1.9. L2's strict route and chain gates
  pass, but its ark ending remains open. L3 retains 90 old fixtures, but the
  current strict route gate fails at Shadow 7. L3 route repair, original-engine
  fidelity and release-candidate checks remain open.
- Physical Intel, minimum macOS, HDR, multiple displays and high refresh rates
  are untested. Sustained 10x play is not established.
- Scalable menus and VoiceOver navigation are implemented. Full VoiceOver
  listening journeys and physical controller journeys remain unverified.
- Game Center is newly testable and unproven against network loss and account
  changes.
- The owner confirmed asset-distribution approval on 15 September. The final
  1.0 candidate still needs its own source freeze, validation, signing and notarisation.

See [22 September campaign closure](ReleaseReadiness/CampaignClosure-2026-09-22.md)
for the recovered routes and current validation limits.
