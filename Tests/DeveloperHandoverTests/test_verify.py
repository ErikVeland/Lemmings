import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("handover_verify", ROOT / "Tools/DeveloperHandover/verify.py")
verify = importlib.util.module_from_spec(spec)
spec.loader.exec_module(verify)


class HandoverSnapshotTests(unittest.TestCase):
    def test_copies_working_edits_and_new_files_without_private_inputs(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "repo"
            root.mkdir()
            subprocess.run(["git", "init", "-q", str(root)], check=True)
            (root / ".gitignore").write_text("ignored.txt\n")
            (root / "engine.swift").write_text("before")
            (root / "deleted.swift").write_text("remove")
            (root / "key.p8").write_text("private-key-fixture")
            (root / "Content").mkdir()
            (root / "Content/game.bin").write_bytes(b"private-game-fixture")
            subprocess.run(["git", "add", "."], cwd=root, check=True)
            (root / "engine.swift").write_text("current working edit")
            (root / "deleted.swift").unlink()
            (root / "new.swift").write_text("new source")
            (root / "ignored.txt").write_text("ignored input")
            (root / "engine.swiftmodule").write_bytes(b"compiler output")
            target = Path(directory) / "snapshot"
            entries, omitted = verify.snapshot(root, target)
            paths = {entry["path"] for entry in entries}
            self.assertEqual(paths, {".gitignore", "engine.swift", "new.swift"})
            self.assertEqual((target / "engine.swift").read_text(), "current working edit")
            self.assertIn("Content/game.bin", omitted)
            self.assertIn("key.p8", omitted)
            self.assertNotIn("private-key-fixture", json.dumps(entries))
            self.assertEqual(next(e for e in entries if e["path"] == "new.swift")["sha256"],
                             verify.hashlib.sha256(b"new source").hexdigest())
            self.assertEqual(verify.changed_inputs(root, entries), [])
            (root / "engine.swift").write_text("edited during preparation")
            (root / "later.swift").write_text("new during preparation")
            self.assertEqual(verify.changed_inputs(root, entries), ["engine.swift", "later.swift"])

    def test_refuses_symlinks_to_files_outside_the_checkout(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "repo"
            root.mkdir()
            subprocess.run(["git", "init", "-q", str(root)], check=True)
            private = Path(directory) / "outside.txt"
            private.write_text("outside fixture")
            (root / "linked.swift").symlink_to(private)
            with self.assertRaisesRegex(ValueError, "Review symlink"):
                verify.snapshot(root, Path(directory) / "snapshot")

    def test_snapshot_uses_the_same_exclusions_as_repository_checks(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "repo"
            root.mkdir()
            subprocess.run(["git", "init", "-q", str(root)], check=True)
            names = ["signing.p12", "signing.pem", "signing.key", "app.mobileprovision",
                     ".swiftpm/config.json", "Content/game.json",
                     "Documentation/ReleaseReadiness/example/build/Audit",
                     "Tests/Fixtures/Content/level.json"]
            for name in names:
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("fixture")
            entries, omitted = verify.snapshot(root, Path(directory) / "snapshot")
            self.assertEqual({entry["path"] for entry in entries}, {"Tests/Fixtures/Content/level.json"})
            self.assertEqual(set(omitted), set(names[:-1]))

    def test_records_nonzero_exit_and_timeout_as_failures(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            failed = verify.run_check([sys.executable, "-c", "raise SystemExit(7)"],
                                      root, root / "failed.log", os.environ.copy(), 5)
            self.assertEqual(failed["status"], "failed")
            self.assertEqual(failed["exitCode"], 7)
            timed_out = verify.run_check([sys.executable, "-c", "import time; time.sleep(30)"],
                                         root, root / "timeout.log", os.environ.copy(), 0.1)
            self.assertEqual(timed_out["status"], "failed")
            self.assertIn("Timed out", timed_out["reason"])


if __name__ == "__main__":
    unittest.main()
