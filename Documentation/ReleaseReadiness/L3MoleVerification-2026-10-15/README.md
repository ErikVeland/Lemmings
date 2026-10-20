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

The baseline and retained audit reports are historical snapshots. The latest
current-main audit is in
[current-head-fixture-audit-03ae9286.json](current-head-fixture-audit-03ae9286.json).
The provenance file records the earlier audit runs and the latest current-head
run.

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

### 15 October route searches

The 15 October audit reports 399 of 416 fixtures passing. I rebuilt the L3
solver against that audited runtime library and searched from
retained route prefixes for levels 206, 213 and 229. The searches used 120
seconds and a beam width of 1,024. None found a winning route. Level 206 was
searched from ticks 424 and 630. Level 213 was searched from tick 750. Level
229 was searched from tick 1,560, before the refused input at tick 1,561.
The results and hashes are in
[`current-route-searches-2026-10-15.json`](current-route-searches-2026-10-15.json).

These searches did not change any fixture. They do not show that these levels
are unsolvable. The four standalone route failures and thirteen carried route
failures remain open.

### 16 October 2.0.3 current-main check

After `main` advanced to `9862374431ff67e67e084eb1f8416eb088b09ea3`, I reran
`python3 Scripts/verify-l3-mole-trace.py`. It again checks 53 recorded
isolated-prototype positions, two repeated traces with 673 samples, and all four
tunnel-edge checks. The L3
runtime, route, replay, trace-verifier and fixture-audit sources did not change
after the `1111ece8` full fixture audit. That audit remains the latest full
result: 399/416 fixtures double-replay and 17 route schedules fail. The trace
check is not a replacement for that full audit. Build 86 also retains the
shared engine libraries, but its complete app audit was not rerun. See the
[current-source recheck](current-source-parity-recheck-2026-10-16.json) and
[2.0.3 release record](../2.0.3-build86/README.md).

The build 83 extraction now contains the exact original L3 executable used by
the retained traces. The unmodified level and placement files do not match the
trace-specific fixture hashes. Both edited fixture sets have now been rebuilt
from the bundled Shadow 107 files and match every retained hash. A new headless
run did not reach the controlled Shadow 7 state. No gameplay capture or valid
actor trace was accepted. The source menu sequence and capture process remain open. The
excavation mask, player-built-brick trigger, complete Mole rules and all 17
route repairs remain open.

These solver probes predate the 16 October current-main audit below. They have
not been repeated against the current runtime source.

The 15 October audit ran when `main` was at `eb6d58d7`. Its diagnostic audit
used a prebuilt verifier and runtime library from `41b7b0f5`. The selected
Swift 6.3.3 compiler did not match that run's SDK, so that checkout could not
rebuild those tools. The current-main rerun below uses a matching Xcode 26.6
toolchain and fresh binaries.

### 16 October build 83 payload audit

I rebuilt the diagnostic audit from current `main` revision `fc52cac4` and ran
it against the staged build 83 L3 resources. All 561 files in the retained
bundle manifest match by path, size and SHA-256. The full extraction contains
15 files outside that manifest. The fresh audit report is identical to the
retained report: 399 of 416 fixtures replay twice, and 17 input schedules do
not win. The four standalone gaps are Shadow 7 and Egyptian 6, 13 and 29. The
other 13 gaps are carried schedules across Shadow 7 and Egyptian 6, 13 and 29.
The current-main revision `4fe7328a` has no changes to the runtime, replay,
audit or solver sources used for this run.

The strict route gate still stops at Shadow 7. The strict campaign gate still
stops at carried fixture `107-1.json`. The current L3 source hash is
`54dde1651c736c03e1a638838fd16cc10b488b39c30224801ab0cc49283cefb1`. The
current library hash is
`2904de481368af1ed13512e9f8271d9afd593447a59840e13ea32e4059f20607`. The
[audit provenance](current-fixture-audit-provenance.json) records the build,
resource manifest and verifier hashes. This confirms the route count. It does
not close the 17 routes or prove original-engine fidelity.

I also reran all four failing standalone routes with the current-source solver.
Each search used a 120-second budget, a 1,024-candidate beam, eight-pixel
tool-site sampling and paired actors. Egyptian 29 resumed from its retained
input through tick 1,560, then refreshed that prefix under the current runtime.
No search found a route, and no fixture changed. These bounds do not show that
any level is impossible. See
[`current-main-searches-2026-10-16.json`](current-main-searches-2026-10-16.json).

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

