# Bundled closure velocity

This record measures progress towards the bundled-content MVP: one verified
winning replay for every bundled level. It excludes imported content and does
not count searches, candidate files, or replay runs as closures. A closure is
counted only when the current bundled audit accepts a winning replay for the
exact level identity.

## Baseline — 20 October 2026

The worktree `HEAD` and cached `origin/main` ref both resolve to
`440caebd886ec35d512137e2aa82c6b610d13141`. A live remote refresh is not
available in this environment, so this does not confirm the current GitHub
`main` tip. Baseline counts below use the latest retained evidence available
in this checkout; the evidence dates differ by engine and appear in the source
column.

| Bundled family | Verified MVP routes | Scope | Open | Evidence date and source |
| --- | ---: | ---: | ---: | --- |
| Official Classic and Oh Yes! | 352 | 352 | 0 | 16 Oct; `Documentation/ReleaseScope.md` |
| Classic fan packs | 2,403 (39.9%) | 6,020 | 3,617 | 17 Oct reconciliation; `Documentation/ReleaseScope.md` |
| Lemmings 2 | 120 standalone routes; 70 carry-over variants; 12 chains | 120 levels | 0 MVP route gaps | 16 Oct; `Documentation/ReleaseScope.md` |
| Lemmings 3 | 86 | 90 standalone routes | 4 level identities | 20 Oct audit: 399/416 scenarios pass; 17 failures are four standalone and 13 carried scenarios |
| NeoLemmix CE | 158 | 794 | 636 | 17 Oct reconciliation; exact-version route evidence |

The simple total is 3,119 of 7,376 levels, or 42.3%, with 4,257 open. This
combines family evidence from different dates. It is a scope summary, not a
single audit or a velocity measure.

Route coverage does not measure all closure work. The L2 Gold Ark is outside
the agreed MVP. L3 source parity and media remain open. NeoLemmix also has 75
levels with unresolved style dependencies and rights. Those are tracked as
separate blockers in `Documentation/ReleaseScope.md`.

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
