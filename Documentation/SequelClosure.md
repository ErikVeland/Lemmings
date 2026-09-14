# Sequel closure after beta 29

13 September 2026. Lemmings 2 and Lemmings 3 remain previews. This pass adds
completion evidence and closes a gap in the L2 release gate. It does not change
either engine or establish fidelity to the original games.

## Lemmings 2

All 64 existing standalone routes still pass. Sixteen separate witnesses now
replay those inputs with the population saved by the preceding level. Each
candidate was replayed twice before it was retained. The manifest records both
sets of witnesses without replacing the original 60-lemming routes.

| Tribe | Continuous levels from the start |
| --- | --- |
| Classic | 5/10 |
| Beach | 1/10 |
| Cavelem | 3/10 |
| Circus | 2/10 |
| Egyptian | 8/10 |
| Highland | 1/10 |
| Medieval | 1/10 |
| Outdoor | 3/10 |
| Polar | 4/10 |
| Shadow | 1/10 |
| Space | 1/10 |
| Sports | 2/10 |

No tribe yet has a complete continuous run. Coverage remains 64/120 distinct
levels, with 56 missing. Several carry-over routes start with one survivor;
they establish continuity but do not establish a good rescue result or a gold
medal campaign. The original route quality counts remain unchanged.

The strict gate now requires all 120 levels **and** twelve complete tribe
chains. Independent wins cannot satisfy the continuous-run requirement.
It validates each carry-over route before counting it and rejects orphan
variants, duplicate starting populations and invalid witness headers.

The repeatable candidate generator is
[`adapt.swift`](../Tools/Lemmings2Completion/adapt.swift). It stops a tribe when
the next level is missing or its inputs fail with the incoming population.
For example, Cavelem stops at level 4 when an assignment targets a lemming that
is absent from the carried population. The route must change to close that gap.

See the [L2 completion report](Lemmings2Completion/README.md) for retained
witnesses, hashes and gate commands.

## Lemmings 3

Level 5 now has a recorded winning route. It saves one lemming, loses nine and
retains ten in reserve. The result, all inputs and the final state reproduce
through the strict replay validator. Attempts to improve the followers' path
have not yet produced a better retained result.

Coverage is now 17/90, with 73 levels missing. A one-survivor route is limited
completion evidence. Original-game trace comparisons, rescue quality and full
campaign progression remain open.

## Validation

Evidence is under `.build/sequel-closure`:

- `gate.log`: all 64 standalone L2 routes and 16 carry-over variants replayed
  twice, followed by continuous-chain counts.
- `chain-negative.log`: actual replay checks reject damaged carry-over
  witnesses, duplicate starting populations and an orphan variant. Strict mode
  also rejects incomplete campaigns.
- `strict-gate.log`: the full L2 inventory passes replay validation, then
  correctly fails the completion requirement with 56 missing routes and no
  complete tribe chain.
- `reproduction.json`: the candidate generator reproduces all 16 retained
  variants. All 176 product Swift files still match the frozen beta 29 source.
- `negative.log`: the original seven damaged L2 witness cases remain rejected.
- `l3-gate.log`: all 17 L3 routes replayed twice and malformed replay cases
  rejected.

The chain unit tests also cover missing levels, wrong populations and ambiguous
routes. The release audit runs these checks with the existing sequel gates.
Classic, L2 and L3 still share the regression requirements for controls,
Hot Seat handovers and saved-run recovery.

Beta 29 remains the frozen, notarised standard release. These later changes are
packaged in [beta 30 Game Center](Beta30GameCenterReadiness.md) for the two
registered test Macs. They are not declared complete for 1.0.
