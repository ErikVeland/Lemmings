# Bundled closure velocity

The 21 October merge combines the two Mole runtime changes. Earlier L3 trace
scores describe their recorded source snapshots. See the [merge validation](Release211ProgressionMerge-2026-10-21.md)
for the combined runtime and replay identities.

This record tracks the bundled-content MVP: one verified winning route for each
bundled level, plus source-behaviour evidence for each bundled engine. It does
not measure imported-content completeness. Imported content stays open-ended and
uses explicit engine, version, format and feature gates.

## Current scope snapshot — 21 October 2026

The solver and L2 work began at `99f92797b6dd200933761019fbb744327c0f77ba`.
The source tree, including the standalone solver adapter, is now committed as
`4bf3bddcb2641751eafd51b44a9cf29f18732c90`. A fresh fetch on 21 October
confirms that `HEAD`, `origin/main` and `FETCH_HEAD` match. The release status
and family counts below come from
[ReleaseScope](../ReleaseScope.md); they have different audit dates and are not
one synchronized full-catalogue run.

| Bundled family | Last accepted routes | Scope | Open routes | Evidence snapshot and remaining gap |
| --- | ---: | ---: | ---: | --- |
| Official Classic and Oh Yes! | 352 | 352 | 0 | 20 October current-source replay against the installed 1.9.1 build 76 resource tree; source-rule checks remain distinct from route coverage. |
| Classic fan packs | 2,404 (39.9%) | 6,019 playable (6,020 source rows) | 3,615 playable routes | 16 October full audit plus one targeted route closure on 21 October; the exact no-exit source row is excluded by owner decision. The full-catalogue gate and source-behaviour evidence remain open. |
| Lemmings 2 | 120 | 120 | 0 | 20 October current-checkout replay; 70 carry-over variants and 12 chains pass, but original tick, continuous-actor and full-render parity remain open. |
| Lemmings 3 | 86 | 90 | 4 | 20 October audit against installed Mac build 76 resources: 399/416 exact fixtures, 17 failures across levels 107, 206, 213 and 229. The build 85 comparison matches these 561 L3 files. A direct current 2.1 package hash check remains open. Mole parity, other source rules, media and transitions also remain open. |
| NeoLemmix CE | 158 | 794 | 636 | 17 October exact-version evidence; 75 levels still need styles and rights. |

The mixed-date total is 3,120 of 7,375 playable routes (42.3%), with 4,255
open. The source inventory retains all 6,020 fan rows; the playable scope
excludes one source row by owner decision. This
includes several content families. The Classic fan-family rate is 39.9%. Treat
the combined total as a scope summary only. The L2 Gold Ark is outside the MVP
route target. It is a stretch ending. L3 closure needs one
winning route for each open level and one complete carried path per tribe, not
50-survivor runs.

These family counts use different audit dates and are not one full-catalogue
run. The 20 October checks confirm current L2 routes and re-evaluate current L3
fixtures. Other route counts are older than the 2.1 source.
Build 93 preserves the checked content trees, but its source commit also changes
`ClassicDOSSimulation`, `Lemmings2Runtime`, `Lemmings3Runtime` and
`NeoLemmixSimulation`. Its five delta checks and content-hash comparison do not
replay all retained witnesses. The current release scope records this boundary
in [ReleaseScope](../ReleaseScope.md).

## Measured route velocity

The latest full Classic fan audit in [ReleaseScope](../ReleaseScope.md) is dated
16 October and records 2,403 of 6,020 source rows. Targeted work added no
accepted route by 20 October. One route passed two current-source replays on
21 October. The owner then excluded one exact no-exit row from playable scope,
so the current count is 2,404 of 6,019 playable levels. The snapshot rate is
one route over five calendar days, or 0.2 routes per day. This sparse rate is
not a forecast. The
L3 current-source audit retains 86/90 routes against installed build 76
resources and accepts no new route. There is no current-main rolling seven-day
audit series here, so no stable weekly rate or completion ETA is supported.

The 21 October route is `Propersision ZERO`, bundled member
`fan:lldb-189/Lemmings platinum Careful Part 2.dat#5`. The earlier solver build
found a route that saves 48 of the required 45 lemmings. The freshly built
current-source solver replayed the same inputs twice and returned the same win.
This closes one fan route. It does not refresh the full fan audit. See the [closure record](ClassicFanPropersisionZeroClosure-2026-10-21.json)
and the [saved route](../../Artifacts/ClassicProgression/verified-fan-replays/fan-lldb-189-propersision-zero.json).

The 21 October scope decision excludes `Choose your lucky PASSWORD!` from
playable bundled scope because its exact source has no exit object or trigger.
Its archive and audit row remain in source inventory. This removes one route
from the playable requirement and closes no route. The measured velocity stays
at one route over five calendar days (0.2 routes per day); this sparse sample
does not support an ETA. See the [scope decision](ClassicFanPlayableScopeExclusion-2026-10-21.json).

Two guide-seeded first-win continuations on L3 Egyptian 6 ran for 242 solver
seconds and expanded 2,066,220 states (about 8,538 states per second). Both
ended unsolved with zero saved lemmings. They used a narrow walkthrough-derived
prefix and did not attempt survivor optimisation or replay a level corpus.
The native trace then showed the Mole looping against terrain after the
built-brick trigger. The walkthrough is secondary evidence, and the headless
DOSBox attempt did not yield a valid actor trace, so this does not yet justify
a production Mole-rule change. L3 remains 86/90; this adds search throughput
but no route closure and does not change the sparse 0.2/day cross-family
snapshot rate or support an ETA. See the [Egyptian 6 search record](L3MoleVerification-2026-10-15/current-source-egyptian6-guide-searches-4bf3bddc-2026-10-21.json).

The current-source search for “Ball Bearing” ran for 120 seconds. It remained
at 8/80 and produced no route. The 5-second baseline and the “Ball Bearing”
search expanded 319,831 states over 125 seconds on the current build. The two
longer “Propersision ZERO” searches used the prior solver build. They expanded
451,740 states over 167 seconds and found the candidate. Across all four search
attempts, the total was 771,571 states over 292 seconds. These mixed-build
figures measure search throughput. One route passed current-source replay.
Search throughput does not predict future closures. See the [Ball Bearing record](ClassicFanBallBearingCurrentSourceSearch-2026-10-21.json).

I also rechecked the retained 8/9 near-win for “A TOWERING PROBLEM” against
the current build. The prefixed search stayed at 8/9. The from-start search
saved 4/9. A 120-second adaptive-rate search reached 8/9 but found no win.
Across these three searches, the solver expanded 333,380 states over 123
seconds. They closed no route. The accepted count remains 2,404/6,019 playable
levels. See
the [current-source search record](ClassicFanTowerCurrentSourceSearch-2026-10-21.json).

The 21 October fresh fetch confirms that `HEAD`, `origin/main` and
`FETCH_HEAD` all match `4bf3bddc`. The worktree is current with main.

