# Beta 8 readiness

Updated 7 September 2026. Baseline review: `8dad1af`.
The eight release defects are fixed. The signed, notarized archive is ready for
private beta testing, with the feature and platform limits listed below.

## Defect closure, in review order

| Defect | Resolution | Regression evidence |
| --- | --- | --- |
| Single-step skips completion | Normal ticks and single-step use `finishSessionIfNeeded` | Wins, losses, campaign progress, fan progress, repeated completion |
| Music source leaves playback silent | Source changes stop the previous player and start the selected engine | All 16 transitions among modules, recordings, DJ, None; shuffled playback survives settings changes |
| Saved audio settings ignored | Restore and apply audio settings before playback; current settings supersede the legacy preset | Saved silence, volume, and preset checks |
| Sound bank never switches | Capture the old source before assigning settings; use the bundled Mac image as fallback | Real Macintosh → Amiga → Macintosh bank replacement |
| Mute and title changes omit recordings | Global mute and suspension cover all players; L2 combines local and global silence settings | Persistent mute and stop checks across every player |
| CRT hold and drag missing | Share pointer down/up/drag handling; cancel held controls on focus or title changes | Detached-panel repeat, release, minimap drag |
| Cancelled fade damages next fade | Fade generations isolate tasks; cancellation returns without touching newer state | Overlapping cues, completed fades, stop/start during a fade |
| Slim filtering misses M4A | Remove recognised recording files while retaining modules, even in mixed folders | Fixtures and a copy of the actual bundle: 12 recordings removed, all 73 modules retained |

The app integration checks exercise the actual app delegate, player classes,
and views. They run with a separate bundle identifier and preferences. The
completion fixture ends deterministically on its next tick; the audio checks
use real local soundtrack and sound-bank files with output volume set to zero.

## Related corrections

- CRT composition is exactly 320 × 200, independent of Retina scale.
  Input uses the same display-to-source curve as the shader and routes the
  bottom 40 rows to the panel.
- The classic simulation accumulates elapsed time, with catch-up capped at
  250 ms after a long interruption. Every simulated tick publishes its sound cues.
- Audio output can suspend and resume without starting sources that were stopped.
  Sleep and audio-device configuration notifications use these paths.
- Settings reopened after a menu preset change use the latest settings.
- Release builds use optimisation for both CPU architectures.
- The icon has no baked-in border or rounded tile. Metadata and tester
  instructions now identify build 8. Old archives move into an archive folder.

## Validation

- All 22 suites in `Scripts/run-beta-regressions.sh` passed. They cover gameplay,
  rewind/replay, rendering, styles, audio, sound banks, FLIC video decoding,
  sequel runtimes, campaign organisation, and bundled resources.
- DOS regression coverage includes 120 levels and 60,000 tick calls. This is
  a stability soak, not a proof that every campaign level is solvable.
- FLIC validation compares all 3,333 frames with an independent decoder.
- All five parser tests pass through `Scripts/run-swift-tests.sh`. The runner
  uses public manifest interfaces and explicit toolchain runtime/plugin paths.
  It works around this machine's incomplete Command Line Tools layout without
  changing the installed toolchain. The test target now uses Swift Testing.
- App integration groups pass on Apple silicon and under Rosetta for x86_64.
- All four Metal pipelines compile on the Apple M4 Pro.
- The playfield drawing suite passes its camera, menu, and panel pixel checks.
- Live UI checks on macOS 27 verified library → rating → briefing → gameplay,
  flat/monitor/television rendering, fullscreen exit, and return to the library.
  A CRT click changed the visible release rate from 50 to 51. The original
  flat-display preference was restored after the check.
- The live app loaded the existing profile with its five completed Lemmings
  levels intact. Automated settings checks use isolated fresh preferences and
  saved settings to exercise restoration.

Logs: `.build/beta8-integration.log`, `.build/beta8-integration-x86_64.log`,
`.build/beta8-regressions.log`, `.build/beta-regressions/`,
`.build/beta8-swift-test.log`, and `.build/beta8-slim.log`.

## Preview limits and validation boundaries

