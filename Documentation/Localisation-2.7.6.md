# Localisation for 2.7.6

This release updates four shared What's New paragraphs and adds ten game-data
download status and recovery messages plus ten developer-tip messages. The
tip messages have 100 new translated values across the ten supported languages:
Catalan, German, Latin American Spanish, French, Swiss German, Italian, Norwegian Bokmål,
Dutch, Brazilian Portuguese and Tamil.

All ten packs contain 3,629 text entries and eight plural entries. Structural
checks found no missing entries, invalid placeholders or unreviewed English
fallbacks. Runtime tables match their source drafts, and retained translations
and plural forms are unchanged. The two priced tip actions use numbered `{0}`
arguments, with all 20 translated price placeholders preserved exactly once.
Purchase progress, pending approval, purchase failure and receipt-verification
failure retain distinct messages in every language.

The new wording received two AI-assisted contextual reviews. These reviews do
not constitute fluent-speaker approval. The catalogue was regenerated using
the existing formatter after reproducing the previous generated files
byte-for-byte. Scoped extraction covered changed message sources, and exact
unchanged-line mapping preserved existing references around the app-startup
insertion. The final Store Settings cleanup changes one existing Back reference
and adds no translation keys.

This record covers source and structural validation. Native SwiftSyntax
extraction, Apple SDK builds, rendered layouts, accessibility and physical
device acceptance were not run for this update on the Linux host and remain
separate checks. Historical per-language review records remain unchanged.
