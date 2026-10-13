# iOS Hot Seat player identity — 13 October 2026

Hot Seat now shows `Hot Seat: <player>` in green bitmap lettering above the
HUD counters. The opaque strip keeps identity clear of terrain, music notices,
touch targeting and controls. The name comes from the attempt owner, including
restored runs. Solo play has no identity row. VoiceOver gets `Current player:
<name>`. Ready handovers retain their existing paused boundary.

The shared HUD renderer supplies both drawing and the accessible identity frame.
Compact layouts reserve 44 points for the two rows only during Hot Seat.
Portrait, landscape and original-panel layouts use their existing status strip.

Validation:

- All 32 windowless, muted renders and input-target checks pass. Eight layouts
  cover solo, host, guest and paused guest. They include narrow phones, iPad,
  the compact fallback, a display division and a playfield occlusion.
- Identity and counters do not overlap controls. Identity stays inside the safe
  area and outside gameplay and reserved regions. Targets remain at least
  44 points, distinct and reachable, including scrolling skills.
- The 32 status strips and full phone, compact and panel captures were inspected.
- All 24 existing tests pass in `MobileHotSeatTests`, `MobilePortraitHUDTests`
  and `MobileAdaptiveLayoutTests`.
- The unsigned arm64 Debug iOS target compiles with `CODE_SIGNING_ALLOWED=NO`.

[Capture geometry](captures.json), [validation record](validation.json) and
[all status states](status-overview.png) retain the evidence.

Reproduce the rendering check after building `LemmingsMobileMenuAudit`:

```sh
LEMMINGS_TEST_WINDOWS=offscreen LEMMINGS_TEST_AUDIO=muted \
  .build/hot-seat-swift/debug/LemmingsMobileMenuAudit \
  .build/mac-artwork/export/lemmings \
  .build/ios-beta/2.0-9-parity-final/BetaGameData \
  .build/hot-seat-hud --hot-seat-hud
```

This tool only creates Core Graphics bitmaps. It has no app or test windows.
Native UI tests continue to use `Tools/UITestRunner/run.py`.

The Mac Classic, L2 and L3 paths already use the attempt owner's identity.
The iOS controller and HUD are shared, but player-facing L2/L3 mobile engines
remain unavailable. This check does not claim sequel device acceptance.
Physical UIKit input and VoiceOver still need device validation.
