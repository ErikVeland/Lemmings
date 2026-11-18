# Ultimate Lemmix feature parity

Ultimate Lemmix uses the developed game frontend. Resource permissions determine
which content ships. They do not define a smaller menu or a separate game shell.

The Mac build retains the common icon, native menus, home families, library,
profiles, Hot Seat, records, insights, playlists, learning journey, hints,
replays, rewind and difficulty controls. Missing commercial campaigns use the
owned-file importer. The included three-level campaign uses the same browser,
briefing, controls and simulation routes.

## Content boundaries

| Content | Behaviour |
| --- | --- |
| Lix artwork, controls and music | Included with the applicable notices. The Lix font has its own licence. |
| Project icon | Matches the developed game. Character-rights review remains open. It is not labelled CC0. |
| Original graphics, lettering, music and commercial levels | Excluded from the clean bundle. The private preview retains its separately recorded original lettering and community fixtures. |
| Authored feature metadata | Included through an exact path and hash allowlist. This retains recovery fingerprints, progression, hints and verified replay witnesses. |
| Owned campaigns | Imported into separate validated installations. Importing another Classic release does not replace the first. |
| Known campaigns and learning journeys | Canonical identity requires matching the full ordered campaign and simulation assets. Load-time checks still use the actual current fingerprint. |
| External fan and NeoLemmix packs | Available through the common library. Personal-preview restrictions apply only to its pinned bundled corpus. |
| Fan update downloads | The updater accepts an explicit permitted-ID set. Store builds currently permit none because distribution permissions remain unverified. Player-selected local packs remain available. |
| Adaptive music | Uses available selected or imported game music first. Lix supplies the fallback when the clean bundle has no matching game music. |
| External folders | App-scoped bookmarks retain access after relaunch. A failed bookmark write reports that the player must select the source again. |
| App updates | Store builds use the App Store. The separate Sparkle updater stays outside those builds. |

## Menu access

All three Mac engines use the same pointer-capture policy. The top edge releases
the pointer so macOS can reveal its menu bar. Native menu tracking suspends
capture until all active menus finish. The pointer must return 32 points inside
the window before capture resumes. Option remains the immediate release key.

The Original and Modern pointer choices remain available. The clean build uses
the licensed Lix cross and target-square artwork for the Original-style option.
The protected embedded Amiga cursor images remain outside Store compilation.

## Local validation on 17 November 2026

The [build4 validation record](ReleaseReadiness/ultimate-lemmix-0.1-build4/feature-validation.json)
retains the 17 native scopes, 36 captures, source comparison and evidence limits.

- Clean candidate: full native menus, keyboard commands, all home families,
  Starter browser and Start action, briefing, gameplay and exact paused
  checkpoint save and restore passed offscreen.
- Private preview: the restored home retains 487 classified packs and 5,051
  levels. Those totals describe the private corpus, not gameplay certification
  or distribution permission.
- The shared pointer policy passed injected edge and nested-menu checks in an
  offscreen AppKit window. Cursor pixels matched the licensed source at three
  scales. Settings retains both pointer choices.
- Focused checks covered personal corpus policy, six canonical release
  identities, owned graphics lookup, permitted update downloads, multiple
  installations, music fallback and bookmark lifecycle behaviour.
- External security-scoped folder access still needs a manual sandbox-picker
  and relaunch check. Automated bookmark tests use injected dependencies.

## Platform and release limits

The iOS and tvOS builds retain the shared mobile frontend. That frontend supported
Classic before this work. They do not yet contain the full Mac feature set or
native Lemmings 2 and Lemmings 3 flows.

Native checks run offscreen with muted test audio and isolated player storage.
The current engine stamp differs from the existing replay certificates after
the importer, starter and Lix presentation additions. Recovery uses the current
stamp. Existing certificates retain their original hashes and fail closed when
incompatible. Affected hints use the existing generic practice guidance until
replay verification produces current proof. This is an evidence limit, not a
reason to remove the journey or hint interfaces.
The retained catalogue contains 512 targets and 350 checked hint decks with
the previous stamp. Solution route maps remain available. Their existing loader
replays each candidate against the current initial state before accepting it.

Compilation, resource audits and local checks do not establish physical-device,
controller, listening, accessibility or App Store acceptance. Signing, Game Center
provisioning, privacy declarations and rights review remain release gates.
