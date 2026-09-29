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
Set `FAN_ONLY_PACK=fan:lldb-N` for a targeted verification pass.

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
