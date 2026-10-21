# Release scope

The next coordinated Apple release is tracked in the
[shared 2.1.2 checklist](ReleaseReadiness/2.1.2Checklist.md). It separates
implemented changes, headless verification, physical acceptance and distribution.
Version 2.1.2 is not yet a release candidate.

The 21 October merge combines the two Mole runtime changes. Earlier L3 trace
scores describe their recorded source snapshots. See the [merge validation](ReleaseReadiness/Release211ProgressionMerge-2026-10-21.md)
for the combined runtime and replay identities.

Classic 1.0 is the historical macOS release baseline, confirmed on 13 September 2026.
As of 21 October 2026, the published Mac release is 2.1.1 build 95. Both
universal archives passed signing, notarisation, stapling and Gatekeeper.
Five direct updates passed exact tree and signature checks. Public assets and
the live signed feed match the recorded hashes. See the
[2.1.1 release record](ReleaseReadiness/2.1.1-build95/README.md).

The [2.1.1 notes](ReleaseNotes-2.1.1-build95.md) cover Journey progress recovery,
automatic worldwide rankings and the latest merged runtime and menu changes.
The current Classic and The Tribes Complete classifications and Chronicles
and NeoLemmix Beta classifications remain unchanged. Fresh rescue checks retain
294 certificates and 315 records across 615 configurations; six remain unknown.
Human, foreground and device acceptance limits remain explicit.
iOS 2.1.1 build 18 is Testing. tvOS 2.1.1 build 8 is
Waiting for Review. Both were uploaded to their existing TestFlight
groups with automatic notifications enabled. These uploads do not establish
physical-device acceptance or close engine-fidelity gaps.

The previous [2.1 release record](ReleaseReadiness/2.1-build93/README.md)
retains its publication and validation evidence.

Version 2.0.3 build 86 fixes the Mac language
picker without changing engine rules or bundled levels. Source checks and
package status are recorded in the [2.0.3 release record](ReleaseReadiness/2.0.3-build86/README.md).

The owner set a stricter bundled-content closure rule on 15 October 2026. Every
bundled level needs a verified winning replay, and every bundled engine needs
source-behaviour evidence for its advertised rules. See the [content roadmap](ContentUniverseRoadmap.md).

Automated evidence supports the recorded native routes. Original-engine
fidelity, high-survivor endings and hardware acceptance retain their recorded
limits. See the [gate register](ReleaseReadiness/gates.json).

Macintosh 2.1.1 build 95 retains the published classifications and known limits.
Its publication record documents the signed update deltas. Existing engine
closure evidence and open limits remain in force.

## Current bundled route counts

The latest retained evidence records 352/352 official Classic routes,
2,404/6,019 playable Classic fan routes, 120 L2 standalone routes with 70 carry-over
variants and 12 chains, 86/90 L3 routes, and 158/794 NeoLemmix routes. The
evidence dates differ by engine. L2 Gold Ark, four L3 level identities, 3,615
Classic fan routes and 636 NeoLemmix routes remain open. See the
[bundled closure velocity record](ReleaseReadiness/BundledClosureVelocity.md)
for dates, search outcomes and measurement limits.

A 20 October structural scan decoded all 6,020 bundled fan levels across 535
packs. It found 54 records without an active exit trigger. Fifty-one have a
zero rescue requirement and already have winning replay evidence. Three
positive-rescue records remain open: `fan:lldb-437` `LDChallenge08.dat#1`,
`fan:lldb-508` `KillerMaster 1 Wicked 1.dat#3`, and `fan:lldb-509`
`KillerMaster 1 Havoc 2.dat#7`. Each decoded record contains only a hatch
object. These three levels cannot meet their rescue requirements as bundled.
The scan found no level-load or pack errors and replayed no levels. See the
[exit-structure audit](ReleaseReadiness/ClassicFanExitStructure-2026-10-20.json).
The 21 October decision excludes the exact `fan:lldb-509` no-exit record from
playable bundled scope while retaining its source archive. The other two rows
retain their recorded limits. See the [merge record](ReleaseReadiness/Release211ProgressionMerge-2026-10-21.md).

