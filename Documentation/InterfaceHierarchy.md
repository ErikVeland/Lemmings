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

## iOS and tvOS page tree

iOS and tvOS share `MobileLibraryViewController`. The tree below shows each page
and every place that opens it. The Mac title screen uses the same Home and Play
split. See [UX redesign](UXRedesign.md) for the reasons behind this structure.

```text
Home
├─ Continue  [one resolved action: saved level, Journey, sequence or playlist]
├─ Play  [play]
│   ├─ Journey ─ Choose level, Revisit, Progression playlists ¹
│   ├─ Other saved routes: saved level, sequence run, playlist run
│   ├─ Classic, Oh No, Holiday, Oh Yes, Fan ─ packs ─ level select
│   │   └─ Fan ─ Search, Shuffle all ², Check for new packs
│   ├─ NeoLemmix, Lemmings 2, Lemmings 3 (or Game Data when absent)
│   └─ Collections ─ Favourites, Recently played, Playlists, Shuffle all ²
├─ Hot Seat  [hotSeat] ─ roster, Saved Hot Seats ³
├─ Profile  [profile]
│   ├─ Records ─ record card ─ Hints, Replay, Play (Classic)
│   ├─ Achievements ─ Level goals, Career progress, Progression ─ award detail
│   ├─ Statistics ─ player and level breakdowns
│   ├─ Players ─ player rows, Edit, New player, Hot Seat, Saved Hot Seats ³
│   ├─ Cloud saves ⁴
│   └─ Play Insights
├─ Community  [worldwide] ─ World, This device, Game Center
└─ Settings icon ─ groups, Game Data, What's New, Donate
    ├─ Audio ─ Soundtrack libraries
    ├─ Desk Clock ─ Open Desk Clock (iPhone and iPad)
    └─ Privacy ─ sharing, Familiar names, Cloud saves ⁴
```

Numbered pages open from two places. Back returns to the page that opened them.
Back from a page under Play returns to Play. Main menu always returns to Home.
Level select keeps Favourite and Playlist actions for the selected level.

The ghost solution is an in-game feature. Open Pause, then Hint, then Ghost
solution. It is not on the Home tree.

The record level page is a record card. It shows the level artwork, earned
stars, the paired statistics and the achievements. Its footer keeps Back at
bottom-left and Play at bottom-right. Hints and Replay fill the row above.
Hints opens the level hint cards. Each card offers Previous, Next hint,
Solution and Play. Solution plays the verified Classic solution.

Replay plays the newest kept action replay for the record. Only Classic attempts
keep action replays. Artwork, Hints, Solution and Play load for Classic and fan
catalogue levels. Lemmings 2 and Lemmings 3 records show statistics and stars
only. Worldwide community replays follow the same Classic limit.

## Screen review register

**Green by owner sign-off, 25 November 2026.** Erik accepted physical VoiceOver and Siri Remote navigation, native system sheets, signed-in Game Center, hosted replay delivery and the engine-specific campaign and movie screens reviewed in #91. The automated evidence for each area is recorded below.

| Player task | Screens and states covered by the source review | Verification |
| --- | --- | --- |
| Get started | First player, portrait and name, effects, sharing consent, What's New and recovery | First-player and navigation bitmap/target checks cover first use, choices and error states. |
| Choose a game | Home, Play, family, fan folder and search, level catalogue, carousel and list, level cover, briefing, loading and Details | Navigation, hierarchy, preview and loading checks exercise the shared controls. The SDK route fixture also builds the library pages. |
| Follow a route | Journey, Revisit, Progression playlists, Techniques, Collections, Short games, Shuffle, Favourites, Recents, playlists, individual playlist and Add to playlist | Journey and Short games have rendered cases. Playlist editing, missing content and alternative entry paths have source coverage. |
| Play and hand over | Classic, L2, L3 and supported fan HUDs, Pause, hints and solutions, Hot Seat roster, saved sessions, Ready, retry and handover | Pause, replay and Hot Seat audits use muted offscreen input. Duo panels have separate geometry checks. |
| Finish a level | Win, fail, retry, next turn, earned rewards, result Details, goals, career, level leaderboard, Records, replay and share | Native Mac result tests exercise Classic, L2 and L3 through the metric control. Mobile fixtures cover tied and offline comparisons and split result panes. |
| Review progress | Profile, Players, Statistics, player and level breakdowns, Records, record card, hints, Achievements and award detail | Navigation renders show empty and populated records, each achievement category, and disabled or available replay actions. |
| Compare scores | Community, World, This device, Game Center, level and career metrics, tied rows, replay availability and sharing | Shared rendering and Mac tests cover offline, loading and populated lists. Signed-in Game Center and hosted replay delivery have owner acceptance. |
| Configure and recover | Settings hub and each settings group, language, controller mappings, Soundtrack, Game Data, asset licence, import, cloud saves, Play Insights, token, clearing and Familiar names, About and Donate | Group, sync and support audits exercise shared layouts. Native pickers and system prompts have owner acceptance. Download reliability and physical controller remapping have separate checks. |
| Use platform and game extras | L2 practice, original movies and campaign presentations, L3 mission and tribe screens, iOS Desk Clock, Mac application menus and panels, and the Apple TV source-folder browser | These have distinct entry points. The shared navigation capture count excludes the native windows, system sheets and engine-owned scenes. The campaign and movie screens have owner acceptance. |

The mobile route regression builds every case of the library controller with an isolated record store, including every family and settings group. Rendered navigation fixtures check the list toolbar as well as the scrolling page. Each category tab retains its selection marker when keyboard or remote focus moves.

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
- The owner accepted VoiceOver, Siri Remote and the sequel campaign screens.
  Automated checks use the offscreen runner with all audio muted.

Footer regression checks cover changing action counts and columns, return labels,
disabled controls, results, home pages and pinned pause shelves. Native Mac checks
verify fixed message footers, mouse targets, keyboard order and replay/movie return
actions. The shared menu/result flows serve Classic, Lemmings 2 and Lemmings 3.
iOS/tvOS source compilation passes. The owner accepted the Siri Remote and sequel campaign flows.
The latest offscreen AppKit composite capture omitted some stone controls even
though native geometry and activation checks passed. Shared bitmap footer captures
verify the column layouts. Full shipping-app message compositing still needs a
manual check; no foreground test was launched.

The menu audit checks the Home captions, the Progress rows and their Back
targets, the record card and hint card footers, stars, and Saved Hot Seats on
Players. The default and `--navigation` audits pass with 495 pages and 87
navigation states. The owner accepted hosted replay delivery.

Reproduce captures with the `LemmingsMobileMenuAudit` executable using `--hierarchy`
and `--pause`. Run native checks through `Tools/UITestRunner/run.py`, including
`InterfaceHierarchyTests` and `ProgressionMenuTests`. Set
`LEMMINGS_HIERARCHY_SCREENSHOTS` to an ignored output directory for Mac captures.
