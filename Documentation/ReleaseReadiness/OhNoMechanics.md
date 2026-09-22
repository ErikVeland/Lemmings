# Oh No! DOS rules

22 September 2026. The Classic engine now has two DOS rule sets. Original
Lemmings keeps its rules. Oh No! More Lemmings, both Xmas releases and both
Holiday releases use the later rules. This change follows a review of
Oh No! Havoc 20, which was not solvable in this engine.

## What changed

The later rules differ from the original rules in three ways:

| Behaviour | Original Lemmings | Later releases |
| --- | --- | --- |
| New lemming x position | Hatch x + 24 | Hatch x + 25 |
| Two-hatch release order | A-B-B-A | A-B-A-B |
| Climber given to a shrugging builder | The builder walks | The builder keeps its shrug |

`ClassicDOSMechanics` selects the rule set from the release and, for the
Oh Yes! pack, from the rank. The Oh No! versus levels use the later rules.
The other conversions and all fan levels keep the original rules.

Checkpoints saved before this change decode with the original rules. A
restored checkpoint keeps the hatch positions that it saved. The replay state
hash adds the rule set for the later rules only. Original-rule hashes do not
change, so the 120 original routes and their proofs stay valid.

## Evidence

The Amiga and DOS level records for Havoc 20 are the same, byte for byte. The
terrain is therefore correct. With spawn x + 24, every lemming from the left
hatch falls 78 pixels through a narrow shaft and dies. With x + 25, the first
lemming lands on a ledge at (601, 73), drops to (600, 92) and walks off that
second ledge to the right. The published walkthroughs describe this path.

[Lemmix](https://github.com/ericlangedijk/Lemmix) is a DOS engine that other
players use to check DOS routes. Its `DOSOHNO_MECHANICS` set has the same three
differences. Lemmix applies that set to Oh No!, Xmas 1991, Xmas 1992 and
Holiday 1994. Lemmix has no Holiday 1993 style. Holiday 1993 uses the same
later engine, so it gets the later rules here. This project reads the Lemmix
source for reference only and copies no code.

The original DOS game in DOSBox asks a manual-lookup copy-protection question.
No answer was available, so this review has no direct recording from the
original executable.

## Effect on routes

The owner chose the later rules for 1.0 on 22 September 2026, with the cost
known. Under the later rules, 46 of the 166 earlier Oh No!, Xmas and Holiday
routes still won. The level lab moved most of the others:

1. `transplant` replays an old route under the original rules. It records the
   position of each assigned lemming. It then gives the same skill to the
   matching lemming when that lemming reaches the same place.
2. `climb` makes small random changes to a partial route. It keeps a change if
   the rescue count does not fall.
3. The strict `recorded` import replays each new route twice.

Fixtures that no longer win are removed. Git history keeps them.

## Rescue certificates

Trolley keys each published rescue target by a level fingerprint. The new
hatch positions change the fingerprint of every affected level. The reviewed
`Tools/TrolleyVerification/rule-changes.json` names this change and the games
it covers. A target lapses only if its game is on that list and the current
audit has the same level with a different fingerprint. All other targets must
still be reproduced.
