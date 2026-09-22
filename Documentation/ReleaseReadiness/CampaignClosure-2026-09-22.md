# Campaign closure, 22 September 2026

Official Classic coverage is **292/292** under the corrected DOS rules.
Both Holiday campaigns and both Xmas releases have complete winning evidence.
Oh Yes! conversion coverage is **60/60**. L2 and L3 remain previews.
This is source validation, not a packaged 1.0 release.

## Recovered official routes

The pass began with nine uncommitted replacement fixtures. All nine replayed
successfully against a fresh build of the current engine. Havoc 13 and Hail 14
were then adapted from their earlier routes. No gameplay code changed.

| Release | Level | Saved | Required | Ticks |
| --- | --- | ---: | ---: | ---: |
| Oh No! | Crazy 1 | 48 | 48 | 2508 |
| Oh No! | Crazy 10 | 79 | 79 | 3006 |
| Oh No! | Wild 10 | 72 | 60 | 1800 |
| Oh No! | Havoc 13 | 76 | 75 | 3426 |
| Holiday 1993 | Flurry 1 | 10 | 10 | 1156 |
| Holiday 1993 | Flurry 9 | 80 | 75 | 3832 |
| Holiday 1993 | Flurry 16 | 48 | 45 | 4080 |
| Holiday 1993 | Blizzard 1 | 22 | 22 | 6182 |
| Holiday 1994 | Frost 1 | 50 | 50 | 3147 |
| Holiday 1994 | Hail 10 | 80 | 80 | 3700 |
| Holiday 1994 | Hail 14 | 65 | 65 | 3334 |

Havoc 13 needs adjusted blocker and builder timing after the hatch shift.
Hail 14 needs an earlier builder for the second left-hatch lemming under the
alternating hatch order. Its final basher holds the crowd until the bridge is ready.
The strict importer replays each new witness twice and requires its exact outcome.

## New conversions

| Mega Drive Sunsoft level | Saved | Required | Ticks |
| --- | ---: | ---: | ---: |
| 1, Rules to fall | 20 | 10 | 839 |
| 11, Turn around and look. | 50 | 45 | 2761 |

These routes came from native simulation traces and coordinate plans.
Sunsoft 1 digs below the hatch and gives each lemming a floater. Delaying the
first floater lets the digger open the route before the next lemming arrives.
Sunsoft 11 stops a miner with a builder, turning the crowd towards the exit.
Both preserve the full population and pass strict import.

The completion tool now accepts `conversion:PORTS_DIRECTORY`. It selects
artwork per rank and checks the complete 20/10/30-level rank inventory.
Missing port data cannot shrink the release gate. The campaign verification
script now includes conversions and tests changed outcomes, unused late inputs,
recorded import and missing-rank rejection. Positive cases cover all three ranks.

## Bundled evidence

- The campaign manifest contains 273 additional campaign fixtures, including L3.
- The solution bundle contains 350 distinct replays for 352 level identities.
- The hint catalogue contains 350 distinct decks covering all 352 official and conversion levels.
- The rescue catalogue contains 251 exact-condition certificates and 17
  best-known rescue records. Its merge checks every previously published target.

The Classic engine, sequel engines and app controls are unchanged by this pass.
The pre-existing lab timing change remains in the workspace.

## Validation

Evidence is under `.build/closure-sep22`:

- `logs/original-120.log`: all Original routes pass against the fresh engine.
- `logs/original-120-final.log` and `logs/original-report-refresh.log`: the final
  verifier passes all 120 routes. The stale Original manifest was refreshed to
  the current engine fingerprint. No fixture or rescue count changed. The release
  audit now checks this manifest as well as running its routes.
- `logs/campaign-final.log`: all known official and conversion routes pass.
- `logs/gate-negative-final.log`: invalid Original evidence, input timing,
  route promotion and unused-input rejection pass after the importer change.
- `logs/conversion-gate-final.log`: all three conversion ranks pass the import
  and rejection checks. Removing a rank fails even when checking known routes.
