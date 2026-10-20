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
| Lemmings 3 | Current worktree audit: 399/416 fixtures double-replay. Four standalone level identities lack a current win: Shadow 7 and Egyptian 6, 13 and 29. Thirteen failed carried schedules overlap those same four levels. | Find one verified win for each of the four levels. Then verify one complete carried campaign path for each bundled tribe. Check source-engine parity, media and the campaign finale. |

These counts come from the committed [fixture manifest](evidence.json). The worktree audit records the current runtime source hash in the [MVP audit](../ReleaseReadiness/L3MoleVerification-2026-10-15/current-worktree-mvp-fixture-audit-8c66ef3e-2026-10-18.json).
To confirm them, run `python3 Tools/CampaignCompletion/report.py --check`.

The 20 October source-driven Mole timing update left 399 of 416 L3 replay
scenarios with exact double-replay evidence after six winning level-113 state
identities were refreshed. Their input streams did not change. The runtime
suite passes; the strict completion gate remains open at Shadow 7 and carried
fixture `107-1`. Current Mole trace counts and source hashes are in the
[current-source trace record](../ReleaseReadiness/L3MoleVerification-2026-10-15/current-main-mole-trace-2026-10-20.json).

For bundled levels, route closure means one verified winning route per level.
The 416-fixture L3 audit includes extra population-specific carried schedules;
its 17 failed scenarios do not represent 17 different levels. Do not search to
improve a route that already wins. Keep the broader fixture audit as diagnostic
evidence, and check the chosen full campaign paths separately.

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

The separate [L3 chain evidence](l3-chain-evidence.json) records an earlier
engine state. It must be regenerated after the current route repairs. It replays each tribe from
its first level with the population carried from the preceding result. It uses
population-specific fixtures when a standalone input schedule does not work at
the carried population. `zsh Scripts/verify-l3-campaign.sh` checks the
recorded fixture hashes, outcomes and first gap in each tribe.
`zsh Scripts/verify-l3-campaign.sh --require-routes` fails when a level has no
verified route through a complete carried path for its tribe. `--require-all`
also requires at least 50 survivors at each tribe's final result, as required
for the original finale. The 50-survivor ending is a stretch goal for bundled
MVP route closure. This is native simulation evidence. Focused tests check the
ending decision and movie handover. Player input, recovery, original engine
parity and a played three-tribe finale need separate checks.

After route repairs, regenerate `l3-chain-evidence.json` with
`zsh Scripts/verify-l3-campaign.sh --write`, review the new outcomes, then run
`--require-routes` for the bundled MVP gate.

The 13 October 2026 native gate passed all ninety standalone routes and all
326 carried fixtures. The 15 October Mole direction and patrol corrections
invalidated route witnesses. The current fixture hash manifest passes for its
322 fixed-input Classic-family and L3 fixtures. The exhaustive audit now double-
replays 399 of 416 retained fixtures. The 17 scenario failures are four
standalone routes—Shadow 7 and Egyptian 6, 13 and 29—and thirteen carried
schedules for those same levels: `107-1`, `107-22`, `107-23`; `206-1`, `206-11`, `206-22`, `206-23`;
`213-1`, `213-8`, `213-21`, `213-22`; and `229-15`, `229-43`. The five
carried Shadow 13 routes (`113-1`, `113-21`, `113-22`, `113-25`, `113-26`)
were refreshed from retained inputs and now double-replay exactly. Current
campaign and 50-survivor results remain unproved until a current continuous
campaign path passes the gate. MVP route work does not require replacing every
population-specific schedule. See the [L3 Mole verification
record](../ReleaseReadiness/L3MoleVerification-2026-10-15/README.md).

A 15 October follow-up searched Shadow 7 at its one-lemming carried population
for 120 seconds from the start and for another 120 seconds from the accepted
prefix of its old route. Neither search found a win. Egyptian 6 and Egyptian 13
also had 120-second searches at the standalone population of 20; neither found
a win. These bounded searches do not prove that the levels are impossible.
The solver's new engine-refresh seed mode then ran another 120-second search on
each of these three cases from a current-runtime prefix. It found no winning
route. The mode checks the exact level-data hash and population, drops refused
inputs from the prefix and double-replays any route it returns.

A 15 October follow-up attempted to refresh the old standalone and carried
inputs for all four affected levels. None of the thirteen stale schedules won.
The five Shadow 13 inputs won and have since been refreshed. Egyptian 29 also
had a 120-second current-runtime search, seeded through tick
1500 from its old route, with beam 1024 and 8-pixel tool-site sampling. It
expanded 1,261,162 candidates and found no win. Its route remains open; this
bounded search does not show that the level is unsolvable.

Two further Shadow 7 searches at the one-lemming carried population each ran
for 600 seconds with tool-site sampling at 16 pixels. The refreshed-seed search
used the accepted old-route prefix through tick 1650, expanded 6,184,978
candidates and raised the beam to 4,096. The unseeded search expanded
8,967,625 candidates at beam 2,048. Neither found a win; each best partial
saved zero and lost zero. These bounded searches do not prove that Shadow 7 is
unsolvable.

A third 600-second unseeded Shadow 7 search used a 4,096-candidate beam,
8-pixel tool-site sampling and fewer-inputs-first ranking. It expanded
7,973,530 candidates without a win; its best partial saved zero and lost zero.
This bounded search also leaves solvability open.

After the Shadow 13 refresh, two further current-runtime searches resumed the
Shadow 7 route before its tick-1,590 Mole action and after its tick-1,666
Jumper action. With 120-second budgets, they expanded 1,492,739 and 1,380,463
candidates. Neither found a route. These bounded searches do not prove that
Shadow 7 is unsolvable.

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
