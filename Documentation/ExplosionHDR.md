# Cinematic nuclear explosions

HD effects, including cinematic nuclear explosions, are on by default. On the
first launch, choose **Play with modern defaults** or **Old school**. The choice is
saved. **Settings > Video > Effects > Enable HD effects** changes it later.
The separate **Explosions** control can disable cinematic blasts while retaining
speed effects. Existing saved explosion choices remain intact until the player
chooses the HD preset.

When enabled, a detonation produces a white flash, a second exposure bloom,
an expanding fireball, a pressure ring, scattered light, and a rising cloud
that cools into smoke. The effect lasts 1.8 seconds. It draws at the window's
resolution and starts at the visible explosion position. Classic CRT mode
maps that position through the tube's curvature. L2 and L3 use the same effect.
The animation uses wall-clock time, so pausing or fast-forwarding the game
does not freeze or shorten it. Frame stepping can also trigger a blast.

The effect remains visible when display headroom is 1. HDR adds brightness to
the same animation, up to the lesser of eight times SDR white and the screen's
current headroom. The previous full-screen shader returned transparent pixels
at headroom 1, which made the enabled setting appear to do nothing on SDR
screens and on HDR screens with no current extra headroom.

During a nuke, at most eight local blasts run at once. Whole-screen exposure
blooms start at least 900 ms apart. Turning the option off, changing levels,
or rewinding clears active cinematic effects. The effects do not intercept
mouse input or change terrain damage, game timing, or rescue rules.

## Rendering

A transparent Metal layer uses `rgba16Float`, extended linear sRGB, and Apple's
EDR display path. The procedural shader generates fire turbulence, cooling,
the rising cloud, pressure front, and lens glow. It composites premultiplied
colour over the game and controls. Unchanged core masks are reused between
animation frames. The overlay redraws at approximately 60 Hz while a blast is
active and stops scheduling frames after expiry.

If Metal is unavailable, AppKit draws a simpler white flash, radial fireball,
and expanding ring. With the cinematic option disabled, the original short
pixel explosion and local HDR highlights remain in place. Flat mode uses a
transparent overlay for those highlights. CRT mode uses its existing source
mask. These local highlights retain their original SDR fallback. Turning off
HD effects removes the cinematic blast and local highlights, and restores the
original classic sprite explosion animation.

## Validation

- `Scripts/run-explosion-hdr-tests.sh` renders the actual Metal shaders to
  FP16 textures and reads their pixels back. It checks visible SDR exposure,
  HDR peaks, changing fireball frames, pressure-ring expansion, blast position,
  valid premultiplied colour, expiry, nuke limits, and CRT coordinate mapping.
  It also retains the original local-core and CRT regression checks.
- `Scripts/run-playfield-draw-tests.sh` checks PC/Mac explosion frames, core
  expiry, panel input, and exact nuke undo.
- `Scripts/run-explosion-hdr-tests.sh --preview .build/explosion-preview`
  saves nine transparent SDR frames for visual inspection over a game image.

SDR PNG previews show shape, colour, and timing samples. They cannot establish
physical HDR luminance. The test displays reported current headroom 1. GPU
output above SDR white is verified separately with simulated headroom 8.
