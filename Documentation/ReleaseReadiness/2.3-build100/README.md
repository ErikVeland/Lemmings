# 2.3 build 100 release record

Release in progress. [Release notes](../../ReleaseNotes-2.3-build100.md).

Release commit: d1d1ddac201dd97f86dbe9ffac3f702f55ae47d9
Release base: v2.2.2

## Engine checks (26 October 2026)

The candidate changes NeoLemmix simulation, audio (SoundEffectPlayer,
MusicFileDeck, MusicRewindBuffer, SoundtrackPlayer), L2 faller rendering and
ClassicGameFlow. The following affected engine and regression checks were run
before release on the release candidate source:

| Check | Result |
| --- | --- |
| NeoLemmix replay tests (`run-neolemmix-replay-tests.sh`) | PASS |
| NeoLemmix simulation tests (`run-neolemmix-simulation-tests.sh`) | PASS |
| Classic DOS replay tests (`run-classic-dos-replay-tests.sh`) | PASS |
| Extra-skill engine tests (`run-extra-skill-engine-tests.sh`) | PASS |
| Music rewind tests (`run-music-rewind-tests.sh`) | PASS |
| Hot Seat ghost tests (`run-hot-seat-ghost-tests.sh`) | PASS |
| Save recovery tests (`run-save-recovery-tests.sh`) | PASS |

The L2 faller change is rendering-only (anchor offset correction). The
`run-mac-sound-tests.sh` pre-existing failure (12 unbound Mac disk sound events)
is unchanged from 2.2.2 and is a content gap, not a regression.

Automated tests ran headless and muted per repository instructions.
Full replay audit, physical-device acceptance and live service acceptance
retain their recorded limits from [PlatformFeatureParity.md](../../PlatformFeatureParity.md).

## Delivery

| Channel | Build | State |
| --- | ---: | --- |
| Mac | 100 | Pending: build-and-notarise.sh |
| iPhone/iPad/Duo TestFlight | 34 | Pending: Tools/IOSBeta/build.py then App Store Connect |
| Apple TV TestFlight | 13 | Pending: Tools/IOSBeta/build.py then App Store Connect |
| AltStore Classic | 34 | Pending: publish IPA to GitHub release and update altstore.json |
