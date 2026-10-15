# Release scope

Classic 1.0 is the historical macOS release baseline, confirmed on 13 September 2026.
The current public Macintosh release is 2.0.2 build 85. Its universal packages
are signed, notarised and accepted by Gatekeeper. The signed update feed and
build-84 delta are live and verified. See the [2.0.2 distribution evidence](ReleaseReadiness/2.0.2-build85/README.md).
This release retains the existing classifications and documented limits. The stricter bundled-content closure remains open.

The owner set a stricter bundled-content closure rule on 15 October 2026. Every
bundled level needs a verified winning replay, and every bundled engine needs
source-behaviour evidence for its advertised rules. See the [content roadmap](ContentUniverseRoadmap.md).

Automated evidence supports the recorded native routes. Original-engine
fidelity, high-survivor endings and hardware acceptance retain their recorded
limits. See the [gate register](ReleaseReadiness/gates.json).

Macintosh 2.0.2 retains the published classifications and known limits. Fresh native checks cover Hot Seat ghosts, retries, rewards, checkpoint recovery and records. The maintenance audit preserves campaign route manifests. Existing L2 chain and NeoLemmix inventory evidence remains in force. No stricter bundled-content or hardware gate is marked closed.

## Bundled content closure

On 15 October 2026, the owner set a stricter bundled-content closure target.
Full closure requires an exact content manifest, load/render/run evidence and a
verified winning replay for every included level. Each engine must also pass
source-behaviour comparisons for its advertised rules. Campaign transitions,
endings, media, saves and recovery must pass when the bundle exposes them.
Build 83 later deferred full closure as a release prerequisite while retaining
the recorded game classifications and limits. Imported content remains
open-ended and uses per-engine, per-version support claims. See the
[content roadmap](ContentUniverseRoadmap.md).

On 16 October, I compared the build 85 input manifest with the locally
installed 1.9.1 build 76 resource tree. All 1,307 `Ports`, 537 `LevelPacks`,
218 L2 and 561 L3 files match. The 4,010 NeoLemmix files have the same paths,
with two metadata files changed. This compares content hashes. It does not
verify the build 85 app binary. See the [build 85 content comparison](ReleaseReadiness/2.0.2-build85/bundled-content-equivalence-recheck-2026-10-16.json).