Lemmings 2 enables all campaign content as a native beta; full walkthrough
coverage and original-engine equivalence remain unverified. Lemmings 3 remains a preview without connected
audio or movie playback. NeoLemmix files have no gameplay sounds or rewind,
and fencer/laserer remain unsupported. Some fan-pack backgrounds and native
console campaigns remain unavailable. These are disclosed in the beta 8 notes;
this repair pass does not implement those unfinished features.

The available host runs macOS 27. Tahoe and a physical Intel Mac were not
available for live checks. Rosetta checks execute the Intel code path on this
host. Interruption checks suspend and resume real audio engines; they do not
replace listening tests with each tester's Bluetooth or USB audio hardware.

## About and Achievements follow-up

- Added the standard macOS About panel, with version and build read from the bundle.
- Replaced the achievement alert with a resizable trophy window, earned states,
  and an overall progress bar. Existing saved achievements remain intact.
- Corrected The Trilogy description to match the existing unlock rule.
- Rebuilt both architectures. Checked the About panel, saved achievement state,
  card layout, and scrolling in the running app on macOS 27.

## L2 campaign expansion

- All twelve tribes, 120 campaign levels, 51 skills and four practice maps are enabled.
- Native skill and object tests, all 120 startup and exit checks, and 64 recorded
  level completions pass. Replays use the app's pointer bounds and fan holds.
- The original intro, talisman award, ark movie and both ending paths pass.
- All 22 beta suites pass. L2 runtime and script tests also pass under Rosetta
  for the Intel build. All 106 eligible reduced-population replay checks pass.
- Twelve input schedules pass 5,445,815 ticks across all 120 levels and exercise
  every skill using the app's pointer bounds and fan resets.
- The universal app and final signed archive include the expansion.
- Earlier live L2 checks covered practice, navigation, introduction playback,
  walker artwork and talisman presentation. The last packaged app could not be
  relaunched for another live check while the Mac was locked.

## Xmas panel crash package verification

The current beta 8 package fixes an array overrun when the first-generation
panel drew thirteen buttons using twelve labels. Labels now follow button types.

- The regression reproduced a Swift index-out-of-range trap before the fix.
- The fixed Xmas panel passes at 640, 960 and 1920 points, with speed on and off.
- Xmas 1 with Macintosh artwork rendered successfully at tick 150.
- Panel drawing tests now run with the beta regression script.
- The universal app was rebuilt and reopened.
- Apple notarization accepted: `3b761b6c-804f-4cf0-944c-b35a1dfb59e3`.
- Stapling and the extracted ZIP's Gatekeeper check passed.
- SHA-256: `21cb6f0cae9c22c345bd0644c60b551db7bcab4049766495ea0d8527dd374f4a`.

Evidence: `.build/xmas-crash-before.log`, `.build/xmas-crash-fixed.log`,
`.build/xmas-panel-fixed.png`, and `.build/xmas-panel-package.log`.

## Previous L2 widescreen package verification

This beta 8 package removed both L2 window aspect locks, expanded the
playfield horizontally, and centres the original control panel. Cursor proximity
to any playfield edge scrolls the camera while the game window is active.

- Viewport tests pass for 4:3, widescreen, camera limits and edge velocity.
- Actual canvas checks pass for wide-area pointer mapping, centred panel clicks,
  ignored panel margins, resize clamping and image rendering.
- The universal app was rebuilt and reopened.
- Apple notarization accepted: `95e71130-dc3e-4f22-8ce1-5fb8a884bb71`.
- Stapling and the extracted ZIP's Gatekeeper check passed.
- SHA-256: `02ed4c52dc5fb939dee61b6a850a0719cb6fa2842b29a2455de2e03941f6cf15`.

Evidence: `.build/l2-widescreen-package.log`, `.build/l2-viewport-tests.log`,
`.build/l2-wide-canvas-tests.log`, and `.build/l2-widescreen.png`.

## Previous L2 tribe palette package verification

This beta 8 package corrected briefing cards and practice portraits to
use the shared INFO palette. All twelve tribe cards were rendered and inspected.

