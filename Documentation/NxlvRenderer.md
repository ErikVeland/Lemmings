# Low-resolution NXLV renderer

`NxlvRenderer` converts a parsed `NxlvLevel` and an `NxlvStyleResolution` into a deterministic low-resolution level bitmap.

## Output

`NxlvRenderResult.renderedLevel` contains these row-major buffers:

- `rgba`: non-premultiplied RGBA8 presentation pixels.
- `solidMask`: nonzero for solid terrain.
- `steelMask`: nonzero for visible steel terrain.
- `oneWayEligibleMask`: nonzero for non-steel terrain placed with `ONE_WAY`.
- `oneWayMask`: a value from `NxlvOneWayDirection` after one-way gadget triggers are applied.

The result also contains static gadget bounds and renderer diagnostics. Style resolver diagnostics remain available in `styleDiagnostics`.

## Implemented rules

- PNG files are decoded through ImageIO into a fixed RGBA8 format.
- A terrain pixel is solid when its alpha is not zero.
- Terrain uses source order. `NO_OVERWRITE`, `ERASE`, steel replacement, and clipping update presentation and physics masks together.
- Resizable pieces use explicit dimensions, metadata defaults, and tiled nine-slice centers.
- Piece transforms use a 90-degree clockwise rotation, then horizontal flip, then vertical flip.
- Terrain groups can use earlier groups. Group member rectangles are normalized to their union before the group is placed.
- A group rejects mixed steel and non-steel content. Eraser members do not set the group material.
- The renderer tiles a static background PNG from the level origin.
- The renderer draws one static primary gadget frame. It supports object transforms, object resize metadata, `NO_OVERWRITE`, `ONLY_ON_TERRAIN`, and background objects.
- One-way gadget directions follow object transforms. Their trigger masks affect only final, eligible, non-steel terrain.

The implementation follows the public NeoLemmix level and style format documentation. It was written independently and does not include NeoLemmix source code.

## Safety limits

`NxlvRendererLimits` limits level pixels, PNG dimensions, decoded PNG pixels, compressed file bytes, and terrain-group pixels. The decoder checks that each resolved graphic stays inside its style directory. It also rejects non-PNG data, malformed PNG data, nonregular files, unsafe coordinate arithmetic, and invalid nine-slice dimensions.

## Current limits

- The renderer uses low-resolution graphics only.
- Style aliases and high-resolution variants must be resolved before rendering.
- Theme background colors and theme-based object recoloring are not applied.
- Static gadgets use only the primary animation. Secondary animations, live animation, digits, and state changes are not drawn.
- `RANDOM` initial frames use frame 0 and produce a warning.
- Moving background gadgets produce a static snapshot and a warning.
- Trigger masks are clipped to the resized primary graphic. Object physics other than directional one-way masks belongs to the NeoLemmix simulation layer.
- Terrain-group bounds and resized trigger behavior need comparison against canonical NeoLemmix screenshots before pixel-perfect compatibility can be claimed.

## Verification

Run:

```sh
zsh Scripts/run-nxlv-renderer-tests.sh
```

The tests generate PNG style assets in a temporary directory. They cover transforms, alpha solidity, draw flags, steel, directional one-way masks, nested groups, invalid groups, default and explicit resize, tiled nine-slice output, clipping, background tiling, primary gadget frames, unsafe paths, coordinate overflow, malformed PNG files, and all image limits.

Format references:

- [NeoLemmix level file format](https://www.lemmingsforums.net/index.php?topic=4336.0)
- [NeoLemmix style format](https://www.lemmingsforums.net/index.php?topic=4337.0)
