# Ultimate Lemmings 1.5 (build 45)

Build: 45
Release base: v1.2-build41

## Fixes since build 38

The public 1.2 builds already delivered these fixes:

- Build 39 added the level browser and the first cursor corrections.
- Build 40 started automatic update checks when the app launched.
- Build 41 fixed the black window and menu-action crash on a new installation.
- Build 41 restored rescue targets and Classic hints. It also fixed selection
  at the visible edge of a level-browser card.
- Build 41 kept the opening music track when a level started and fixed the
  Game Center variant's launch signature.

The 1.5 candidate adds these changes after build 41:

- Defer startup HDR work until an effect needs it.
- Present the first frame before level music starts.
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
notarisation and Gatekeeper checks. The Game Center archive is a separate
development-signed build for registered Macs.

## Validation boundary

The source gate, cursor geometry tests, pointer-capture tests, input tests,
release-input checks and deterministic Classic evidence must pass against the
frozen commit. Physical Intel, minimum-macOS, audio, thermal, VoiceOver and
live Sparkle update checks remain separate release evidence.
