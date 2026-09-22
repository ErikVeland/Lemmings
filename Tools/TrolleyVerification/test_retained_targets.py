import unittest
from catalogue import require_retained_targets


class RetainedTargetsTests(unittest.TestCase):
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
