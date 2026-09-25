# Ultimate Lemmings 1.5 (build 47)

[Download the Mac app](https://github.com/ErikVeland/Lemmings/releases/download/v1.5.0/UltimateLemmings-1.5-build47.zip)

Build: 47
Release base: v1.2-build41

These notes list all changes since 1.1 RC1 (build 37). Builds 38 to 41 were
public test and 1.2 releases. Builds 42 to 46 were local test builds.

## New in 1.5

### Soundtrack

- The adaptive DJ now plays from a catalogue of 495 versions of 210 tunes.
  These include Amiga modules, chip recordings from other ports, composer
  recordings and fan remixes.
- The first time a tune plays, you hear the original Amiga version. Later
  levels with the same tune play other ports and remixes.
- Retry, level select, saved runs and Hot Seat handovers keep the same
  version of a tune. Special-level, seasonal and result music keep their own
  tunes.
- Level music stays the same during play. The DJ mixes to a new track only
  when the game state changes, for example at the result screen.
- The SNES recording of "As Long As You Try Your Best" now plays to its end.
  Before, the macOS decoder stopped with an error at the end of the file.
- The first frame shows before level music starts.

### Play and controls

- The four-corner reticle is back, with one-pixel strokes. Green corners show
  an eligible lemming, yellow an ineligible lemming, and grey empty terrain.
- Settings has skill-icon sizes None, 1× and 2×. The default is 2×.
- An optional lemming count shows beside the cursor. The default is off.
- Cursor settings apply in Classic, Lemmings 2 and Lemmings 3.
- The selected lemming shows a faint halo and a gentle shimmer. With reduced
  motion, the halo does not move.
- Space and P toggle pause once for each key press. Key release and key
  repeat do not toggle pause again.
- A new level or a retry starts automatically after a 3–2–1 countdown. Pause
  or single-step to cancel the automatic start. Saved runs stay paused.
- Hot Seat handovers accept keyboard actions. Handovers stay paused until the
  next player is ready.
- The macOS pointer shows over menus and controls. The game hides it only
  over the playfield.
- You can click a checkbox label to change the checkbox.
- The speed toolbar buttons toggle correctly.

### Speed

- The title screen opens without a pause. The game reads only the header of
  each saved run to find the newest run. With 516 saved runs, this step fell
  from 6.1 s to 0.26 s.
- The title menu no longer stalls on each key press.
- The game does not set up a campaign again when you go back to it.
  Transition saves no longer block play.
- HDR effects start only when an effect needs them.

### Gameplay fixes

- Liquid fills correctly below bridges and does not cover terrain.

### NeoLemmix (Preview)

- The game can import, show and run NeoLemmix `.nxlv` levels, and read
  current `.nxrp` replays.
- The Fencer and Laserer skills, skill pickups and some other mechanics are
  not supported. Full NeoLemmix replay and behavior compatibility is not
  claimed.

## Delivered in 1.2 builds 39 to 41

- Build 41: A new installation starts correctly. Before, the game showed a
  black window, and a menu action closed the app (issue #3).
- Build 41: Rescue targets and Classic level hints show again.
- Build 41: A click on the visible edge of a side card in the level browser
  selects that card.
- Build 41: The opening music track continues when a level starts.
- Build 40: Automatic updates start when the app starts.
- Build 39: A new level browser shows each campaign as cards with previews
  and playlists.
- Build 39: The gameplay cursor no longer disappears in Lemmings 2 and
  Lemmings 3.
- Build 39: A click behind a bridge builder gives the skill to the follower
  lemming, also outside the click's pick box.
- Build 39: The skill icon beside the cursor stays inside the window.
- Build 39: Sparkle signed automatic updates.

## Delivered in 1.1 RC2 (build 38)

- New CRT display models.
- The system cursor no longer disappears during pointer capture.
- Classic releases pointer capture while a page, such as Settings, is open.
- The CRT view scrolls correctly at its curved corners.
- A fix that protected steel from destruction was removed. It broke 57 of
  the 352 Classic completion routes. All 352 routes verify again.

## In 1.1 RC1 (build 37)

- When a click could select two lemmings, the game prefers the lemming that
  comes toward the click. Settings has a switch for this in all three games.
- Lemmings 2 and Lemmings 3 have rewind, forward and step controls. Rewind
  plays audio cues in all three games.
- Solution replays have transport controls.
- The cursor shows the selected skill. The target lemming has a glow, and a
  skill assignment shows a short pulse.
- The adaptive DJ covers the soundtracks of all ports, with modern mixing
  and seasonal music.
- A run that cannot succeed plays a sad mood.
- Gameplay has no hover help pop-ups.
- The minimum macOS version is 12.3.

## Install and update

Installations of 1.2 builds 39 to 41 can select **Ultimate Lemmings → Check
for Updates…** to install this build. For a new installation, expand the
ZIP, move Ultimate Lemmings.app to Applications, then open it.

Universal app for Intel and Apple silicon, macOS 12.3 or later. The public
app and all bundled Sparkle components are Developer ID signed and Apple
notarised.

Saved runs from earlier builds resume as before.

## Known limits

- Lemmings 2, Lemmings 3 and NeoLemmix remain previews.
- The Lemmings 2 artwork toggle does not restore pixel-identical rendering
  after a round trip.
- A controller retry, rewind and step button sequence has a known routing
  issue.
- Chip recordings repeat the full file, with its intro and fade. They do not
  loop seamlessly.
- With the Mac sound set, the "yippee" and "pop" events have no sound.
- Physical Intel and minimum-macOS testing is not verified.
- The iPhone and iPad app is not part of this release.
