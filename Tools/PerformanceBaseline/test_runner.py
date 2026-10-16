import copy
import json
from pathlib import Path
import tempfile
import unittest
import hashlib

from run import compare, verify
from snapshot import capture_assets


class EvidenceComparisonTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.root = Path(self.directory.name)
        sample = dict(stateHash="abc", ticks=10, saved=2, width=320, height=160, population=10)
        self.rows = [dict(scenario=dict(id="one"), samples=[sample], allocationSample=sample)]

    def tearDown(self):
        self.directory.cleanup()

    def check_after(self, rows):
        before, after = self.root / "before.json", self.root / "after.json"
        before.write_text(json.dumps(self.rows))
        after.write_text(json.dumps(rows))
        compare(before, after)

    def test_changed_state_with_same_counts_fails(self):
        rows = copy.deepcopy(self.rows)
        rows[0]["samples"][0]["stateHash"] = "different"
        rows[0]["allocationSample"]["stateHash"] = "different"
        with self.assertRaisesRegex(ValueError, "Outcomes differ"):
            self.check_after(rows)

    def test_dropped_level_fails(self):
        with self.assertRaisesRegex(ValueError, "Empty result"):
            self.check_after([])

    def test_duplicate_level_fails(self):
        with self.assertRaisesRegex(ValueError, "Duplicate case"):
            self.check_after(self.rows * 2)

    def test_timing_change_preserves_identity(self):
        rows = copy.deepcopy(self.rows)
        rows[0]["samples"][0]["wallSeconds"] = 100
        self.check_after(rows)

    def test_same_outcome_different_level_fails(self):
        rows = copy.deepcopy(self.rows)
        rows[0]["scenario"]["level"] = "different-level"
        with self.assertRaisesRegex(ValueError, "Outcomes differ"):
            self.check_after(rows)

    def test_changed_snapshot_fails(self):
        manifest = self.root / "manifest.json"
        records = [dict(path="input", sha256="wrong")]
        aggregate = hashlib.sha256(json.dumps(records, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
        manifest.write_text(json.dumps(dict(treeSHA256=aggregate, files=records)))
        (self.root / "input").write_text("changed")
        with self.assertRaisesRegex(ValueError, "Snapshot changed"):
            verify(manifest, self.root)

    def test_asset_capture_survives_original_change(self):
        resources, neo, destination = [self.root / name for name in ["resources", "neo", "captured"]]
        for name in ["Ports", "LevelPacks", "Localization.bundle", "Hints", "Progression"]:
            (resources / name).mkdir(parents=True)
        for name in ["levels", "styles"]:
            (neo / name).mkdir(parents=True)
        original = resources / "Ports/input.dat"
        original.write_bytes(b"fixed")
        destination.mkdir()
        capture_assets(destination, resources, neo)
        original.write_bytes(b"changed")
        self.assertEqual((destination / "assets/resources/Ports/input.dat").read_bytes(), b"fixed")
        verify(destination / "assets-manifest.json", destination / "assets")


if __name__ == "__main__":
    unittest.main()
