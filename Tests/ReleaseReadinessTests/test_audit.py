"""Reject changed evidence and incomplete release closure."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("audit", Path(__file__).resolve().parents[2] / "Tools/ReleaseReadiness/audit.py")
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)


class AuditTests(unittest.TestCase):
    def test_closure_requires_all_checks_and_gates(self):
        passed = [{"status": "passed"}]
        closed = [{"status": "closed"}]
        self.assertEqual(audit.exit_status(passed, [], closed, True), 0)
        for status in ["open", "partial", "external", "not-implemented"]:
            self.assertEqual(audit.exit_status(passed, [], [{"status": status}], True), 2)
        self.assertEqual(audit.exit_status([{"status": "not-run"}], [], closed, True), 2)
        self.assertEqual(audit.exit_status([{"status": "failed"}], [], closed, False), 1)
        self.assertEqual(audit.exit_status(passed, ["asset.dat"], closed, False), 1)
        self.assertEqual(audit.exit_status(passed, [], [{"status": "open"}], False), 0)

    def test_assets_and_replay_evidence_are_hashed(self):
        original = audit.ROOT
        with tempfile.TemporaryDirectory() as temporary:
            audit.ROOT = Path(temporary)
            try:
                names = ["Sources/Ports/game.dat", "Resources/Info.plist",
                         "Documentation/CampaignCompletion/routes.json",
                         "Documentation/Lemmings2Completion/evidence.json",
                         "Documentation/ReleaseReadiness/gates.json",
                         ".build/local/Ultimate Lemmings.app/Contents/Resources/level.dat"]
                for name in names:
                    path = audit.ROOT / name
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.write_bytes(b"original")
                before = audit.manifest(audit.input_paths())
                self.assertTrue(set(names).issubset(before))
                for name in names:
                    (audit.ROOT / name).write_bytes(b"changed")
                after = audit.manifest(audit.input_paths())
                self.assertTrue(all(before[name] != after[name] for name in names))
                (audit.ROOT / names[0]).unlink()
                self.assertNotIn(names[0], audit.manifest(audit.input_paths()))
            finally:
                audit.ROOT = original


if __name__ == "__main__":
    unittest.main()
