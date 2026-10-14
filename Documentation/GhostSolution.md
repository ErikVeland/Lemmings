# Ghost solution

Classic offers a default-off **Ghost solution** checkbox beneath the shared
Your game / Solution selector on Mac, iOS and tvOS. It appears after the existing
full-solution reveal confirmation. The whole stone row is one input target.
Its checked shape, accessible value and focus state distinguish on, off and focus.

The overlay uses sharp, translucent blue silhouettes with an outline from the
current sprite artwork. Draw ghosts behind the live lemmings, before camera and
CRT projection. Ghosts add no targeting, assignment feedback, countdown labels,
sound or input surface. They do not change skill stock, records or run ownership.

`ClassicSolutionGhost` owns a separate simulation, terrain and replay commands.
Rendering synchronises it to the live game's simulation tick. Speed changes,
paused stepping and rewinds therefore follow the live game. With the checkbox
off, the cursor stays parked until the next enable. It reconstructs the matching
tick when enabled during a run. Ten-second checkpoints and a bounded sprite cache
limit repeat seeking and rendering work. Playback stops at the solution's end.

This cursor is separate from the retained Solution view's tick, camera and speed.
Toggling the ghost preserves the current pause or Ready state. Switching views
continues to pause both. A same-level retry for the same owner retains the choice
and synchronises the ghost to the new attempt. A different level or Hot Seat owner
does not inherit the revealed solution or ghost.

Only sprites are overlaid. The ghost follows its own solution terrain, so bridges
or tunnels absent from the live attempt can leave ghosts above ground or inside
terrain. A different release rate can also separate live and solution lemmings.
The overlay demonstrates the recorded route and timing, without making moves.

Verified solutions currently cover Classic and matching Classic fan levels.
Lemmings 2 and 3 retain their existing coaching and checkpoint flows. They do not
offer this toggle because their verified-solution adapters and data are absent.
Recorded movies cannot provide simulation sprites.

## Validation

- Shared cursor tests compare scheduled and after-tick actions, release-rate
  changes and nuke against the replay player. They cover repeated paused ticks,
  backward and forward seeks, start and completion, changed level data and live
  simulation isolation. Pixel tests cover transparent space and the outline.
- The existing retained replay and sequel checkpoint regressions pass.
- `Tools/IOSMenuAudit` with `--ghost-solution` verifies unchanged live checkpoints,
  silent ghost seeking, retained study position, opaque live sprite priority,
  rewind, retry and changed-level rejection. Ten on/off renders cover narrow
  phone, phone, landscape, iPad and TV sizes and checkbox bounds.
- The retained-solution pause audit adds the checkbox row to the live selector.
  Forty pause renders and input checks cover both modes, start/move/end states
  and the smaller body area beneath the expanded selector.
- The native Mac retained-solution check presses the actual checkbox and checks
  its hit target. Offscreen, muted captures verify sprites and checkbox artwork.
  It checks running/paused toggles, retained study position, live rewind, Hot Seat
  Ready state, same-owner retry and different-owner invalidation.
- The Mac app and shared frontends compile for Apple silicon Mac, iOS and tvOS.

Native checks run through `Tools/UITestRunner/run.py` in its default offscreen,
muted mode. The focused build uses isolated shared modules to avoid another
task's SwiftPM build lock. AppKit registration requires the same offscreen
runner outside the filesystem sandbox. Physical touch, Siri Remote focus,
VoiceOver and CRT/HDR display appearance remain manual device checks.