- `logs/regressions.log`: DOS mechanics regressions and the 120-level soak pass.
- `logs/trolley-*.log`: fresh Classic, conversion, L2 and L3 rescue audits and
  retained-target packaging checks.
- `logs/hint-export-tests.log`: repeatable hint export and rejection of changed
  winning outcomes without replacing the existing catalogue.
- `logs/audit-integrity.log` and `logs/package-scope.log`: ten release-tool checks pass.

The first corpus command hit a local filename collision between the `Corpus`
executable and the requested `corpus` directory on this case-insensitive volume.
The initial rerun uses `corpus-results`. The final follow-up uses
`corpus-official-parallel`, with eight disjoint fan-pack partitions. It recorded the then-missing conversion wins. The conversion follow-up below
closes them. Earlier setup logs are retained.

The earlier official-only corpus checked 6,372 levels with no load/render failures. It records
292 official, 10 conversion and 302 fan winning identities. Its only release
failure was the 50 then-missing conversion routes. The fan evidence count
fell because 99 shared campaign witnesses now have later-rule identities.
The fan inventory and all initial state hashes match the earlier corpus.
See [current Classic validation](ClassicValidation-current.md) for the comparison.

## Official closure follow-up

The six remaining official levels now have winning fixtures and coordinate plans:

| Oh No! level | Saved | Required | Ticks |
| --- | ---: | ---: | ---: |
| Crazy 20 | 10 | 10 | 4080 |
| Wild 9 | 40 | 40 | 2904 |
| Havoc 5 | 20 | 20 | 2160 |
| Havoc 7 | 18 | 15 | 3060 |
| Havoc 16 | 48 | 45 | 2040 |
| Havoc 20 | 50 | 50 | 6038 |

The engine rules, level data, skill supplies and rescue quotas are unchanged.
Havoc 20's first explosion moves from tick 94 to tick 92. Its deeper holding
pit turns the climber back safely, saving the final required lemming.
Crazy 20 uses a route across the upper steel platforms. Other right-hatch
lemmings extend its bridges before the group reaches each gap.

