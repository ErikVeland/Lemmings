# Lemmings 2 completion gate design

13 September 2026. Scope: route evidence for the twelve Lemmings 2 tribes.
This document designs the gate. It does not record any new route.

## Problem

The Classic family has a strict evidence gate. A committed manifest hashes every
fixture. Two shell scripts run the gate outside the test suite. A `--require-all`
mode fails on uncovered levels. Negative tests prove the gate rejects damaged
evidence. A solver tool finds new routes.

Lemmings 2 has none of this. Its 64 recorded routes live in
`Tests/Lemmings2RuntimeTests/Fixtures`. Only the 1,600-line runtime suite reads
them. Nothing hashes the set, so a fixture can appear or disappear without a
failure. No tool searches for new routes.

Current state, measured on 13 September 2026:

- 120 campaign levels across twelve tribes. 64 have a recorded route.
- 46 of those 64 routes rescue exactly one lemming of sixty.
- All 64 replay correctly. The suite passes.

## Decisions

The user made these choices during design.

1. **Two tiers.** Tier 1 is one independent winning route for each level. Tier 1
   gates coverage. Tier 2 is medal quality. Tier 2 reports only and gates nothing.
2. **Full parity.** L2 gets the manifest, the standalone script, the
   `--require-all` mode, the negative tests and a generated coverage document.
3. **Build a solver.** L2 gets its own route discovery tool.
4. **Move the fixtures** to `Tests/Lemmings2CompletionTests/Fixtures`. This
   separates route evidence from physics unit tests and matches
   `Tests/ClassicFamilyCompletionTests/Fixtures`.
5. **Report chaining, do not gate it.** See the next section.

## Population carry-over

`Lemmings2Campaign.population` returns 60 for the first level of a tribe. For
every later level it returns the saved count of the previous level. A route is
therefore not independent of the route before it.

Every current fixture assumes a population of 60. Most do not chain. The Classic
tribe saves 60 on level 1 and one lemming on level 2. Its level 3 fixture still
assumes 60. A continuous run cannot reach that route.

The gate records this rather than hiding it.

- Each fixture states the starting population it assumes.
- A tribe **chains** when level 1 assumes 60, and each later level assumes a
  population no greater than the saved count of the level before it.
- The coverage document reports chain status for each tribe.
- Chain status does not gate tier 1.

Today no tribe chains. The document must say so.

## Architecture

One replay implementation serves both the gate and the test suite. This prevents
the two from drifting apart.

| Component | Responsibility |
| --- | --- |
| `Sources/NxlvKit/Lemmings2ReplayWitness.swift` | Decode a fixture. Run it against a level, style and masks. Return saved count, medal, ticks and a state hash. |
| `Tools/Lemmings2Completion/main.swift` | Command line gate. Modes `verify`, `verify-known` and `--require-all`. Holds the negative tests. |
| `Tools/Lemmings2Completion/report.py` | Generate `evidence.json` from the committed fixtures. `--check` asserts the manifest matches the files. |
| `Scripts/verify-lemmings2-completion.sh` | Build the library and the tool, then run the gate. |
| `Documentation/Lemmings2Completion/README.md` | Coverage table, chain status and medal counts. |
| `Tests/Lemmings2RuntimeTests/main.swift` | Drops its inline replay block. Calls the shared witness instead. |

The solver is a separate sub-project. It reuses the same witness type, so any
route it finds passes the same gate as a hand-played route.

## Manifest

`Documentation/Lemmings2Completion/evidence.json`:

```json
{
  "schemaVersion": 1,
  "coverage": { "beach": 5, "circus": 7 },
  "quality": { "gold": 5, "silver": 3, "bronze": 56, "bareSurvivals": 46 },
  "chains": { "beach": false, "circus": false },
  "fixtures": [
    {
      "fixture": "Tests/Lemmings2CompletionTests/Fixtures/beach-01.json",
      "sha256": "...",
      "tribe": "beach",
      "level": 1,
      "levelSHA256": "...",
      "startingPopulation": 60,
      "saved": 29,
      "medal": "silver",
      "ticks": 8100
    }
  ]
}
```

`coverage` counts routes for each tribe. `quality` counts medals. `chains`
reports the carry-over result. `report.py --check` compares a fresh scan against
the committed file and fails on any difference.

`Lemmings2Campaign.medal` returns gold, silver or bronze for every win. It
returns none only when the run saves nobody, which the gate already rejects.
Bronze therefore covers everything from one rescued lemming upward. The medal
alone hides a bare survival, so the manifest also counts routes that save
exactly one lemming. The coverage document reports that number next to the
medals.

## Verification rules

The gate accepts a route only when every rule holds.

1. The fixture level hash matches a campaign level.
2. The run starts from a fresh runtime with the stated starting population.
3. The runtime accepts every recorded input at its recorded tick.
4. Each input follows the one before it in tick order.
5. The run completes within the recorded tick count.
6. The final saved count equals the recorded value.
7. A second run from a fresh runtime produces the same outcome and state hash.

A matching start state selects a candidate. It does not prove a win.

## Negative tests

The tool proves the gate rejects each kind of damaged evidence. It mirrors the
L3 gates already in `Tools/Lemmings3Completion`.

- A missing fixture for a covered level.
- A changed starting population.
- A changed level hash.
- A wrong tribe or level number.
- A changed saved count.
- An input the runtime rejects.
- Inputs out of tick order.
- A fixture added without a manifest entry.
- A manifest entry without a fixture.

Each test damages one field and requires a failure.

## Testing

1. Run the new script against the committed fixtures. Expect 64 verified and 56
   uncovered.
2. Run the script with `--require-all`. Expect failure, naming the 56 levels.
3. Run `report.py --check` against the committed manifest. Expect a pass.
4. Add, remove and edit a fixture in a scratch copy. Expect three failures.
5. Run the negative tests. Expect every damaged case to fail the gate.
6. Run the existing runtime suite. Expect the same 64 passes through the shared
   witness.

## Out of scope

- The L2 route solver. It is the next sub-project.
- The 69 missing Classic routes and the 60 conversions. The existing Classic
  tool covers that work and needs no new design.
- Original-engine fidelity comparison. That gate stays open and separate.
- Medal improvement for the 46 bare survivals. Tier 2 reports it. No gate
  depends on it.
