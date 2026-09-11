# 1.0 gap evaluation after beta 13

11 September 2026. Scope: the macOS game in this repository. This document does not
declare a 1.0 release. It measures the distance from beta 13 to one.

The [gate register](gates.json) holds the exit criteria. The
[1.0 gap review](../ReleaseReadiness-1.0.md) holds the change history. This
document ranks the open work and names the decision that controls the schedule.

## Position

Beta 13 is a complete beta. The source is frozen, every automated gate passes, and
the archive is signed, notarized and checked through Gatekeeper. That closes the
packaging question for a beta. It does not move the product near 1.0.

Six P0 gates remain open or partial. Four of them need new evidence or new work,
not another regression run. One of them, the publishing agreement, is outside
engineering control. A passing test suite cannot close any of them.

## Route evidence

A level counts as verified when a preserved replay wins it in the native engine and
a fresh run reproduces the outcome and the state hash.

| Campaign | Levels | Verified routes | Missing |
| --- | ---: | ---: | ---: |
| Lemmings (DOS original) | 120 | 120 | 0 |
| Oh No! More Lemmings | 100 | 54 | 46 |
| Xmas 1991 | 4 | 4 | 0 |
| Xmas 1992 | 4 | 2 | 2 |
| Holiday 1993 | 32 | 13 | 19 |
| Holiday 1994 | 32 | 15 | 17 |
| Lemmings 2 | 120 | 64 | 56 |
| Lemmings 3 | 90 | 16 | 74 |
| **Total** | **502** | **288** | **214** |

Missing evidence does not prove a level is broken. It proves nobody recorded a win.

Two further limits sit behind these numbers. 17 of the 120 original levels have a
winning route but no proven maximum rescue count. Converted and imported levels
carry their own separate evidence gap.

## Open work in priority order

### 1. Campaign routes (P0, open)

214 routes. This is the largest measurable item and the easiest to plan, because
each route is independent and the gate already rejects bad evidence. Route search
and manual play both work today. The cost is time, not design.

### 2. Sequel fidelity (P0, open)

L3 tool, movement and trap semantics remain provisional. Environmental effects,
original movie audio and story transitions are incomplete. L2 needs wider
original-engine comparison. This item has no fixed size, because each answer
depends on evidence from the original engines. It is the main schedule risk.

### 3. Performance and hardware (P0, open)

Nothing in the matrix is measured on physical hardware. The one measured number is
a shortfall: recent local samples reached 6.8x to 8.7x when the game requested 10x
with replay recording on. Physical Intel, macOS 13, SDR and HDR, multiple displays
and high refresh rates all remain untested. This work needs machines, not code.

### 4. Input and accessibility (P0, partial)

Remapping, conflict swapping, device glyphs and held-input reset are complete.
Scalable text and VoiceOver navigation are not. No journey has been tested with a
physical Xbox, PlayStation or Switch-layout controller.

### 5. Save and interruption recovery (P0, partial)

Versioned checkpoints cover Classic, NeoLemmix and native L2 and L3 campaigns.
Classic fan imports and L2 practice remain uncovered. Power-loss trials and
migration from an installed earlier release remain untested.

### 6. Release package (P0, partial)

Beta 13 proves the pipeline. The 1.0 candidate still needs its own freeze, build,
signature, notarization and Gatekeeper check. Beta notarization is not evidence for
a later build.

### 7. Publishing agreement and assets (P0, external)

The app contains commercial game data. No engineering task closes this gate. It
blocks every public release, on every platform, whatever the code does. Treat the
date it closes as unknown and independent of the other six items.

## The scope decision

The 214-route figure hides a choice. The classic family and the sequels are in very
different states, and 1.0 does not have to include both.

**Option A. Classic 1.0.** Ship Lemmings, Oh No!, Xmas and Holiday as complete.
Keep L2 and L3 in the app with their current preview labels. The route gap falls
from 214 to 84, all in a known engine with a working gate. Sequel fidelity leaves
the critical path and becomes post-1.0 work.

**Option B. Four-game 1.0.** Ship all four games as complete. This requires all 214
routes plus an open-ended fidelity program against two original engines.

Option A is the recommendation. It converts the largest open item from research
into countable work, and it keeps the sequels shipping and improving. The cost is
that the product name has to say what is complete and what is a preview, in the app
and in the store text.

## Out of scope for this repository

iPhone, iPad and consoles have no app target here. A `Package.swift` deployment
declaration is not an iOS app, and Mac controller support is not a console port.
A Mac 1.0 does not imply any of them.

## Next actions

1. Choose Option A or Option B. Every estimate below depends on this.
2. Under Option A, record the 84 remaining classic-family routes. Start with the 46
   Oh No! levels.
3. Book physical hardware time: an Intel Mac, a macOS 13 machine, an HDR display
   and three controller brands.
4. Close the 10x shortfall or restate the advertised limit to a measured number.
5. Add scalable text and VoiceOver navigation.
6. Extend checkpoints to classic fan imports and L2 practice.
7. Keep the publishing conversation separate and running. It does not wait on code.
