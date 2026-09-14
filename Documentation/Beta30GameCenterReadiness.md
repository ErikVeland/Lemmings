# Beta 30 Game Center readiness

13 September 2026. The private Game Center beta is packaged and ready for the
two registered test Macs. It is a universal macOS 13+ app with full soundtracks.
This is an Apple Development build. It is not notarised or a TestFlight upload.

## Package

- ZIP: `~/Downloads/UltimateLemmings-beta30-gamecenter-macOS.zip`
- Notes: `~/Downloads/UltimateLemmings-beta30-gamecenter-ReleaseNotes.md`
- Size: 426,513,004 bytes.
- SHA-256: `9d72cc9f7d732cc0ccd2be1d273238ff8330e024e5b5f7ffa7263225ac685fce`

The embedded profile covers two Macs and expires on 11 September 2027.
The older installed profile covered only one Mac. The final archive uses the
newer two-Mac profile, preserved with its hash in the release evidence.

## Validation

- Both the executable and core library contain arm64 and x86_64 slices.
- Strict signature verification passed on a freshly extracted archive.
- The profile, application identifier, Game Center entitlement and spatial
  audio entitlement agree. The bundled leaderboard catalogue is enabled.
- Leaderboard IDs and score thresholds are unchanged.
- All 9,529 resource files were compared with beta 29. Updated hints and rescue
  evidence match the frozen source. Regenerated lossless tracks decode to the
  same audio as beta 29 and the frozen source WAVs.
- The archive matches the signed app and includes the release notes.
- Signed-app startup passed natively on Apple silicon and under Rosetta.
- Game Center transport tests passed for offline recovery, score duplication,
  displayed ranks and local-player ownership. The complete Trolley suite passed.
- A stale UI test was corrected to click rendered button targets and open the
  affinity popover from Details. The correction changes only test code.
- Frozen package inputs have no drift. All 176 product Swift files match the
  previously validated beta 29 source. The beta 29 ZIP is unchanged.

Gatekeeper rejects this development signature on a quarantined download, as
expected for this distribution path. Testers must follow the quarantine step in
the [release notes](ReleaseNotes-beta30.md). The archive is limited to the Macs
registered in its profile.

Live Game Center sign-in, account changes and real score submissions remain
tester checks. The transport tests use a test implementation of the service.
Classic 1.0 completion and the existing hardware validation gaps remain open.

Evidence is in `.build/beta30-gamecenter`: `release-results.json`,
`package-verification.json`, `resource-verification.json`, `profile-input.json`,
`validation-followup.json`, `trolley-tests.log` and `launch-smoke.log`.
The source snapshot and corrected follow-up test source are preserved there.