The reconstructed left-facing fixture uses object ID 354 at `(112,96)` and
`(112,104)`. Its decoded `TEMP002` style assigns four `0x60` attribute cells
to the object. Each cell is 8 by 2 pixels; `0x60` carries the runtime's solid
and steel bits. This confirms the material in the controlled witness, but it
does not prove that steel is the only material that can start a Mole dig. The
resource hashes and decoded fields are in the
[current production trace record](current-head-production-mole-trace-2026-10-17.json).

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

An isolated native prototype matched every fourth-tick position from tick 36
through 244, including ricochets and tunnel crossing. See
`prototype-steel-comparison.json`. This result supported the production 8x2
cell-carve change. It does not establish the full excavation mask, a
player-built brick trigger, travel outside terrain, water interactions or
destruction.

The production Mole now uses the 8x2 cell carve. A fresh current-main trace
matches 141 of 329 source positions. Two of four tunnel-edge witnesses reject
the production carve. The strict fixture audit confirms 399 of 416 exact
double replays. Seventeen route schedules still fail. See the current-head
trace and audit records below. The Mole mask, trigger and complete behaviour
remain open.

## Coordination across machines

On 15 October, work was split between production Mole changes and source
verification. That split is historical. Current runtime and fixture changes
are in `main`. Any new runtime rule must match captured source behaviour and
pass the full fixture and campaign gates before it can close a bundled gap.

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
is still required. The exact original binary is present in the extracted build
83 payload, and both trace fixture sets have exact hash matches. The headless
replay did not reach the controlled level. The manual PDF and accepted gameplay
captures are absent from this worktree and the installed app. The retained trace summaries
do not allow pixel-level reanalysis. The menu sequence and raw capture path must
be restored before closing the Mole excavation-mask and built-brick trigger
gates.

At the time of the original coordination split, this chat made no runtime or
route fixture changes. A separate session owned those repairs. That ownership
split is historical. The current closure work must implement source-backed
Mole behaviour, refresh affected routes and pass the full campaign gate against
a fresh source build.

## Current-main trace recheck

After this worktree advanced to `main` revision `fc2c59e6`, I reran
`python3 Scripts/verify-l3-mole-trace.py`. It checked the 53 recorded
isolated-prototype positions, both repeated source traces with 673 samples, and
all four tunnel-edge witnesses. The intervening main commit changed pause and
presentation code, not the L3 runtime or trace verifier. This does not compare
production trajectory to the source or close the excavation-mask and built-brick
trigger gaps. See the
[current parity recheck](current-source-parity-recheck-2026-10-15.json) for the
source and verifier hashes.

## Current-main trace recheck, 16 October

At `4fe7328a`, the whole runtime file hash changed after the previous recheck.
The change adds action-eligibility helpers and refactors assignment guards.
The Mole update and movement source region still matches the trace baseline.
The verifier checks the baseline movement region, 53 recorded isolated-prototype
positions, 673 samples across two repeated source traces, and four tunnel-edge
witnesses. The 53 positions do not come from the current production runtime.
This result does not close the
excavation-mask, trigger or complete Mole behaviour gaps. See the
[16 October parity recheck](current-source-parity-recheck-2026-10-16.json) for
the source and verifier hashes from that check.

At the 16 October source check at `9862374431ff67e67e084eb1f8416eb088b09ea3`, the Mole trace
verifier checked 53 recorded isolated-prototype positions, both source traces
with 673 samples and all four tunnel-edge witnesses. The production runtime
hash and Mole movement region match the pre-prototype baseline. The verifier
does not establish production trajectory parity. The latest full fixture audit at `1111ece8` still
records 399/416 strict double-replay passes and 17 route failures; L3 runtime,
route, replay and audit sources have not changed since that audit.

Three wider current-main searches used a 4,096 beam and 4-pixel tool-site grid.
Egyptian 13 expanded 3,889,087 candidates, Egyptian 6 expanded 5,181,833,
and Egyptian 29 expanded 3,620,601 candidates from its tick-1,560 seed. Each
search ran for 300 seconds and found no route. They did not change fixtures.
See the [search record](current-main-wide-route-searches-2026-10-16.json).
The excavation mask, built-brick trigger, 17 route schedules and complete Mole
rules remain open. The exact original executable is present in the extracted
build 83 payload, and the trace-edited fixtures have been rebuilt with exact hash matches.
The ignored `.build/l3-mole-verification` directory now contains four
framebuffer image dumps from a later failed launch. The original executable and
trace-edited fixture hashes match. The images do not show an accepted controlled
gameplay capture or actor trace, so they do not extend the source comparison.
See `current-source-parity-recheck-2026-10-16.json` for their hashes.

## 17 October current-main check

