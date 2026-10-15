# Lemmings 2 seeded search results

15 September 2026. This report records phase 2 of the Lemmings 2 route solver. The
design is in `docs/superpowers/specs/2026-09-14-lemmings2-seeded-search-design.md`.
The [completion report](README.md) holds the current coverage and route quality.

## Result

| Measure | Before phase 2 | Now |
| --- | ---: | ---: |
| Levels with a verified route | 64 of 120 | 73 of 120 |
| Tribes that chain all ten levels | 0 | 1 (Cavelems) |
| Carry-over routes | 16 | 24 |

The gate replays every route twice. A route counts only after both replays agree.

## Chains by tribe

Each list shows the lemmings saved on each chained level. Level 1 starts with 60,
and each later level starts with the number saved before it.

| Tribe | Levels chained | Saved on each chained level |
| --- | ---: | --- |
| Cavelems | 10 | 47, 30, 12, 3, 2, 2, 1, 1, 1, 1 |
| Egyptian | 8 | 40, 14, 1, 1, 1, 1, 1, 1 |
| Sports | 7 | 2, 2, 1, 1, 1, 1, 1 |
| Classic | 5 | 60, 1, 1, 1, 1 |
| Polar | 4 | 26, 7, 1, 1 |
| Circus | 3 | 2, 2, 2 |
| Outdoor | 3 | 59, 14, 1 |
| Space | 2 | 51, 1 |
| Beach | 1 | 29 |
| Highland | 1 | 60 |
| Medieval | 1 | 1 |
| Shadow | 1 | 1 |

The ark ending needs 30 lemmings on level 10 of every tribe. No tribe reaches it.
Cavelems level 10 saves one.

## What worked

- **Route version 2.** One ordered event list lets the solver drop a refused input
  without changing the replay of the inputs around it. All 64 earlier routes
  replay to the same state hash in both versions.
- **Following the seed.** Every branch plays the rest of the seed. The
  `classic-01` recovery test restores a damaged route from 59 to 60 of 60.
- **Keeping the seed line.** The beam always keeps the candidate that only waits.
  Without it, the unchanged route left the beam long before the decision point
  that one change improves.
- **Corridor distance.** The score measures the distance to an exit through open
  space. A straight-line distance ranked a lemming under a wall as close to an exit
  that it could reach only by a long way round. This change solved Cavelems 6 to 10
  and Sports 3 to 7.
- **Promotion of a first route.** A level without a route now takes its first
  verified route at any population. The gate needs that route before it accepts a
  carry-over route.

## What did not work

These changes were tried on the levels where chains break and then removed.

| Change | Result |
| --- | --- |
| A decision in each new location cell for crowds of four or fewer | Solved nothing, and lost the Cavelems 6 route |
| Ranking fewer inputs before crowd distance | Solved nothing in 10 minutes for each level |
| The beta 8 single-lemming search on seven break levels | Solved nothing in 5 minutes for each level |
| Beam widths up to 4,096 and 45 minutes for each level | Solved nothing |

## Why chains break

Most chains break at a level that starts with one or two lemmings.

- **Outdoor 4.** One lemming can cross the water only as a kayaker. The runtime
  lands the kayaker against the wall face of the far shore, where it turns and
  drowns. No second skill on any later tick saves it, and no roper aim on an 8
  pixel grid saves it either. The route needs a longer sequence, or a larger crowd
  from the level before. The runtime logic was not changed. A physics change needs
  original-engine evidence.
- **Classic 6.** One lemming must turn back from the left, climb the steel stairs
  and cross a 1,280 pixel level. The search keeps it alive but does not find the
  full sequence.
- **Highland 2 and Beach 2.** These start with 60 and 29 lemmings. No search found
  any win.

A bigger crowd from the level before gives more ways through. Full tribe reruns
with the corridor score raised Cavelems level 1 from 6 to 47 saved without
shortening any chain.

## Seeds from players

The app saves every campaign level that a player completes as a route file in
`~/Library/Application Support/Ultimate Lemmings/Lemmings2Routes`.
**Show Recorded Routes** in the app menu opens the folder. A played route for a
break level is the most direct way to extend a chain:

```sh
zsh Scripts/solve-lemmings2-tribes.sh outdoor -- --from 4 --population 1 --seeds "$HOME/Library/Application Support/Ultimate Lemmings/Lemmings2Routes" --promote
```

A seed must be for the same level. The solver starts from it at the population
that the chain passes on, and it promotes a route only after two replays agree.

## 15 October bounded ark follow-up

