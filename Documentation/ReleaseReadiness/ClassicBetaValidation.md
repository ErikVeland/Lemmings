# Classic beta validation

12 September 2026. **The Classic release gate remains open.** The corpus audit
covers all 6,395 indexed levels before L2: 292 official campaign levels, 60
Oh Yes! conversions and 6,043 fan levels in 535 archives. This is a validation
report with failures, not a claim that all those levels are playable or complete.

## Candidate and scope

Local development build **20.6** contains source `d3781ad` and the fan fixes below.
It is a Universal, ad-hoc signed app. It is not a notarised beta release.
[Candidate and package evidence](../../.build/classic-validation/evidence/candidate.json).

The final corpus run uses a freshly compiled engine, the candidate's packaged
assets and 215 committed solution fixtures frozen from `56e21e5`. The audited
Ports and LevelPacks directories match all 1,844 corresponding candidate files.
The core source is unchanged from beta 20. Source, assets and fixtures are hashed
before and after the final run. No input drift was detected.

The archive inventory checks files independently of the level decoder. All 1,222
files with decoded level records are represented. The other two candidate INI files are
reviewed graphics definitions. No unaccounted level files remain in these
archives. Future downloads do not inherit this result.

## Results

| Collection | Levels | Reproduced winning routes | Remaining evidence |
| --- | ---: | ---: | --- |
| Lemmings | 120 | 120 | Original-engine equivalence remains a separate claim. |
| Oh No! | 100 | 61 | 39 winning routes |
| Xmas 1991 | 4 | 4 | Preserve these routes. |
| Xmas 1992 | 4 | 2 | 2 winning routes |
| Holiday 1993 | 32 | 13 | 19 winning routes |
| Holiday 1994 | 32 | 15 | 17 winning routes |
| Oh Yes! conversions | 60 | 0 | 60 winning routes |
| Bundled fan levels | 6,043 | 294 | 5749 levels without a verified win, including 94 load/start failures |

Every winning witness is replayed twice from a fresh simulation. Both outcomes
must agree and meet the authored rescue requirement. A matching initial state
only selects a candidate replay; it does not count as a win. Rejected candidate
replays remain unverified and do not, by themselves, prove a physics defect.
The fan wins reuse 120 original-campaign fixtures, largely through redistributed
stock levels. They do not represent 294 newly solved fan puzzles.
Levels without witnesses receive a 180-tick smoke check. That is not a complete
playthrough, a comparison with original software, or a test of every mechanic.

[Per-level results](../../.build/classic-validation/evidence/final-results/levels.jsonl),
[coverage and strict gate result](../../.build/classic-validation/evidence/final-results/coverage.json),
[all remaining evidence gaps](../../.build/classic-validation/evidence/final-results/blockers.json),
and [input hashes](../../.build/classic-validation/evidence/final-results/inputs.json).

## Defects fixed

- Resolve numeric fan graphics slots 0–9 independently of the previously selected
  campaign. Named styles take precedence. Unknown names fail explicitly.
- Resolve Xmas fan graphics to the installed Holiday artwork.
- Use deterministic base sprite and special-graphic assets for fan simulations.
- Return failed fan loads to the level list. Do not show a playable briefing
  backed by the previous session. Build the simulation before replacing its image.

The baseline audit found 1,559 fan load/render failures. The corrected audit finds
94: **1,465 fewer failures**. This measures successful loading and startup, not
physics fidelity. The remaining failures are missing terrain pieces, missing
special graphics and records with no entrance. Each is retained in
[the failure inventory](ClassicBetaValidationFailures.json). Nothing was removed
from the catalogue to improve the result.

## Regression evidence

- Full AppKit integration: controls, speed, Escape, paused keyboard overlay,
  hints, seasonal music, Hot Seat ownership/results, checkpoints and recovery.
- Fan library: offline catalogue, safe updates, duplicate handling, binary INI
  files, all ten graphics slots, named overrides and unsupported-style rejection.
- Classic replay, rewind and all six official datasets.
- All 60 Oh Yes! conversions render and release lemmings with their source artwork.
- All 292 Mac artwork scenes and all 292 Amiga artwork scenes, including sprites
  in both directions. Macintosh level resource decoding also passes.
- Portable engine, modern engine, unified catalogue and packaged-resource checks.
- NeoLemmix simulation: 15 groups, 19 implemented skills and explicit rejection
  of two unsupported skills. No external `.nxlv` playthrough corpus was found in
  the inspected Content, Ports or Tests trees. Synthetic checks do not establish
  complete imported-pack compatibility.
- Eight coverage-gate tests reject smoke-only evidence, omissions, duplicates,
  missing provenance, changed archives and hidden content. A separate manifest
  check confirms that modified assets invalidate a run.

[Regression logs](../../.build/classic-validation/evidence/checks),
[app integration log](../../.build/classic-validation/evidence/app.log),
[fan checks](../../.build/classic-validation/evidence/fan-library-fixed.log),
and [gate tests](../../.build/classic-validation/evidence/report-tests.log).

The controller checks use software events. Physical controller journeys were
not performed, consistent with the user's instruction to proceed without one.
Native Intel hardware, full VoiceOver journeys, continuous campaign endings,
installed-release migration and original-engine reference comparisons remain
separate evidence gaps. They are not closed by these regression results.

## Reproduce

From a checkout with the required packaged resources:

```sh
zsh Scripts/run-classic-validation.sh \
  '/path/to/Ultimate Lemmings.app/Contents/Resources' \
  '/path/to/new-audit-output' '/path/to/frozen-fixture-root'
python3 Tools/ClassicValidation/test_report.py
```

The fixture root must contain `Tests/ClassicDOSCompletionTests/Fixtures` and
`Tests/ClassicFamilyCompletionTests/Fixtures`. Omitting it uses the current
checkout. Use a new output directory and keep inputs unchanged during a run.
The script builds the current core, audits every collection, checks archive
coverage and rejects changed inputs. **A nonzero exit is expected while winning
evidence is missing.** This is the corpus-completion gate, not the whole 1.0 gate.

Claude retains campaign solver and official fixture work. This pass covers fan
resolution, corpus accounting, shared app regression and candidate integration.
The [Classic scope requirements](ClassicScopeClosure.md) remain unchanged.
