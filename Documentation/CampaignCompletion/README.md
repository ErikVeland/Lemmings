# Additional campaign completion evidence

The manifest holds 205 fixed-input winning replays. These supplement the original
[120-level DOS gate](../ClassicCompletion/README.md) and the existing L2 tests.

| Campaign | Winning replays | Levels without a fixture |
| --- | ---: | ---: |
| Oh No! More Lemmings | 89/100 | 11 |
| Xmas 1991 | 4/4 | 0 |
| Xmas 1992 | 4/4 | 0 |
| Holiday 1993 | 32/32 | 0 |
| Holiday 1994 | 32/32 | 0 |
| Oh Yes! conversions | 3/60 | 57 |
| Lemmings 3 | 41/90 | 49 |

These counts come from the committed [fixture manifest](evidence.json).
To confirm them, run `python3 Tools/CampaignCompletion/report.py --check`.

Run `zsh Scripts/verify-campaign-completion.sh` after building the local app.
The script uses its native NxlvKit library, checks the committed
[fixture manifest](evidence.json), then replays every known solution. Missing
or changed committed fixtures fail. Levels without recorded evidence are
reported separately. Add `--require-all` to fail on any uncovered level.
An uncovered level is not evidence of a broken level.

Classic-family replays use the existing strict DOS replay format and real
campaign data. Local reference candidates and small route searches supplied
the inputs; only routes that completed in this engine were retained. The gate
does not need the reference downloads. It checks level identity, accepted
assignments, completion and exact recorded outcome.

L3 fixtures record inputs at simulation ticks, a level-data hash, initial state
and final state hashes, and rescue, loss and reserve counts. Every retained
route is replayed twice with 20 carried-in lemmings, plus the extra lemmings
placed in that level. The verifier rejects
invalid actions, changed data, wrong level numbers and changed outcomes. Its
negative tests deliberately damage each kind of evidence. Some routes use the
game's End Run action after rescuing at least one lemming. Reserves are reported
separately; they are not counted as rescues. These are standalone winning
witnesses, not continuous campaign runs or original-engine equivalence proofs.

`Tools/ClassicCompletion` and `Tools/Lemmings3Completion` can discover routes.
After deliberately adding or improving a fixture, run
`python3 Tools/CampaignCompletion/report.py`, the replay gate, and
`zsh Scripts/verify-trolley-maxima.sh`. The rescue audit imports and verifies
these fixtures, then stamps its results with the current engine fingerprint.
Do not refresh the manifest to hide an unexplained regression.

For the selected Classic release, use `--classic-only --require-all`. This checks
all five additional Classic campaigns and reports every missing route. The
conversion fixtures are replayed by the full Classic corpus gate. Sequel regression
checks remain separate.

24 Lemmings 3 routes come from the beam solver in
[`Tools/Lemmings3Solver`](../../Tools/Lemmings3Solver). Run
`zsh Scripts/solve-lemmings3-levels.sh missing --fewer-inputs-first --promote` to
search the levels without a fixture. A second pass without `--fewer-inputs-first`
ranks crowd distance first and finds different levels. The solver writes a route only after two
replays agree, and the gate checks it again.
