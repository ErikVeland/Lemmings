# Lemmings 2 route solver design

13 September 2026. Scope: a solver that finds winning Lemmings 2 routes that chain
through each tribe. This document designs the solver. It records no new route.

## Goal

Find crowd routes that save enough lemmings to carry population through a tribe.
A tribe can then be played from level 1 to level 10. The ark ending requires at
least 30 survivors on level 10 of every tribe.

The existing completion gate measures success. The target is
`fullyChainedTribes: 12` in `Documentation/Lemmings2Completion/evidence.json`.

## Current state

The gate verifies 64 of 120 levels. No tribe chains all ten levels. 43 routes save
one lemming of sixty.

### The existing search tool

`Tools/Lemmings2Reference/search-replay.swift` is an 87 line beam search from the
beta 8 work in progress. It is a single lemming pathfinder, not a campaign solver.

| Limit | Evidence | Effect |
| --- | --- | --- |
| One lemming | `total:1` and `assign(slot:to:0)` | A found route saves one lemming when it is replayed with 60 |
| Roper aim only | Aim variants exist only for `.roper` | Levels that need other aimed skills stay unsolved |
| No fans | The search never sets a pointer or a fan | Levels that need fans stay unsolved |
| Level special case | `number != 21` appears three times | A hard coded exception |
| Wrong output | It writes `{tick, slot, id, aimX, aimY}` | The gate cannot read its output |

The tool and most fixtures first appear in commit `f5af795`. This makes it very
likely, but not proven, that the tool produced the one lemming routes.

A good route changes terrain so that the crowd can follow. A builder's bridge or a
basher's tunnel serves every lemming that follows. A single lemming search accepts
a trick, such as floating past a hazard, that kills the rest of the crowd.

### Measurements

Measured on an M4 Pro, one core, with optimised builds.

| Measurement | Value |
| --- | --- |
| Stepping a 60 lemming runtime | About 8,300 ticks per second |
| One runtime copy | About 11 ms, the cost of about 100 ticks |
| A full level, up to 8,100 ticks | About 1 second |
| Passive result on three levels without routes | 0 of 60 saved |

Simulation is cheap. Branching is expensive. The Classic solver's `solve` mode
branches on a fixed tick grid (`SOLVE_STRIDE=8`). It found no new route in a
40 minute run. A solver that copies at fixed intervals repeats that cost.

The runtime reads the aim point in several places: flyer steering, projectile
launch, the roper, and machine and chain control. Pointer input is a continuous
control, so the solver must choose from a small discrete set of targets.

## Decisions

The user made these choices during design.

1. **Chaining crowd routes.** A level counts as done when its route saves enough of
   the crowd to carry population forward.
2. **Crowd search with decision point branching.** A seed hook rescues levels the
   search cannot solve.
3. **An early go or no-go spike.** The spike runs before the full skill model is
   built.

## Architecture

Each unit has one purpose.

| Unit | Purpose |
| --- | --- |
| `Tools/Lemmings2Solver/DecisionPoints.swift` | Watch a runtime and report when a decision can matter |
| `Tools/Lemmings2Solver/Actions.swift` | List the legal actions at a decision point |
| `Tools/Lemmings2Solver/Search.swift` | Run a beam search over snapshots taken at decision points |
| `Tools/Lemmings2Solver/main.swift` | Run a level or a tribe chain and write a witness |
| `Sources/NxlvKit/Lemmings2ReplayWitness.swift` | Reused. Replays a route and gives its outcome |
| `Scripts/verify-lemmings2-completion.sh` | Reused. Accepts a route only after two matching replays |

### Shared input application

The solver and the gate must apply inputs in the same order. The existing tool
calls `assign` before `setAim`. The witness applies pointer input before skill
input on each tick. A route found with one order can fail to reproduce with the
other.

Move the per tick input application out of `Lemmings2ReplayWitness.run` into a
shared `apply(inputsAt:)`. The solver and the witness both call it.

## Search

### Decision points

The detector checks these signals every tick. The checks need no runtime copy.

| Trigger | Signal |
| --- | --- |
| Edge ahead | The column 8 pixels ahead of the lead walking lemming has no solid pixel from `y + 1` to `y + 4` |
| Wall turn | The lead lemming's `direction` changes |
| Fall start | The lead lemming changes from `walking` to `falling` |
| Death | `lost` increases |
| Fallback | No other trigger fires for 150 ticks, which is 10 seconds of game time |

The lead lemming is the active walking lemming nearest to an exit. The fallback
keeps the search moving when the trigger model misses a mechanic.

Triggers must not repeat. A crowd that follows one path would otherwise fire a
trigger for every lemming, which is the waste this design removes.

- Edge ahead fires once for each edge position. It fires again only after the
  lead lemming changes or the edge is no longer ahead.
- Fall start follows only the lead lemming. Deaths of other lemmings use the death
  trigger.
- Death fires at most once every 15 ticks, which is one second of game time.
- The fallback timer restarts whenever any trigger fires.

### Actions

At a decision point, the solver considers these actions.

- **Wait.** Run to the next decision point.
- **Assign.** Assign each stocked skill to the lead lemming or to the lemming that
  fired the trigger. The solver never tries all released lemmings.
- **Aim, roper only in the spike.** Ten targets: two directions, at 64 pixels
  horizontal distance, with vertical offsets of -48, -24, 0, 24 and 48.

