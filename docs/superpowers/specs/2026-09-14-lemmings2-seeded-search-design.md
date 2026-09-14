# Lemmings 2 seeded search design

14 September 2026. Scope: phase 2 of the Lemmings 2 route solver. This document
follows [the route solver design](2026-09-13-lemmings2-route-solver-design.md) and
the spike report in `Documentation/Lemmings2Completion/SolverSpike.md`. It records
no new route.

## Goal

Get tribes to chain from level 1 to level 10 by starting the search from routes
that already reach an exit. The completion gate measures success. The target stays
`fullyChainedTribes: 12` in `Documentation/Lemmings2Completion/evidence.json`.

## Why seeded search

The spike verdict was no-go and inconclusive.

- Every spike search ended in under a minute, far inside its 15 minute budget,
  because the beam ran out of branches.
- The search saved 0 of 60 on `classic-01`, a level with a recorded route that
  saves 60 of 60. The search, not only the levels, caused the no-go.
- A branch without the rest of a route almost never wins. The score then had no
  gradient to follow.

The gate verifies 64 of 120 levels. 43 of those routes save one lemming of sixty.
Egyptian chains 8 levels. No tribe chains 10. The game cannot record a Lemmings 2
route, so the 64 fixtures are the only seeds today.

## Decisions

The user made these choices during design.

1. **Both seed sources, existing routes first.** Improve and chain the 64 recorded
   routes, then add in-game recording so a played level becomes a seed.
2. **Branch from the seed and follow it.** Branch at the seed's decision points.
   After a change, the rest of the seed plays. Small edits to the seed's own
   inputs are also actions.
3. **Three parts, in order.** Seeded search, then tribe chaining and promotion,
   then in-game recording. Each part merges on its own.

## Route file version 2

Version 1 holds skill inputs and pointer records. It cannot hold machines, chains,
pointer release or nuke. Its per-tick rules also release and restore the fan around
each assignment, so removing one input from a version 1 route can change the
replay of the inputs around it.

Version 2 holds one ordered list of events. Each event is one runtime call.

| Event | Runtime call |
| --- | --- |
| `assign(skill, lemming)` | `assign(slot:to:)` with the slot that holds `skill` |
| `aim(x, y, held)` | `setAim(x:y:held:)` |
| `fan(x, y, active)` | `setFan(x:y:active:)` |
| `releasePointer` | `releasePointerInput()` |
| `machine(x, y)` | `moveMachine(x:y:)` |
| `chain(x, y)` | `releaseChain(x:y:)` |
| `nuke` | `nuke()` |

- Events apply in list order on their tick, before the runtime steps. This is the
  order the app's run recovery already uses.
- A version 2 file has `events` and no `inputs` or `pointers`.
- Coordinates of `aim`, `fan`, `machine` and `chain` must be inside the viewport
  range that version 1 pointers use. A refused `assign`, `machine`, `chain` or
  `nuke` is an error in a strict replay.
- `Lemmings2RouteEvent` and the event cursor live in
  `Sources/NxlvKit/Lemmings2ReplayWitness.swift`, so the gate, the runtime suite and
  the solver share one set of rules.
- A version 1 file converts to events exactly. A pointer becomes `aim` and `fan`.
  An input becomes `fan(0, 0, false)`, `assign`, and `fan` on again when the last
  pointer held the fan. The gate test replays every fixture in both forms and
  requires the same state hash.
- The gate and `report.py` accept versions 1 and 2. Existing files stay version 1.
  New solver and app routes are version 2.

This change touches `Sources/NxlvKit`, so the Trolley engine fingerprint changes.
The rescue certificates and checked hints must be re-verified before the next
beta, as after the spike merge.

## Part 1: seeded search

### Replay with refused inputs dropped

The solver replays events with a lenient cursor. When the runtime refuses an
`assign`, `machine`, `chain` or `nuke`, the cursor removes that event from the
candidate's list and continues. A refusal is checked before any runtime call, so
the dropped event leaves no trace. The candidate's list is therefore always the
events that applied plus the events still to come. A strict replay of the finished
list gives the same result.

### Search

1. **Root.** The root candidate holds the whole seed as pending events. The
   population is the level's starting population, which may differ from the seed's.
2. **Decision points.** The spike detector runs unchanged. Each decision point is a
   snapshot with its pending events.
