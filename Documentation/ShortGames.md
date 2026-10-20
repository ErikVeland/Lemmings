# Short games

Short games offers optional five-level campaign openings through the existing
playlist and saved-run flows. The 227-lesson Classic Journey remains separate.

| Opening | Exact levels | Mac | iPhone, iPad and TV |
| --- | --- | --- | --- |
| Classic | Original DOS Fun 1–5 | Available with matching data | Available with matching data |
| The Tribes | Classic tribe 1–5 | Available with matching data and isolated survivor carry-over | Unavailable: sequel playlist playback is not implemented |
| Chronicles | Classic tribe 1–5 | Unavailable: playlists do not retain isolated reserve carry-over | Unavailable: sequel playlist playback is not implemented |

On Mac, open Playlists, then Short games. On mobile and TV, open Collections,
then Short games. Play creates a normal saved playlist and fixed run snapshot.
The existing session choice and paused Hot Seat Ready handover still apply.
Browsing does not change the player, turn, Journey or campaign saves.

The catalogue pins the exact Classic level addresses and source revision, sequel
level hashes and retained winning-fixture hashes. Missing or changed sources
disable Play. The narrow campaign-lock exception applies only to the exact,
unshuffled catalogue order. Editing that order creates an ordinary playlist
subject to normal availability rules.

The mobile Classic copy retains an installed-content fingerprint with every
entry. Playlist saves, shared collection archives and resumed runs retain it.
Both eager browsing and lazy run loading reject replacement bytes under the same
pack and level key. Old entries without a fingerprint keep their existing rules.

The Tribes starts its isolated Classic tribe at level 1 with 60 lemmings.
Later levels use that run's actual survivors through the existing L2 snapshot.
Retained route examples carry 60, 13, 13, 12 and 5 survivors through these five
levels. These examples establish working routes, not a smooth novice difficulty
curve or a maximum rescue target. The first two use the normal completion
fixtures. Levels 3–5 also have matching carry-over fixtures in
`Tests/Lemmings2CompletionTests/Chains`.

Chronicles remains visibly unavailable because normal playlist launches create
a fresh campaign at each level. Enabling it requires per-run reserve/progress
snapshots across retry, advance, save, resume and Hot Seat, including cloud
archives. A fresh-population substitute would change the campaign rules.

Focused tests check fixture hashes, source changes, exact order and eligibility,
legacy mobile entries, shared saved-run ownership and isolated carry snapshots.
`testShortGames` renders the Mac page at two widths and checks its targets and
non-mutating browsing. The shared navigation audit renders ready, missing and
loading states for phone, tablet and TV. These checks do not replace fresh
campaign replays or newcomer observation. Physical touch, remote focus,
VoiceOver and installed-device acceptance remain device checks.
