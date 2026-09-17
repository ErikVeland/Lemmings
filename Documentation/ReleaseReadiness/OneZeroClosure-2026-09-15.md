# Classic 1.0 closure work, 15 September 2026

Classic 1.0 remains the selected macOS milestone. L2 and L3 remain previews.
The shipped beta 32 archives are unchanged. This work is not a completed 1.0 release.

## Owner and tester evidence

Erik Veland confirms regular personal and external tester play, working live
Game Center integration, and approval to distribute the original assets.
Testers have reported no issues in Classic or early L2 levels and enjoy the game.
The publishing approval gate is closed on that confirmation.

This feedback does not identify particular Intel or minimum-macOS machines,
physical controller models, a complete VoiceOver listening journey, or a
separate novice study. Those specific checks are not claimed here.

## Changes

- Fix exit entry on slopes. The native Frost 2 trace reached the exit at
  (1032, 144), then rose above its trigger before reaching the horizontal centre.
  The engine now accepts a walker before its next step would leave the trigger.
  Flat-ground entries retain their central position. Taxing 4, Crazy 18, Flurry 1
  and Frost 11 retain their rescue counts and finish earlier; their stored
  outcomes were refreshed from the same inputs. The new mirrored slope
  regression fails against the previous engine and passes with this change.
- Restore system-font bomb countdowns in Classic, as requested. The white,
  bold monospaced digits were visually checked at four zoom levels.
- Export verified tiered hints for the other official Classic campaigns.
  Every included route runs through the native simulation before export.
  The original 120 proof-backed hint decks retain their checks.
- Preserve completed Classic player-input routes, including Classic fan levels.
  The background writer validates exact outcomes, deduplicates by content and
  publishes complete files atomically. Normal app termination drains its queue.
  The existing Show Recorded Routes command opens Classic and L2 route folders.
- Import recorded Classic inputs through the strict completion tool. Preserve
  live after-tick timing in recorded, planned and adjusted inputs. Refused skill
  assignments, unused inputs and changed outcomes still fail verification.
- Prevent stale Game Center account callbacks and leaderboard loads from
  exposing another account's personal rank or suppressing its score submission.
- Test checkpoint recovery after ten abrupt writer-process terminations.
- Give active replay encoding user-initiated priority. Twenty repeated scenarios
  retain every captured frame after utility-priority runs stalled. The bounded
  500 ms failure behaviour remains in place. See
  [performance evidence](PerformanceMeasurementClosure.md).
- Accept the version 2 L2 event routes produced by Claude's recorder and solver
  in the rescue-certificate audit. Use the shared event cursor and retain strict
  rejection of refused and unused inputs. The old audit decoder crashed on
  these routes because it required the version 1 `inputs` field.

The route recorder covers Classic DOS simulations. Native NeoLemmix runs are
not captured by this recorder. L2 retains its existing recorder. L3 does not yet
preserve player input routes automatically. No new Hot Seat control or handover
behaviour was introduced.

## New official routes

| Classic level | Saved | Required | Ticks |
| --- | ---: | ---: | ---: |
| Flurry 8 | 77 | 70 | 6120 |
| Flurry 12 | 80 | 77 | 1722 |
| Flurry 13 | 80 | 80 | 1977 |
| Blizzard 3 | 80 | 80 | 1449 |
| Blizzard 4 | 80 | 80 | 5734 |
| Blizzard 8 | 80 | 80 | 1704 |
| Blizzard 10 | 80 | 80 | 3806 |
| Blizzard 11 | 80 | 80 | 2651 |
| Blizzard 12 | 78 | 70 | 5226 |
| Blizzard 14 | 80 | 80 | 4076 |
| Holiday 1994 Frost 2 | 50 | 49 | 1727 |
| Holiday 1994 Frost 8 | 80 | 75 | 905 |

