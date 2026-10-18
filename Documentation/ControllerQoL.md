# Controller QoL

Controller actions share the keyboard command handlers in Classic, Lemmings 2 and Lemmings 3.
Button names below follow the Xbox layout; PlayStation uses the corresponding
button positions.

| Controller | Action |
| --- | --- |
| Left stick / right stick | Aim / pan camera |
| A / B | Assign selected skill / reset fast speed, then pause or play |
| X / Y | Reset speed / nuke or undo where supported |
| LB / RB | Previous / next available skill |
| D-pad left / right | Previous / next unassigned lemming |
| D-pad up / down | Increase / decrease release rate where supported. Hold to repeat, with the same timing as the on-screen rate button |
| Tap RT / hold RT | Toggle fast-forward / temporary speed boost |
| Menu | Game menu |
| View / Options | Show keyboard and controller help |

The defaults include fast-forward toggles, temporary held boosts, quick exits, skill cycling,
unassigned and last-assigned focus, repeat assignment, entrance/exit focus, hints, settings and retry.
Rewind and backward stepping remain limited to engines with history support. Classic, Lemmings 2 and Lemmings 3 support forward stepping.
Unsupported engine actions do not mutate the game.
During gameplay, ⌘Z rewinds one simulation tick and pauses the run in Classic,
NeoLemmix, Lemmings 2 and Lemmings 3. Each press steps once. Text fields retain
normal undo. Controls help lists the shortcut.

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

## Step controls

Hold LT + LB / RB on Mac and iOS, or Create / View + L1 / R1 on TV, to step
one tick back or forward. Keep both buttons down to scrub: after 0.18 s the
step repeats 15 times a second, like the held `,` and `.` keys. Release either
button to stop. The run stays paused. A stalled frame catches up four ticks at
most. In menus the shoulder buttons change tabs and do not repeat.

On a DualSense or DualShock 4, slide a finger left or right on the touchpad to
step back or forward. One slide across the pad moves 16 ticks. A touchpad click
still starts a DJ shuffle and never steps. Lifting the finger, a menu or a new
touch far from the last one starts a new slide.

Each step plays a short haptic tick on controllers with haptics. A backward
step is softer than a forward step. Fast scrubbing plays one tick each 30 ms.
`LEMMINGS_TEST_AUDIO=muted` also silences these ticks.

The shared logic is `ControllerBindings` (held repeat), `TouchpadJog` and
`ControllerStepFeedback`. Classic, Lemmings 2 and Lemmings 3 use their existing
step handlers, so engine limits for backward steps are unchanged. Known limits:
the haptic ticks have no separate setting, and touchpad travel, haptic strength
and held scrubbing need physical controller validation.

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

During play, − and + step the release rate. A double tap moves it to the
minimum or the maximum. A held key still steps one at a time. N starts the nuke,
and a second N undoes it while undo is still possible. Outside play, N in Classic
still opens the next level. L2 has no release rate, and L3 has no release rate or nuke.

Help > Keyboard commands (Command-?) opens a searchable command reference.
During gameplay, ? opens the same guide. Categories cover skills, speed, camera,
menus and results, app menu shortcuts, and the current controller mapping. Skill
rows use the current level, including direct letter aliases and shared initials.
The guide pauses play, supports text search and category filtering, and links to
level hints. Escape closes it and restores the prior pause state.

During a live level, ? and Help > Keyboard commands now show annotations over
the paused game. Number, pause, speed and release-rate badges align with the
actual controls. Closing the overlay restores the previous pause state. All
commands opens the searchable reference, and Level hints opens the current
hint page. Outside gameplay, the command reference opens directly.


Hot Seat handovers and retries wait for the player across all three games. L2's
briefing also identifies the incoming player, and its forward-step command handles
completion through the normal results path. L3's in-game Resume action resumes
the existing attempt directly. See [cross-game parity](ReleaseReadiness/CrossGameParity.md)
for shared behaviour, engine-specific limits and validation status.

## TV precision and transport

Circle / B is the default pause/play button across Mac, iOS and TV. Square / X
resets speed. Triangle / Y nukes or undoes the nuke where supported. Menu opens
the game menu. On Mac and iOS, Play/Pause first resets fast speed and leaves play
running. Release and press again to pause. R2 also consumes a fast-speed press
as a reset. Its release cannot restore the previous fast speed.

On TV, Circle toggles planning pause/play immediately, including at fast speed.
It resets speed when pausing and does not open the pause menu. Menu opens the
pause menu. Circle uses normal Back navigation on menu pages. The native tvOS
Back event for a gameplay Circle press is consumed with its release so UIKit
cannot also open a menu.

R2 uses the shared fast-forward pedal: tap toggles fast speed; hold ramps speed;
release restores the selected speed. A press during planning resumes play.
A fast-speed press resets to 1× while play continues. R2 never parks or steps the
timeline and cannot bypass Ready, handover, interruption or result pages.
DualSense resistance follows the active speed tier and respects the saved
adaptive-trigger preference. Physical resistance still needs device validation.

L2 retains tap-to-step-back and held rewind. At fast speed, L2 first resets to
1× and requires release before rewinding. R2 stops held rewind before forward
play. Held L2 cannot restart rewind until both triggers return to neutral.

TV draws an aim reticle independently of the skill badge. It can move through
the playfield and HUD. Cross / A uses the same visible HUD button bounds to
select a skill or activate a control. Precision picks retain the displayed
eligible actor while it remains under the pointer. They do not prefer a moving
neighbour merely because its direction changes. Deliberate actor cycling keeps
its ID lock. A missing locked actor cannot silently select another actor.

Settings is directly available on the shared mobile/TV pause page. Its
soundtrack-library and Play Insights pages retain the paused attempt. Mac keeps
its in-game Settings command. Classic, L2 and L3 share these input paths. L2/L3
have no release-rate controls, and L3 has no nuke.

Muted, offscreen validation and physical-device limits are recorded in
[the playtester follow-up](PlaytesterControls.md).
