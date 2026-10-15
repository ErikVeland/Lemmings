# Interface localisation

English is the source language. Macintosh 2.0 includes seven additional language
packs: Spanish (Latin America), German, French, Brazilian Portuguese, Italian,
Dutch and Norwegian Bokmål. The owner requested their inclusion in a fresh
release build on 15 October 2026 and instructed reuse of passed tests.
These are AI-assisted drafts with full structural coverage. Human language
review and complete translated-screen and device validation remain open.
Per-locale `.review.json` files retain their checkpoint and remaining work.
The shared layer serves Mac, iOS and tvOS, including Classic, NeoLemmix,
Lemmings 2 and Lemmings 3.

Tamil (`ta`) is the eighth candidate translation pack. Its complete draft is
installed for in-app testing. The integrated pixel font serves shared controls and the native
Classic, Lemmings 2 and Lemmings 3 renderers. Human Tamil review, complete
translated journeys, accessibility and device acceptance remain open.

`Sources/NxlvKit/InterfaceLocalisation.swift` supplies language selection,
English fallback, complete message interpolation, native plural selection and
text expansion for layout checks. Menus, settings, game controls, dialogs,
help, notifications and accessibility messages use the same catalogue.
Resolve messages before measuring text or building input targets.
Standalone compiler scripts include the same localisation source when they
compile a subset of shared files.

## Choosing a language

Open **Settings > Gameplay** and choose **Language**. Select a language to
preview translated text immediately. Choose **Apply** to save the choice.
Choose **Back** to undo the preview and restore the previous language.
Choose **System default** to follow the device language.

## Translation handover

The continuing validation task covers eight translation locales across Classic,
Lemmings 2 and Lemmings 3 on Mac, iPhone/iPad and Apple TV. The seven existing
packs remain AI drafts included in Macintosh 2.0. Tamil is a candidate addition.
All need human language review and platform acceptance. Their checkpoint files
record the reviewed scope and remaining work.

