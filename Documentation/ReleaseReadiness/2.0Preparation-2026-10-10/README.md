# 2.0 iOS source preparation

The 10 October scope requires Classic, Lemmings 2 and Lemmings 3 on iPad,
iPhone and iPhone Duo. This record verifies the first shared-library refactor
and the existing mobile build baseline. It does not certify the 2.0 release.

The shell now uses `MobileGameLibrary`, `MobileLevelSummary` and
`MobileLevelContent`. Classic implements the library contract. The displayed
interface and Classic behaviour stay the same. Sequel content factories,
renderers and campaign flows remain open.

The source gate checks available runtimes rather than matching their names
alone. It reports CoreSimulator query failures separately from missing runtimes
and forces mechanical-test audio to muted.

## Results

- All 13 focused mobile core tests pass, including checkpoint restoration for
  Classic, L2 and L3.
- Debug and Release Simulator products build with arm64 and x86_64 slices.
- The unsigned Release device product builds with an arm64 slice.
- All 48 release-tooling tests pass.
- Runtime-probe checks cover available iOS, unavailable iOS, non-iOS and
  malformed responses.
- The recorded source files retain identical hashes across the final gate.

The selected toolchain is Xcode 27.2 build 27B5019j with the iOS 27.2 SDK.
Service-accessible discovery finds an available iOS 26.0 runtime. No Simulator
was booted and no native UI test, foreground window or audible test was run.

The first pass built products but exited 127 because the gate script changed
while it was active. It also emitted Xcode diagnostics about commands that
failed with exit code zero. The stable incremental rerun exits zero and does
not repeat those diagnostics. Both logs are retained. This is an incremental
source check, not a clean final-candidate archive build.

See [evidence.json](evidence.json), [source-manifest.json](source-manifest.json)
and [source-gate.log](source-gate.log) for exact source and product identities.
The [2.0 roadmap](../../2.0Roadmap.md) lists the remaining delivery and device
acceptance gates. No source or build result closes three-game gameplay, Duo,
physical-device, accessibility, signing, TestFlight or App Store acceptance.