At the 17 October check, `HEAD`, `origin/main` and the fetched `main` tip matched at
`b2dd57a6991f5f9685435d3df6533f6245b794f4`. The full fixture audit was rerun at
`fe11bd5d` and records 399 of 416 exact double replays, with 17 route failures.
L3 runtime, replay, route, audit and fixture paths have no changes after
`1111ece8`. The audit report therefore remains source-continuous, but the full
audit was not rerun at `b2dd57a`. The trace verifier checks 53 prototype
positions, 673 repeated source samples and four tunnel-edge witnesses. A
separate production comparison matches 0/329 original-engine positions. Its
first mismatch is tick 2: source `(154,110)`, production `(156,110)`. A
temporary one-pixel-per-tick timing probe also matched 0/329 positions. It
reduced mean Manhattan error from 90.65 to 86.76 pixels, but it did not model
the source descent or excavation. Do not promote it. A 300-second Shadow 7
search expanded 3,732,001 candidates without a route. It did not change
fixtures. These checks do not
prove that any level is impossible or verify the excavation mask and
built-brick trigger. Source parity, all 17 route repairs and the build 86 app
audit remain open. See the [current parity recheck](current-source-parity-recheck-2026-10-16.json),
[Shadow 7 search](current-head-shadow07-search-2026-10-17.json) and
[production trace record](current-head-production-mole-trace-2026-10-17.json).




### 17 October main fast-forward to build 87 preparation

The worktree is now fast-forwarded from `b2dd57a` to `b92386eb`, which matches
`origin/main`. Neither L3 runtime nor the Mole trace verifier changed in the
three incoming commits. The 0/329 production comparison at `b2dd57a` remains
source-continuous; the 399/416 fixture audit remains at its recorded `fe11bd5d`
source. Main now contains prepared 2.0.4 build 87 release notes, but there is no
accepted build 87 package evidence. The latest accepted macOS package remains
build 86. See the [current-main reconciliation](../2.0-build83/current-main-sync-reconciliation-2026-10-17.json).

### 17 October current-main trace check after build 87 preparation

After the fast-forward to `b92386eb`, `python3 Scripts/verify-l3-mole-trace.py`
passed 53 recorded DOS/prototype positions, isolated prototype reconstruction,
the production movement source fingerprint, two repeated source traces with 673
samples, and four tunnel-edge checks. The check confirms the current production
movement is still the pre-prototype implementation. It does not establish
production-to-DOS parity. The recorded 0/329 production comparison remains at
`b2dd57a`; neither the L3 runtime nor its trace inputs changed in the incoming
commits. The 399/416 full fixture audit remains at its recorded `fe11bd5d`
source. See the [current-main reconciliation](../2.0-build83/current-main-sync-reconciliation-2026-10-17.json).


### 17 October build 83 reference payload correction

The extracted build 83 payload contains `LEM3CD/L3CD.EXE` and
`LEM3CD-2/L3CD.EXE`. Both files match the retained trace executable SHA-256
`5eef913b578fb642eef183d80404d91c4cbcb1f4c998e184962ce1f37f64f018`. The
unmodified `LEVEL101.DAT`, `PERM101.OBS` and `TEMP101.OBS` files in both
directories do not match the trace-specific fixture hashes. The raw source captures remain absent.
The prior availability record was too broad when it said the original
executable was absent. This correction does not close the excavation-mask or
built-brick trigger gates. See the [updated source parity recheck]
(current-source-parity-recheck-2026-10-16.json).


### 17 October headless source replay attempt

I launched the rebuilt `steel-left-facing` fixture with the hash-matched
executable in DOSBox Staging 0.83.0. SDL dummy video and muted audio kept the run
headless. Eight delayed Enter keypresses did not establish the controlled
Shadow 7 level state. The memory samples did not form a valid actor trace, so I
rejected them. The original retained traces still use DOSBox Staging 0.82.2.
The fixture files are reproducible, but the startup menu sequence and raw
capture process remain open. No Mole behaviour or route gate changed.


### 17 October full L3 fixture audit

I rebuilt the audit executable from current `main` and reran all 416 standalone
and carried fixtures against the build 83 L3 resources. The fresh report hash
`8efd819255e4b522993a32d0b3541048011429bb6dcd5b02e261a550f08f2351` matches
the retained report. It confirms 399 exact double replays and 17 route failures.
The failures remain four standalone routes and thirteen carried schedules. The
non-zero audit result is expected because the strict gate requires every route
to pass. The audit does not verify source parity or the full app package. See
[current fixture audit provenance](current-fixture-audit-provenance.json).


### 17 October Egyptian 13 wider search

