# Player navigation

The player must be able to return to the place they left. Back restores the
caller, its selection, keyboard focus and scroll position. Main menu is the
explicit shortcut to Home. Back never starts an attempt, resumes simulation,
changes its owner or passes a Hot Seat turn.

## Existing routes

Mac panels place Back and Main menu in their bottom action row as regular stone
buttons. Full-window Mac pages use a fixed bottom row. On iOS and tvOS, menu
headers place the return action at the top-left and Main menu at the top-right
of the safe viewport. Keep navigation visible through scrolling and layout
changes. Remove the matching body return when the header supplies it.
The primary forward action stays at the bottom-right. Group related tools in
the body, with complete rows that divide their width among the actual buttons.
Pause and replay share this structure. Mac solution replay groups Replay,
Speed and Camera tools above its fixed Play/Pause action.

Activating a level preview follows its existing forward action. Browser previews
choose Play; Ready, pause and result previews use their current primary action,
including disabled/loading rules. Mac carousel clicks select and start the
clicked level. Preview activation does not add a separate launcher or bypass a
paused Ready handover.

| Player task | Route and return behaviour |
| --- | --- |
| Start or resume | Home keeps the saved run and current player visible. Start/Ready remains the deliberate forward action. Resume restores the saved attempt before play. |
| Choose a level | Home → game/fan group → pack/rating → level. Back retraces those pages. The Mac retains the actual browser pages while a selected level runs; leaving the level restores them. The same Start action becomes Resume for that unfinished attempt. Main menu discards that return context. |
| Search a large catalogue | Search, sorting and filtering remain above the entries. Back and Main menu remain outside the scrolling content. Search results, selected entries and parent groups survive nested visits. |
| Find saved levels | Home → Collections → Favourites, Recently played or Playlists. The Home caption matches Collections; Playlists names only the playlist list. |
| Play a playlist or short game | Existing collection/setup pages lead to the existing level/Ready flow. Retry and Next retain the run's ownership and progression rules. No additional launcher is introduced. |
| Follow the Journey | Home always shows Start Journey or Resume Journey (current level/total) for the selected solo or Hot Seat session. It opens that route directly through the existing level/Ready flow. Independent saves cannot replace this action. The Journey hub retains Choose level and Revisit on return from the route. Progression playlists retain the Journey/Collections caller. Technique selection returns to its progression page. |
| Pause or skip | Mac Menu/Escape and mobile gameplay Pause open their pause pages. Resume continues the same attempt. Eligible campaign and Learning levels show Skip with the owner’s balance, disabled at zero. Q and Back to library save the attempt and restore browsing. Failed results keep the same Skip action. |
| Get hints | Mac: the labelled Hints control opens the current level's hints directly. It replaces the graphics-cycle tile; graphics remains in Settings and on F2. Mobile/TV: Pause → Hint. Hint Back restores the caller; moving between hint stages does not replace it. Reading hints after a failed Journey attempt retains the result and does not start a retry. |
| Read controls | The existing controls guide stays underneath nested Mac hints. Back returns to the guide, then to paused gameplay. Mobile help retains the caller's page, actions, focus and scroll position. |
| Study a solution | Existing hint stages and spoiler confirmation remain. Cancel retains the hint. Game/Solution switches retain the live attempt and the replay's study position. Returning to Game stays paused. Verified full solutions remain subject to engine/content availability. |
| See progress and rankings | Home → Progress for the active player's totals, Records, Achievements and Play Insights. Home → Leaderboards for ranked players: tabs choose World, Game Center or This device, then the category. Back returns Home. |
| Watch a replay | Results → Replay, or Progress → Records / Replay → level → Replay on mobile. Mac records retain their existing replay actions and level navigation. Playback is read-only; closing it returns to its source. Movie export cancellation and completion retain the exact result page. Navigation away cancels stale export presentation. |
| Inspect results or awards | Retry/Next remains the forward action. Back from details, achievements and rewards returns through the caller. The global Back button uses that same history. Solo and Hot Seat result Back return to the browser; the duplicate result Menu action is removed. Mobile award details retain the source list's scroll position and focus. |
| Change settings | Settings retains the game/library caller. Horizontal mobile/TV layouts use fixed tabs above the content and fixed Back/Main menu controls below it. Tab changes replace the current group without adding Back steps. Portrait layouts retain the category index. Nested soundtrack/configuration pages return to their actual parent. Updating an option does not reset the scrolling group. Replays can use their presenting library's settings. |
| Manage players and Hot Seat | Players owns profiles and shared-session setup. Cancel preserves the existing attempt/session. Ready remains paused. Temporary L2 fan and L3 direction selection are cancelled before Escape opens the pause page. |
| Recover from a failure | Existing save/import/replay recovery pages retain Retry and a safe Back/Cancel. Leaving an active attempt checks its save and keeps the attempt open if saving fails. Failed or cancelled loading must not replace the screen the player returned to. |
| Read About, version history or welcome pages | Existing bounded reading pages and fixed navigation remain. About/version selection and help retain their caller. Welcome's Continue stays explicit. |
| Use cloud, privacy and optional services | Cloud saves, sync, privacy and Play Insights keep their existing owners and return paths. External authentication, file pickers and sharing use platform presentation. No extra destination is added. |
| Watch original movies or use Desk Clock | These retain their existing entry points and their underlying game/library. Returning must keep gameplay paused; Ready and handover gates are not bypassed. |

