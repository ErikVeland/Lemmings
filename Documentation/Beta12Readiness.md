# Beta 12 release evaluation

Updated 10 September 2026. Version 0.1, build 12.

## Verdict

The follow-up candidate is built, Developer ID signed, notarised and stapled.
All 39 fresh test groups and verification gates passed. The quarantined,
extracted ZIP passes Gatekeeper as **Notarized Developer ID**. Apple accepted
submission `a14ae136-e2a9-419e-b172-167a520fe998`.
The original beta 12 candidate and its evidence remain preserved in
`.build/beta12`; follow-up evidence is in `.build/beta12-followup`.

This beta does not justify a 1.0 claim for every listed campaign. Automated
checks do not replace complete campaign solutions or testing on supported hardware.

## Closed gaps

- Oh Yes! resolves each rank's artwork, including Sunsoft ground metadata and
  its special background. All 60 converted levels render and release lemmings.
- NeoLemmix rejects unsupported skills and object mechanics before replacing
  the current playfield. Zero-stock unsupported skills remain acceptable.
- Lemmings 3 plays tribe module music and six named original voice samples.
  Volume, mute, replay suspension, stopped-player safety and recording are connected.
- The L3 pause menu offers all five original movies. Streaming playback supports
  pause, return and safe shutdown. Gameplay stays suspended during playback.
- The additional campaign gate checks 88 classic-family and 16 L3 winning
  replays, with input, identity, outcome and fixture-integrity checks.
- Fast-forward trails remain faint and short. They follow measured movement,
  including diagonals, and draw beneath all solid lemmings. Blur is cached.
- The package includes release notes and accurate game-data notices.

## Validation

The follow-up [test manifest](../.build/beta12-followup/test-results.json) records
fresh checks: 28 core suites, five app subsystem suites, both architecture
integration runs, sequel views, original completion, additional campaign
completion and the rescue audit. The earlier [44-check baseline](../.build/beta12/test-results.json)
also includes HDR GPU output, CRT pipelines, viewport geometry, fan downloads,
Swift Testing and packaging checks. Baseline checks are not counted as fresh runs.

The original 120 Classic replays still win. Their negative gate rejects missing,
invalid and regressed evidence. The new [campaign gate](CampaignCompletion/README.md)
checks 104 more fixed-input witnesses: Oh No! 54, Xmas 1991 4, Xmas 1992 2,
Holiday 1993 13, Holiday 1994 15 and L3 16. Only Xmas 1991 has full coverage
among these extra campaigns. Some L3 routes use End Run after rescuing lemmings;
reserves remain separate from rescues. L2 retains 64 standalone level completions.

The refreshed rescue audit covers 562 level identities and 565 configurations.
It contains 158 proven maxima and 136 other winning witnesses; 268 levels have
no winning witness. The bundle contains 161 exact-condition certificates,
including three alternate L2 carry-over configurations, and 17 best-known records.
The audit can find additional no-input wins beyond the committed campaign fixtures.
Missing witnesses do not establish broken levels. See the
[level-by-level audit](TrolleyVerification/levels.md).

## Performance and environment

Tests run on an Apple M4 Pro with macOS 27.0, build 26A428. Both binaries target
macOS 13. Rosetta checks do not replace physical Intel testing.

The unchanged speed effect's original beta 12 benchmark measured these
warm-cache medians for 80 lemmings:

| Drawing size | Plain sprites | With speed trails | Added time |
| --- | ---: | ---: | ---: |
| 1920 × 1080 | 0.745 ms | 0.963 ms | 0.218 ms |
| 3840 × 2160 | 1.839 ms | 2.790 ms | 0.951 ms |

These measure sprite drawing, not complete game frame rates. Trail draws are
capped at 24 per frame. High-refresh-rate, long-session and older-Mac performance
remain tester checks. The baseline GPU test validates HDR values; the current
Studio Display desktop reports SDR headroom.

## Remaining 1.0 gates

| Area | Evidence still required |
| --- | --- |
| Lemmings 2 | The remaining 56 level solutions, continuous campaign progression and broader original-engine comparisons. |
| Lemmings 3 | The remaining 74 level solutions, provisional mechanics, environmental effects, movie soundtracks and automatic story triggers. The gallery is not full original front-end integration. |
| Oh No!, Xmas, Holiday and conversions | Remaining winning solutions across advertised levels. The audit has 57 Oh Yes! levels without a winning witness. |
| NeoLemmix | Representative fan-pack playthroughs within the supported feature set. Unsupported features fail explicitly. |
| Hardware and upgrades | Physical Intel, minimum supported macOS, longer display/performance sessions and real beta 11 upgrades. |
| Public distribution | Private-beta notarisation and downloaded-ZIP checks pass. A public release still needs an agreed game-data distribution model. |

Further visual polish and proving every maximum-rescue upper bound do not need
to block a stable release with accurately labelled records.

## Reproduction and artifacts

[Build inputs](../.build/beta12-followup/build-inputs.json) record the compiler,
targets and engine fingerprint. The frozen source snapshot and manifest are in
`.build/beta12-followup`. This report may be updated after that snapshot as a
final validation record. The prior beta 11 archive and initial beta 12 candidate
remain preserved. A concurrent HDR animation edit arrived during packaging; it
is preserved in the working tree and excluded from this frozen candidate. Both
release binaries and integration harnesses were rebuilt from the frozen source.
The app subsystem and sequel-view checks also use that frozen source.

Follow [BetaTesting.md](BetaTesting.md) for a fresh build and the full suite.
The follow-up candidate uses `.build/beta12-followup/package-candidate.sh`;
`RESUME_NOTARY=1` resumes submission of that signed candidate. Verify it with
`python3 .build/beta12-followup/verify-package.py`. Use these follow-up paths,
not the original beta 12 packaging script.


## Signed handoff

- [Beta 12 ZIP](../.build/local/UltimateLemmings-0.1-beta12.zip)
- [Signed candidate app](../.build/beta12-followup/candidate/Ultimate%20Lemmings.app)
- [Package verification](../.build/beta12-followup/release-verification.json)
- [Installation record](../.build/beta12-followup/handoff.json)

Archive size: 424,719,680 bytes. SHA-256:
`e83c721b20713c73bb4122c2c88256f86fb362f0e6f41bbec99aa0fe738cd353`.

The archive contains both macOS 13 architecture slices, 535 fan packs with 6,043
readable levels, 161 rescue certificates, 17 best-known records, and all eleven
newly connected L3 media files. File hashes match the frozen inputs. The source
snapshot covers 3,791 files and their resource forks.

A newer HDR build in `.build/local/Ultimate Lemmings.app` is preserved. Use the
ZIP or the signed candidate above to test this exact release. The current
working tree continues to contain the separate HDR work.

The preserved beta 11 snapshot was checked against its own release manifest
and both binary hashes. The older beta 12 preservation record's local ZIP path
is no longer present; the replacement reference and original expected hash are
retained in the package verification record.
