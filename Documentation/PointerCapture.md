# Pointer capture

During play, the pointer stays inside the game on its current display. This keeps
edge scrolling active when another monitor sits beside the game. Capture is on
by default for classic campaigns, fan levels, Lemmings 2 and Lemmings 3.

Hold **Option** to move the pointer outside the game. Pausing, opening a menu or
switching apps also releases it. Return the pointer to the game to capture it
again. To turn capture off, clear **Settings → Video → Pointer → Keep pointer
inside the game**. The choice persists and survives a graphics preset change.

`GamePointerCapture` samples the absolute pointer position before each display
update. It clamps the position one point inside the visible game area, clipped
to the window's display. AppKit-to-Quartz conversion uses the primary display's
top edge. Negative display origins and different display scales retain their
logical coordinates.

The views receive the corrected position directly because
[cursor warps](https://developer.apple.com/documentation/coregraphics/cgwarpmousecursorposition%28_%3A%29)
do not generate mouse events. Classic CRT scrolling also accepts the curved black
border, while clicks retain their original image bounds. Lemmings 2 retains
held pointer input across the boundary.

Capture starts only after the pointer is inside the game. Focus loss, display
changes, window closure, live resizing and system menus reset it. The game does
not disconnect the mouse from the system cursor.

Run `Scripts/run-pointer-capture-tests.sh` for simulated crossings on all four
sides, repeated left scrolling, release and reacquisition, moved windows, and
coordinate conversion. The tests do not move the system cursor.
`Scripts/run-settings-tests.sh` checks migration and the saved opt-out.
`Scripts/run-explosion-hdr-tests.sh` includes the CRT border regression.

For a physical display check, play a level beside another monitor and hold the
pointer against the left edge. Scrolling must continue. Check Option, pause,
menus and app switching, then repeat after moving the game to another display.
