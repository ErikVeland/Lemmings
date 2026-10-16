from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "Tools/RepositoryMaintenance"))
from check import check_files


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


if __name__ == "__main__":
    unittest.main()