## Bundled content closure

On 15 October 2026, the owner set a stricter bundled-content closure target.
Full closure requires an exact content manifest, load/render/run evidence and a
verified winning replay for every included level. Each engine must also pass
source-behaviour comparisons for its advertised rules. Campaign transitions,
endings, media, saves and recovery must pass when the bundle exposes them.
Build 83 later deferred full closure as a release prerequisite while retaining
the recorded game classifications and limits. Imported content remains
open-ended and uses per-engine, per-version support claims. See the
[content roadmap](ContentUniverseRoadmap.md) and the
[bundled closure velocity record](ReleaseReadiness/BundledClosureVelocity.md).

The 2.1 build 93 content comparison confirms unchanged `Ports`, `LevelPacks`
and NeoLemmix trees. Its source commit also changes the Classic, L2, L3 and
NeoLemmix simulations. The five delta checks do not replay all retained route
witnesses against those current engines. Counts below are the last accepted
route evidence; they are not a fresh full-family audit of the 2.1 source.

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

As of 20 October, a fresh fetch confirms that this worktree, `origin/main` and
`FETCH_HEAD` all point to `4bf3bddcb2641751eafd51b44a9cf29f18732c90`. The
worktree has no commits ahead of or behind live `main`. The worktree has local
uncommitted changes. The 18 October fetch and ancestry record are historical.
The 18 October audit on worktree `8c66ef3e` verified 399/416 exact double
replays. It recorded 17 failures across levels 107, 206, 213 and 229. That
source snapshot is historical. The 20 October audit uses current source
`4bf3bddc` and the installed Mac build 76 L3 resource tree. After the Mole
patrol-phase hash change, 203 winning fixtures were refreshed through two
replays. The latest audit verifies 399/416 exact fixtures, with 17 failed
schedules across levels 107, 206, 213 and 229. Level 101 passes its retained
route. Current coverage is 86/90 standalone levels and 313/326 carried
fixtures. The build 85 content comparison matches this 561-file L3 tree. Build
93 does not provide a direct hash link from build 76 to its build 2.0.7 content
baseline. See the [cycle-12 audit](ReleaseReadiness/L3MoleVerification-2026-10-15/current-cycle12-audit-4bf3bddc-2026-10-20.json).

The current source-built L3 runtime suite passes. The strict route and campaign
gate fails on `107.json` and carried fixture `107-1.json`. A seeded, 120-second
search on Shadow 7 produced no route. See the [current-source route
search](ReleaseReadiness/L3MoleVerification-2026-10-15/current-source-shadow07-seeded-search-4bf3bddc-2026-10-20.json).
Seven cycle-12 first-win searches covered the open L3 route identities at Levels 107, 206, 213 and 229. They expanded 7,693,495 states over 847 seconds and found no route. The extra Level 213 search doubled beam width to 16,384. They saved no lemmings and closed no level. These results measure search throughput. See the [search record](ReleaseReadiness/L3MoleVerification-2026-10-15/current-cycle12-mvp-searches-4bf3bddc-2026-10-20.json).

The Trolley runner passes the history, deterministic-classification, Game
Center reconnect, rank, account-switch and profile-ownership checks. Its full
UI flow stops at the `Play replay` control assertion. The local app bundle
lacks game data, and a rebuild is blocked because
`Content/LevelPacks/packs.json` is absent.

The historical 2.0 branch includes the 2.0.5 Trolley history hotfix, a deterministic
classification fix, the explicit-steel L3 Mole contact change and the source-based
open-drop transition. Commit `833f396b` still updates the 2.0.4 appcast.
The current source-derived Mole cadence matches 225/344 air-gap and 139/329
left-facing positions in the retained probe scenes. Their level 101 data differs
from the bundled level, so these traces are isolated source-behaviour evidence.
They do not prove route or scene parity for bundled level 101. The post-drop
trace matches through tick 248 and first differs at tick 249. See the
[cycle-12 audit](ReleaseReadiness/L3MoleVerification-2026-10-15/current-cycle12-audit-4bf3bddc-2026-10-20.json).
The earlier 4/3-pixel experiment is historical and is not current evidence.
See the [historical Mole record](ReleaseReadiness/L3MoleVerification-2026-10-15/current-main-open-drop-e613a5e9-2026-10-17.json).

