# 2.0.7 build 91 release record

Published on 2026-10-19 at [GitHub](https://github.com/ErikVeland/Lemmings/releases/tag/v2.0.7).
Frozen source: `a851d3577bf1a21bc023db94357ea3693bd29e63`. Release base: `v2.0.6`.

The release owner requested a quick public release, approved the gates and
explicitly waived engine tests. No gameplay, integration, launch or hardware
tests were rerun. Earlier focused About, count-recovery, donation, menu and
simulator checks remain recorded in the feature documentation.

The universal Mac full update and slim fresh-install app both passed Developer
ID signature verification, Apple notarisation, stapling and Gatekeeper checks
after archive extraction. Both contain Apple silicon and Intel slices and
target macOS 12.3 or later. The full update retains the soundtrack. The slim
download contains 54 essential music versions. Both bundle the opted-in public
credits without the private supporter ledger.

All seven public assets passed HTTPS, size and GitHub SHA-256 digest checks.
They include five signed direct deltas from builds 90, 87, 86, 85 and 84.
The signed appcast matches both remote main and its public HTTPS response.
Checksums, URLs and accepted Apple submission IDs are in
[publication.json](publication.json). No application was launched by this run.
Direct delta installation and relaunch were covered by the owner's gate waiver.

## Rescue-target certificate limit

The retained proof fingerprint matches the 2.0.6 engine source. The only
`Sources/NxlvKit` source change since that release is `MenuThemeSelection.swift`,
which is included in the proof fingerprint. Its change makes those certificates
stale. They were not relabelled as verified. This release leaves the affected
targets unverified and records that limit in the published release notes.

This publication covers macOS only. iOS and tvOS remain separate device builds.
