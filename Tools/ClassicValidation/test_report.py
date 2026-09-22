import contextlib
import hashlib
import io
import json
from pathlib import Path
import tempfile
import unittest
import zipfile

from report import report


class CoverageTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.library = self.root / "LevelPacks"
        self.library.mkdir()
        self.output = self.root / "results"
        self.output.mkdir()
        with zipfile.ZipFile(self.library / "test.zip", "w") as archive:
            archive.writestr("test.lvl", b"fixture")
        self.packs = [{"pack": "test.zip", "decodedLevels": "1", "sha256": hashlib.sha256((self.library / "test.zip").read_bytes()).hexdigest()}]
        (self.library / "level-counts.json").write_text('{"test.zip": 1}')
        expected = {"lemmings": 120, "ohNoMoreLemmings": 100, "xmasLemmings1991": 4,
                    "xmasLemmings1992": 4, "holidayLemmings1993": 32, "holidayLemmings1994": 32,
                    "ohYesMoreLemmings": 60}
        self.rows = [{"collection": key, "source": f"{key}/{index}", "status": "winning-replay",
                      "witness": "fixture.json", "initialHash": "fixture"}
                     for key, count in expected.items() for index in range(count)]
        self.rows.append({"collection": "fan", "source": "test.zip/test.lvl#0", "status": "winning-replay",
                          "witness": "fixture.json", "initialHash": "fixture"})

    def run_report(self):
        (self.output / "levels.jsonl").write_text("\n".join(map(json.dumps, self.rows)))
        (self.output / "packs.json").write_text(json.dumps(self.packs))
        with contextlib.redirect_stdout(io.StringIO()):
            return report(self.root, self.output)

    def test_complete_fixture(self):
        self.assertTrue(self.run_report())

    def test_smoke_is_not_completion(self):
        self.rows[0]["status"] = "rendered-and-smoke-tested-only"
        self.assertFalse(self.run_report())

    def test_conversion_needs_a_win(self):
        next(row for row in self.rows if row["collection"] == "ohYesMoreLemmings")["status"] = "rendered-and-smoke-tested-only"
        self.assertFalse(self.run_report())

    def test_fan_level_needs_no_route(self):
        self.rows[-1] = {"collection": "fan", "source": "test.zip/test.lvl#0", "status": "rendered-and-smoke-tested-only"}
        self.assertTrue(self.run_report())

    def test_fan_level_must_load(self):
        self.rows[-1] = {"collection": "fan", "source": "test.zip/test.lvl#0", "status": "load-or-render-failed"}
        self.assertFalse(self.run_report())

    def test_missing_collection(self):
        self.rows = [row for row in self.rows if row["collection"] != "ohYesMoreLemmings"]
        self.assertFalse(self.run_report())

    def test_duplicate_rows(self):
        self.rows[-1] = self.rows[0]
        self.assertFalse(self.run_report())

    def test_missing_provenance(self):
        del self.rows[-1]["witness"]
        self.assertFalse(self.run_report())

    def test_modified_archive(self):
        with zipfile.ZipFile(self.library / "test.zip", "a") as archive:
            archive.writestr("hidden.lvl", b"unaccounted level")
        self.assertFalse(self.run_report())

    def test_hidden_content_even_with_current_hash(self):
        with zipfile.ZipFile(self.library / "test.zip", "a") as archive:
            archive.writestr("hidden.lvl", b"unaccounted level")
        self.packs[0]["sha256"] = hashlib.sha256((self.library / "test.zip").read_bytes()).hexdigest()
        self.assertFalse(self.run_report())

    def test_unindexed_pack(self):
        with zipfile.ZipFile(self.library / "new.zip", "w") as archive:
            archive.writestr("new.lvl", b"new level")
        self.assertFalse(self.run_report())


if __name__ == "__main__":
    unittest.main()
