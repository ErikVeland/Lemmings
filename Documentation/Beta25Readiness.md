# Beta 25 readiness

Version 0.1, build 25. Universal arm64 and x86_64 app; macOS 13 or later.

## Frozen inputs

Base revision: `9e1b901dfa1f9c938eee5eb5f15a9c7a2299255e` plus frozen release metadata.
Snapshot SHA-256: `2917b5de8bff711ddcd14e6552e98a38348968f4e2eb9b90033586eaeb30fef3`.
All 745 recorded source, test and resource inputs remained unchanged.

Only GameplaySpeed.swift changed in the shared core since beta 24. The Classic
simulation sources are unchanged. Game assets match beta 24 byte for byte;
release notes, scope and build metadata are the only resource differences.

## Checks

- Both complete app journeys passed: 32 checks on arm64 and 32 on x86_64 under Rosetta.

- All 25 core/resource regression suites passed against the updated library.
- Dedicated speed and controller binding tests passed. F retains each reached tier; arrows apply speed from 1×, and quick exits stop it.
- Focused app integration passed for real mouse/key events, actual 2×–10× simulation timing, pause/resume, CRT input and presentation.
- The updated keyboard overlay was rendered and inspected. HUD skill labels, green shortcuts, unified speed control and rightmost Next Level layout carry forward from the inspected beta 24 interface.

- Main-window ownership was corrected after validation exposed a delayed-refresh crash. The full journeys include window close and refresh coverage.
- The handover screen was rendered and inspected: incoming initials are green, Retry Last Level uses the incoming player, and Begin Level stays on the right. Tests cover real mouse activation, shared progress, failed-level boundaries and stale solo actions.

## Remaining scope

Beta 23's 6,395-level corpus audit remains the coverage baseline: 223 official
Classic wins and 294 fan wins, 94 fan load/start failures and 5,878 levels without
verified winning routes. This release does not claim a fresh full-corpus audit.
Full Classic/fan compatibility, physical Intel/controllers, minimum-macOS hardware,
complete VoiceOver and sustained performance remain open. L2 and L3 remain previews.

## Signing

Apple accepted notarisation `7ece2524-be4e-4e26-b63c-38aeda848e81`.
The standard app is Developer ID signed, notarised and stapled.
The separate Game Center app is development signed for two registered Macs.

## Final archives

Both final ZIPs were extracted and their signatures, build numbers, processor slices and bundled notes checked. Gatekeeper accepted the standard app with a fresh quarantine attribute as Notarized Developer ID. The Game Center entitlement and two-device provisioning profile were verified.

- `UltimateLemmings-0.1-beta25.zip`: SHA-256 `5da71ff5d67b82390779e0e5a3021198b2f33095f216db1208cc8ec4d13502a6`.
- `UltimateLemmings-0.1-beta25-gamecenter.zip`: SHA-256 `f9825bf14db02f06574547be65e980543f71c6b63dd0ff02e11cb038a1310b77`.

Evidence, logs, source manifests and rendered screens are retained in `.build/beta25`.
