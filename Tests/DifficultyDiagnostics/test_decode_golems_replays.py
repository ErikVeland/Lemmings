"""Regression checks for public Golems replay timing and action encoding."""

import struct
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "Tools/DifficultyDiagnostics"))
from decode_golems_replays import decode  # noqa: E402


class GolemsReplayTests(unittest.TestCase):
    def test_step_deltas_advance_cycles_and_rate(self):
        raw = bytes((3, 27, 254, 3)) + b"".join((
            struct.pack("<HBBBB", 71, 50, 2, 0, 0),
            struct.pack("<HBBBB", 32, 0, 2, 1, 0),
            struct.pack("<HBBBB", 0, 1, 0, 255, 255),
            struct.pack("<HBBBB", 0, 1, 0, 255, 255),
        ))
        events = decode(raw)
        self.assertEqual([event["tick"] for event in events], [71, 71, 104, 105, 106])
        self.assertEqual(events[0]["action"], {"releaseRate": {"_0": 50}})
        self.assertEqual(events[2]["action"],
                         {"assign": {"lemmingID": 1, "skill": "climber"}})
        self.assertEqual(events[-1]["action"], {"releaseRate": {"_0": 52}})

    def test_rejects_truncated_record(self):
        with self.assertRaises(ValueError):
            decode(bytes((3, 0, 0, 0, 1)))

    def test_terminal_abandon_requires_explicit_translation(self):
        raw = bytes((3, 10, 50, 0)) + struct.pack("<HBBBB", 49, 0, 10, 255, 255)
        with self.assertRaises(ValueError):
            decode(raw)
        self.assertEqual(decode(raw, abandon_as_nuke=True),
                         [{"tick": 49, "afterTick": True, "action": {"nuke": {}}}])


if __name__ == "__main__":
    unittest.main()
