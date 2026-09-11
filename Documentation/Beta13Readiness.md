# Beta 13 release verification

Version 0.1, build 13. This beta includes shared sessions, checkpoint recovery and
the latest interface refinements. It is not a 1.0 release.

Release notes: [beta 13](ReleaseNotes-beta13.md). The source and assets are frozen
under `.build/beta13/source`. Build logs, checksums and verification results are
retained under `.build/beta13`.

## Automated gates

Every recorded check passed against the frozen source. See
[verification.json](../.build/beta13/verification.json) for the log names and their
hashes: profiles, sequels, playfield, app, replay, audit integrity and signing
configuration. The replay check needed one harness filename correction, and the
first failed log is kept beside the passing one.

The working tree matches the frozen source exactly for `Sources`, `Tests`,
`Resources` and `Scripts`.

## Package

Both archives are built, signed, notarized, stapled and checked. The verification
step extracts each zip to a new folder, applies the download quarantine flag, and
asks Gatekeeper. Both results read `accepted source=Notarized Developer ID`.

| Archive | Purpose | Notarization ID | SHA-256 |
| --- | --- | --- | --- |
| `.build/beta13/package/UltimateLemmings-0.1-beta13.zip` | Frozen-source evidence copy | `4b3437ff-586a-4d64-ba4a-7301d9881645` | `e44443ebd7778d7ab963c73f10b2abccf8e6007ab8baacd4605d4e14879469b5` |
| `.build/local/UltimateLemmings-0.1-beta13.zip` | Tester handoff copy | `46681b7b-f6c2-4b4a-8d59-a68a462a1b82` | `a2d038bf8a58dcb200a93f932e21ceef2a139716b3643389beddc339e64aac81` |

Apple accepted both submissions. The two hashes differ because the build and the
signature record their own timestamps. The packaging is not bit-reproducible. Send
only one archive to testers. Use the handoff copy.

- Executable slices: `x86_64` and `arm64`.
- Minimum system version: macOS 13.0.
- Archive size: about 406 MiB.
- `Release Notes.md` is included inside each zip and beside it.

## Limits

This verification covers the package only. It does not close any campaign,
fidelity, accessibility, hardware or publishing gate. See the
[1.0 gap evaluation](ReleaseReadiness/OneZeroGapEvaluation.md) and the
[gate register](ReleaseReadiness/gates.json).
