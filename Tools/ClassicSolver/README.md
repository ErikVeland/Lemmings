# Fan-level search

`ClassicSolver` accepts `fan:PACK.zip` with a one-based level number and
`--resources RESOURCES`. A win is written as a native replay. Use `--hash-named`
when the output argument is a directory; the replay filename then matches the
initial simulation hash.

`solve_fan_batch.py` reads an evidence audit, searches low-confidence playable
fan levels, and records every attempt in `attempts.jsonl`. It skips attempts
already made with at least the requested time and width. The output directory
can be passed as `FAN_SOLVER_REPLAYS` to `ExpandFanEvidence`. That tool replays
each candidate in the native simulation before it assigns a score.
The batch uses the Golems clock for bundled fan levels. Use `--clock dos` only
for a comparison run; the attempt ledger keeps the clock setting.
Set `FAN_ONLY_PACK=fan:lldb-N` for a targeted verification pass.

Use `--golems-mechanics` in a targeted `ClassicSolver` run for the opt-in
Golems hatch, fall and miner rules. Pair it with `--golems-clock` when testing
packs 495 and 496. The batch wrapper and selected fan ledger still use the
default mechanics. Replays found with this override require strict verification
and a separate score under the same profile; see
`Artifacts/DifficultyEvaluation/classic-golems-mechanics-alternatives.json`.

The beam search is bounded. An `UNSOLVED` result means that it found no winning
route within the chosen search limits. It does not prove that a level is
impossible. Do not count an attempt as a scored level until
`ExpandFanEvidence` produces a winning profile and replay.
When an exit is separated from the lemmings by solid terrain, the distance
estimate uses geometric distance until an open route exists. This lets the
search keep Builder and digging candidates that can cross the barrier.

Use `--fallback N` and `--refire N` to test shorter decision intervals in a
batch. The batch ledger records both values so a new setting gets its own
attempt. Use the solver's `--partial-out` option for a focused search if an
unsolved route needs inspection. A `.partial.json` file is a research lead;
it is not a winning replay or a difficulty score.

Use `--adaptive-rate` to let the solver raise the release rate at up to two
decision points. It tests rates 25, 50, 75 and 99 above the current rate.
The default search still uses a fixed rate. The batch ledger records this
option separately. A candidate still needs an exact bundled-level replay and
strict verification before it receives a score.

Use `--prefer-progress` to rank routes nearer an exit before routes that keep
more spare lemmings. The default keeps the survivor-first ranking. The batch
ledger records this mode separately, so it does not skip an earlier search
with the other ranking. A route still needs exact-level verification.

Use `--rollout-single` for a focused one-skill search. After the first skill
input, it runs the candidate without further inputs to completion before beam
pruning can discard it. The batch ledger records this mode separately. Start
with a moderate fallback interval and inspect the reported waiting-route tick
and rollout count. `--fallback 1` checks more input frames, but can use the
whole time budget near the hatch. Use it for a known narrow timing window or
with a longer bound. This pass does not cover routes that need a second skill.
An unsuccessful run is only a bounded search result.

Use `--sweep-single` to try one after-tick skill assignment to every active
lemming on each tick of a fixed-rate, no-input route. It runs each assignment
without further inputs and does not prune by beam score. It cannot be combined
with `--prefix`, `--adaptive-rate` or `--rollout-single`. The unsolved report
gives the last waiting-route tick, assignments started, continuations completed
and whether the deadline expired. A completed sweep covers only this one-skill,
fixed-rate search; it does not establish that a level is impossible.

`generate_solver_partial_retimes.py` makes bounded one-command timing
candidates from these partial routes. Use `--minimum N --radius M` to search
an untested range without repeating earlier shifts. Feed the candidate folder
to `ExpandFanEvidence`, then run strict exact-level replay verification before
adding any win to the ledger.

The default fan runtime activates all 32 object slots when the DOS rule would
leave the level without a functional exit. Official levels keep the DOS rule.
Use `--include-structural` for a batch that retests previously blocked levels
after a native rule changes. Check every resulting candidate on its exact
bundled level before adding a score.
Use `--golems-objects` to test all 32 slots on other fan levels as a separate
compatibility probe. A route found under that override needs a matching fan
runtime and fresh difficulty audit before it can enter the ledger.
Set `FAN_GOLEMS_OBJECTS=1` in `ExpandFanEvidence` to analyse or strictly verify
such a route under the same 32-slot rule. Keep that evidence separate from a
default fan-runtime replay and score.
