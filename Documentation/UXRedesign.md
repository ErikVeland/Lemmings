# UX redesign proposal

Status: Phase 1 structure implemented on `feature/ux-phase1-home` (November 2026).
Phases 2–4 remain proposals. See [Phase 1 status](#phase-1-status) for what
landed, what changed from the proposal and what is not yet verified.

This proposal reorganises the existing depth of Ultimate Lemmings. It does not
remove features. It builds on [UI clarity](UIPrinciples.md),
[Player navigation](Navigation.md) and [Interface hierarchy](InterfaceHierarchy.md).
Those documents keep their rules about bitmap typography, stone controls,
Back/Main menu placement and footer order. Where this proposal changes a rule,
the change is stated explicitly.

## Evidence and limits

This audit comes from source review on `release/ultimate-lemmings` and the
current feature documents. The main sources are:

- `Sources/LemmingsGameArt/MobileHomeArt.swift` (iOS, iPadOS, tvOS Home)
- `Sources/LemmingsMobileUI/MobileLibraryViewController.swift` (all mobile routes)
- `Sources/LemmingsMobileUI/MobileWelcomePages.swift` (mobile first launch)
- `Sources/LemmingsLocal/main.swift` (Mac launch, menu bar, music state)
- `Sources/LemmingsLocal/ArcadeWindow.swift` (Mac profile creation)
- `Sources/LemmingsLocal/TelemetryDashboard.swift` (consent page)
- `Sources/LemmingsGameArt/MobileHUDRenderer.swift` (HUD and status row)
- `Sources/LemmingsLocal/RewindTransportCue.swift` (Mac rewind cue)
- [Variable speed](SuperSpeed.md), [Audio coverage](AudioCoverage.md), [Hot Seat](HotSeat.md)

No app was launched for this audit. No screenshot or device check supports it.
Interaction counts are derived from routes in source. Confirm them on a running
build before Phase 1 starts.

## A. UX audit — principal problems by severity

### Severity 1 — blocks comprehension

1. **Home is a dashboard, not a launch surface.** Mobile Home renders up to
   19 controls. These are the Journey row, up to three different Resume rows,
   eight game rows and eight footer actions. The footer actions are Players,
   Progress, Leaderboards, Collections, Donate, Desk Clock, Settings and What's New.
   All game rows have the same weight as Resume.
2. **The primary action is the first enabled row, not the most likely intent.**
   `MobileHomeArt.page` marks the first enabled row as primary. The Journey row
   always comes first. A player with a saved level therefore sees Journey as
   primary and their actual saved attempt as secondary.
3. **Three resume concepts compete.** Home can show "Resume level – NAME",
   a learning-run resume and "Resume PLAYLIST n/m" together. The player must
   understand saves, learning runs and playlists to choose the right one.
4. **Onboarding mixes identity with community data.** The first profile page
   (Mac and mobile) shows the worldwide saved-lemmings counter as its subtitle.
   The player sees global data before they have an identity. The consent page
   exists (`TelemetryConsentWindow`, `.telemetryConsent`) but no launch path
   presents it. Sharing therefore stays off until the player finds
   Settings > Privacy. The choice is never offered at the right moment.
5. **Speed shows action, not state.** The speed button toggles, holds to ramp,
   and has ‹ › arrows that choose the *next* tier without changing the current
   speed. At 1× a small label shows that next tier. This is three models in one
   control. The accessibility label needs a full sentence to explain it.

### Severity 2 — slows every session

6. **Game families are navigation, not content.** Classic, Oh No, Holiday,
   Oh Yes, Fan, NeoLemmix, Lemmings 2 and Lemmings 3 are eight peer rows on Home.
   A missing game shows "Import … data" in the same row. Preservation structure
   becomes the first menu.
7. **Personal data is split across four destinations.** Players, Progress,
   Records and Achievements are separate, and Cloud saves sits under both
   Players and Settings > Privacy. Play Insights sits under Progress and
   Settings > Privacy.
8. **Terminology drifts.** One concept has several names:
   - Collections / Playlists / "Saved level sequences" / "Collections / Playlists"
   - Leaderboards / Worldwide / Rankings
   - Progress / Records / Level Records
   - Back / Back to library / Library / Main menu
   - Players / Player Profiles / PLAYER SELECT
   - Settings "Display" (mobile) / "Video" (Mac) next to "Graphics" on both
9. **Level music continues through results.** [Audio coverage](AudioCoverage.md)
   states that the level track "keeps looping through the result screen".
   Only the Home menu (`showsMainMenu`) changes to the menu theme. Level select,
   briefing and results have no state of their own.
10. **Owner and developer tools appear in player navigation.** Play Insights
    asks for an owner access token. "Show Recorded Routes" and "Play … Beta"
    are in the Mac app menu. Familiar Names and insights token pages are mobile
    routes. These are useful to the owner, not to a player.

### Severity 3 — polish and stability

11. **Status values can still move.** The mobile status row reserves each
    slot at its widest value, which is good. But it centres text inside the slot,
    so "OUT 9/80" and "OUT 10/80" sit at different x positions. tvOS joins
    status values into two strings with spaces, so every value change reflows
    the whole line.
12. **Rewind exposes engine units.** The Mac cue reads "<< REWIND −N TICKS".
    Ticks are an implementation term. The rail is useful but the text is not.
13. **Status duplicates controls.** The status row shows "SPEED 2X" while the
    speed button also shows "2X". The state slot shows "PAUSED" while the
    Pause button already changes to Play.
14. **Settings categories overlap.** Graphics and Display/Video both cover
    visuals. Desk Clock is a settings group on mobile but a menu item on Mac.

## B. Navigation map

### Current (mobile and TV, from `Route`)

```text
Home (19 controls)
├─ Journey ─ map ─ Choose level, Revisit, Progression playlists
├─ Resume level │ Resume learning run │ Resume playlist
├─ Classic / Oh No / Holiday / Oh Yes ─ packs ─ level select
├─ Fan ─ groups ─ packs ─ level select (Search, Shuffle all, Check for packs)
├─ NeoLemmix / Lemmings 2 / Lemmings 3 (or Import … data)
├─ Players ─ rows, Edit, New, Hot Seat ─ Saved Hot Seats, Cloud saves
├─ Progress ─ Records ─ record card ─ Hints/Replay/Play
│           ├─ Achievements ─ award
│           ├─ Worldwide ─ community replays, Game Center
│           └─ Play Insights ─ token
├─ Leaderboards ─ World / Game Center / This device ─ category
├─ Collections ─ Favourites, Recent, Playlists, Progression, Shuffle all
├─ Donate
├─ Desk Clock
├─ Settings ─ Gameplay, Controller, Graphics, Display, Audio,
│             Accessibility, Desk Clock, Privacy, Game Data, Language
└─ What's New
First launch: First player → first level (consent and presentation pages unrouted)
```

The Mac duplicates most of this in the menu bar: Player Profiles, Hot Seat,
Level Records, Achievements, Cloud Saves, Play Insights, Level Select,
Fan Levels and Resume Saved Run.

### Proposed

```text
Home
├─ Continue  ← one primary action, resolved by the Continue rule
├─ Play
│   ├─ Journey (map, progress, Choose level)
│   ├─ Games  (one grid: Classic family, Fan, NeoLemmix, L2, L3)
│   │    └─ game ─ pack/rank ─ level preview
│   └─ Collections (Favourites, Recent, Playlists) as a tab, not a destination
├─ Hot Seat  (roster → session → Ready)
├─ Profile   (identity, progress, records, achievements, history, cloud saves)
├─ Community (leaderboards, worldwide total, community replays)
└─ Settings  (icon)
    └─ About (What's New, credits, legal, Donate, version)
Owner tools: Mac Debug menu and a hidden settings gesture only.
```

Home goes from 19 controls to 6: Continue plus five destinations. Game rows
move into Play. Donate, What's New and Desk Clock move under Settings > About
or the Mac app menu.

## C. Information architecture

| Information | Lives in | Visibility |
| --- | --- | --- |
| Current run, next level, owner | Home Continue card | Permanent |
| Journey position (n/total) | Continue card, Journey | Permanent |
| Per-game completion (n/total) | Play > Games cards | Contextual |
| Level objective (save n of m), skills, time | Level preview, HUD | Permanent in context |
| Personal best, stars for this level | Level preview (one line), results | Contextual |
| Full records, replays, run details | Profile > Records | On request |
| Achievements | Profile > Achievements, result reward line | On request, on unlock |
| Lifetime statistics | Profile > Statistics | On request |
| Worldwide saved total | Community header, result screen when sharing | Occasional |
| Leaderboards, community replays | Community | On request |
| Source game, port, provenance, pack | Level preview detail sheet | On request |
| Hot Seat roster and next turn | Hot Seat, handover, HUD owner badge | Permanent in session |
| Cloud sync state | Profile header icon, Settings > Online | Quiet status |
| Play Insights, telemetry dashboard | Owner tools only | Hidden |
| Version history | Settings > About | On request; one badge after update |

Rule: "play information" (what to do now) appears in the flow. "Information
about play" (history, provenance, comparison) lives in Profile or Community.

## D. Core user journeys

Counts are taps or key presses from app open. "Current" is derived from routes.

| Journey | Current | Proposed | Friction removed |
| --- | --- | --- | --- |
| First launch to first level | Name + portrait + Play = 3, no consent offer | Welcome 1 + name 1 + portrait 0–1 + community 1 + presentation 1 = 4–5 | Adds the missing consent step. Removes the counter from identity. |
| Returning player resumes Journey | 1 if no saved level; 2 when a saved level makes Journey compete | 1 (Continue) | One resolved action |
| Resume a saved single level | 1, but not primary | 1 (Continue) | Continue chooses the latest attempt |
| New Journey | Home → Journey → Start = 2 | Play → Journey → Start = 2 | Same count, clearer place |
| Manual level selection (Classic) | Home → family → pack → level → Play = 4 | Play → Games → game → rank → preview tap = 5, or Play → Recent = 2 | Recent and Continue shorten repeats |
| Complete a level | Result → Next = 1 | 1 | Music and state change (see H) |
| Fail and retry | Result → Retry = 1 | 1 | Same, with clearer reason line |
| Hot Seat | Home → Players → Hot Seat → select players → Choose a game → family → pack → level = 7+ | Home → Hot Seat → Resume session = 2, or New → players → Start Journey = 4 | Hot Seat becomes a mode with its own Continue |
| Inspect statistics | Home → Progress → Records → level = 3 | Home → Profile → Records → level = 3 | One owner for personal data |
| Change a setting | Home → Settings → tab → option = 3 | Same, or 1 for in-context settings | Speed, music and hints move to their point of use |
| Leaderboards | Home → Leaderboards → tab → category = 3 | Home → Community → category = 2 | Board kind becomes a filter |

## E. Gameplay HUD proposal

Keep the classic skill-panel position and order. Players have learned it.
Change grouping, state and stability, not location.

Control hierarchy, left to right on wide layouts:

1. **Release rate** (− / value / +). Unchanged position. Value right-aligned.
2. **Skills.** Unchanged order and position. Each slot has icon above a
   right-aligned count. Zero shows the icon dimmed with a red X count, never an
   empty slot. Selection uses three cues: a bright 2 px frame, a raised stone
   face and a small marker under the slot. Colour alone never shows selection.
3. **Time controls** (one stone group, see F): Rewind, Pause/Play, speed.
4. **Minimap** with Home/Goal tracking buttons attached to its frame edge.
   The minimap frame and the time group share one baseline and frame style.
5. **Menu** (☰). Opens pause/menu. Separate from Pause.

Status row above the panel: Saved n/needed (green, primary), Out n/total,
Time. Lost, rate, reserve and nuke state appear only when the level uses them.
Remove "SPEED nX" and "PAUSED" from the status row. The time group shows them.

Stability rules:

- Right-align every number in a slot sized for the largest value the level allows.
- Use the bitmap font's fixed-width digits. Where a face is proportional, draw
  each digit in a fixed cell.
- Never centre a changing value. Centre only static labels.
- On tvOS, replace the joined status strings with fixed slots like mobile.
- Values animate in place (count flash) without moving neighbours.

Controls look pressable (stone face, bevel). Read-only values have no bevel and
sit on the panel background. This rule applies on every platform.

## F. Speed and rewind proposal

Three concepts get three visual treatments inside one time group:

| Concept | Control | State shown |
| --- | --- | --- |
| Rewind (changes history) | ◀◀ button, left of Pause | Chevrons 1–3 for velocity, blue rail with "−4.2 s" |
| Pause (freezes) | ‖ / ▶ button, centre | Icon change and dimmed playfield edge |
| Speed (forward simulation) | Speed selector, right of Pause | Current multiplier always visible |

**Wide layouts (iPad, Mac, TV, iPhone landscape over 700 pt):** a segmented
speed strip: `1× 2× 3× 5× 10×` (plus 25× when enabled). The lit segment is the
current speed. Tap a segment to go there. Tap 1× to return. Each segment is at
least 44 pt wide.

**Compact layouts:** one speed button that always shows the current speed in
large digits. Tap cycles 1× → last fast tier → 1×. Hold opens the same strip
as a popover above the button. Release over a segment selects it. Removing the
‹ › arrows removes the "next tier" concept from the visible HUD.

**Keyboard (Mac):** F toggles 1× and last tier. 1–5 with Shift select tiers
directly. Shift hold keeps its temporary boost. `\` returns to 1×. Space pauses.
Backspace or `[` rewinds.

**Controller and Siri Remote:** Play/Pause pauses. RT taps toggle speed, RT hold
boosts. Rewind: each Left press on the time group (or LT tap) adds one chevron,
up to three (2×, 4×, 8× rewind). Play/Pause or any skill assignment stops rewind.
The chevrons and a growing rail make the velocity visible. The player never
needs to know presses are stacked.

Replace "REWIND −N TICKS" with "−4.2 s" (simulated seconds). Ticks stay in
developer logs only.

## G. Onboarding proposal

1. **Welcome.** Logo, one line of tone, one action: Start. On a returning
   install, this page is skipped.
2. **Your lemming keeper.** Name (initials, as now) and portrait. One line:
   "Your progress, saves, records and Hot Seat seat belong to this profile."
   No worldwide counter here. Nothing online is required.
3. **Join the count?** Show the worldwide total here, now that it means
   something. Explain the consequence in two lines: your rescues add to the
   world total and your initials and best runs can appear on leaderboards.
   Actions: Join (primary) and Not now. Route the existing consent page here
   and rewrite it. The six-line policy list moves to Settings > Online.
4. **How it looks.** Not implemented. [Variable speed](SuperSpeed.md) records
   the owner's decision that presentation choices stay in Settings with no
   first-launch screen. Phase 1 keeps that decision.
5. **Play.** The first level briefing opens with the 3–2–1 countdown.
   First-use hints appear during play (see Phase 4).

Steps 3 and 4 accept the controller Back as "Not now" or the default.
A returning install never sees steps 1–4 again.

## H. Audio-state model

| State | Music | Transition in |
| --- | --- | --- |
| Home, Play, Profile, Community, Settings | Menu theme (or silence if Menu music is off) | Equal-power crossfade, 0.8 s |
| Level preview and briefing | Menu theme continues | No change |
| Countdown | Menu theme fades out | 0.6 s fade |
| Playing | Level's assigned track (Adaptive DJ rules unchanged) | Starts on countdown end, beat-aligned for modules |
| Paused | Same track, −9 dB low-pass at 1.2 kHz | 0.25 s ramp, same ramp back |
| Pause menu, hints, help | Same as Paused | No change |
| Win result | Rescue lift continues for one phrase, then fades to a result loop or menu theme | Fade after 6–8 s or on first input |
| Fail result | Track stops on a short fall stinger | 0.4 s fade under the stinger |
| Hot Seat Ready handover | Menu theme at low level | Crossfade 0.8 s |
| Solution replay | Level track, normal level | Same as Playing |

This changes the documented rule that the level track loops through results.
It keeps the one rescue lift. Implementation rules:

- One audio-state owner per platform, driven by app state, not by each screen.
- Crossfades reuse the existing DJ decks and EQ paths. No new audio graph per transition.
- A repeated request for the current state does nothing. No restart, no click.
- Fades ease from the current value when a transition reverses, as
  [UI clarity](UIPrinciples.md) already requires.
- Older devices skip the pause low-pass and use volume only.

## I. Cross-platform layouts

| Platform | Home | HUD | Navigation |
| --- | --- | --- | --- |
| iPhone portrait | Continue card on top, 5 destinations as a bottom row | Landscape preferred. Portrait uses compact speed button | Back top-left, Home top-right (current rule) |
| iPhone landscape | Continue left, destinations right column | Compact speed below 700 pt, strip above | Same |
| iPad | Continue card with level art, Journey map summary beside it | Full strip, persistent minimap, status above panel | Same; Profile and Community use two panes |
| Duo / foldable | Folded: iPhone layout. Unfolded: Home uses the second region for Journey map | Unfolded: second region holds minimap and level status; skills stay on the main region | Fold change keeps the selected route and focus |
| Apple TV | Continue card centred, 5 large focus tiles | Strip with large segments, rewind chevrons, status in fixed slots | Menu button = Back. Labels never wrap |
| Mac | Continue card, destinations as a stone row | Full strip with keyboard hints in tooltips | Back and Home in the window toolbar row, not in the HUD; menu bar mirrors destinations only |

The Mac menu bar keeps one item per destination: Play, Hot Seat, Profile,
Community, Settings. Developer items move to a Debug menu that only appears
in non-store builds or with the Option key.

## J. Consolidation plan

| Change | Items |
| --- | --- |
| Merge | Players + Progress + Records + Achievements + Cloud saves → **Profile**. Leaderboards + Worldwide + community replays → **Community**. Three Resume rows → **Continue**. Graphics + Display/Video → **Visual**. |
| Move into Play | Classic, Oh No, Holiday, Oh Yes, Fan, NeoLemmix, L2, L3 rows. Collections becomes a Play tab. Import/Game Data becomes the empty state of a game card. |
| Move to Settings > About | What's New, Donate, credits, legal, version. Desk Clock settings join Visual on mobile. |
| Make contextual | Speed and music volume (HUD popover), hints (pause), level provenance (preview detail sheet), house rules (Hot Seat setup). |
| Hide (owner tools) | Show Recorded Routes (Mac: Option alternate of Replay Last Game). Play Insights keeps its local counts for players, so it stays on Profile and leaves Settings > Privacy. |
| Keep unchanged | Skill panel order and position. Back/Home corners. Footer order rule. 3–2–1 countdown. Hot Seat Ready gate. Result Next/Retry. |
| Rename | Collections (one name). Community (replaces Leaderboards/Worldwide/Rankings). Profile (replaces Players/Player Profiles). Home (replaces Main menu/Library in labels). |

## K. Implementation priority

### Phase 1 — Structural UX

1. Continue resolver in shared core: one function returns the one most recent
   resumable thing for the selected session (saved attempt, Journey, playlist,
   Hot Seat). Unit-test it against existing saves.
2. New Home: Continue + five destinations, on the shared `GameFrontEnd.Page` model.
3. Play destination with Journey, Games grid and Collections tab.
4. Profile and Community pages from existing record, achievement and leaderboard pages.
5. Onboarding steps 1–5, using the existing consent and presentation pages.
6. Terminology pass across `L10n` keys and `LocalisationCatalogue.json`.
7. Move owner tools behind the Debug menu.

### Phase 2 — Gameplay controls

1. Time group: rewind chevrons, Pause, speed strip and compact speed button.
2. Fixed-slot, right-aligned status values on mobile, TV and Mac.
3. Skill selection and zero-count states, checked against all three engines' panels.
4. Minimap and tracking buttons in one frame.

### Phase 3 — Secondary systems

1. Hot Seat as a mode: roster → session list → Continue/New → Ready.
2. Settings regrouped: Gameplay, Controls, Audio, Visual, Accessibility,
   Online, Storage & Downloads, About.
3. Level preview detail sheet for provenance, records and rankings.
4. Search and filters only on Fan and NeoLemmix catalogues. Default order:
   incomplete first within pack order.

### Phase 4 — Polish

1. Audio-state owner and transitions (H).
2. First-use hints for speed, rewind and skill assignment, shown once each.
3. Motion: selection and state changes only. No HUD motion during play.
4. Per-layout tuning for Duo fold changes and TV distance.

Every phase must keep saved runs, session IDs, rosters, next turns and
checkpoints readable. No phase may change the engine fingerprint.

## Open decisions for the owner

1. Profile names stay as arcade initials, or gain a separate display name.
   A display name changes saved profile data and needs a migration.
2. The speed strip includes 3×, or uses 1×/2×/5×/10× as the brief suggests.
   The engines support 3× today.
3. Result music: a dedicated short result loop, or a fade to the menu theme.
4. Mac back/home: a toolbar row above the playfield, or the bottom row as today.

## Validation plan

- Mobile menu audit (`LemmingsMobileMenuAudit --hierarchy --navigation`) for
  every new page at six viewports and three text sizes.
- `Tools/UITestRunner/run.py` offscreen and muted for Mac routes and HUD targets.
- Status-slot tests at minimum and maximum values (0, 9, 10, 99, 100, 999).
- Continue resolver tests against archived saves and Hot Seat queues.
- Audio-state tests that check state transitions without audible output.
- Physical device checks remain manual: iPhone, iPad (A10X), Duo fold,
  Apple TV remote and VoiceOver. Record them separately from source checks.

## Phase 1 status

### Implemented

| Area | Mac | iOS and tvOS |
| --- | --- | --- |
| Continue | `homeContinueAction` uses `ContinueResolver` and puts Continue first with the initial selection | `homeContinuations()` uses `ContinueResolver`; Continue is the only primary row |
| Home | Continue, Play, Hot Seat, Profile, Community; Settings and Update in the header | Same five rows; Settings in the header |
| Play | Title screen Play mode (`homeShowsPlay`) with the game grid; Back and Escape return Home | `.play` route with the game grid (`Page.gameLibrary`); Back from pages under Play returns to Play |
| Profile | Profile… opens player profiles | Profile replaces Progress and adds Players and Cloud saves |
| Community | Leaderboards window titled Community | Community page shows the local and worldwide saved totals |
| About items | Donate moves to the Help menu | What's New and Donate move to Settings; Open Desk Clock moves to Settings > Desk Clock |
| First launch | Profile, then Join the count?, then the first level | Profile, then Join the count?, then the first level |
| Owner tools | Show Recorded Routes is an Option alternate | Play Insights leaves Settings > Privacy |
| tvOS Home | — | Centred column when Home has no game rows; Play uses the TV game grid |

The Mac title screen keeps the local and worldwide saved totals as a quiet
status line at its foot. Mobile Home no longer shows them.

### Validation

- `ContinueResolverTests` (8) and `HomeContinueTests` (6) pass.
- `LemmingsMobileUITests` (45) pass, including the open-Duo Home fit test that
  failed on `main` before the smaller Home. The Mac `DeviceMenuLayoutTests`,
  `LevelLeaderboardResultTests` and `FooterNavigationTests` (23) pass, muted and offscreen.
- iOS and tvOS SDK modules compile with the SDK check. The tvOS application
  entry point typechecks. The iOS entry point check needs the script update below.
- No simulator, device or rendered Mac window was inspected. Touch, focus,
  VoiceOver and Siri Remote behaviour remain manual checks.

### Known gaps

- New and renamed strings fall back to English in all eight translated locales.
  The committed English catalogue on `main` is already stale from other work,
  so the catalogue regeneration belongs to the localisation integration worker.
- The Mac integration checks do not compile on `main`: commit `35a4235b` made
  `homeContentRow` optional without updating six checks. The updated first-profile
  and Home checks in this branch are therefore not yet run.
- `Scripts/check-apple-ui-sdk.sh` uses a removed app delegate path and `rg`.
  `Scripts/run-playfield-draw-tests.sh` lists a moved `RunRecovery.swift`.
- Mac Community does not yet show the worldwide total in its header.
- The legacy `TVLibraryViewController` source-folder path keeps its own menu.
