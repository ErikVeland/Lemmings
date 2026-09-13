# Holiday fan graphics correction

13 September 2026. The Frost and Hail fan archives retain Holiday graphics slot 2.
The combined-editor loader treated this as marble. These levels could load with
the wrong terrain, so a load-only check did not expose the defect.

Four exact archive identities now select the bundled Holiday 1994 artwork.
All 64 records use slot 2. Thirty-one of the 32 canonical terrain/object records
match the bundled official campaign exactly. “Separate Ways” is a variant.
The cLemmings Frost/Hail records use the same Holiday snow pieces.

| Archive | SHA-256 |
| --- | --- |
| 0482-DOS-Frost.zip | `9f0b55e9f63bc1d3b5f931af6cd9881f439aba28aa939e4dd79e74c8e4b847a0` |
| 0483-DOS-Hail.zip | `0543b9c913b9999d82112c55561fc37b9e765a299c6dc4ee7dbea6c1db569d9e` |
| 0535-Holiday-cLemmings-Frost.zip | `e0b4def872bc847330ee71afc5a6e602c97aaefe65f5b0f86d28af0145245339` |
| 0536-Holiday-cLemmings-Hail.zip | `982bcf92e698b395415cb59da56b5ad4ac3e4f6224163e64920f0a55218b74a2` |

The loader checks both byte count and SHA-256. Renamed bytes retain the mapping.
Changed or unknown archives keep the existing convention. Explicit named styles
and archive graphics retain precedence. Mixed Flurry/Blitz archives remain
excluded pending evidence for their other slots.

The optional checkpoint field `fanHolidayStyles` separates this correction from
the previous `fanLocalStyles` update. Missing Holiday flags retain the old terrain,
including saves that already enabled the earlier Oh No!/Xmas correction.
Retry starts a new attempt with Holiday artwork. The app regression verifies
an exact paused legacy restore, changed initial terrain on retry, and an exact
current-save restore.

This only changes Classic-format fan graphics. Native L2/L3 asset selection,
recovery and handover paths do not change. Their native suites were not rerun
for this correction.

## Validation

- All 64 affected levels render and start with the expected source assets.
- Tests retain old marble assets when the Holiday correction is disabled.
- The preceding 218 release-local records and 108 canonical matches still pass.
- The full 6,395-level audit changes 64 initial states and adds 15 verified fan
  wins (367 → 382). All 590 previous wins remain valid. There are no new load
  failures. The same 23 invalid or unsupported records remain listed.
- The strict completion gate remains open: 5,790 levels lack verified winning
  routes. The total verified count is 605.
- Save-file corruption, version, backup, stale-writer and queue checks pass.
- The complete optimized arm64 app suite passes with beta 27 resources, including
  legacy/current Holiday saves, retry, interruption and Classic Hot Seat.
- The final corpus manifest reports no input drift. Core sources still match
  the validated macOS 13 arm64 library.

Logs: `fan.log`, `recovery.log` and `app.log`. Per-level audit evidence:
`corpus/levels.jsonl`, `corpus/coverage.json`, `corpus/inputs.json`,
`corpus/input-drift.json` and `comparison.json`.

Evidence is under `.build/beta-exit-holiday/`. This is a source correction,
not a new signed or notarised release. The beta-exit gates remain open.
