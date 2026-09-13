# Current Classic validation

13 September 2026. **All 120 original Lemmings routes pass. Official Classic
coverage is 236/292. The wider completion gate remains open.**

The retained corpus contains 6,372 levels: 292 official Classic-family levels,
60 conversions and 6,020 fan levels in 535 archives. The user authorised deletion
of empty and malformed fan levels. Twenty-three records were removed from ten
archives. No complete pack was removed.

## Coverage

| Collection | Levels | Verified winning routes | Load/start failures |
| --- | ---: | ---: | ---: |
| Original Lemmings | 120 | 120 | 0 |
| Oh No! More Lemmings | 100 | 70 | 0 |
| Xmas 1991 | 4 | 4 | 0 |
| Xmas 1992 | 4 | 4 | 0 |
| Holiday 1993 | 32 | 22 | 0 |
| Holiday 1994 | 32 | 16 | 0 |
| Oh Yes! conversions | 60 | 3 | 0 |
| Fan levels | 6,020 | 390 | 0 |

There are 629 verified wins. The remaining 5,743 identities need winning evidence:
56 official levels, 57 conversions and 5,630 fan levels. Ten fan entries reject
available candidate replays. Those candidates are not counted as wins and their
failure does not establish that the levels are impossible.

The retained corpus passed loading, rendering and a 180-tick smoke simulation.
A smoke simulation is not a completed playthrough. Matching witnesses must replay
twice from fresh simulations and reproduce the stored winning outcome.

## Pruning and saved runs

The removed records were fourteen empty LemEdit slots with no terrain or objects,
and nine levels that reference unavailable terrain. The
[pruning manifest](../FanLevelPruning.json) records their names, original slots,
reasons and before/after archive hashes.

Every surviving compressed DAT record is unchanged. The archive slot map keeps
original identities instead of renumbering survivors. Old saved attempts therefore
select the same level. Restored queues omit deleted entries and keep their selected
attempt, state and ownership. A deleted selected level cannot open a neighbour.

Catalogue generation applies only the reviewed, hash-matched transformations.
Packaging rejects an unpruned or unreviewed version of an affected archive.
The former failures were deleted from the source assets, not reclassified as
successful playthroughs. Their removal is explicit in the corpus comparison.

## Route additions

After beta 29, full-rescue routes were added for Xmas 1992 level 2 and Flurry 6,
7, 9, 11 and 15. All six were replayed twice. Xmas 1992 now has all four wins.

New full-rescue routes cover Tame 12, 13, 18 and 20, plus Flurry 2. Existing rescue
proofs supplied strict campaign fixtures for Flurry 3 and 5 and three conversions.
The Xmas 1992 level 1 fixture now preserves its existing full-rescue proof.

All previous corpus wins remain valid. The native engines were not changed by
this closure pass. The shared controls and recovery remain subject to regression
checks across Classic, L2 and L3.

## Evidence

Current work is recorded in [Classic 1.0 closure](../ClassicOneZero.md).
The current full-corpus run is `.build/classic-closure/corpus`. Its input-drift
check is empty. The comparison against beta 29 retains all 622 earlier wins and
all initial states, and adds seven winning identities.

Earlier pruning and beta 29 evidence remains under `.build/classic-one-zero`:

- `pruning-comparison.json`: exactly 23 removed records, no changed retained
  initial states, no lost wins and no load/start failures.
- `pruned-fan-tests.log`: native parsing, original slot identities, saved queues,
  direct selection of removed slots and rejected malformed mappings.
- `campaign-current.log`: all preserved additional Classic routes, including the
  final Flurry 2 addition, replayed against the freshly compiled current engine.
- `final-corpus`: the complete cleaned corpus before the final Flurry 2 addition,
  with 621 wins, unchanged inputs and explicit remaining coverage gaps.
- `final-audit/classic-corpus`: the candidate audit output when the final strict
  release command is run. Its own inputs and results govern its claims.

Earlier loader corrections remain documented in [fan style conventions](FanStyleConventions.md),
[Holiday graphics](HolidayStyleClosure.md), [exact archive selection](LiteralArchiveClosure.md)
and [Holiday aliases](HolidayAliasClosure.md). The frozen beta 28 and beta 29 ZIPs are unchanged.
