# Ultimate Lemmings 2.0.4 for Macintosh

Build: 87
Release base: v2.0.3

This maintenance release fixes worldwide leaderboard verification and saved
journeys. It also makes the game simulations faster.

## Worldwide leaderboards

A Classic leaderboard entry now records a fingerprint of the exact level.
The fingerprint includes terrain, steel, entrances, traps, exits, skills and
counters. Previously, a route from a different level with the same terrain and
counters could pass verification. Entries recorded before this update still
verify.

## Journey

A revised journey no longer repeats its opening levels for a saved run.
Previously, a change in the journey order queued every level that the run had
not visited, starting again from the first level.

The journey now resumes after the furthest level that you reached in the new
order. Earlier levels that you skipped appear in **Come back to these**. They do
not count as wins. Levels that you won in the journey or in a Classic campaign
do not come back.

## Performance

Classic, The Tribes and NeoLemmix levels use less processing time. Classic
replays with blockers run up to a third faster. Level results, replays and
saved runs are unchanged.

## Language selection

The 2.0.3 language fix is retained. Open **Settings > Gameplay > Language**.
Select a language to preview it. Choose **Apply** to save the choice or
**Back** to restore the previous language.

## Compatibility and known limits

The public app targets Apple silicon and Intel Macs running macOS 12.3 or later.
The slim fresh-install download contains essential music and offers optional
soundtrack libraries. Automatic updates retain the full soundtrack.

Classic and The Tribes retain their published Complete classifications.
Chronicles and NeoLemmix remain Beta. This update does not change level content
or the existing campaign and source-fidelity limits.

The eight translated language packs remain AI-assisted drafts. Human language
review, physical controllers, VoiceOver, audible listening, minimum-OS and Intel
hardware, HDR appearance and live cross-device synchronisation retain their
recorded validation gaps. Mobile and TV releases have separate gates.
