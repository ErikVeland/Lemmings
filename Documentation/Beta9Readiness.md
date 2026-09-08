# Beta 9 readiness

Prepared 8 September 2026 from `41925c0`, with the build-number change and
the Lemmings 2 walker artwork correction described below.

## Package

- Version 0.1, build 9. Full package with recorded soundtracks.
- Archive: `.build/local/UltimateLemmings-0.1-beta9.zip` (418,409,844 bytes).
- Both the app and NxlvKit library contain arm64 and x86_64 code.
- Both executable architectures declare macOS 13.0 as their minimum version.
- Developer ID signing and strict signature verification passed.
- Apple accepted notarization submission `e1b3f12a-df25-455c-89da-d153cd74a122`.
- The ticket was stapled and independently validated.
- The extracted ZIP, marked as downloaded, passed Gatekeeper as `Notarized Developer ID`.
- SHA-256: `0d1c3d3fa1b672d5ee5b731a2aaa43c9c3511997ea27f654c65fa2efe652e42f`.

The checksum sidecar and `ReleaseNotes-beta9.md` accompany the ZIP.
Earlier beta archives remain under `.build/local/archive/`.

## Lemmings 2 artwork correction

The reported Beach 1 scene exposed a gap in the conversion. The Settings
checkbox changed terrain, but all sixteen Beach walker frames retained their
original pixels. The general character rule expected green hair and pale skin.
Tan skin and several other tribe palettes did not match it.

The walker now uses its defined palette roles for clothing, hair and skin.
All twelve tribes receive the Macintosh-style face, eye, cuffs and shoes.
Hair retains its tribe colour. Source data, frame origins, opacity, animation
timing and gameplay geometry remain unchanged. Artwork cache revision 5
separates the corrected images from earlier cached frames.

The canvas test helper also needed an access-control correction before it
could compile with the private menu-canvas type.

## Validation

- All 22 beta regression suites passed again after the artwork correction.
  The additional slim-package, CRT, viewport and playfield checks passed too.
- Final app integration checks passed on arm64 and under Rosetta for x86_64.
- All five Swift parser tests passed. The explosion tests passed their actual
  FP16 GPU output, brightness bounds, unchanged background and expiry checks.
- Artwork validation passed for 59,542 frame variants and 214 levels, including
  all 192 walker variants and 120 checked-in visual hashes.
- Four existing walker hashes changed as intended. The remaining existing
  hashes stayed unchanged, and 44 walker checks were added for the other tribes.
- Actual canvas checks passed for all twelve L2 tribes and all three L3
  environments. Switching back to PC artwork reproduced the original image.
- A test clicked the real Settings checkbox with the Beach player attached to
  a shared window. The image changed and restored while gameplay, selected
  skill, pause and camera state remained intact.
- The corrected Beach canvas was visually inspected. Before the correction,
  the running app reproduced the unchanged walker with the setting enabled.

The final rebuilt app was not relaunched for another live UI check. The UI
automation tool repeatedly reported that the app had changed and declined
further actions. The corrected controller and Settings path were verified by
the actual-view test above. Physical Intel hardware and older macOS versions
were not available. GPU values above standard white were verified, but physical
HDR luminance was not measured.

Feature limits remain in `ReleaseNotes-beta9.md`.

## Evidence

- `.build/beta9-package.log`
- `.build/beta9-final-regressions.log` and `.build/beta-regressions/`
- `.build/beta9-final-integration-arm64.log`
- `.build/beta9-final-integration-x86_64.log`
- `.build/beta9-swift-tests.log`
- `.build/beta9-explosion-hdr.log`
- `.build/beta9-sequel-artwork-verified.log`
- `.build/beta9-sequel-canvas-fixed.log`
- `.build/sequel-mac-artwork/levels/l2-beach-settings-mac.png`