A current-main search used the exact extracted build 83 L3 resources, an
8,192-state beam, two-pixel tool-site sampling and a 600-second budget. It
expanded 7,175,180 candidates and found no route. It wrote no candidate, and
fixture `213.json` stayed unchanged. The earlier 4,096-state, four-pixel,
300-second search expanded 3,889,087 candidates and also found no route.
Neither bounded search proves that the level is impossible. The route gate stays
open. See the [search record](current-head-egyptian13-wide-search-2026-10-17.json).


### 17 October strict L3 completion gate

The fresh `verify-l3-completion.sh --require-all` run used the extracted build
83 resources and the current-main runtime library. The 322-entry campaign
manifest, fixture refresh checks and negative checks passed. The standalone
route gate failed at Shadow 7 (`107.json`). The full campaign gate failed at
carried fixture `107-1.json`. The strict route and campaign gates remain open.
See the [current-head gate record](current-head-strict-gate-2026-10-17.json).


### 17 October production Mole trace comparison

The current-source trace audit was rerun at `b2dd57a`. It rebuilt NxlvKit and
compared the production Mole with all 329 retained positions from the
reconstructed left-facing steel case. Production matched none; its first
mismatch is at tick 2: source `(154,110)`, production `(156,110)`. The isolated
proposal matches 141 positions, including the burrow samples at ticks 36–153
and 173–187, then continues through an opening where the source falls. Its
rectangular carve also conflicts with two of the four retained tunnel-edge
witnesses. Neither result is a complete Mole implementation.

The decoded left-facing fixture places steel tags `0x60` at x=112–119 and
y=96–111. The production Mole checks steel as a protected boundary and will not
clear it. This does not yet reproduce the source contact transition. Its patrol
also uses a different vertical path and a provisional terrain mask. The source
first shows down-right movement at tick 36. The four edge witnesses do not
define the full excavation mask.

Repeat the production comparison with
`L3_MOLE_TRACE_ROOT=/absolute/path/to/reconstructed/steel-left-facing zsh
Scripts/audit-l3-mole-production-trace.sh`. The expected current result is a
non-zero exit because production does not match the source. See the
[production trace record](current-head-production-mole-trace-2026-10-17.json).
No route or bundled closure count changed.

### 17 October current-source production Mole rerun

At `dd0f1578`, `Scripts/audit-l3-mole-production-trace.sh` rebuilt NxlvKit
and compared the production Mole with all 329 retained positions. It matched
0 positions; the first mismatch is tick 2 (source `(154,110)`, production
`(156,110)`). The exact source, library and trace hashes are in the
[current production trace record](current-head-production-mole-trace-2026-10-17.json).
This confirms a current-source fidelity gap. The partial prototype remains
unpromoted because its excavation mask and fall transitions do not match the
source evidence.


### 17 October Egyptian 29 seeded searches

Two current-source searches resumed the accepted Egyptian 29 input schedule. One
refreshed the seed through tick 1,560; the second used a shorter seed through
tick 1,200. Both used an 8,192-state beam, two-pixel tool-site sampling, paired
actors and a 600-second budget. They expanded 7,975,174 and 6,634,249
candidates, respectively, and neither found a route. No candidate was written
and fixture `229.json` is unchanged. These bounded searches do not show that the
level is impossible. See the [search record]
(current-head-egyptian29-seeded-searches-2026-10-17.json).


### 17 October current-main recheck at 03ae9286

The worktree is at `03ae9286c5bb0f3dbd4c478bfe017047f6e728d6`, which matches
`origin/main`. Fresh production traces match 141 of 329 left-facing positions
and 140 of 344 air-gap positions. The air-gap trace diverges after tick 167.
The full fixture audit passes 399 of 416
double replays, with zero stale-identity wins and 17 route failures. The strict
gate passes the 322-entry manifest and negative checks, then fails at standalone
route `107.json` and carried fixture `107-1.json`.

This closes the six stale expected-state hashes for level 113. The initial
state hashes, level hashes and input schedules already matched current source.
The refresh tool double-replayed all six candidates before it updated the
fixtures. The 17 route failures, Mole parity, built-brick trigger and full L3
completion remain open. See the [current fixture audit](current-head-fixture-audit-03ae9286.json),
[strict gate](current-head-strict-gate-03ae9286.json) and
[production Mole trace](current-head-production-mole-trace-2026-10-17.json).


### 17 October current-runtime Shadow 7 searches

The solver was rebuilt from the current source at `03ae9286`. Three 300-second searches used an 8,192-state beam, two-pixel tool-site sampling, paired actors and fewer-inputs-first ranking. The searches were unseeded, seeded through tick 1,666, and seeded through tick 1,590. They expanded 2,583,028, 1,338,517 and 2,195,448 candidates. None found a route. No candidate was written, and fixture `107.json` did not change. These bounded results do not prove that Shadow 7 is impossible. See the [current-runtime search record](current-head-shadow07-currentmole-search-2026-10-17.json).


