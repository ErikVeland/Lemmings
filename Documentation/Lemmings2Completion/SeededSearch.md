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

## Commands

| Task | Command |
| --- | --- |
| Solve one level | `zsh Scripts/solve-lemmings2-level.sh <tribe-NN> [--seed FILE] [--population N]` |
| Run tribes in parallel | `zsh Scripts/solve-lemmings2-tribes.sh [tribe ...] -- [--from N --population P] [--promote]` |
| Promote candidate files | `.build/l2-solver/solver promote Sources/Ports/Lemm2 <file>...` |
| Regenerate the manifest | `python3 Tools/Lemmings2Completion/report.py` |
| Run the gate | `zsh Scripts/verify-lemmings2-completion.sh` |