The 17 October L3 audit at `e613a5e9` records 399/416 exact double replays and
17 failures across four levels. This is historical evidence. The current 20
October audit against the installed build 76 resource tree records 399/416
exact replays and 17 failures across four levels.
Earlier Trolley evidence checks
615 configurations across 562 campaign identities, with 294 population proofs,
315 rescue records and six unknown configurations. These results do not close
the Classic fan, L2 Gold Ark, L3 route or NeoLemmix style gaps.

The feed and source versions are recorded at the start of this document. The
latest Mac package acceptance record is build 93. See the
[2.1 publication record](ReleaseReadiness/2.1-build93/README.md),
[current release notes](ReleaseNotes-2.1-build93.md) and [current-main
reconciliation](ReleaseReadiness/2.0-build83/current-main-sync-reconciliation-2026-10-17.json).
Build 86 records no non-localisation resource-index changes from build 85, but
its complete app audit was not rerun. The last installed iOS beta, build 8,
contains 120 Classic campaign levels and no L2 or L3 mobile library. Later
source support for L2, L3 and NeoLemmix does not prove those engines are in an
accepted iOS release package. See the
[bundled-scope reconciliation](ReleaseReadiness/bundled-scope-reconciliation-2026-10-17.json).

Imported content stays open-ended. It is excluded from bundled closure counts.
Support claims apply only to the named engine, content version and verified
features; they do not imply that every imported pack or level is complete.

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

As of 21 October, the accepted Classic fan route count is 2,404 of 6,019
playable bundled levels. The source inventory retains 6,020 rows. One exact
no-exit source row is excluded from playable scope by owner decision; the
exclusion adds no route. The route count includes the 16 October full audit and
one targeted route that passed two current-source replays. The full-catalogue
audit remains dated 16 October.
See the [route closure](ReleaseReadiness/ClassicFanPropersisionZeroClosure-2026-10-21.json)
and the [velocity record](ReleaseReadiness/BundledClosureVelocity.md), plus the
[playable-scope decision](ReleaseReadiness/ClassicFanPlayableScopeExclusion-2026-10-21.json).

