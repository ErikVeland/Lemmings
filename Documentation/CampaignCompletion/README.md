# Additional campaign completion evidence

The manifest holds 322 fixed-input winning replays. These supplement the original
[120-level DOS gate](../ClassicCompletion/README.md) and the existing L2 tests.

| Campaign | Fixture count and latest result | Open gaps |
| --- | ---: | ---: |
| Oh No! More Lemmings | 100/100 | 0 |
| Xmas 1991 | 4/4 | 0 |
| Xmas 1992 | 4/4 | 0 |
| Holiday 1993 | 32/32 | 0 |
| Holiday 1994 | 32/32 | 0 |
| Oh Yes! conversions | 60/60 | 0 |
| Lemmings 3 | The strict rerun stops at Shadow 7. Egyptian 6 and Egyptian 13 still have no winning route under the current Mole patrol. | Repair affected standalone and carried routes. Then rerun all 90 standalone levels and the carried chains. |

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
witnesses, not original-engine equivalence proofs.

The separate [L3 chain evidence](l3-chain-evidence.json) replays each tribe from
its first level with the population carried from the preceding result. It uses
population-specific fixtures when a standalone input schedule does not work at
the carried population. `zsh Scripts/verify-l3-campaign.sh` checks the
recorded fixture hashes, outcomes and first gap in each tribe; `--require-all`
fails until all three 30-level chains complete with at least 50 survivors at
each tribe's final result. This is native simulation evidence. Focused tests
check the ending decision and movie handover. Player input, recovery, original
engine parity and a played three-tribe finale need separate checks.

The 13 October 2026 native gate passed all ninety standalone routes and all
326 carried fixtures. The 15 October Mole direction and patrol corrections
invalidated route witnesses. The current manifest check passes. A refreshed
Shadow 13 route now passes with ten saved and no losses. The strict route gate
still stops at Shadow 7. Egyptian 6 and 13's old inputs no longer produce a
win, and carried fixture `107-1.json` fails identity. Earlier route and
survivor results do not close the current route gate.

A 15 October follow-up searched Shadow 7 at its one-lemming carried population
for 120 seconds from the start and for another 120 seconds from the accepted
prefix of its old route. Neither search found a win. Egyptian 6 and Egyptian 13
also had 120-second searches at the standalone population of 20; neither found
a win. These bounded searches do not prove that the levels are impossible.
The solver's new engine-refresh seed mode then ran another 120-second search on
each of these three cases from a current-runtime prefix. It found no winning
route. The mode checks the exact level-data hash and population, drops refused
inputs from the prefix and double-replays any route it returns.

`Tools/ClassicCompletion` and `Tools/Lemmings3Completion` can discover routes.
After deliberately adding or improving a fixture, run
`python3 Tools/CampaignCompletion/report.py`, the replay gate, and
`zsh Scripts/verify-trolley-maxima.sh`. The rescue audit imports and verifies
these fixtures, then stamps its results with the current engine fingerprint.
Do not refresh the manifest to hide an unexplained regression.

When an L3 engine change invalidates an input prefix, the solver accepts
`--refresh-engine-seed` with `--seed FILE --seed-through TICK`. This mode still
requires the same level-data hash and population. It rebases the starting state
to the current runtime and drops refused prefix inputs; it does not reuse the
old expected outcome. A new winning route must still pass the solver's two
replays and the full completion gate.

For the selected Classic release, use `--classic-only --require-all`. This checks
all five additional Classic campaigns and reports every missing route. The
conversion fixtures also run through this strict gate, with artwork selected by
source rank. Missing conversion data fails rather than reducing the level count.
The full Classic corpus gate independently replays them. Sequel regression
checks remain separate.

25 Lemmings 3 routes come from the beam solver in
[`Tools/Lemmings3Solver`](../../Tools/Lemmings3Solver). Run
`zsh Scripts/solve-lemmings3-levels.sh missing --fewer-inputs-first --promote` to
search the levels without a fixture. The solver, runtime suite and completion
gates use `Sources/Ports/LEM3CD` by default; set `L3_PORTS_ROOT` to another
`LEM3CD` directory to run against installed bundle data. A second pass without
`--fewer-inputs-first` ranks crowd distance first and finds different levels.
The solver writes a route only after two replays agree, and the gate checks it
again.

For a same-level runtime change, pass `--refresh-engine` to
`Scripts/derive-l3-carried-route.sh` with the same source and target population.
The tool requires an unchanged level-data hash, reapplies the recorded inputs,
and writes a candidate only when the current runtime completes a winning run
that replays twice. Keep the source fixture and output candidate in separate
files.

The official Classic gate is complete: `zsh Scripts/verify-official-classic.sh`
requires all 292 wins and runs the real session/recovery and progression checks.
See [official quest evidence](../ReleaseReadiness/OfficialClassicQuest.json).

Add `--include-conversions` to the official gate to require all 352 Classic wins,
1,056 saved-run restores, 352 progress resumes and six release transitions.
See [combined quest evidence](../ReleaseReadiness/ClassicConversionQuest.json).