| Bundled set | Current evidence | Open closure work |
| --- | --- | --- |
| Official Classic and Oh Yes! | Current-source recheck passes all 352 routes and the full quest. The build 85 manifest has the same 1,307 `Ports` paths and hashes as the route-check baseline. Current main changed only `MobileHomeArt.swift` since build 85, so no Classic gameplay source changed. | Finish any remaining variant-specific source checks. The 2.0 build 83 candidate has verified resources and retained plus focused regression evidence. See the [build 85 content comparison](ReleaseReadiness/2.0.2-build85/bundled-content-equivalence-recheck-2026-10-16.json). |
| Classic fan packs | A full native audit replayed all 6,020 fan levels from the exact build 83 resources. Its package audit matched all 537 `LevelPacks` paths, sizes and hashes to the frozen input manifest. Build 85 has the same 537 paths and hashes, including all 535 fan archives. The route totals therefore apply to the public build 85 fan content. The audit found 2,399 winning routes, 3,600 levels without a matching candidate and 21 failed replay levels. It found no load, decode or render failures. Of 6,020 levels, 3,621 still lack a verified win. Both “Deep Deep Down” copies have verified fan routes. The two “It’s a Magical World” copies still lack winning routes. A 16 October current-engine continuation search used the retained route prefix through tick 880 on both exact archive identities. Each 300-second, beam-8,192 search found no win; a 300-second from-start search for the first copy also found no win after 709,892 expansions. These bounded searches do not prove either level impossible. See the [route repair record](ReleaseReadiness/2.0-build83/classic-fan-magical-world-route-repair-2026-10-16.json). Adaptive-rate searches and a partial timed Builder/Basher sweep found no win for “Only practice.” An earlier current-main beam-8,192 run covered actor IDs 0 through 3. Two later five-minute searches covered all 40 actors with balanced and progress-first rankings. They expanded 576,145 and 684,056 candidates and found no win. The level has no verified route. See the [current-main search record](ReleaseReadiness/2.0-build83/classic-fan-only-practice-search-2026-10-16.json). A targeted current-runtime search for “I Challenge You to a Duel!” also found no replacement route after 280,631 prefixed and 291,536 from-start expansions; its stored witness is refused at tick 943. See the [targeted repair record](ReleaseReadiness/2.0-build83/classic-fan-duel-route-repair-2026-10-16.json). Four additional 120-second current-main probes on Increasing step heights, The Arctic, Amazonian and Wait. I have a plan. found no winning route. A 300-second current-main continuation seeded with the source-derived Increasing step heights prefix expanded 598,444 candidates and found no win. These bounded searches do not prove that the levels are impossible. See the [route probe record](ReleaseReadiness/2.0-build83/classic-fan-route-probes-2026-10-16.json). Two October CSV entries are imported `fan:lldb-595` levels outside the bundle. | Verify the remaining bundled routes and source behaviour. Keep imported content open-ended under per-engine and per-version support claims. See the [build 83 replay audit](ReleaseReadiness/2.0-build83/classic-fan-build83-replay.json), [package audit](ReleaseReadiness/2.0-build83/classic-fan-package-audit.json), [build 85 manifest comparison](ReleaseReadiness/2.0.2-build85/bundled-content-equivalence-recheck-2026-10-16.json), [2.0 build83/15 October engine-equivalence snapshot](ReleaseReadiness/2.0-build83/engine-content-equivalence-current-main.json) and [“Only practice” search](ReleaseReadiness/2.0-build83/classic-fan-only-practice-search-2026-10-16.json). |
| Lemmings 2 | On 16 October, current-main replay passes all 120 routes, 70 carry-over variants, twelve chains, event checks and the runtime suite against the exact staged build 83 app payload. Its 218 files match the retained build 82 manifest and installed build 76 tree. The full archive extraction had 14 DOS interpreter/support files that the app packager excludes. A renderer-preserving source capture shows Beach 10 at 8:36, matching native tick 360 with 516 seconds remaining. Exact WALKER.DAT palette matches occur at two sampled positions predicted for native actor 11, at 8:36 and 8:34. These matches support local sprite-position parity only. The source frames contain no DOS tick or actor ID, and the comparison does not cover full Mac rendering or broader engine behaviour. See the [frame comparison](ReleaseReadiness/L2GameplayParity-2026-10-16/frame-comparison-001.json), [8:36 sample](ReleaseReadiness/L2GameplayParity-2026-10-16/source-renderer-run13-frame-2450.png) and [8:34 sample](ReleaseReadiness/L2GameplayParity-2026-10-16/source-renderer-run13-frame-2520.png). Every accepted chain ends with one survivor and a Bronze talisman. Candidate routes save 34/36 on Cavelems 3, 13/34 on Level 4 and 10/13 on Level 5. Searches found no Cavelems Level 6 route at population 10 or 13. The latest population-10 search used a beam of 8,192 and depth 80 for 300 seconds, and expanded 692,245 candidates without a win. Two unseeded Level 4 searches at population 34 reached beam 8,192; the 4-pixel grid expanded 1,014,578 candidates and the finer 2-pixel grid expanded 1,126,648, with neither finding a win. Three seeded Level 4 searches reproduced the existing 13-of-34 Bronze route byte for byte with 2-, 4- and 8-pixel grids. Other bounded searches reproduced the existing Level 5 and Classic 2 routes. The accepted chains remain unchanged. | Raise each chain to 30 final survivors, verify the golden talisman ending and close source-engine comparisons. See the [build 83 payload replay](ReleaseReadiness/2.0-build83/lemmings2-build83-payload-replay.json), [Cavelems reconnection search](Lemmings2Completion/cavelem-ark-reconnection-search-2026-10-16.json), [current-main follow-up](Lemmings2Completion/ark-reconnection-search-2026-10-16-current-main.json), [wider Level 4 search](Lemmings2Completion/cavelem04-beam8192-search-2026-10-16.json) and [seeded Level 4 search](Lemmings2Completion/cavelem04-seeded-beam8192-search-2026-10-16.json). |
| Lemmings 3 | Current audit: 399/416 fixtures double-replay. Five Shadow 13 carried identities are refreshed. Four standalone outcomes and 13 carried schedules still fail. On 16 October, current-source searches found no route for standalone Shadow 7 or Egyptian 6, 13 and 29. Source evidence has 673 repeatable samples for left-facing burrowing and a fall into an open gap. An isolated prototype matches 53 sampled positions, but four terrain-edge samples contradict its rectangular carve. | Recover four standalone routes and 13 carried schedules, then rerun the full 90-route and campaign gates. Verify the exact excavation mask, built-brick trigger and remaining source rules. Close environmental effects, movie audio, story transitions, recovery and release checks. See the [current-main search record](ReleaseReadiness/L3MoleVerification-2026-10-15/current-main-searches-2026-10-16.json) and [fixture audit](ReleaseReadiness/L3MoleVerification-2026-10-15/current-fixture-audit-provenance.json). |
| NeoLemmix CE | The 2.0.2 build85 bundled-resource check passes all 794 indexed levels and resolves all 719 levels supported by the 26 bundled DMA styles. The release staging script links the existing Xmas group into the Original parent index; build85's packaged index hash differs from the unchanged source index. The other 75 levels need 44 community styles. Exact-version winning replay evidence covers 158 levels. | Obtain distribution rights for the remaining styles, retain all 794 levels in closure scope, and verify every route and advertised source rule. See the [2.0.2 release evidence](ReleaseReadiness/2.0.2-build85/README.md), [build84 content inventory](ReleaseReadiness/2.0.1-build84/neo-content.json), [resource check](ReleaseReadiness/2.0.2-build85/raw-audit-logs/BundledGameResourcesTests.log) and [style rights inventory](ReleaseReadiness/2.0-build83/neolemmix-style-rights-inventory.json). |

