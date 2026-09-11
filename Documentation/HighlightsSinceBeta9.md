# Highlights since beta 9

Every player-facing change in betas 10, 11, 12 and 13, grouped by area. Build-by-build
notes stay in [beta 10](ReleaseNotes-beta10.md), [beta 11](ReleaseNotes-beta11.md),
[beta 12](ReleaseNotes-beta12.md) and [beta 13](ReleaseNotes-beta13.md). For what is
still incomplete, read the [1.0 gap evaluation](ReleaseReadiness/OneZeroGapEvaluation.md).

## Players and shared play

- Local arcade profiles have initials, sprite portraits and separate campaign
  progress. Each level tracks rescue records, skill use, achievements and retry
  targets.
- Hot seat let two or more profiles alternate attempts on one level. Open
  **Hot Seat…** from the app menu, **Hot seat** in Player Profiles, or
  **Players** on a result page.
- **Retry as [initials]** hands the same level to the next player. Turn order wraps
  through the selected profiles.
- Campaign progress stays with the host. Each attempt keeps its own player, scores,
  records and achievements. Guests do not inherit the host's saves.

## Runs survive interruption

- Classic campaigns, NeoLemmix files and native L2 and L3 campaigns save
  in-progress checkpoints. Use **File → Resume Saved Run** to restore the latest
  run for the current player. A restored game stays paused.
- The game pauses when its window or the app loses focus. Returning needs an
  explicit resume.
- Disconnecting a controller that you have used pauses play. An idle controller
  does not interrupt a keyboard player. Held speed input clears.
- Arcade records keep validated backups and offer a retry after a failed save.
  Settings, manual L2 slots and fan progress carry forward from earlier versions.

## The Trolley

- Optional rescue stars sit beside the native goal. One star meets the goal, two
  reward an extra rescue, and three need the verified maximum or a supported full
  rescue. An unknown maximum stays labelled unknown.
- Achievements span levels. Objectives the current game cannot support are hidden.
  Awards you already earned remain.
- Play style names open short philosopher and run explanations.
- Run details show separate statistics. Empty hatch, nuke, rewind and undo counts
  are omitted.

## Results and interface

- Results, records, profiles, settings and replays all stay inside the game window.
  Macintosh bitmap fonts and stone borders replace the separate records window.
- Results lead with the rescued count, the requirement, and the best possible or
  best known rescue. Retry is on the left. Next level is on the right.
- Rewind records use an explicit **Used** and **Unused** filter.
- Player and leaderboard rows are vertically centered. Achievement names and
  run-detail labels use green lettering. Supporting text stays blue.

## Level hints

- All 120 original levels have three revealable tiers: a nudge, an approach, then
  three opening assignments from a verified route. Each tier needs a deliberate
  action.
- Hint text uses the game font. Long text scrolls with mouse, keyboard or
  controller. Other campaigns receive labelled general coaching.

## Fan levels and NeoLemmix

- Fan Levels opens directly, with 535 embedded packs and 6,043 readable levels. No
  folder prompt.
- Each launch checks the Lemmings Level Database for new compatible packs and
  downloads them in the background. The collection stays available offline.
- A NeoLemmix level that needs unsupported skills or objects is refused with an
  explanation before it replaces the current playfield. An unsupported skill with
  zero stock does not block an otherwise compatible level.
- Opening a compatible NeoLemmix file now enters the playing interface correctly.

## Lemmings 2

- New campaigns start at Beach. Existing tribe selections and progress remain
  intact. Briefings name the tribe beside the level number.
- The intro, menus, map, briefings, results and endings use finer Macintosh-style
  2x artwork and lettering. Level previews use their tribe's terrain treatment.
- The panel background fills the margins on widescreen displays.

## Lemmings 3

- L3 uses its original panel artwork and bitmap lettering, with working skill,
  timer and playback controls.
- L3 plays its bundled tribe module music. Music follows volume and mute, suspends
  during replay playback, and appears in exported recordings.
- Six named original voices play for the entrance, assignments, rescues, deaths and
  bomb activation.
- The pause menu offers **Original movies**. Watch all five bundled movies, pause
  with Space, and return with Escape. These gallery movies play without a
  soundtrack.

## Oh Yes! More Lemmings

- Each rank loads artwork from the correct source. The Sunsoft conversion keeps its
  own ground metadata and special background. All 60 levels pass rendering and
  release checks.

## Speed, explosions and music

- Fast-forward draws fading sprite afterimages. They are now faint and short, they
  follow real movement including slopes and diagonals, and the solid lemmings stay
  sharp above every ghost.
- The final ten seconds play a warning sound each second.
- Explosions have a larger orange-and-white burst. Optional full-screen HDR flashes
  are in Video settings and stay off by default.
- The DJ changes music only after you reach the rescue goal, and it prefers
  triumphant tracks. L2, L3 and other port soundtracks join the mix through an
  option that is on by default.
- Music no longer overlaps after a quick pause and unpause or a brief hide. Fades
  follow elapsed time when rendering delays them.

## Replays and movies

- Finished runs support variable-speed replay and MP4 movie export.
- Replay audio uses less temporary memory and skips mixing during silence. A
  recorded video keeps every simulation frame.

## Controller and accessibility

- Controller buttons can be remapped. Conflicting bindings swap. Device names and
  glyphs follow the connected controller.
- The pointer is captured correctly across multiple screens.
- **Reduce added motion** turns off speed trails and cinematic explosions.
- **Reduce added flashes** turns off added bright explosion cores, HDR flashes and
  cinematic explosions. Original game artwork can still contain flashes.
- Both controls keep game speed and controller support unchanged.

## Rules and evidence

- Destructive skills now follow the original DOS steel-probe rules. This opens
  routes that overly restrictive terrain masks used to block.
- Rewind and replay keep commands at tick boundaries, branch changes and queued
  actions.
- All 120 original DOS levels have winning replays checked on the native engine.
  103 of them rescue the full population.
- The campaign gate checks 88 further winning replays across Oh No!, Xmas and
  Holiday, plus 16 Lemmings 3 levels.
- Verified maxima and demonstrated rescue records carry distinct labels. A winning
  replay proves its rescue count is reachable. It does not prove that more rescues
  are impossible.

## Scope

Records and rankings are local. Rescue stars never replace native progression
rules. The sequel artwork is an inferred Macintosh-style reconstruction. Fan
updates cover compatible packs in the database, not arbitrary forum attachments.
Replay movies use SDR output. L2 and L3 remain labelled previews, and NeoLemmix
compatibility is partial.
