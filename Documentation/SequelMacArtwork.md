# Macintosh-style sequel artwork

## Reference study, before sequel conversion

The source study uses the supplied DOS and Macintosh releases of Lemmings,
Oh No! More Lemmings, Xmas 1992 and Holiday 1994. `reference.swift` exports
2,703 matched terrain, object and sprite records. No image is interpolated.
Object sequences with different frame counts are excluded from automatic
correspondence. Equal frame counts do not prove equivalent animation phases.

Macintosh frames are often cropped and have signed origins. Comparing raw
file dimensions is therefore misleading. Terrain and objects are aligned by
their authored origins on a doubled DOS canvas. Sprite actor origins differ
between ports. Their measurement uses integer translation to maximise mask
overlap. This alignment is for analysis only, never sequel registration.

The first pass measures all matched terrain and object frames and the first
frame of each sprite sequence. A split block is an occupied 2×2 area with
more than one RGBA value, including transparency.

| Reference | Records measured | Occupied blocks split at 2× |
| --- | ---: | ---: |
| Lemmings terrain | 272 | 57.8% |
| Lemmings ordinary objects | 201 | 45.2% |
| Lemmings traps | 159 | 64.2% |
| Lemmings sprites | 30 | 45.0% |
| Oh No! terrain | 225 | 21.7% |
| Xmas / Holiday snow terrain, each | 37 | 7.7% |

These are descriptive measurements, not target edit quotas. Xmas and Holiday
share many assets and are not independent evidence. Liquid height and phase
differences make their raw pixel error unsuitable as a quality score.

Visual inspection of the reference sheet shows:

- Dirt adds short, clustered highlight and shadow marks inside existing
  material regions. Large colour masses and the original light direction remain.
- Brick mortar stays straight and regularly spaced. Flat fills retain blocks.
- Pebbles and snow refine stepped internal contours. Snow keeps much more of
  its enlarged source than the original dirt set does.
- Lemmings retain economical colour regions. Hair tips, faces and cuffs receive
  small integer-pixel changes. They are not given modern dark outlines.
- Metal exits retain separate dark joints and bright rivets. The hatch adds
  small marks and changes the border independently of its landscape insert.
- Water is materially redrawn, including its height. Its bright marks remain
  discrete pixels. A direct geometric transplant would violate this task's masks.

## Constraints on inference

The reference is hand-authored and is not the output of a universal scaler.
An automatic reconstruction cannot recover the artists' intent uniquely.
Category-specific neighbourhood rules can transfer observed colour boundaries,
but ambiguous shapes must retain the source block. They must not receive random
texture. Repeated animations must use the same rule without a time or frame seed.

For the sequels, source transparency takes precedence over reference silhouette
changes. Every transparent source pixel remains four transparent pixels. Every
opaque source pixel remains four opaque pixels. Reconstruction changes colour
within those masks. The pipeline must not copy the Mac water height, cropped
origins, altered proportions or frame timing into a sequel.

All generated images and comparison sheets remain under `.build/`, alongside
the supplied commercial data. The repository holds the generation code and
measured rule evidence, not copies of the game artwork.