### 17 October current-runtime air-gap trace

I rebuilt the retained air-gap fixture from the left-facing fixture. Its level,
permanent-object and temporary-object hashes match the retained source hashes.
The current production runtime matches 140 of 344 positions and follows the
source through tick 167. The source then pauses, drops vertically from ticks
173 to 182, and resumes patrol at floor position `(112,192)`. Production keeps
moving diagonally and reaches `(150,167)` at tick 182. This confirms a missing
fall transition. The trigger and animation timing remain open. See the
[air-gap trace record](current-head-production-air-gap-trace-2026-10-17.json).

A prototype trigger based on empty current and next footprints was rejected. It
started a fall at tick 70, but the DOS Mole continued its down-left burrow
through tick 167. The prototype matched 44 of 344 source positions, down from
140. Empty footprints alone do not identify the source transition. The
production runtime remains unchanged while the trigger stays open.

### 17 October current-main runtime check

The L3 runtime test runner fails at the Shadow 7 assertion for the right patrol
position. A separate build of the committed runtime and test at `03ae9286`
fails at the same assertion against `Sources/Ports/LEM3CD`. This is a baseline
failure. The expected position and direction need a fresh source comparison.


### 17 October local patrol candidate

The worktree is based on `03ae9286`, which matches the fetched `origin/main`. A
local runtime candidate uses an 8x16 horizontal patrol footprint and removes
the two-pixel ground snap. The full L3 runtime suite passes, including the
Shadow 7 patrol assertion. Six level-113 fixture outcome hashes were refreshed
after double replay; the 322-entry campaign manifest now passes.

The candidate does not close bundled L3 routes. The full fixture audit reports
399/416 exact double replays, zero stale-identity wins and 17 failed route
schedules. The strict gate passes its manifest and negative checks, then fails
at standalone Shadow 107 (`107.json`) and carried fixture `107-1.json`. These
results apply to this uncommitted candidate. Main's original runtime baseline
remains separately recorded. See the [candidate record]
(current-worktree-candidate-03ae9286-2026-10-17.json).


### 17 October current-main recheck at 8d65e927

A fresh fetch confirms the worktree matches `origin/main` at `8d65e927`. The
L3 runtime suite passes. The full 416-fixture audit verifies 399 exact double
replays, zero stale-identity wins and 17 route failures. The strict gate passes
the 322-entry manifest and negative checks, then fails at standalone Shadow 7
(`107.json`) and carried fixture `107-1.json`.

The patrol change and six level-113 outcome hashes are now part of main. Direct
source comparisons show 0/329 left-facing Mole positions and 2/344 air-gap
positions. Parent `03ae9286` matched 140/344 positions on the air-gap trace. The
new runtime test passes, but this does not establish full Mole fidelity. The
level-107 patrol rule and level-101 steel-contact transition still need a rule
that matches both source scenes. See the [current fixture audit]
(current-head-fixture-audit-8d65e927.json), [strict gate]
(current-head-strict-gate-8d65e927.json) and [air-gap trace]
(current-head-production-air-gap-trace-2026-10-17.json).

### 17 October current-main recheck at 183bc8a8

A fresh fetch confirms `HEAD`, `origin/main` and `FETCH_HEAD` match at
`183bc8a8`. The L3 runtime suite passes with bundled resources. The fresh audit
checks 416 fixtures. It verifies 399 exact double replays, zero stale-identity
wins and 17 route failures. The strict gate still fails at `107.json` and
`107-1.json`.

The explicit-steel Mole contact change is in main at `5b2306ed`. Its source
matches 139/329 left-facing positions and 140/344 air-gap positions. It does
not match the source fall after tick 167. Two of four tunnel-edge checks also
remain open. These results do not close the 17 failing schedules or prove full
L3 engine fidelity. See the [current-main record]
(current-main-steel-contact-183bc8a8-2026-10-17.json), [fixture audit]
(current-head-fixture-audit-183bc8a8.json), [left-facing trace]
(current-main-steel-contact-left-facing-trace-2026-10-17.json) and [air-gap
trace](current-main-steel-contact-air-gap-trace-2026-10-17.json).

### 17 October current-main recheck at e613a5e9

A fresh fetch confirms `HEAD`, `origin/main` and `FETCH_HEAD` match at
`e613a5e9`. The L3 runtime suite passes with bundled resources. A fresh audit
checks 416 fixtures. It verifies 399 exact double replays, zero stale-identity
wins and 17 route failures. The strict gate fails at `107.json` and `107-1.json`.

