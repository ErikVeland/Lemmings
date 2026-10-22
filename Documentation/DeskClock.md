# Desk Clock

Status: source implementation added on 22 October 2026. Signed builds and device checks remain open.
Target release: tonight's 2.2 Duo update, including the iOS and Mac widgets.
The owner's latest instruction replaces the earlier 2.2.x scope decision.
See the [current check record](ReleaseReadiness/2.2DuoPolish-2026-10-22.md).

Prototype: [Tent Clock artifact](https://claude.ai/artifact/XvvA8foJYF5WLBMR3kLArH), version 3.
The prototype is a web sketch. It is the reference for look and behavior, not for code.

## Intent

The Desk Clock turns an idle phone into a Lemmings ornament. The owner wants
it on the desk while they work. It shows the time and the next calendar event.
The joy comes from the lemmings: they rebuild the clock digits by hand every
minute, and a blocker holds the exit shut until the next meeting starts.

The feature started as a "tent pose" idea for the iPhone Duo. iOS 27.2 has no
API that reports a tent pose or a hinge angle. The app can detect only the
reserved regions (division and occlusion) and the navigation rail edge. The
clock therefore opens from triggers the app can detect, and from a widget.

## Goals

- Show the time as terrain digits that lemmings rebuild each minute.
- Show the next calendar event and a countdown to it.
- Open the clock four ways: Stacked pose when idle, closed and charging, a menu entry, and a widget.
- Work on every iPhone and iPad. The Duo poses add the automatic triggers.
- Give the Mac a desktop widget (owner decision, 22 October 2026).
- Use the shipped Macintosh artwork for all sprites, terrain, objects and text.

## Non-goals

- Gameplay. Lemmings in the clock take no player input.
- A tent pose or a back face. No API can detect them.
- Lemmings 2 and Lemmings 3 art. Version 1 uses Classic Macintosh art only. Record this as a known limit.
- Apple TV, and a clock screen in the Mac app. Record these as not supported in version 1. The Mac gets the widget only.
- Calendar editing. The clock only reads events.

## Anti-goals

These make the feature a failure even if it works:

- The clock opens while a level runs, during a Hot Seat handover, or over a pause menu.
- The clock plays music or sound effects.
- The clock keeps the screen awake on battery.
- The clock asks for calendar access before the player opens it.
- The art does not match the shipped Macintosh frames.
- Explanatory text that repeats what the picture shows (see `UIPrinciples.md`).

## Behavior

### The scene

The scene uses classic simulation pixels. Mac artwork draws two pixels for each
classic pixel. The scene is 208 × 149 classic pixels and scales to fit the
available pane with integer scaling where possible.

| Element | Source |
| --- | --- |
| Lemming poses | Bank 1400, through `ClassicMacArtwork.lemming(pose:left:tick:)` |
| Foot offsets | The classic animation offsets in `ClassicMainDAT` |
| Trapdoor | Bank 1600, style 0, object 1. Frames 1–9 open the doors. Frame 0 rests open. |
| Exit | Bank 1600 frame 16 (arch). Frames 10–15 are the animated top, 6 classic pixels above the arch origin. |
| Digit terrain | Texture from bank 1500 piece 10 (dirt rock) |
| Ground | Bank 1500 piece 3 (flat slab), alternately mirrored. Grass from pieces 9 and 36–39. |
| Text | Charset1 for small text, Charset2 for the event title |

The scene keeps the prototype layout: trapdoor at the top left, four digits
with a colon, event text under the digits, ground with the exit at the right.
The panel line on the ground shows `OUT n`, `IN n` and the date.

### The lemmings

- Each digit is 5 × 7 terrain blocks. Lemmings walk on the digit tops with the
  classic rules: step up at most 6 pixels, step down at most 3, else fall.
- A falling lemming opens an umbrella after 26 pixels. No lemming splats.
- The trapdoor releases one lemming every 7 seconds while fewer than 6 walk.
- A lemming that reaches the exit plays the exiting animation and adds 1 to `IN`.
- One worker comes to each digit that changes at the next minute. It floats
  down, digs the old blocks from the top, then builds the new blocks from the bottom.
- Each worker starts early, so its last block lands at the exact start of the
  minute. It holds that last block until the minute starts. The digits never show the next minute early.
- At the top of the hour, all four digits change at the same time.
- After a time jump (the app returns from the background, or the clock changes),
  the digits change at once, without workers.
- In 12-hour time, a blank leading digit has no blocks. The format follows the system locale.

### The next event

- The text shows `NEXT` with the start time, the event title, and a countdown.
- The countdown counts whole clock minutes: the event's minute minus the current
  minute. It changes on the same frame as the digits.
- Ten minutes before the event, a blocker floats down in front of the exit. The countdown blinks amber.
- When the event starts, the blocker walks out, 10 lemmings leave the trapdoor
  quickly, and the countdown shows `LET'S GO!`. This state lasts 2 minutes.
- The clock skips all-day events and declined events. It shows the next event within 24 hours.
- With no access or no event, the event text is absent. The clock still runs.

### The nuke

One event in three starts with a nuke instead of a parade. The choice is stable
for each event: a hash of the event identifier and its start time. The owner asked
for "every third event or so".

- Six seconds before the start, every lemming on screen gets a fuse, except the workers.
  The workers keep the clock correct.
- Each lemming shows 5 to 1 over its head in Charset1, one number each second.
  The fuses are 80 ms apart, as in the game's own nuke.
- In the last second, each lemming plays "Oh no!" (bank 1400 frames 337–352).
- At the start, each lemming explodes: frame 75 for 0.2 seconds, debris, and a
  hole in the digits. The blast removes each digit block whose center is inside an
  ellipse 3 classic pixels above the feet. The ellipse has a horizontal radius of
  10 and a vertical radius of 13 classic pixels. The blocker explodes too. The ground stays.
- Builders repair the holes at once. The parade waits 1.6 seconds for the smoke to clear.
- The trapdoor releases no lemmings from the fuse until 1.5 seconds after the blast.
- The nuke is silent, like the rest of the clock.
- With Reduce Motion or Reduce flashes on, the event starts with the parade instead.

### Triggers

| Trigger | Condition | Exit |
| --- | --- | --- |
| Stacked, idle | A horizontal division is present (`MobileDisplayRegions.tablePanes` returns two panes). The app shows Home. No input for 60 seconds. | Any touch on either pane, controller B or Menu, Escape, or a pose change |
| Closed, charging | Duo only. The device is closed (no division), the battery state is charging or full, and the app is idle on Home for 60 seconds | Any touch, controller B or Menu, Escape, or the charger is removed |
| Menu entry | The player picks Desk Clock from Home | Close, controller B or Menu, or Escape. A touch or controller A shows the close control. |
| Widget | The player adds the widget to the Home Screen, Lock Screen or StandBy | Tap opens the app on the Desk Clock |

In Stacked pose, the clock fills the top pane and shows the next event. The
bottom pane shows only the close control. The idle triggers fire only on Home.
They never fire on another menu page, during a level, a replay, a pause menu,
a Hot Seat handover, or any modal sheet.

The automatic triggers apply to the Duo only. `DeskClockTrigger` takes a
"foldable" input from the presence of inactive division regions
(`reservedRegions(kind:options:)` with `.includeInactive`). Other iPhones and
iPads use the menu entry and the widget. The app cannot start itself when the
phone starts to charge. StandBy covers that case through the widget.

### Screen and power

- The clock disables the idle timer only while the device charges.
- On battery, the system can lock the screen as usual.
- Every 3 minutes, the whole scene moves by up to 2 points to reduce OLED burn-in.
- Between 22:00 and 07:00 local time, the clock dims the scene, the same as the prototype Night state.
- Reduce Motion: the digits change at once, no worker comes, and at most 2 lemmings walk.
- The clock pauses menu music while it shows, and plays no sound.

### The widget

- A WidgetKit extension in the iOS app. Families: small, medium and large on the
  Home Screen, small in StandBy, and rectangular on the Lock Screen.
- A WidgetKit extension in the Mac app, from the same source. Families: small,
  medium and large on the desktop and in Notification Center. A tap opens the Mac app.
- WidgetKit cannot animate. Each timeline entry is one still frame for one minute:
  the digits, the trapdoor, the exit, and one lemming in a pose chosen from the minute.
  In the start minute of a nuke event, that lemming is in the "Oh no!" pose.
- The timeline holds 60 entries and asks for a new timeline after them.
- The Lock Screen family shows the time and the next event in Charset1 only.
- The small family enlarges the terrain digits and uses compact countdowns to keep labels legible.
- The extension bundles a pruned copy of `MacArtwork/lemmings` with only the frames
  the clock uses. The copy keeps the manifest format, so `ClassicMacArtwork` loads
  it in the same way as the app. Calendar reads use EventKit in the extension.

### Calendar permission

- The app asks for full calendar access when the player opens the Desk Clock from
  the menu entry or from a widget tap. It asks only while Show next event is on and
  iOS has no answer from the player. iOS shows the prompt only once.
- After the player answers, the app reloads the widget timelines, so the widgets show the event at once.
- An automatic trigger never asks. Until the player grants access, a clock that
  opened by itself and the widget show no event text.
- The minimum iOS version stays 16.0. On iOS 17 and later, use
  `requestFullAccessToEvents` and `NSCalendarsFullAccessUsageDescription`. On iOS 16,
  use `requestAccess(to: .event)` and `NSCalendarsUsageDescription`. Both keys go in `Info.plist`.
- StandBy and the iOS 17 widget families have availability gates. iOS 16 gets the Home and Lock Screen families only.
- If the player denies access, the clock never asks again. Settings shows the state and a link to iOS Settings.

### Settings

A Desk Clock section in Settings, built with the existing settings pages:

- Open in Stacked pose when idle (default on, shown on Duo only)
- Open when closed and charging (default on, shown on Duo only)
- Show next event (default on, controls the calendar request)

### Accessibility

- VoiceOver reads the clock as one element: the time, then the next event and countdown.
- The close control has a label and a 44-point target.
- Bitmap text has the same string as an accessibility label.

## Architecture

Follow the existing split. Keep simulation logic free of UIKit so tests run headless.

| Part | Module | Notes |
| --- | --- | --- |
| `DeskClockSimulation` | LemmingsMobileCore | Terrain mask, digit glyphs, workers, walkers, event phase. Takes an injected clock and seed. |
| `DeskClockEventSource` | LemmingsMobileCore | Protocol for the next event. Tests use a stub. |
| `DeskClockTrigger` | LemmingsMobileCore | Pure decision from regions, idle time, battery state, screen and settings |
| `GameDeskClockArt` | LemmingsGameArt | Loads frames through `ClassicMacArtwork`, like `GameUnfoldArt`. Draws one state into a `CGContext`. |
| `MobileDeskClockView` | LemmingsMobileUI | Display-link view. Reuses the HUD and stone controls for the close control. |
| EventKit adapter | LemmingsMobileUI | Implements `DeskClockEventSource` |
| Widget extension | `Apps/UltimateLemmingsIOS` | New target, uses `GameDeskClockArt` to render still frames |
| Mac widget extension | `Apps/DeskClockWidget/Mac` | Same widget source. `Scripts/build-desk-clock-mac-widget.sh` compiles it with `swiftc` against the Mac app's modules, copies it into the Mac app's `Contents/PlugIns` and signs it before the app. |

The app and the widget draw with the same `GameDeskClockArt` code, so the art stays the same in both.

## Verification

- Unit tests for `DeskClockSimulation`: digit diffs, worker order, walker steps,
  exit count, event phases, 12-hour and 24-hour strings, and the hour rollover.
- Unit tests for `DeskClockTrigger`: every row of the trigger table, and every blocked state.
- Add the Desk Clock to `Tools/IOSMenuAudit/duo.swift` in stacked, compact-stacked,
  closed-landscape and closed-portrait poses. Inspect one render for each.
- Add a native UI test through `Tools/UITestRunner/run.py`, offscreen and muted.
- Render each widget family in the Simulator. Inspect the renders.
- Add the Desk Clock rows to the Duo coverage matrix.

## Known limits

- No physical Duo test. Pose triggers have Simulator evidence only.
- Lemmings 2 and Lemmings 3 art is not in version 1.
- The widget shows still frames. Only the app animates.
- On Mac, a widget cannot ask for calendar access. The Mac app asks from one menu item. The hardened runtime blocks EventKit without the `com.apple.security.personal-information.calendars` entitlement, so every Mac release signature includes it (`Resources/UltimateLemmings.entitlements`). Whether macOS shares that access with the extension needs a device check.
- Calendar access in the widget extension needs a check on a device.

## Release decision

The owner included the clock and both widgets in tonight's 2.2 release on
22 October 2026. The new extension targets, calendar permission and signing
checks are therefore part of this candidate's acceptance gates. The
[current check record](ReleaseReadiness/2.2DuoPolish-2026-10-22.md) separates
source verification from signed builds and device acceptance.

## Calls made for the owner to check

These are my calls, not decisions the owner made:

- The trigger delay is 60 seconds of no input.
- The night dim runs from 22:00 to 07:00.
- The clock pauses menu music.
- The clock shows events in the next 24 hours only, and skips all-day and declined events.
- The widget bundles a pruned copy of the Mac artwork instead of reading the app's artwork through an app group.
- The automatic triggers apply to the Duo only. You asked for the widget to serve other phones.
- Only the menu entry and a widget tap ask for calendar access. An unattended clock never shows the prompt.
- The minimum iOS version stays 16.0, with availability gates for the iOS 17 features.
- One event in three is a nuke, chosen by a stable hash, not by counting. A count would change when an event moves or the app restarts.
