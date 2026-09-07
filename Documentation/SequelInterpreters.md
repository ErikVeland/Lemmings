# Lemmings 2 and 3 interpreters

The native readers do not execute DOS binaries or convert sequel levels to
Lemmings 1 physics. The L2 runtime now starts all 120 campaign levels and four practice maps.
Classic 1 has an automated full-rescue replay (60/60, no nuke); Cavelem 1–3
have a continuous one-survivor completion replay chain. L3 now starts all 90 campaign
levels. Classic levels 1–3, Egyptian level 1, and Shadow level 1 have completed-run
replays. The Shadow replay abandons one lemming after rescuing nine. L2 is available as a native beta; L3 remains a preview. Neither claims
verified 1:1 original-engine behaviour.

## Play L2

Build and open the self-contained local app:

```sh
zsh Scripts/build-native-l2.sh
open ".build/native-l2/Lemmings 2 Native.app"
```

The full app also offers **Play Lemmings 2…** in its app menu (Command-Shift-2).
Both builds embed the L2 assets, eighty original Sound Blaster clips and fourteen Amiga music modules. The player
opens the original menu directly, without a data-folder picker. An explicit
command-line data path remains available for reader development.

Click Play, then click the briefing to start. Select a skill on the original
panel or with keys 1–8, then click a lemming. Space pauses, R retries, and F
toggles three-times fast forward. You can assign skills while paused.
The original yellow/red outline marks the selected skill, including while paused.
The original pointer becomes a box over an eligible target; the panel names its
current activity. Overlapping lemmings that can accept the skill take priority.
Double-click the mushroom cloud (upper-right control) to nuke. A single click
only arms it briefly. The lower-left control is the fan, not nuke. Nuke stops
new releases and starts one lemming's countdown per tick. Escape returns to
the menu; Play resumes the same unfinished level. There is no developer strip
or single-step control.
Arrow keys move the camera. Trackpad scrolling moves on both axes.
Shift-scroll moves horizontally with a mouse wheel.

Preferences has separate Music and Sound FX toggles. The native PCM mixer plays
panel clicks, assignments, entrance cues, explosions, falls, water/fire deaths,
steel hits, construction warnings, machine launches, rope, valves and teleporters.
Some skill and object effects still need sound parity checks.

The original map selects a tribe. Briefing arrows select unlocked levels.
All 120 campaign levels start and pass an initial physics smoke check. All 51
skills and object types 0–14 have native implementations. The extended physics
still needs broader full-level and original-engine comparison. A successful
load is not a verified solution.
The campaign model covers all twelve tribes, carries the best survivor count
forward, and applies the original gold/silver/bronze thresholds. Progress uses
the separate `nativeL2Campaign.v1` store, with autosave and eight manual slots.
Old preview preferences remain untouched. Embedded progress uses a stable key
when the app is moved; explicit external data paths retain separate stores.
Reopening restarts the selected level, not an in-progress simulation.
The original MASKS and INTERN assets now drive terrain changes. Terrain-skill
phases and release timing follow the original overlays; full collision,
assignment rules and several sprite mappings still need validation.
See [L2 physics evidence and remaining work](Lemmings2PhysicsEvidence.md).
This is not a 1:1 engine yet. It does not award verified
campaign achievements or change original saves.

The menu, font, panel, map and briefing use original assets. Practice supports
choosing eight skills on the four original training maps, with separate progress.
The eight-scene introduction, talisman award and ending screens run their original
GAL scripts. The ark movie decodes all 100 original frames. The ark ending requires
a golden talisman and at least 30 survivors from each tribe.

## Play the L3 preview

```sh
zsh Scripts/build-native-l3.sh
open ".build/native-l3/Lemmings 3 Native.app"
```

