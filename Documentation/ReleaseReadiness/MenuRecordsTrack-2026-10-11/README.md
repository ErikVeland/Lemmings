# macOS menu access, Records navigation and track notices

The shared pointer capture now releases at the window’s top four points. The
pointer can reach the title bar and macOS menu bar, including the hidden bar in
full screen. Capture stays released while a native menu tracks input. Returning
below the strip after the menu closes reacquires capture. Side and bottom edges,
Option release, focus changes, system sheets and moved-window handling remain.
The same capture class serves Classic, Lemmings 2, Lemmings 3 and game pages.

Records Previous/Next formerly navigated an alphabetic list of attempted
boards. It could not move through unplayed campaign levels. The shared Records
page now takes the campaign or pack order from the active engine. Classic uses
its campaign, fan packs use their queue, NeoLemmix uses its catalogue pack, L2
uses the current tribe’s ten levels and L3 uses the current tribe’s campaign.
Standalone files use saved boards. Unplayed levels have empty boards without
invented conditions or verified targets. Saved levels retain the latest recorded
conditions, with the current level’s conditions preferred. First/last outward
actions are disabled. Left/right arrows reach level navigation instead of the
generic button-focus loop. Browsing does not change game selection, progression
or Hot Seat ownership.

All three Mac engines show a shared stone notice for a changed track URL. Its
rows use the catalogue composition title and soundtrack name from the library
index. User files fall back to their filename/module title and source folder.
The original Macintosh bank is identified separately as Macintosh (original).
Classic’s persistent song-status captions are replaced by this single notice.
The notice stays for four seconds, fades for half a second, accepts no pointer
input and includes both names in accessibility. Reduced motion keeps it steady
until expiry. Silent music clears it. Results and handovers hide it. Track
polling covers legacy modules, recordings and DJ/celebration variant changes.

## Validation

- [Pointer checks](pointer-tests.log) passed through `Tools/UITestRunner/run.py`
  with its default offscreen/muted environment. They cover four display
  positions, side/bottom edges, top escape and reacquisition, Option release,
  moved windows, capture gates and native menu begin/end notifications. They
  never move the system cursor.
- [Full native runtime](native-runtime.log) passed the `celebration` scope with
  actual Classic/L2/L3 campaign Records providers, real mouse events, arrow keys,
  unplayed boards, first/last endpoints and compact/large targets. Saved career,
  current gameplay and turn ownership were unchanged by browsing. Existing
  celebration, precision rewards and paused handover checks still passed.
- The first render inspection found a truncated Next caption. Both navigation
  buttons now have 244-point widths. [Final compilation](final-compile.log) and
  [focused native runtime](final-runtime.log) passed the `menu-records-track`
  scope after that repair and the Macintosh metadata addition. The final checks
  measure caption fit, render all four engine identities, exercise real pointer
  and key actions, and check catalogue title/source resolution, Macintosh bank
  identity, changed variants, expiry, reduced motion, accessibility, silent music
  and notice input passthrough. No track is played audibly.
- Final first/adjacent/last Records states and song notices at compact/large sizes
  were inspected. Commercial artwork captures stay in ignored
  `.build/menu-records-track-renders`.

All native runtime checks used the required runner with `LEMMINGS_TEST_AUDIO=muted`
and the default offscreen mode. Apple’s equalizer service required access outside
of the sandbox. This did not change window or audio policy. Native local code was
recompiled against unchanged shared modules after the small UI repairs.

## Separate Mac candidate

`.build/menu-records-track-beta/Ultimate Lemmings.app` is a separate unoptimised
arm64 preview with an ad-hoc signature and automatic updates disabled. It retains
1.9.1 (76) metadata and is not a published release. [Initial build](candidate-build.log),
[final executable/signature verification](candidate-rebuild.log) and
[packaged resources](candidate-resources.log) passed. It contains Classic, L2,
L3, all four RGBA artwork families and learning-17. Its game resources were
preserved during the executable rebuild. [Final source hashes](source-sha256.txt)
were unchanged through final compilation/testing; [candidate hashes](candidate-sha256.txt)
identify the build. It was not launched or installed over the user’s running app.

## Scope

These changes are in the Mac AppKit front end. The pointer policy tests use
injected positions and never warp the user’s cursor. Native automated tests must
remain muted and offscreen. Actual macOS menu tracking under the user’s pointer,
composited CRT acceptance and audible soundtrack acceptance require manual
checking. This turn does not install or update the iPad app.
