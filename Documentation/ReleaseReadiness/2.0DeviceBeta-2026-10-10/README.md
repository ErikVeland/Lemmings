# First 2.0 device-beta candidate

Prepared 10 October 2026 with stable Xcode 27.1, build 27A9269.
The candidate is version 2.0, build 1, for iPhone and iPad on iOS 16 or later.
It uses `academy.glasscode.lemmings.ios` and team `54WU29TRTY`.

The candidate bundles the original 120-level Classic campaign for offline
startup. Lemmings 2 and 3 remain required for the full 2.0 launch. Their
mobile libraries and renderers are not connected in this candidate.

## Verified

- A signed arm64 Release archive and development IPA were produced.
- The archive and exported app passed code-signature verification with system
  keychain access. The installed development certificate and wildcard iOS
  profile belong to the configured team. The profile includes the paired iPhone.
- The compiled icon, 2.0/build 1 metadata, iPhone/iPad device families,
  privacy reasons and 26 bundled input hashes passed archive inspection.
- Executable and dSYM UUIDs match. Executable and IPA hashes are in `evidence.json`.
- All 120 levels loaded and rendered with a panel. Each session ran 50 ticks,
  then restored an exact snapshot and bitmap from its checkpoint.
- All 13 mobile core tests and 52 release-tooling tests passed headlessly.
  Mechanical tests were muted.
- Mobile source hashes matched before and after archiving and exporting.
  They remained unchanged during the exported-app check.

The binary and symbol files remain in ignored local build output:
`.build/ios-beta/2.0-1-development`. The repository records manifests and
validation results, without commercial data or signing credentials.

## Limits

No physical gameplay or rendered UIKit acceptance is claimed. No Simulator
or game window was launched by these checks. The default offscreen native
runner does not yet have a verified iOS workflow. Rotation, touch targeting,
VoiceOver, background termination, update migration and sustained performance
need checks on the installed beta. iPad and Duo hardware acceptance remain open.

The current mobile slice has no connected music or sound playback, Game Center,
Hot Seat or durable campaign progress. Do not apply Mac feature claims to it.

Local development signing and export succeeded with existing signing assets.
The installation attempt stopped because the paired iPhone was locked
(CoreDevice error 10003). The owner asked to keep the signed build for later.
The app was not installed or launched.

The TestFlight export attempt exited 70. Xcode reported no valid account session
and no iOS App Store profile for this bundle ID. Sign back in under Xcode
Settings → Accounts, then prepare an App Store Connect export and app record.
No IPA was uploaded and no tester invitation was sent.
The final delivery status is recorded in `evidence.json`.

The initial sandboxed attempt in `.build/ios-beta/2.0-1` passed real-data
validation but could not archive because Xcode could not access its package
cache. The stable signed candidate supersedes that failed preparation attempt.

Use the [device-beta procedure](../2.0DeviceBeta.md) for later builds and
the manual acceptance matrix. Keep the three-game mobile distribution gate open.
