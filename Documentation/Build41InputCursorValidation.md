# Build 41 input and cursor corrections

Classic's local keyboard monitor handled key release as another command.
Only key-down events now reach commands after transport release handling.
Space and P repeats are ignored. Sequel key-down handlers also ignore pause
repeats. Lemmings 2 and 3 already receive commands only on key down.

The shared pointer restores the small crosshair from before build 38. The
skill sprite sits outside its lower-right corner. Classic now requests
right-facing skill artwork, with directionless artwork as a fallback.
The shared selection effect is a faint radial halo with gentle brightness
variation. Reduced motion disables that variation. There is no stroked ring
or rotating arc.

Validation:

- `zsh Scripts/run-playfield-draw-tests.sh` passed. This covers cursor bounds,
  badge alignment and edge clamping, targeting and panel input regions.
- Inspected `.build/selection-animated.png` and
  `.build/selection-reduced-motion.png`, rendered by the real Classic view.
- Full app integration builds compiled for arm64 and x86_64.
- Added `TEST_SCOPE=cursor-input` regression checks for Space and P press,
  repeat, release and second press. The runner crashed before these checks
  completed on both architectures. The arm64 crash points to the existing
  GameplayController timer and Swift main-executor check. Runtime pause
  verification therefore remains incomplete.
- Lemmings 2 and 3 use the same cursor, badge and selection renderer. Their
  pause handlers were inspected and compiled. Live sequel and Hot Seat
  validation were not run for this change.
