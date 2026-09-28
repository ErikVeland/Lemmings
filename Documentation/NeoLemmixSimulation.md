# NeoLemmix simulation phase 1

`NeoLemmixSimulation` is a deterministic, fixed-tick native engine for low-resolution NeoLemmix levels. It has no rendering dependency. The caller supplies collision masks, entrance data, trigger zones, preplaced lemmings, traits, and skill inventory.

The implementation uses NeoLemmix 12.14 behaviour as an oracle. The current
Community Edition contract is CE 1.2.0 at commit
[`38d0449f87501798e78ac668a9494848f4aa9649`](https://github.com/Willicious/NeoLemmixCommunityEdition/commit/38d0449f87501798e78ac668a9494848f4aa9649).
The Swift implementation was written for this project using the published
formats and CE behaviour as references. It does not include NeoLemmix source
text or binary assets.

## Public inputs and state

- `NeoLemmixTerrain` stores solid, steel, and one-way masks.
- `NeoLemmixConfiguration` stores timing, entrances, zones, preplaced lemmings, traits, and skills.
- `NeoLemmixConfiguration(level:renderedLevel:)` converts an `NxlvLevel` and `NxlvRenderedLevel`.
- The static renderer clips paint objects to solid terrain.
- `NeoLemmixReplayCommand` schedules an assignment, spawn interval change, or nuke command by tick and sequence.
- `NxrpReplayDecoder` imports current section-based `.nxrp` metadata and
  commands. It retains all 21 current skill names, including skills that the
  simulator rejects explicitly.
- `NxrpReplayPlayback` checks the recorded level and live assignment state,
  applies source commands in CE frame order and checks the rescue frame.
- `NeoLemmixSnapshot` contains the complete observable state and the events from the last tick.
- `NeoLemmixSimulation` is `Codable`, `Equatable`, and `Sendable`. An encoded state continues deterministically after decoding.

The engine uses lemming foot coordinates. A terrain pixel at the same `(x, y)` position supports a lemming.

## Implemented rules

The phase-1 engine implements these fixed values and state transitions:

- 17 simulation ticks per second.
- Entrance opening on tick 35.
- First release on tick 54 with the default opening timing.
- A minimum spawn interval of 4 ticks.
- Walking, step-up, ascending, falling, climbing, hoisting, floating, swimming,
  diving and splatting.
- A maximum safe fall distance of 62 pixels.
- Exit, locked exit, button, pickup, water, fire, reusable trap, one-shot
  trap, splat pad and anti-splat pad zones.
- Preplaced lemmings, entrance traits, entrance limits, neutral lemmings, and zombies.
- Finite and infinite skill supplies.
- Steel and directional one-way destruction checks.
- Replay command ordering by `(tick, sequence)`.
- Nuke countdown assignment.
- Completion, save counts, loss counts, and time limits.

The engine accepts all 21 current skills:

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
- Laserer
- Basher
- Fencer
- Miner
- Digger
- Cloner

`NeoLemmixRules.implementedSkills` provides this set at runtime.

`NeoLemmixRules.unsupportedSkills` is empty. Unknown future object effects still
produce an explicit unsupported result.

The macOS player resolves the level theme's `LEMMINGS` style at runtime, reads
its `scheme.nxmi`, uses the declared direction-specific foot anchors and applies
athlete, zombie, neutral and theme recoloring, including declared alternate
shades. Jumper artwork follows CE's `0...5`, `6`, and `7...12` progress buckets.
The Stoning phase uses CE's 16-frame Oh-No artwork and its `FOOT_Y 10`
anchor; only the one-frame stone burst uses the Stoner artwork and its
`FOOT_Y 25` anchor.
It does not bundle third-party sprite pixels. The pinned corpus resolves 15,104
representative frames across all 794 levels and 59 themes.

The playfield retains separate background, terrain and foreground layers and
recomposites them from the live `NeoLemmixTerrain` mask when a tick changes.
Destroyed pixels reveal the background. Builder and Platformer pixels retain
CE gradient steps 0 through 11 around the theme `MASK` colour; Stacker pixels
retain steps 4 through 11. Per-pixel provenance makes terrain that is destroyed
and later rebuilt use the new construction colour, including after encoded
recovery. The retained opacity mask also matches CE's rule that construction
replaces partially transparent terrain but preserves fully opaque art. A
completed Stoner uses the external canonical 16-by-11
`gfx/mask/stoner.png` at CE's `X - 8`, `Y - 10` origin, with CE's one-pixel
right-facing offset. Its owner and source-pixel index are retained, existing
terrain is not overwritten, and foreground gadgets keep their layer. The larger
32-by-32 animation frame is not used as the persistent terrain image.

Unlock buttons and locked exits retain every primary-animation frame. They
start on CE frame 1 when buttons exist, advance after lemming processing on the
trigger tick, and settle permanently on frame 0. Locked exits with no buttons
start open on frame 0. Current frames and in-progress transitions survive
encoded recovery.

Reusable and one-shot traps also expose their live primary frame. A trigger
advances frame 0 to frame 1 after lemming processing, the declared animation
then runs to frame 0, and a reusable trap becomes available on the following
lemming-processing pass. Recovery retains the busy frame and transition.

Foreground exits, hazards, force fields, one-way arrows, updrafts, pads,
portals and state changers in CE's always-animate set advance their retained
primary frames from the deterministic simulation tick. Entrances remain on
frame 1 until their configured opening tick, advance on that tick, and settle
on frame 0 after the opening cycle.

## Compatibility boundary

The current NeoLemmix 12.14 and CE 1.2.0 contract is closed by the strict
794-level source corpus, the 160-route Redux replay corpus, an independent CE
terminal-state manifest, and live CE pixel captures for all 21 current skills.
The final-state comparison matches every scalar, lemming, gadget and terrain
field in all 160 records. The selected visual matrix matches all 68 frames with
zero mutually visible RGB differences across seven style families.

Legacy `.nxrp` formats remain outside the current section-based replay contract.
The legacy LVL Superlemming marker remains a separate Classic-family format
concern because CE 1.2 does not parse it from NXLV. Unknown future skills and
object effects produce explicit diagnostics instead of silent fallback.

Basher, Miner, Bomber, Stoner, Fencer and Laserer use the CE mask geometry as
coordinate spans; the repository does not contain the oracle bitmap files.
Grounded Bombers and Stoners use the CE Oh-No fall behavior. Airborne instant
assignments bypass Oh-No and enter the explosion or stone-finish action.

Callers must treat unknown future level effects as a load diagnostic.

## Verification

Run:

```sh
zsh Scripts/run-neolemmix-simulation-tests.sh
zsh Scripts/run-neolemmix-replay-tests.sh
```

The scripts compile all `NxlvKit` sources and focused test executables with
Swift 6 and warnings as errors. The test groups cover spawn timing, movement,
assignments, all implemented skills, steel, directional one-way terrain,
hazards, NXLV conversion, replay ordering, inventory, nuke behaviour, current
replay decoding, checked source-frame playback and deterministic Codable
continuation.

Run the combined source gate with:

```sh
zsh Scripts/check-1.5-neolemmix.sh
```

The [1.7 roadmap](1.7Roadmap.md) defines the pinned real-level corpus, strict
runnable mode and external replay evidence. The development corpus can pass
while it reports unsupported mechanics. Only the strict runnable and reference
replay gates can close those compatibility claims.
