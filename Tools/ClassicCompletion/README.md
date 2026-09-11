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
