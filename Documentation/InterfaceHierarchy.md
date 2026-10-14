# Interface hierarchy

The shared iOS page renderer measures wrapped bitmap text before placing the
preview, details and actions. Titles use the large green face. Section headings
use small green lettering; supporting text uses small blue lettering. A group of
peer buttons uses one height, with enough room for its longest wrapped caption.
The footer retains its secondary-to-primary order and exact UIKit targets.

Level selection, briefings, Hot Seat handovers, pause pages and results show the
full level title. The pause level title has the large green face. Results and
handovers keep the level name distinct from the outcome or incoming player.
The wide iOS browser reserves measured space for its title and source, followed
by the carousel and its actions. Titles no longer overlay the artwork cards.

`MobileLevelSummary` carries Official or Fan-made origin and the pack name.
Stock and port-exclusive releases are official. Fan archives are fan-made.
Journeys preserve each entry's source; favourites and lazy playlists preserve
source metadata across mixed packs. An older decoded summary has an unspecified
origin until its library supplies the current source. A title is never used to
infer its origin. Record pages show origin when the saved conditions identify it.
Repeated pack names are omitted from the level-number line.

The Mac menu header also reserves the measured wrapped title and subtitle height.
Its browser places the full selected title, source and position above the artwork.
The same source labels cover Classic, NeoLemmix, Lemmings 2 and Lemmings 3 catalogue
entries. Reduced-motion lists retain native controls. The change does not alter
turn ownership, engine controls or the paused Ready handover.

Footer grids reserve bottom-left for Back, Cancel, Library or Close and
bottom-right for the primary forward action. Other actions use the rows above
and remaining slots. Back keeps its corner when actions change or become
unavailable. UIKit binds targets by action ID. Keyboard/controller traversal
and accessibility follow the rendered order. Mac messages use the normal
footer positions, and return controls lead movie, replay and result rows.

## Validation

- The iOS UI target compiles for arm64 iOS 16.
- The windowless menu audit covers 180 hierarchy captures across six viewports,
  all three text sizes, Official and Fan-made sources, selection, results,
  handovers, settings and section groups. It checks full text measurements,
  long unbroken names, explicit line breaks, target order, disabled input,
  containment and non-overlapping targets.
- Native Mac captures use the shipped bitmap fonts through a scoped render fixture.
  They cover official, fan-made and unavailable selections in carousel and list
  modes, with native hit targets and primary actions.
- Model tests cover old summary decoding, retained origin, official sequel
  identities, fan archive identities, curated journey sources and mixed/lazy lists.
- Physical UIKit acceptance and live sequel briefing screens remain manual checks.
  Automated checks use the offscreen runner with all audio muted.

Footer regression checks cover changing action counts and columns, return labels,
disabled controls, results, home pages and pinned pause shelves. Native Mac checks
verify fixed message footers, mouse targets, keyboard order and replay/movie return
actions. The shared menu/result flows serve Classic, Lemmings 2 and Lemmings 3.
iOS/tvOS source compilation passes. Physical touch/controller acceptance and live
sequel result/Ready screens remain manual validation gaps.

Reproduce captures with the `LemmingsMobileMenuAudit` executable using `--hierarchy`
and `--pause`. Run native checks through `Tools/UITestRunner/run.py`, including
`InterfaceHierarchyTests` and `ProgressionMenuTests`. Set
`LEMMINGS_HIERARCHY_SCREENSHOTS` to an ignored output directory for Mac captures.
