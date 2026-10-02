# Difficulty evaluation

This ledger covers 6020 bundled fan levels in the native Classic playback lane and 794 bundled NeoLemmix levels. A row has a difficulty score only when a winning replay supports it. Low-confidence metadata estimates remain outside the score column.

299 rows in the Classic playback lane come from 20 packs that LLDB identifies as Lemmini. Two have a native Classic win and replay-based score; 297 remain unverified. The `source_engine` column separates known source families from the current playback lane; most other fan packs are not independently classified there. Classic's 160-pixel playfield cannot represent several of these levels' hatch and exit coordinates. This is an engine-family compatibility gap, not proof that the source puzzles are unsolvable. See `validation.md` for the pack list.

22 levels in packs 433, 495 and 496 use the Golems source player. Their source-engine label does not establish native physics parity. See `validation.md` and `classic-independent-source-checks.json`.

The four phase-corrected Golems evidence files hold 67 distinct exact-level native wins with ten-probe scores under opt-in Golems mechanics. Most remain outside the selected ledger. `Pass Interference` now has a separate ordinary-assignment win under the selected Golems profile for its exact bundled pack. Its selected digest and score are in `levels.csv`. The two-player alternative stays outside the learning path. See `classic-golems-phase-shift-third.json` and `validation.md`.

Verified winning replays support 2154 Classic fan scores and 322 NeoLemmix scores. The remaining 3869 non-official levels and 469 official conversion levels have no replay-based score. Of the non-official rows, 4 bundled Classic levels cannot win under the current native object and rescue rules recorded below.

The `playtest` column records the latest check. A passive loss or timeout only describes a run without player input. It does not prove that the level is impossible. Source-compatible replays can have an absent or different level version; their native wins are valid, but source parity is unverified.

The `issue` column records a replay-analysis failure where one occurred. Such rows have no replay-based score and do not count as verified wins.

Classic fan rows marked `no functional exit` contain no exit object. The native fan runtime activates all 32 object slots when every exit would otherwise be inactive under the DOS rule. This gives the 30 late-exit levels functional exits; the ledger records their winning evidence separately. The inspected Golems assembly processes all 32 slots. Other native fan levels still use DOS object semantics, so full Golems parity is not established. See [the traditional Lemmix object rule](https://www.neolemmix.com/old/nle_piece_properties.html), `classic-structural-limits.json` and `validation.md`. A row marked `rescue requirement exceeds population` also cannot win on the bundled level.

A native win shows that this engine can complete the level. It does not independently prove physics parity with the source engine. The `physics_parity` column records partial assignment-state matches and known object-rule replay differences where checked. The full parity gate remains separate.

`classic-independent-source-checks.json` records Golems browser runs of published `Holy Cow!` and `It's Raining Lemmings` replays. The source engine wins both. The exact native `Holy Cow!` input saves 0 of 20 after the source saves 18 of 20; the other input has a native assignment rejection. Both ledger rows flag these parity failures and stay unscored until native winning replays exist.

An isolated Golems fall-rule trial wins `It's Raining Lemmings` with the published input, but ends two ticks later than the source under later-release hatch rules. Across the two confirmed Golems packs, the same trial invalidates 11 of 14 current scored witnesses. The trial is diagnostic evidence; it is not a shipped native replay or a new ledger score. See `validation.md` and `classic-independent-source-checks.json`.

Bundled Classic fan playback uses the Golems timed-level clock, which allows two more update cycles than the DOS clock. Official Classic levels retain the DOS clock. [The clock audit](classic-fan-clock-audit.json) replayed 2,138 earlier fan witnesses: all retained their wins. The selected fan witnesses were then rescored with ten probes on the bundled levels. Three earlier replay-key mismatches were repaired from commands that won again under both clocks; their provenance is in `source-clock-candidates/replay-integrity-repairs.json`. See `validation.md` and `Tools/DifficultyDiagnostics/ClassicFanClockAudit/main.swift` for the source check.

The Classic replay initial-state hash covers the starting counters, workers and terrain mask. It omits entrance and trigger geometry. 11 unscored levels share that hash with scored levels but have different geometry. None won with a transferred replay. See `classic-state-hash-alias-checks.json`. Verify the exact archive fingerprint, level identity and native replay outcome for each row. `FAN_COMPARE_GOLEMS_OBJECTS=1` with `FAN_VERIFY_ONLY=1` in `ExpandFanEvidence` compares selected winning replays with all 32 object slots active. `classic-golems-object-comparisons.json` records those native rule comparisons; `python3 Tools/DifficultyDiagnostics/verify_golems_object_comparisons.py` checks their level and replay identities. These comparisons are not full source-physics checks.

1 affected level has a separate strictly replayed win under Golems' 32-slot object rule. The alternative score and replay are in `classic-golems-alternative-evidence.json` and `classic-golems-alternative-solutions.json`. Set `FAN_GOLEMS_OBJECTS=1` and `FAN_VERIFY_ONLY=1` in `ExpandFanEvidence` to recheck these alternative replays. This is object-rule compatibility evidence, not full source physics parity.

`classic-source-outcomes.json` compares unchanged published replay inputs against their saved-count and completion-tick headers. The `physics_parity` column flags saved-count differences and completion differences over five ticks. Saved count and completion within five ticks match on 89 of 134 unchanged source-input comparisons. A published header is limited outcome evidence, not a full simulation trace.

8 bundled Classic fan levels also have exact native wins from published Lemmings Plus I NeoLemmix replay inputs. Their source archive, per-replay digests and native replay digests are in `classic-neolemmix-replay-derivations.json`. Run `python3 Tools/DifficultyDiagnostics/verify_classic_neolemmix_replay_derivations.py` to check the identities, digests and input conversion; the optional source archive adds source-byte checks. These native wins do not establish source physics parity.

Third-party replay archives and community styles remain in the ignored local build folder. The repository does not redistribute them. See `summary.json` for source digests.
