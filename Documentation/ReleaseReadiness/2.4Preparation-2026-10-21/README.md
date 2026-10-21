# 2.4 Duo launch preparation

Target: existing iOS/tvOS TestFlight groups by Friday, 23 October 2026.
See the [delivery plan](../../2.4Roadmap.md).

## Changes

- Cancel ongoing pinch and trackpad scroll updates when layout or lifecycle
  cancellation invalidates their geometry. Require a fresh gesture begin.
- Reject scroll updates inside reserved display regions.
- Clear stale pointer coordinates on layout changes while preserving hover during
  ordinary planning pauses.
- Reuse the existing pause/Ready flow when a window becomes playable again.
  A pending Start or Hot Seat Ready remains explicit.

All three native games use the shared mobile controller and playfield. No engine
rules, route witnesses, skill counts or release classifications changed.

## Checks

| Check | Result |
| --- | --- |
| Focused shared core | 91 tests in seven suites pass: layout, camera, touch, Hot Seat, checkpoint ownership, controllers and rewind. |
| Duo bitmap audit | 156 captures pass across Classic/L2/L3, eight poses and six gameplay states, plus previews. Checks include reserved regions, minimap, status, 44-point targets, overlap and hit testing. |
| Inspected renders | Classic compact book with armed end action, L2 camera/book with the last skill selected, and L3 stacked/paused remain legible with controls clear of reserved regions. |
| SDK checks | All eight modules and app entry points pass for iOS and tvOS. Final shared UI compiles again for tvOS; the final iOS production module compiles and links in the native test bundle. |
| Native Duo Simulator | 13 tests in two suites pass on iPhone Duo / iOS 27.1. Both gesture regressions, Solo Start/Hot Seat Ready after resizing, hover, interruption, save cancellation and navigation pass. |
| Physical devices | Owner can test Mac, iPhone, iPad and Apple TV. Results pending. Physical Duo unavailable; Simulator validation is the agreed launch boundary. |
| Distribution | Owner requested consolidation and publication of the latest changes. The active release chat owns the consolidated source freeze, packaging and publication. No new archive, upload or TestFlight availability is claimed by this preparation record. |

[checks.json](checks.json) records the source identities and limitations.
Later interface-copy changes require their own focused validation before the
consolidated release is frozen; these results do not certify untested changes.
The focused test and render logs are retained alongside it. Local captures and
native build products are under `.build/duo-2.4/`.

The native run uses an isolated temporary package with the production libraries
and exact copies of `MobilePoseTransitionTests.swift` and
`MobileNavigationRecoveryTests.swift`. Xcode's unit-test agent runs these tests
without an app host. The test configuration explicitly sets muted audio and
offscreen mode. These tests inject events and resize views. They do not establish
complete system-delivered fold, touch, VoiceOver or physical-device acceptance.

The full package scheme could not build its unrelated ZIP tests on iOS because
they use `Process`. The isolated harness avoids that target without changing it.
The native helper needed an explicit MainActor callback for Swift 6. Its initial
run then exposed a hover fixture that injected input before layout. The helper
now lays out the real view first, preserving the original assertions. The initial
failure and final pass remain in `native-run-initial.log` and
`native-run-final.log`. Xcode reports a runtime build-number parsing warning but
completes execution successfully.

The initial test attempt failed because the default compiler cache was outside
the sandbox. A workspace cache resolved that. The first filter selected the
whole mobile-core module, including tests missing artwork inputs. Its failures
remain in `core-baseline-retry.log`; that broad run was interrupted. The corrected
suite-qualified filter passes and does not claim artwork validation.

The first native-build attempt could not create its log because storage was
full. Three compiler caches older than 24 hours were removed after checking their
contents: `clang-cache`, `hint-availability-module-cache` and
`ridiculous-speed-cache`, about 1 GiB total. Release archives, source and evidence
were preserved. Native execution remains offscreen and muted.
