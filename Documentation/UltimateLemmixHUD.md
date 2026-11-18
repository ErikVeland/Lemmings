# Ultimate Lemmix HUD artwork

The Classic gameplay HUD uses the original lettering in the personal preview
and Lix's own UI font in clean builds. Both use actual Lix skill and transport
icons. The shared buttons use synthesised stone, including Home and timeline
controls. Transparent icon padding is removed before fitting. Half-step scaling
uses the 2× artwork to fill each existing input target.

## Typography

`PanelView` obtains its original font from `GameMenuArtwork` without requiring
an imported campaign's Mac artwork. `GameTypography.drawInterfaceText` also
supplies the source face to compact labels, quantities, speed and zoom badges.

The original small face has 12×18 source cells. At the usual 3× HUD size,
skill captions have 66×18 logical cells with a gap between adjacent names.
At 2×, every peer caption uses the same half-size source face. Speed uses the
normal counter size instead of expanding to fill its socket.

Clean builds use Lix's unchanged DejaVu Sans Condensed Bold 2.29 font.
The exact TTF and full Bitstream Vera/Arev notice are separate from the CC0
graphics pack. `LixInterfaceText` rasterises that font at whole pixel sizes
and rejects unavailable glyphs instead of choosing a system font.
Its paragraph fitter uses measured glyph widths and returns complete text
or a failed fit. Mobile multiline labels use that fitter.

## Buttons and input

`LixInterfaceArtwork` decodes the authored skill, transport and checkbox
sheets. It removes their grid separators and transparent source colours,
uses the garden player palette and retains the authored disabled skill row.
Missing Lix semantics remain explicit. Menu actions keep their text labels.

The Mac HUD, timeline, speed arrows and shared controls use the AppKit image
cache. The mobile HUD and pixel buttons use the UIKit adapter. Pause changes
to Play, and an active End Run changes to Undo. The visual change does not
alter skill rules, the simulation tick or saved-run identity. The expanded
Classic skill cells keep their visible bounds and input targets aligned.

The primary Lemmings 2 and 3 panels still use their imported native artwork
and font banks. Their shared timeline and speed controls use the Lix adapter.
Home navigation rows retain their layout and use the shared stone sockets.

## Current presentation — 18 November 2026

The character choice no longer replaces stone with plain Lix button fills.
`GamePlayButtonArt` retains its existing synthesis for imported artwork and
has a deterministic generated fallback when those source banks are absent.
Home settings and update icons use the full socket well.

Lemmix restores HD effects and cinematic explosions once. It preserves motion
and flash reductions, then respects later settings changes. Apple TV retains
its existing cinematic and EDR limits. Rewind, speed trails, selection glows,
Hot Seat, hints, modern controls and saved-run features use the shared frontend.
No engine rule changes are part of this update.

## Earlier verification

The source checks cover four complete personal-window states: running,
paused, Undo End Run and the narrow window. A separate clean-window case uses
the bundled Lix font. Each checks 19 HUD input targets. Full-window and panel
captures were inspected after the caption spacing and speed-size fixes.
Seven existing menu, community and scene cases also pass.

The shared interface suite checks actual source pixels, enabled/disabled skill
rows, selected/pressed/disabled controls, button colours and invalid inputs.
The font suite checks the exact typeface, palette, dimensions, glyph bounds
and complete paragraph fitting. Automated checks stay offscreen and muted.

Build 3 evidence is retained under
`Documentation/ReleaseReadiness/ultimate-lemmix-0.1-build3`.
Original-art captures stay in ignored local build folders.
UIKit rendering, touch, tvOS focus and physical-device acceptance need their
platform runtimes and devices. A successful SDK build does not establish them.

The [final HUD record](ReleaseReadiness/ultimate-lemmix-0.1-build3/hud-validation.json)
includes the five packaged-engine runs. All ten final full-window/panel PNGs
match the inspected captures byte for byte. The
[four-candidate audit](ReleaseReadiness/ultimate-lemmix-0.1-build3/final-audit.json)
records the clean/personal Mac, iOS and tvOS source snapshots and six archives.
The separate [manual review copy](ReleaseReadiness/ultimate-lemmix-0.1-build3/manual-review-launch.json)
was opened with its own sandbox and preferences. It preserves the canonical
resource bytes and does not share saved games with the earlier personal app.
