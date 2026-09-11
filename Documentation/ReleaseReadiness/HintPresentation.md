# Hint presentation review

Scope: the existing Mac game and a separate local development build. This pass does not declare 1.0 readiness.

## Closed defects

- Hint progress, headings, prose, notes and map numbers use the menu bitmap font.
- Bitmap paragraphs preserve explicit line breaks and blank lines. Skill arrows map to supported glyphs.
- Long words wrap without losing characters. Long hint bodies scroll instead of being truncated.
- Mouse wheel, controller right stick, arrow keys, Page Up/Down and Home/End can scroll hints.
- Each revealed tier returns to the top after its document is resized.
- Complete hint values remain available to accessibility tools.
- `LEMMINGS_BUILD_DIR` selects a separate build output directory through the production build script.

The typography changes apply to checked hints and general coaching across all game engines.

## Validation

The integration checks cover the 360 original hint tiers, the actual packaged fonts,
paragraph and arrow handling, accessible values, oversized text, keyboard scrolling
and tier reset. Existing pause, spoiler, controller, flat/CRT and help handoff checks remain.

The full [Mac integration suite](../../.build/release-polish-app-tests.log) passed.
Visual inspection covered nudge, approach and opening moves in the rendered flat/CRT pages.
The two release-audit integrity tests and shell syntax check passed.

The [sequel suite](../../.build/release-polish-sequel-tests.log) passed, including 59,542 artwork frames,
214 levels, live L2/L3 hint pause restoration, controllers, settings and original media.

The optimised [Universal development app](../../.build/release-polish/Ultimate%20Lemmings.app) built successfully
through the production script. The executable and shared library each contain arm64 and x86_64 slices,
both targeting macOS 13. Strict, deep ad-hoc signature verification passed.
The bundled hint fingerprint matches the engine. The recorded source inputs did not change.
See [build output](../../.build/release-polish-build.log), [package integrity](../../.build/release-polish/integrity.json)
and [source inputs](../../.build/release-polish-inputs.json).

The full [integration rerun](../../.build/release-polish-package-app-tests.log) also passed with
the new package's resource bundle and optimised shared library.

This is a local development build. It is not a newly notarised release archive.

## Remaining release gates

The [gate register](gates.json) remains open. The existing campaign review records
214 core levels without winning-route evidence, plus converted-level gaps.
Sequel fidelity, installed-release recovery checks, physical input and hardware testing,
online services and final distribution also need closure. This presentation pass does
not change that evidence or the app's development version.
