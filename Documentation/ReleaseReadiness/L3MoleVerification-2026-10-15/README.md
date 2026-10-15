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

The first diagonal movement segment is consistent with two horizontal pixels
and one vertical pixel per native logic tick. This is a spatial and cadence
comparison, not an exact original logic tick trace. Later ricochets, the full
collision mask and the transition out of digging remain under investigation.
A private prototype is not production runtime or route evidence.

No Mole runtime change, route replacement or campaign closure is claimed yet.
