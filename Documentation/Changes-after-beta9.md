# Changes after beta 9

- Fan Levels opens the embedded collection without a folder prompt. New compatible
  packs are checked and downloaded in the background at launch, then kept offline.
  See [Fan levels](FanLevels.md).

- New L2 campaigns start at Beach. Existing tribe selections and progress remain intact.
  Briefings name the tribe beside its level number.
- L2 front-end illustrations and lettering now refine diagonal contours at 2×
  resolution, including the intro, menu, map, briefings, results and endings.
  Level previews use their tribe’s terrain treatment. The artwork toggle applies immediately.

- Explosions have a larger orange-and-white burst on all screens. HDR cores
  can reach eight times SDR white, within the display's available
  HDR headroom. Settings > Video adds optional full-screen HDR flashes. They are
  off by default. Whole-screen pulses are brief and spaced during nukes.
- The DJ changes music only after the rescue target is reached. It prefers
  victory and ending themes. L2 uses the gold-medal rescue target for that level.
- Settings > Audio adds **Include L2, L3 and other ports**, on by default. The DJ
  now plays native modules as well as recordings. The current bundle provides
  seven pools and 85 tracks, including the L2 and L3 soundtracks.
- Playable port recordings and modules can be added below
  `~/Library/Application Support/Ultimate Lemmings/Soundtracks`, in named folders.
  Supported files are MOD, WAV, AIFF, MP3, M4A, CAF and FLAC. Other console audio
  remains archived in ROM formats with no connected playback decoder.
- Fast-forward leaves very faint, short afterimages behind moving lemmings in all
  three games. Trails follow actual movement, including slopes and diagonals.
  A slight directional blur softens the additive ghosts. All solid
  sprites draw above the ghosts, including those of neighbouring lemmings. The
  effect reuses cached sprites, with no frame capture or per-frame blur and at
  most 24 trails. Pausing or leaving fast-forward clears it.
- The last ten seconds play one builder-style warning per second. The sound
  follows the game clock and honours volume and mute settings.
- Finished runs have variable-speed replay and MP4 movie export, including
  music and sound effects where connected. See [Replays and movies](ReplayMovies.md).
- Arcade profiles add three-letter initials, eight sprite portraits and separate
  campaign progress. Each level has local rescue, skill-efficiency and 100% boards,
  six achievements, personal records and a retry target after wins or losses.
  See [Arcade records](ArcadeRecords.md) for ranking rules and maximum-rescue limits.

- Results now lead with the rescue count, personal best and one retry challenge.
  Detailed boards, achievements and solution statistics have their own pages.
  Results, profiles, settings, campaign achievements and replays all stay in the
  main game window. Back restores the previous page. Retry starts immediately.
  Game clocks pause while a page or attached file picker is open.

These changes are included in beta 10. See [the release notes](ReleaseNotes-beta10.md)
for the complete tester summary. The signed beta 9 archive remains unchanged.
