# Beta 10 readiness

Prepared 9 September 2026. Version 0.1, build 10. Full package with recorded soundtracks.

## Tester package

- Archive: `.build/local/UltimateLemmings-0.1-beta10.zip`.
- Size: 424,552,240 bytes.
- SHA-256: `3520d586f28df56b368a7356b841407a27d403004b6be9a7705c04cdb5c21324`.
- App and NxlvKit library contain both arm64 and x86_64 code.
- Both executable architectures declare macOS 13.0 as the minimum version.
- Developer ID: Erik Veland, team `54WU29TRTY`.
- Apple accepted submission `bbeb2793-9544-4b15-b869-5dab283ed7ef`.
- Stapling and independent ticket validation passed.
- The extracted final ZIP, marked as downloaded, passed Gatekeeper as
  `Notarized Developer ID`.
- The checksum sidecar and `ReleaseNotes-beta10.md` accompany the ZIP.
- The original beta 9 ZIP was preserved and its checksum verified.

## Validation

- All 22 beta regression suites, plus packaging, CRT, viewport and playfield checks passed.
- App integration tests passed on arm64 and x86_64.
- Arcade records, Trolley identity, rescue goals, profile isolation, retry history,
  in-game pages and bundled rescue proofs passed.
- Replay frame counts, audio, variable speed and movie export passed.
- Actual FP16 GPU explosion output, SDR bounds, HDR headroom and expiry passed.
- Live sequel canvas checks passed, including artwork toggles, front-end screens,
  Beach defaults, saved Classic selections and successful progression.
- Fan-library discovery, decoding, duplicate handling, download validation,
  offline preservation and a live catalogue check passed.
- Swift Testing: five tests passed.
- A test-only change made failure to solve Fun 1 fail the replay suite. That stricter
  test was rebuilt against the release library and passed.
- All 535 embedded fan archives match their source files. Their index contains
  6,043 readable levels.

Evidence is under `.build/beta10/`. `source-manifest.json` and `source-snapshot/`
record the release inputs. Production sources, resources and build scripts
remained unchanged through the build. `validation-addendum.json` records the
later test-only tightening. Logs include the notarisation and final ZIP checks.

See [Release notes](ReleaseNotes-beta10.md) for tester focus and feature limits.
