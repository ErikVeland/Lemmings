# Holiday style aliases

13 September 2026. The shared Classic style resolver mapped both `Xmas` and
`Christmas` to slot 0. In the Xmas 1991 data, that slot contains brick graphics
for the Oh No! promotional levels. The Holiday snow graphics are in slot 2.
Xmas 1992 has no slot 0, so an installation with only that release could not
resolve the aliases.

Both aliases now select slot 2. Release-directory preference, case/whitespace
handling, missing-data reporting and pack overrides retain their existing rules.
The fan loader's explicit Holiday 1994 mapping is unchanged. Native L2/L3 style
selection and saved-run formats do not change.

The old tests checked only whether a named style was recognised and could load
objects. Brick passed those checks. The new regression compares the complete
ground set with Holiday snow and rejects the promotional brick set. It also
checks Xmas 1992-only data, pack override selection and missing assets.

The new test failed against the previous library with:
“Xmas selected promotional brick instead of Holiday snow”.

This is a shared resolver correction, not additional completion evidence.
The nine remaining terrain failures require missing asset definitions, and
14 records still have no entrance. Those records remain in the failure inventory.

## Validation

- The complete Amiga-versus/style suite passes, including the new alias regression.
- The fan-library suite passes with 218 Oh No!/Xmas records, 64 Holiday records,
  literal ZIP member selection and duplicate-member rejection.
- The strict original Lemmings gate verifies all 120 routes with no missing or
  failed fixtures.
- The core library was rebuilt for arm64 and macOS 13. The only core source change
  is the two alias slots in ClassicStyleResolver.
- The full 6,395-level corpus retains all 605 verified wins and identical initial
  states and statuses. The final manifest reports no input drift.
- The whole-corpus completion gate still fails: 5,790 records lack verified
  winning routes. The 23 load/start failures are unchanged.
- Native L2/L3 and GUI suites were not rerun for this resolver-only change.

Evidence is under `.build/beta-exit-style/`: `before.log`,
`after-final.log`, `fan.log`, `original-120.log`,
`library-inputs.json` and `bundled-ground-index.json`.
Corpus evidence: `corpus/{levels.jsonl,coverage.json,inputs.json,input-drift.json}`
and `comparison.json`. This source correction is not a signed or notarised release.
