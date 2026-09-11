# Ultimate Lemmings — beta 13

Version 0.1, build 13. Universal Mac app for Intel and Apple silicon, macOS 13 or later.

## Changes since beta 12

### Take turns on the same level

- Shared sessions let two or more existing profiles alternate attempts. Open **Shared Session…** from the app menu, **Shared session** in Player Profiles, or **Players** on a result page.
- **Retry as [initials]** starts the same level for the next player. **Retry** keeps the current player. Turn order wraps through the selected profiles.
- Campaign progress stays with the host. Each attempt keeps its own player, scores, records and arcade achievements. Guests do not inherit the host's campaign saves.
- The roster lasts until the app closes, the host changes, or **Play solo** is selected. Add new profiles through Player Profiles first.

### Save recovery and controls

- Classic campaigns, NeoLemmix files and native Lemmings 2 and 3 campaigns now save in-progress checkpoints. Use **File → Resume Saved Run** to restore the latest run for the current player. Restored games stay paused and retain their attempt identity.
- Checkpoints validate the engine, original level data and replayed state. Atomic writes, backups, file-size limits and stale-writer checks protect saved runs. External NeoLemmix files and styles must remain available.
- Arcade records have validated backups and a retry action for temporary save failures. Legacy preferences and supported campaign saves migrate into the unified app without replacing newer values.
- Controller buttons can be remapped. Conflicting bindings swap, device names and glyphs follow the connected controller, and interruptions clear held input.
- Rewind and replay fixes preserve commands at tick boundaries, branch changes and queued actions.

### Presentation, hints and audio

- Level tips use the game font. Original-campaign tips remain divided into three revealable tiers.
- Player and leaderboard row text is vertically centred. Achievement names and run-detail labels use green lettering; supporting text and values remain blue.
- CRT/menu rendering, bitmap text, directional speed trails and explosion presentation have been refined.
- **Reduce added motion** and **Reduce added flashes** control added effects without disabling modern controls or changing game speed. Original game artwork can still contain flashes.
- Replay audio uses less temporary memory and avoids unnecessary mixing during silence. Recorded video retains every simulation frame.
- Adaptive DJ fade timing handles delayed callbacks and audio suspension more consistently.
- Opening a compatible NeoLemmix file now correctly enters the playing interface.

## Tester focus

1. Upgrade from beta 12. Check existing profiles, progress, records, achievements, settings and manual L2 save slots.
2. Create two or three profiles and start a shared session. Alternate failed and successful attempts in Classic, NeoLemmix, L2 and L3. Verify the same starting level, turn order, separate records, ordinary Retry and Play solo.
3. Pause or close a supported run, relaunch and use Resume Saved Run with the correct player selected. Check camera, selected action, nuke undo where supported and continued play. Recovered runs do not restore the previous movie recording.
4. Check player rows, career leaderboards, achievements, run details and hints at different window sizes and in Flat, Monitor and Television modes.
5. Remap controller buttons, disconnect during play and reconnect. Check that held speed input clears and play remains paused after an interruption.
6. Exercise music changes, mute, replays, repeated engine switches and longer sessions. Record frame stalls and audio interruptions, especially at 10× speed.

Report the game, rank and level, player, Mac model, macOS version, display mode and exact steps. Preserve a replay or movie where available.

## Known limits

- This is a test beta, not a 1.0 release. The original DOS campaign has 120 verified winning routes. Another 214 core campaign routes remain unverified, plus conversion gaps. Missing evidence does not prove those levels are broken.
- L2 and L3 fidelity work remains. L3 environmental effects, original movie soundtracks and story transitions are not complete. NeoLemmix compatibility is partial.
- Checkpoints do not cover classic fan imports or L2 practice. Installed-release migration and physical power-loss trials remain open. Changed engines or source assets can prevent checkpoint restoration.
- Sustained 10× performance is not established. Recent short local samples with replay recording reached about 6.8–8.7× when 10× was requested. Hardware, audio, accessibility and physical-controller validation remain incomplete.
- This Developer ID build uses local records with Game Center disabled. Online-service validation remains separate.
- The package is for private testing under the project's game-data policy. It does not establish rights-holder approval for public distribution.

See [Shared sessions](SharedSessions.md), [Save recovery](SaveRecovery.md) and the repository's release gate register for details.
