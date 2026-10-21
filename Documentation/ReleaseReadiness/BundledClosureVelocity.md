# Bundled closure velocity

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
