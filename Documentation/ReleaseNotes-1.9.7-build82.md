# Ultimate Lemmings 1.9.7 — Shared improvements, ghost solutions and controls

Build: 82
Release base: v1.9.6

This macOS update adds optional Classic ghost solutions, clearer controls and help, shared performance and save-recovery fixes, and broader bitmap lettering.

## Ghost solutions

Classic can overlay a recorded winning route as translucent blue lemming silhouettes. Enable **Ghost solution** after revealing the full solution. The overlay follows the current simulation tick through pause, speed changes and rewind. It leaves your terrain, skills and live attempt unchanged.

Same-owner retries retain the choice. A different level or Hot Seat player clears the revealed solution. Ghosts follow their recorded terrain, so they can pass through ground or cross bridges that your attempt has not changed. Lemmings 2 and Lemmings 3 retain their existing coaching and checkpoint flows. They do not offer ghost overlays.

## Controls, help and presentation

- Controller defaults use B for speed reset, pause and resume, X for speed reset, Y for end run or undo, and Menu for the game menu. Holding a speed boost does not skip the first reset to 1×.
- Keyboard help follows the active engine and control settings. The searchable command reference and in-game annotations make available actions easier to find.
- Closing sequel hints restores the previous pause state. An interruption keeps the game paused.
- Classic, The Tribes and Chronicles keep Hot Seat retries, restored runs and handovers paused until the player is ready. Sequel playfields identify the current player.
- Result help explains achievements and rescue goals. Shared result pages use clearer grouping and consistent bitmap lettering.
- Macintosh monochrome skill backpacks use distinct pixel patterns for Climber, Floater and both skills.
- Manual soundtrack shuffle follows the chosen music collection. Bomb countdowns use crisp digits above the lemming.
- If an incoming Classic journey music deck stops, the outgoing track recovers while gameplay remains paused.

## Shared performance and rewind

- Classic, The Tribes and Chronicles use the shared vinyl backspin for rewind music and captured sound effects. Rewind keeps gameplay paused and respects mute, volume and interruptions.
- Rendering adapts optional effects to available memory and sustained performance. Terrain caches and crowd limits reduce repeated work.
- Saved journeys exclude unsupported multiplayer levels while retaining compatible progress and ownership. Learning journeys preserve their existing route evidence.
- Background level preparation retains caller cancellation, including synchronous actor decoding.
- Manual shuffle can change music when the essential soundtrack contains only one version of the current theme.

## Saves and profiles

Matching profiles can recover newer shared progress, including saved Hot Seat journeys. Recovery preserves saved ownership and visited levels. Private library linking and recovery-key flows retain local saves. Live cross-device synchronisation remains a device-validation gap.

## Bitmap lettering and localisation groundwork

Classic menu fonts, the compact bitmap fallback, Lemmings 2 front-end and panel fonts, and Lemmings 3 lettering support accented Western Latin characters. Composed and combining forms render alike. The original glyph pixels and spacing remain intact.

Menus, controls, help and accessibility text use a shared localisation catalogue with English fallback and plural handling. **The shipped interface remains English. No translated language pack is enabled.** Other scripts, right-to-left layouts and text baked into original artwork require further work.

## Compatibility and release scope

The universal app supports Apple silicon and Intel on macOS 12.3 or later. The fresh-install download includes essential music and offers optional soundtrack libraries. Automatic updates retain the full soundtrack.

Classic and The Tribes remain Complete. Chronicles and NeoLemmix remain Beta. This release publishes macOS only. iPhone, iPad and Apple TV work follows separate 2.0 release gates.

## Validation scope

The release uses a frozen source checkout, a universal optimised build, focused shared regressions, preserved winning-route manifests, and muted offscreen native UI checks. Distribution evidence records signing, notarisation, Gatekeeper, archive integrity and the signed Sparkle update feed.

Physical controller and VoiceOver journeys, audible listening, foreground shipping-app launch, minimum-OS and Intel hardware, HDR appearance and live cross-device synchronisation remain manual validation gaps. A minor audit preserves campaign evidence rather than claiming a fresh replay of every campaign.
