# Controller QoL

Controller actions share the keyboard command handlers in Classic, Lemmings 2 and Lemmings 3.
See the [binding table](../README.md#controller-controls) for the complete layout.

The defaults include fast-forward toggles, temporary held boosts, quick exits, skill cycling,
unassigned and last-assigned focus, repeat assignment, entrance/exit focus, hints, settings and retry.
Rewind and backward stepping remain limited to engines with history support. Lemmings 3 also supports forward stepping.
Unsupported engine actions do not mutate the game.

**Settings > Controller** controls gamepad support, trigger taps and stick layout.
Preferences persist, follow the modern/OG presets and survive changes to machine artwork or sound presets.
Existing saved OG settings keep controller support off during migration.

The controller can navigate hint pages, settings and controls-help sheets.
The selection has a green outline. D-pad up/down selects controls; left/right adjusts sliders and lists.
LB/RB changes settings tabs. A activates the selection and B returns. The right stick scrolls long help text.
The LT modifier does not turn menu navigation into gameplay commands.

Input is limited to the active app and the window's owning engine. Changing windows, reconnecting a gamepad,
or entering a different page clears button history. A button held during that transition must be released before it can act.
The first page selection is the back/default control. Hint details still require an explicit new press.

## Validation

- `Scripts/run-controller-qol-tests.sh` runs the pure button and trigger tests without requiring SwiftPM.
- `Scripts/run-gameplay-speed-tests.sh` checks shared speed behaviour, including keyboard regressions.
- `TEST_SCOPE=controller Scripts/run-app-integration-tests.sh` drives the production controller dispatch with simulated button frames.
  It checks toggle/hold/rapid exits, legacy speed reset, disconnect/reconnect, ownership, hint tiers, help sheets and settings controls.
- Classic settings checks cover defaults, persistence, migration and OG/modern resets.
- Sequel app checks cover the attached-window command handlers and presentation state.

**Settings > Gameplay > Pause** also covers controller disconnection. If a controller has been used,
disconnecting it pauses the level and clears held speed input. An unused controller does not pause keyboard play.
Returning to the app or reconnecting does not resume automatically. Closing hints, help or a replay retains an interruption pause.

The automated checks simulate controller input. They do not certify individual physical controller models or Bluetooth connections.

## Button remapping

**Settings → Controller → Remap buttons** lets players select a physical button and its gameplay action.
Conflicting choices swap, so every action stays reachable. Modifier combinations follow the remapped buttons.
Mappings persist across launches and machine presets. **Reset button mappings** restores defaults.
Experience presets also reset mappings. Menu navigation always uses the standard buttons so players can return to Settings.
Changing mappings or moving between gameplay and menus clears held input.

The remapping list uses the connected controller's reported button names and SF Symbols.
Controls help uses the current mapping and device names. Standard Xbox-style names are the fallback when no device is connected.
Physical Xbox, PlayStation and Switch-layout journeys remain to be tested.

## Menu parity and accessibility

Controls help follows the current engine and preferences. OG mode omits modern skill and focus shortcuts;
controller support, trigger taps, variable speed, hints and history actions appear only when available.
The L2 and L3 playfields show the active Hot Seat attempt owner's portrait and initials. The badge changes
when the next attempt starts, and disappears outside Hot Seat.

**Settings > Accessibility > Text and menu size** offers 100%, 125% and 150%. It enlarges shared menu pages
(settings, hints, profiles, records and dialogs) and controls-help text. Enlarged pages scroll so their controls
remain reachable. The choice persists and experience presets preserve it. Original engine artwork and live
playfields retain their existing scale controls.

VoiceOver can navigate the individual controls in drawn Classic menus and panels, L2 front-end pages and
panels, L3 menus and direction controls, and Arcade profile/result/record pages. Profile initials are editable
through accessibility. The CRT view exposes the same Classic controls. Tab and Shift-Tab also select Arcade
buttons, with Return or Space to activate. This adds menu navigation; it does not provide a complete spoken
representation of terrain or moving lemmings.

Automated coverage checks conditional help, size persistence and migration, scrollable pages, accessible
actions and initials editing, and sequel badge ownership across handoff and solo play. Controller validation
uses standard extended-gamepad button frames and remapped actions. No physical controller was available;
model-specific button labels, Bluetooth behavior and hands-on comfort remain unverified. A full VoiceOver
listening journey also remains a manual release check.


From gameplay, **Escape** now saves the active run and returns directly to the main
menu in Classic, fan levels, NeoLemmix, L2 and L3. It also cancels fast-forward,
including a held boost. Repeated key-down events do not cause further navigation.
Use **F** or controller **B** to cancel fast-forward while staying in the level.
Escape inside an open dialog or help page retains that page's normal Back action.

Text and menu size uses a fixed base size in points: 100% no longer grows to fill
a large window. 125% and 150% enlarge that base size. Small windows fit the base
layout, and enlarged pages scroll when needed. Retina rendering does not add
another UI size multiplier.

Xmas 1991/1992 and Holiday 1993/1994 retain their seasonal soundtrack when
shuffle or DJ mode is enabled. Regular DJ and shuffle pools exclude tracks
labelled Holiday, Xmas or Christmas, including the L2 DJ pool. Leaving a seasonal
campaign refreshes the module library, including when entering a fan level.
Silence and mute remain available. A manually chosen soundtrack in a regular
campaign remains an explicit override.

Help > Keyboard commands (Command-?) opens a searchable command reference.
During gameplay, ? opens the same guide. Categories cover skills, speed, camera,
menus and results, app menu shortcuts, and the current controller mapping. Skill
rows use the current level, including direct letter aliases and shared initials.
The guide pauses play, supports text search and category filtering, and links to
level hints. Escape closes it and restores the prior pause state.
