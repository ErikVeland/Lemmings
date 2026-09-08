# Explosion HDR

The explosion core uses Apple's extended dynamic range (EDR) display path.
Its first tick is white and its second tick is yellow at a lower peak. The
remaining burst keeps its normal SDR colours and ends after four ticks.

Flat mode composites a transparent Metal surface over the AppKit playfield.
CRT mode supplies a separate source-coordinate flash mask to the final shader.
Both use `rgba16Float` output, extended linear sRGB and
`wantsExtendedDynamicRangeContent`. The CRT shader converts its existing SDR
output to linear sRGB before adding the selected HDR pixels. Ordinary scenery
and controls cannot acquire HDR highlights from their colour alone.

The peak is `min(4, current screen headroom)`, in multiples of SDR white.
No fixed nit value is assumed. The screen is checked at presentation, including
after a window moves between displays. An EDR surface remains ready while idle,
so a short flash does not have to enable the display mode from scratch. If the
current headroom is 1, the original SDR core is retained. If Metal is unavailable,
the flat AppKit rendering remains available.

Flash masks follow the first two animation ticks and carry a wall-clock expiry.
The flat overlay schedules a clear even when the simulation is paused. CRT
presentation checks the same expiry on each display update. Undo and a new game
reset flash event tracking. Masks submitted to the GPU are not modified in place.

Validation:

- `Scripts/run-explosion-hdr-tests.sh` renders both shaders into FP16 textures
  and reads GPU output back. It checks 4× peaks, lower yellow peaks, transparency,
  unchanged SDR scenery, bounded headroom, clipping and expired masks.
- `Scripts/run-playfield-draw-tests.sh` checks the real PC/Mac flash frames,
  their short HDR masks, input controls and exact nuke undo.

An ordinary PNG is an SDR preview and cannot prove on-screen HDR luminance.
The test host reported a Studio Display with potential headroom 2 and a second
display with potential headroom 1. Both reported current headroom 1 during the
headless test. GPU values above SDR white were verified; peak physical luminance
was not measured.

Implementation references: Apple's [EDR layer property](https://developer.apple.com/documentation/quartzcore/cametallayer/wantsextendeddynamicrangecontent)
and [custom tone-mapping guidance](https://developer.apple.com/documentation/metal/performing-your-own-tone-mapping).