The open-drop change matches the captured air-gap Mole position through tick
183. The first patrol step then differs: at tick 184 the source centre is
`(115, 192)` and current main is `(116, 192)`. Source and runtime positions for
ticks 182-190 are retained in the [current-main record](current-main-open-drop-e613a5e9-2026-10-17.json).
The full trace matches 179/344 air-gap positions and 139/329 left-facing
positions. Two of four tunnel-edge checks remain open. This does not close the
17 route failures or prove full L3 fidelity. See the
[current-main record](current-main-open-drop-e613a5e9-2026-10-17.json),
[fixture audit](current-head-fixture-audit-e613a5e9.json),
[strict gate](current-main-strict-gate-e613a5e9-2026-10-17.json),
[left-facing trace](current-main-open-drop-left-facing-e613a5e9-2026-10-17.json)
and [air-gap trace](current-main-open-drop-air-gap-e613a5e9-2026-10-17.json).

### 17 October rejected post-drop cadence experiment

A historical worktree experiment used a 4/3-pixel-per-tick accumulator after
the source-observed open-drop landing. The runtime test passed, and its trace
matched 191/344 air-gap positions compared with 179/344 on current main. That
aggregate count did not prove source fidelity. Direct pointwise comparison
shows the source centre positions at ticks 182-189 are 112, 114, 115, 117,
118, 119, 120 and 122. The candidate first differs at tick 185 (116 instead
of 117), then matches again at ticks 186-189 before differing at tick 190
(123 instead of 126). The candidate runtime change and its regression test
were removed. No replacement cadence is established. See the [rejected
experiment record](current-worktree-post-drop-cadence-candidate-e613a5e9-2026-10-17.json)
and its retained [source trace](original-followup-traces.json).

The historical candidate also ran two 60-second Shadow 7 searches and one
60-second Egyptian 6 search. They found no routes and did not change fixtures.
These bounded searches do not prove that the levels are impossible. They used
the rejected candidate runtime, so they are not evidence for current main.
Search details remain in the [experiment record](current-worktree-post-drop-cadence-candidate-e613a5e9-2026-10-17.json).

### 18 October current-main check at 0659e3a6

Main advanced from `e613a5e9` through four release-preparation commits. The L3
runtime source hash remains `97be04c8eeb386689581c7d22b85a46c7b30c1b0803d0e33c2d4a1143c42e750`.
The L3 runtime suite passes on `0659e3a6`. The trace verifier selects the
retained `e613a5e9` audit by its matching runtime hash and reports the first
post-drop patrol mismatch at tick 184: source `(115, 192)`, runtime
`(116, 192)`. The full 416-fixture audit remains the retained `e613a5e9` run:
399 exact double replays, zero stale-identity wins and 17 route failures. The
release-preparation commits did not change the L3 runtime source, but no build
88 app-package audit is recorded. See the [current-main reconciliation](../2.0-build83/current-main-sync-reconciliation-2026-10-17.json)
and [pointwise trace record](current-main-open-drop-e613a5e9-2026-10-17.json).

### 18 October current-main MVP replay refresh

The full current-main audit checked 416 retained routes. It found 203 routes
that still won with their existing inputs but had stale initial-state records.
The refresh updated their current identity and expected outcome. It changed no
input stream. Each refreshed route passed two replays.

The current-main audit now records 399 exact double replays and 17 routes that
still fail. Four failures are standalone routes. Thirteen are carried routes.
The fixture manifest and same-level refresh checks pass. The strict gate stops
at `107.json` and `107-1.json`. This closes stale replay identity only. It does
not prove optimal routes or original-engine parity. See the [current-main MVP
audit](current-main-mvp-fixture-audit-8c66ef3e-2026-10-18.json).

### 18 October upstream ancestry check

A fresh fetch resolves remote `main` to
`09155829a9a404c052410e175818f6da75a43b4d`. Worktree `8c66ef3e` contains that
commit and is 1,153 commits ahead, with none behind. The local `origin/main`
tracking ref still points to `8c66ef3e` and is stale for this fetch. The 416
retained replay scenarios produce 399 exact double
replays. The 203 refreshed identities keep their original input streams. The
17 failures are population-specific scenarios for four levels: Shadow 7,
Egyptian 6, Egyptian 13 and Egyptian 29. The L3 runtime source hash remains
`97be04c8eeb386689581c7d22b85a46c7b30c1b0803d0e33c2d4a1143c42e750`.

