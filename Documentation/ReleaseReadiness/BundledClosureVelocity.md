# Bundled closure velocity

This record tracks the bundled-content MVP: one verified winning route for each
bundled level, plus source-behaviour evidence for each bundled engine. It does
not measure imported-content completeness. Imported content stays open-ended and
uses explicit engine, version, format and feature gates.

## Current scope snapshot — 20 October 2026

The current `origin/main` checkout is `99f92797b6dd200933761019fbb744327c0f77ba`.
GitHub could not be refreshed because DNS resolution failed. The release status
and family counts below come from [ReleaseScope](../ReleaseScope.md); those
counts have different audit dates and are not one synchronized full-catalogue
run.

| Bundled family | Last accepted routes | Scope | Open routes | Evidence snapshot and remaining gap |
| --- | ---: | ---: | ---: | --- |
| Official Classic and Oh Yes! | 352 | 352 | 0 | 16 October route evidence; source-rule checks remain distinct from route coverage. |
| Classic fan packs | 2,403 | 6,020 | 3,617 | 16 October audit; strict route gate and source-behaviour evidence remain open. |
| Lemmings 2 | 120 | 120 | 0 | 20 October current-checkout replay; 70 carry-over variants and 12 chains pass, but original tick, continuous-actor and full-render parity remain open. |
| Lemmings 3 | 86 | 90 | 4 | 18 October [8c66ef3e audit](L3MoleVerification-2026-10-15/current-worktree-mvp-fixture-audit-8c66ef3e-2026-10-18.json); 17 retained scenarios fail across levels 107, 206, 213 and 229. Source parity, media and transitions remain open. |
| NeoLemmix CE | 158 | 794 | 636 | 17 October exact-version evidence; 75 levels still need styles and rights. |

The mixed-date total is 3,119 of 7,376 routes (42.3%), with 4,257 open. Treat
this as a scope summary only. The L2 Gold Ark is outside the MVP route target;
it is a stretch ending, not a reason to optimise routes. L3 closure needs one
winning route for each open level and one complete carried path per tribe, not
50-survivor runs.

The counts remain last accepted closure totals. The 20 October L2 gate now
confirms its 120 routes, 70 carry-over variants and 12 chains on this checkout.
The other route totals are not fresh verification against the 2.1 source.
Build 93 preserves the checked content trees, but its source commit also changes
`ClassicDOSSimulation`, `Lemmings2Runtime`, `Lemmings3Runtime` and
`NeoLemmixSimulation`. Its five delta checks and content-hash comparison do not
replay all retained witnesses. The current release scope records this boundary
in [ReleaseScope](../ReleaseScope.md).

## Measured route velocity

The latest full Classic fan audit in [ReleaseScope](../ReleaseScope.md) is dated
16 October and records 2,403 of 6,020 routes. The current-source targeted work
on 20 October added no accepted route. The observed net rate across those
snapshots is zero routes over four calendar days, or zero routes per day. This
is a sparse snapshot rate, not a forecast. There is no current-main rolling
seven-day audit series here, so no weekly rate or completion ETA is supported.

### 20 October current-source route refresh

The Lemmings 2 strict gate passed 120 standalone routes, 70 carry-over
variants and all 12 tribe chains against commit
`99f92797b6dd200933761019fbb744327c0f77ba`. This is route revalidation, not a
new route closure. The accepted route count remains 120/120. The Gold Ark stays
outside the MVP route target. See the [run record](L2CurrentSourceReplay-2026-10-20.json).

The full official Classic gate could not run because its Classic resource tree
is absent from this checkout. The current L3 gate also lacks bundled L3 campaign
resources. Their previous evidence remains dated to older engine snapshots.

### 20 October `A TOWERING PROBLEM` probe

I rebuilt `ClassicSolver` from current main with
`zsh Scripts/build-classic-solver.sh` and checked the exact bundled archive and
level hash against the retained 16 October audit. A saved four-command prefix
reaches 8/9 saved. I ran 72 targeted Builder timing and worker probes across
70 distinct combinations. Two first-Builder workers reproduce an 8/9 near-win;
no tested combination wins. An adaptive release-rate continuation expanded
92,587 states over 32 solver seconds and reached a best partial of 3/9. Neither
result closes the level.

The 72 targeted variants expanded 35,213 states. The separate bounded beam
continuation expanded 92,587 states. This work accepted zero routes. These are
solver throughput measures, not route-closure velocity. The [run record](ClassicFanTowerContinuation-2026-10-20.json)
contains the exact level identity, input prefix, result counts and hashes. A
bounded `UNSOLVED` result does not show that a level is impossible.

### 20 October `The Reflection` continuation

I replayed the retained two-command prefix for `fan:lldb-345/MARSHY01.DAT#4`
against the current-main archive and solver. The 30-second, width-1,024 search
expanded 81,327 states and reported 0/40 saved. The historical 35/40 partial
does not reproduce under this current-source profile. The level remains open;
this bounded result does not show that it has no solution. See the [run record](ClassicFanReflectionContinuation-2026-10-20.json).

Across these two exact fan levels, the focused work accepted zero routes. The
measured work comprises 72 Builder probes across 70 distinct configurations,
two bounded beam continuations and 209,127 expanded states. These counts track
search work only; the accepted-route count stays unchanged.

### Solver build support

The standalone solver build now has a local adapter for fan-progress identity
and storage. The route solver does not read or write player progress. This keeps
the search tool buildable with the current `FanLevelLibrary` dependency without
changing app persistence or engine rules. The repository build script passed.

## Measurement rules

- Count a closure only after the current bundled audit accepts a winning replay
  for the exact level identity and content hash.
- Keep route closures separate from engine-rule parity, assets, rights,
  campaigns, media, saves and release acceptance.
- Report candidate timings, expanded states and solver time separately from
  accepted route closures. Never infer a rate from commits or elapsed work
  alone.
- Use fresh family audits when a source or content change can alter witnesses.
  Do not replay the whole catalogue for routine updates.
- Keep imported levels outside the finite bundled denominator.
