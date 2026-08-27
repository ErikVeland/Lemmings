# NeoLemmix simulation phase 1

`NeoLemmixSimulation` is a deterministic, fixed-tick native engine for low-resolution NeoLemmix levels. It has no rendering dependency. The caller supplies collision masks, entrance data, trigger zones, preplaced lemmings, traits, and skill inventory.

The implementation uses NeoLemmix 12.14 behavior as an oracle. It is a clean-room Swift implementation. It does not include source text or binary assets from NeoLemmix.

## Public inputs and state

- `NeoLemmixTerrain` stores solid, steel, and one-way masks.
- `NeoLemmixConfiguration` stores timing, entrances, zones, preplaced lemmings, traits, and skills.
- `NeoLemmixConfiguration(level:renderedLevel:)` converts an `NxlvLevel` and `NxlvRenderedLevel`.
- `NeoLemmixReplayCommand` schedules an assignment, spawn interval change, or nuke command by tick and sequence.
- `NeoLemmixSnapshot` contains the complete observable state and the events from the last tick.
- `NeoLemmixSimulation` is `Codable`, `Equatable`, and `Sendable`. An encoded state continues deterministically after decoding.

The engine uses lemming foot coordinates. A terrain pixel at the same `(x, y)` position supports a lemming.

## Implemented rules

The phase-1 engine implements these fixed values and state transitions:

- 17 simulation ticks per second.
- Entrance opening on tick 35.
- First release on tick 54 with the default opening timing.
- A minimum spawn interval of 4 ticks.
- Walking, step-up, ascending, falling, climbing, hoisting, floating, and splatting.
- A maximum safe fall distance of 62 pixels.
- Exit, water, fire, reusable trap, and one-shot trap zones.
- Preplaced lemmings, entrance traits, entrance limits, neutral lemmings, and zombies.
- Finite and infinite skill supplies.
- Steel and directional one-way destruction checks.
- Replay command ordering by `(tick, sequence)`.
- Nuke countdown assignment.
- Completion, save counts, loss counts, and time limits.

The engine accepts these 19 skills:

- Walker
- Jumper
- Shimmier
- Slider
- Climber
- Swimmer
- Floater
- Glider
- Disarmer
- Bomber
- Stoner
- Blocker
- Platformer
- Builder
- Stacker
- Basher
- Miner
- Digger
- Cloner

`NeoLemmixRules.implementedSkills` provides this set at runtime.

## Explicit unsupported results

The engine rejects Fencer and Laserer assignments with `unsupportedSkill`. `NeoLemmixRules.unsupportedSkills` provides this set.

The engine does not silently substitute another action for an unsupported skill.

## Compatibility limits

Phase 1 is not a replay-compatibility claim. These items still need work before the engine can claim NeoLemmix 12.14 or CE 1.1.2 parity:

- Canonical terrain mask shapes for Basher, Miner, Bomber, and Stoner. Phase 1 uses deterministic procedural shapes.
- Fencer and Laserer actions and their terrain masks.
- Exact multi-entrance spawn-order edge cases.
- Exact Slider dehoist transitions and wall pinning.
- Updraft, splat pad, anti-splat pad, force field, splitter, button, locked exit, pickup, teleporter, receiver, and portal effects.
- Gadget animation keyframes, trap occupancy, and paired gadget state.
- Zombie infection, neutralizer, deneutralizer, skill-adder, and skill-remover effects.
- Superlemming behavior and CE-specific physics changes.
- Golden replay comparison against NeoLemmix 12.14 and CE 1.1.2.

Callers must treat unsupported level effects as a load diagnostic until these items are implemented.

## Verification

Run:

```sh
zsh Scripts/run-neolemmix-simulation-tests.sh
```

The script compiles all `NxlvKit` sources and the focused test executable with Swift 6 and warnings as errors. The test groups cover spawn timing, movement, assignments, all implemented skills, steel, directional one-way terrain, hazards, NXLV conversion, replay order, inventory, nuke behavior, and deterministic Codable continuation.
