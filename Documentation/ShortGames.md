# Short games

Short games offers optional five-level campaign routes through the existing
playlist and saved-run flows. The 227-lesson Classic Journey remains separate.

| Route | Exact levels | Mac | iPhone, iPad, Duo and TV |
| --- | --- | --- | --- |
| Classic opening | Original DOS Fun 1–5 | Available with matching data | Available with matching data |
| Classic follow-up | Original DOS Fun 6–10 | Available with matching data | Available with matching data |
| The Tribes opening | Classic tribe 1–5 | Available with matching data and isolated survivor carry-over | Available with matching data and isolated survivor carry-over |
| Chronicles opening | Classic tribe 1–5 | Unavailable because playlists cannot carry reserves | Unavailable because playlists cannot carry reserves |

On Mac, open Playlists, then Short games. On mobile and TV, open Collections,
then Short games. Play creates a normal saved playlist and fixed run snapshot.
The existing session choice and paused Hot Seat Ready handover still apply.
Browsing does not change the player, turn, Journey or campaign saves.

The catalogue pins the exact Classic level addresses and source revision, sequel
level hashes and retained winning-fixture hashes. Missing or changed sources
disable Play. The narrow campaign-lock exception applies only to the exact,
unshuffled catalogue order. Editing that order creates an ordinary playlist
subject to normal availability rules.

Mobile checks the original DOS game-data revision before offering either
Classic route. Each playlist entry keeps an installed-content fingerprint
through save, sync and resume. Browsing and loading check for replacement
files. Older entries without a fingerprint use their original rules.

On 5 November 2026, the Classic completion verifier ran each Fun 6–10
fixture twice against the original DOS data. Each pair matched.

| Level | Saved | Required | Ticks |
| --- | ---: | ---: | ---: |
| Fun 6 | 48 | 10 | 1695 |
| Fun 7 | 50 | 25 | 924 |
| Fun 8 | 80 | 76 | 1448 |
| Fun 9 | 80 | 72 | 535 |
| Fun 10 | 20 | 10 | 470 |

The Tribes starts its isolated Classic tribe at level 1 with 60 lemmings.
Later levels use that run's actual survivors through the existing L2 snapshot.
Retained route examples carry 60, 13, 13, 12 and 5 survivors through these five
levels. The first two use the normal completion
fixtures. Levels 3–5 also have matching carry-over fixtures in
`Tests/Lemmings2CompletionTests/Chains`.

Chronicles remains visibly unavailable because normal playlist launches create
a fresh campaign at each level. Enabling it requires per-run reserve/progress
snapshots across retry, advance, save, resume and Hot Seat, including cloud
archives. A fresh-population substitute would change the campaign rules.

Focused tests check fixture hashes, source changes, exact order and eligibility,
legacy mobile entries, shared saved-run ownership and isolated carry snapshots.
`testShortGames` renders the Mac page at two widths and checks its targets.
Browsing preserves the player, active run and campaign saves. The mobile
checks load all five follow-up levels in order, reopen at Fun 7 in the
original Hot Seat session and reject changed files with a stale manifest.
Physical touch, remote focus and VoiceOver still need device checks.
