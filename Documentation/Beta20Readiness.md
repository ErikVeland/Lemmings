# Beta 20 readiness

Version 0.1, build 20 is ready for private beta testing.

Source commit: `732c0a9ce2a109ce61be266d4358b02982f87ccc`. Sources and assets were copied to `.build/beta20/source` before building. The input manifest still matches that snapshot.

## Archives

- Standard: `.build/beta20/standard/UltimateLemmings-0.1-beta20.zip`. Developer ID signed, accepted by Apple, stapled, and accepted by Gatekeeper after extraction and quarantine.
- Game Center: `.build/beta20/gamecenter/UltimateLemmings-0.1-beta20-gamecenter.zip`. Development signed with the profile covering both devices in `BetaTesters.md`. Gatekeeper rejection is expected because this variant cannot be notarised.

Both archives contain the beta 20 release notes and universal Intel/Apple silicon binaries. Minimum macOS is 13.

## Validation

- Full app integration tests passed on Apple silicon and Intel under Rosetta, including Hot Seat and checkpoint boundaries.
- All 25 core/bundled gameplay suites passed. The asset-dependent platform suite was rerun after bundle assembly.
- Swift Testing: 18 tests across four suites passed.
- Dedicated Hot Seat records tests, sequel artwork and interaction checks, playfield rendering, controller input, speed, HDR, CRT, viewport and slim packaging checks passed.
- All 120 original level solutions passed. Additional known-solution checks passed: 88 Classic-family levels and 16 L3 levels. This does not certify every campaign level.
- Rescue audit completed for 562 levels / 565 configurations: 158 verified, 136 observed, 268 unknown. Generated audit outputs were preserved separately from the frozen release inputs.
- One Apple silicon controls-help sheet check lost focus during overlapping graphics tests. The complete integration suite passed when rerun with UI tests serialised.

Logs, input hashes and archive checksums are under `.build/beta20`. Notarisation submission: `b739d14b-c696-4878-af9a-5544b8888736`.

## Archive SHA-256

- `standard/UltimateLemmings-0.1-beta20.zip`: `590a00055dae3e9145349b02f7ceb6c4cf1fa2dfad6ffa997fa0711bac666023`
- `gamecenter/UltimateLemmings-0.1-beta20-gamecenter.zip`: `df814ba10f31adf99fc484d5a6210ce05ca98ae3e337520b8d31ccd1a376885e`

Physical controller journeys, physical Intel/minimum-macOS testing, full VoiceOver listening validation, complete campaign coverage and mid-level shared-attempt attribution remain outside this beta sign-off.
