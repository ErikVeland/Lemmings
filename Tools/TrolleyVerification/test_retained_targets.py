import unittest
from catalogue import require_retained_targets


class RetainedTargetsTests(unittest.TestCase):
    def test_explicit_ruleset_transition_retires_only_old_rules(self):
        change = [{"gameIDs": ["lemmings3"],
                   "rulesetTransition": {"from": "old", "to": "new"}}]
        def row(game, version, saved):
            return {"conditions": {"gameID": game, "levelID": "1",
                                   "levelFingerprint": "unchanged", "rulesetVersion": version},
                    "witness": {"saved": saved}, "title": "Example"}
        previous = row("lemmings3", "old", 50)
        require_retained_targets([row("lemmings3", "new", 1)], [previous], change)
        unknown = row("lemmings3", "new", 0)
        unknown["witness"] = None
        require_retained_targets([unknown], [previous], change)
        for current in [[], [row("lemmings3", "old", 1)], [row("lemmings3", "future", 1)],
                        [row("lemmings2", "new", 1)]]:
            with self.assertRaises(ValueError):
                require_retained_targets(current, [previous], change)
        with self.assertRaises(ValueError):
            require_retained_targets([row("lemmings2", "new", 1)],
                                     [row("lemmings2", "old", 50)], change)

    def test_missing_and_lower_targets_fail(self):
        original = {"conditions": {"levelID": "level-1"}, "witness": {"saved": 50}, "title": "Example"}
        require_retained_targets([original], [original])
        require_retained_targets([{**original, "witness": {"saved": 60}}], [original])
        for current in [[], [{**original, "witness": {"saved": 49}}],
                        [{**original, "witness": None}],
                        [{**original, "conditions": {"levelID": "level-2"}}]]:
            with self.assertRaises(ValueError):
                require_retained_targets(current, [original])


    def test_rule_change_retires_only_changed_levels(self):
        change = [{"gameIDs": ["ohNoMoreLemmings"], "ranks": {"ohYesMoreLemmings": ["Oh No! More Lemmings Versus"]}}]
        def row(game, fingerprint, saved=50, rank="Tame"):
            return {"conditions": {"gameID": game, "levelID": "level-1", "levelFingerprint": fingerprint},
                    "witness": {"saved": saved}, "rank": rank, "title": "Example"}
        # The rule change altered the level: the old target lapses.
        require_retained_targets([row("ohNoMoreLemmings", "new", 40)], [row("ohNoMoreLemmings", "old")], change)
        require_retained_targets([row("ohYesMoreLemmings", "new", 1, "Oh No! More Lemmings Versus")],
                                 [row("ohYesMoreLemmings", "old", 40, "Oh No! More Lemmings Versus")], change)
        for current, published in [
            # Unchanged level: its target still applies.
            ([row("ohNoMoreLemmings", "old", 40)], [row("ohNoMoreLemmings", "old")]),
            # A game outside the change keeps every target.
            ([row("lemmings", "new", 40)], [row("lemmings", "old")]),
            ([row("ohYesMoreLemmings", "new", 1, "Lemmings Versus")], [row("ohYesMoreLemmings", "old", 40, "Lemmings Versus")]),
            # A level missing from the audit is never excused.
            ([], [row("ohNoMoreLemmings", "old")]),
        ]:
            with self.assertRaises(ValueError):
                require_retained_targets(current, published, change)


if __name__ == '__main__':
    unittest.main()
