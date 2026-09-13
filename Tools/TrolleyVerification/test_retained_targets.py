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


if __name__ == '__main__':
    unittest.main()
