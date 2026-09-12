# Beta 26 readiness

Version 0.1, build 26. Universal arm64 and x86_64 app; macOS 13 or later.

## Frozen inputs

Base revision: `0defd9fa`. The build ran from a separate checkout of that commit,
so no uncommitted work from the shared tree entered the archive. The commercial
game data directories are not in git. The checkout linked them read only. The
packaging step writes only into the app bundle and `.build`.

Included since beta 25:

- Main screen resume for solo and Hot Seat attempts.
- Hot Seat player change guards on the results and profile screens.
- Fan packs render with the terrain and special pictures in their own archives.
- Corrected release readiness counts.

Left out on purpose: the solution replay and hint work still in progress in the
shared tree at build time. It is unverified, so it waits for beta 27.

## Checks

All checks ran against the packaged revision before the build.

| Check | Result |
| --- | --- |
| Nine core regression suites | All passed |
| App integration suite | Passed |
| Classic completion gate | 120 of 120 routes, none failed |
| Campaign completion gate | 103 of 103 routes, none failed |
| Lemmings 2 runtime and routes | Passed, 64 recorded completions |
| Fan library, including pack artwork | Passed |

The campaign gate covers Oh No! 66, Holiday 1993 14, Holiday 1994 16, Xmas 1991
four and Xmas 1992 three. The Lemmings 3 gate verified 16 levels and reported 74
without a fixture.

The corpus audit records 85 fan levels that fail to load or render. Beta 23
recorded 94. The pack artwork change closed nine. See
[the failure inventory](ReleaseReadiness/ClassicValidation-current-failures.json).

## Signing

Apple accepted notarisation `90594bcb-7b4d-4508-8211-876a95fcd73d`.
The app is Developer ID signed, notarised and stapled.
`xcrun stapler validate` passed.

## Final archive

The finished ZIP was extracted and checked the way a tester receives it.
Gatekeeper accepted it as Notarized Developer ID.

- `UltimateLemmings-0.1-beta26.zip`: SHA-256
  `2e7272eb005dbabb3578571824889c806e9d3f738c8efcf701e2880f016b0e02`.
- Size 145 MB. Slices: `x86_64` and `arm64`. Build number 26. Minimum system 13.0.
- The archive carries `Release Notes.md`.

No Game Center archive was built for this beta.

Evidence and logs are in `.build/beta26`.

## Open gates

This beta does not close any release gate. The following remain open.

- 199 core campaign routes are unrecorded: 69 Classic family, 56 Lemmings 2 and
  74 Lemmings 3. The 60 Oh Yes! conversions have no route.
- Lemmings 2 and Lemmings 3 remain previews. They lack the keyboard overlay,
  the minimap, menu scaling, wide VoiceOver labelling and the Hot Seat handover.
- No Lemmings 2 tribe chains all ten levels under the population carry-over rule.
- Physical Intel, minimum macOS, controllers, displays and sustained performance
  remain untested.
- The publishing agreement with the rights holder remains open. No engineering
  task closes it.
