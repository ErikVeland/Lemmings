# Level browser

The 1.2 level browser is a shared selection path for Classic, bundled fan packs,
Lemmings 2 and Lemmings 3. It does not change engine rules or campaign progress.

## Behaviour

- The home screen always shows seven content families: Classic Lemmings,
  Oh No! More Lemmings, Holiday Lemmings, Oh Yes! More Lemmings, Fan Lemmings,
  Lemmings 2 and Lemmings 3.
- `Oh My! ALL Lemmings!` starts or resumes one run through every installed
  non-fan release. It does not add imported or archived fan levels.
- Each family opens its filtered CoverFlow catalogue. A family with one pack
  opens its level carousel directly. A missing family stays visible and reports
  that its data is not available in the build.
- Fan Lemmings includes installed fan archives and imported scanned Classic
  packs. Oh Yes! More Lemmings keeps its own family and release identity.
- Fan progress totals include installed packs only. New records use the pack's
  catalogue identity, and older name-based records migrate when read.
- `File > Level Select` opens the complete pack carousel, then a level carousel.
- The centre card is the selected item. `Start` is the only primary action.
- The carousel uses one shared perspective camera. The centre cover faces
  forward at 1.5 times its base size. Side covers remain full size and rotate
  45 degrees towards the centre. The near-card pitch keeps the transformed
  planes separate, including at the half-way hand-off. Selection changes
  animate between positions.
- Each accessible input slot stays flat. A separate screenshot plane gets the
  three-dimensional transform. Only the screenshot appears in its faded
  reflection.
- Each level card shows a screenshot from its source renderer. Pack cards use a
  representative level screenshot when one is available.
- Arrow keys, Page Up, Page Down, Home, End, scrolling, controller actions and
  direct mouse selection move through the catalogue. Precise trackpad gestures
  move the cards continuously, carry into momentum and snap to the nearest
  level when movement ends.
- VoiceOver receives a button name with the item, source, status and
  availability. Reduced motion changes the carousel to a stable list with
  thumbnails. It removes perspective, animation and reflections.
- Every launch resolves an engine, pack and level identity. L2 also checks its
  campaign unlock. L3 checks current runtime availability.
- Classic direct selection follows the active player's campaign progress by
  default. The first level of each rating starts unlocked, and progress unlocks
  later levels in that rating. `Settings > Gameplay > Level Select` can unlock
  all Classic cards without changing campaign progress.

## Playlists and shuffle

Playlists belong to the active player profile. The player can add an available
level from its card, create a manual ordered playlist, or create `Random 10`.
The manual editor can add, replace, remove and reorder levels. Rename also
offers confirmed playlist deletion, including its saved run.

`Random 10` first asks the player to choose one pack. It then saves an editable
playlist with up to ten distinct eligible levels from that explicit pool. It
does not silently combine official campaigns and fan packs.

A saved playlist can start in manual order or in shuffled order. A shuffled run
stores its seed, fixed order and current position. This makes the order stable
after a relaunch and prevents repeats within that run.

`Shuffle all` uses the installed eligible fan-level pool only. The confirmation
shows the level and pack counts before play. The run keeps that pool identity
and visits each level once before it ends. It does not start if an installed
pack cannot be read and verified.

Each playlist entry stores the engine, pack, level, catalogue revision and
source revision. The editor shows locked, missing and changed entries. These
entries block the run until the player removes or replaces them.

The playlist file also stores the active run for the player profile. The
playlist library shows its saved position as `Resume run`. Playlist and shuffle
results do not advance campaign or fan-pack progress, create saved attempts,
preserve verified routes or enter player records. A run cannot start during Hot
Seat, and Hot Seat cannot change while a sequence is loading or playing.
Alternate game and level navigation stays unavailable during that time. Leaving
to the game library pauses the run at its current level. A failed level retries
the same entry. Starting another run requires confirmation before replacing a
saved run.

## Level screenshots

The screenshot pipeline renders only visible cards. It crops a 320 by 160 image
at the level's authored starting camera. Classic and fan Classic screenshots
include the opening object frames. Lemmings 2 screenshots include terrain and
the first object frames. Lemmings 3 screenshots use its composed static scene.

Rendering runs outside the UI thread. A revision-aware store coalesces duplicate
work and keeps a 32 MiB least-recently-used bitmap cache. The view keeps a
separate recent-image cache limited to 21 entries or 8 MiB. Work stops when no
visible card is waiting for it.

The cache key includes the typed level identity, the renderer revision and the
source content identity. Lemmings 2 fingerprints the level and style data.
Lemmings 3 also fingerprints its style banks, palettes and referenced object
files. The renderer checks these inputs again when rendering finishes, so a
mid-render content change cannot enter the cache.

A screenshot failure does not substitute another level. The card keeps its real
name and input target and shows `PREVIEW UNAVAILABLE`.

## Content boundary

Official Classic campaigns keep their `Complete` status. L2 and L3 remain
`Preview`. Bundled fan packs keep their existing `Playable` evidence. Packs from
other folders are visible only through the existing import or update paths and
are labelled `Unverified`.

The browser fingerprints a selected fan archive. It rejects the launch if the
archive changes before the player starts the level. It does not substitute a
different level.

Catalogue discovery and final source validation run outside the UI thread.
Their loading pages can be cancelled. Imported Classic progress uses a source
and content revision; an unambiguous old save key migrates once.

## Validation and limits

The app integration test covers typed selection, missing and changed identity,
projected trapezoids, transformed hit regions, continuous gesture and momentum
movement, settled and half-way plane separation, reflections, screenshot
loading, bounded cache reuse, mouse input, keyboard input, simulated controller
input, VoiceOver names, focus targets and the reduced-motion layout. It also
checks the seven home families, their filtered routes and live pack refreshes.
It captures the compositor carousel and list states for inspection.

The source tests also cover per-rating Classic unlocks, the Settings override,
ordered playlist edits, seeded non-repeating shuffle, random pool limits,
profile-owned persistence, active-run resume and storage recovery. A separate
Classic flow check confirms that playlist results do not change campaign
progress.

Physical controller checks, a complete VoiceOver listening journey and packaged
launch journeys for all three engines remain open. This checkout does not contain
the commercial game data for those journeys.

The catalogue does not yet include individual NeoLemmix `.nxlv` imports. Those
files still use the existing file-picker path, so they do not yet have browser
cards or cached screenshots.

The full 1.2 content atlas, automatic fan-pack updates and application updates
remain separate work. Current playlist evidence covers source and automated
build paths only. It does not establish packaged three-engine journeys.
