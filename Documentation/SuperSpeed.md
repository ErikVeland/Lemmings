# Variable speed and HD effects

HD effects are enabled by default. Choose **Old school** on the first launch,
or clear **Settings > Video > Effects > Enable HD effects**, to remove the speed
streaks and ghost trails. The HD switch preserves your chosen gameplay speed.
Old school also restores the original fixed-speed controls.

Modern controls and variable speed are enabled by default. Tap to keep fast-forward
on, or hold for a temporary boost. The first fast tier is 2×.

| Control | Action |
| --- | --- |
| Tap **F**, click **Speed**, or tap controller **RT** | Toggle fast-forward on/off |
| Hold **Shift**, **Speed**, or **RT** | Ramp through tiers; release to restore the previous speed immediately |
| Speed **‹ / ›**, **Shift+[ / Shift+]**, or **LT + D-pad left/right** | Choose 2×, 3×, 5× or 10× |
| **F**, **Escape**, controller **B**, or click **Speed** while fast | Return to 1× |

The arrows stop at 2× and 10×. While fast-forward is off, they choose the tier
for the next toggle without accelerating play. The panel shows the current multiplier and lights green while fast-forward is active.
At 1×, a smaller arrow label shows the tier for the next toggle. Its tooltip explains the hold.
Each level starts at 1× with a 2× first fast tier. Within a level, toggling off
preserves the chosen tier. Temporary boosts never replace it.

**Settings > Controller** can make RT hold-only. Escape, B and **LT + X** cancel
held boosts. Releasing a cancelled hold cannot restart speed. **Shift+\\** also
returns to 1×. Extra clicks and rapid taps after stopping cannot restart speed.
Double-click has no separate command and single clicks have no double-click wait.

A hold starts ramping after 0.25 seconds, with a new tier every 0.5 seconds.
Speed increases ease over 0.24 seconds. Speed decreases and hold releases take
effect immediately. Focus loss clears speed and held input. Pausing stops the
simulation and preserves the selected cruising speed.

The cyan engagement ring appears once. Streak motion continues across tier
changes, while brightness, colour and ghost strength blend with speed.
The centre remains clear, and the screen effect stops above the controls.

**Settings > Gameplay** has separate modern-controls and variable-speed switches.
**Preset > Original** restores fixed fast-forward and number keys. It also turns
off HD effects, pointer capture, enhanced sequel artwork, shuffle, DJ extras and
music enhancements. Saves, the chosen machine and volumes stay as set.
**Preset > Modern** restores the convenience switches. The original fixed
fast speeds remain 3× for Classic/L2 and 8× for L3 when variable speed is off.

Moving lemmings leave fading sprite echoes. The ghosts follow actual movement, including
slopes, falls, climbs, and direction changes. Stationary actors and teleports
do not create a wake. All solid sprites draw after the wakes.

Each fast tier adds a longer, softer tail: two echoes at 2×, three at 3×,
four at 5× and five at 10×. Distant echoes get fainter and blurrier as speed
increases. Neighbouring profiles blend during acceleration. Solid artwork stays sharp.

Variable speed also raises music pitch without changing its tempo. The 2×, 3×,
5× and 10× tiers use pitch ratios of 1.04, 1.09, 1.18 and 1.35 respectively.
Pitch glides take 120 ms in either direction and cannot exceed 1.50×.
This applies to native modules, recorded soundtracks and both DJ decks in all
three games. Returning to normal speed or leaving active gameplay restores
normal pitch. Fixed-speed OG controls keep normal pitch.

The effect runs in Classic flat and CRT modes, Lemmings 2, and Lemmings 3.
It works on SDR displays and adds HDR brightness when available. It does not
depend on the nuclear explosion setting. Explosions composite above the speed
effect. Pausing, returning to 1×, opening a game page, and leaving gameplay
stop the speed animation. The simulation uses whole original physics ticks at the selected clock rate.