The full app offers **Play Lemmings 3 Native Preview…** (Command-Shift-3).
Both builds now resolve L3 data inside the app, without a data-folder picker.
Keys 1–5 select Walker, Blocker, Jumper, Use, or Drop. Click a lemming to assign
the action. Use applies the selected direction to bricks and spades. Grenades
and Hadokens follow the lemming's facing direction. The preview also supports
bombs, suckers, shimmy devices, umbrellas, swimming aids, and clocks.
Carriers show a tool label and remaining quantity. Clocks add one minute
without replacing a held tool. Umbrellas open during falls; swimming aids
activate in water. Turning a swimmer needs a second aid. Use and Drop prefer
a carrier when lemmings overlap. Use activates suckers or starts a shimmy
jump. Active climbing equipment shows its remaining time. Walker releases
a wall or ceiling grip. Bombs stay at the lemming's feet. Grenades launch
at 45 degrees, bounce, and have four charges per box.
Walker interrupts work, releases a blocker, or turns a walking lemming.
Space pauses, period steps, F changes speed, and R retries. Actions work while
paused. Arrow keys and scrolling move the camera on larger maps.
End run (or Escape) opens a confirmation sheet and pauses the simulation.
Keep playing restores the prior pause state. End run loses active lemmings,
retains rescued lemmings and reserves, and records the result. A run with no
rescued lemmings cannot advance. Retry remains available after ending a run.
Escape and Return choose Keep playing while the confirmation sheet is open.

The tribe selector offers Classic, Shadow, and Egyptian, each with 30 levels.
Their native file ranges are 001–030, 101–130, and 201–230. All 90 levels load
and release lemmings. The 15 previously blocked trap levels are now enabled.
Next level follows the selected tribe's sequence after each win. This is a load-and-release check, not
evidence that every level can be completed. Direct selection starts with 20 lemmings.
Progress is saved separately for each tribe and data folder. Existing Classic
preview saves remain compatible; saves from another tribe are rejected. Reopening restarts the
selected level, not the in-progress simulation. No original saves are changed.

The reserve rules now follow the original manual: at most ten initial lemmings
enter, deaths draw replacements from reserve, and surviving reserves carry
forward with rescued lemmings. Extra lemmings can increase the next population.
The earlier preview incorrectly released all 20. Its old completion count is
not evidence for the corrected rules.

Classic level 1's replay rescues ten and retains ten in reserve. Level 2's replay uses
the spade to release both prisoners and open an escape route. Twelve exit and
ten remain in reserve, giving 22 survivors. Level 3's spade replay starts with
those 22, rescues ten, loses one, and retains eleven in reserve in 640 ticks.
Egyptian level 1's downward-spade replay rescues ten without a loss, retains
ten in reserve, and completes in 502 ticks. It also verifies campaign advance.
The other enabled levels have only load/release tests, not full solution
replays. A trial level-4 bridge route reaches the spade but does not complete
the level. It is not counted as a passing replay.
Shadow level 1's replay uses jumpers to cross the hill, collects the brick
boxes, and builds toward the raised exit. Nine lemmings exit in 594 ticks.
The replay then ends the run, abandoning one active lemming and retaining ten
in reserve. The next level starts with 19 survivors. This is a completed run,
not an all-rescued solution or evidence of original-engine fidelity.

All nine trap types use native 8×2 trigger cells, frame counts, start frames,
frame delays, and cycle pauses. They capture one lemming, animate, and rearm.
The original executable confirms mode-1 busy-state exclusion and timing fields.
Tests check every animation frame, a second arrival during cooldown, and a
later arrival after rearming. Synthetic tests also cover covering and jumps.
The earlier foot-cell probe and victim death timing remain provisional.
See [native trap evidence](Lemmings3TrapEvidence.md) for offsets and limitations.

