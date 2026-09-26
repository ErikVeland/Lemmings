# Ultimate Lemmings 1.5 (build 50)

[Download the Mac app](https://github.com/ErikVeland/Lemmings/releases/download/v1.5.0/UltimateLemmings-1.5-build50.zip)

Build: 50
Release base: v1.2-build41

These notes list all changes since 1.1 RC1 (build 37). Builds 38 to 41 were
public test and 1.2 releases. Builds 42 to 49 were local test builds.

## New in 1.5

### Soundtrack

- The adaptive DJ now plays from a catalogue of 495 versions of 210 tunes.
  These include Amiga modules, chip recordings from other ports, composer
  recordings and fan remixes.
- The app includes the recordings as AAC at 192 kbps, to keep the download
  below 2 GB. Amiga modules play as before.
- The first time a tune plays, you hear the original Amiga version. Later
  levels with the same tune play other ports and remixes.
- Retry, level select, saved runs and Hot Seat handovers keep the same
  version of a tune. Special-level, seasonal and result music keep their own
  tunes.
- Level music stays the same during play. The DJ mixes to a new track only
  when the game state changes, for example at the result screen.
- With the Mac sound set, the "pop" event now plays the Amiga sample.
- The SNES recording of "As Long As You Try Your Best" now plays to its end.
  Before, the macOS decoder stopped with an error at the end of the file.
- The first frame shows before level music starts.
- A crossfade keeps its length when the game stalls for a moment. Before, a
  long frame made the fade last longer.

### Play and controls

- The four-corner reticle is back, with one-pixel strokes. Green corners show
  an eligible lemming, yellow an ineligible lemming, and grey empty terrain.
- Settings has skill-icon sizes None, 1× and 2×. The default 1× is the size
  that builds 44 to 46 called 2×. The new 2× is twice as large. The old,
  smallest size is gone. Saved settings keep their current icon size.
- Gameplay settings have Original, Modern and Custom presets. Modern turns on
  the targeting aids below. Original turns them off and hides the skill icon.
  A change to one setting selects Custom.
- An optional lemming count shows beside the cursor. The default is off.
- Cursor settings apply in Classic, Lemmings 2 and Lemmings 3.
- With a bomb skill selected, a click near a blocker picks the blocker. With
  Builder selected, a click near a builder picks it, so its bridge continues.
  Both options are on by default in all three games. In Lemmings 3, they
  apply to Use tool. The native skill rules still decide each assignment.
- Press R to retry, and the music stops like a record under a DJ's hand.
  The new attempt releases the record, and it spins back up to speed.
- The selected lemming shows a faint halo and a gentle shimmer. With reduced
  motion, the halo does not move.
- Space and P toggle pause once for each key press. Key release and key
  repeat do not toggle pause again.
- A new level or a retry starts automatically after a 3–2–1 countdown. Pause
  or single-step to cancel the automatic start. Saved runs stay paused.
- Hot Seat handovers accept keyboard actions. Handovers stay paused until the
  next player is ready.
- On a game page, controller focus starts on the main action. For example,
  on the hints page, A shows the next hint.
- A confirmation page, such as "End this run?" or "Reveal full solution?",
  starts on the safe choice. Return, Space and controller A do not accept
  the action until you move to it.
- The macOS pointer shows over menus and controls. The game hides it only
  over the playfield.
- You can click a checkbox label to change the checkbox.
- The speed toolbar buttons toggle correctly.

### Controls and dialogs

- Press H for level hints. I and F1 still work.
- Use the toolbar to rewind two seconds or step one tick backward or forward
  in all three games. Play stays paused after a step or a rewind.
- Open hints from the toolbar in all three games. Left and Right move between
  hint stages. The full solution still asks for confirmation.
- Return and keypad Enter activate the focused dialog button. Tab, Shift-Tab
  and the arrow keys move between dialog controls.
- Dialogs and help screens use the normal mouse pointer in all three games.
- Replay and original-movie controls work from the keyboard and with
  VoiceOver actions.

### Speed

- The title screen opens without a pause. The game reads only the header of
  each saved run to find the newest run. With 516 saved runs, this step fell
  from 6.1 s to 0.26 s.
- The title menu no longer stalls on each key press.
- The game does not set up a campaign again when you go back to it.
  Transition saves no longer block play.
- HDR effects start only when an effect needs them.
- Music pitch rises a little at each fast-forward speed, without a change in
  tempo. Normal speed restores normal pitch.
- Speed echoes behind moving lemmings grow longer and softer at each speed.

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

Installations of 1.2 builds 39 to 41 download and install this build
automatically. For a new installation, expand the ZIP, move Ultimate
Lemmings.app to Applications, then open it.

From 1.5, the game checks for updates each day. When an update is ready, the
game shows its release notes. You choose to install it now or later.

Universal app for Intel and Apple silicon, macOS 12.3 or later. The public
app and all bundled Sparkle components are Developer ID signed and Apple
notarised.

Saved runs from earlier builds resume as before.

## Known limits

- Lemmings 2, Lemmings 3 and NeoLemmix remain previews.
- Chip recordings repeat the full file, with its intro and fade. They do not
  loop seamlessly.
- With the Mac sound set, the "yippee" event has no sound. The Mac disk has
  no yippee sample, and no named Amiga sample is a yippee.
- Physical Intel and minimum-macOS testing is not verified.
- The iPhone and iPad app is not part of this release.