A seeded search re-ran Classic 2 at 60 lemmings with a 1,024-candidate beam and
a 180-second budget. It expanded 364,199 candidates and retained the existing
13/60 Bronze result. It found no improved route. This search does not close the
ark gate or prove that Classic 2 cannot save more lemmings.

The retry used the recorded Classic 2 fixture as its seed:

```sh
zsh Scripts/solve-lemmings2-level.sh classic-02 \
  --seed Tests/Lemmings2CompletionTests/Fixtures/classic-02.json \
  --population 60 --beam 1024 --budget 180 \
  --out .build/l2-solver/ark-attempt-classic
```

### Cavelems carry-over update

A seeded Cavelems Level 1 search improved the standalone route from 52 to 59
saved out of 60. Population-specific searches then found routes that save 36
of 59 on Level 2, 17 of 36 on Level 3, 4 of 17 on Level 4 and 2 of 4 on Level
5. The gate verified each promoted route twice. Existing later routes complete
the ten-level chain, but the final result remains one survivor.

A wider Level 3 search used a 4,096-candidate beam and a 360-second budget. It
found no route better than 17 of 36. This search does not prove that the level
has no higher-survivor route. Strict ark mode still fails because all twelve
tribes finish with one survivor and a Bronze talisman.

A 4,096-candidate, 360-second search for Cavelems Level 2 also found no route
better than 36 of 59. The verified Level 1 and Level 2 witnesses remain the
best routes found in these searches.

### Beach 3 ark search

A 600-second seeded search at the carried population of 42 used a 4,096-candidate
beam. It expanded 2,684,497 candidates and returned a replay-verified route
that saves one, matching the accepted chain witness. It did not improve the
population passed to Beach 4. This bounded search does not show that Beach 3
cannot save more lemmings.

A second 600-second search kept the same seed and beam but changed the decision
cell to 4 pixels and the refire interval to 75 ticks. It expanded 2,704,573
candidates and returned the same 1-of-42 route. Neither search improved the
Beach chain or proves a higher-survivor route is unavailable.

### Current-main route probes

After syncing to `main` revision `061e1b99`, bounded searches checked routes
that feed the weak Highland and Beach chains. L2 source files did not change in
that sync. The retained solver found no better route in these probes:

| Route | Incoming population | Result | Search |
| --- | ---: | ---: | --- |
| Highland 1 | 60 | 60 saved | 120-second seed search, beam 2,048; 202,791 candidates |
| Highland 2 | 60 | 3 saved | 180-second seed search, beam 2,048; 344,212 candidates |
| Highland 2 | 60 | 3 saved | 180-second seed search, beam 4,096, cell 4, refire 75; 403,470 candidates |
| Beach 1 | 60 | 42 saved | 180-second seed search, beam 4,096; 88,155 candidates |
| Beach 2 carry-over | 42 | 42 saved | 180-second seed search, beam 4,096, cell 4, refire 75; 535,594 candidates |

The current chain loses survivors later. Highland 2 carries only three forward,
and Beach 3 carries one from 42. These searches do not prove that a better
route is impossible. The 15 October strict gate replayed all 120 standalone
routes, 70 carry-over variants and twelve ten-level chains. It still fails the
ark check because every tribe ends with one survivor. The latest successful
gate revision is recorded in the [completion report](README.md).

Two additional Highland 2 probes on 15 October tested different search lines.
An unseeded 300-second search with beam 4,096, cell 8 and refire 150 found no
win after 436,351 expansions. A 600-second search from the verified 3-of-60
chain witness, with beam 4,096, cell 8 and refire 75, returned the same route
after 1,089,933 expansions. These bounded searches did not improve the route;
the 30-survivor ark condition remains open.

After `main` advanced from `b8f11a21` to `3cf456ea`, a 240-second search varied
the seeded Runner/Jumper timing grid at cell 4 and refire 24. The L2 runtime,
level data and completion tools did not change in that update. The solver
expanded 590,072 candidates and replay-verified the same 3-of-60 Bronze route
in 4,500 ticks. It did not improve the Highland chain. The source-guided
Runner/Jumper timing change remains an unproven route lead, not DOS parity
evidence. At that review point, main through `fc2c59e6` had no later L2
runtime, level-data, solver or completion-tool changes; the probe itself remains
evidence from `3cf456ea`. The current-main solver deadline correction is recorded
below.

### Solver deadline correction on current main

A later narrow-beam Highland 2 probe remained active after its 600-second
budget. Code review found that the solver checked time between beam rounds, but
not within a candidate advance or action expansion. I stopped that run before
it returned a result; it is not evidence of a win or an unsolved level. I changed
the solver to use one deadline for seed profiling, candidate expansion and
partial-route finishing.

