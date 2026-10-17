# Ultimate Lemmings 2.0.5 for Macintosh

Build: 88
Release base: v2.0.4

This optimisation and hotfix release removes pauses at the end of a level, on
the result screen and when a level starts. These notes also summarise every
2.0 update, so players who skipped a patch can see all the changes.

## Smoother results and saves

A level result no longer pauses the game when you have a long play history.
Previously, the game analysed every saved attempt again when a level ended.
After a few hundred attempts, this pause could last many seconds.

The career leaderboard and the result screen now reuse earlier analysis. They
redraw without a delay. A new level starts without a full records write on the
main thread. The game saves the start in the background. Cloud progress no
longer rewrites its local file when nothing has changed.

Saved records, attempts and leaderboards keep the same format and content.
Earlier saves load without changes.

## Chronicles Moles

In Chronicles, a Mole that touches steel now follows the original game more
closely. It stops, moves down and starts to dig diagonally. Other protected
terrain still turns the Mole on its patrol. The bundled Chronicles routes keep
their 2.0.4 results.

## Earlier 2.0 updates

- **2.0:** Original Macintosh 1-bit artwork with a matching monochrome
  gameplay panel. Journeys and sequence playlists resume the saved attempt.
  Classic can show an optional ghost solution. Seven added language packs use
  the original bitmap fonts.
- **2.0.2:** Hot Seat retries show earlier players' latest attempts as coloured
  ghosts. Retry actions and rewards use clearer grouping.
- **2.0.3:** Language buttons accept clicks across their full width.
- **2.0.4:** Worldwide Classic leaderboard entries identify the exact level. A
  revised journey no longer repeats its opening levels. Classic, The Tribes and
  NeoLemmix levels use less processing time.

## Compatibility and known limits

The public app targets Apple silicon and Intel Macs running macOS 12.3 or later.
The slim fresh-install download contains essential music and offers optional
soundtrack libraries. Automatic updates retain the full soundtrack.

Classic and The Tribes retain their published Complete classifications.
Chronicles and NeoLemmix remain Beta. The Mole change does not close the
recorded Chronicles route and engine-fidelity limits.

The eight translated language packs remain AI-assisted drafts. Human language
review, physical controllers, VoiceOver, audible listening, minimum-OS and Intel
hardware, HDR appearance and live cross-device synchronisation retain their
recorded validation gaps. The iPhone, iPad and Apple TV 2.0.5 builds go to
TestFlight. Their separate release gates remain open.
