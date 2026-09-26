# Ultimate Lemmings 1.5 test build 42

Build: 42

This local Game Center test build consolidates all 1.2 changes through build 41
with the 1.5 source branch. It retains the 1.3 mobile source work. The supplied
Mac application does not include an iPhone or iPad app.

## Changes

- Includes the 1.2 first-launch, content-browser, soundtrack, updater, signing,
  rescue-proof and hint fixes.
- Space and P toggle pause once per press. Key release and auto-repeat no longer
  toggle pause again.
- Restores the pre-38 crosshair and places a tiny selected-skill sprite
  diagonally below its lower-right corner.
- Replaces the selection ring and rotating arc with a faint halo and gentle
  brightness shimmer. Reduced motion keeps the halo static.
- Includes the 1.5 NeoLemmix parser, renderer, simulation and replay-import
  baseline. NeoLemmix remains Preview. Fencer, Laserer and other documented
  mechanics remain unsupported.

## Test focus

Check pause and resume with Space, including holding and releasing it. Check
skill icons and target highlighting in Classic, Lemmings 2 and Lemmings 3.
Check saved-run recovery and paused Hot Seat handovers.

## Distribution

Apple Development signed Game Center build for registered Macs. This local
Apple-silicon test archive is not notarised. Lemmings 2 and Lemmings 3 remain
Preview. Full NeoLemmix compatibility and physical mobile validation remain
open. See `ReleaseReadiness/1.5NeoLemmixHandoff.md` for compatibility limits.
