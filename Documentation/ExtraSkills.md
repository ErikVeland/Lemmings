# Bonus skills

Each player earns one rare Bonus skill for every ten distinct three-star levels
cleared without rewind, undo or a bonus skill. Classic, Lemmings 2 and Lemmings 3
share the same profile balance. Existing qualifying history counts. Repeating a
clear or changing its settings does not add another level to the milestone.

Spend at most one Bonus skill per attempt. Classic and Lemmings 2 add one use to
a finite skill supplied by the original level, including an exhausted skill.
NeoLemmix uses the same rule. Unlimited and absent skills are unavailable.
Lemmings 3 adds one charge to a selected active tool carrier. It never awards a
whole pickup box, a clock, or an unmetered command. An exhausted L3 tool that
has left its carrier cannot be topped up.

The charge is saved before the grant. It remains spent after a failure, retry,
rewind, abandoned attempt or restore. Rewinding before the grant can remove its
stock, but cannot permit a second grant. A retry starts a new attempt with the
original supplies. Profiles and Hot Seat players keep separate balances.

Bonus clears can advance the campaign. They show **Bonus skill used**, have
separate comparison conditions, and cannot earn consumables, career stars or
achievements. They cannot change standard rescue maxima or enter
Game Center or community rankings. Clearing a previously skipped level still
returns that earlier skip under the existing refund rule.

On Mac, **Bonus skill (N)** beside the gameplay menu opens the paused skill
chooser. **Command-E** opens the same page. Back cancels without spending.
**Use bonus skill** applies the selected top-up. The chooser preserves the
previous pause state and the Hot Seat Ready boundary. Phone, tablet and TV use
the shared pause menu and bitmap chooser.

Results name newly earned consumables. The rare receipt reads
**RARE: +1 BONUS SKILL**. Rewards earned retains the full earning reasons.
Mac Career progress shows the balance and progress towards the next ten levels.
Mac Zoom, Superzoom, Skip and Bonus skill badges fade with the gameplay menu,
including their backgrounds and active outlines. Hovering their retained area
or a menu control reveals them. Using a reward reveals them before fading
resumes. Paused Inspect remains visible without holding the badges on screen.

The records ledger stores immutable use evidence by attempt UUID. Cloud merges
keep every charge once. Concurrent offline spends remain debt until later
earnings cover them. Checkpoints carry the same evidence, including when a
rewind removes the grant event. A checkpoint received before its records can
restore the charge as debt until qualifying history arrives. Conflicting
evidence cannot replace a saved charge.

Older mobile L2/L3 records without comparison conditions cannot safely be
converted into qualifying history. New sequel attempts record those conditions.
Mobile and Mac sequel rules retain their existing distinct engine identifiers.

## Validation

Background checks passed five engine fixture groups, eleven policy and receipt
tests, five replay/recovery tests and five mobile runtime regressions. They
cover distinct-level earning, one grant per attempt, profile ownership, retry
and rewind, separate records, ranking/proof exclusions, save migration, cloud
merge debt and checkpoint recovery. Mobile validation also passed 108 bitmap
and action captures plus iOS and tvOS UI typechecks.

Muted, offscreen Mac integration checks passed live grants, checkpoint/replay
recovery, rewind limits and clean retries in all three games. Chooser selection,
cancel/confirm, keyboard and accessibility actions, hit targets, rare receipts,
bonus markers and menu/badge fade/reveal states passed at three window sizes.
The bitmap captures were visually reviewed, including active outlines.

Native NSWindow mouse delivery could not run in offscreen mode; those checks
verified target geometry and invoked the same control actions directly.
Foreground/composited CRT output, physical touch, TV remote and VoiceOver
interaction still need manual checks.
The [2.1 release audit](ReleaseReadiness/2.1-build93/README.md) checks 615 native
configurations and reproduces all 294 retained certificates and 315 rescue records.
Existing campaign, source-fidelity and physical-device limits remain open.
