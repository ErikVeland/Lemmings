# Beta exit: text import hardening

13 September 2026. Local source changes after beta 27. No new release package
was built, and no campaign or physical-device gate is closed by this pass.

## Closed defects

- Text imports reject coordinate and time-limit arithmetic overflow instead of
  terminating the app.
- Invalid and empty numeric components are rejected. They can no longer shift
  later values into the wrong object, terrain or steel fields.
- An explicitly malformed optional number is rejected instead of becoming a
  default. A malformed minute value cannot silently fall back to seconds.
- The standard release audit now runs the text-import regression suite
  (`AmigaVersusTests`) and the fan-library suite.
- The release-scope document now identifies beta 27, the current 85 fan
  load/start failures, and the implemented accessibility work accurately.

## Validation

- Optimised shared-library build and complete Amiga versus suite passed,
  including 11 malformed-input cases and existing valid text-format vectors.
- Complete fan-library suite passed against the rebuilt library, including
  archive validation, offline behaviour, custom graphics and special pictures.
- All 274 bundled text inputs matched the previous parser's results exactly:
  272 identical record hashes and the same two rejected files.
- Both release-audit integrity tests passed. `git diff --check` passed.

Local logs and comparison inputs are under `.build/beta-exit-imports/`:
`amiga-versus.log`, `fan-library.log`, `ini-index.json`, `baseline.txt` and
`current.txt`. This was focused validation, not a complete release audit.

## Remaining work

The [gate register](gates.json) still applies. The 69 missing official Classic
routes, 85 fan load/start failures, sequel fidelity, physical recovery and
controller trials, VoiceOver listening, sustained hardware performance and
external distribution requirements remain open.

The subsequent [text-steel pass](TextSteelClosure.md) fixes the steel defect found
here and adds saved-attempt compatibility. The byte comparison above records the
earlier parser-only change. It does not describe the later steel correction or
prove text-format fidelity or solvability.
