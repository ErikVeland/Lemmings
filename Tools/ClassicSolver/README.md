# Fan-level search

`ClassicSolver` accepts `fan:PACK.zip` with a one-based level number and
`--resources RESOURCES`. A win is written as a native replay. Use `--hash-named`
when the output argument is a directory; the replay filename then matches the
initial simulation hash.
The number is the sequential entry in the whole archive. For packs with
multiple source files, it is not the zero-based `#section` in a level identity.
Run `--describe` and check the title before a targeted search.

`solve_fan_batch.py` reads an evidence audit, searches low-confidence playable
fan levels, and records every attempt in `attempts.jsonl`. It skips attempts
already made with at least the requested time and width. The output directory
can be passed as `FAN_SOLVER_REPLAYS` to `ExpandFanEvidence`. That tool replays
each candidate in the native simulation before it assigns a score.
The batch uses the Golems clock for bundled fan levels. Use `--clock dos` only
for a comparison run; the attempt ledger keeps the clock setting.
Set `FAN_ONLY_PACK=fan:lldb-N` for a targeted verification pass.

The solver uses the fan library's exact archive and level mechanics by default.
For a geometry probe of an `.ini` source pack, pass `--canvas-width N` and
`--canvas-height N` to the direct solver. The default canvas remains 1600×160.
`--source-canvas` instead reads explicit dimensions from a text `.ini` level
and uses the related SuperLemmini source defaults of 3200×320 when absent.
It rejects binary Classic records. An explicit width or height overrides that
axis of `--source-canvas`.
Use `--source-terrain-coordinates` with the larger canvas when the text source
places terrain below the DOS encoding limit. Add `--source-object-coordinates`
to retain exact text object positions instead of DOS object alignment. The
default still decodes both through the DOS record. These flags expose source
geometry, but do not provide
Lemmini physics. Treat any route found with them as research
until the app can load the same source dimensions and a strict replay wins.
Bundled fan levels use the Golems clock by default, as they do in the app.
Use `--dos-clock` only for a focused clock comparison.
Use `--golems-mechanics` in a targeted `ClassicSolver` run to test Golems hatch,
fall and miner rules on a level that the library has not selected for those
rules. Replays found with this override require strict verification and a
separate score under the same profile. See
`Artifacts/DifficultyEvaluation/classic-golems-mechanics-alternatives.json`.

The beam search is bounded. An `UNSOLVED` result means that it found no winning
route within the chosen search limits. It does not prove that a level is
impossible. Do not count an attempt as a scored level until
`ExpandFanEvidence` produces a winning profile and replay.
Build the solver and its linked `NxlvKit` library with Swift `-O` for timed
searches. An unoptimised native library can consume the deadline before a
one-skill sweep reaches the rest of the waiting timeline. Record both binary
digests with a bounded attempt so its coverage can be reproduced.
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
Use `--rescue-quota-distance` when a level needs only some of its lemmings.
The distance score then uses the nearest number still needed to meet the
rescue target. This keeps a promising worker from being penalised for other
lemmings far from the exit. It changes search order only and may be combined
with `--prefer-progress`; record both options with each attempt.
Use `--balanced-ranking` for a targeted search that reserves half the beam for
each ranking. This can retain a route that sacrifices a lemming to open terrain
while preserving routes that keep more lemmings alive. It cannot be combined
with `--prefer-progress`. Record the mode and beam width with each attempt.
Use `--focus-workers N` to offer new skill assignments only to the first N
released lemmings. Later lemmings still move and count towards the rescue goal.
The distance ranking also follows those workers, so a bridge-building search
can retain a lead route when the crowd is far from the exit. This option works
with the beam search, including `--rollout-single`. It excludes routes that
need a later worker, so a failed focused search does not establish that a
level is impossible.

Use `--rollout-single` for a focused one-skill search. After the first skill
input, it runs the candidate without further inputs to completion before beam
pruning can discard it. The batch ledger records this mode separately. Start
with a moderate fallback interval and inspect the reported waiting-route tick
and rollout count. `--fallback 1` checks more input frames, but can use the
whole time budget near the hatch. Use it for a known narrow timing window or
with a longer bound. This pass does not cover routes that need a second skill.
An unsuccessful run is only a bounded search result.
Use `--sweep-pair FIRST,SECOND` for a focused two-skill timing check. Set
`--first-from`, `--first-through`, `--second-gap-min` and `--second-gap-max`
to the measured window. It tries each valid first assignment and then each
valid second assignment in that window, completing the remaining route with
no more input. The mode needs a fixed release rate and cannot use `--prefix`,
`--sweep-single` or `--rollout-single`. Record the waiting-route tick and both
assignment counts. A win still needs exact-level strict verification.
Use `--broadcast-skill SKILL --broadcast-from N --broadcast-through N` for a
level stocked with one copy of a skill per lemming. It tries each hatch-to-skill
delay in the stated range and assigns that skill to each active lemming when
available. The mode uses a fixed release rate and cannot use a prefix or another
sweep mode. It found exact-level wins where a one-skill search could not assign
the stocked skill to the whole crowd. Record the completed delay count; a failed
broadcast sweep covers only this policy.
The solver keeps the strongest completed continuation as a partial replay for
the next focused search. A partial replay is not a winning or scored level.
The unsolved report includes its terminal tick and released, lost and active
counts. Use `--diagnose-active` to print the active lemmings' final positions
and actions when a near-win needs a timing or route diagnosis.
Before a beam search without a forced prefix, it also runs the fixed-rate,
no-input route. This preserves a strong passive result even if the search
deadline expires before its waiting branch reaches the end.
An initial `--rate` command is setup input and does not count as the skill.
The same applies to a forced `--prefix` command that has already run.
The search keeps a waiting branch after forced prefix commands, so a second
skill can still be tried at later ticks.
An initial `--prefix` release-rate command at tick 0 is applied before the
first simulation tick, matching `--rate` at the same tick.

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