3. **Actions at a decision point.**
   - Wait. Continue with the pending seed events.
   - Assign each stocked skill to each offered lemming, as in the spike.
   - Aim the roper, as in the spike.
   - Edit the next pending `assign`: move it 8 ticks later, move it 8 ticks earlier
     but not before the current tick, give it to each other offered lemming, or
     drop it.
4. **Follow the seed.** A new action inserts its events at the current tick, before
   the pending events of that tick. The candidate then plays on with its pending
   events and the lenient cursor.
5. **Beam.** Width 64. Merging and the scoring order are unchanged from the spike:
   saved, then not lost, then distance to an exit, then fewer events, then the
   fingerprint.
6. **Depth.** The decision points on a replay of the seed, plus 40.
7. **Budget.** 15 minutes of one core for each level. A flag changes it.
8. **Result.** The best finished candidate must win and must pass two strict
   replays of the written file with matching state hash, saved count and ticks.

Other aimed skills, fans, machines and chains are not branched. They keep the
events the seed recorded.

### Command

`solve-level <data-root> <tribe-NN> --seed <file> [--population N]` runs a seeded
search. Without `--seed`, the command runs the spike search, which now writes
version 2 routes. The exit codes and the `SOLVED` and `UNSOLVED` lines stay as in
the spike.

### The recovery test

The test proves the seeded search can find a route it was given part of.

1. Take the `classic-01` fixture, which saves 60 of 60.
2. Convert it to events and remove one `assign` that the route needs. The damaged
   route saves fewer than 60.
3. Run the seeded search from the damaged route with the default limits.
4. The search must save 60 of 60.

If the search fails, the search is broken, and no real level runs.

## Part 2: chaining and promotion

### Tribe runs

`solve-tribe <data-root> <tribe> [--seeds DIR] [--budget SECONDS] [--out DIR]`
solves levels 1 to 10 in order. Level 1 starts with 60 lemmings. Each later level
starts with the saved count of the chosen route before it.

For each level, the seed is the first that exists:

1. a route recorded at the level's starting population, from the chain fixtures,
   the fixtures or `--seeds`;
2. the best route for the level at any population, highest saved first;
3. no seed, which runs the spike search.

A seeded search that does not beat its seed still returns the seed replayed at the
new population, when that replay wins.

- **Pass.** A level passes when its route saves at least 1. The search already
  ranks saved lemmings first. The report states whether level 10 saves the 30
  that the ark ending needs.
- **Backtrack.** The chosen route saves the most, but a smaller crowd can pass
  where a large one blocks or dies. When a level cannot pass, the solver goes back
  one level. It collects up to three other winning routes for that level with a
  different saved count, from the finished candidates of its search, most saved
  first. It retries the failed level with each population in turn. It backtracks
  one level only.
- **Break.** A chain that still fails is recorded at the level where it broke, with
  `UNSOLVED` and the best partial route.
- **Report.** `solve-tribe` writes `.build/l2-solver/tribes/<tribe>.json` with the
  saved count, population, seed source and time for each level.

`Scripts/solve-lemmings2-tribes.sh` runs one `solve-tribe` process for each named
tribe, or all twelve, in parallel.

### Promotion

`solve-tribe --promote` and `solve-level --promote` write accepted candidates into
the gate's directories. Promotion happens only after two strict replays agree.

| Candidate population | Destination | Replaces an existing route when |
| --- | --- | --- |
| 60 | `Tests/Lemmings2CompletionTests/Fixtures/<level>.json` | The candidate saves more |
| Not 60 | `Tests/Lemmings2CompletionTests/Chains/<level>.json` | The existing chain route has a different population, or saves less at the same population |

A promotion that replaces a level's chain route can leave later chain routes at a
population that no longer follows. The gate then counts a shorter chain until the
tribe run solves the later levels again. After promotion, `report.py` regenerates
the manifest and the completion gate runs.

### Order of runs

Egyptian runs first, because it already chains 8 levels. The other tribes follow
in order of their one-lemming routes, most first.

## Part 3: recording routes in the game

1. **Source.** The Lemmings 2 play window already logs every input with its tick
   for run recovery. Undoing a nuke removes the inputs after the nuke. The play
   window has no other rewind, so the log always matches the played run.
