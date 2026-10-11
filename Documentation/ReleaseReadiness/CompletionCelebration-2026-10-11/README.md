# Completion celebration and Cellbash

The Mac learning journey previously excluded rescue-target telemetry from the
DJ. The opening-track hold also discarded completed-win celebration on short
levels. The journey now forwards those cues, and a completed win bypasses the
opening hold. Legacy music fades into an available lifted arrangement of the
same composition. Silent music and the alternates preference remain respected.

Classic, Lemmings 2 and Lemmings 3 share a subtle golden playfield rim. It fades
in over 1.4 seconds, stays steady, and clears on rewind or retry. Reduced motion
and reduced flashes skip the animation. Completed losses do not retain it,
including losses with a satisfied rescue quota. Qualifying shared result panels
use the same rim. The native sequel rescue policies remain unchanged: L2 uses
its existing `didWin`, and L3's current policy requires at least one survivor.

Learning-16 puts Cellbash immediately after Just dig! as lesson 2. Its exact
source revision and single-basher witness are unchanged. This placement follows
the owner's playtest; it does not certify the full discovery-review checklist.
Saved journeys retain their current lesson, history, owner and run ID. Every
unvisited lesson remains in the queue even when moved before the current lesson.

## Validation

- [Core tests](core-tests.log): 19 tests passed, including old learning-14/15
  migrations, Cellbash's second position, failure-state handling, golden pixel
  colour, alpha limits, clipping and an unchanged centre.
- [Muted DJ playback](dj-playback.log): completed wins during the opening hold,
  legacy arrangement selection, one-shot cues, preference handling, retries,
  same-composition score selection across the three engines and suspended fades.
- [Native compilation](native-compile.log) and [native runtime](native-runtime.log):
  the `celebration` integration scope passed through `Tools/UITestRunner/run.py`
  in its default offscreen mode with `LEMMINGS_TEST_AUDIO=muted`. It covers the
  actual journey's legacy/DJ win routing, Solo and paused Hot Seat handovers,
  win/loss states in all three engines, captures, restrained pixel coverage,
  result persistence and Menu/Q/Escape targets at multiple window sizes.
- [Journey generation](journey-generation.log) and the generator's `--check`
  passed for all 294 lessons and 1,627 review candidates.
- Actual Classic, L2 and L3 earned/inactive/reset captures and shared win/loss
  result captures were inspected. The captures remain in ignored
  `.build/celebration-renders` and `.build/exit-progress` with the commercial art.

Apple's audio equalizer service could not initialise in the sandbox. The same
muted, offscreen audio checks passed with service access outside the sandbox.
The isolated integration setup now loads its own interface, campaign and level
catalogue. Nested symlink fixtures were replaced by local resource copies so
Foundation could enumerate the campaigns. Native build scripts now include the
shared `LemmingsGameArt` module.

## Local Mac test app

The separately built app is
`.build/celebration-beta/Ultimate Lemmings.app`. It is an unoptimised arm64
development candidate with an ad-hoc signature and a distinct bundle ID. Its
inherited version metadata is 1.9.1 (76); it is not a published release.
[Build and signature verification](candidate-build.log) passed. Packaged game
data, all four current RGBA artwork families and learning-16 are checked in
[candidate-resources.log](candidate-resources.log). It was not launched in the
foreground or installed over the user's current app. See
[source hashes](source-sha256.txt) and [candidate hashes](candidate-sha256.txt).

The native tests were muted; listening acceptance and composited CRT acceptance
were not run. These Mac results do not establish UIKit or device parity. The
installed iPad build 8 has no music player and does not contain this change.
