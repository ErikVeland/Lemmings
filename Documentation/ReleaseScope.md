# Release scope

Classic 1.0 is the historical macOS release baseline, confirmed on 13 September 2026.
The current public Macintosh release is 2.0.3 build 86. Its universal packages
are signed, notarised and accepted by Gatekeeper. The signed update feed and
five deltas from builds 85, 84, 83, 82 and 81 are live and verified. See the [2.0.3 distribution evidence](ReleaseReadiness/2.0.3-build86/README.md).
This release retains the existing classifications and documented limits. The stricter bundled-content closure remains open.

Version 2.0.3 build 86 fixes the Mac language
picker without changing engine rules or bundled levels. Source checks and
package status are recorded in the [2.0.3 release record](ReleaseReadiness/2.0.3-build86/README.md).

The owner set a stricter bundled-content closure rule on 15 October 2026. Every
bundled level needs a verified winning replay, and every bundled engine needs
source-behaviour evidence for its advertised rules. See the [content roadmap](ContentUniverseRoadmap.md).

Automated evidence supports the recorded native routes. Original-engine
fidelity, high-survivor endings and hardware acceptance retain their recorded
limits. See the [gate register](ReleaseReadiness/gates.json).

Macintosh 2.0.3 retains the published classifications and known limits. The release record documents the language-picker fix and five verified update deltas. Existing engine closure evidence and open limits remain in force.

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

The published 2.0.3 build 86 changes the Mac language picker and records no
engine-rule or bundled-level changes. Its non-localisation resource indexes
match build 85, and it retains the shared engine libraries. The complete build
86 app audit was not rerun, so build 85 route and engine evidence carries
forward only for unchanged inputs and code. See the [2.0.3 release record](ReleaseReadiness/2.0.3-build86/README.md).

On 17 October, `HEAD` matches `origin/main` at `81a7d030`. The worktree has
uncommitted evidence and diagnostic changes. The fast-forward from `368e7e72`
changes only the Apple TV Xcode project and scheme settings. The Classic, L2,
L3 and NeoLemmix engine, loader and route-validation sources remain unchanged.
The accepted Classic replay witnesses were rerun at `9a95012e` and matched.
This source check does not certify the build 86 app binary. The 3,617 Classic
fan route gaps, L2 Gold ark, L3 route and source-parity gaps, and NeoLemmix
style dependencies remain open. Imported content remains open-ended. See the
[current-main reconciliation](ReleaseReadiness/2.0-build83/current-main-sync-reconciliation-2026-10-17.json).

The published Mac build 86 and the current 2.0 iOS source are separate package
states. Build 86 records no non-localisation resource-index changes from build
85, but its complete app audit was not rerun. The last installed iOS beta,
build 8, contains 120 Classic campaign levels and no L2 or L3 mobile library.
Later source support for L2, L3 and NeoLemmix does not prove those engines are
in an accepted iOS release package. See the
[bundled-scope reconciliation](ReleaseReadiness/bundled-scope-reconciliation-2026-10-17.json).

A current-source bounded search used a 2,048-state beam for five unresolved
fan levels. It found no winning route. The verified fan count remains
2,403/6,020, with 3,617 routes open. These searches do not prove that the
levels are impossible. See the [five-level search record](ReleaseReadiness/2.0-build83/classic-fan-gap-search-2026-10-16.json).

The fan batch solver now accepts this audit’s exact unresolved member rows; it no longer depends on low-confidence profiles that are absent from the current evidence set. Twenty 60-second attempts, three focused continuations and a second progress-first batch covering ten identities (nine new) found no verified route, so the 3,617-route gap is unchanged. See the [batch search record](ReleaseReadiness/2.0-build83/classic-fan-batch-search-2026-10-17.json).

A 17 October exact-member search for the invalid-witness level “In the Core”
expanded 150,349 candidates in 60 seconds and found no replacement route. This
bounded result does not prove the level impossible. See the [search record](ReleaseReadiness/2.0-build83/classic-fan-in-the-core-search-2026-10-17.json).

