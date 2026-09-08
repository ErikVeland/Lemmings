# Beta 9 readiness

Prepared 8 September 2026. The initial release used `41925c0` with the
build-number change and Lemmings 2 walker artwork correction. This package
adds the widescreen panel fill to release commit `ae4d51f`.

## Package

- Version 0.1, build 9. Full package with recorded soundtracks.
- Archive: `.build/local/UltimateLemmings-0.1-beta9.zip` (418,410,971 bytes).
- Both the app and NxlvKit library contain arm64 and x86_64 code.
- Both executable architectures declare macOS 13.0 as their minimum version.
- Developer ID signing and strict signature verification passed.
- Apple accepted notarization submission `02e41bdc-db7e-4fd8-af3e-9a373f1f8d67`.
- The ticket was stapled and independently validated.
- The extracted ZIP, marked as downloaded, passed Gatekeeper as `Notarized Developer ID`.
- SHA-256: `f3ce59b2b731348cbe3df018ca2368ac02a07dee778fd91b9d5595636788da53`.

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

## Widescreen panel follow-up

The Lemmings 2 panel background now spans the full window width beneath the
playfield. It uses the same palette entry as the central panel. The control
artwork remains centred at its original size.

The actual canvas was rendered in PC and Macintosh-style modes at 960 × 720,
1280 × 720 and 1920 × 720. Samples from both side margins matched the central
panel background at the top, middle and bottom of the bar. The widescreen
result was also visually inspected.

Evidence: `.build/beta9-panel-fill-checks.log`,
`.build/beta9-panel-fill-preview.png`, and `.build/beta9-panel-fill-package.log`.

## Earlier beta 9 validation

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

- `.build/beta9-panel-fill-package.log` (current package)
- `.build/beta9-package.log` (initial package)
- `.build/beta9-final-regressions.log` and `.build/beta-regressions/`
- `.build/beta9-final-integration-arm64.log`
- `.build/beta9-final-integration-x86_64.log`
- `.build/beta9-swift-tests.log`
- `.build/beta9-explosion-hdr.log`
- `.build/beta9-sequel-artwork-verified.log`
- `.build/beta9-sequel-canvas-fixed.log`
- `.build/sequel-mac-artwork/levels/l2-beach-settings-mac.png`