Work geometry, six-use work-tool boxes, action timing, drowning delay, fall limits,
sprite anchors, and animation IDs remain provisional. The construction tile
comes from each style's native temporary object: 298 for Classic, 439 for
Shadow, and 1152 for Egyptian, with provisional placement rules.
Umbrella deployment and descent, swimming movement, and the five-second aid
lifetime are also provisional. The automatic-tool tests check long-fall
survival, consumption, water crossing, turns, and one-time clock collection.
Suckers and shimmy devices use a provisional five-second active lifetime.
Tests cover activation, wall-top transitions, flat ceilings, uneven ceilings,
manual release, and exhaustion. Bombs use the manual's five-second fuse.
Grenades use its eight-second fuse. Blast radii, trajectories, damping,
and tool charge counts other than grenades remain provisional. Tests check
fuses, inventory, terrain damage, permanent-terrain protection, and tool-box
survival. Hadokens defeat creatures without damaging lemmings or terrain. Effect
rendering uses tool icons, blast rings, and simple fireballs as preview art.

The Lemme Fatale attracts one walking lemming at a time. Successful actions
break the attraction and give a brief recovery period. Potato Beasts attack
nearby lemmings. Buzzards pursue nearby lemmings in flight. Explosions and
Hadokens defeat these creatures. Tests cover attraction, distraction, combat,
reserve replacement, deterministic pursuit, and native creature-count checks.
Creature movement, collision bounds, attack cooldowns, attraction range, the
five-second charm duration, and two-second recovery remain provisional.
Native IND/CMP sprites use each creature's own low-32-color VGA palette.
Animation IDs and anchors still need original-engine comparison.

Levels 16, 20, and 22 use multiple hatches. They share the release count and
reserve population, with provisional round-robin release order. Tests cover
all three native levels and shared-population accounting.

Moles dig without attacking lemmings and change direction at constructed
bricks or permanent terrain. Synthetic tests cover digging, harmlessness, and
terrain protection. Dig masks, movement rate, and clockwise steering remain
provisional. Each tribe uses its own native sprites, palette, and construction art.

These results do not prove original-engine fidelity. Native collision and
death-animation details, complete solution replays, and verified sequel
achievements remain unfinished.

## Implemented

- `Lemmings2Compression`: GSCM decompression with output limits, ordered
  dictionary redefinitions, multiple chunks, and exact length checks.
- `Lemmings2Form`: big-endian FORM framing. Unknown sections are retained.
- `Lemmings2Level`: level name, eight skill slots, time, signed release rate,
  initial viewport, gold-loss allowance, style, tile arrangement, terrain
  records, and object records. The container retains the remaining fields.
- `Lemmings3Level`: the native 30-byte metadata header, resource references,
  dimensions, viewport, time, release fields, extra lemmings, and enemy count.
  The original header bytes remain available.
- `Lemmings3Objects`: permanent and temporary six-byte object placements.
- `Lemmings2Style`: palette, four-plane terrain tiles, object definitions,
  and regular object animation frames with resolved payload offsets.
- `Lemmings2Terrain`: terrain pixels and terrain-only collision. Object steel
  and triggers are not yet part of the collision map.
- `Lemmings3StyleBank`: object records, frame lists, sparse frame composition,
  four-plane 8x2 graphics blocks, and separate native attribute grids.
- `Lemmings3Style` and `Lemmings3Scene`: tribe/style palettes and static scene
  composition from the level's native object placements.
- `Lemmings2Sprites`: native VLEMMS command interpretation, all four pixel
  planes, signed sprite offsets, frame self-pointers, and explicit opacity.
- `Lemmings3Sprites`: native IND/CMP command interpretation, animation groups,
  four-plane frames, literal runs, transparent skips, and row/plane endings.
- `Lemmings2AirPhysics`: integer airborne movement before collision resolution.
  Preserves old-velocity position updates, signed countdowns, minimum horizontal
  drift, terminal downward velocity, and 16-bit position arithmetic.
- `Lemmings2Runtime`: independent, fixed-tick Classic preview simulation.
- `Lemmings2Objects`: regular component positioning, repeated components,
  native trigger bitfields, and clipped point/square trigger rectangles.
  Runtime collision includes steel, water, and constant fire hazards.
