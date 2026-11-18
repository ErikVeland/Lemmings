# Ultimate Lemmix personal preview

This separate Mac test build combines the original Lemmings bitmap lettering,
classified community levels and Lix artwork. Its app identity and saved data
are separate from the clean Ultimate Lemmix candidates and the preservation app.

The original lettering and community content are personal test resources.
Their inclusion does not establish permission to redistribute them. They do
not enter the clean Mac, iOS or tvOS resource allowlists.

## Included content

- Original green and blue Macintosh lettering: 188 glyph images, extracted from
  the supplied game source and checked against its pinned hashes.
- 487 Classic-format community packs with 5,051 selectable levels.
- The three independent starter puzzles, Lix graphics and six CC0 Lix tracks.
- The original Classic terrain and object banks needed to interpret the
  selected community levels. These remain original artwork, even when the
  player selects Lix presentation.

Lix artwork selects full-colour Classic terrain, hatches, exits and mapped
hazards at 2× detail. The starter themes are brick, earth and wood. Imported
geometry and simulation masks stay intact; unmapped decorations and effects
keep their source frames. Lemmings 2 and 3 currently replace characters only.

The source catalogue contains 535 packs and 6,020 levels. The classification
policy excludes 48 packs linked to official releases or conversions. It also
hides three exact official-level copies inside mixed packs. The ZIP files
remain unchanged so mechanics overrides and saved identities retain their
original hashes. Runtime checks reject the excluded entries, including direct
loads. Those records still exist inside the unchanged personal ZIP resources.

This classification does not prove that every remaining level is independently
authored or cleared for redistribution. The archive extras include 88 image or
music files in three packs; the importer does not extract, execute or play them.

## Scope limits

The current selection covers the supplied Classic-format catalogue. Lix levels
need a separate parser and simulation adapter; copying their graphics does not
make those levels compatible. The NeoLemmix Introduction pack has 120 authored
levels: 65 resolve the installed styles, render and initialise; 55 need 43
missing styles. These levels are outside this personal selection.

The full selected Classic corpus passed native decoding, rendering and one
simulation tick: 487 packs, 5,051 levels, no failures. This establishes loading
and initialisation. It does not establish winning routes, sustained gameplay or
fidelity to a reference engine. The local result is
`.build/community-preview-tests/results.json`.

## Build and checks

Use the dedicated scripts:

```sh
zsh Scripts/prepare-original-font.sh
zsh Scripts/prepare-lix-font.sh
zsh Scripts/prepare-community-levels.sh
zsh Scripts/build-ultimate-lemmix-personal-preview.sh --rebuild-core
zsh Scripts/check-community-preview.sh
zsh Scripts/run-personal-preview-app-tests.sh
```

The current build output is
`.build/ultimate-lemmix-personal-preview-build3/Ultimate Lemmix.app`.
Its identifier is `academy.glasscode.ultimatelemmix.personal-preview`.
The resource inventory and build evidence record the exact source files,
included content, architecture slices and signing state.

For this build, the verified clean core can be reused with
`--base-build .build/ultimate-lemmix-app-store-build3-universal` instead of
`--rebuild-core`. Reuse fails if the core source or recorded outputs differ.

Automated checks use isolated preferences, offscreen windows and muted audio.
Original-art captures remain in ignored local build folders. Keep manual play,
audible playback, physical-device checks and App Store submission as separate
validation steps.

## Verified build 2, 17 November 2026

The universal personal app passed its exact resource, signature and archive
audits. It reuses the verified clean Mac executable and engine; personal
behaviour comes from its separate Info profile and resources. The
[build record](ReleaseReadiness/ultimate-lemmix-0.1-build2/mac-personal/build-evidence.json)
records this code reuse explicitly. No duplicate compilation is claimed.

The review ZIP is 32,348,976 bytes, SHA-256
`cd7291da08173efe66ba3f78f389f4dadb84e838aa97cd7c092cac1aa8db3b61`.
Seven isolated native cases passed against the final packaged engine, with
nine inspected captures. Scene-only means were 1.92–2.46 ms across five copied
simulation ticks per starter. These samples do not establish device frame rate.
[Native evidence](ReleaseReadiness/ultimate-lemmix-0.1-build2/native-validation.json).

The selected community corpus passed decoding, rendering and one simulation
tick for all 5,051 entries.
[Corpus result](ReleaseReadiness/ultimate-lemmix-0.1-build2/community-corpus.json).
This corpus check preceded the optional Lix scene composition; representative
community artwork toggles were checked through the final native app harness.

The personal app was opened for the user's manual test and its process was
confirmed. This proves startup, not gameplay acceptance or audible playback.
[Startup record](ReleaseReadiness/ultimate-lemmix-0.1-build2/manual-launch.json).
The clean Mac and mobile packages exclude its original lettering and community
content.

## Verified build 3, 17 November 2026

Build 3 applies the original bitmap font to the full Classic HUD and uses the
actual Lix button sheets. Full-window checks cover running, paused, Undo and
narrow states, with 19 input targets checked in each case. A separate clean
case verifies the licensed Lix font. All five cases passed against the exact
packaged engine. See [HUD evidence](UltimateLemmixHUD.md#verification).

The personal ZIP is 32,705,288 bytes, SHA-256
`db7ad85a5a63c2ed3305a791236b3aab5d672b6ad87a42b6686e630511522259`.
[Build record](ReleaseReadiness/ultimate-lemmix-0.1-build3/mac-personal/build-evidence.json).
Original lettering, community scope and redistribution limits remain as stated
above. The previous build 2 app remained unchanged across all 2,156 files.

The opened review copy is
`.build/ultimate-lemmix-hud-build3-manual-review/Ultimate Lemmix.app`.
It has a separate sandbox identity, matching canonical resource bytes and a
verified ad-hoc signature. It does not share existing saved games.
[Startup and isolation record](ReleaseReadiness/ultimate-lemmix-0.1-build3/manual-review-launch.json).