A current-source follow-up rebuilt the solver and searched the same bundled
member for 180 seconds with an 8,192-wide beam, adaptive release rate and more
frequent decisions. It expanded 492,416 candidates and found no route. The
level remains open; the bounded search does not prove it impossible. The search
record includes the solver, library, archive hashes and exact settings.

The exact bundled level “Frozen in the airport” needs one survivor from eight.
A current-source 8,192-width beam, a complete one-skill timing sweep and a
Builder-to-Basher timing sweep found no route. These searches do not prove the
level impossible. A 17 October follow-up searched multi-skill routes for one
worker, then continued from its recorded partial commands. It expanded 557,979
and 660,621 candidates without a win. The level and bundled fan gate remain
open. These bounded searches do not prove the level impossible. See the
[search record](ReleaseReadiness/2.0-build83/classic-fan-frozen-airport-search-2026-10-17.json).

A targeted search of both bundled `Lemcon Nine` entries also found no route.
Each level has one Blocker and requires one saved lemming. Exhaustive single-skill
timing sweeps tested 5,418 to 15,954 assignments per run under the recorded
mechanics and clock variants. The fan count did not change. This does not prove
the levels impossible. See the [diagnosis record](ReleaseReadiness/2.0-build83/classic-fan-lemcon-nine-diagnosis-2026-10-16.json).

The exact pixel inspection found both exit triggers at y=96..<100 with no
terrain under them. Member 2 first reaches floor pixels at y=105. Member 4 has
only nearby pixels at or beyond the exit right edge. A temporary copy of member
2 with the exit object moved down eight pixels produced a replayed three-save
route. A 17 October DOS regression confirms that the native engine accepts a
splatter when its landing point overlaps a supported exit trigger. That test
does not establish whether DOS accepts either exact trigger placement. The
changed level does not count as closure evidence. Keep both entries open until
an original-engine comparison or an unchanged-content route confirms the
result. See the [updated diagnosis](ReleaseReadiness/2.0-build83/classic-fan-lemcon-nine-diagnosis-2026-10-16.json).

A native regression now checks the reported DOS climber turn across a one-pixel
gap and its landing on a bridge. The full Classic simulation suite and its
120-level campaign soak pass. A bounded exact-member Builder-to-Climber sweep
found no route for “It’s a Magical World”. The regression confirms one engine
behaviour. It does not prove source parity or close either bundled copy. See the
[climber check](ReleaseReadiness/2.0-build83/classic-fan-magical-world-climber-2026-10-17.json)
and the [route record](ReleaseReadiness/2.0-build83/classic-fan-magical-world-route-repair-2026-10-16.json).

