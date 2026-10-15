# L3 Mole behaviour and route repair

The macOS 2.0 L3 campaign gate remains open. This record tracks original-engine
Mole checks and the repair of routes invalidated by the 15 October patrol change.

## Baseline

The strict full gate was rerun against a current source-built NxlvKit library.
It fails at Shadow 7 and at carried fixture `107-1.json`. Its negative replay
checks pass. See `baseline-full-gate.log`.

The baseline diagnostic audit double-replayed every retained fixture without
stopping at the first failure. Before the five Shadow 13 identity refreshes,
394 of 416 fixtures passed twice and 22 failed:

- Standalone: Shadow 7, Egyptian 6, Egyptian 13 and Egyptian 29.
- Carried: three Shadow 7, five Shadow 13, four Egyptian 6, four Egyptian 13,
  and two Egyptian 29 fixtures.

The earlier fail-fast result did not expose Egyptian 29. Five carried Shadow 13
input schedules won when rebased and double-replayed under the patrol runtime.
The other 17 schedules—four standalone and thirteen carried—did not win. These
failures do not prove that any level is impossible.

See `baseline-fixture-audit.json`, `baseline-double-replay-audit.log`,
`baseline-fixture-audit.log` and `baseline-provenance.json`. The diagnostic audit
checks retained fixture identity and deterministic winning outcomes. The strict
campaign gate additionally checks full coverage and linked survivor accounting.

The baseline report and its provenance remain as historical snapshots. The
current audit is in [current-fixture-audit.json](current-fixture-audit.json),
with source, tool and resource hashes in
[current-fixture-audit-provenance.json](current-fixture-audit-provenance.json).

## Current-main recheck

On 15 October 2026, I rebuilt `NxlvKit` from `main` revision `41b7b0f5` and
reran the gates against
`/Applications/Ultimate Lemmings.app/Contents/Resources/Ports/LEM3CD`. Five
Shadow 13 carried fixtures still won but had stale initial-state and result
hashes. I refreshed fixtures `113-1`, `113-21`, `113-22`, `113-25` and
`113-26` from their retained inputs. The derivation tool double-replayed each
candidate before I replaced its fixture. The exhaustive audit now reports 399
exact double-replays, zero stale-identity wins and 17 route failures: four
standalone and thirteen carried schedules.

The strict `--require-all` gate still fails at carried fixture `107-1.json`.
The campaign manifest check passes for 322 fixtures, and the negative gate
checks pass. The bundled L3 route gate remains open. The installed app is 1.9.1
build 76, and its L3 files match the 1.9.7 build 82 `Ports` baseline. Replay
evidence and route gaps cause the gate failure. See the [content recheck](../MacOS2Preparation-2026-10-15/classic-content-recheck.json).

### Current-main route searches

The latest current-main audit still reports 399 of 416 fixtures passing. I
rebuilt the L3 solver against the audited runtime library and searched from
retained route prefixes for levels 206, 213 and 229. The searches used 120
seconds and a beam width of 1,024. None found a winning route. Level 206 was
searched from ticks 424 and 630. Level 213 was searched from tick 750. Level
229 was searched from tick 1,560, before the refused input at tick 1,561.
The results and hashes are in
[`current-route-searches-2026-10-15.json`](current-route-searches-2026-10-15.json).

These searches did not change any fixture. They do not show that these levels
are unsolvable. The four standalone route failures and thirteen carried route
failures remain open.

The audit ran when `main` was at `eb6d58d7`. The worktree is now at
`0e3ac4a7` after a localisation-only commit. That commit did not change L3
engine or verifier sources. The diagnostic audit uses a prebuilt verifier and
runtime library from `41b7b0f5`; the L3 engine and verifier Swift sources did
not change between those revisions. The selected Swift 6.3.3 compiler does
not match the installed SDK, so this checkout cannot rebuild the tools used
for the rerun.

