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

The focused checks are run with
`TEST_SCOPE=hints Scripts/run-app-integration-tests.sh`. Sequel data and
artwork checks use `Scripts/run-sequel-data-tests.sh` and
`Scripts/run-sequel-mac-artwork-tests.sh`. The release audit records the source
and fixture hashes for a candidate build; local `.build` outputs are disposable
and are not linked from maintained documentation.

This review records development validation. It is not a release certificate.

## Remaining release gates

The [gate register](gates.json) remains open. The existing campaign review records
214 core levels without winning-route evidence, plus converted-level gaps.
Sequel fidelity, installed-release recovery checks, physical input and hardware testing,
online services and final distribution also need closure. This presentation pass does
not change that evidence or the app's development version.