Published walkthroughs helped identify the intended miner routes and the two
halves of Havoc 7. The exact inputs were developed and verified with native
simulation traces. References: [David Newton's walkthrough](https://gamefaqs.gamespot.com/pc/564582-oh-no-more-lemmings/faqs/47112)
and [Richard Halloran's Havoc 5 walkthrough](https://www.youtube.com/watch?v=MQ_HZ4TPF8M).
No reference code, level edits or altered quotas were used.

`Scripts/verify-official-classic.sh` requires all 292 strict winning replays.
It then runs `Tools/OfficialClassicQuest` against the app's `ClassicSession`,
`RunRecoveryFile`, `ClassicGameFlow` and `UnifiedGameLibrary` implementations.
It writes and restores each running level at tick 1, halfway and one tick before
completion, then checks the exact final replay outcome. It also writes progress,
rebuilds the flow, resumes the next level, crosses all five release boundaries
and requires the final quest result. All 876 run restores and 292 progress
resumes passed. Negative tests reject missing fixtures, altered outcomes and
unused late inputs without replacing the prior report.

The gate uses an **official-only library** of six Classic releases. It validates
actual session/recovery and navigation code without driving the rendered app.
The installed library also contains conversions and sequel previews, so its
end-to-end Full Quest remains a separate claim. Physical interruption and
installed-version migration are not established by these tests.

The Classic sprite-to-pose function moved unchanged from `PlayfieldView.swift`
to `GameSession.swift` so the session can be tested without compiling the view.
The playfield drawing tests pass. No control or rendered state changed.

Preserved evidence:

- [Official quest results](OfficialClassicQuest.json): 292 level identities,
  fixture hashes, exact outcomes and all recovery ticks.
- `.build/closure-sep22/logs/official-gate-final.log`: full strict gate and
  session/progression checks, including negative tests.
- `.build/closure-sep22/logs/playfield-final.log`: drawing regression checks.
- `.build/closure-sep22/logs/release-tools-official-final.log`: release audit
  integrity and packaging gate checks.
- `.build/closure-sep22/logs/trolley-official-final.log`: fresh official rescue
  audit; published targets survive the catalogue merge.

## Remaining work

Fifty conversions still need winning evidence and progression checks. L2/L3
retain preview status. Full installed-library progression, physical controller
and VoiceOver journeys, installed-release recovery, sustained performance and
the hardware matrix remain open. The final 1.0 candidate needs its own freeze,
build, signing, notarisation and archive verification.
The [gate register](gates.json) separates the closed official content gate from
these remaining release requirements.

## Conversion closure follow-up

All **60/60 conversions** now have strictly verified winning fixtures:
20 Lemmings Versus, 10 Oh No! Versus and 30 Mega Drive Sunsoft levels.
The final four routes save 80/80 in Versus 4, 10/10 in Sunsoft 4,
45/45 in Sunsoft 13 and 80/80 in Sunsoft 29. The strict verifier replays
all 352 Classic fixtures twice, checking identities, accepted assignments,
consumed inputs and exact outcomes.

The combined quest gate passes **352 wins, 1,056 run restores, 352 progress
resumes, six release transitions and the final quest result**. It follows the
app's canonical campaign order, including conversions before Holiday 1994.
The harness selects the correct artwork and mechanics for each conversion rank.
The release audit now requires this expanded quest as well as the official gate.

The final corpus passes all required checks across 6,372 retained levels:
292 official wins, 60 conversion wins and 344 optional fan wins. All 6,020 fan
levels load, render and start. Nine optional fan replay failures remain visible.
The inventory and original level data are unchanged.

The solution bundle and hint catalogue each contain 350 distinct records for
352 level identities. Conversion hints use the same verified route exporter as
the official campaigns, with per-rank artwork. Off-canvas assignments remain in
the full replay and are omitted from map markers. The rescue audit covers all 60
conversions: 39 full-population certificates and 21 observed winning counts.
An observed count is not a proof of the maximum possible rescue.

Native traces, coordinate plans and bounded route searches supplied the exact
inputs. [Cormac Murray's Mega Drive walkthrough](https://gamefaqs.gamespot.com/genesis/586283-lemmings/faqs/57427)
helped identify several intended paths. No engine rules, level geometry, quotas
or skill supplies changed to obtain these wins.

Reproduce with `zsh Scripts/verify-official-classic.sh --include-conversions`.
Preserved evidence:

- [Combined quest report](ClassicConversionQuest.json).
- `.build/closure-sep22/logs/conversions-full-gate.log`: all strict routes,
  combined session/recovery checks and six atomic-report rejection cases.
- [Corpus summary](ClassicConversionCorpus.json): passing full-corpus gate with
  hashes of the detailed results. The required blocker list is empty.
- `.build/closure-sep22/logs/hints-conversion-tests.log`: repeatable export and
  rejection of altered official and conversion outcomes.
- `.build/closure-sep22/logs/hint-catalogue-conversions.log`: conversion rank
  coverage, hint stages, input ordering and spoiler boundaries.
- `.build/closure-sep22/logs/hints-conversion-ui-final.log`: fresh native app
  integration passes for all 350 decks, live conversion identities, flat/CRT
  hints, solution playback, paused runs and spoiler controls. All three
  conversion ranks and the off-canvas route have inspected captures under
  `.build/hints/family-ohYesMoreLemmings-*.png`.
- `.build/closure-sep22/logs/quest-conversion-negative.log`: the final optional
  conversion test mode rejects all six damaged-evidence cases. The default
  official-only mode retains its three rejection cases.
- `.build/closure-sep22/logs/trolley-conversions.log`: current conversion rescue
  results. Catalogue and retained-target checks also pass.

The first UI test setup could not enumerate its symlinked Ports directory.
The rerun used an isolated copy of those assets and passed. The live local app
and distributed archives were not changed.

This closes the Classic and conversion content/progression gates in source.
L2/L3 previews, physical input/hardware validation and final 1.0 packaging keep
their separate release gates.
