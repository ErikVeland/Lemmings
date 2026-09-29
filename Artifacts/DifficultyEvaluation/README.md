# Difficulty evaluation

This ledger covers 6020 bundled Classic fan levels and 794 bundled NeoLemmix levels. Every row has a difficulty score. A low-confidence score is a metadata estimate, not a completed playtest.

Verified winning replays support 2095 Classic fan scores and 322 NeoLemmix scores. The remaining 3928 non-official scores and 469 official conversion scores lack a verified win. Of the non-official rows, 4 bundled Classic levels cannot win under the current native object and rescue rules recorded below.

The `playtest` column records the latest check. A passive loss or timeout only describes a run without player input. It does not prove that the level is impossible. Source-compatible replays can have an absent or different level version; their native wins are valid, but source parity is unverified.

The `issue` column records a replay-analysis failure where one occurred. Such rows keep their metadata score and do not count as verified wins.

Classic fan rows marked `no functional exit` contain no exit object. The native fan runtime activates all 32 object slots when every exit would otherwise be inactive under the DOS rule. This gives the 30 late-exit levels functional exits; the ledger records their winning evidence separately. The inspected Golems assembly processes all 32 slots. Other native fan levels still use DOS object semantics, so full Golems parity is not established. See [the traditional Lemmix object rule](https://www.neolemmix.com/old/nle_piece_properties.html), `classic-structural-limits.json` and `validation.md`. A row marked `rescue requirement exceeds population` also cannot win on the bundled level.

A native win shows that this engine can complete the level. It does not independently prove physics parity with the source engine. The `physics_parity` column records partial assignment-state matches where checked and keeps the full parity gate separate.

Third-party replay archives and community styles remain in the ignored local build folder. The repository does not redistribute them. See `summary.json` for source digests.