The table tracks engine and content closure. It does not certify a specific
app archive. Release packaging, platform acceptance and distribution need their
own records.

The October CSV is a discovered-content inventory, not the bundle manifest. Its
two `fan:lldb-595` levels (`LEVELPAK.DAT#0` and `LEVELPAK.DAT#1`) are imported
and outside the 535-pack bundle. The nine saved-count mismatches are stale
candidate replay records. Although the candidate archive labels matching
inputs as wins, those labels are not proof: the strict native audit found 21
candidate or historical replay witnesses that did not reproduce a win. The
September 344-witness count is historical. The full current-source audit against the exact build 83 resources recorded
2,399 verified bundled fan routes, 3,600 levels without matching candidates
and 21 failed replay levels. It found no load, decode or render failures. Both
Deep Deep Down copies have verified fan wins. The two Magical World copies
remain without wins. The strict route gate remains open. The audit input manifest
has no drift. Package-level runtime verification is closed. Source-state parity
and the remaining routes stay open.

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
readiness on 15 October 2026. Build 83 shipped under the recorded acceptance
with existing classifications and documented limits. The `macos-2.0` scope
tracks the stricter bundled-content closure target after release. It remains
open until all bundled routes, source-engine checks, campaign transitions,
endings and dependencies pass. Imported content remains open-ended under
per-engine and per-version support claims. Mac distribution checks stay in
their separate release records.

The retained full 1.9.7 resource bundle provides a hashed content baseline.
The full current-source audit ran at `fc2c59e6` against the exact extracted
build 83 resources. It replayed all 6,020 fan levels and recorded 2,399 winning
routes, 3,600 levels without a matching candidate, 21 failed replay levels and
no load, decode or render failures. The strict route gate still has 3,621
levels without verified wins. A separate package audit confirms that all 537
`LevelPacks` inputs and all 535 fan archives match the frozen bundle hashes. See
the [package replay audit](ReleaseReadiness/2.0-build83/classic-fan-build83-replay.json),
[package audit](ReleaseReadiness/2.0-build83/classic-fan-package-audit.json) and
[Mac preparation evidence](ReleaseReadiness/MacOS2Preparation-2026-10-15/README.md).

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
content rule. The latest full audit recorded 2,399 winning routes, 3,600 levels
without a matching candidate and 21 failed replay levels after the Deep Deep Down
replay refresh. Those two copies already pass through verified-fan routes. The
two Magical World routes remain open. The strict route gate remains open. The audit
found no load, decode or render failures and no input-manifest drift. The October inventory lists two additional imported
levels outside the bundle and has nine stale saved-count mismatches. Close every
bundled level route and source-behaviour gap. See [current Classic validation](ReleaseReadiness/ClassicValidation-current.md)
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
