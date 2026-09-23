# Classic completion evidence

`Scripts/verify-classic-completion.sh` builds the current engine and checks all 120
retail levels against `Tests/ClassicDOSCompletionTests/Fixtures`. Every replay
must consume all inputs, apply every skill, win with the retail settings, match
its stored outcome and reproduce it from a fresh simulation. Missing fixtures,
invalid inputs, changed results and timeouts fail the process.

The native fixtures are sufficient for verification; external recordings are
not required. `CLASSIC_COMPLETION_FIXTURES` selects a separate fixture directory
for negative tests. Run `python3 Tests/ClassicDOSCompletionTests/test_gate.py VERIFIER DATA_DIRECTORY` to exercise the failure cases.

Discovery modes use the same final validation. They do not count incomplete
searches as passes:

- `maximize`, `maximize-adapt`, and `maximize-guided`: test every matching candidate and retain only higher rescue counts.
- `polish`: test input removal and timing changes, retaining higher rescue counts.
- `augment`: test an extra builder assignment after existing builder inputs.
- `search`: sample one assignment, allowing losses within the rescue requirement.
- `tutorial`: generate inputs from the tutorial policies in this tool.
- `import`: test decoded Lemmix recordings, including levels with matching terrain.
- `adapt` and `guided`: generate adjusted inputs, then verify the resulting replay.
- `plan`: execute a local plan and save the resulting fixed input sequence.
- `refresh`: rerun existing input sequences after an engine change and record new
  outcomes only if they still win and reproduce exactly.

Use `python3 Tools/ClassicCompletion/import_lemmix.py DIRECTORY` to decode local
Lemmix v1 `.lrb` files. The format comes from the Lemmix player's `LemGame.pas`.
Decoded inputs are candidates, not evidence that our engine can complete a level.

The executable arguments are `MODE DATA_DIRECTORY [LEVEL [PLAN [RATE [RATE_TICK]]]]`.
`LEVEL` is 1–120. Plans use native coordinates; `id: -1` refers to the last selected
lemming. The optional release rate is recorded at `RATE_TICK`, which defaults to 1.
For the retained plans, Mayhem 20 uses rate 99 at tick 1; Taxing 24 uses rate 99 at
tick 600. Other plans use the level's default rate.

Plans cannot replace a valid replay with a lower rescue count. `CLASSIC_DISCOVERY_TRACE=1` prints discovery inputs and positions. The native tutorial policies also contain the recovered full-rescue routes for Tricky 4, Tricky 21, and Taxing 14.

After the full replay gate passes, run `python3 Tools/ClassicCompletion/report.py` to update the report, then `python3 Tools/ClassicCompletion/report.py --check` to check its fixture hashes and source fingerprint. Published DOS records are reference targets, not native upper-bound proofs.

Completion and optimality are separate. A full-population rescue proves a zero-loss
maximum. A replay with losses proves only that its rescue count is achievable.

The `*-route.json` files in `Plans` preserve native event sequences found during
route discovery. They use the replay format, not the coordinate-plan format.
The verified copies, including expected outcomes, are in the completion fixtures.
These routes cover Tricky 16, Taxing 7, Mayhem 15, and Mayhem 18; Taxing 24 retains its
coordinate plan.

## Recorded player inputs

Completed Classic wins are saved in
`~/Library/Application Support/Ultimate Lemmings/ClassicRoutes`.
Use the app's **Show Recorded Routes** command to open this folder.
Recordings contain native input timing and a verified outcome. They contain no
player name or Game Center account identifier.

Use `recorded DATA_DIRECTORY LEVEL RECORDING_DIRECTORY` to import a matching
recording. Set `CLASSIC_COMPLETION_FAMILY=1` for a family campaign and
`CLASSIC_COMPLETION_FIXTURES` to its fixture folder. Import checks the initial
state, accepted assignments, consumed inputs and exact winning outcome twice.
It cannot replace a better existing rescue count. Both legacy before-tick and
live after-tick inputs remain supported.

After adding a family fixture, regenerate the campaign manifest, solution bundle
and hint catalogue. `Tools/SolutionReplays/generate.py --check` checks the bundle
without rewriting it. `Tests/LevelHintCatalogueTests/test_export.py` checks fresh
export, a changed outcome and optional live recorded input.

The Holiday 1993 plans added on 15 September use rate 99 at tick 600 for
Flurry 12 and Blizzard 8, tick 1000 for Flurry 13, tick 110 for Blizzard 3, and
tick 1900 for Blizzard 11. Holiday 1994 Frost 8 uses rate 99 at tick 1.
All other new plans retain their default rates.
See `Documentation/ReleaseReadiness/CampaignClosure-2026-09-22.md` for the retained baseline provenance.

## Level lab

`Lab/main.swift` renders a level and runs an ordered plan against the native
engine. Build it against the local NxlvKit library, as the verify script does.

- `info DATA LEVEL` prints the population, skills, entrances and triggers.
- `run DATA LEVEL PLAN [--png FILE --crop x1,y1,x2,y2 --scale N]` draws the
  terrain, triggers and lemmings at the end of the run.
- `--trace IDS --every N` prints lemming positions. `--lost` prints losses.
- `--out FILE` writes a winning run as a live after-tick replay.
- `columns` and `steelmap` print terrain heights and steel.

Lab plans are in `Plans/lab`. A step can match a lemming by id, position range,
direction, action and earliest tick. A step can also set the release rate or
start a nuke. The lab output is only a candidate. Import it with the `recorded`
mode, which replays it twice and rejects refused or unused inputs.
Each committed lab plan reproduces its fixture exactly.

A plan step with `"async": true` runs when it matches, without waiting for earlier
steps. Add `"exactTick": true` to apply it only at its `tick`.
`beam DATA LEVEL PLAN --id N --target x,y[;x,y...]` searches skill assignments for
one lemming toward the given waypoints. It prints the assignments as exact-tick
steps. Run them with `run` and import the result like any other candidate.

## Oh Yes! conversions

Use `conversion:PORTS_DIRECTORY` as the data argument for the strict verifier.
Set `CLASSIC_COMPLETION_FIXTURES` to the separate Oh Yes! fixture folder.
`recorded`, `verify-known` and `verify` use the same input and outcome checks as
other Classic campaigns. Artwork follows each rank, including the Sunsoft
fallback assets. All 60 levels must be present even when checking one route.

`Scripts/verify-campaign-completion.sh` includes conversions and their negative
checks. `--require-all --classic-only` requires all 172 additional official
Classic levels and all 60 conversions. The Original 120 retain their own gate.

## Complete official Classic gate

Run `zsh Scripts/verify-official-classic.sh` for all 292 official levels. It
requires every fixture, replays it twice, then runs the real app session through
three saved-run restores per level and checks progress through all six releases.
The default report is `.build/official-classic/quest.json`. Set
`CAMPAIGN_TEST_RESOURCES` to a candidate app’s `Contents/Resources`; set
`CAMPAIGN_TEST_LIBRARY_DIR` to reuse an already verified current engine build.
The broader campaign gate still requires all conversions.