Each committed fixture wins and reproduces its full outcome in a fresh run.
Coordinates and timing were found against the native engine. Frost 2 exposed
the slope exit bug described above; its corrected route uses only floaters and
rescues all 50 lemmings. Several initial strategies came from [Tom Hayes's Holiday 1993 guide](https://gamefaqs.gamespot.com/pc/926349-holiday-lemmings-1993/faqs/37649).
Flurry 8 extends the retained native coordinate plan. The guide text is not copied into the project. The native coordinate plans are
in `Tools/ClassicCompletion/Plans/holiday1993-*.json`.
Flurry 13 uses release rate 99 at tick 1000. Blizzard 3 uses rate 99 at tick 110.
Flurry 12 and Blizzard 8 use rate 99 at tick 600. Blizzard 11 uses rate 99 at tick
1900. Frost 8 uses rate 99 at tick 1. The other plans retain their default rates. Holiday 1993 now has preserved
wins for all 32 levels. Official Classic coverage is 250/292, with 28 Oh No! and
14 Holiday 1994 routes still missing.

## Validation record

Evidence is in `.build/one-zero-current`:

- `audit/report.md`: baseline engine, save, controller, content and known-route
  checks. The all-level completion checks remain red. Source changes during
  this run prevent it from certifying the final combined source.
- `classic-gate-negative.log`: invalid route rejection, exact live input timing,
  recorded import, and rejection of unused late inputs.
- `hint-export-tests.log`: reproducible export, changed-outcome rejection without
  replacing the catalogue, and a recorded after-tick route.
- `hints-current.log`: rendered family hint journeys, input targets, catalogue
  layout checks and route recording round-trip, deduplication and invalid inputs.
- `trolley.log`: Game Center account-change cases and existing Trolley checks.
- `trolley-event-tests.log`: exact version 2 L2 route retention and rejection
  of refused assignments and unused late events.
- `trolley-classic-proof-final.log`: all 292 official configurations, preserving
  existing rescue targets and checking the new after-tick witnesses.
- `exit-app.log`: complete app integration against the corrected engine, built
  for macOS 13. Live hint rendering, input, checkpoints, movies and Hot Seat
  flows pass. The Holiday hint page was also visually reviewed.
- `exit-regressions.log` and `exit-before.log`: mirrored slope regression passes
  with the fix and fails against the previous engine.
- `exit-refresh-tests.log`: explicit outcome refresh and preserved rescue targets.
- `exit-hint-tests.log`: fresh hint export, invalid outcomes and live input timing.
- `recovery-process.log`: existing checkpoint tests and ten isolated SIGKILL trials.

The full corpus run after the exit fix contains 6,372 levels, 647 verified wins
and no load/start failures. It includes 250 official, 394 fan and three conversion
wins. There are 5,725 missing wins, including ten rejected fan replay candidates.
See `exit-corpus.log`. The strict rescue audit also reproduces all 195 published
certificates and 17 rescue records against the corrected engine.
`readiness-final.log` records ten passing release-tool tests. Missing wins are missing evidence,
not proof of a broken level. The bounded search tested all 54 initially missing
states and found no additional winning route. Search timeouts do not establish
that a level is impossible.

## Holiday 1994 and Havoc 10 routes, 16 September

Claude completed the Holiday 1994 routes that Codex had started. The four
uncommitted Codex fixtures (Frost 5, Frost 15, Frost 16 and Hail 12) replay
and are now in the manifest. Claude added routes for the other ten Holiday 1994
levels and for Oh No! Havoc 10.

| Level | Saved | Required | Ticks |
| --- | ---: | ---: | ---: |
| Holiday 1994 Frost 6 | 69 | 69 | 2980 |
| Holiday 1994 Frost 7 | 32 | 25 | 6120 |
| Holiday 1994 Frost 9 | 40 | 40 | 1302 |
| Holiday 1994 Frost 12 | 80 | 78 | 2115 |
| Holiday 1994 Frost 13 | 80 | 80 | 1457 |
| Holiday 1994 Hail 1 | 75 | 75 | 2148 |
| Holiday 1994 Hail 5 | 71 | 68 | 3060 |
| Holiday 1994 Hail 11 | 70 | 70 | 3315 |
| Holiday 1994 Hail 13 | 50 | 50 | 2761 |
| Holiday 1994 Hail 16 | 10 | 10 | 1296 |
| Oh No! Havoc 10 | 5 | 3 | 456 |

Holiday 1994 now has preserved wins for all 32 levels. Official Classic coverage
is 265/292. The 27 remaining gaps are all Oh No! levels.

The routes came from the new level lab in `Tools/ClassicCompletion/Lab`. Strategy
notes on the Lemmings Wiki suggested the approach for several levels. No wiki
text is copied into the project. Coordinates and timing come from the native
engine. Some routes differ from the wiki because this engine turns lemmings at
different places. Each route was imported through the strict `recorded` mode.

The campaign gate, the rescue audit and the hint export pass with these routes.
There are now 263 distinct hint decks and 266 bundled solution replays.

## Oh No! routes, 17 September

Claude added routes for 15 more Oh No! levels with the level lab.

| Level | Saved | Required | Ticks |
| --- | ---: | ---: | ---: |
| Crazy 3 | 48 | 48 | 1106 |
| Crazy 6 | 20 | 20 | 2784 |
| Wild 5 | 75 | 68 | 4080 |
| Wild 8 | 10 | 10 | 782 |
| Wild 16 | 1 | 1 | 1561 |
| Wild 18 | 71 | 60 | 1913 |
| Wicked 1 | 55 | 48 | 1164 |
| Wicked 2 | 1 | 1 | 3560 |
| Wicked 5 | 20 | 20 | 1926 |
| Wicked 6 | 40 | 30 | 8160 |
| Wicked 7 | 73 | 72 | 2040 |
| Wicked 12 | 78 | 78 | 4080 |
| Wicked 16 | 5 | 5 | 614 |
| Wicked 19 | 46 | 41 | 1539 |
| Havoc 9 | 50 | 50 | 2369 |

Official Classic coverage is now 280/292. The 12 remaining gaps are Oh No! levels.
The lab now supports steps that do not wait for earlier steps, and a random
search over step templates found the Wicked 6 and Wicked 7 routes. Lab plans
for seven of these routes are in `Tools/ClassicCompletion/Plans/lab`. The plans
for the other eight were lost with a cleared scratch folder. Their fixtures
remain the evidence, and the strict gate replays each fixture.

The campaign gate, the rescue audit and the hint export pass. There are 278
distinct hint decks and 281 bundled solution replays.

## Remaining release boundaries

The gate register still requires every bundled Classic, fan and conversion
level to have winning evidence. The owner has been asked whether community
content should retain that 1.0 requirement. It remains unchanged pending an answer.
Final package signing and notarisation must use the final source and assets.
Earlier beta packages do not certify later source changes.