Read `AGENTS.md`, `Documentation/UIPrinciples.md` and the
[localisation architecture](../ARCHITECTURE.md#localisation) first.
TV work also follows `Apps/UltimateLemmingsTV/AGENTS.md` and `IOSParity.md`.
Preserve concurrent changes. Localisation changes are spread across commits,
including `b2856b52` and `1ef4abe1`, rather than one isolated feature commit.
Inspect the current checkout before resetting, staging or committing files.

### Current checkpoint

Eight translation locales share the current text catalogue and eight plural
keys. Each locale has a complete AI draft and runtime tables for testing.
Read the catalogue and review checkpoints for current counts and hashes.
Check the review files before treating a translation as approved.

| Locale | Language | Reviewer checkpoint |
| --- | --- | --- |
| `es-419` | Spanish, Latin America | `Tools/Localisation/drafts/es-419.review.json` |
| `de` | German | `Tools/Localisation/drafts/de.review.json` |
| `fr` | French | `Tools/Localisation/drafts/fr.review.json` |
| `pt-BR` | Portuguese, Brazil | `Tools/Localisation/drafts/pt-BR.review.json` |
| `it` | Italian | `Tools/Localisation/drafts/it.review.json` |
| `nl` | Dutch | `Tools/Localisation/drafts/nl.review.json` |
| `nb` | Norwegian Bokmål | `Tools/Localisation/drafts/nb.review.json` |
| `ta` | Tamil candidate | `Tools/Localisation/drafts/ta.review.json` |

A missing checkpoint means that review has not been recorded. A candidate or
populated JSON file alone does not establish review. Check each checkpoint's
scope, remaining issues and file hash before continuing. Coordinate one writer
per locale. Keep shared source, catalogue and `unchanged.json` updates with one
integration worker.

Source fixes already present include:

- The L2 artwork lookup table no longer passes through translation.
- TV skill captions and target accessibility status use translated messages.
- Keyboard help uses structured commands instead of parsing translated prose.
- TV transfer captions are separate from HTML, JavaScript, HTTP and path data.
- Journey captions translate at display time while saved identities remain stable.
- More counts use native plural tables. Blank text falls back to English.
- Sequel fonts support additional typographic punctuation without changing ASCII glyphs.
- Shared and native game renderers measure complete Tamil sequences, including vowel forms and conjuncts.
- The catalogue checker rejects known technical-data mistakes and incomplete bundled tables.

The expanded source state needs a fresh full localisation regression run.
Earlier focused tests passed, but they predate some bank-text, plural and font
changes. The catalogue check and six Python validator tests passed during the
handover. This does not establish translated gameplay or device acceptance.

### Files and formats

| File | Use |
| --- | --- |
| `Documentation/LocalisationCatalogue.json` | Current English keys, message kind and source references. Read the source around a reference before translating an ambiguous key. |
| `Tools/Localisation/drafts/<locale>.json` | Translation values keyed by the exact English message. Edit values, not keys or numbered placeholders. |
| `Tools/Localisation/drafts/<locale>.plurals.json` | Plural key to category/value mapping. This is staging data, not an Apple `.stringsdict` file. |
| `Tools/Localisation/drafts/<locale>.review.json` | Reviewed scope, remaining gaps, deliberately unchanged terms and validation evidence. State partial review explicitly. |
| `Tools/Localisation/install_drafts_for_testing.py` | Exports complete draft text and plural files to the runtime bundle for in-app testing. |
| `Tools/Localisation/captions.tsv` | Shared game actions and skill vocabulary. Apply the locale column and check uppercase variants. Do not overwrite context-specific wording blindly. |
| `Tools/Localisation/unchanged.json` | Optional shared allowlist for deliberately unchanged text. Format: locale, then English key, then a reason. The validator does not read this information from review files. |
| `Tools/Localisation/l2-original-text.json` | Original L2 text inventory and bank references. Review this inventory before treating it as complete content localisation. |
| `.build/localisation-tools/candidates/<locale>.json` | Disposable machine candidates. Not included in Git or the app. Preserve any useful candidate before moving to another machine. |

Example staged plural entry:

```json
{
  "count.levels": {
    "one": "%ld niveau",
    "other": "%ld niveaux",
    "many": "%ld niveaux"
  }
}
```

Every category must retain exactly one `%ld`. Use the locale's native rules,
including zero and large counts. Preserve literal percent signs as `%%`.
Do not insert `{0}` arguments into a plural format. The current plural API
supplies one integer only.

Example deliberately unchanged text:

```json
{
  "fr": {
    "Lemmings": "Original game title"
  }
}
```

Do not allowlist a whole pack to suppress untranslated-English errors.
Brand names, hardware abbreviations and authored identifiers need individual
reasons. Shared English words may be valid translations, but still need review.

### Resume the translation work

1. Read each locale's review checkpoint and inspect its current diff.
2. Refresh the English catalogue after settling source changes:

   ```sh
   python3 Tools/Localisation/catalogue.py
   python3 Tools/Localisation/catalogue.py --check --audit
   ```

3. Compare every draft with the current catalogue. Remove obsolete keys and
   translate missing keys. Preserve existing reviewed values.
4. Apply and review `captions.tsv` vocabulary. Check primary actions, Ready,
   retry, resume, Hot Seat ownership and destructive/undo wording first.
5. Review all remaining messages in their source context. Preserve argument
   meaning, negation, time units, key bindings and complete sentences.
6. Complete every plural entry. Test zero, one, two and large counts with
   Foundation's actual locale selection.
7. Merge justified unchanged-text entries into `unchanged.json`.
8. Run the structural checks below. Read every reported issue and missing key.
9. Inspect actual translated renders and input targets across the engine and
   platform matrix. Record checks that cannot run headlessly.
10. Update each review checkpoint with the exact draft hash and remaining gaps.
    Record each pack's remaining language and platform checks explicitly.

Machine candidates contain known semantic errors. Examples include Norwegian
Start translated as “Slutt”, German eligible as “beihilfefähig”, Spanish player
as “reproductor”, and Dutch Builder as “Bouwmachine”. Placeholder checks do not
detect these errors. A nonempty translation is not evidence of correctness.

### Optional local candidate generation

`generate_drafts.py` uses local OPUS models through Transformers. It does not
send app text to a translation service. Its Python packages and model weights
are optional development dependencies, not application requirements.
The listed Romance and Germanic models cover the seven Latin-script packs.
They do not generate the Tamil candidate.
Use a separate Python environment with `transformers<5`, `torch`,
`sentencepiece` and `sacremoses`. The existing local environment is
`.build/localisation-venv/` and model root is `.build/localisation-tools/models/`.
Neither directory travels with Git.

To prepare another machine, use a Python version supported by PyTorch. This
checkout used Python 3.12:

```sh
python3.12 -m venv .build/localisation-venv
.build/localisation-venv/bin/python -m pip install \
  'transformers>=4.50,<5' torch sentencepiece sacremoses
.build/localisation-venv/bin/python - <<'PY'
from pathlib import Path
from huggingface_hub import snapshot_download

root = Path('.build/localisation-tools/models')
files = ['config.json', 'generation_config.json', 'tokenizer_config.json',
         'vocab.json', 'source.spm', 'target.spm', 'pytorch_model.bin', 'README.md']
for name in ['opus-mt-en-ROMANCE', 'opus-mt-en-gem']:
    snapshot_download('Helsinki-NLP/' + name, local_dir=root / name,
                      allow_patterns=files)
PY
```

The model root contains `opus-mt-en-ROMANCE` and `opus-mt-en-gem`. Obtain them
from their Helsinki-NLP repositories. Their model cards describe the language
codes and licences:
[Romance model](https://huggingface.co/Helsinki-NLP/opus-mt-en-ROMANCE),
[Germanic model](https://huggingface.co/Helsinki-NLP/opus-mt-en-gem).
The current tool uses `es_MX` as a starting candidate for `es-419` and `pt_BR`
for Brazilian Portuguese. Regional and game terminology still require review.

```sh
.build/localisation-venv/bin/python Tools/Localisation/generate_drafts.py \
  --model-root .build/localisation-tools/models --languages de
```

**Preserve reviewed work before rerunning this tool.** It reads the draft,
then overlays an existing candidate file. A stale candidate can therefore
replace reviewed values in its output. Move that locale's old candidate to a
backup name first. Generate missing material, inspect the diff, and merge only
the required values into the maintained draft. Never copy a regenerated
candidate over a reviewed pack without comparison.

The generator translates individual lines and writes each locale at the end.
It does not review full-message grammar, write plural files, apply the glossary,
approve a pack, or install runtime resources. Long messages can lose arguments.
Inspect the matching `.issues.json` file and the validator report.

### Validation and enablement

Run these from the repository root:

```sh
python3 -m unittest discover -s Tools/Localisation -p 'test_*.py'
python3 Tools/Localisation/catalogue.py --check --audit
python3 Tools/Localisation/validate.py \
  --report .build/localisation-tools/pack-validation.json
```

`validate.py` returns nonzero while any pack is structurally incomplete. Its
report lists missing text, missing plurals and errors per language. It detects
duplicate JSON keys, unknown keys, blank values, invalid placeholders,
unreviewed identical English values and unsafe count formats. Its `complete`
field covers those checks only. It does not consume `.review.json` or prove
language quality, glyph coverage, layout, accessibility or platform acceptance.

Run native checks through the muted, offscreen runner:

```sh
export LEMMINGS_TEST_WINDOWS=offscreen
export LEMMINGS_TEST_AUDIO=muted
export CLANG_MODULE_CACHE_PATH="$PWD/.build/localisation-module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$CLANG_MODULE_CACHE_PATH"
python3 Tools/UITestRunner/run.py swift test --disable-sandbox --jobs 2 \
  --filter 'InterfaceLocalisationTests|BitmapLatinGlyphTests|BitmapTamilGlyphTests|SequelLatinFontTests|LocalisationLayoutTests|BitmapLatinRenderTests|TamilBitmapRenderTests|TamilSequelRenderTests|SequelLatinRenderTests|FooterNavigationTests'
LEMMINGS_TEST_LANGUAGE=en-XA python3 Tools/UITestRunner/run.py \
  swift test --disable-sandbox --jobs 2 --filter SequelLatinFontTests
```

The second command exercises the L2 artwork regression under text expansion.
Existing render tests cover representative captions and shared layouts. They
do not establish complete translated application journeys for every locale. Staged
JSON cannot be selected through `LEMMINGS_TEST_LANGUAGE` until a test harness
loads it as a temporary localisation bundle. Build that fixture path before
claiming end-to-end language coverage. Do not enable an incomplete pack merely
to make a render test select it.

Validate Mac, iOS and tvOS source compilation after runtime changes.
`Scripts/check-tvos-sdk.sh` compiles TV modules and the app entry point.
`Scripts/check-1.3-mobile.sh --require-sdk` is the broader iOS gate and requires
an available Simulator runtime. Read it before running. Report unavailable
headless checks instead of switching to visible windows or device tests.
SDK compilation alone does not establish native focus, touch or VoiceOver.

For every locale, check Classic/L2/L3 Home, selection, briefing, Ready, pause,
results, retry/continue, saved-run resume, Hot Seat handover, hints, help,
settings and accessibility. Include disabled/selected/focused actions,
long player names, zero/one/many counts, narrow phone widths, tablet panes and
TV safe areas. Handovers must remain paused until Ready. Preserve engine limits:
mobile L2/L3 have no release-rate control, and L3 has no nuke.

Run `python3 Tools/Localisation/install_drafts_for_testing.py
--for-in-app-testing` to export complete JSON drafts to Apple `.strings` and
`.stringsdict` tables. The installer checks all eight translation locales and
stops while any pack is incomplete. Bundle metadata lists English and the
eight test locales. Use **Settings > Gameplay > Language** to preview a locale.
**Apply** saves the choice. **Back** restores the previous language.
**System default** follows the device language.
These resources are for testing. Complete the human language and platform
reviews before release.

### Remaining language and platform review

- Complete human linguistic review for all eight translation locales.
- Review plural wording in each locale. Automated checks cover all eight Tamil
  plural keys at zero, one, two and large counts through Foundation.
- Review original L2 text grouping. The current inventory splits authored
  carriage-return lines, including incomplete sentence fragments. Preserve
  credits and complete sentences before final translation.
- Check original L2 bank text and baked menu pictures, story screens and other
  imported lettering. String coverage does not replace an artwork pass.
- Audit remaining computed captions, hint fragments and count-dependent text.
- Complete translated journeys beyond the representative automated captures.
- Complete the iOS SDK gate with an SDK that supplies the project's iOS 27 APIs.
- Record physical touch, remote focus, VoiceOver and complete device journeys
  separately. Keep the packs marked as drafts until each release gate passes.

### Local validation checkpoint — 15 October 2026

- All eight draft/runtime packs contain 3,130 text keys and eight plural keys.
  Pack validation and the source-catalogue check pass. Six validator tests pass.
- The font rebuild reproduces the runtime resource byte for byte. The prototype
  has 456 entries across three sizes, with no missing source glyphs. Six expected
  silhouette warnings cover the two source letter/digit lookalike pairs.
- Forty-eight focused Swift tests pass through the muted, offscreen runner.
  These cover original Latin pixels, Tamil sequences, wrapping, bounds, editor
  caret geometry, controls, Classic/L2/L3 renders and the original L2 intro.
  The installed Tamil text and plural tables have complete runtime glyph coverage.
- Apple TV's eight modules and app entry point compile. The final changed mobile
  UI module also compiles against the TV SDK.
- iOS compilation passes the shared font and layout modules, then stops in the
  existing `MobileReservedRegions.swift`: the installed 26.5 SDK lacks
  `UIView.ReservedRegion`, which the source expects for iOS 27.
- Captures and logs are under `.build/tamil-font` and `.build/tamil-font-renders`.
  These checks do not establish human language, tiny-label legibility, physical
  input, VoiceOver or device acceptance.

## Authoring

Use complete messages:

```swift
let title = L10n.text("Ready, \(player.initials)")
let count = L10n.plural("count.levels", count: levels.count,
    one: "%ld level", other: "%ld levels")
```

Translations can reorder `{0}`, `{1}` and later arguments. Each argument must
remain present. Substitution does not interpret the inserted player name,
level title or error detail as another template. Missing messages and damaged
interpolation fall back to English. Use `.stringsdict` for count-dependent
wording, with Apple's `zero`, `one`, `two`, `few`, `many` and `other` categories.

Keep identifiers, save keys, file names, source ranks, artwork keys and keyboard
bindings stable. Localise their captions separately. `SkillVocabulary` translates
skill captions without changing the names used by sprites and shortcuts.
`SoundtrackCatalogue.interfaceTitle` follows the same rule for music settings.
Player names, original level titles and fan content retain their authored text.

`GameFrontEnd.Action` can set `backNavigation` explicitly. Its stable navigation
IDs keep Back on the left even when its caption changes. Legacy actions with
numbered IDs retain a translated-caption fallback. New actions should use stable
IDs and an explicit role. Mobile pause overview presentation has an explicit
flag. Solution segments keep their selected mode independently of captions.
Ready and Hot Seat ownership continue to use the existing engine state.

## Catalogue and packaging

Run `python3 Tools/Localisation/catalogue.py` after editing messages. It parses
Swift syntax, including escaped and multiline strings. It writes:

- `Sources/NxlvKit/Resources/Localization.bundle/en.lproj/Interface.strings`
- `Sources/NxlvKit/Resources/Localization.bundle/en.lproj/Interface.stringsdict`
- `Documentation/LocalisationCatalogue.json`, with source locations for translators.

Run `python3 Tools/Localisation/catalogue.py --check --audit` to check catalogue
freshness, translation placeholders, plural formats and direct UI literals.
The explicit exemptions list preserves identifiers and original content titles.
The source check catches direct UI assignments and common control constructors.
It does not prove coverage of all computed text or imported game content.

Keep English keys stable and translate values. Mac bundle scripts and the
shared iOS/TV asset packager copy this bundle. SwiftPM copies it as an NxlvKit
resource. App metadata declares all testing locales. The in-app selector
previews a language immediately and persists it only with **Apply**.
Complete language and platform reviews before
release. Unsupported languages use English. Missing messages fall back to English.

## Layout and artwork limits

`LEMMINGS_TEST_LANGUAGE=en-XA` expands interface text with ASCII characters.
It keeps interpolated player data unchanged and works with the shipped fonts.
Use it only in background, muted tests through `Tools/UITestRunner/run.py`.

The shared Macintosh menu faces and compact bitmap fallback now retain Western
Latin letters. `BitmapLatinGlyphs` extends the shipped alphabet with Latin-1
and Latin Extended-A letters, Romanian Ș/Ț, capital ẞ, and inverted ¡/¿.
This includes Æ/æ, Ø/ø, Å/å, Œ/œ, Ð/ð, Þ/þ and Ł/ł. Added marks use the
original colour ramp and bevel. The original ASCII glyphs and cell advances
stay unchanged. Composed and combining forms render alike. Uppercase menus
retain accents and use one cell for ẞ. Line measurements include accent and
descender overhang; peer controls keep a shared face and scale.

The original Lemmings 2 FONT.DAT front-end face and PANEL.DAT alphabet, and the
Lemmings 3 FONT.DIN/FONT.DEL alphabet, cover the same Western Latin repertoire.
`SequelBitmapFont` retains their original indexed pixels and advances. Added
letters reuse each bank's shapes and shade indices. L2's front-end extensions
retain its rim and proportional spacing. The panel extensions retain their
compact shaded forms. L3's three large digit sets remain unchanged.
The banks' original single-case lettering is retained for panel text.

Text layout preserves Unicode characters and complete Tamil sequences, so
combining signs do not create extra columns. Front-end and animation line
spacing includes accent and Tamil mark overhang.
L2's fixed eight-pixel header fits the complete row on one pixel grid when marks
need extra height. Its icons, counters and targets retain their original bounds.
L3 menu text fits the existing row targets, including the selected background.
Glyph extensions load beside the banks. They do not rewrite imported game files.

### Tamil candidate font

`BitmapTamilGlyphs` loads `Localization.bundle/Fonts/TamilPixelFont.json`.
The resource contains 399 complete Tamil forms at body heights of 14, 18 and
26 pixels, plus the common SA-based shrii alias. The 456-entry prototype also
contains ASCII support and isolated combining-sign diagnostics. Runtime export
excludes those entries so original Latin artwork remains authoritative.

Input uses NFC and the longest matching complete Tamil sequence. Kssa and
shrii forms can span multiple Swift `Character` values. Width, line bounds,
wrapping and truncation use complete sequences and variable advances. Negative
bearings, pulli and vowel marks remain inside the measured bounds. Tamil aligns
with the source font's baseline. Sequel glyphs use each bank's shade indices.
The compact L2 header fits the complete row vertically and truncates to its
measured width without splitting a sequence.

Shared bitmap controls, the compact fallback and native Classic/L2/L3 text
paths use this resource. Runtime drawing needs no Core Text or installed font.
Bounded caches retain derived frames and palette glyphs. SwiftPM and existing
Mac, iOS and tvOS packaging copy the font and its notices with the localisation
bundle. See the [font tool](../Tools/TamilPixelFont/README.md) for rebuild and
export commands, and [third-party notices](../THIRD_PARTY_NOTICES.md) for licences.

The font and Tamil translations remain candidates. A fluent reader must check
shapes, spacing, wording and the compact panel. Complete translated-screen,
accessibility, input-target and device acceptance remain open. Source integration
does not establish those checks. Other scripts, unsupported Latin letters and
right-to-left layout remain outside this repertoire. Preserve complete Unicode
messages in accessibility text.

Original menu pictures and lettering baked into imported artwork are not
translated by the string catalogue. Some original L2 bank and story text now
uses the explicit inventory and `originalL2Text` lookup. That path still needs
sentence grouping, credit-name and rendered-script validation. Baked artwork
needs a separate pass for each chosen language. Computed captions, hint
fragments and remaining count-dependent sentences need a language-specific review.
Do not describe the source scan as complete language support.

## Validation

Focused tests cover English catalogue round trips, language matching,
missing-message fallback, reordered arguments, invalid placeholders, count
plurals, unchanged player data and stable settings/skill identifiers.
Windowless expanded-text renders cover phone, tablet and desktop sizes with
selected, focused, primary and disabled actions. Checks verify action centres,
disabled targets, containment and Back ordering. These renders reuse the shipped
bitmap art. Physical touch, VoiceOver and complete translated screen journeys
remain device checks after the languages are chosen.

`BitmapLatinGlyphTests` checks both original font banks byte for byte, the
extended repertoire, Unicode equivalence and overhang measurements.
`BitmapLatinRenderTests` generates `.build/latin-glyphs/western-latin.png`,
shared control renders at phone/tablet/desktop widths and native Mac controls.
It checks Unicode accessibility captions and activation targets. Run these
through the muted offscreen test runner, like all other native UI tests.

`SequelLatinFontTests` checks source pixels, palette indices, Western Latin
coverage, combining forms, compact panel rows and original L2 introduction
timing. `SequelLatinRenderTests` captures the three faces, L2 panel rows and
native L2 text and accessibility targets in `.build/sequel-latin`.

`BitmapTamilGlyphTests` covers resource forms, normalisation, aliases, sequence
layout, original ASCII pixels, sequel palettes and unclipped masks. The
`TamilBitmapRenderTests` and `TamilSequelRenderTests` suites cover representative
shared controls and native game text. Run these with the same muted, offscreen
runner. Their presence does not establish a completed test run or complete
Tamil language and device acceptance.
