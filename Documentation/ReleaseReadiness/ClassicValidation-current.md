# Current Classic validation

22 September 2026. **All 6,372 retained levels load and render. Official Classic
coverage is 292/292 and conversion coverage is 60/60. The corpus gate passes.**

The corpus contains 292 official Classic levels, 60 conversions and 6,020 fan
levels in 535 archives. Each matching replay runs twice. Levels without a
matching replay run a 180-tick smoke check. Loading and a smoke check do not
establish a completed playthrough.

| Collection | Levels | Verified winning routes | Load/render failures |
| --- | ---: | ---: | ---: |
| Original Lemmings | 120 | 120 | 0 |
| Oh No! More Lemmings | 100 | 100 | 0 |
| Xmas 1991 | 4 | 4 | 0 |
| Xmas 1992 | 4 | 4 | 0 |
| Holiday 1993 | 32 | 32 | 0 |
| Holiday 1994 | 32 | 32 | 0 |
| Oh Yes! conversions | 60 | 60 | 0 |
| Fan levels | 6,020 | 344 | 0 |

The corpus has 696 winning identities. All official and conversion levels have
winning routes. The owner removed the fan winning-route requirement on
22 September. Nine fan entries reject available replay candidates. Those entries
are not counted as wins. No fan archive or level was removed in this pass.

## Fan evidence after the DOS rules correction

The earlier 15 September exit-fix corpus recorded 394 fan wins. The current
corpus has the same 6,020 fan identities and initial state hashes. Ninety-nine
old fan witnesses no longer match because their shared campaign fixtures now
use the later DOS rules. Seven other fan identities gained matching witnesses,
leaving 302 wins in the earlier official-only run. The conversion closure adds
42 matching fan witnesses, bringing current fan coverage to 344. All 99 unmatched
witnesses point to replaced fixture identities, rather than a replay that ran and stopped winning in this pass.

This is reduced current replay coverage. It does not establish broken fan
levels or prove the older routes against the current engine. The comparison is
recorded in `.build/closure-sep22/fan-evidence-comparison.json`.

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

## Evidence

The full run is `.build/closure-sep22/corpus-conversions-parallel`. Its `coverage.json` checks
all archive hashes, decoded counts, level identities and inventory. All required
checks pass. `levels.jsonl` contains every result. `blockers.json` is empty.
The [preserved summary](ClassicConversionCorpus.json) includes the result hashes.

The nine failed optional fan candidates remain visible in `levels.jsonl`.
The separate load/render failure register is
[ClassicValidation-current-failures.json](ClassicValidation-current-failures.json).

See [22 September campaign closure](CampaignClosure-2026-09-22.md) for strict
route checks, new plans, refreshed hints and rescue certificates. This run used
a fresh native engine with the existing local bundled game data. It is not a
signed candidate audit and does not certify the final 1.0 archive.

Earlier pruning evidence remains under `.build/classic-one-zero` and
`.build/classic-closure`. See [fan style conventions](FanStyleConventions.md),
[Holiday graphics](HolidayStyleClosure.md), [exact archive selection](LiteralArchiveClosure.md)
and [Holiday aliases](HolidayAliasClosure.md). Published beta archives remain unchanged.
