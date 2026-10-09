# Ultimate Lemmings 1.1 RC2 (build 38)

Build: 38
Release commit: 7edebfb8545a5b7554d6b36861279cd9d0eef68b
Release base: 957a813

This candidate fixes three build breaks in test and packaging scripts. It also
fixes a Bool-to-boolean_t compile error in pointer capture, and an
edge-scrolling bug in the CRT view's curved corners.

This candidate also reverts a steel-protection fix. The fix was correct on
its own, but it broke 57 of 352 official Classic completion routes. This
repository has no tool to re-solve those routes. All 352 routes and the
Trolley bonus catalogue now verify clean again. The steel fix is separate
follow-up work with its own re-verification pass.

## Known issues

- The L2 artwork toggle does not restore pixel-identical rendering after a
  round trip. See `Tests/SequelMacArtworkAppTests/checks.swift:180`.
- A controller button-combo sequence for retry, rewind, and step does not
  route as expected. See `Tests/AppIntegrationTests/checks.swift:160`.

Both predate this release and are unrelated to its changes.

## Changes since the previous release
- 7edebfb Fix CR2 build breaks and revert steel-protection regression
- 56f6c4f Merge branch 'claude/controls-cursor-visibility-bugs-6jsnce' into codex/1-1-qol-target-select
- c0deec4 CRT models
- 0915582 Classic: release pointer capture while a page is presented
- 09a0acc Fix system cursor going invisible during pointer capture

## Source files
M	Sources/LemmingsLocal/CRTShaders.swift
M	Sources/LemmingsLocal/CRTView.swift
M	Sources/LemmingsLocal/GamePointerCapture.swift
M	Sources/LemmingsLocal/main.swift
M	Sources/NxlvKit/ClassicDOSSimulation.swift

## Package targets
- Developer ID standard: notarised.
- macOS 12 Monterey: notarised.
- Game Center: development-signed for registered devices; not notarised.