| Bundled set | Current evidence | Open closure work |
| --- | --- | --- |
| Official Classic and Oh Yes! | The current-source recheck passes all 352 routes and the full quest. The build 85 manifest has the same 1,307 `Ports` paths and hashes as the route-check baseline. | Finish any remaining variant-specific source checks. The 2.0 build 83 candidate has verified resources and retained plus focused regression evidence. See the [build 85 content comparison](ReleaseReadiness/2.0.2-build85/bundled-content-equivalence-recheck-2026-10-16.json). |
| Classic fan packs | A fresh 16 October current-main audit replayed all 6,020 bundled levels in 535 packs. It verifies 2,403 wins, leaves 3,599 levels without a matching candidate and 18 failed candidate replays, and reports zero load, decode or render failures. The input-drift report is clean. This supersedes the prior 2,402-win count; 3,617 bundled routes remain unverified. The 17 October reconciliation classified all 18 failed-candidate rows. Ten came from checked state-hash aliases between different puzzles. The other eight have candidate metadata that matches the target pack, level number and title. No route status changed. See the [state-hash alias reconciliation](ReleaseReadiness/2.0-build83/classic-fan-state-hash-alias-reconciliation-2026-10-17.json). The Classic route solver now considers every simultaneous decision actor. Its six-actor regression passes. Current bounded searches found no route for “crossing stairs” or “The mini-labyrinth”; the route count remains 2,403/6,020. Two 600-second, beam-16,384 exact-member searches for “The Frantic Lemming Antic” found no route. The searches used different distance rankings, expanded 1,663,361 and 1,675,731 candidates, and retained the same 0/2 partial. The stored “The Great Lemming Caper” replay also failed on this target. A further 89,771 bounded retiming trials produced no winning witness. These results do not prove that the level is impossible. See the [search and replay-repair record](ReleaseReadiness/2.0-build83/classic-fan-frantic-search-2026-10-17.json). See the [solver change and search evidence](ReleaseReadiness/2.0-build83/classic-solver-all-actor-search-2026-10-16.json). Three exact-member searches for “Getting Closer...” found no route: native-rate, adaptive-rate and seeded adaptive-rate runs expanded 837,512, 770,486 and 654,163 candidates. Its existing level-3 witness fails on level 6, and the same legacy state hash belongs to a different level fingerprint. The level remains unverified. See the [targeted repair record](ReleaseReadiness/2.0-build83/classic-fan-getting-closer-repair-2026-10-16.json). Four current exact-member searches for “Ups and Downs” found no route. The 21-command continuation expanded 309,612 candidates. Adding the recorded Golems source-assignment rule to the old replay still saved 0 of 20 on the current runtime. This conflicts with the 4 October recovery record’s 19/19 result, so that result and its score are historical and do not count as current verified evidence. The level remains unverified. See the [repair and replay reconciliation record](ReleaseReadiness/2.0-build83/classic-fan-ups-and-downs-repair-2026-10-16.json). The new “the last mohilem” witness passes twice with its static level fingerprint. The audit used installed 1.9.1 build 76 resources. All 535 fan archives match build 85, and build 86 reports no non-localisation resource-index changes. The source and content hashes are retained in the audit input manifest. All 2,755 winning routes (352 official and 2,403 fan) now have identity-pinned replay witnesses; each passed two strict deterministic runs, and the coverage checker verifies its state hash and static level fingerprint against the row. The replay witness file is retained beside the audit rows. This does not certify the 2.0.3 app binary. Both “Deep Deep Down” copies have verified fan routes. The two “It’s a Magical World” copies still lack winning routes. A 16 October current-engine continuation search used the retained route prefix through tick 880 on both exact archive identities. Each 300-second, beam-8,192 search found no win; a 300-second from-start search for the first copy also found no win after 709,892 expansions. These bounded searches do not prove either level impossible. See the [route repair record](ReleaseReadiness/2.0-build83/classic-fan-magical-world-route-repair-2026-10-16.json). Adaptive-rate searches and a partial timed Builder/Basher sweep found no win for “Only practice.” An earlier current-main beam-8,192 run covered actor IDs 0 through 3. Two later five-minute searches covered all 40 actors with balanced and progress-first rankings. They expanded 576,145 and 684,056 candidates and found no win. The level has no verified route. See the [current-main search record](ReleaseReadiness/2.0-build83/classic-fan-only-practice-search-2026-10-16.json). A targeted current-runtime search for “I Challenge You to a Duel!” also found no replacement route after 280,631 prefixed and 291,536 from-start expansions; its stored witness is refused at tick 943. See the [targeted repair record](ReleaseReadiness/2.0-build83/classic-fan-duel-route-repair-2026-10-16.json). A separate failed “Dude, where’s my exit?” copy shares its legacy state hash with a winning Earth copy, but has a different static level fingerprint. Two current-source searches and a seeded continuation found no replacement route; a Digger/Blocker sweep stopped after 206 continuations and is incomplete. See the [variant repair record](ReleaseReadiness/2.0-build83/classic-fan-dude-wheres-my-exit-repair-2026-10-16.json). Four additional 120-second current-main probes on Increasing step heights, The Arctic, Amazonian and Wait. I have a plan. found no winning route. A 300-second current-main continuation seeded with the source-derived Increasing step heights prefix expanded 598,444 candidates and found no win. These bounded searches do not prove that the levels are impossible. See the [route probe record](ReleaseReadiness/2.0-build83/classic-fan-route-probes-2026-10-16.json). Two 120-second searches on “Let’s play with stairs !” used 60-tick and 20-tick timing intervals. They expanded 343,698 and 348,757 candidates. Both partial routes used all 15 Builders and saved 0/1. These bounded searches do not prove the level impossible. See the [route probe record](ReleaseReadiness/2.0-build83/classic-fan-route-probes-2026-10-16.json). Three further low-population searches on “2 lemmings,” “New Message -From KillerMaster-” and “The strange spiral” found no winning route. One-skill sweeps completed 48, 76 and 5,990 assignments. Multi-input searches expanded 15,001 to 357,697 candidates. Four exhaustive two-skill timing sweeps for “New Message -From KillerMaster-” tested all Builder/Digger orderings, with first inputs through tick 122 and second-input gaps of 1 to 240 ticks; they found no route. The two-lemming Builder level also had a complete Builder-pair sweep (557 continuations) and a 101-delay Builder-broadcast sweep; neither found a route. These bounded attempts do not prove that the levels are impossible. See the [low-population search record](ReleaseReadiness/2.0-build83/classic-fan-low-population-searches-2026-10-16.json). A current-main five-minute search of “Mission at max-fall 60” found no win after 600,630 expansions; an exhaustive single-skill sweep tested 7,727 assignments and found no one-skill route. These searches do not prove the level impossible. See the [targeted search record](ReleaseReadiness/2.0-build83/classic-fan-mission-max-fall-60-search-2026-10-16.json). Two October CSV entries are imported `fan:lldb-595` levels outside the bundle. | Verify the remaining bundled routes and source behaviour. Keep imported content open-ended under per-engine and per-version support claims. See the [build 83 replay audit](ReleaseReadiness/2.0-build83/classic-fan-build83-replay.json), [package audit](ReleaseReadiness/2.0-build83/classic-fan-package-audit.json), [build 85 manifest comparison](ReleaseReadiness/2.0.2-build85/bundled-content-equivalence-recheck-2026-10-16.json), [2.0 build83/15 October engine-equivalence snapshot](ReleaseReadiness/2.0-build83/engine-content-equivalence-current-main.json) and [“Only practice” search](ReleaseReadiness/2.0-build83/classic-fan-only-practice-search-2026-10-16.json). |
| Lemmings 2 | On 16 October, current-main replay passes all 120 routes, 70 carry-over variants, twelve chains, event checks and the runtime suite against the exact staged build 83 app payload. Its 218 files match the retained build 82 manifest and installed build 76 tree. The full archive extraction had 14 DOS interpreter/support files that the app packager excludes. A renderer-preserving source capture shows Beach 10 at 8:36, matching native tick 360 with 516 seconds remaining. Exact WALKER.DAT palette matches occur at two sampled positions predicted for native actor 11, at 8:36 and 8:34. A 17 October rebuild from current main also reports exact WALKER pixels in the 8:33 frame, but across multiple native actors and ticks and without a tracked actor-11 match. These samples support local sprite geometry only; they do not establish DOS tick alignment, source actor identity, continuous actor parity, full Mac rendering or broader engine behaviour. See the [frame comparison](ReleaseReadiness/L2GameplayParity-2026-10-16/frame-comparison-001.json) and [current-main 8:33 matcher output](ReleaseReadiness/L2GameplayParity-2026-10-16/walker-match-2590-current-main-2026-10-17.txt). Every accepted chain ends with one survivor and a Bronze talisman. Candidate routes save 34/36 on Cavelems 3, 13/34 on Level 4 and 10/13 on Level 5. Searches found no Cavelems Level 6 route at population 10 or 13. The latest population-10 search used a beam of 8,192 and depth 80 for 300 seconds, and expanded 692,245 candidates without a win. Two unseeded Level 4 searches at population 34 reached beam 8,192; the 4-pixel grid expanded 1,014,578 candidates and the finer 2-pixel grid expanded 1,126,648, with neither finding a win. Three seeded Level 4 searches reproduced the existing 13-of-34 Bronze route byte for byte with 2-, 4- and 8-pixel grids. A 300-second seeded Beach 1 search with an 8,192 beam and 2-pixel decision grid reproduced 42/60 without improvement. Other bounded searches reproduced the existing Level 5 and Classic 2 routes. The accepted chains remain unchanged. A new current all-actor search at population 10 also found no route: the unseeded and seeded runs expanded 747,437 and 876,791 candidates. Both use the carried count produced by the candidate Level 5 route. See the [candidate-chain reconciliation](Lemmings2Completion/cavelem-candidate-chain-reconciliation-2026-10-16.json). The earlier 600-second current-main population-13 search used the pre-fix solver and found no route after 1,250,232 expansions. Two current all-actor searches at population 13, unseeded and seeded from the accepted 2-of-2 route, ran for 600 seconds and found no win after 1,291,693 and 1,463,726 expansions. These bounded searches do not prove impossibility. See the [candidate-chain reconciliation](Lemmings2Completion/cavelem-candidate-chain-reconciliation-2026-10-16.json). See the [wide Level 6 search](Lemmings2Completion/cavelem06-pop13-beam16384-current-main-2026-10-16.json). A 600-second 32,768-beam Level 2 search and three seeded-prefix searches did not improve the accepted 36/59 route. The Gold ark requirement remains open. A fresh 120-second search on current origin/main after the L2 runtime optimisation also retained 36/59. See the [wider and current-main Level 2 search record](Lemmings2Completion/cavelem02-unseeded-beam32768-cell1-search-2026-10-16.json). | Raise each chain to 30 final survivors, verify the golden talisman ending and close source-engine comparisons. See the [build 83 payload replay](ReleaseReadiness/2.0-build83/lemmings2-build83-payload-replay.json), [Beach 1 search](Lemmings2Completion/beach01-seeded-beam8192-search-2026-10-16.json), [Cavelems reconnection search](Lemmings2Completion/cavelem-ark-reconnection-search-2026-10-16.json), [current-main follow-up](Lemmings2Completion/ark-reconnection-search-2026-10-16-current-main.json), [wider Level 4 search](Lemmings2Completion/cavelem04-beam8192-search-2026-10-16.json) and [seeded Level 4 search](Lemmings2Completion/cavelem04-seeded-beam8192-search-2026-10-16.json) and [Cavelems Level 2 search](Lemmings2Completion/cavelem02-current-main-ark-route-searches-2026-10-16.json) and [all-actor follow-up](Lemmings2Completion/cavelem02-all-actor-followup-search-2026-10-16.json). |
| Lemmings 3 | The fixture audit at `1111ece8` double-replays 399/416 fixtures, with the same 17 route failures. Five Shadow 13 carried identities are refreshed. Four standalone outcomes and 13 carried schedules still fail. The five main commits through 2.0.3 changed no Lemmings 3 engine source, so this engine evidence remains applicable to current main. On 16 October, source searches found no route for standalone Shadow 7 or Egyptian 6, 13 and 29. Wider 4,096-beam, 4-pixel-grid searches expanded 3,889,087 candidates for Egyptian 13, 5,181,833 for Egyptian 6 and 3,620,601 seeded candidates for Egyptian 29, with no route. A 17 October 300-second Shadow 7 follow-up expanded 3,732,001 candidates and found no route. Source evidence has 673 repeatable samples for left-facing burrowing and a fall into an open gap. An isolated prototype matches 53 sampled positions, but four terrain-edge samples contradict its rectangular carve. | Recover four standalone routes and 13 carried schedules, then rerun the full 90-route and campaign gates. Verify the exact excavation mask, built-brick trigger and remaining source rules. Close environmental effects, movie audio, story transitions and recovery. See the [wider route searches](ReleaseReadiness/L3MoleVerification-2026-10-15/current-main-wide-route-searches-2026-10-16.json), [current-main search record](ReleaseReadiness/L3MoleVerification-2026-10-15/current-main-searches-2026-10-16.json), [fixture audit provenance](ReleaseReadiness/L3MoleVerification-2026-10-15/current-fixture-audit-provenance.json) and [Mole source-parity recheck](ReleaseReadiness/L3MoleVerification-2026-10-15/current-source-parity-recheck-2026-10-16.json). |
| NeoLemmix CE | The build 85 bundled-resource check indexes all 794 levels and resolves 719 through the 26 bundled DMA styles; the other 75 need 44 community styles. Exact-version winning replay evidence covers 158 levels. Build 86 records no non-localisation resource-index differences from build 85, but its full app audit was not rerun. | Keep all 794 levels in closure scope. Obtain rights for missing styles and verify every bundled route and source rule. See the [2.0.3 release record](ReleaseReadiness/2.0.3-build86/README.md), [2.0.2 resource check](ReleaseReadiness/2.0.2-build85/README.md), [build 84 content inventory](ReleaseReadiness/2.0.1-build84/neo-content.json) and [style rights inventory](ReleaseReadiness/2.0-build83/neolemmix-style-rights-inventory.json). |

