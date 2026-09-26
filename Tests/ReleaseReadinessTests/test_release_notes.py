import sys
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "Tools/ReleaseReadiness"))
from release_notes import render_release_notes


class ReleaseNotesTests(unittest.TestCase):
    COMMIT = "a" * 40
    DRAFT = "# 1.5\n\nBuild: 45\nRelease base: v1.2-build41\n\nFixes.\n"

    def test_stamps_commit_without_changing_reviewed_text(self):
        result = render_release_notes(self.DRAFT, "45", "v1.2-build41", self.COMMIT)
        self.assertIn(f"Build: 45\nRelease commit: {self.COMMIT}\n", result)
        self.assertTrue(result.endswith("\n\nFixes.\n"))

    def test_rejects_a_stale_build_or_base(self):
        with self.assertRaisesRegex(ValueError, "build 46"):
            render_release_notes(self.DRAFT, "46", "v1.2-build41", self.COMMIT)
        with self.assertRaisesRegex(ValueError, "release base"):
            render_release_notes(self.DRAFT, "45", "v1.2-build40", self.COMMIT)

    def test_rejects_a_stale_or_duplicate_release_commit(self):
        draft = self.DRAFT + f"Release commit: {self.COMMIT}\n"
        with self.assertRaisesRegex(ValueError, "must not contain"):
            render_release_notes(draft, "45", "v1.2-build41", self.COMMIT)
        with self.assertRaisesRegex(ValueError, "exactly once"):
            render_release_notes(self.DRAFT + "Build: 45\n", "45", "v1.2-build41", self.COMMIT)

    def test_rejects_an_abbreviated_commit(self):
        with self.assertRaisesRegex(ValueError, "full Git SHA"):
            render_release_notes(self.DRAFT, "45", "v1.2-build41", "abc1234")


if __name__ == "__main__":
    unittest.main()