For MVP, the route target is one verified win per bundled level. No route must
be optimal, save every lemming or minimise inputs. Reuse and replay existing
winning witnesses; only work on levels with no winning witness. Keep the 17
failed scenarios visible until they are resolved or explicitly moved out of the
MVP gate. Imported content remains open-ended and is gated per engine and
version. See the [current-main MVP audit](current-main-mvp-fixture-audit-8c66ef3e-2026-10-18.json)
and the [bundled-scope reconciliation](../bundled-scope-reconciliation-2026-10-17.json).


### 18 October replay state hash correction

`L3Replay.stateHash` now records `Creature.moleDropDelay`. This timer changes
future Mole movement, so the replay identity must include it. The regression in
`Tests/Lemmings3CompletionTests/test_state_hash.swift` confirms that two otherwise
equal Mole states with different delays produce different hashes.

The refresh rebuilt 203 winning routes with current state hashes. It updated the
initial identity for 17 losing route scenarios. It changed no route inputs. The
source-built audit then passed 399 of 416 scenarios twice. The same 17 route
scenarios fail across Shadow 7 and Egyptian 6, 13 and 29. Their current
identities now match, so the audit reports route failures directly.

`Scripts/verify-l3-completion.sh 001` passed the state-hash regression, fixture
manifest, refresh checks, verifier integration and strict-gate checks. The
Mole movement and excavation-mask gaps remain open. See the [current-main audit](current-main-mvp-fixture-audit-8c66ef3e-2026-10-18.json).

### 18 October MVP discovery follow-up

The L3 discovery tool now ignores a retained route when it does not replay as
a win. It keeps a valid existing route and writes the first new route that
passes two replays. This removes the prior survivor-count comparison from the
discovery gate. The current fixed policies found no winning route for levels
107, 206, 213 or 229. They produced no candidate fixture. These bounded tries
do not show that the levels are impossible and do not search for optimal
routes. The runtime suite passed after the static-brick test label was corrected
to state what its fixture contains. The four route gaps and Mole source-rule
gaps remain open.


## 18 October current-worktree MVP audit

The current-worktree source-built runtime suite passes. The strict fixture
manifest and negative gates pass. The 416-route audit verifies 399 exact
double replays. Seventeen route scenarios still fail across Shadow 7 and
Egyptian 6, 13 and 29. The strict gate stops at standalone `107.json` and
carried `107-1.json`. This work uses one winning route as the MVP target. It
does not optimise rescue or input counts.

The runtime now starts a Mole tunnel at player-built bricks. The original manual
says bricks can direct a Mole, but this audit does not prove the trigger timing
or excavation mask against the original engine. See the [current-worktree audit](current-worktree-mvp-fixture-audit-8c66ef3e-2026-10-18.json).

An 18 October DOSBox Staging 0.83 session started the bundled `L3CD.EXE`.
Its local API exposed CPU and memory access, but no screen capture or timed
input endpoint. One BIOS Enter key advanced the display, but it did not produce
a readable level image or an actor trace. This attempt adds no original-engine
evidence and closes no Mole or route gap. The emulator was stopped.

The current-worktree solver now stops at the first verified win. It keeps a
retained route when that route still wins. Three targeted 120-second searches
found no route for Egyptian 6, Egyptian 13 or the carried Egyptian 29 case.
Three Shadow 7 searches also found no route, including a 300-second run with a
2,048-wide beam. See the [MVP search details](current-worktree-mvp-fixture-audit-8c66ef3e-2026-10-18.json).

A direct walkthrough-based Shadow 7 attempt built a vertical stack at tick 615
and jumped at tick 700. The Mole reached the embedded Spades, but two boxes
fell only 2 to 6 pixels and no Lem collected them. The route saved no Lems by
tick 2,200. The [MVP audit](current-worktree-mvp-fixture-audit-8c66ef3e-2026-10-18.json)
records this failed attempt. This points to tunnel clearance or pickup access.

### 18 October Egyptian 6 route segment

The runtime allows a supported eight-pixel step near the left boundary in
Egyptian 6's 320 by 400 layout. The actor needs a full support runway and clear
body space. A bundled-level regression follows Egyptian 6 through the vertical
brick stack and Shimmy traversal. The L3 runtime suite passes with this
regression. The rule stays local because the wider rule changed Egyptian 16 and
22 route outcomes.

The route still fails after the Mole trigger. The actor enters a trap near
x=135,y=52 and dies. Jump timing probes did not avoid it. This verifies one
route segment, not an MVP win. No original-engine trace confirms the new step
rule. The audit records the runtime and test hashes.

### 20 October current-source Mole trace refresh

