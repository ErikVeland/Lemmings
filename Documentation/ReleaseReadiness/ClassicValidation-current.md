# Current Classic validation

## Latest route audit

The latest available strict audit is dated 16 October 2026. It covers the 6,020
bundled fan levels and all 352 official and conversion routes. It passes all
352 official routes, verifies 2,403 fan routes, records 18 rejected fan route
candidates, and finds 3,599 fan levels without a matching candidate. In total,
3,617 bundled fan levels still lack a verified winning route. There are no
load, decode or render failures. The strict bundled route gate remains open.
The audit used the modified worktree based on `9862374431ff67e67e084eb1f8416eb088b09ea3`
and the installed 1.9.1 build 76 resource tree. It did not include imported
levels. See the [audit record](2.0-build83/classic-fan-current-main-audit-reconciled-2026-10-16/audit.json),
[level results](2.0-build83/classic-fan-current-main-audit-reconciled-2026-10-16/levels.jsonl)
and [coverage gate](2.0-build83/classic-fan-current-main-audit-reconciled-2026-10-16/coverage.json).

The route MVP is one verified winning replay per bundled level. Keep an
existing route when it still wins. Do not search to maximise rescues or minimise
inputs. This audit proves the recorded outcomes for its source and content
snapshot; rerun affected routes after a relevant engine or level-data change.

## 22 September corpus snapshot

The earlier corpus audit found that all 6,372 retained levels load and render.
It verified 292/292 official Classic routes and 60/60 conversion routes. Its
default corpus gate did not require winning routes for fan levels. That result
is historical and does not close the current strict fan-route gate.

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

The snapshot contained 696 winning identities. All official and conversion
levels had winning routes. No fan archive or level was removed in that pass.

## Historical fan evidence after the DOS rules correction

The 15 September exit-fix corpus recorded 394 fan wins. The 22 September
snapshot retained the same 6,020 fan identities and initial state hashes. Ninety-nine
old fan witnesses no longer match because their shared campaign fixtures now
use the later DOS rules. Seven other fan identities gained matching witnesses,
leaving 302 wins in the earlier official-only run. The conversion closure adds
42 matching fan witnesses, bringing current fan coverage to 344. All 99 unmatched
witnesses point to replaced fixture identities, rather than a replay that ran
and stopped winning in that pass.

This is reduced replay coverage for that historical engine state. It does not
establish broken fan levels or prove the older routes against the current
engine. The comparison is recorded in
`.build/closure-sep22/fan-evidence-comparison.json`.

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

The nine failed optional fan candidates from this snapshot remain visible in
`levels.jsonl`. The separate load/render failure register is
[ClassicValidation-current-failures.json](ClassicValidation-current-failures.json).

See [22 September campaign closure](CampaignClosure-2026-09-22.md) for strict
route checks, new plans, refreshed hints and rescue certificates. This run used
a fresh native engine with the existing local bundled game data. It is not a
signed candidate audit and does not certify the final 1.0 archive.

Earlier pruning evidence remains under `.build/classic-one-zero` and
`.build/classic-closure`. See [fan style conventions](FanStyleConventions.md),
[Holiday graphics](HolidayStyleClosure.md), [exact archive selection](LiteralArchiveClosure.md)
and [Holiday aliases](HolidayAliasClosure.md). Published beta archives remain unchanged.