- `Lemmings2Campaign`: all twelve tribe sequences, locked-level selection,
  original medal thresholds, survivor carry-over and validated progress.
- `Lemmings2FrontEnd`: native front-end images, palettes, text, font and panel.
- `Lemmings2PlayWindow`: original-art menu and panel, terrain, sprites, music,
  map, briefing, results and save/load flow. It does not yet use the airborne module.
- `BundledGameResources`: app-relative assets, music and automatic Classic discovery.
- `Lemmings3Runtime`: separate fixed-tick simulation with core actions,
  brick/spade pickup and drop, directional work, permanent-terrain protection,
  automatic tools, climbing equipment, explosives, Hadoken projectiles,
  all nine trap types, Fatales, Moles, Potato Beasts, Buzzards, multiple hatches,
  extra lemmings, water, reserves,
  exits, timeout, and rescue counts.
- `Lemmings3ClassicCampaign`: validated preview progress, direct starts,
  tribe-specific progress, level-specific results, and survivor/reserve carry-over.
- `Lemmings3PlayWindow`: level and direction selectors, native graphics,
  terrain updates, camera movement, pause-time assignment, confirmed end-run,
  retry, and speed.

The readers retain numeric IDs and unknown fields. The experimental runtime
maps eight Classic skills, stacker, platformer, stomper, and object types 2, 3, 5, 6, and 11. It rejects other
types instead of silently assigning them unrelated behaviour.

## Verification

Run `zsh Scripts/run-sequel-data-tests.sh` from the repository.
Run `zsh Scripts/run-lemmings2-runtime-tests.sh` to test the playable runtime.
Run `zsh Scripts/run-lemmings3-runtime-tests.sh` for attribute-grid bounds,
core actions, tools, terrain protection, water, reserves, progress validation,
automatic tools, traps, and full completion replays for Classic levels 1–3
and Egyptian level 1, plus a Shadow level-1 replay that abandons one lemming
after nine rescues. Tests verify survivor carry-over and terminal-state safety.

The tribe expansion passed runtime and native-data tests, canonical saga tests,
and the universal app build. An isolated UI check loaded Shadow and Egyptian
level 1, verified their artwork and ten initial releases, and checked disabled
Egyptian trap entries. After the trap expansion, another isolated UI check
verified all 30 Egyptian entries were enabled and ran level 2's trap scene.
This does not establish completion of every level.
An isolated UI check verified cancellation from paused and running states,
confirmed end-run behavior, and the disabled End run button after completion.
The keyboard check confirmed that Escape and Return cancel without losing lemmings.

Runtime tests check the ten implemented skills, inventory, native terrain masks and action
phases, release timing, deterministic replay, rescue, nuke, and completion.
With local assets, a fixed twenty-input replay rescues all 60 lemmings in the
original first level, with no nuke or state injection. This proves a full-rescue
path in our native interpreter, not original-engine fidelity. An isolated UI
check also assigned a digger while paused and stepped through its first native
cut while four lemmings were active.
Tests also check steel protection, work-skill interruption, hazards, component
extensions, trigger clipping, survivor carry-over, and progress round trips.
Construction tests cover both directions, exact mask/action frames, platformer
continuation, ceiling and movement probes, and steel. The original countdown
uses fifteen ticks per displayed second. The 60/60 replay still ends at tick 2878.

After building both apps, run `zsh Scripts/run-bundled-game-resources-tests.sh`.
It checks embedded L2 maps, UI, masks, sprites, music and the all-in-one asset
catalog from a different working directory, and rejects source-linked assets.
An isolated copy outside the checkout was also launched without arguments:
the original menu, Classic briefing and in-game panel rendered without a picker.
All ten Classic levels release lemmings in smoke tests. Each exit sits on
solid terrain with air immediately above it. Separate one-lemming fixtures
approach each original exit and verify rescue. Those fixtures isolate exit
interaction and do not count as full-level solutions.