| Bundled set | Current evidence | Open closure work |
| --- | --- | --- |
| Official Classic and Oh Yes! | The 20 October current-source replay passes all 352 routes against installed 1.9.1 build 76 resources. Its quest check passes 1,056 recoveries, 352 progress resumes and six chapter transitions. The 1,307-file `Ports` tree matches the retained content manifest. | Finish variant-specific source checks and validate the 2.1 build 93 app binary. The route run does not prove original-engine parity. See the [current-source replay](ReleaseReadiness/OfficialClassicCurrentSourceReplay-2026-10-20.json) and [build 85 content comparison](ReleaseReadiness/2.0.2-build85/bundled-content-equivalence-recheck-2026-10-16.json). |
| Classic fan packs | A fresh 16 October current-main audit replayed all 6,020 bundled levels in 535 packs. It verifies 2,403 wins, leaves 3,599 levels without a matching candidate and 18 failed candidate replays, and reports zero load, decode or render failures. The input-drift report is clean. This supersedes the prior 2,402-win count; 3,617 bundled routes remain unverified. The 17 October reconciliation classified all 18 failed-candidate rows. Ten came from checked state-hash aliases between different puzzles. The other eight have candidate metadata that matches the target pack, level number and title. No route status changed. See the [state-hash alias reconciliation](ReleaseReadiness/2.0-build83/classic-fan-state-hash-alias-reconciliation-2026-10-17.json). The Classic route solver now considers every simultaneous decision actor. Its six-actor regression passes. Current bounded searches found no route for “crossing stairs” or “The mini-labyrinth”; two more current-source exact-member probes found no route for “Winter Solstice” (including the retained failed 9/9 candidate) or “Look Down!” (including all single-skill sweeps and all 12 ordered two-skill pairs at rate 99). No route status changed. See the [Winter Solstice and Look Down! search record](ReleaseReadiness/2.0-build83/classic-fan-winter-solstice-look-down-search-2026-10-17.json). the route count remains 2,403/6,020. Two 600-second, beam-16,384 exact-member searches for “The Frantic Lemming Antic” found no route. The searches used different distance rankings, expanded 1,663,361 and 1,675,731 candidates, and retained the same 0/2 partial. The stored “The Great Lemming Caper” replay also failed on this target. A further 89,771 bounded retiming trials produced no winning witness. These results do not prove that the level is impossible. See the [search and replay-repair record](ReleaseReadiness/2.0-build83/classic-fan-frantic-search-2026-10-17.json). See the [solver change and search evidence](ReleaseReadiness/2.0-build83/classic-solver-all-actor-search-2026-10-16.json). Three exact-member searches for “Getting Closer...” found no route: native-rate, adaptive-rate and seeded adaptive-rate runs expanded 837,512, 770,486 and 654,163 candidates. Its existing level-3 witness fails on level 6, and the same legacy state hash belongs to a different level fingerprint. The level remains unverified. See the [targeted repair record](ReleaseReadiness/2.0-build83/classic-fan-getting-closer-repair-2026-10-16.json). Four current exact-member searches for “Ups and Downs” found no route. The 21-command continuation expanded 309,612 candidates. Adding the recorded Golems source-assignment rule to the old replay still saved 0 of 20 on the current runtime. This conflicts with the 4 October recovery record’s 19/19 result, so that result and its score are historical and do not count as current verified evidence. The level remains unverified. See the [repair and replay reconciliation record](ReleaseReadiness/2.0-build83/classic-fan-ups-and-downs-repair-2026-10-16.json). The new “the last mohilem” witness passes twice with its static level fingerprint. The audit used installed 1.9.1 build 76 resources. All 535 fan archives match build 85, and build 86 reports no non-localisation resource-index changes. The source and content hashes are retained in the audit input manifest. All 2,755 winning routes (352 official and 2,403 fan) now have identity-pinned replay witnesses; each passed two strict deterministic runs, and the coverage checker verifies its state hash and static level fingerprint against the row. The replay witness file is retained beside the audit rows. This does not certify the 2.0.3 app binary. Both “Deep Deep Down” copies have verified fan routes. The two “It’s a Magical World” copies still lack winning routes. A 16 October current-engine continuation search used the retained route prefix through tick 880 on both exact archive identities. Each 300-second, beam-8,192 search found no win; a 300-second from-start search for the first copy also found no win after 709,892 expansions. These bounded searches do not prove either level impossible. See the [route repair record](ReleaseReadiness/2.0-build83/classic-fan-magical-world-route-repair-2026-10-16.json). Adaptive-rate searches and a partial timed Builder/Basher sweep found no win for “Only practice.” An earlier current-main beam-8,192 run covered actor IDs 0 through 3. Two later five-minute searches covered all 40 actors with balanced and progress-first rankings. They expanded 576,145 and 684,056 candidates and found no win. The level has no verified route. See the [current-main search record](ReleaseReadiness/2.0-build83/classic-fan-only-practice-search-2026-10-16.json). A targeted current-runtime search for “I Challenge You to a Duel!” also found no replacement route after 280,631 prefixed and 291,536 from-start expansions; its stored witness is refused at tick 943. See the [targeted repair record](ReleaseReadiness/2.0-build83/classic-fan-duel-route-repair-2026-10-16.json). A separate failed “Dude, where’s my exit?” copy shares its legacy state hash with a winning Earth copy, but has a different static level fingerprint. Two current-source searches and a seeded continuation found no replacement route; a Digger/Blocker sweep stopped after 206 continuations and is incomplete. See the [variant repair record](ReleaseReadiness/2.0-build83/classic-fan-dude-wheres-my-exit-repair-2026-10-16.json). Four additional 120-second current-main probes on Increasing step heights, The Arctic, Amazonian and Wait. I have a plan. found no winning route. A 300-second current-main continuation seeded with the source-derived Increasing step heights prefix expanded 598,444 candidates and found no win. These bounded searches do not prove that the levels are impossible. See the [route probe record](ReleaseReadiness/2.0-build83/classic-fan-route-probes-2026-10-16.json). Two 120-second searches on “Let’s play with stairs !” used 60-tick and 20-tick timing intervals. They expanded 343,698 and 348,757 candidates. Both partial routes used all 15 Builders and saved 0/1. These bounded searches do not prove the level impossible. See the [route probe record](ReleaseReadiness/2.0-build83/classic-fan-route-probes-2026-10-16.json). Three further low-population searches on “2 lemmings,” “New Message -From KillerMaster-” and “The strange spiral” found no winning route. One-skill sweeps completed 48, 76 and 5,990 assignments. Multi-input searches expanded 15,001 to 357,697 candidates. Four exhaustive two-skill timing sweeps for “New Message -From KillerMaster-” tested all Builder/Digger orderings, with first inputs through tick 122 and second-input gaps of 1 to 240 ticks; they found no route. The two-lemming Builder level also had a complete Builder-pair sweep (557 continuations) and a 101-delay Builder-broadcast sweep; neither found a route. These bounded attempts do not prove that the levels are impossible. See the [low-population search record](ReleaseReadiness/2.0-build83/classic-fan-low-population-searches-2026-10-16.json). A current-main five-minute search of “Mission at max-fall 60” found no win after 600,630 expansions; an exhaustive single-skill sweep tested 7,727 assignments and found no one-skill route. These searches do not prove the level impossible. See the [targeted search record](ReleaseReadiness/2.0-build83/classic-fan-mission-max-fall-60-search-2026-10-16.json). Two October CSV entries are imported `fan:lldb-595` levels outside the bundle. | Verify the remaining bundled routes and source behaviour. Keep imported content open-ended under per-engine and per-version support claims. See the [build 83 replay audit](ReleaseReadiness/2.0-build83/classic-fan-build83-replay.json), [package audit](ReleaseReadiness/2.0-build83/classic-fan-package-audit.json), [build 85 manifest comparison](ReleaseReadiness/2.0.2-build85/bundled-content-equivalence-recheck-2026-10-16.json), [2.0 build83/15 October engine-equivalence snapshot](ReleaseReadiness/2.0-build83/engine-content-equivalence-current-main.json) and [“Only practice” search](ReleaseReadiness/2.0-build83/classic-fan-only-practice-search-2026-10-16.json). |
| Lemmings 2 | Current-main replay passes all 120 standalone routes, 70 carry-over variants, twelve chains, event checks and the runtime suite against the staged build 83 app payload. The strict route gate was rechecked on 20 October at `4bf3bddc`. Every accepted chain reaches a Bronze talisman ending. Source captures support local sprite geometry but do not establish DOS tick alignment, continuous actor parity or full rendering fidelity. See the [20 October replay](ReleaseReadiness/L2CurrentSourceReplay-2026-10-20.json), [frame comparison](ReleaseReadiness/L2GameplayParity-2026-10-16/frame-comparison-001.json) and [current-main matcher output](ReleaseReadiness/L2GameplayParity-2026-10-16/walker-match-2590-current-main-2026-10-17.txt). | MVP route coverage passes. Keep source-engine fidelity and ending rules in engine closure. A 30-survivor Gold Ark route is a stretch goal, not an MVP blocker; do not run more maximum-rescue searches for release closure. See the [build 83 payload replay](ReleaseReadiness/2.0-build83/lemmings2-build83-payload-replay.json) and [current-main follow-up](Lemmings2Completion/ark-reconnection-search-2026-10-16-current-main.json). |
| Lemmings 3 | Current source passes the runtime suite and 399/416 fixtures against installed build 76 resources. Seventeen fixtures fail across levels 107, 206, 213 and 229. Route coverage is 86/90 standalone levels and 313/326 carried fixtures. The strict gate fails at `107.json` and `107-1.json`. The build 85 content comparison matches the build 76 resource tree. A direct resource hash link to build 93 remains open. | Close the four open route identities with one verified winning route per level, then verify one carried path per tribe. Keep other population fixtures as continuity checks. Do not target 50 survivors or optimise routes for closure. Verify Mole behaviour, source rules, environmental effects, movie audio, story transitions and recovery. See the [installed-resource fixture audit](ReleaseReadiness/L3MoleVerification-2026-10-15/current-bundled-fixture-audit-build76-4bf3bddc-2026-10-20.json), [Mole reconciliation](ReleaseReadiness/L3MoleVerification-2026-10-15/current-main-mole-reconciliation-4bf3bddc-2026-10-20.json), [level 206 searches](ReleaseReadiness/L3MoleVerification-2026-10-15/current-source-level206-search-4bf3bddc-2026-10-20.json), [seeded level 206 search](ReleaseReadiness/L3MoleVerification-2026-10-15/current-source-level206-seeded-search-4bf3bddc-2026-10-20.json), [Trolley-seeded level 206 search](ReleaseReadiness/L3MoleVerification-2026-10-15/current-source-level206-trolley-seed-search-4bf3bddc-2026-10-20.json), [wide level 206 search](ReleaseReadiness/L3MoleVerification-2026-10-15/current-source-level206-wide-search-4bf3bddc-2026-10-20.json), [level 213 search](ReleaseReadiness/L3MoleVerification-2026-10-15/current-source-level213-search-4bf3bddc-2026-10-20.json), [level 229 search](ReleaseReadiness/L3MoleVerification-2026-10-15/current-source-level229-search-4bf3bddc-2026-10-20.json) and [seeded Shadow 7 search](ReleaseReadiness/L3MoleVerification-2026-10-15/current-source-shadow07-seeded-search-4bf3bddc-2026-10-20.json), [wide Shadow 7 search](ReleaseReadiness/L3MoleVerification-2026-10-15/current-source-shadow07-wide-search-4bf3bddc-2026-10-20.json). The [velocity record](ReleaseReadiness/BundledClosureVelocity.md) separates search throughput from route closures. |
| NeoLemmix CE | The build 85 bundled-resource check indexes all 794 levels and resolves 719 through the 26 bundled DMA styles; the other 75 need 44 community styles. Exact-version winning replay evidence covers 158 levels. Build 86 records no non-localisation resource-index differences from build 85, but its full app audit was not rerun. | Keep all 794 levels in closure scope. Obtain rights for missing styles and verify every bundled route and source rule. See the [2.0.3 release record](ReleaseReadiness/2.0.3-build86/README.md), [2.0.2 resource check](ReleaseReadiness/2.0.2-build85/README.md), [build 84 content inventory](ReleaseReadiness/2.0.1-build84/neo-content.json) and [style rights inventory](ReleaseReadiness/2.0-build83/neolemmix-style-rights-inventory.json). |