The cached `.build/classic-fan-current/audit-output` is older than this baseline.
Its source revision is `fc2c59e6`, dated 15 October. It reports 2,399 fan wins,
3,600 smoke-tested levels and 21 failed replays. The figure 2,751 is the total
Classic count in that audit. It includes 352 official routes, so it is not the
fan count. Do not use this cached audit to replace the 16 October accepted
baseline. The 20 October `A Looooong Gap` searches added 783,030 states across
240 solver seconds and accepted no route. This is search throughput, not route
velocity. See the [continuation record](ClassicFanLongGapContinuation-2026-10-20.json).
The one-lemming MVP searches for `A Moonlight Stroll (Louise)` added 569,365
states over 180 solver seconds. They also checked 81 single-skill timings and
2,556 ordered-pair timings. No search found a winning replay. Across all nine
searches, the total is 1,352,395 states over 420 solver seconds, or about 3,220
states per second. The accepted route count remains 2,403/6,020. No new route
closure means no increase in measured route velocity. See the
[search record](ClassicFanMoonlightMVP-2026-10-20.json).

A bounded one-lemming sweep searched nine more bundled levels. Each had ten
seconds and a beam width of 2,048. The searches expanded 249,908 states over 80
solver seconds and found no route. One selected level was not searched because
its exact bundled file has one entrance and no exit object or exit trigger.
The 20 October structural scan listed four unplayable source cases: three had
no exit, and one required 37 saves from 20 lemmings. The 21 October decision
excludes one exact no-exit row from playable scope; the other three remain
active. The source inventory still contains 6,020 rows. See the [sweep record](ClassicFanOneLemmingSweep-2026-10-20.json)
and [structural blocker record](ClassicFanStructuralBlockers-2026-10-20.json).
The current decoder reads the 37 value as a count. The LLDB level page also
lists “Save 37 of 20” and marks the level unsolved. Its downloaded archive and
level-file hashes match the bundled solver resource. This confirms the source
data, not author intent or original-engine behaviour. Keep the level open until
an authoritative correction or format rule is available. See the [source
semantics record](ClassicFan37of20SourceSemantics-2026-10-21.json) and [LLDB
entry](https://lldb.camanis.net/level/386/2/Unnamed).

Across the 18 bounded searches on 11 exact levels in these records, the solver
expanded 1,602,303 states over 500 solver seconds, or about 3,205 states per
second. The accepted fan route count remains 2,403/6,020. These searches add no
route-closure velocity.

A further ten-second-budget search on bundled level 303, “Lemmings Of Mass
Destruction”, expanded 15,414 states in four solver seconds. It saved 0/8 and
found no route. Across the 19 recorded bounded searches on 12 exact levels,
the total is 1,617,717 states over 504 solver seconds, or about 3,210 states
per second. The accepted fan count remains 2,403/6,020. This increases measured
search throughput; route-closure velocity remains zero. See the
[level 303 search record](ClassicFanTWPak01MVP-2026-10-20.json).

The level 101 search used a Mole-probe resource variant. Its level DAT differs
from the installed bundle, so the result does not count toward bundled route
progress. See the [excluded probe record](L3MoleVerification-2026-10-15/mole-probe-level101-search-4bf3bddc-2026-10-20.json).

### 20 October current-source route refresh

The L2 strict gate passes 120 standalone routes, 70 carry-over variants and
all 12 tribe chains on current checkout `4bf3bddc`. It also passes strict
negative cases. The accepted route count remains 120/120, so this recheck adds
no route closure. The Gold Ark stays outside the MVP route target. See the
[run record](L2CurrentSourceReplay-2026-10-20.json).

The full official Classic and Oh Yes! gate passed against the installed 1.9.1
build 76 resource tree. All 352 routes passed, then the full quest passed 1,056
recovery points, 352 progress resumes and six chapter transitions. This is a
current-source route recheck, not a new route closure or a 2.1 build 93 app
audit. See the [run record](OfficialClassicCurrentSourceReplay-2026-10-20.json).

The L3 audit also used the installed 1.9.1 build 76 resource tree. The build 85
comparison matches that tree. Build 93 records no content differences from
build 2.0.7, but this audit does not link build 2.0.7 to build 76 by file hash.
The current runtime suite passes. The strict route and campaign gate fails on
`107.json` and `107-1.json`.

I also searched two untouched Classic fan levels for one MVP route each. Three
bounded searches on “All with 0 and 1” expanded 473,536 states. Two searches
on “Let’s climb!” expanded 300,632 states. None produced a route. The exact
identities, profiles and results are in the [continuation record](ClassicFanMVPContinuation-2026-10-20.json).

### 20 October `A TOWERING PROBLEM` probe

I rebuilt `ClassicSolver` from current main with
`zsh Scripts/build-classic-solver.sh` and checked the exact bundled archive and
level hash against the retained 16 October audit. A saved four-command prefix
reaches 8/9 saved. I ran 72 targeted Builder timing and worker probes across
70 distinct combinations. Two first-Builder workers reproduce an 8/9 near-win;
no tested combination wins. An adaptive release-rate continuation expanded
92,587 states over 32 solver seconds and reached a best partial of 3/9. Neither
result closes the level.

The 72 targeted variants expanded 35,213 states. The separate bounded beam
continuation expanded 92,587 states. A second 60-second continuation ranked
direct exit and rescue-quota distance, expanded 91,916 states, and did not
recover the retained 8/9 near-win. This work accepted zero routes. These are
solver throughput measures, not route-closure velocity. The [run record](ClassicFanTowerContinuation-2026-10-20.json)
contains the exact level identity, input prefix, result counts and hashes. A
bounded `UNSOLVED` result does not show that a level is impossible.

### 20 October `The Reflection` continuation

I replayed the retained two-command prefix for `fan:lldb-345/MARSHY01.DAT#4`
against the current-main archive and solver. The 30-second, width-1,024 search
expanded 81,327 states and reported 0/40 saved. The historical 35/40 partial
does not reproduce under this current-source profile. The level remains open;
this bounded result does not show that it has no solution. See the [run record](ClassicFanReflectionContinuation-2026-10-20.json).

Across these six exact fan levels, the focused work accepted zero routes. The
retained records contain 72 Builder probes across 70 distinct configurations,
ten bounded beam continuations and 1,395,757 expanded states. The latest
current-source pass searched two levels in `fan:lldb-412`, expanded 320,546
states over 108 solver seconds (2,968 states per second), and found no saved
lemmings on either level. This is solver throughput, not route-closure
velocity. The accepted-route count stays unchanged at 2,403/6,020. See the
[additional level searches](ClassicFanMVPContinuation-2026-10-20.json).

A separate first-win sweep searched 12 more unresolved fan levels with a
five-second budget and beam width 512. It expanded 180,118 states in 60 solver
seconds, about 3,002 states per second, and found no winning route. The best
partials were 8/80 on “Ball Bearing” and 1/45 on “Propersision ZERO”. They are
search leads only. The accepted route count remains 2,403/6,020. See the
[12-level sweep record](ClassicFanMVPFirstWinSweep-2026-10-20.json).

“Frozen in the airport” needs one saved lemming for MVP. Two beam searches
expanded 905,865 states over 300 solver seconds and saved 0/1. A third,
progress-first search focused assignments on the first worker and also saved
0/1. A complete single-skill sweep checked 8,432 assignments through waiting
tick 540. Two timing sweeps checked 205,881 floater/builder and
builder/floater assignments through tick 200. None found a winning route or
produced a replay candidate.
These bounds do not prove that the level has no solution. See the
[continuation record](ClassicFanFrozenAirportContinuation-2026-10-20.json).

The low-quota sweep also found “Lomax and Jimmy” (2 saves required). A
120-second, progress-first search focused on the first two workers and expanded
348,775 states; it saved 0/2. No replay candidate or route closure resulted.
See the [continuation record](ClassicFanLomaxJimmyContinuation-2026-10-20.json).

### 20 October `Ball Bearing` continuation

The earlier first-win sweep included `fan:lldb-283/GARJEN03.dat#2` with a
five-second budget. I confirmed its exact 80/80 rescue target and ran a
120-second search with width 4,096, progress-first ranking and rescue-quota
distance. It expanded 304,681 states and retained an 8/80 partial. It produced
no replay candidate. The accepted fan count stays 2,403/6,020, with 3,617 open.
This adds 2,540.7 solver states per second, not route velocity. The observed
snapshot rate remains zero accepted routes per day across 16–20 October. See
the [continuation record](ClassicFanBallBearingContinuation-2026-10-20.json).

### 20 October `Execution Style` first-win search

The bundled member `fan:lldb-341/JM15.DAT#5` requires one of 20 lemmings to
survive. An adaptive beam search, a continuation from its partial input list, a
4,272-assignment single-skill sweep and all six ordered pairs among floater,
basher and digger found no winning route in the tested timing windows. The pair
sweeps tested 4,918,348 second assignments over 224 solver seconds. Across all
nine searches, the solver expanded 4,922,739 states, about 21,977 states per
second. This is search throughput only. No route candidate passed replay, so the
accepted fan count remains 2,403/6,020 and the open count remains 3,617. These
bounds do not prove that the level has no solution. A nominal rate-30 control
was excluded: the runtime clamps the rate to this level's encoded minimum of
99, so it did not test slower releases. See the
[search record](ClassicFanExecutionStyleMVP-2026-10-20.json).

The initial 20 October route searches used the runtime before the cycle-12 Mole
change. They verified 86/90 standalone routes and 313/326 carried fixtures.
Seven bounded searches across the four open levels found no route. Level 206 searches expanded 1,751,877
states from the start, 1,649,985 from its retained prefix and 3,963,125 with a
wider beam. Level 213 expanded 1,043,609 states, and level 229 expanded
1,404,327 states. Seeded Shadow 7 expanded 763,437 states. A wider Shadow 7
search expanded 942,577 states in 124 seconds. These runs used 1,020 budgeted
seconds and expanded 11,518,937 states. They closed zero routes. A separate
level 101 Mole-probe search used different data, so it does not count. See the
[excluded probe record](L3MoleVerification-2026-10-15/mole-probe-level101-search-4bf3bddc-2026-10-20.json).
The [resource reconciliation](L3MoleVerification-2026-10-15/current-main-mole-reconciliation-4bf3bddc-2026-10-20.json)
records the three changed probe files and the unverified build 76 to 2.1
resource hash link.
An additional level 229 trace confirms actor 2 lands at tick 1579 after the
retained tick-1560 spade input. The Walker and Jumper assignments are accepted
when moved to landing. I then tested eight blocker timings in retained input
order; none produced a winning route. On Shadow 7, fourteen Jumper timings and
eleven combined builder/Jumper timings produce no saved lemmings by the
tick-2300 route boundary. These probes use the library hash from the
current-source completion audit. They add attempted work, not closures: the
L3 count stays 86/90 and the
observed route velocity stays zero accepted routes. See the [229 retiming
record](L3MoleVerification-2026-10-15/current-source-level229-retiming-4bf3bddc-2026-10-20.json)
and [Shadow 7 retiming record](L3MoleVerification-2026-10-15/current-source-shadow07-jump-retiming-4bf3bddc-2026-10-20.json).
The cached-main Mole baseline matched 139/329 left-facing positions and
179/344 air-gap positions. Its air-gap fall matched through tick 183, then
diverged at tick 184. The later cycle-12 result below supersedes this trace
baseline. These checks add evidence, not accepted routes. See the [current-source
reconciliation](L3MoleVerification-2026-10-15/current-main-mole-reconciliation-4bf3bddc-2026-10-20.json),
[bundled fixture audit](L3MoleVerification-2026-10-15/current-bundled-fixture-audit-build76-4bf3bddc-2026-10-20.json),
[level 206 search](L3MoleVerification-2026-10-15/current-source-level206-search-4bf3bddc-2026-10-20.json),
[level 206 seeded repair](L3MoleVerification-2026-10-15/current-source-level206-seeded-search-4bf3bddc-2026-10-20.json),
[level 206 wide search](L3MoleVerification-2026-10-15/current-source-level206-wide-search-4bf3bddc-2026-10-20.json),
[level 213 search](L3MoleVerification-2026-10-15/current-source-level213-search-4bf3bddc-2026-10-20.json),
[level 229 search](L3MoleVerification-2026-10-15/current-source-level229-search-4bf3bddc-2026-10-20.json)
and [seeded Shadow 7 search](L3MoleVerification-2026-10-15/current-source-shadow07-seeded-search-4bf3bddc-2026-10-20.json),
[wide Shadow 7 search](L3MoleVerification-2026-10-15/current-source-shadow07-wide-search-4bf3bddc-2026-10-20.json).

### 20 October source-derived Mole cadence

The L3 runtime now uses the captured 12-tick Mole movement cadence after a
vertical tunnel landing. The cadence is `1,1,1,1,0,1,2,1,1,1,2,4` pixels,
after an initial 2-pixel step. Grounded Mole movement follows the retained
2-1-1 check until this landing state begins. The focused runtime regression and
full L3 runtime suite pass.

The current-source air-gap trace matches 225/344 positions, up from 179/344 on
the cached `main` runtime and 193/344 on the earlier 2-1-1 candidate. The first
post-drop mismatch now occurs at tick 249. The left-facing trace remains
139/329. An isolated sweep of all twelve cadence phase offsets confirms that the
current offset is best: 225/344 matches through tick 248, with the next-best
variant at 201/344 and a first mismatch at tick 184. A simple phase shift does
not explain the remaining divergence. The probe scenes use modified level 101
data, so these results support source-behaviour investigation only. They do not
count as bundled scene or route closure. See the [phase sweep](L3MoleVerification-2026-10-15/current-cycle12-phase-sweep-4bf3bddc-2026-10-20.json),
[air-gap trace](L3MoleVerification-2026-10-15/current-cycle12-air-gap-4bf3bddc-2026-10-20.json),
[left-facing trace](L3MoleVerification-2026-10-15/current-cycle12-left-facing-4bf3bddc-2026-10-20.json)
and [cycle-12 audit](L3MoleVerification-2026-10-15/current-cycle12-audit-4bf3bddc-2026-10-20.json).

Adding the Mole patrol phase to replay state hashes made 203 winning fixture
identities stale. The derivation tool refreshed all 203. Each candidate passed
two replays before replacement. The post-refresh audit verifies 399/416 exact
double replays, no stale-identity wins and 17 failed schedules across Levels
107, 206, 213 and 229. L3 route coverage remains 86/90 standalone levels and
313/326 carried fixtures. The campaign manifest has 322 fixture hashes. The
strict completion gate still stops at `107.json` and `107-1.json`. See the
[post-refresh audit](L3MoleVerification-2026-10-15/current-cycle12-fixture-audit-4bf3bddc-2026-10-20.json).

This work accepted zero new routes. It adds no route-velocity interval. The
Classic fan snapshot rate remains zero routes per day across 16–20 October.
There is no supported completion ETA. A focused app-core recovery hash test
could not compile because an unrelated expression in `MacArrowWrapTests.swift`
exceeds the compiler type-check limit. The recovery hash now includes the Mole
patrol phase, but this test remains unverified.

A fresh NxlvKit build from this checkout reproduced the L3 strict-gate failures
at standalone level 107 and carried fixture 107-1. Both original input schedules
also fail when replayed under the current runtime with the initial hash
refreshed. The 322-entry manifest and refresh/negative checks pass. No route
closed; both schedules need replacement, not hash-only updates. See the updated
[cycle-12 audit](L3MoleVerification-2026-10-15/current-cycle12-audit-4bf3bddc-2026-10-20.json).

A separate carried-population search at population one expanded 150,061 states
in 120 solver seconds, with a best result of 0/1 saved. It found no route or
replay candidate. This does not prove the level is impossible. See the
[Level 107 population-one search](L3MoleVerification-2026-10-15/current-source-level107-pop1-search-4bf3bddc-2026-10-20.json).

A separate population-20 entrance search used paired actors, an 8,192-state
beam and two-pixel tool-site sampling. It expanded 862,829 states in 121
seconds and saved 0/5. It produced no route candidate. This also leaves the
standalone route open; see the [entrance search record](L3MoleVerification-2026-10-15/current-source-level107-entrance-search-4bf3bddc-2026-10-20.json).
Together, these two follow-up searches expanded 1,012,890 states over 241
solver seconds. Across the seven cycle-12 searches and these two follow-ups,
the total is 8,706,385 states over 1,088 solver seconds, about 8,002 states per
second. No route closed; this is solver throughput only.

A third follow-up increased the entrance-search beam to 16,384 while keeping
the other settings fixed. It expanded 810,923 states in 120 seconds and saved
0/5. Across all three follow-ups, the total is 1,823,813 states over 361
solver seconds. Across all ten cycle-12 and follow-up searches, the total is
9,517,308 states over 1,208 solver seconds, about 7,879 states per second. No
route closed; this remains solver throughput, not route-closure velocity. See
the [wider-beam record](L3MoleVerification-2026-10-15/current-source-level107-entrance-beam16384-search-4bf3bddc-2026-10-20.json).

### 20 October cycle-12 MVP route searches

I rebuilt the route solver against the current runtime and searched all four
open L3 route identities. Each search used the first-win MVP policy, a beam of
8,192 states, paired actors and two-pixel tool-site sampling. Two Level 107 searches and one Level 229 search continued retained prefixes
through ticks 1,666, 1,590 and 1,560. The other three searches started from
their level entrances.

The six baseline searches expanded 6,647,224 states over 726 seconds. Level 107
expanded 559,514 and 1,124,062 states in two seeded searches. Level 206
expanded 1,576,662 states from the start. Level 213 expanded 947,016 from the
start. Level 229 expanded 1,302,443 states from the start and 1,137,527 from
a retained prefix. None saved a lemming or found a route. They closed zero levels.
The accepted L3 count stays 86/90. These figures measure solver throughput,
not route velocity. See the [search record](L3MoleVerification-2026-10-15/current-cycle12-mvp-searches-4bf3bddc-2026-10-20.json).

A further Level 206 first-win search disabled paired actors and used a
16,384-state beam with two-pixel tool-site sampling. It expanded 1,454,392
states over 127 solver seconds and saved zero lemmings. It found no route and
produced no replay candidate. Level 206 remains open; the result does not show
that the level has no solution. The [single-actor record](L3MoleVerification-2026-10-15/current-cycle12-level206-single-actor-search-4bf3bddc-2026-10-20.json)
keeps this throughput separate from route velocity.

A seeded search used the retained Level 206 Trolley witness through tick 441.
It expanded 965,040 states in 92 solver seconds and saved zero lemmings. It
found no replay candidate. Level 206 remains open, and the accepted L3 count
stays 86/90. This adds solver throughput, not route-closure velocity. See the
[seeded search record](L3MoleVerification-2026-10-15/current-source-level206-trolley-seed-search-4bf3bddc-2026-10-20.json).

### Solver build support

The standalone solver build now has a local adapter for fan-progress identity
and storage. The route solver does not read or write player progress. This keeps
the search tool buildable with the current `FanLevelLibrary` dependency without
changing app persistence or engine rules. The repository build script passed.

## Measurement rules

- Count a route closure only after the current engine accepts the same winning
  replay twice against the exact bundled level hash. Label incremental counts
  separately from the date of the last full-catalogue audit.
- Keep route closures separate from engine-rule parity, assets, rights,
  campaigns, media, saves and release acceptance.
- Report candidate timings, expanded states and solver time separately from
  accepted route closures. Never infer a rate from commits or elapsed work
  alone.
- Use fresh family audits when a source or content change can alter witnesses.
  Do not replay the whole catalogue for routine updates.
- Keep imported levels outside the finite bundled denominator.

A seventh search varied the Level 213 beam width to 16,384. It expanded 1,046,271 states in 121 seconds and saved no lemmings. Across the seven runs, the total is 7,693,495 states over 847 solver seconds, or about 9,083 states per second. This is solver throughput only. The L3 route count remains 86/90 and no route-closure interval was observed. See the [updated search record](L3MoleVerification-2026-10-15/current-cycle12-mvp-searches-4bf3bddc-2026-10-20.json).

## Historical feature-branch work — 20 October 2026

The following records describe the feature branch before this merge. Their
route totals and runtime trace scores are historical snapshots. Use the current
scope snapshot above for accepted progression counts. Search throughput does
not add route closures. The combined Mole runtime needs a fresh replay audit.

## 20 October audit refresh

A fresh fetch confirms that `HEAD` and `origin/main` both resolve to
`440caebd886ec35d512137e2aa82c6b610d13141`. The current-source L3 audit checked
all 416 retained fixtures: 399 replayed twice exactly, none won after rebasing,
and 17 schedules failed. The failures remain four standalone levels and
thirteen carried schedules for those levels. The standalone route count stays
86/90. The audit library matches the rebuilt current-source library SHA-256
`a60fa080713052a35aa152c63861255d39e7c5d9148e1882f7f7c67eff9fe963`; the
runtime source SHA-256 is
`cdf4e0f0625f36b7e1be8d7059514d6679270b270c5b2627ed8aa3c1e313cdf0`.

The strict carried-campaign verifier stops at `107-1.json`, which ends at tick
9,660 with zero saved and two lost. The full campaign chain and its first gap
remain unverified. This refresh changes no family route count.

The runtime and library hashes above predate the later 20 October timing
correction recorded below.

## 20 October velocity checkpoint

The latest accepted Classic fan count remains 2,403/6,020. This is 39.9%,
with 3,617 routes open. The latest full route audit is dated 16 October. The
17 October reconciliation and work recorded through 20 October changed no
route count. The observed net rate between the 16 and 20 October snapshots is
zero routes over four calendar days, or zero routes per day. This is a sparse
snapshot rate, not a forecast.

The 20 October structural scan covered all 6,020 bundled fan records without
replaying them. It found three positive-quota records with no active exit:
`fan:lldb-437/LDChallenge08.dat#1`,
`fan:lldb-508/KillerMaster 1 Wicked 1.dat#3`, and
`fan:lldb-509/KillerMaster 1 Havoc 2.dat#7`. Searches of the public database
and local Downloads and Documents folders found no authoritative source copy
for these exact records. No content was changed. The records remain open until
their source can confirm whether the missing exits are intentional or defects.

This checkpoint accepted zero routes. It adds source-content blockers to the
work list, not to the route-search denominator. The solver cannot close these
records while the bundled data has no exit trigger.

### 20 October bounded Classic fan search

I searched the exact bundled member `fan:lldb-3/Anatol00.dat#8` (“Crystmas”).
The level has 40 Lemmings and needs 38 saved. The archive SHA-256 is
`69b7e2e0e7acd0be7f709333e5bdf05749719d47796966d6f461661ee429861f`, which
matches the retained current-main audit input. The solver SHA-256 is
`3a66736309167422c33eda25298050abd135f3d733958900fffca59777d1f134`.

Four 60-second, beam-2,048 searches used the Golems clock, 30-tick fallback and
refire, quota-distance ranking, and progress-first ranking. They tested the
native rate of 1, adaptive rate, fixed rate 99, and a forced-prefix continuation
from the best adaptive partial. They expanded 656,736 states in total. None
saved a Lemming or found a win. The continuation released 36 Lemmings by tick
194, then ended without a saved Lemming. The route remains open.

This batch accepted zero routes in 240 solver seconds. It does not prove that
the level is impossible. Candidate partials and the forced prefix remain under
the ignored `.build/fan-velocity-20261020/` directory. The [run record](ClassicFanCrystmasSearch-2026-10-20.json)
retains per-search counts and hashes.

### 20 October follow-up searches

I ran fourteen more bounded searches across exact bundled identities. The batch
covered eight untried levels with an eight-second limit each. Three separate
probes covered “The Lemming Avalanche” and “The Pendulemming”. Three more
covered “A home up high” at its native rate, at rate 99, and with a single-skill
sweep. None found a win. The last sweep reached its 60-second limit after 2,403
of 2,404 continuations, so that sweep is incomplete.

These searches expanded 588,101 states in 289 reported solver seconds. They
accepted zero routes. “A home up high” released 26 Lemmings at rate 99 but saved
none of the 40 required. “The Lemming Avalanche” saved none of its 20. No route
count changed. The [targeted search record](ClassicFanTargetedSearch-2026-10-20.json)
retains the exact identities, input hashes, partial hashes and per-run results.

## Historical route-count movement

| Family | Earlier snapshot | Later snapshot | Net change | Measured interval |
| --- | ---: | ---: | ---: | --- |
| Classic fan packs | 2,399 on 15 Oct | 2,403 on 16 Oct | +4 | One day |
| Classic fan packs | 2,403 on 16 Oct | 2,403 on 17 Oct | 0 | One day |

The four-route increase included accepted retained candidates and replay
reconciliation; it is not a clean measure of newly discovered routes. The
17 October search batches added no verified wins. These source dates are
historic snapshots, not a continuous measurement series. They do not support
a delivery-date forecast. Zero-yield search batches are not the velocity of
all prior work.

### 19 October bounded batch

Using the current solver built at `364803556c5ebdcce8a6dbf636f5a93f74d76fff`,
I searched three unresolved exact fan identities selected from the retained
6,020-level audit. The run used a 2,048-state beam, a 30-second limit per
level, rescue-quota distance, progress-first ranking and partial-route output.
It expanded 232,481 candidates in 93.5 seconds of solver time. None won, so no
strict replay or route closure was available. The fan count remains 2,403/6,020
and the open count remains 3,617.

| Exact bundled identity | Search result |
| --- | --- |
| `fan:lldb-457/LeviOtherLevels.dat#0` — How to evacuate a gold mine? | 4/78 saved; partial retained |
| `fan:lldb-237/JEFFPCK3.DAT#7` — Upside-down Exit?? | 0/80 saved |
| `fan:lldb-329/JM03.DAT#3` — Caught in a trap | 0/60 saved |

These are bounded search failures, not claims that the levels are impossible.
This batch's measured route-closure rate is 0 wins per 93.5 solver seconds.
It is one small sample and must not be used alone as the forecast for the full
corpus. The attempt ledger and partial replays are retained under the ignored
`.build/fan-velocity-20261019/` directory for follow-up.

This search ran before the worktree fast-forwarded from `364803556` to current
`main`. A source comparison confirms that the intervening commits changed no
Classic engine or `ClassicSolver` source. The count and search outcomes remain
valid; future searches use a solver built from `a851d357`.

### 19 October L3 route follow-up

I ran bounded timing probes against the exact bundled fixtures for Shadow 7
and Egyptian 13. The probe tested 580 timing variants for Shadow 7 and 506 for
Egyptian 13. Neither probe found a winning route. These results leave all four
open L3 level identities unresolved.

The current L3 verifier also rejects the Egyptian 6 fixture. It expects 11
saved, but the replay ends at tick 9,660 with zero saved and 11 lost. A wider
timing sweep did not finish within about 150 seconds, so I stopped it without a
candidate count or a search result. This is an incomplete attempt, not a
no-win result. The earlier source discovery checks returned no fixture for any
of the four open identities.

This follow-up accepted **zero** routes. The measured timing probe total is
1,086 tested variants with no wins across Shadow 7 and Egyptian 13. The
Egyptian 6 baseline fixture also fails, but its interrupted sweep is excluded
from that candidate count. The L3 route count remains 86/90. The exact
current-source verifier and fixture audit remain the closure gates.

### 19 October follow-up

The worktree was fast-forwarded to `440caebd` after a fresh fetch. The two new
main commits change release records and the update feed. They do not change
Classic simulation or solver source. The fan route evidence remains the
16 October audit at 2,403/6,020. No later full audit has verified a new route.

I continued with the gold-mine level because its partial route and public
community notes point to a blocker-turning basher trick. Two bounded beam-8,192
searches had a 180-second limit each. They tested (1) the tick-119 blocker
prefix and (2) that prefix plus the tick-137 basher. They expanded 451,146 and
396,566 candidates. The best partials saved 10/78 and 40/78. Neither search
won. A third search tested the earlier three-skill partial and also did not
win. These are bounded search results. They do not show that the level is
impossible.

I added `testBlockerTurnsBasher` to the Classic simulation regression runner.
It checks that a basher turns at a blocker field and keeps bashing. The
regression passed on 19 October after the fast-forward. This confirms the
tested engine behaviour. It does not provide a complete level replay or close
the route. The regression runner took 20.74 seconds, including the 120-level
campaign soak. This is validation time, not route-solving velocity.

The measured route-closure result for this follow-up is **zero**. The retained
count is still 2,403/6,020, with 3,617 routes unverified. This is route closure
velocity, not general engineering throughput. The 16 October audit is the last
full-corpus measurement, so no precise day-by-day rate or completion forecast
is supported.

I also checked the public level-104 replay linked in the
[LemmingsForums discussion](https://www.lemmingsforums.net/index.php?topic=5963.15).
Its title and author match the bundled gold-mine level. Its recorded game is
the Revenge of the Lemmings Outtakes pack, with NeoLemmix level ID
`xAB8EDD40AB8EDD40` and version 3. Those fields do not identify the Classic
DAT member. I translated its skill and release-rate commands into a forced
Classic prefix. The source nuke command is not supported by the solver prefix,
so this did not test the full replay.

I then replayed all six commands, including the nuke, against the bundled
`LeviOtherLevels.dat#0` member. The Golems run passed the exact initial-state
and level-fingerprint checks, then ended at tick 2,706 with 0/78 saved. The DOS
clock run also saved 0/78. The earlier forced-prefix searches used the Golems
clock for 60 seconds and the DOS clock for 30 seconds. They expanded 169,238
and 85,250 candidates, respectively, and also saved 0/78. These results reject
this replay as a route for the bundled Classic DAT. They do not reject it for
its recorded Outtakes level. The source replay and translated prefix remain in
the ignored `.build/fan-velocity-20261019/external-references/` directory.

### 20 October L3 rerun

I repeated the probes against `Sources/Ports/LEM3CD`, the current bundled data
in this checkout. The exact-source verifier reproduces the known failures:
Shadow 7 saves 0/11 at tick 2,300; Egyptian 6 saves 0/11 at tick 9,660;
Egyptian 13 saves 0/11 at tick 4,140; and Egyptian 29 rejects input 6 at tick
1,561.

The wider retiming run tested 580 variants for Shadow 7 and 3,741 for Egyptian
13. Both returned no win. A targeted search varied the four commands around
Egyptian 29's rejected input and tested 417 variants. It found no win. The
Egyptian 6 retiming run remains incomplete and has no candidate count.

This rerun tested **4,738 timing variants and accepted zero routes**. The L3
count remains 86/90. The current solver run did not test all possible routes,
so these results do not show that the levels cannot be solved.

### 20 October Egyptian 6 trigger-site batches

I followed the documented Egyptian 6 sequence and tried twelve fixed vertical
brick trigger positions from x=136 through x=296 in two bounded batches. Ten
positions placed a brick and triggered the Mole. All ten produced a down-left
tunnel. Two positions were not reached because the leader crossed the false
exit first. A tick trace shows the Mole starts at x=160 moving right; the
leader reaches the candidate sites between ticks 1,070 and 1,214. A temporary
source-linked harness against the bundled `LEM3CD` data ran these attempts; it
did not change the runtime or retained fixture.

I then added one extra circuit on the upper platform before placing the
vertical brick. Six trigger-site variants changed the Mole trigger to
down-right. At x=176 and x=180, the leader fell to the y=104 platform; at
x=184, it reached y=112. It did not reach the Spade pickup at x=56,y=220. The
trapped lemming remained near x=111,y=260. Jumping from the x=184 path and
placing a down-left brick at its left edge did not reach the Spade. All six
variants ended with zero saved.

Across the trigger and continuation work, **21 Egyptian 6 route variants
produced zero closures**: ten single-pass placements triggered down-left, two
did not reach their sites, six repeated-loop placements triggered down-right,
and three follow-up movement variants did not reach the Spade or an exit. The
down-right segment is progress in route diagnosis, not a winning replay. Two
isolated tunnel-clearance prototypes also failed to save a lemming: widening
the excavation to 16 pixels led the leader off the right edge; clearing the
full 18-pixel Mole body height lost the released population. Neither prototype
changed worktree source. The remaining gap runs from the tunnel opening
through the Spade and trapped-lemming sequence to a lower exit. The L3 route
count stays 86/90.

### 20 October Egyptian 29 route probes

The retained Egyptian 29 replay turns the leader back near the Hadoken pickups.
That route collects Hadokens before the Grenade stack. The level data places
eight Grenade pickups at x=112,y=352 and eight Hadoken pickups at x=152,y=360.
The runtime gives a lemming a new pickup only when it has no tool or the same
tool, so this order matters.

I tested nine bounded movement and blocker variants. Removing the early
turn-back walker command let the leader collect 32 Grenade charges before the
Hadoken location. A blocker command at tick 1980 was accepted. The replay then
used the remaining recorded Grenade and rescue commands, but saved zero and
lost twelve lemmings before its abort at tick 3191. Other blocker timings were
rejected while the leader jumped or ended with nineteen losses. These results
show a valid pickup segment. A ninth probe turned the leader right before the
first throw. All recorded commands were accepted, but the replay still saved
zero. These results do not show a winning route or an engine defect. The L3
count remains 86/90.

I then tested fifteen more variants. These included continued movement to the
right, four blocker timings, jump timing, and the earlier two-Spade route with
three exit approaches. None saved a lemming. In the right-facing Grenade
attempts, the projectile hit the ledge and later burst behind it. A published
[walkthrough](https://www.deinonych.com/lemmings/lemmchronegyptian_walk.shtml)
uses repeated Grenade throws to open that ledge. The runtime marks Grenade
trajectory and blast radius as provisional. This is a source-parity lead, not
proof of a defect. Compare a headless original-engine trace before changing the
runtime. This brings the Egyptian 29 probe total to twenty-four variants with
zero route closures.

One more probe followed the old two-Spade opening with a Walker, Jumper and a
third downward Spade at tick 2,000. The leader reached y=392 but stayed near
x=195 and saved no lemmings by tick 9,660. This was the twenty-fifth variant.

This work window accepted **zero** routes. The Classic fan count remains
2,403/6,020 (39.9%, with 3,617 open). The two latest recorded daily Classic
snapshots, 16 and 17 October, show no net accepted-route increase. The route
corpus has not been re-audited, so the snapshots do not support a current
full-project completion date.

From the last full Classic fan snapshot on 17 October through 20 October,
recorded route work accepted zero new wins across the bundled families. The
observed closure velocity for this three-day evidence window is 0 routes per
day. This is an attempt-stream measure, not a new full-corpus audit or a basis
for an ETA.

### Confirmed velocity at 20 October

The latest seven-day evidence window confirms **zero** new route closures. This
is a confirmed-evidence rate, not proof that no unrecorded work happened: the
latest full Classic audit is dated 16 October, with its 17 October
reconciliation unchanged, and the latest L3 audit is dated 20 October. The
20 October Egyptian 6 batches accepted zero of twenty-one route variants.
The Egyptian 29 probes accepted zero of twenty-five variants.
Across these two Egyptian levels, the recorded route and control probes total
forty-six with no wins. The separate 4,738-variant timing batch also found no
winning replay.
There is no supported ETA until new accepted routes and a fresh
family audit establish a sustained rate.

### Current work window

This work window accepted **zero** bundled route closures. Classic fan
coverage remains 2,403/6,020 (39.9%), with 3,617 levels open. The latest
verified fan audit remains dated 16 October, with its 17 October reconciliation
unchanged.

Engine evidence advanced separately. The 20 October Mole timing correction
raised exact position matches from 139/329 to 146/329 for the left-facing trace
and from 179/344 to 186/344 for the air-gap trace. This adds seven matching
positions to each trace. It does not close a level or change the L3 route count
of 86/90. The runtime suite passed, but the traces remain partial evidence of
Mole behaviour.

The current continuation rechecked the source actor-memory samples and
reproduced both trace counts: 146/329 and 186/344. The tick-15 source position
advances four pixels while the recorded animation ID stays at 27; the runtime
does not make that same move on that tick. This supports an early patrol
cadence gap, but is not enough evidence for a broad physics change. The check
accepted zero routes and ran no route search. Route velocity for this work
window remains zero closures; the engine-trace result is tracked separately.

A second source check found 31 Mole animation records and 174 decoded frames
in the bundled `CREAT002.IND` bank. The captured animation values could be
flattened frame indices, but the source capture does not prove this. The mobile
renderer currently chooses only animation 0 or 1 by direction and advances by
creature age. I recorded this as an open rendering-parity question; no route
count or route velocity changed.

I then searched one low-score, untried fan identity: `fan:lldb-305/TWPAK03.dat#0`,
“Revenge Of The Evil Gardener”. The 10-second, width-512 native-rate Golems
search expanded 27,629 states and saved zero of the 20 required Lemmings. It
accepted zero routes. This batch measured zero closures in 10 solver seconds;
the route count remains 2,403/6,020. The [run record](ClassicFanContinuationSearch-2026-10-20.json)
retains input hashes and the partial result. This bounded failure does not show
that the level is impossible.

I then searched six more low-score, untried exact identities from the bundled
fan pool. The batch expanded 110,505 states in 40 reported solver seconds.
None saved any Lemmings; one level required only one save and ended after 101
expansions without a win. I followed that one-save level with a completed
fixed-rate single-skill sweep of 4,272 assignments; it also found no win. The
batch accepted zero routes. Combined with the
single-level probe above, this continuation totals zero closures in 50
reported solver seconds. Classic fan coverage remains 2,403/6,020, and the
observed 16–20 October calendar-day rate remains zero closures per day. These
short searches are not an ETA or evidence that the levels are impossible. The
[batch record](ClassicFanContinuationBatch-2026-10-20.json) lists all six
identities, archive hashes, partial hashes and the follow-up sweep.

### 20 October targeted Classic fan search

Before this batch, the retained low-confidence search input contained 3,546
unresolved identities with no matching attempt in the available local ledgers.
I searched three exact members from pack `fan:lldb-437`: `LDChallenge08.dat#2`
and `#3` had 30-second, width-2,048 searches. `LDChallenge08.dat#1` had a
60-second, width-8,192 search with 30-tick fallback and refire intervals. The
searches expanded 85,309, 81,585 and 177,269 candidates, 344,163 in total.
None found a winning replay. This batch accepted zero routes and does not show
that these levels are impossible. The exact `LDChallenge08.dat#1` description
contains one hatch and no exit trigger. Treat that result as a source or loader
parity lead before spending more search time on this member.

The solver executable hash was
`3a66736309167422c33eda25298050abd135f3d733958900fffca59777d1f134`. The
retained build record identifies it as a current-main build. The subsequent
main commits did not change Classic simulation or solver behaviour. The full
attempt ledger and partial replay remain under the ignored
`.build/fan-mvp-20261020/` directory. The fan count remains 2,403/6,020.

I then scanned the structure of all 6,020 current bundled fan entries. The scan
found 54 records without an active exit trigger and no load errors. Fifty-one
have a zero rescue requirement and already have winning replay evidence. The
other three require saves, contain only a hatch object, and have no winning
replay evidence. This identifies a source-content blocker in `LDChallenge08`,
`KillerMaster 1 Wicked 1` and `KillerMaster 1 Havoc 2`. The scan replayed no
levels and accepted zero routes. Full details and source hashes are in the
[exit-structure audit](ClassicFanExitStructure-2026-10-20.json).

### 20 October focused L3 route searches

I searched each open standalone identity against the current bundled `LEM3CD`
data at `440caebd`. All four searches used a 2,048-state beam and a 180-second
budget. Level 206 also used eight-pixel tool-site sampling and fewer-inputs-
first ranking. Levels 213 and 229 also used paired-actor branches.

| Level | Search setup | Expanded candidates | Result |
| --- | --- | ---: | --- |
| Shadow 7 (`107`) | Beam 2,048; default decisions | 1,230,662 | No win; best partial saved zero |
| Egyptian 6 (`206`) | Beam 2,048; eight-pixel tool-site sampling; fewer inputs first | 2,439,792 | No win; best partial saved zero |
| Egyptian 13 (`213`) | Beam 2,048; eight-pixel tool-site sampling; paired actors; fewer inputs first | 1,536,486 | No win; best partial saved zero |
| Egyptian 29 (`229`) | Beam 2,048; eight-pixel tool-site sampling; paired actors; fewer inputs first | 1,758,497 | No win; best partial saved zero |

The four searches expanded 6,965,437 candidates over 720 solver seconds. A
separate 180-second continuation from a source-guided Shadow 7 prefix expanded
398,360 more candidates and found no win. That prefix assigns Blocker to actor
2 at tick 570, starts a four-Brick vertical stack with actor 1 at tick 630, and
jumps at tick 680. The walkthrough describes the same Mole-triggering Brick
stack, but this native prefix is not original-engine proof. See the
[walkthrough](https://www.cheatbook.de/wfiles/lemmingschronicles.htm).

The complete batch expanded 7,363,797 candidates over 900 solver seconds and
accepted zero routes. The standalone L3 count remains 86/90. The current
runtime source SHA-256 is
`cdf4e0f0625f36b7e1be8d7059514d6679270b270c5b2627ed8aa3c1e313cdf0`; the
rebuilt solver and library SHA-256 values are
`e819a17f67920f162378da1832b3b1db65f31af3cc654fcc870f6b9e6aef322f` and
`a60fa080713052a35aa152c63861255d39e7c5d9148e1882f7f7c67eff9fe963`.
These bounded searches do not show that the levels are impossible.

### Shadow 7 route-seed follow-up

I traced three full vertical-stack prefixes. They continued building, jumped
right, or turned left before jumping. None saved a Lemming. A runtime trace
recorded the Mole and pickup positions. In one prefix, I assigned Walker at
tick 550 and an up-right Brick at tick 580. The Mole starts a down-right tunnel
at tick 605 near `(164,112)`. At tick 650, it reaches `(234,147)` and causes
three Spade boxes to fall. By tick 1,800, they are at y=156–160. By tick
2,600, they are at y=162–170. No Lemming collects them.

I swept 52 Brick timing and direction combinations through tick 2,600. None
saved a Lemming or completed the level. I then tried 18 jump timings from tick
590 to 760 and 34 Walker or Jumper timings from tick 800 to 1,600. None
collected a Spade. The runtime accepted 46 of these 52 scheduled actions.
I also tried 15 Walker-then-Jumper pairs from tick 600 to 740. The runtime
accepted three pairs, but none collected a Spade. These probes narrow the gap
to getting the lead Lemming to the Spades after the Mole reaches them. They do
not prove full Mole parity or show that the level is impossible.

I also placed a blocker after the initial Walker and Brick actions, then
released the group at ticks 900, 1,200, 1,600, 2,000, and 2,400. All five
inputs were accepted. Each replay ended at tick 3,500 with no saved or lost
Lemmings, no Spade pickup, and no level completion. Delaying the group release
did not close follower access in these five timings. An attempted original DOS
trace could not connect to the local DOSBox API, so this result uses the
current L3 runtime only.

This follow-up added zero accepted routes. The L3 rate remains zero verified
closures in the latest seven-day evidence window. Keep these diagnostic probes
out of the winning-route denominator.

### 20 October L3 level 229 retry

The retained route for level 229 first fails at input 6, a Walker assignment
at tick 1,561. I confirmed that the complete local L3 resource set contains
the fixture's exact level-data hash. The focused state-hash, campaign-manifest
and replay-refresh checks passed. The fixed discovery policies found no route.
I then shifted only the four actions at ticks 1,560–1,563 by each uniform
offset from -10 to -1 and +1 to +10. None of the 20 variants won. No fixture
changed. A second set kept the down-use at tick 1,560 and delayed the two
Walker actions and Jumper by 1–20 ticks. None of those 20 variants won either.
Level 229 remains open. These attempts added zero accepted routes.

The first 20 October L3 Mole trace rebuild matched 139/329 left-facing
positions and 179/344 air-gap positions. A later source-driven timing change
and its updated comparison are recorded below.

A live main-branch refresh was not available in this environment: Git could
not write the shared worktree's `FETCH_HEAD`, and `git ls-remote` could not
resolve GitHub. The local `HEAD` and `origin/main` refs still match
`440caebd886ec35d512137e2aa82c6b610d13141`; the remote tip was not confirmed
in this retry.

### 20 October original-engine inspection

I started the bundled Lemmings 3 DOS executable in DOSBox Staging with dummy
video and audio output and a read-only game-data mount. The local API returned
CPU and video-memory snapshots. The DOSBox log showed transitions through
320x240 and 320x200 graphics modes. This inspection did not capture a
controlled gameplay trace or identify Mole state, so it does not support a
runtime change or a parity claim.

This was engine investigation, not a route search: it tested zero route
candidates and accepted zero routes. The L3 route count remains 86/90. Since
there was no route-search denominator, this session does not define a
time-based route-closure rate. No production source or retained route fixture
changed.

### 20 October source-supported Mole timing correction

The retained original actor trace shows the Mole settle two pixels onto solid
ground at tick 7. The source holds its steel-contact reaction through ticks
26–35 and begins diagonal movement at tick 36. The runtime now applies that
settle when solid ground is below the Mole, avoids a second two-pixel offset
when its feet are already on solid terrain, and uses a ten-tick reaction
cooldown.

The current-source comparison improved from 139/329 to 146/329 left-facing
positions and from 179/344 to 186/344 air-gap positions. Both cases still
first differ at tick 2. Shared tunnel positions match at ticks 36–153 and
173–187 for the left-facing case, and through tick 183 for the air-gap case.
The current source SHA-256 is
`0525d7a013ff78343b8875c83374017db08674e21e0050470282637900c90e37`; the
trace library SHA-256 is
`77bf4cba294553f576d4a8801cccf4fa4fdb849aad12f09be42fe2ac7abd1da6`. Full
trace hashes are in the [current trace record](L3MoleVerification-2026-10-15/current-main-mole-trace-2026-10-20.json).

The headless L3 runtime suite passes. A fresh audit of 416 retained fixtures
found 393 exact double replays, six level-113 fixtures that still won twice
with stale state hashes, and the same 17 failing schedules. I refreshed the
six state identities from two successful replays each. Their route inputs did
not change. This leaves 399 exact double replays and the same 17 open route
scenarios. The campaign manifest validates hashes and coverage for all 322
fixture records. The strict completion gate still stops at Shadow 7
(`107.json`) and carried fixture `107-1.json`. The standalone route count
remains 86/90.

This timing correction accepted zero new routes. The three-day closure rate
remains zero routes per day, and the seven-day evidence window still supports
no completion ETA.

## Measurement rules for subsequent work

- Record the verified count, exact scope, evidence commit and date after each
  content-family audit.
- Report net accepted route closures per elapsed calendar day between audited
  snapshots. Keep hours spent separate; do not infer labour velocity from
  commits or search duration.
- Record a zero route-closure result when a work window produces no accepted
  replay. Do not count an engine regression or partial route as a route closure.
- Track route closures separately from source-rule parity, assets, rights,
  campaign continuity and release-package acceptance.
- Show short-window and rolling seven-day rates. Do not turn a sparse or
  zero-yield search window into a completion ETA.
- Keep imported levels out of bundled denominators. Report their supported
  engine, version and feature gates separately.

No full-catalogue replay is required for routine progress. Re-run only the
affected routes and the required regression set, then refresh the family count
from the retained audit.

## 20 October current work window

This work window added no accepted route. It ran one targeted Classic fan
search that expanded 1,061,870 two-skill continuations in 52 solver seconds.
The latest bundled route count remains 3,119 of 7,376, based on the mixed-date
audit in the baseline table. The Classic fan count remains 2,403 of 6,020. The
current window is too short to calculate a calendar-day rate. The rolling
seven-day route count remains unchanged at zero accepted closures. This gives
no ETA.

I added a provisional Mole frame map for the source states in the retained
trace. Two focused tests cover mapped frames and fallback behaviour. This is
engine-rendering work. It does not change the route denominator or close an
MVP level. The source frame format still needs proof before the rendering gap
can close.

### 20 October `Execution Style` targeted pair search

I rebuilt `ClassicSolver` from this checkout. Its binary hash is
`3a66736309167422c33eda25298050abd135f3d733958900fffca59777d1f134`. I
confirmed the exact member `fan:lldb-341/JM15.DAT#5` is `Execution Style`, with
20 Lemmings and a one-save quota. A fixed-rate sweep tested one Floater
assignment followed by one Basher assignment. It tested first assignments
from ticks 1–300 and second assignments 1–100 ticks later.

The sweep completed 1,061,870 continuations in 52 solver seconds. It found no
win and accepted no route. The search only tests two assignments followed by
no further input. It does not show that the level has no solution. The fan
count remains 2,403/6,020. The [run record](ClassicFanExecutionStylePairSweep-2026-10-20.json)
retains the exact level, archive, initial-state and solver hashes.

### 20 October `A TOWERING PROBLEM` continuation probe

I verified the retained near-win against the current solver and exact bundled
archive `fan:lldb-325/t3tesla.dat#8`, titled `A TOWERING PROBLEM`. The archive
has 35 Lemmings and needs nine saved. A saved historical prefix reproduces
8/9 saved under the current solver. I varied the second Builder assignment
from ticks 795 through 815, keeping the other Builder and two release-rate
commands fixed. None of the 21 timings won. The route remains open.

This probe tested 21 targeted timings and expanded 9,294 states. It accepted
zero routes. These are search-throughput measures only. The verified Classic
fan count remains 2,403/6,020, with 3,617 open. The one-window closure rate
remains zero; no ETA follows from this
sample. The [run record](ClassicFanT3TeslaTowerContinuation-2026-10-20.json)
contains the exact commands, result summaries and content/tool hashes.