Synthetic tests need no commercial assets. The script also reads local data
under `Sources/Ports/Lemm2` and `Sources/Ports/LEM3CD` when those folders exist.
These folders remain ignored by Git. Corpus tests include extra level files,
so their file counts are not campaign counts or proof of campaign order.

The current local corpus has 124 L2 level files and 97 L3 level files. Terrain
and object graphics resolve for all 124 L2 files, including Medieval 7 and 8.
The upper six bits of their tile words are metadata, not part of the tile index.
All 12 L2 styles decode, including regular and special animation frames. All referenced
L3 objects resolve to graphics. These checks do not prove gameplay fidelity.

The native sprite interpreters decode all 122 groups in local `VLEMMS.DAT`.
All 11 local L3 IND/CMP pairs decode, including the three 95-animation tribe
banks. Synthetic tests check opaque black pixels, transparent skips, literal
255 values, signed anchors, truncated commands, and invalid frame pointers.
Airborne-motion tests check the published routine's arithmetic and operation
order. They are not yet original-engine flight comparisons.

`Tools/SequelProbe/main.swift` renders the first level of either local game to
a PNG for inspection. It is a diagnostic tool, not a player. L2 campaign levels
0–119 and four practice files are supported, including special-object sprites.
The diagnostic renderer shares the runtime's object
resolver, including border normalization and repeated components.

```sh
zsh Scripts/render-sequel-shot.sh Sources/Ports/Lemm2 .build/first-l2.png
zsh Scripts/render-sequel-shot.sh Sources/Ports/Lemm2 .build/classic-5.png --level=4
zsh Scripts/render-sequel-shot.sh Sources/Ports/LEM3CD .build/first-l3.png
zsh Scripts/render-sequel-shot.sh Sources/Ports/Lemm2 .build/l2-sprites.png --sprites
zsh Scripts/render-sequel-shot.sh Sources/Ports/LEM3CD .build/l3-sprites.png --sprites
```

## Next implementation stages

### Original-engine reference runs

Install DOSBox Staging, then run either command. The launcher prefers the
macOS app in `/Applications`, then the `dosbox-staging` command:

```sh
zsh Scripts/run-sequel-reference.sh 2
zsh Scripts/run-sequel-reference.sh 3
```

Each run copies the local game data into a new folder under
`.build/sequel-reference`. Only that copy is mounted as a DOS drive.
Original game files and saves remain unchanged. Previous reference runs
remain available for inspection. The launcher ignores the emulator's primary
configuration and uses the checked-in reference configuration.

This is a development reference, not the shipped interpreter. It does not
award achievements or prove that native sequel gameplay works. Use original
frames and recorded input sequences to check graphics and simulation changes.

