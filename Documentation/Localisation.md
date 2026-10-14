# Interface localisation

English is the source language. No translated language pack is enabled yet.
The shared layer serves Mac, iOS and tvOS, including Classic, NeoLemmix,
Lemmings 2 and Lemmings 3.

`Sources/NxlvKit/InterfaceLocalisation.swift` supplies language selection,
English fallback, complete message interpolation, native plural selection and
text expansion for layout checks. Menus, settings, game controls, dialogs,
help, notifications and accessibility messages use the same catalogue.
Resolve messages before measuring text or building input targets.
Standalone compiler scripts include the same localisation source when they
compile a subset of shared files.

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

Create each chosen language's `.lproj` directory in the same bundle. Keep English
keys stable and translate values. Both Mac bundle scripts and the shared iOS/TV
asset packager copy this bundle. SwiftPM copies it as an NxlvKit resource.
System preferred languages select the bundle at app startup. Unsupported
languages use English. Incomplete language packs use English for missing keys.

## Layout and artwork limits

`LEMMINGS_TEST_LANGUAGE=en-XA` expands interface text with ASCII characters.
It keeps interpolated player data unchanged and works with the shipped fonts.
Use it only in background, muted tests through `Tools/UITestRunner/run.py`.

The bitmap fonts still fold accents and substitute unsupported characters.
Full accented glyphs, other scripts and right-to-left layout need new pixel
font assets and rendering work before those languages can ship. Preserve the
complete translated Unicode message in accessibility text.

Original menu pictures, story animations and lettering baked into imported
artwork are not translated by the string catalogue. Lemmings 2 also has text
inside its original banks. These need a separate content/artwork pass for each
chosen language. Computed journey focus text, hint fragments, keyboard-help
parsing and remaining count-dependent sentences need a language-specific review.
Do not describe the source scan as complete language support.

## Validation

Six focused tests cover English catalogue round trips, language matching,
missing-message fallback, reordered arguments, invalid placeholders, count
plurals, unchanged player data and stable settings/skill identifiers.
Windowless expanded-text renders cover phone, tablet and desktop sizes with
selected, focused, primary and disabled actions. Checks verify action centres,
disabled targets, containment and Back ordering. These renders reuse the shipped
bitmap art. Physical touch, VoiceOver and complete translated screen journeys
remain device checks after the languages are chosen.
