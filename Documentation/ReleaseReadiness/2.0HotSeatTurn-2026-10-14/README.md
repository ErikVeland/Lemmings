# Explicit turn label during iOS play

14 October 2026. The gameplay HUD now says **TURN: ERI** or **TURN: UVA**.
The earlier name-only label did not make the current turn clear enough.
The green bitmap line uses the existing identity row above the counters.
It adds no input target and covers no terrain. VoiceOver says “Current turn”
with the full player name. Ready and selection pages keep their distinct
next-player wording. Pause and results retain the named states verified in the
[flow evidence](../2.0HotSeatFlow-2026-10-13/README.md).

All **32 windowless, muted render and input-target checks pass**, including
portrait, landscape, narrow, compact, iPad, divided and occluded layouts.
The audit checks that the complete caption fits, stays clear of gameplay,
counters and controls, and that every control remains reachable. The complete
status montage and representative full screens were inspected. The unsigned
arm64 iOS Debug build also passes.

The renderer is shared across iOS session adapters. Playable L2/L3 campaigns
remain unavailable in the iOS library. Physical UIKit and VoiceOver checks
still require device testing. This evidence describes source validation,
not installation on the user's device.

![Gameplay](iphone-portrait-guest.png)

[All status states](status-overview.png), [capture inventory](captures.json),
and [validation and source hashes](validation.json).