Local smoke test: L2 boots into graphics mode. L3 boots through its introduction
to the animated main menu in DOSBox Staging 0.83.0. Automated L3 map-room clicks
have not yet worked, so no level-play or frame-timing comparison is claimed.
Seamless mouse mode is enabled for reference interaction. See the
[DOSBox Staging mouse documentation](https://www.dosbox-staging.org/0.83/manual/input/mouse/)
for capture controls and compatibility limits.

### Measured L2 walking sample

A 974-frame, 320x200 ZMBV recording of the original Beach practice level is
stored locally at `.build/sequel-reference/l2.j5Kbyu/captures/walking.avi`.
It is not distributed. The original was paused, recorded, unpaused, and paused
again. The video reports a VGA rate of 2190197/31250 frames per second.

`Tools/SequelTrace` compares literal native sprite pixels with RGB24 video
frames, with a maximum difference of three per colour channel. This allows
for DAC colour expansion differences. Transparent sprite pixels are excluded.
The first frame searches all animations. Later frames search LM5C in the
measured platform region. This is a diagnostic for this sample, not a general
lemming tracker. Duplicate sprite artwork does not identify the active skill.

Observed image matches include:

| Video frame | Matched LM5C frame | Image x | Image y |
| --- | --- | --- | --- |
| 9 | 9 | 183 | 88 |
| 13 | 10 | 184 | 87 |
| 17 | 11 | 185 | 88 |
| 21 | 12 | 186 | 87 |
| 25 | 13 | 187 | 87 |

This sample confirms one-pixel horizontal advances every four VGA frames.
The image coordinates are not lemming foot coordinates. Do not infer collision
probes, skill IDs, or universal tick timing from these matches alone.

To repeat the sample analysis:

```sh
ffmpeg -i .build/sequel-reference/l2.j5Kbyu/captures/walking.avi -t 3 -an -pix_fmt rgb24 -f rawvideo .build/walking.rgb
zsh Scripts/trace-sequel-reference.sh Sources/Ports/Lemm2 BEACH .build/walking.rgb
```

### Native implementation

The Classic map-origin bug is fixed. The terrain reader removes one 16-pixel
column and two 8-pixel rows from the native map. Object positions included
that border but were not normalized. Both entrance and component coordinates
now subtract (16, 16), and exit triggers test the lemming's foot position.
This aligns all ten native exits to their terrain without enlarging any
trigger or buffer. Camera movement uses the native header's limits instead
of exposing unused columns. Original-engine movement comparisons remain due.

1. Broaden L2's complete-level solutions and original-engine comparisons; all stocked skills and campaign object types are implemented.
2. Validate L3 attribute semantics and resolve remaining object interactions.
3. Implement each game's fixed-tick simulation and skill mechanics separately.
4. Validate movement and outcomes against recorded runs of the original games.
5. Connect verified campaign orders and sessions to the app and achievements.

## Format references

The reserve and tool interaction rules were checked against the original
[Chronicles manual](https://db.hfsplay.fr/files/2018/10/06/c9f24f28-42dd-4046-aa9b-1d0b7622142e.pdf),
printed pages 22–23 and 26–35. Creature identities were checked against native
placement artwork and the manual. The local practice-level transcripts also map
brick/spade boxes to IDs 5000/5002 and umbrella/swimmer/clock boxes to
5005/5008/5009. Exact movement and
consumption constants still require original-engine traces.

The readers were implemented from these published format investigations,
then tested against the user's local data:

- [GuyPerfect: Lemmings 2 formats](https://www.camanis.net/lemmings/files/docs/lemmings_2_file_formats_guyperfect.html)
- [geoo89: Lemmings 2 level format](https://www.camanis.net/lemmings/files/docs/lemmings_2_level_file_format.txt)
- [Mindless and geoo89: Lemmings 3 level format](https://www.camanis.net/lemmings/files/docs/lemmings_3_level_file_format.txt)
- [geoo89 and ccexplore: Lemmings 2 style format](https://www.camanis.net/lemmings/files/docs/lemmings_2_style_file_format_l2gfx.txt)
- [Carl Reinke and Kieran Millar: lem3edit format implementation](https://github.com/kieranmillar/lem3edit/blob/master/src/style.cpp)
- [geoo89: Lemmings 2 sprite command formats](https://www.camanis.net/lemmings/files/docs/lemmings_2_sprite_file_format_l2ss.txt)
- [Carl Reinke and Kieran Millar: L3 CMP format investigation](https://github.com/kieranmillar/lem3edit/blob/master/src/cmp.cpp)
- [exit and RavenNine: Lemmings 2 physics research](https://www.lemmingsforums.net/index.php?topic=5886.0)

The Lemmings 2 overview contains inconsistent endianness descriptions. The
specific level-format document and local files agree on big-endian FORM
lengths, little-endian header/object fields, and big-endian terrain records.
Local VLEMMS data uses FORM type `L2VL`, not the documented `L2VG`. Its frame
and plane offsets are relative to the section payload, including the count.
Frame headers contain a self-pointer that independently confirms this base.
Chronicles palettes are masked to the six bits consumed by the VGA DAC.
The local files contain upper-bit values. Colour fidelity still needs a
side-by-side comparison with the original game.
