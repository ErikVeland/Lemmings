# Variable speed and HD effects

HD effects are enabled by default. Choose **Old school** on the first launch,
or clear **Settings > Video > Effects > Enable HD effects**, to remove the speed
streaks and ghost trails. The HD switch preserves your chosen gameplay speed.
Old school also restores the original fixed-speed controls.

Modern controls and variable speed are enabled by default. Set a cruising speed
with deliberate taps, or hold a boost key temporarily.

| Control | Action |
| --- | --- |
| Tap **F** or click **Speed** | 1× → 2× → 3× → 5× → 10× → 1× |
| Hold **F** or **Shift** | Ramp through the speed tiers; release to return to the selected cruising speed |
| **Shift+[ / Shift+]** | Step down / up |
| Double-tap **F**, double-click **Speed**, **Shift+\\**, or **Escape** | Return to 1× immediately |

Controller **RT** follows the same tap, hold, release and double-tap behaviour.
**LT + D-pad left / right** steps the selected speed. **B** or **LT + X** returns to 1×.
**Settings > Controller** can make RT hold-only. A quick exit cancels a held boost so releasing RT cannot restore fast-forward.

Rapid taps are presses within 0.3 seconds. OS key repeat does not count as a tap.
Holding starts the ramp after 0.25 seconds, with a new tier every 0.5 seconds.
Ordinary speed changes ease over 0.24 seconds. Quick exits clear pending fast
updates. Focus loss also returns to 1×. Pausing stops simulation time and keeps
the selected cruising speed.

The cyan engagement ring appears once. Streak motion continues across tier
changes, while brightness, colour and ghost strength blend with speed.
The centre remains clear, and the screen effect stops above the controls.

**Settings > Gameplay** has separate modern-controls and variable-speed switches.
**Use OG settings** restores fixed fast-forward and number keys. It also turns
off HD effects, pointer capture, enhanced sequel artwork, shuffle, DJ extras and
music enhancements. Saves, the chosen machine and volumes stay as set.
**Use modern defaults** restores the convenience switches. The original fixed
fast speeds remain 3× for Classic/L2 and 8× for L3 when variable speed is off.

Moving lemmings leave longer energy wakes with an amber filament, cyan glow,
and three fading sprite echoes. The wakes follow actual movement, including
slopes, falls, climbs, and direction changes. Stationary actors and teleports
do not create a wake. All solid sprites draw after the wakes.

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
actor uses one additional texture draw. The renderer allows at most 24 wakes
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
  rapid exits, focus recovery and the original fixed speeds.
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