A holding skill such as the blocker is an action only when the level stocks it.

### Scoring

The solver compares candidates in this order. It does not add weighted values.

1. Saved lemmings, higher first.
2. Lemmings not yet lost, higher first.
3. Total distance of active lemmings to the nearest exit, lower first.
4. Number of inputs, lower first.
5. The state fingerprint, as a fixed tie break.

Beam entries with the same `stateFingerprint` merge into one entry. Different
input orders often reach the same state. The merge keeps the entry that ranks
highest under the order above, so the shorter route survives.

### Parameters

| Parameter | Spike value |
| --- | --- |
| Beam width | 64 |
| Maximum decision depth | 40 |
| Time budget per level | 15 minutes of one core |
| Threads | One |

The search is deterministic. The same level and parameters give the same route.

## Phases

The implementation plan covers phase 1 only. Phase 2 needs its own plan after a
go result.

### Phase 1: spike

Build the shared input application, the detector, the actions for skills without
aim plus the roper, the search, and a `solve-level` command.

Run each spike level with a population of 60. The spike tests whether a level can
be solved. Chaining is phase 2.

| Level | Reason | Skills |
| --- | --- | --- |
| `cavelem-01` | Known to be solvable. The current route saves 1 of 60 | stomper, builder, clubBasher |
| `highland-03` | No route. Smallest set of skills | filler, jumper, builder |
| `space-03` | No route. Eight skills, so a wide search | fencer, platformer, shimmier, stomper, jumper, slider, rockClimber, runner |
| `medieval-03` | No route. Needs the roper | bomber, stacker, stomper, jumper, platformer, roper |

The levels come from a probe of all 120 skill sets. Of the 56 levels without a
route, 14 use no pointer skill and 4 use only the roper as their pointer skill.

**Go** requires both results within the time budget:

- `cavelem-01` gets an accepted route that saves at least 30 of 60.
- At least two of the other three levels get an accepted route that saves at
  least 20 of 60.

**No-go** makes seeded search the primary method. The spike records the result.

Write the result to `Documentation/Lemmings2Completion/SolverSpike.md`. For each
level, record the saved count, ticks, decision points, expanded nodes, the share
of decision points that came from the fallback, and wall time.

Improving `cavelem-01` breaks the existing Cavelems chain, because `cavelem-02`
was recorded with a population of 1. The gate then reports Cavelems chaining
through one level until phase 2 solves level 2 with the new population. This is
expected.

### Phase 2: full solver

Phase 2 starts only after a go result.

- Solve tribes as chains.
- Add all aimed skills, fans, machines and chains.
- Run tribes in parallel, one process for each tribe.
- Solve existing routes again where their population does not match the chain.

### Chaining

`solve-tribe <tribe>` solves level 1 with 60 lemmings. It keeps the saved count of
the best route, then solves level 2 with that population, and so on. It takes the
highest saved count at each level.

If a level cannot be solved with its population, the solver backtracks. It tries
up to three lower ranked routes for the previous level that save more lemmings.
A chain that still breaks is recorded at the level where it broke.

### Seed hook

`--seed <witness.json>` replays a known route and starts the beam from its decision
states. A human or reference route can then rescue a level. The seed must pass
witness validation first.

## Acceptance

The solver never writes to the fixture directory directly.

1. The solver writes a candidate to `.build/l2-solver/candidates/`.
2. The witness replays the candidate twice. The state hash and saved count must
   match. A mismatch is an error, and the candidate is never promoted.
3. `--promote` moves the candidate into `Tests/Lemmings2CompletionTests/Fixtures/`.
   It replaces an existing route only when the candidate saves more at the same
   population, or when the existing route starts with a population that does not
   match the chain. It never overwrites a better route.
4. `report.py` regenerates the manifest, and the gate runs.

### Results

| Exit code | Meaning |
| --- | --- |
| 0 | An accepted route was found |
| 2 | No route was found within the budget |
| 1 | An error, including a replay mismatch |

An unsolved level writes its best partial route and prints
`UNSOLVED <level>: best saved <n>`. A missing route does not prove a level is
broken.

## Testing

The search must show it can succeed before a hard level can be called hard.

| Test | What it proves |
| --- | --- |
| All 64 fixtures and the seven negative cases pass after the shared input change | The refactor did not change replay behaviour |
| Detector unit tests on synthetic levels | Each trigger fires, including the fallback |
| Planted solution on a synthetic level with one known winning assignment | The search can find a route at all |
| Known answer: solve `classic-01` again | The search reaches a proven result on real data |
| Scoring order and fingerprint merging | Ranking is deterministic |

The known answer test passes when the solver finds an accepted `classic-01` route
that saves at least 30 of 60 within the budget. The recorded route saves 60 of 60
with 20 inputs across seven skills, so it is not a passive win.

The synthetic runtime builder `fixture(wall:)` and `syntheticMasks()` live inside
`Tests/Lemmings2RuntimeTests/main.swift`. Move them into a shared test helper that
both the runtime suite and the solver tests compile. The builder uses only the
public `Lemmings2Runtime.Configuration` initialiser. Its wall between the entrance
and the exit gives the planted solution a clear obstacle.

## Out of scope

- Phase 2 features during the spike.
- Changes to the runtime physics. The solver must never change physics to fit a
  route.
- Original engine fidelity comparison. That gate stays separate.
- Lemmings 3 routes. The design may later extend to L3, but this document does not
  cover it.