I rebuilt the solver against the fresh `NxlvKit` library from `fc2c59e6` and
ran a 10-second seeded check. The solver returned the accepted 3-of-60 route in
4,500 ticks. The report used 10 search seconds; process wall time was 11.71
seconds, including startup and two replay checks. A deeper 180-second search
with beam 4 reached six rounds and 108,925 expansions. It returned the same
route. The strict ark condition remains open. See the
[deadline recheck record](search-budget-recheck-2026-10-15.json).

### Current-main Cavelems carry searches

I rebuilt the solver against the current-main L2 library and repeated the
Cavelems Level 2 and Level 3 searches with cell 4 and refire 75. The Level 2
search used the verified 36-of-59 route. It returned the same route after
891,959 expansions in 240 seconds. The Level 3 search used the verified
17-of-36 route. It returned the same route after 1,371,468 expansions in
360 seconds. The solver replay-verified both results twice. Neither search
improved the carried population. All tribes still end with one survivor and a
Bronze talisman. A separate 360-second Level 3 search at cell 2 and refire 24
expanded 1,707,555 candidates and kept the same route. A 240-second search for
Level 4 at population 17 also kept the accepted 4-of-17 Bronze route. These
searches do not prove that a higher-survivor route is impossible. See the
[search record](cavelem-carry-search-2026-10-15.json).

### Current-worktree Beach 3 carry probe

A 120-second search from the accepted 1-of-42 Beach 3 route used beam 4,096,
cell 2 and refire 24. It expanded 443,181 candidates and returned the same
route, verified twice by the solver. The exact candidate bytes match the accepted
seed. The solver source includes worktree edits based on main `fc2c59e6`. It used
the installed 1.9.1 build 76 resource tree. The seed level fingerprint matched,
but the run does not prove full resource-set equivalence or audit the exact
build 83 package. The bounded search does not show that a better route is
impossible, and Beach still carries one survivor from Level 3. See the
[search record](beach-carry-search-2026-10-15.json).

### 16 October Cavelems ark reconnection search

An unseeded Level 3 search against the build 83 L2 app payload found a
34-of-36 route, up from the accepted 17. Seeded searches found 13 of 34 on
Level 4 and 10 of 13 on Level 5. Two 300-second Level 6 searches at population
10—one seeded from the accepted 2-of-2 route and one unseeded—found no win.
The new routes therefore do not form a verified longer chain. I preserved the
existing ten-level chain and retained the new routes as separate candidates.
The solver replay-verified each winning candidate twice. See the [search
record](cavelem-ark-reconnection-search-2026-10-16.json).

### Current-main ark route probes

At `4fe7328a`, a 300-second Level 6 search at population 13 found no route.
A seeded Level 5 search reproduced the same 10-of-13 route after 712,233
expansions. A wider Classic Level 2 search also reproduced its accepted
13-of-60 route after 1,289,171 expansions. The source and solver files did not
change after the build 83 payload replay. All 218 input files matched the
release manifest. These bounded searches do not prove that better routes are
impossible. The ark gate remains open. See the [current-main search record](ark-reconnection-search-2026-10-16-current-main.json).

At `c38831f3`, two unseeded Cavelems Level 4 searches at population 34 used a
beam of 8,192 and a 300-second budget. The 4-pixel grid expanded 1,014,578
candidates; the 2-pixel grid with 24-tick refire expanded 1,126,648. Neither
found a win or improved the retained 13-of-34 witness. These bounds do not
show that a higher-survivor route is impossible. See the [wider Level 4 search
record](cavelem04-beam8192-search-2026-10-16.json).

At `c38831f3`, a seeded Level 4 search at population 34 used beam 8,192,
depth 100, a 2-pixel grid and a 24-tick refire interval. It expanded 782,183
candidates and reproduced the retained 13-of-34 Bronze route byte for byte.
It did not improve the route. See the [seeded Level 4 search
record](cavelem04-seeded-beam8192-search-2026-10-16.json).

## Commands

| Task | Command |
| --- | --- |
| Solve one level | `zsh Scripts/solve-lemmings2-level.sh <tribe-NN> [--seed FILE] [--population N]` |
| Run tribes in parallel | `zsh Scripts/solve-lemmings2-tribes.sh [tribe ...] -- [--from N --population P] [--promote]` |
| Promote candidate files | `.build/l2-solver/solver promote Sources/Ports/Lemm2 <file>...` |
| Regenerate the manifest | `python3 Tools/Lemmings2Completion/report.py` |
| Run the gate | `zsh Scripts/verify-lemmings2-completion.sh` |