The table tracks engine and content closure. It does not certify a specific
app archive. Release packaging, platform acceptance and distribution need their
own records. The current Classic fan result supersedes earlier 2,399/6,020
summaries and the failed-replay investigation below: two Amiga routes and one
Genesis Taxing route now replay as wins. The old search records remain historical
and do not describe the latest route status. See the [current-main audit](ReleaseReadiness/2.0-build83/classic-fan-current-main-audit-reconciled-2026-10-16/audit.json)
and its per-level [results](ReleaseReadiness/2.0-build83/classic-fan-current-main-audit-reconciled-2026-10-16/levels.jsonl).

On 17 October, the source-derived L2 walking-step boundary gained a native
regression. The repository runtime suite passed against the installed bundle;
it checked four-pixel ascent, five-pixel rejection, all 120 level loads and
advances, and 120 recorded completion replays. This closes that boundary-test
gap only. DOS parity, the Gold Ark and the remaining bundled requirements stay
open. See the [test record](ReleaseReadiness/L2GameplayParity-2026-10-17/walking-step-boundary.json).

The 17 October NeoLemmix rights review found a possible name match between
`l2_polar` and `l2 polar` under DMA in the pinned licence. The style-to-licence
identity still needs confirmation. Name-prefix evidence gives 14 candidate
creators for other unlisted styles, but it does not prove ownership. Three
style owners remain unassigned: `sms_crystal`, `sms_fire` and `special`. All 44
styles remain uncleared, and the 75 affected bundled levels remain open. See
the [style rights inventory](ReleaseReadiness/2.0-build83/neolemmix-style-rights-inventory.json).

