import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path


sys.dont_write_bytecode = True
SCRIPT = Path(__file__).with_name("solve_fan_batch.py")
SPEC = importlib.util.spec_from_file_location("solve_fan_batch", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class LoadAuditRowsTests(unittest.TestCase):
    def test_keeps_only_unresolved_fan_rows_and_preserves_exact_member(self):
        rows = [
            {
                "collection": "fan",
                "initialHash": "a" * 64,
                "source": "0193-Gronklems-0.zip/Gronklems #1.dat#0",
                "status": "replay-failed",
                "title": "A level",
            },
            {
                "collection": "fan",
                "initialHash": "b" * 64,
                "source": "0001-geooPk0.zip/geooPk0.dat#2",
                "status": "winning-replay",
            },
            {
                "collection": "official",
                "initialHash": "c" * 64,
                "source": "official/level.dat#0",
                "status": "rendered-and-smoke-tested-only",
            },
        ]
        with tempfile.TemporaryDirectory() as directory:
            audit = Path(directory) / "levels.jsonl"
            audit.write_text("\n".join(json.dumps(row) for row in rows) + "\n")
            result = MODULE.load_rows(audit)

        self.assertEqual(len(result), 1)
        self.assertEqual(result[0]["entry"]["identity"], {
            "engine": "classic",
            "levelID": "Gronklems #1.dat#0",
            "packID": "fan:lldb-193",
        })
        self.assertEqual(result[0]["memberSelector"], "Gronklems #1.dat#0")
        self.assertEqual(result[0]["initialHash"], "a" * 64)

    def test_rejects_unparseable_fan_identity(self):
        row = {
            "collection": "fan",
            "initialHash": "a" * 64,
            "source": "not-a-pack/level.dat",
            "status": "replay-failed",
        }
        with tempfile.TemporaryDirectory() as directory:
            audit = Path(directory) / "levels.jsonl"
            audit.write_text(json.dumps(row) + "\n")
            with self.assertRaisesRegex(ValueError, "invalid fan identity"):
                MODULE.load_rows(audit)


class FilterPackTests(unittest.TestCase):
    def test_keeps_only_rows_for_requested_fan_pack(self):
        rows = [
            {"entry": {"identity": {"packID": "fan:lldb-193"}}},
            {"entry": {"identity": {"packID": "fan:lldb-194"}}},
        ]

        self.assertEqual(MODULE.filter_pack(rows, "fan:lldb-194"), [rows[1]])

    def test_rejects_invalid_pack_id(self):
        with self.assertRaisesRegex(ValueError, "invalid fan pack ID"):
            MODULE.filter_pack([], "lemmings_dos")


if __name__ == "__main__":
    unittest.main()
