# Ultimate Lemmings 1.5 test build 43

Build: 43

Fixes the slow startup in test build 42.

- Game Center test builds now use compiler optimisation by default.
- Empty HDR overlays skip full-screen mask allocation and GPU submission.
- Active flash masks avoid an allocation for every screen pixel.
- Menu music waits until the initial window transition and first frame submission.
- The launch gate now checks first-frame timing and audio ordering, as well as crashes.

This build includes all changes in consolidated 1.5 build 42. It is an
Apple-silicon Game Center test build for registered Macs, without notarisation.
Lemmings 2, Lemmings 3 and NeoLemmix retain their Preview status.