The table tracks engine and content closure. It does not certify a specific
app archive. Release packaging, platform acceptance and distribution need their
own records. The current Classic fan result supersedes earlier 2,399/6,020
summaries and the failed-replay investigation below: two Amiga routes and one
Genesis Taxing route now replay as wins. The old search records remain historical
and do not describe the latest route status. See the [current-worktree audit](ReleaseReadiness/2.0-build83/classic-fan-current-main-audit-reconciled-2026-10-16/audit.json)
and its per-level [results](ReleaseReadiness/2.0-build83/classic-fan-current-main-audit-reconciled-2026-10-16/levels.jsonl).
The dated baseline and route-closure measurement method are in the
[bundled closure velocity record](ReleaseReadiness/BundledClosureVelocity.md).

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
above. See the [current-worktree audit](ReleaseReadiness/2.0-build83/classic-fan-current-main-audit-reconciled-2026-10-16/audit.json)
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
[release notes](https://github.com/ErikVeland/Lemmings/blob/364803556c5ebdcce8a6dbf636f5a93f74d76fff/Documentation/ReleaseNotes-1.9.4-build79.md).

The macOS 1.9.7 build 82 release consolidates the current shared controls,
performance, rewind audio, recovery and lettering improvements. Its universal
build and 53 release checks pass after the recorded repairs. Both public
packages are Developer ID signed, notarised and accepted by Gatekeeper. The
signed automatic-update feed and delta from build 81 are live and verified.
The owner explicitly approved the Apple and GitHub uploads on 15 October 2026.
Existing game classifications and the separate mobile/TV gates remain in force.
See the [release evidence](ReleaseReadiness/1.9.7-build82/README.md) and
[1.9.7 notes](https://github.com/ErikVeland/Lemmings/blob/364803556c5ebdcce8a6dbf636f5a93f74d76fff/Documentation/ReleaseNotes-1.9.7-build82.md).

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

## Sequel completion rule — 18 October 2026

The owner set the completion rule for Lemmings 2 and Lemmings 3. A sequel is
Complete when every bundled level has a winning route that the current native
engine replays exactly twice, and the campaign progresses with carry-over,
saves, recovery, replay identity and result records. Higher survivor counts,
talismans, endings and better scores are better completions. They do not block
the Complete classification. Source-fidelity work improves accuracy, but it
does not decide Complete or Beta. Fan levels keep their separate route work.

Lemmings 2 passes this route and campaign rule on the current checkout. Its
20 October replay verifies 120 standalone routes, 70 carry-over variants and
12 tribe chains. This does not close the bundled engine-fidelity target.
Lemmings 3 has 86 of 90 routes on the 20 October audit against installed
build 76 resource data.
Four levels remain open: 107 (Shadow 7), 206, 213 and 229. The audit verifies
399/416 fixtures. The strict campaign gate fails on `107-1.json`. Lemmings 3
stays Beta until the current-source route gate passes. See the
[gate register](ReleaseReadiness/gates.json) and the [20 October L2 replay
record](ReleaseReadiness/L2CurrentSourceReplay-2026-10-20.json).

## Wording

Three words carry the claims, and they mean different things.

**Complete.** Every level has a preserved winning replay that the native engine
reproduces. The gate fails if a replay is missing, altered, or stops winning.
A better score or ending is an improvement, not a requirement.

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

For bundled levels, the MVP route bar is one verified winning route per level.
Keep existing routes when they still pass. Build or verify a simple winning
route where coverage is missing. Do not spend effort on optimal routes, perfect
rescue counts or minimum inputs. A routine release checks existing evidence and
replays routes affected by engine or content changes; it does not regenerate
solutions across the full catalogue.

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
The exact bundled structural scan lists four route blockers. Three levels have
no exit object or trigger. A fourth requires 37 survivors from a population of
20. Current archive hashes match the structural-limit records. These levels
cannot meet the route gate with their current data. Keep them in the 6,020-level
count until their data or bundle status changes. See the [current structural
record](ReleaseReadiness/ClassicFanStructuralBlockers-2026-10-20.json).
The 21 October source check confirms that the decoder treats the 37 field as
an absolute rescue count. It does not convert the value to a percentage. The
authoring intent remains unverified, so keep the level open until an
authoritative corrected file or format rule is found. See the [source semantics
record](ReleaseReadiness/ClassicFan37of20SourceSemantics-2026-10-21.json).
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
| Lemmings 2: The Tribes | 120 | 20 October current-checkout replay: 120/120 routes, 70 carry-over variants and 12 full chains pass | **Complete** |
| Lemmings 3: The Chronicles | 90 | 20 October bundled-resource audit: 86/90 routes; levels 107, 206, 213 and 229 remain open | **Beta (route gate open)** |

These classifications track route and campaign completion. They do not close
the bundled engine-fidelity target.

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
  pass, but its ark ending remains open. The current L3 source audit verifies
  399/416 fixtures and 86/90 routes. The strict campaign gate fails on carried
  fixture `107-1.json`. L3 route repair, original-engine fidelity and release
  candidate checks remain open.
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
