# Controller QoL

Controller actions share the keyboard command handlers in Classic, Lemmings 2 and Lemmings 3.
See the [binding table](../README.md#controller-controls) for the complete layout.

The defaults include variable-speed taps, temporary held boosts, quick exits, skill cycling,
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
  It checks tap/hold/rapid exits, legacy speed reset, disconnect/reconnect, ownership, hint tiers, help sheets and settings controls.
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
