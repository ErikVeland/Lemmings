# Ultimate Lemmings 1.5 (build 45)

Build: 45
Release commit: 0b0b8fd5e85d617cd68b48308bc8e585306a11c4
Release base: v1.2-build41

## Fixes since the 1.2 build 41 public release

- Fix first-launch and level-browser paths that could show a blank window or
  close the app.
- Defer startup HDR work until an effect needs it.
- Present the first frame before level music starts.
- Keep level music stable during ordinary play and change the mix only when
  the game state changes.
- Keep the drawn four-corner gameplay reticule precise at every zoom level.
- Hide the macOS pointer only over gameplay. Keep the system arrow over menus
  and controls.
- Apply cursor preferences, skill badges and lemming-count behaviour across
  Classic, Lemmings 2 and Lemmings 3.
- Preserve input release, retry, pause and fresh-level transitions without
  leaving held controls active.

## Release scope

This macOS release candidate contains the completed Classic campaign and the
current Lemmings 2 and Lemmings 3 preview engines. NeoLemmix import remains a
Beta or Preview capability. It does not claim full NeoLemmix replay or
behaviour compatibility.

The Developer ID and macOS 12 Monterey archives require fresh signing,
notarisation and Gatekeeper evidence. The Game Center archive is a separate
development-signed build for registered Macs.

## Validation boundary

The source gate, cursor geometry tests, pointer-capture tests, input tests,
release-input checks and deterministic Classic evidence must pass against this
commit. Physical Intel, minimum-macOS, audio, thermal, VoiceOver and live
Sparkle update checks remain separate release evidence.