I also tested two seeded repairs for Shadow 7 with the current runtime library.
The first resumed from the retained route at tick 1,580 with a 1,024-wide beam
and 8-pixel tool-site sampling. It expanded 1,492,739 candidates in 120
seconds without a route. The second resumed at tick 1,666 with a 2,048-wide
beam, 4-pixel sampling and paired-actor inputs. It expanded 1,380,463
candidates in 120 seconds without a route. The retained solver executable
loaded the current `NxlvKit` library, confirmed by the dynamic-loader trace.
These bounded searches do not prove that Shadow 7 is unsolvable.

To repeat the current-source campaign check, build `NxlvKit` into the selected
library directory, then run:

```sh
L3_TEST_LIBRARY_DIR="$PWD/.build/l3-closure-current" \
L3_PORTS_ROOT="/Applications/Ultimate Lemmings.app/Contents/Resources/Ports/LEM3CD" \
  zsh Scripts/verify-l3-completion.sh --require-all
```

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
244; setup and samples without a valid actor record are excluded. The original actor is 16
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
Run `python3 Scripts/verify-l3-mole-trace.py` to check the 53 source/native
coordinate pairs, the runtime fingerprint, both repeated traces and all four
tunnel-edge counterexamples. The verifier also confirms that both source traces
use the same executable.

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
The owner assigned this split on 15 October:

- The other agent owns production Mole runtime changes and L3 route fixtures.
- This chat owns original-engine verification, exhaustive fixture diagnostics
  and the final gate rerun after the runtime and route repairs are available.

This chat will not edit `Sources/NxlvKit/Lemmings3Runtime.swift` or either L3
fixture directory while that work is in progress. The owner confirmed the split in this chat. The other session is not directly
accessible from this machine. The other agent
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

## Repeated original-engine follow-up

Two additional controlled DOS cases repeat without position differences in
samples validated in both runs. See `original-followup-traces.json`.

| Case | Samples compared | Result |
| --- | ---: | --- |
| Left-facing steel contact | 329 | Contact starts a down-right burrow. Early movement mirrors the right-facing case. |
| Open gap beneath the tunnel | 344 | Burrowing transitions to a fall, lands and returns to patrol. |

The air-gap case removes source TEMP objects 343/345 in the central region
listed in the trace record. At tick 167 the mapped position is `(120,152)`.
Ticks 168–172 contain the transition. At ticks 173–182 the mapped horizontal
position stays at 112 while the feet descend four pixels per tick from 156
to 192. Patrol resumes on the floor. Continuing through an earlier tunnel
and falling into an open gap are distinct observed cases. The exact test and
animation phase that chooses the transition still need comparison.

Position agreement does not establish excavation-mask agreement.
`original-tunnel-edge-check.json` records four unobscured counterexamples at
tick 62 in the controlled baseline steel case. The source clears `(198,112)`
and `(199,113)`, which the private rectangle proposal retains. The proposal
clears `(184,118)` and `(192,114)`, which remain terrain in the source.
The observed edge is consistent with the source 8×2 attribute grid. The exact
brush algorithm is still open. Do not apply the proposal as a complete source
fidelity correction on the strength of its matching trajectory.

The [original manual](https://db.hfsplay.fr/files/2018/10/06/c9f24f28-42dd-4046-aa9b-1d0b7622142e.pdf),
printed pages 25, 31 and 35, documents Use and Drop, directional brick/spade
selection and using placed bricks to redirect a harmless Mole. These are
source instructions. A verified gameplay capture of the built-brick trigger
is still required. The manual PDF, original binary and raw captures stay in
the ignored reference directory.

No runtime or route fixture changes were made by this chat. The full campaign
gate will be rerun against a fresh source build after the other agent's runtime
and route repairs reach `main`.

## Current-main trace recheck

After this worktree advanced to `main` revision `fc2c59e6`, I reran
`python3 Scripts/verify-l3-mole-trace.py`. It passed the 53 sampled positions,
both repeated source traces with 673 samples, and all four tunnel-edge checks.
This confirms the retained source comparison still matches the current runtime
fingerprint. The intervening main commit changed pause and presentation code,
not the L3 runtime or trace verifier. This does not close the excavation-mask
or built-brick trigger gaps. See the
[current parity recheck](current-source-parity-recheck-2026-10-15.json) for the
source and verifier hashes.