2. **When.** A campaign level that completes with at least 1 lemming saved writes a
   route. Practice runs are not recorded, because their skills differ from the
   campaign level.
3. **Conversion.** Each logged input becomes one event. `assign(slot, lemming)`
   becomes `assign` with the skill in that slot.
4. **File.** `~/Library/Application Support/Ultimate Lemmings/Lemmings2Routes/
   <tribe>-<NN>-saved<n>-<yyyyMMdd-HHmmss>.json`, route version 2, with
   `expectedSaved` and `expectedTicks` from the played run.
5. **Check.** A background task replays the file once. When the replay differs
   from the played run, the file is kept as a seed with `"verified": false`,
   `playedSaved` and `replayedSaved`, and its expected fields hold the replayed
   result. A route that fails to replay at all is kept with `"verified": false`
   and no replayed result. The gate never reads this folder.
6. **Finding the files.** The Lemmings 2 menu gets **Show Recorded Routes**. It
   creates the folder when needed and opens it in Finder.
7. **Solver.** `solve-tribe --seeds <folder>` reads every route in the folder that
   replays. It matches files to levels by `levelSHA256`.

## Testing

| Test | What it proves |
| --- | --- |
| Every fixture replays as version 1 and as converted events to the same state hash | The conversion is exact |
| The seven negative gate cases, plus a version 2 file with a refused assign and an off-viewport aim | Version 2 keeps the gate strict |
| A lenient replay that drops an event, then a strict replay of the kept list | Dropping leaves no trace |
| Synthetic level: a seed without its winning basher, seeded search restores 3 of 3 | Seeded branching works |
| The `classic-01` recovery test | Seeded search finds a known route |
| Synthetic two-level chain with populations 3 and then the saved count | Population passes forward |
| Promotion on a temporary copy never replaces a route that saves more | Promotion is safe |
| App integration: play a short Lemmings 2 level with inputs and a nuke undo, then replay the written route | Recording is faithful |
| The completion gate, its negative mode and the runtime suite | Nothing regressed |

## Errors

| Case | Result |
| --- | --- |
| Unreadable or mismatched seed | Skipped with a warning. The level falls back to the next seed source |
| Two replays of a candidate disagree | Exit code 1. The candidate is never promoted |
| No route within the budget | Exit code 2, `UNSOLVED <level>: best saved <n>`, best partial route written |
| A recorded route that does not replay | Kept with `"verified": false` for inspection |

## Out of scope

- Branching on aimed skills other than the roper, fans, machines or chains.
- Changes to runtime physics.
- Original engine fidelity comparison.
- Lemmings 3 routes.
- Converting the existing version 1 fixtures to version 2.

## Amendments during implementation

### Seed line protection and restarts

The first `classic-01` recovery run failed. Removing the route's last builder left
59 of 60. A builder for lemming 9 at the decision point on tick 2409 saves 60, but
the search ended after 130 seconds with 59.

The beam keeps the 64 best partial states. The candidate that only waits, which
follows the seed unchanged, scored no better than variants with harmful early
assignments. Over about 200 decision points it left the beam before tick 2409.

- **Seed line.** The beam always keeps the candidate that has only waited.
- **Restarts.** When a search finds a route that saves more, the solver searches
  again from that route while budget remains.

Scoring every branch by playing it to the end was rejected. It costs about
1,600 plays of the rest of the level for each beam round.

With both changes, the recovery test restores 60 of 60 in 2 rounds and about
3 minutes.

### Merge key cost

The merge key first described every pending event as text. On `beach-01`, whose
seed has 16,216 events, the search expanded 1,597 nodes in 120 seconds. The key
now uses a stable FNV-1a hash of the pending events, and the same run expands
156,483 nodes. Swift's `Hasher` was not used, because its values change between
processes and the merge order must not.

### Promotion and backtracking

A backtracked route saves fewer lemmings than the level's best route. The
promotion rule that never replaces a route that saves more would keep the better
chain route, and the gate's chain would then break at the next level.

- A chain route (population not 60) that a tribe run chose by backtracking replaces
  the existing chain route at the same population.
- A 60-lemming fixture never gets worse. A backtracked level 1 route is therefore
  not promoted, and the tribe report shows it.
- A chain route needs a fixture for its level, because the gate rejects a chain
  route without one.
