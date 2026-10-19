from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "Tools/RepositoryMaintenance"))
from check import check_files
from repository_policy import contains_symlink, exclusion_reason, repository_files


class RepositoryMaintenanceTests(unittest.TestCase):
    def test_links_ignore_examples_urls_and_anchors_but_check_local_targets(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "Some File.md").write_text("# Target\n")
            (root / "README.md").write_text(
                '[Target](Some%20File.md) [Anchor](#target) [Web](https://example.com)\n'
                '```md\n[Example](missing-example.md)\n```\n[Missing](absent.md)\n')
            counts, errors = check_files(root, [Path("README.md")])
            self.assertEqual(counts["local_links"], 2)
            self.assertEqual(len(errors), 1)
            self.assertIn("absent.md", errors[0])

    def test_rejects_local_state_and_invalid_source_or_configuration(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "bad.py").write_text("def broken(\n")
            (root / "bad.json").write_text('{"missing": }')
            (root / "bad.sh").write_text("#!/bin/zsh\nif then\n")
            _, errors = check_files(root, [Path(p) for p in
                ("bad.py", "bad.json", "bad.sh", "Project/xcuserdata/state.plist", "key.p8")])
            self.assertEqual(len(errors), 5)

    def test_rejects_compiler_products_but_keeps_evidence_json(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            generated = ["crowd.swiftmodule", "crowd.swiftdoc", "crowd.swiftsourceinfo",
                         "crowd.abi.json", "libEngine.dylib", "engine.o"]
            for name in generated:
                (root / name).write_text("{}")
            evidence_build = Path("Documentation/ReleaseReadiness/example/build/Audit")
            (root / evidence_build).parent.mkdir(parents=True)
            (root / evidence_build).write_bytes(b"compiled audit fixture")
            (root / "audit.json").write_text('{"status": "passed"}')
            _, errors = check_files(root, [Path(p) for p in generated + ["audit.json"]] + [evidence_build])
            self.assertEqual(len(errors), len(generated) + 1)
            self.assertTrue(all("compiler output" in error for error in errors))

    def test_shared_policy_covers_private_inputs_without_excluding_fixtures(self):
        private_paths = ["key.p8", "key.p12", "key.pfx", "key.pem", "key.key",
                         "app.mobileprovision", "app.provisionprofile", "Sources/Ports/game.dat",
                         "Sources/Music/theme.wav", "Content/levels.json", "Project/.swiftpm/config.json",
                         "Documentation/ReleaseReadiness/example/build/Audit"]
        for name in private_paths:
            with self.subTest(path=name):
                self.assertIsNotNone(exclusion_reason(Path(name)))
        for name in ("Tests/Fixtures/Content/level.json", "Tests/Fixtures/sample.dat",
                     "Tools/RepositoryMaintenance/check.py", "Resources/Info.plist"):
            with self.subTest(path=name):
                self.assertIsNone(exclusion_reason(Path(name)))

    def test_checks_empty_scripts_and_refuses_symlink_targets(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "repo"
            root.mkdir()
            (root / "empty.sh").write_text("")
            # Invalid Python must never be opened through the link.
            outside = Path(directory) / "outside.py"
            outside.write_text("def broken(\n")
            (root / "linked.py").symlink_to(outside)
            (root / "linked-directory").symlink_to(outside.parent, target_is_directory=True)
            self.assertTrue(contains_symlink(root, Path("linked-directory/outside.py")))
            counts, errors = check_files(root, [Path("empty.sh"), Path("linked.py")])
            self.assertEqual(counts["shell"], 1)
            self.assertEqual(len(errors), 1)
            self.assertIn("symlinks", errors[0])

    def test_working_inventory_omits_deleted_files_and_includes_new_files(self):
        import subprocess

        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            subprocess.run(["git", "init", "-q", str(root)], check=True)
            (root / "deleted.swift").write_text("source")
            subprocess.run(["git", "add", "."], cwd=root, check=True)
            (root / "deleted.swift").unlink()
            (root / "new.swift").write_text("new source")
            self.assertEqual(repository_files(root), [Path("new.swift")])


if __name__ == "__main__":
    unittest.main()
