# Current Classic validation

13 September 2026. **All 120 original Lemmings levels pass the strict winning-replay gate. The wider Classic/fan completion gate remains open.**

The complete audit accounts for 6,395 levels: 292 official Classic-family levels,
60 conversions and 6,043 fan levels in 535 archives. It uses frozen current audit
and engine sources with the distributed beta 25 assets. No engine rules or bundled
assets changed. The production fan loader and audit now use the same pack graphics.

## Results

| Collection | Levels | Verified winning routes | Load/start failures |
| --- | ---: | ---: | ---: |
| Original Lemmings | 120 | 120 | 0 |
| Oh No! More Lemmings | 100 | 66 | 0 |
| Xmas 1991 | 4 | 4 | 0 |
| Xmas 1992 | 4 | 3 | 0 |
| Holiday 1993 | 32 | 14 | 0 |
| Holiday 1994 | 32 | 16 | 0 |
| Oh Yes! conversions | 60 | 0 | 0 |
| Fan levels | 6,043 | 294 | 85 |

All 517 previously verified wins were reproduced. No previously successful load
became a failure. The official family still needs 69 winning routes; conversions
need 60. Fan levels need 5,749, including the 85 load/start failures. The strict
whole-corpus gate fails with 5,878 levels lacking verified winning evidence.

A successful load receives a 180-tick smoke simulation when no matching winning
witness exists. That is not a complete playthrough. Candidate witnesses are replayed
twice from fresh simulations and must win with identical outcomes. The separate
original-game gate also checks input acceptance and retained expected outcomes.
Winning routes do not establish exact equivalence with every original-engine quirk.

## Defects fixed

Fan packs previously ignored their bundled terrain definitions and special pictures.
The loader now checks assets beside the level, then at the archive root, and uses
stock files only when a pack provides no replacement. It also recognises the older
letter-coded special filenames found in Supaplex Tricks and The Mon0lith. Assets
are read directly from archives without extracting their paths. Archive listings
are cached and refreshed when file metadata changes.

Nine formerly failing fan levels now render and start:

- Through the thicket
- Supaplex Tricks...
- The Apple Computer Level
- The Mon0lith
- A Beast of a level
- MENACING !!
- What an AWESOME level
- A BeastII of a level
- SUNSOFT Special

The corrected artwork changes 19 initial simulation states, including those nine
recovered levels. No verified winning witness was lost. Existing saved fan runs
retain the graphics rules they started with; a new attempt uses the corrected
assets. An app test restores a pre-change Genesis checkpoint to the identical
state and verifies that retry switches to the corrected graphics.

The remaining 85 failures consist of 71 levels referencing unavailable terrain
pieces and 14 records with no entrance. They remain in the catalogue and in the
[failure inventory](ClassicValidation-current-failures.json). They were not removed
or counted as successful playability checks.

## Validation and evidence

- Strict original-game replay gate: 120 passed, zero missing or failed.
- Eight focused regression suites passed: campaign flow, settings, physics, rewind,
  replay, unified catalogue, packaged resources and port-exclusive content.
- Fan-library tests passed for stock fallback, custom terrain, special pictures and
  both letter-coded packs, including rendering and simulation startup.
- App integration passed for Hot Seat boundaries, paused resume, fan recovery,
  legacy graphics checkpoints and retry. The last letter-mapping addition was
  covered by the fan-library tests and complete corpus rerun.
- Eight coverage-gate tests passed. Merge tests reject duplicate fan evidence and
  conflicting official results. The final scan partitions fan archives across four
  processes, compares repeated official evidence, then checks the complete inventory.
- Both baseline and final input manifests report no drift. The final gate's only
  failure is missing winning evidence; there are no inventory or provenance omissions.

[Per-level results](../../.build/classic-current-validation/release-results/levels.jsonl),
[coverage gate](../../.build/classic-current-validation/release-results/coverage.json),
[before/after comparison](../../.build/classic-current-validation/release-comparison.json),
[input hashes](../../.build/classic-current-validation/release-results/inputs.json),
and [original 120 results](../../.build/classic-current-validation/original-120.log).

The scan also inventories 19 bundled Lemmix recordings and two solution text files
across three packs as candidates for the solver owner. These are not counted as
verified wins. See `.build/classic-current-validation/bundled-route-candidates.json`.

These source fixes are not in the existing signed beta 25 ZIP. L2/L3 completion,
physical hardware/controller testing and full original-engine equivalence are not
established by this Classic audit.
