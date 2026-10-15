# Classic Pause and Nuke artwork

The Classic panel uses the paw and explosion tiles from the bundled Amiga
`Sources/Ports/amiga_extracted/lemmings/panel1` artwork. It replaces the custom
pause bars and simplified mushroom cloud. Resume remains a play triangle.
An undoable Nuke remains an undo arrow.

The source is a 640×40 image with four planar bitplanes. The two controls occupy
32×24 cells at (320,16) and (352,16). The embedded tiles omit two pixels on each
horizontal edge and one on each vertical edge. This retains the original icon
pixels while the shared stone controls supply the border. The panel artwork
uses half-width horizontal pixels in the 320-wide game panel.

Every Classic panel control shows panel rock behind its glyph. The speed box
repeats the rock tile side by side. It uses the same crop
from the ten skill cells at (0,16) to (288,16). The lemmings and counter boxes
cover the middle of every cell, so the check script rebuilds those pixels:

1. Below the counter box, use the rock colour that most cells agree on.
2. Where the cells do not agree, copy the nearest settled rock pixel in the
   same row, about half a cell away.
3. Under the counter box, mirror the rows below it.

Every rock pixel is an original panel colour. The arrangement in the middle of
the tile is rebuilt, not recovered.

The Pause and Nuke tiles draw at the scale that fills the button. The stone
bevel covers their outer rock edge.

Classic Macintosh skill buttons crop transparent sprite padding and share one
source-pixel scale across all eight poses. The widest tool pose and tallest
umbrella set the fit. Visible artwork stays centred on a common bottom edge,
with whole display-pixel scaling and nearest-neighbour sampling. Colour and
1-bit artwork use the same rule. Button bounds, counts and selection stay in
their existing positions. L2 and L3 retain their authored panel tiles.

Mac Classic's 1-bit mode also uses the original dithered rock from `Charset0`
frame 95. The 28×44 crop at (38,0) keeps the background dark behind the white
lemmings. A one-pixel black sprite edge separates them from the rock dots.
Bevels, control silhouettes, counters, captions, speed arrows and
selection underlines use black and white. Disabled timeline symbols use a
checker stipple. Colour modes retain their existing artwork. L2 and L3 do not
offer Classic's 1-bit artwork option.

The 16-colour display palette was matched to the user's reference. It is an
approximation, not a recovered original hardware palette. The image shapes are
direct source pixels, not new illustrations. The discarded DOS variant had
different shapes and insufficient colour detail for this reference.

Run `python3 Tools/ClassicPanelArt/check.py` to compare every embedded pixel
index with the original Amiga file. Run `zsh Scripts/run-playfield-draw-tests.sh`
to check rendering, input targets, Nuke gestures and restored game history.
The panel renders at five widths, with extra captures for Resume, Undo and the
DOS-panel fallback under `.build/panel-label-regression`.

L2 continues to use its `PANEL.DAT` control sprites. L3 continues to use its
`PANxxx.RAW` normal and pressed panels. Neither uses these Classic glyphs.
Their input, paused handover and turn ownership paths are unchanged. This work
does not add a new focus or disabled state to the existing Classic panel.

This source change follows the frozen beta 30 Game Center package. It is not
included in that archive.
