# Difficulty evaluation

This ledger covers 6020 bundled Classic fan levels and 794 bundled NeoLemmix levels. Every row has a difficulty score. A low-confidence score is a metadata estimate, not a completed playtest.

Verified winning replays support 2084 Classic fan scores and 322 NeoLemmix scores. The remaining 3939 non-official scores and 469 official conversion scores need a verified win.

The `playtest` column records the latest check. A passive loss or timeout only describes a run without player input. It does not prove that the level is impossible. Source-compatible replays can have an absent or different level version; their native wins are valid, but source parity is unverified.

The `issue` column records a replay-analysis failure where one occurred. Such rows keep their metadata score and do not count as verified wins.

A native win shows that this engine can complete the level. It does not independently prove physics parity with the source engine. The `physics_parity` column records partial assignment-state matches where checked and keeps the full parity gate separate.

Third-party replay archives and community styles remain in the ignored local build folder. The repository does not redistribute them. See `summary.json` for source digests.
