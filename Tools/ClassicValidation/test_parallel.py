import json
from pathlib import Path
import tempfile
import unittest

from parallel import merge


class MergeTests(unittest.TestCase):
    def test_merge_preserves_disjoint_fan_levels_and_shared_official_evidence(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            official = {"collection": "lemmings", "source": "original/0", "status": "winning-replay", "witness": "route"}
            parts = []
            for i in range(2):
                part = root / str(i)
                part.mkdir()
                rows = [official, {"collection": "fan", "source": f"pack{i}/0", "status": "unverified"}]
                (part / "levels.jsonl").write_text("\n".join(map(json.dumps, rows)))
                (part / "packs.json").write_text(json.dumps([{"pack": f"pack{i}"}]))
                parts.append(part)
            merge(parts, root)
            self.assertEqual(len((root / "levels.jsonl").read_text().splitlines()), 3)
            self.assertEqual(len(json.loads((root / "packs.json").read_text())), 2)
            self.assertEqual(json.loads((root / "summary.json").read_text())["fan"]["unverified"], 2)
            with self.assertRaises(ValueError):
                merge([parts[0], parts[0]], root)
            changed = dict(official, status="unverified")
            (parts[1] / "levels.jsonl").write_text(json.dumps(changed))
            with self.assertRaises(ValueError):
                merge(parts, root)


if __name__ == "__main__":
    unittest.main()
