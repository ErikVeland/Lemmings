# Difficulty evaluation

This ledger covers 6020 bundled Classic fan levels and 794 bundled NeoLemmix levels. Every row has a difficulty score. A low-confidence score is a metadata estimate, not a completed playtest.

Verified winning replays support 2136 Classic fan scores and 322 NeoLemmix scores. The remaining 3887 non-official scores and 469 official conversion scores lack a verified win. Of the non-official rows, 4 bundled Classic levels cannot win under the current native object and rescue rules recorded below.

The `playtest` column records the latest check. A passive loss or timeout only describes a run without player input. It does not prove that the level is impossible. Source-compatible replays can have an absent or different level version; their native wins are valid, but source parity is unverified.

The `issue` column records a replay-analysis failure where one occurred. Such rows keep their metadata score and do not count as verified wins.

Classic fan rows marked `no functional exit` contain no exit object. The native fan runtime activates all 32 object slots when every exit would otherwise be inactive under the DOS rule. This gives the 30 late-exit levels functional exits; the ledger records their winning evidence separately. The inspected Golems assembly processes all 32 slots. Other native fan levels still use DOS object semantics, so full Golems parity is not established. See [the traditional Lemmix object rule](https://www.neolemmix.com/old/nle_piece_properties.html), `classic-structural-limits.json` and `validation.md`. A row marked `rescue requirement exceeds population` also cannot win on the bundled level.

A native win shows that this engine can complete the level. It does not independently prove physics parity with the source engine. The `physics_parity` column records partial assignment-state matches and known object-rule replay differences where checked. The full parity gate remains separate.

The Classic replay initial-state hash covers the starting counters, workers and terrain mask. It does not include configured object triggers. An archive fingerprint and a replay run under the current object rule are required alongside that hash. `FAN_COMPARE_GOLEMS_OBJECTS=1` with `FAN_VERIFY_ONLY=1` in `ExpandFanEvidence` compares selected winning replays with all 32 object slots active. `classic-golems-object-comparisons.json` records those native rule comparisons; `python3 Tools/DifficultyDiagnostics/verify_golems_object_comparisons.py` checks their level and replay identities. These comparisons are not full source-physics checks.

1 affected level has a separate strictly replayed win under Golems' 32-slot object rule. The alternative score and replay are in `classic-golems-alternative-evidence.json` and `classic-golems-alternative-solutions.json`. Set `FAN_GOLEMS_OBJECTS=1` and `FAN_VERIFY_ONLY=1` in `ExpandFanEvidence` to recheck these alternative replays. This is object-rule compatibility evidence, not full source physics parity.

`classic-source-outcomes.json` compares unchanged published replay inputs against their saved-count and completion-tick headers. The `physics_parity` column flags saved-count differences and completion differences over five ticks. Saved count and completion within five ticks match on 88 of 131 unchanged source-input comparisons. A published header is limited outcome evidence, not a full simulation trace.

8 bundled Classic fan levels also have exact native wins from published Lemmings Plus I NeoLemmix replay inputs. Their source archive, per-replay digests and native replay digests are in `classic-neolemmix-replay-derivations.json`. Run `python3 Tools/DifficultyDiagnostics/verify_classic_neolemmix_replay_derivations.py` to check the identities, digests and input conversion; the optional source archive adds source-byte checks. These native wins do not establish source physics parity.

Third-party replay archives and community styles remain in the ignored local build folder. The repository does not redistribute them. See `summary.json` for source digests.
