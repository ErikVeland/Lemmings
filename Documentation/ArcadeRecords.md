# Arcade profiles and level records

New completed attempts use [THE TROLLEY](TheTrolley.md): immutable history,
evidence-aware rescue potential, philosophical affinities, seven compatible local
boards, and adaptive Retry challenges. This page also describes the compact legacy
records retained during migration. Existing profiles and campaign saves remain intact.

Use **Player Profiles** (Command-Shift-P) to manage up to eight local players.
Each player has three initials and a portrait from the original lemming sprites.

| Task | Steps |
| --- | --- |
| Add a player | Select **+ New player**, type initials, choose a portrait, then select **Add player**. |
| Change initials or portrait | Select the player, then type or choose a portrait. Changes save immediately. |
| Change the active player | Select the player, then select **Play as**. |
| Delete a player | Select the player, select **Delete**, then confirm. |

The primary action changes with the selection: **Add player**, **Play as** or **Done**.
Enter does the primary action. Arrow keys choose portraits.

Deleting a player removes their campaign progress, saved runs, replay movies,
scores, records and achievements. It also removes a shared campaign that they
host. You cannot undo a deletion. You cannot delete the last player. During a run,
you cannot delete the host, the current player or a Hot Seat player.

The first profile, initially called LEM, retains existing campaign progress.
New profiles start their own campaigns and achievements. Graphics and audio
settings remain shared.

Finish the current run before changing players. You can add and edit players
during a run. Opening profile selection pauses play. A run belongs to the profile
that started it. Renaming initials or changing the portrait does not change that
identity or erase records.

If the records file cannot be read, the app cannot save results. Select
**Fix records**. The app reads the file again. If it still fails, select
**Start new records**. The unreadable files stay in the records folder with a
`.set-aside-` suffix.

Each completed classic, fan, L2 or L3 run opens THE TROLLEY result page **inside the game
window**. The rescue count is the main result. The page then shows the rescue goal,
your personal best and one optional challenge for another attempt. **Next level**
is the primary action after a clear, including a one-star clear. Additional rescue
goals never delay progression. At a boundary, Continue or level selection follows
the original campaign flow. **Try again** is the primary action after failure.

Press **R** to retry, **Enter** or **Space** for the primary action, or **V** to watch the replay. Replays
stay in the game window; their controls include speed, seeking and movie export.
**Records & awards** (or **B**) opens the detailed pages. **Escape** returns to the
result without advancing the level. Opening settings or another game page pauses
the simulation underneath it. Back returns to the previous page.

The detailed pages separate three kinds of information:

- **Leaderboards:** rescue, efficiency and 100% rankings among local players.
- **Achievements:** six level challenges, with earned and locked states.
- **Run details:** most-used skill, time, none/all rescued, attempt history and
  maximum-rescue information.

**Level Records** (Command-Shift-B) opens the current level's boards. The record
browser also lets you revisit levels with stored scores. The three boards are:

| Board | Ranking |
| --- | --- |
| Most saved | Most rescued, then fewer skills, then faster time |
| Fewest skills | Fewest skills among runs that met the rescue target, then more rescued and faster time |
| 100% club | Every starting lemming rescued, then fewer skills and faster time |

Each board keeps one best entry per player. The top five appear on screen.
Changing boards does not discard other personal bests. Failed runs remain in
attempt statistics and cannot win the skill-efficiency board. Ties use the earlier
run. Most-used skill counts accepted assignments, not unsuccessful clicks.

Boards compare the same level data, rules and starting population. L2 carry-over
populations have separate boards. Legacy L2 efficiency records used the gold-medal target. New Trolley records use
the engine's pass condition (one rescued) and retain the gold target separately.
Rewind and nuke-undo attempts use separate boards and level achievements. Classic
rewind and nuke undo restore the solution's skill count with the game state.
L2 counts consumed skill supplies. L3 counts accepted action and tool-use commands.
Fast-forward and pauses do not change the simulation time used for ranking.

The population ceiling is an upper bound, not an assertion that a level permits
100%. **Best demonstrated rescue** is the best completed solution recorded on this Mac.
A recorded 100% rescue demonstrates that ceiling. Trolley evidence remains
OBSERVED until a sourced verification is explicitly accepted. Lower mathematical
maxima need a solver or verified level analysis and are not guessed. In L3, reserve
lemmings have not passed through an exit. They do not count as rescued or award a
100% rescue. Its experimental rules have their own records.

Records start with this build. Older campaign saves lack skill-use and complete
attempt data, so they are not converted into leaderboard entries. Level awards
are separate from the existing ordered-campaign achievements.

The app stores profiles and records atomically in
`~/Library/Application Support/Ultimate Lemmings/Arcade/records-v1.json`.
Development preview apps use `Arcade Preview` instead. New profile campaign saves
use separate preference keys. A corrupt record file is preserved. The app shows
an error instead of replacing it with an empty file.

Run `Scripts/run-arcade-records-tests.sh` for ranking, retention, profile isolation,
save/reload, UI controls, and rendered profile/result screens. The app integration
and sequel-view tests check actual completion callbacks and retries.

Successful result screens now lead with Next level (Enter or Space). Retry is
optional. The shared three-star rescue goals and evidence rules are documented in
[The Trolley](TheTrolley.md#optional-rescue-stars). Failures lead with Try again.

Click **new award** on a result, or press **A**, to open the highest-tier new
award. Awards from that run have a gold outline and a **NEW** label. **Next new**
visits the other new awards across pages and collections. The highlights remain
while reviewing that result and clear when a new result, records session or
profile page opens.

The result now shows explicit rescue stars, named level and career awards,
near misses, and career progress. Local and worldwide ranking links use the
[results and rewards](ResultRewards.md) flow. Worldwide service uses
[Apple Game Center](GameCenterSetup.md) after release configuration.