## Rendering and limits

The screen effect shares the existing transparent Metal surface with explosions
and updates at approximately 60 Hz. Its time comes from the wall clock. Repeated
game updates do not restart the engagement burst. A simple radial-line effect
is available when Metal cannot initialise.

Actor wakes are baked into cached textures at the artwork resolution. Each
actor uses one additional texture draw at a settled speed, or two while blending
between speed tiers. The renderer allows at most 24 wakes
per frame and one per crowd cell. Camera movement does not affect their direction.

Direction is sampled from world positions on each game tick. A three-tick motion
history smooths pixel steps on slopes. A small angle tolerance stops cached
trail directions from alternating on shallow slopes. Reversals and changes between walking,
falling and climbing start a fresh direction immediately. Stops, teleports,
rewinds and removed actors clear their motion history. Skill changes between
ticks also clear the old wake.

Live frames and replay captures read the same direction for a tick. Extra
redraws, CRT composition, capture scaling and camera movement cannot change it.
Saved movies retain that direction when replayed or exported at another speed.
Previously recorded movies retain their original frames.

## Validation

- `Scripts/run-gameplay-speed-tests.sh` checks tiers, ramping, held-key combinations,
  rapid exits, focus recovery, the original fixed speeds and music pitch glides.
- `Scripts/run-adaptive-dj-playback-tests.sh` renders a tone through the actual
  recording graph at each speed. It checks pitch, unchanged tempo, the upper
  pitch limit and pitch routing to module and incoming recording decks.
- `TEST_SCOPE=variable-speed Scripts/run-app-integration-tests.sh` checks real key
  events, attached windows, and the actual simulation clock at every speed.

- `Scripts/run-explosion-hdr-tests.sh` checks actual FP16 speed output for SDR
  visibility, HDR brightness, animation, engagement, transparency, and clipping.
  It also checks pause/resume timing and all nuclear explosion regressions.
- `Scripts/run-playfield-draw-tests.sh` checks stronger, longer wakes, exact
  solid-sprite pixels, direction, pause, rewind, clipping, and crowd limits.
- `Scripts/run-app-integration-tests.sh` checks speed controls in flat and CRT
  modes, pause/resume, menus, results, and independence from explosion settings.
- `TEST_SCOPE=hd-effects Scripts/run-app-integration-tests.sh` runs the focused
  first-launch and effects checks, including saved choices and 3× gameplay with
  HD effects disabled.
- The sequel canvas checks verify L2 detach/return and L3 menu/resume behaviour.
- `Scripts/run-replay-movie-tests.sh` encodes and decodes 41 ghost frames with
  slopes, reversals, falls and climbs. It checks the decoded trail direction,
  repeated capture, camera shifts, and different live/replay render rates.
- `Scripts/run-explosion-hdr-tests.sh --speed-preview .build/super-speed-preview`
  writes transparent SDR frames for visual inspection over a game image.

A GPU timing sample on the development Mac measured about 1.7 ms for the
screen effect at 2560×1440. This excludes the base game render and is not a
guarantee for other displays or GPUs.

### Speed feedback checks, 25 September 2026

The speed-state and Classic drawing suites passed. Offline audio measurements
passed at all five speeds, including the pitch cap and unchanged tempo. The
DJ module and incoming recording checks also passed. Focused L2/L3 canvas
checks passed for sprite layering, controls, menus and effect lifetimes.
The 2×, 3×, 5× and 10× renders were generated for all three games.

The following gaps were recorded before build 50. See the
[build 50 release record](ReleaseReadiness/1.5PublicRelease.md) for current results:

- The installed music library fails the sequel alternate-version assertion.
  The pre-change playback code at `e894667` fails the same assertion.
- Classic's variable-speed integration checks pass, but the later CRT minimap
  drag assertion fails.
- The full sequel app suite calls removed Settings preset methods and cannot
  compile. The canvas checks above ran separately from those Settings tests.
