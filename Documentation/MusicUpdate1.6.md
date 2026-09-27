# Music update 1.6

Build 51 adds optional soundtrack libraries, rhythm-only pause and bar-aware
mixing to the shared music players used by Classic, Lemmings 2 and Lemmings 3.

## Selection and transitions

“Winnable” means the rescue target has been met: Classic's required count, or one
saved lemming in Lemmings 2 and 3. Ordinary telemetry, danger and nuking cannot
change tracks. The DJ allows one transition at that threshold. It uses an
explicit win cue from the current game and port, or the next available version
of the same composition. Completing the win does not trigger a second change.
An unwinnable run keeps its current tune and funeral slowdown through the result.
New levels and retries retain their deterministic composition assignment.

Compatible stable grids align both downbeats and fade over whole measured bars.
The planner requires matching meter, effective BPM within 1%, local bar lengths
within 4%, corresponding boundaries within 80 ms, a pickup no longer than two
seconds and a wait no longer than four seconds. Nearby tempos can match within
8%, with pitch compensation. The fade exchanges bass before completing an
equal-power overlap. Other pairs use a short beat-aware or timed fade. A pause
invalidates a pending mix plan; resume plans from the audible deck's current grid.

Variable-speed pitch remains independent of the mix tempo. The 1×, 2×, 3×, 5×
and 10× settings use pitch ratios 1, 1.04, 1.09, 1.18 and 1.35, with a 120 ms
glide and a hard cap of 1.50.

## Pause

The opt-in Audio setting isolates classified native percussion voices without
changing the tracker clock. Recorded tracks use an isolated, looping two-bar
excerpt where stable bar metadata and sufficient drum energy exist. The full
recording continues muted underneath; resume crossfades back over 80 ms. One-shot
cues stop their rhythm node when they end. There are 148 such loops. Separation
can leave melodic bleed; the loops are automated estimates, not full-song stems.

Unavailable rhythm parts and ordinary pause use a 160 ms vinyl stop: source speed
and gain fall together before the engine pauses. Rapid resume cancels the stop.
Frame-step and rewind also enter the chosen manual pause mode. Focus interruption
stays silent until the player resumes. Retry clears the previous audio pause while
keeping the gameplay countdown paused. No Hot Seat ownership or Ready flow changed.

## Bundles and installation

The main music set contains 54 essential versions, about 5.6 MB of original audio.
The remaining 441 versions form 18 libraries, around 4 GB combined. The app index
contains all composition identities and timing metadata. Downloads add recordings,
ports, remixes and prototypes without changing the selection rules. Derived drum
loops are hidden from track enumeration.

The first-launch soundtrack checklist follows the play-style choice and any upgrade
notes. Not now dismisses the offer once. Settings > Audio > Download soundtracks
reopens it. Select individual libraries or all extra soundtracks and review the
combined size. Downloads run in sequence and continue after the page closes. The
shared bitmap controls show progress, verification, installed and retry states.
Cancel preserves an existing installation; Remove deletes only the selected
optional library. Full bundles report those libraries as Included.

See [packaging](../Tools/MusicCatalogue/README.md) and
[analysis and rhythm generation](../Tools/MusicTiming/README.md) for reproducible commands.

## Validation and release status

- All 495 original versions have timing records: 276 stable BPM estimates and
  209 stable bar grids. These are automated classifications, not listening claims.
- All 18 archives and every member pass size/hash verification. Main and optional
  sets cover all 495 versions exactly once. Installation, replacement, corrupt
  updates and path rejection have local tests.
- Audio signal tests cover each speed pitch, preserved tempo, tempo-match pitch
  compensation, rhythm isolation, vinyl stop and rapid resume.
- App tests cover pause input and retry behaviour in all three engines. Rendered
  Audio and library states have input-target and keyboard checks.
- The local build is not a public release. The `music-1.6` asset URLs are prepared
  but the archives are not published; live public downloads are unverified.
- The fingerprint migration verified that all 105 replay-engine files are
  unchanged, validated all 268 witness hashes, and excluded four music-only files
  from future physics identities. Rescue proofs and hints use the new identity.
  See the [migration evidence](TrolleyVerification/presentation-fingerprint-migration.json).
- The optimized Apple silicon build passes the fresh-user launch check. Live
  multiplayer handovers and manual listening across every track remain validation gaps.

## Integrated 1.5 release work

The candidate includes changes through `origin/release/1.5.0` at `d8fbae2`: retry
vinyl motion, Mac Pop and supplied Yippee fallbacks, formatted Sparkle notes, archive
size checks and updated Old school validation. The split 1.6 bundle replaces the
full-library AAC conversion path so timing and rhythm hashes continue to match.
No replay-engine source changes were needed.