I rebuilt the trace tool from the runtime at `440caebd` and compared both
retained level-101 scenes. The left-facing steel-contact trace matches 139 of
329 positions. The air-gap trace matches 179 of 344 positions and follows the
source through tick 183 before diverging. Both first differ at tick 2. The
runtime source hash is `cdf4e0f0625f36b7e1be8d7059514d6679270b270c5b2627ed8aa3c1e313cdf0`.
The results confirm the current trace counts; they do not close Mole fidelity
or change the four open L3 level identities. See the [current-source trace
record](current-main-mole-trace-2026-10-20.json).

### 20 October source-driven Mole timing correction

The retained original actor samples show the Mole settle from feet y=110 to
y=112 on tick 7. They show a steel-contact reaction on ticks 26–35 and the
first diagonal movement on tick 36. The runtime now applies the two-pixel
settle only when solid ground is below the Mole, avoids a second height change
when its feet are already on solid terrain, and uses a ten-tick contact
cooldown.

The two production comparisons improved from 139/329 to 146/329 positions for
left-facing steel contact and from 179/344 to 186/344 for the air-gap fall.
The shared tunnel samples still match at ticks 36–153 and 173–187 in the
left-facing case, and through tick 183 in the air-gap case. Both traces still
first differ at tick 2. The full Mole rule set remains open. See the
[updated source trace record](current-main-mole-trace-2026-10-20.json).

The headless L3 runtime suite passes with these changes. A fresh 416-fixture
audit found 393 exact double replays, six level-113 routes that still won
twice with refreshed state hashes, and the same 17 failing schedules. The six
retained input streams did not change. The strict completion gate still stops
at Shadow 7 (`107.json`); no level route closed.

### 20 October source-coordinate follow-up

I rechecked the retained source actor-memory samples against the decoded
positions. At tick 15, the source Mole moves from x=178 to x=182 while its
animation ID remains 27. The current runtime stays at x=178 on that tick. This
confirms that this early mismatch exists in the source actor position; a
rendered-sprite anchor alone does not explain it. The two current runtime
comparisons reproduce 146/329 exact positions for left-facing steel contact
and 186/344 for the air-gap case. Both still first differ at tick 2, while the
long shared tunnel segments remain exact. This identifies an early patrol
cadence gap, but does not establish a general source rule. I made no physics
change from this inspection.

This follow-up accepted zero routes and changed no route counts. It adds no
route-search sample to the velocity series. Source parity remains separate
from the 86/90 standalone L3 route count.

### 20 October one-pixel patrol candidate

I tested one horizontal patrol candidate against the captured left-facing
scene. It moved the Mole one pixel on every logic tick. The retained runtime
moves two pixels on two of every three ticks. The candidate matched 1 of 329
source positions, down from 146. Its first sample was `(158,110)` at tick 2;
the source sample was `(154,110)`. I rejected the candidate and restored the
runtime. It does not establish the original patrol rule or change route
coverage.

I also scored constant coordinate offsets from -8 to +8 pixels horizontally
and -4 to +4 vertically against both source traces. The unshifted runtime was
best in each case: 146/329 matches for left-facing steel contact and 186/344
for the air-gap fall. A single spawn-origin correction cannot explain the
remaining mismatch. The open gap is in movement or state timing.

### 20 October Mole animation-bank mapping check

The source capture records Mole animation values 26, 27, 53, 55–62 and 65.
The bundled `CREAT002.IND` file has 31 animation records and 174 decoded
frames. If those source values are flattened frame indices, they map to
animation/frame pairs 4/2, 4/3, 9/3, 9/5, 10/0–5 and 11/0, 11/3. The source
record does not yet establish that interpretation. Values 26–65 cannot index
the bank's 31 animation records. They may identify flattened frames or another
sprite state. On the aligned air-gap trace, values 26 and 27 occur during the
rightward patrol; value 53 occurs at the steel reaction; values 55–62 cycle
during diagonal movement. Before this change, the mobile renderer picked
animation 0 or 1 from direction and advanced its frames by creature age. It
did not consume the source animation value. I checked the full frame table.
Every mapped frame is 16×18, but every animation in this bank has those
dimensions, so size does not prove the mapping. The copied source bank and the
installed bundled bank have matching SHA-256 values for `CREAT002.IND` and
`CREAT002.CMP`.

The mobile renderer now uses the flattened-frame interpretation for the
captured Mole ages and dig directions. It maps only the recorded state ranges
and keeps the existing animation path for other states. Focused tests check
the selected animation/frame pairs and the fallback. This is a provisional
rendering change. A source-format proof or visual comparison against a source
capture must confirm the flattened-frame interpretation before this gap closes.
