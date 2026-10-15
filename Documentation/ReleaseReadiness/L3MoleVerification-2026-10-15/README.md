# L3 Mole behaviour and route repair

The macOS 2.0 L3 campaign gate remains open. This record tracks original-engine
Mole checks and the repair of routes invalidated by the 15 October patrol change.

## Baseline

The strict full gate was rerun against a current source-built NxlvKit library.
It fails at Shadow 7 and at carried fixture `107-1.json`. Its negative replay
checks pass. See `baseline-full-gate.log`.

The exhaustive diagnostic audit double-replays every retained fixture without
stopping at the first failure. Of 416 fixtures, 394 pass twice and 22 fail:

- Standalone: Shadow 7, Egyptian 6, Egyptian 13 and Egyptian 29.
- Carried: three Shadow 7, five Shadow 13, four Egyptian 6, four Egyptian 13,
  and two Egyptian 29 fixtures.

The earlier fail-fast result did not expose Egyptian 29. Five carried Shadow 13
input schedules still win when rebased and double-replayed under the patrol
runtime. The other 17 failing schedules do not win. These failures do not prove
that any level is impossible.

See `baseline-fixture-audit.json`, `baseline-double-replay-audit.log`,
`baseline-fixture-audit.log` and `baseline-provenance.json`. The diagnostic audit
checks retained fixture identity and deterministic winning outcomes. The strict
campaign gate additionally checks full coverage and linked survivor accounting.

Run the exhaustive audit with:

```sh
L3_TEST_LIBRARY_DIR=/absolute/path/to/current/library \
  zsh Scripts/audit-l3-fixtures.sh
```

## Original-engine observations in progress

A fresh disposable DOS game copy ran in DOSBox Staging 0.82.2 with SDL dummy
video, SDL dummy audio, software rendering and `nosound=true`. No desktop window
opened. The original executable and original supplied resources remain unchanged.
The ignored capture directory is `.build/l3-mole-verification`.

Shadow 7 was loaded in Shadow's opening slot. Only the two placement references
in the copied level header changed to 101. The baseline placement files match
the supplied Shadow 7 files. The corridor floor stayed pixel-identical during
passive patrol. A controlled contact case adds two source steel objects (ID 354)
at `(200,96)` and `(200,104)` to the copied temporary placements. The original
Mole then excavates a diagonal tunnel. A static brick-object case did not show
excavation. A lemming-built brick trigger is still unverified.

Read-only actor samples now identify the original logic counter, actor position
and animation state. `original-steel-actor-trace.json` records ticks 7 through
244; setup and actor cleanup samples are excluded. The original actor is 16
pixels wide and 18 pixels high. Its source left/top position maps to native
centre/feet by adding `(8,18)`.

In this controlled case, patrol settles the feet from 110 to 112. Steel contact
starts the reaction at tick 26; the first diagonal movement occurs at tick 36.
Burrowing then moves two horizontal pixels and one vertical pixel on every
logic tick. Ricochets reflect the obstructed axis. The Mole continues through
its previously excavated tunnel. Stopping as soon as its body reaches empty
cells does not match this trace.

An isolated native prototype matches every fourth-tick position from tick 36
through 244, including the ricochets and tunnel crossing. See
`prototype-steel-comparison.json`. This proves the sampled trajectory in this
case. It does not establish the full excavation mask, a player-built brick
trigger, long travel outside terrain, water interactions or destruction.

`mole-prototype.patch` contains the isolated proposal against the baseline
runtime hash recorded in `baseline-provenance.json`. It has not been applied
to production. Its full fixture audit has 393 passes and 23 failures; rebasing
old inputs yields six winning refresh candidates, including standalone Shadow
13. That refresh saves four and loses six, so it is not a lossless campaign
repair. No candidate has been promoted.

No Mole runtime change, route replacement or campaign closure is claimed yet.

## Coordination across machines

The owner confirmed on 15 October that another Codex agent is working on
`main` on a separate machine. This chat cannot directly message that session.
The proposed split is:

- The other agent owns production Mole runtime changes and L3 route fixtures.
- This chat owns original-engine verification, exhaustive fixture diagnostics
  and the final gate rerun after the runtime and route repairs are available.

This chat will not edit `Sources/NxlvKit/Lemmings3Runtime.swift` or either L3
fixture directory while that work is in progress. The split is a handoff
proposal, not a claimed acknowledgement from the other agent. The other agent
should pull this record before further route searches: the pending source
behaviour correction can change replay timing again.

Baseline failures include Egyptian 29, not just Shadow 7 and Egyptian 6/13.
Use `baseline-provenance.json` for all 22 exact fixture names. Refresh identity
only when the accepted input schedule still wins twice. Regenerate the linked
campaign evidence only after new routes pass; the prior 90-level proof applies
to its recorded runtime, not automatically to a changed runtime.

After a fresh complete NxlvKit build, run `Scripts/audit-l3-fixtures.sh`,
`Scripts/verify-l3-completion.sh --require-all` and the full campaign gate
specified by `Documentation/CampaignCompletion/README.md`. Retain the source
revision and runtime hash with each result. All mechanical tests remain
headless and muted.
