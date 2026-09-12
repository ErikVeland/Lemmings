# Beta 24 readiness

Version 0.1, build 24 is ready for private beta testing. Universal Intel and Apple
silicon app; macOS 13 or later.

## Downloads and notes

- [Standard beta](../.build/beta24/standard/UltimateLemmings-0.1-beta24.zip): Developer ID signed, notarised, stapled and Gatekeeper accepted after fresh extraction and quarantine. Local records enabled.
- [Game Center beta](../.build/beta24/gamecenter/UltimateLemmings-0.1-beta24-gamecenter.zip): development signed for the two registered test Macs. Extracted signature and Game Center entitlement verified. This variant cannot be notarised.
- [Changes since beta 18](ReleaseNotes-beta24.md): the full cumulative notes are included in both apps and archives.

Beta 24 adds held-F speed ramping, one continuous speed control, restored skill
names with green shortcut letters, and Next Level at the right of both retry choices.

## Verification

- Full app integration: 30 checks passed on Apple silicon and 30 on Intel under Rosetta.
- All 25 core/resource regression suites passed, compiled from the frozen beta 24 tests.
- Dedicated speed and controller binding tests passed.
- Rendered skill labels, shortcut letters, speed states and result actions were inspected before the release freeze. The shipping interface source matches that build.
- All 745 recorded source, test and resource hashes remained unchanged during the build.
- NxlvKit source and engine binaries are unchanged from beta 23. Game assets match byte for byte; release notes, scope and metadata are the only resource changes.
- Both archives contain matching app/root notes, scope and build metadata. Both executables and libraries contain arm64 and x86_64 slices.

Apple notarisation: `79d1e95f-e6e9-4eb9-8cc5-a94ab6698ef7`.
Base source: `9511021bfd16a6bbcb6893cfeb92ba250dc5d852` plus frozen release metadata.
Snapshot SHA-256: `1d90bd8179849f9becb575b912b4fb9b9d513364b44db6a2453fe06cad10b025`.

Logs, captured screens, manifests and archive validation are in `.build/beta24`.
An initial regression attempt lost access to the previous build directory; the
final run rebuilt every test executable in beta 24's directory and passed.

## Remaining limits

The full Classic/fan completion gate remains open. Beta 23's corpus audit is the
coverage baseline: 6,395 identities, 223 official Classic wins and 294 fan wins,
94 fan load/start failures, and 5,878 levels without verified winning routes.
Beta 24 does not claim a fresh full-corpus replay audit. Physical Intel/controllers,
minimum-macOS hardware, full VoiceOver and sustained performance remain unverified.
L2 and L3 remain previews.

## Archive SHA-256

- `UltimateLemmings-0.1-beta24.zip`: `8a9f6a79744728855cb66551dc28338d8f7d0182108b6adf558774eb262ee404`
- `UltimateLemmings-0.1-beta24-gamecenter.zip`: `fbf3cd1b0d0de96b09a2f81a4bd0dfaf2e88b2834cc55c5f37af46680fc67a09`
