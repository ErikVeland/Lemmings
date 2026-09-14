# Classic 1.0 closure work

14 September 2026. The selected target is a complete macOS Classic release.
Lemmings 2 and Lemmings 3 retain preview status. Shared controls, paused Hot Seat
handovers and saved-run recovery remain regression requirements across all three engines.

Beta 29 is packaged and notarised. The current work after that release has
238 verified official Classic levels, with 54 still missing. This does not
declare a completed or published 1.0.

## Work included in beta 29

- Removed 23 reviewed fan records from ten archives: fourteen empty LemEdit
  records and nine levels referencing unavailable terrain. All 6,020 remaining
  fan levels stay in the catalogue. No complete pack was deleted.
- Preserved every surviving compressed DAT record byte-for-byte. A small archive
  manifest retains original slot numbers, so deletion cannot shift a saved
  attempt to a different level. Restored queues omit deleted entries and retain
  their current attempt. A deleted current level fails without selecting a neighbour.
- Added a reproducible, hash-checked pruning operation to catalogue generation.
  Packaging rejects original or unreviewed versions of the affected archives.
  Exact removals and archive hashes are in `FanLevelPruning.json`.
- Recorded full-rescue routes for Tame 12, 13, 18 and 20. All twenty Tame levels
  now have preserved wins. The official Classic gap falls from 69 to 65.
- Recovered existing rescue-proof routes for Flurry 3 and 5, reducing that gap
  to 63. Also preserved three conversion routes and the full-rescue Xmas 1992
  level 1 route in the campaign fixtures.
- Recorded a full-rescue Flurry 2 route, reducing the official gap to 62.
- Refreshed the solution catalogue to 231 distinct replays for 233 level routes.
  Refreshed the original hint decks against the current engine after replaying
  all 120 solutions. Hint text and opening moves remain unchanged.
- Corrected the proof refresh to replay published Classic witnesses even when
  its output directory starts empty. Packaging now rejects missing or lower
  published rescue targets before replacing the catalogue.
- Added an explicit `classic-1.0` release audit scope. It requires all Classic,
  fan and conversion routes. Sequel regression checks remain enabled, while
  sequel completion and future platform delivery are tracked outside this milestone.

## Work after beta 29

- Added full-rescue routes for Xmas 1992 level 2 and Holiday 1993 Flurry 6, 7, 9,
  11 and 15. Xmas 1992 now has winning evidence for all four levels.
- Replayed every retained Holiday 1993 route and all four Xmas 1992 levels with
  the shipping beta 29 engine. No physics change was needed.
- Updated the hint solution bundle to 237 distinct replays for 239 route
  identities. Refreshed rescue evidence to 177 full-rescue certificates and
  17 best-known rescue records, retaining all earlier targets.
- Added separate L2 carry-over witnesses and tightened its strict completion
  gate. L3 level 5 now has a preserved route. Sequel claims remain previews.
  See [sequel closure work](SequelClosure.md).

Evidence for this work is under `.build/classic-closure` and
`.build/sequel-closure`. The beta 29 archive remains unchanged.
[Beta 30 Game Center](Beta30GameCenterReadiness.md) packages these additions
for the two registered test Macs.

The later Pause and Nuke change restores the original Amiga panel shapes. Its
rendering and click-state tests passed; it is not included in beta 30. The colour
palette is matched to the reference, rather than recovered from the original
hardware palette. See [panel artwork provenance](../Tools/ClassicPanelArt/README.md).

Packaging now rejects version 1.0 and later while any required Classic gate is
open. After those gates are closed, the packager also requires a fresh strict
Classic audit of the signed candidate before creating an archive. That audit
runs after optional soundtrack removal. Keep the candidate inside its source
checkout so its inputs can be recorded and checked for drift. Gate status must
come from reviewed evidence; changing it does not replace validation. Prepare
and validate the release candidate before using the distribution packager.
Pre-1.0 tester builds remain available with their documented gaps.

`Tests/ReleaseReadinessTests/test_package_scope.py` verifies rejection of open
and malformed gates and confirms that a failed candidate audit prevents archive
creation. The release audit also checks the original Pause and Nuke pixel shapes.

## Remaining closure work

| Area | Required outcome |
| --- | --- |
| Official campaigns | Preserve the remaining 56 winning routes: Oh No! 30, Holiday 1993 ten, Holiday 1994 sixteen. |
| Conversions | Preserve the remaining 57 winning routes and verify progression. |
| Fan library | Preserve winning evidence for retained levels. Successful loading alone does not close completion. |
| Full Quest | Verify the 292-level progression, release boundaries, save/resume and final results with winning outcomes. |
| Recovery | Test physical interruption, power loss, installed-release migration and rollback. |
| Input and accessibility | Complete physical controller, VoiceOver and novice-player journeys. |
| Performance | Establish sustained throughput, memory and audio stability on supported hardware. |
| Hardware | Test physical Intel, macOS 13 and the supported display configurations. |
| Services | Validate the advertised account and offline behaviour. |
| Distribution | Resolve the recorded publishing/asset approval, then freeze and verify the actual 1.0 package. |

## Evidence

Evidence for the beta 29 pass is under `.build/classic-one-zero`:

- `pruning-comparison.json` compares the first cleaned corpus with the baseline.
  It records 23 removals, no changed surviving initial states and no lost wins.
- `pruned-fan-tests.log` covers native decoding, preserved slots, deleted slots,
  malformed mappings and restored queues.
- `campaign-current.log` verifies the preserved additional Classic routes with
  the freshly compiled current engine.
- `proof-final` contains replayed rescue evidence from an isolated output directory.
- `final-audit/classic-corpus` contains the beta 29 completion inventory.
- `final-comparison.json` records 6,372 retained official, fan and conversion
  levels, 622 verified wins, no load/start failures, no changed retained initial
  states and no lost wins. Seventeen additional route identities now have wins.
- `build/Ultimate Lemmings.app` is a fresh universal development build. Its
  packaged fan archives, hints and rescue witnesses match the current inputs.
  It has an ad-hoc signature; it is not the notarised beta 28 archive.

The earlier `audit` directory is diagnostic evidence from the start of this pass.
It recorded source drift while the authorised changes were in progress. Its old
resource bundle also exposed stale hint and proof identities. Do not use that
run as final candidate validation.

The strict candidate audit completed with 49 passing checks. Required campaign
and corpus completion checks remain red. The app check rejected an invalid new
test fixture whose queue index disagreed with its saved level index. The fixture
was corrected; the full app journeys then passed on native Apple Silicon and
in the Intel binary under Rosetta, including pruned queue recovery and Hot Seat.
`validation.json` records those follow-up logs and their hashes, zero follow-up
input drift, and the unchanged product inputs. The original audit is retained with that failure and its one-file source drift. No product
source changed during the correction.

Reproduce the strict release audit against the candidate bundle:

```sh
python3 Tools/ReleaseReadiness/audit.py --scope classic-1.0 --app \
  --app-bundle '.build/classic-one-zero/build/Ultimate Lemmings.app' \
  --require-closure --out .build/classic-one-zero/final-audit
```

This command must continue to fail while required routes or release gates remain
open. Beta signing and notarisation do not close a later candidate's package gate.