A follow-up audit adds a static level fingerprint to all 6,020 fan rows. It
retains the same 2,403 verified wins, 18 failed replays and 3,599 levels without
a matching candidate. It also confirms 5,461 distinct fingerprints across the
6,020 level entries; repeated identities remain visible as separate bundled
entries. The clean input-drift result and exact resource hashes are recorded in
the [fingerprinted audit](ReleaseReadiness/2.0-build83/classic-fan-fingerprinted-audit-2026-10-16/audit.json)
and its per-level [results](ReleaseReadiness/2.0-build83/classic-fan-fingerprinted-audit-2026-10-16/levels.jsonl).
This tightens identity evidence; it does not close the 3,617 missing routes or
certify the 2.0.3 app binary.

On 16 October, the focused replay-identity tests passed under Xcode 26.6. They
confirm that different terrain dimensions, entrances, triggers and destruction
masks produce different level fingerprints. Legacy replay files still decode.
This check does not rerun the full audit or close the 3,617 missing bundled fan
routes. Repeat it with `swift test --disable-sandbox --filter ClassicLevelFingerprintTests`.

The full NxlvKit test group ran 123 tests. The 119 tests that did not need
missing assets passed. One font check skipped because its decoded bank is absent.
Three monochrome tests failed because this checkout has no generated artwork
manifest at `.build/mac-artwork/export/monochrome/lemmings/manifest.json`.
The ZIP decoder passed across all 535 bundled archives, and the L2 font tests
passed against the installed resource tree.

