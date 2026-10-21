# 2.1.1 build 95 release record

Published on 21 October 2026 at [GitHub](https://github.com/ErikVeland/Lemmings/releases/tag/v2.1.1).
Release source: `9af6210022a51f4df086c88803d992839b782828`. Compiled source:
`ec1815441e055cc054e7457fc06efccd0ccba632`, cut from current main `a2245430`.
The [release notes](../../ReleaseNotes-2.1.1-build95.md) cover Journey counts,
automatic worldwide rankings, current Mole timing and recovery, bundled fan
scope and Macintosh-first menu music.

## Mac delivery

Both archives contain Apple silicon and Intel code and require macOS 12.3 or
later. Developer ID signatures, Apple notarisation, stapling and Gatekeeper
passed after archive extraction. The full update contains the complete music
bundle; the slim installer contains the canonical main soundtrack.

Five direct updates, from builds 93, 91, 90, 87 and 86, each reproduce 18,568
files and links, including permissions, and pass signature checks. The installed
Ed25519 public key verifies the full update and all five deltas. All seven public
assets pass size, SHA-256 and HTTPS checks. The signed appcast matches remote
main and the public feed. See [publication receipts](publication.json),
[delta checks](delta-verification.json) and [signature checks](signature-verification.json).

## Source and regression checks

The release commit changes only three assertions in the fan archive test:
20 source levels, 19 bundled-playable levels and 20 imported levels. The exact
corrected test copy passed against the release library. Product inputs match
the compiled commit. [Source provenance](source-provenance.json) records the difference.

All 56 minor-scope checks are accounted for with their recorded reruns. The
original audit ran out of disk during its final stages. Completed results were
retained. The interrupted checks passed after cleanup. The recording benchmark
passed after Sparkle disk work finished; earlier loaded runs failed encoder
admission. The mobile ghost tests passed from the real asset directory after
rejecting the checkout's linked asset path. No product change was needed.
The 21 focused progress, Hot Seat learning and automatic-ranking tests pass.
All native tests remained offscreen with audio muted. Foreground-only focus
checks were skipped, as required. See [verification summary](verification-summary.json),
[audit results](audit-results.json) and [short local timings](performance.json).

Fresh rescue verification retains 294 population certificates and 315 rescue
records across 615 configurations, with six configurations unknown. The current
L3 audit reproduces 399 of 416 fixtures, with the same 17 gaps on levels 107,
206, 213 and 229. It closes no new route. See [L3 results](l3-fixture-report.json)
and the [merged-runtime evidence](../Release211ProgressionMerge-2026-10-21.md).
The current Classic fan inventory is 2,404 accepted routes across 6,019 playable
levels from 6,020 source rows. The exact no-exit record remains in its source
archive and is excluded from bundled play.

## TestFlight

iOS 2.1.1 build 18: **Testing**, assigned to the existing
iOS Private Beta group. tvOS 2.1.1 build 8: **Waiting for Review**,
assigned to TV Private Beta. Both uploads succeeded. Current notes are saved,
and automatic tester notifications are enabled. Apple beta review remains a
separate delivery stage. [Mobile receipts](testflight.json) record the build IDs,
archive/export checks, symbols and IPA hashes.

Mobile Journey playback remains Classic-only. Physical touch, remote/controller
focus, VoiceOver, live cloud propagation, sustained performance and the existing
engine-fidelity and route limits remain open. This release preserves the shipped
Classic/The Tribes Complete and Chronicles/NeoLemmix Beta classifications.
