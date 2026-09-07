# Ultimate Lemmings, beta 8

Version 0.1, build 8. This beta enables all Lemmings 2 campaign content in the
native player. It also fixes gameplay controls, audio settings and music
transitions, and removes the extra frame from the app icon.

## App windows

- About Ultimate Lemmings shows the current version and beta build.
- Achievements has a trophy summary, progress bar, and illustrated award cards.
- The Trilogy description now matches its unlock rule: complete Lemmings 1, 2, and 3.

## Gameplay and display

- Fixed a control-panel crash in Xmas Lemmings and other first-generation games
  when drawing labels alongside the new speed button at larger display sizes.
- Liquid colour continues below animated surfaces to the terrain floor or level
  bottom. Standard and Macintosh artwork retain their own colours and collision rules.
- The first-generation player has a speed button. Click it or press F to toggle
  3× speed. Each level starts at normal speed.
- Finishing a level with single-step now shows results and records progress.
  This works for campaign and fan levels, on both wins and losses.
- Hold the release-rate buttons and drag the minimap in monitor and television
  modes. Those controls now work as they do in flat mode.
- CRT clicks now match the displayed picture, including on Retina screens.
- The simulation uses elapsed time when display callbacks are delayed.
  A long sleep or interruption does not cause unlimited catch-up.
- The app icon fills its background to the edge without an extra bevel.

## Lemmings 2

- Widescreen windows show more of the level while keeping the original control
  panel centred. Move the cursor to any playfield edge to scroll the camera.
- Tribe cards and practice portraits use the original shared INFO colour palette.
- All twelve tribes and 120 campaign levels are enabled in the native beta.
- All 51 skills, interactive campaign objects and four practice maps are available.
- Fan controls, original skill artwork, sound effects and tribe music are connected.
- Progress includes survivor carry-over, medals, autosave and eight save slots.
- The original introduction, talisman award, ark movie and ending scripts play.
- Sixty-four recorded level completions pass with the app's pointer and fan rules.
  Full campaign walkthrough coverage and original-engine equivalence remain unverified.

## Audio

- Switching between modules, recordings, the DJ, and None starts the selected
  source. Module music returns correctly after a recording or DJ mix.
- Saved volume, silence, and music-style settings apply at launch.
- Macintosh and Amiga sound-bank changes take effect immediately.
- Mute includes recordings and the DJ, and stays set after relaunch.
- Entering a sequel stops the previous title's audio.
- A new DJ cue can interrupt a crossfade without corrupting the next fade.
- Audio output resumes after interruptions without restarting a stopped source.

## Packages

The full package includes Apple Lossless recordings. The slim package removes
recordings, including M4A files, and keeps module music.

## Known limits

- Lemmings 3 is a preview, with no connected music,
  sound-effect, or movie playback. Passing decoder tests does not make those
  features available in the game.
- NeoLemmix level files have no gameplay sound effects or rewind. Fencer and
  laserer remain unsupported. This is separate from the classic fan-pack browser.
- Some fan-pack special background pictures remain unavailable.
- Native SNES and Mega Drive cartridge campaigns are not playable.

Report the game, level, display mode, artwork, music, and sound settings used.
Include whether the problem returns after a restart.
