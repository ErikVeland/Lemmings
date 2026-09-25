# QoL and Hot Seat parity

QoL and Hot Seat are shared product requirements for Classic, Lemmings 2 and
Lemmings 3. A new feature must be checked in all three. Shared controls and
result pages define the behaviour. Engine limitations must remain explicit.
This requirement is also recorded in `AGENTS.md`.

| Behaviour | Classic | L2 | L3 |
| --- | --- | --- | --- |
| Shared speed controls, held ramp, latched speed and quick reset | Yes | Yes | Yes |
| Keyboard guide over paused play and searchable commands | Yes | Yes | Yes |
| Controller mapping, menu navigation and interruption pause | Yes | Yes | Yes |
| Assignment focus, last target and repeat assignment | Yes | Yes | Yes |
| Active Hot Seat owner badge | Yes | Yes | Yes |
| Explicit retry/continue result choices | Shared result page | Shared result page | Shared result page |
| Shared progress separate from solo progress | Yes | Yes | Yes |
| Saved attempts and paused recovery from the main library | Yes | Yes | Yes |
| Shared typed level browser | Complete and Playable packs | Preview, preserves unlocks | Preview, available levels only |
| Playlist and shuffled-run campaign isolation | Yes | Yes | Yes |
| Guarded Players/solo transitions through shared library UI | Yes | Yes | Yes |
| Paused Hot Seat retry | Yes | Yes | Yes |
| New-level handover | Briefing | Briefing | Paused play |
| Forward single step | Yes | Yes, added in this pass | Yes |
| Rewind/backward step | Classic DOS history | Not implemented | Not implemented |
| Tiered hints | Checked hints and general coaching | General coaching | General coaching |
| Automatic completed input routes | Classic DOS, including fan levels | Existing recorder | Not implemented |
| Verified solution playback | Matching bundled routes only | Not implemented | Not implemented |

## Gaps closed in this pass

- Hot Seat retries now wait paused in all three games, including Classic's
  previous-level retry for the incoming player. Attempt ownership stays fixed.
- L2 briefings show the incoming player's badge above the original artwork,
  without covering the skill list or level preview.
- L2 starts and retries clear held speed state. Direct L2 and L3 retries wait paused
  at normal speed. Starting an L2 briefing is the player's ready action, as in Classic. Solo retry behaviour is retained.
- L2 supports forward single stepping through the shared keyboard/controller
  command. A final step uses the normal completion, recording and results path.
  Held fan and aim input is released before stepping.
- L3's in-game Resume action now resumes the same attempt in one action.
  Main-library checkpoint recovery still restores paused, as in the other games.
- The shared level browser resolves engine, pack and level identity before it
  starts Classic, L2 or L3. Imported archives remain labelled Unverified. A
  changed archive is rejected before launch.
- Classic direct selection now follows the active player's progress in each
  rating. The Settings override unlocks all Classic cards without granting
  campaign progress.
- Profile-owned manual and random playlists can start all three engines through
  the shared typed route. Their stored active run keeps a fixed order and resume
  position without changing campaign, Hot Seat, recovery, route, replay or
  verified record state.
- Seeded playlist shuffle and fan-level `Shuffle all` do not repeat entries.
  Missing, changed and newly locked entries stop visibly.

## Remaining limits

L2 and L3 do not yet have a verified solution playback path or full rewind
history. Their hints must not claim to be checked winning solutions. The new
Classic solution viewer must not be reused with sequel data without engine-specific
input timing and outcome validation.

Mid-level player takeovers need shared-attempt attribution before they can be
added consistently. L2's fan and L3's direction/tool choices remain engine-specific
controls. Engine fidelity and winning-route coverage are separate from UI parity.

Automated controller tests use simulated input. No physical controller was
available. Physical-device and complete VoiceOver listening journeys remain open.

The browser checks presentation and typed routing with fixtures. Packaged
Classic, fan, L2 and L3 launch journeys remain open because commercial game data
is not present in this checkout. Playlist evidence currently covers the source,
model tests, storage tests, Settings tests and Classic game-flow tests. The full
1.2 content atlas remains separate work and is not complete.

Validation evidence for this pass: `.build/parity/qol.log`,
`.build/parity/focused-final.log` and `.build/parity/classic.log`.
The final focused run checks the completed briefing, retry, recovery, stepping
and Resume behaviour. The sequel checks also capture the Hot Seat badges,
paused panels, game artwork and control layouts.

The initial broader sequel suite stopped on a stale bundled L2 proof asset
identity. Beta 27 closes that mismatch: all five bundled witnesses replayed twice
against the freshly packaged assets, with identical witness bytes, input timing,
rescue counts and other conditions. Only their asset suffix changed. The complete
the earlier sequel suite passed with the live proof check enabled; there is no
excluded check. The retained witness details are in
`Documentation/TrolleyVerification/beta27-l2-proof-refresh.json`.

An older settings assertion also assumed native tabs were direct page children.
It now finds the tab view inside the game's drawn tab controls.