On 16 October, a further current-engine search for bundled “Smile if you love
decoration” used a beam of 8,192 for 600 seconds and expanded 1,564,061
candidates. It found no winning route; the partial run saved 0/10. The route
remains unverified. The search bound does not prove the level impossible. The
latest full audit verifies 2,403/6,020 bundled routes, with 3,617 wins still
unverified. See the [search record](ReleaseReadiness/2.0-build83/classic-fan-smile-decoration-route-search-2026-10-16.json)
and [partial replay](ReleaseReadiness/2.0-build83/classic-fan-smile-decoration-partial-2026-10-16.json).

On 16 October, two current-main searches tried to repair the failed witness for
“Don’t do anything too hasty” in the two Amiga archives. The 600-second from-start
search expanded 1,422,777 candidates. A 300-second search seeded with the first
12 historical actions expanded 938,891 candidates. Neither found a win. This
search result was superseded by the current-main strict audit, which replayed
both Amiga copies successfully with fingerprinted routes. The legacy
`initialStateHash` includes remaining time but omits terrain dimensions,
entrances, triggers, destruction masks and hatch source offsets. It cannot prove
full simulation equivalence. New app, solver and completion replays now carry
`initialLevelFingerprint` for these static inputs. The standalone Classic DOS
replay suite passed with collision, legacy-decoding and Fun 1 checks. SwiftPM
could not run `NxlvKitTests` in its initial command-line-tools invocation
because that SDK lacked the `Testing` module. A later Xcode 26.6 run is recorded
above. See the [current-main audit](ReleaseReadiness/2.0-build83/classic-fan-current-main-audit-reconciled-2026-10-16/audit.json)
for the replacement route evidence.

