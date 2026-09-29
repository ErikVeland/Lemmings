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

Use `--golems-objects` only for fan-level compatibility research. It activates
all 32 object slots, as the pinned Golems assembly does. The default retains
the DOS rule for official levels and existing replay evidence. A route found
under this option needs a matching fan runtime and fresh difficulty audit
before it can enter the ledger.