The generic mobile route history records positions, not copied game state.
Returning to an ancestor removes the intervening history. Refreshing the same
route does not add a visit. Main menu starts a fresh navigation history.
Mac browser retention keeps existing views and their callbacks alive until
return or explicit Main menu; it does not change saved-game formats. Hints has
one gameplay button. The duplicate timeline Hint is removed, so the three
transport buttons have larger input targets.

## Validation and limits

The October 2026 UX review inspected the shared routes and the Classic,
Lemmings 2, Lemmings 3 and NeoLemmix host wiring. Changes use the existing stone
buttons and bitmap renderers. Native checks run through `Tools/UITestRunner/run.py`
with offscreen windows and muted test audio.

Validation on 24 October 2026:

- 34 muted offscreen Mac tests pass. They cover retained pages, scroll and
  focus, one-time restoration/discard, result → hints → result, explicit Retry,
  nested records, solo/Hot Seat Back, fixed navigation, target geometry and
  transport controls that consume disabled targets and gaps.
- The arm64 app integration checks pass with bundled game data in Classic,
  Lemmings 2 and Lemmings 3. They exercise direct Hints, controls → hints →
  controls, Settings, keyboard shortcuts, focus/hover/fading, input bounds and
  640/900/1600-point windows. Final bitmap captures were inspected. Each engine
  also returns through the retained level/pack pages and restores the saved
  attempt's run ID, tick and state hash while paused. L3's original Menu target
  uses the same return path as the shared Menu control.
- iOS and tvOS SDK module builds pass. Caller, hints, nested settings, library,
  award, recovery and global-navigation tests typecheck against both SDKs.
  These are compilation checks, not UIKit runtime passes.

The native test harness skips window-server mouse-event delivery offscreen;
target bounds, hit tests and direct/accessibility actions are checked instead.
NeoLemmix's return/resume wiring was reviewed but its full native journey was
not exercised in this check. Physical iPhone/iPad touch, Siri Remote focus, external authentication, network
failure delivery and audible movie/music behaviour require their respective
devices or explicit test authorisation. Source review and SDK compilation do
not establish that every one of those interactions has been exercised.

This is a navigation contract, not a claim that every level, translated string,
external service or hardware input combination has passed a novice playthrough.
L2/L3 hints currently offer practice guidance; verified solution availability
must not be implied where no verified replay exists. Sequel short games remain
unavailable on mobile/TV.

The pause/skip flow supersedes the earlier direct Menu/Escape return described
in the 24 October validation record. Q retains that direct return.


On iOS/tvOS, Main menu is fixed at the safe menu viewport’s top-right. Optional
header actions fill the remaining space. Every body and footer action row fills
its width, including partial rows. The level carousel wraps its action shelf
when targets would become too narrow.