In the earlier 21-row failed-candidate audit, 18 initial hashes recurred. Ten failed-hash
groups also occur on a winning row, and six include a winning row with a
different title. A shared hash does not identify a level or transfer its route.
This hash analysis is historical and predates the corrected candidate index.
See the [repair record](ReleaseReadiness/2.0-build83/classic-fan-failed-witness-repair-2026-10-16.json).

The October CSV is a discovered-content inventory, not the bundle manifest. Its
two `fan:lldb-595` levels (`LEVELPAK.DAT#0` and `LEVELPAK.DAT#1`) are imported
and outside the 535-pack bundle. The nine saved-count mismatches are stale
candidate replay records. Although the candidate archive labels matching
inputs as wins, those labels are not proof: the earlier strict native audit found
21 candidate or historical replay witnesses that did not reproduce a win. The
September 344-witness count is historical. That earlier full current-source
audit against the exact build 83 resources recorded
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
An earlier full current-source audit ran at `fc2c59e6` against the exact extracted
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

## 2.0 bundled-content closure rule — 17 October 2026

The owner requires full bundled-content closure for each new 2.0 release
candidate. Freeze the exact candidate manifest. Keep every level, engine
version, style, asset and dependency in that manifest within closure scope.
Verify every bundled route, advertised engine rule, campaign transition,
ending, save, media path and recovery path that the candidate exposes. Mark
the candidate not ready while any bundled item remains open.

Apply this rule to all content that the candidate ships. Keep all 794 NeoLemmix
levels in the current Macintosh bundle within the wider bundled-closure scope.
Do not classify unresolved bundled levels as imports. Imported content outside
the candidate manifest remains open-ended under per-engine and per-version
support claims.

The current evidence does not meet this rule. See the [2.0 release gate](ReleaseReadiness/2.0ReleaseGate-2026-10-14.md)
and the [gate register](ReleaseReadiness/gates.json).

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
content rule. The earlier full audit recorded 2,402 winning routes, 3,600 levels
without a matching candidate and 18 failed replay levels. The reconciled audit
now records 2,403 wins, 3,599 levels without a matching candidate and the same
18 failed replays. The corrected candidate index recovered two Amiga copies of
“Don’t do anything too hasty”, one Genesis Taxing level and “the last mohilem”. The two Magical World routes remain open. The strict route gate remains open. The audit
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