- L2 introduction, endings, ark, walker and award tests pass.
- The universal app was rebuilt and reopened.
- Apple notarization accepted: `e7042b77-f439-4a72-94fa-e252b7b488ce`.
- Stapling and the extracted ZIP's Gatekeeper check passed.
- SHA-256: `77f856b47ae494b491e74ede536c1544aba4e4d7d53484619b55e6988837abd1`.

Evidence: `.build/l2-card-palette-package.log`, `.build/l2-card-palette-tests.log`,
and `.build/l2-cards-corrected.png`.

## Previous liquid rendering package verification

This beta 8 package extended liquid colour below the animated surface,
stopping at terrain floors or the level bottom. Collision rules are unchanged.

- Scene regressions pass, including liquid bounds, floors, digging, and rewind.
- Macintosh pillar water, a raised pool, and CRT output were rendered and inspected.
- The universal app was rebuilt and reopened.
- Apple notarization accepted: `d5a53efc-408b-4265-8f9c-2d34d2e3ba00`.
- Stapling and the extracted ZIP's Gatekeeper check passed.
- SHA-256: `109df17679afb5a6b5bd24f8b830b99d17c59bed634409c8f120fbceb2afae18`.

Evidence: `.build/liquid-package.log`, `.build/liquid-scene-tests.log`,
`.build/liquid-mac-pillar.png`, `.build/liquid-mac-basin.png`, `.build/liquid-crt.png`.

## Previous speed button package verification

This beta 8 package added a 1×/3× speed button and F shortcut to the
first-generation player. Each new session resets speed to 1×.

- Panel drawing tests pass; DOS and Macintosh panels were rendered and inspected.
- The universal app was rebuilt and reopened.
- Apple notarization accepted: `22d4ce2c-5335-46b0-b846-377a960f89c4`.
- Stapling and the extracted ZIP's Gatekeeper check passed.
- SHA-256: `1c1a83e08569d1e17f2905d5241589e791a49c237f13fea4732b855aabf5f12b`.

Evidence: `.build/speed-button-package.log`, `.build/speed-panel-tests.log`,
`.build/speed-button-native.png`, and `.build/speed-button-mac.png`.
The full L2 suite results below belong to the preceding package.

## Previous L2 expansion package verification

- Archive: `.build/local/UltimateLemmings-0.1-beta8.zip` (418,250,698 bytes).
- App: `.build/local/Ultimate Lemmings.app`, version 0.1, build 8.
- arm64 and x86_64 slices are present. The Developer ID signature passes strict verification.
- Apple notarization accepted: `0ab0c1fc-d37e-4c1d-b905-503f62d9c024`.
- The ticket was stapled and independently passed `stapler validate`.
- The extracted, quarantined ZIP passed Gatekeeper as `Notarized Developer ID`.
- The signed app passed its bundled maps, UI, sound, music and artwork checks.
- SHA-256: `f4c7c07748e683baca33e078cba4f685139d20ac0239837ca822429989606f95`.

Evidence: `.build/l2-expansion-package.log`, `.build/l2-final-beta-regressions.log`,
`.build/l2-final-runtime-x86_64.log`, `.build/l2-final-intro-x86_64.log`,
`.build/l2-final-bundle.log` and `.build/l2-ui-population-check.log`.

## Previous package verification (before the L2 expansion)

- Final archive: `.build/local/UltimateLemmings-0.1-beta8.zip` (401 MB by `du -h`).
- Both arm64 and x86_64 slices declare macOS 13.0 as their minimum version.
- Developer ID signature verified successfully.
- Apple notarization accepted: `b6283220-1e49-4bc7-bbb8-c030e8c6e07f`.
- Ticket stapled and independently validated with `stapler validate`.
- The packaging script extracted the final zip, applied quarantine, and received
  Gatekeeper's `accepted source=Notarized Developer ID` verdict.
- SHA-256: `3a784b85db80b166229b79620ea1843613a7558d3bf87787a20507ad4e710678`.

See `.build/l2-stomper-package.log` for the signing, notarization, and archive checks.
