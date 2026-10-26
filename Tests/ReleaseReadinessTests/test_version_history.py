from pathlib import Path
import plistlib
import subprocess
import tempfile
import unittest

import sys
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "Tools/ReleaseReadiness"))
from version_history import validate


class VersionHistoryTests(unittest.TestCase):
    def make_repository(self, root):
        (root / "Resources").mkdir()
        (root / "Documentation").mkdir()
        (root / "Sources/LemmingsLocal").mkdir(parents=True)
        for path in (
            root / "Apps/UltimateLemmingsIOS/UltimateLemmingsIOS.xcodeproj",
            root / "Apps/UltimateLemmingsTV/UltimateLemmingsTV.xcodeproj",
        ):
            path.mkdir(parents=True)
            (path / "project.pbxproj").write_text(
                f"MARKETING_VERSION = 2.3; CURRENT_PROJECT_VERSION = {'34' if 'IOS' in str(path) else '13'};\n"
            )
        (root / "Resources/Info.plist").write_bytes(plistlib.dumps({
            "CFBundleShortVersionString": "2.3", "CFBundleVersion": "100"
        }))
        (root / "Documentation/ReleaseNotes-2.3-build100.md").write_text(
            "# Ultimate Lemmings 2.3\n\nBuild: 100\nRelease base: v2.2.2\n"
            "Platform builds: Mac 100, iPhone/iPad/Duo 34, Apple TV 13\n\nNotes.\n"
        )
        (root / "Documentation/ReleaseNotes.md").write_text(
            "The current source version is **2.3** (Mac build 100, iOS build 34, tvOS build 13).\n"
            "[Complete notes](ReleaseNotes-2.3-build100.md)\n"
        )
        (root / "Sources/LemmingsLocal/ReleaseWelcome.swift").write_text(
            'static let notesVersion = "2.3"\n'
        )
        subprocess.run(["git", "init", "-q", str(root)], check=True)
        subprocess.run(["git", "-C", str(root), "config", "user.email", "test@example.invalid"], check=True)
        subprocess.run(["git", "-C", str(root), "config", "user.name", "Test"], check=True)
        subprocess.run(["git", "-C", str(root), "add", "."], check=True)
        subprocess.run(["git", "-C", str(root), "commit", "-qm", "candidate metadata"], check=True)
        subprocess.run(["git", "-C", str(root), "tag", "v2.2.2"], check=True)

    def test_accepts_current_tracked_notes_and_matching_platform_versions(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.make_repository(root)
            self.assertEqual(validate(root), ("2.3", "100", "ReleaseNotes-2.3-build100.md"))

    def test_rejects_missing_current_history_link(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.make_repository(root)
            (root / "Documentation/ReleaseNotes.md").write_text("Old release only.\n")
            with self.assertRaisesRegex(ValueError, "must link the current version"):
                validate(root)

    def test_rejects_platform_version_drift(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.make_repository(root)
            project = root / "Apps/UltimateLemmingsTV/UltimateLemmingsTV.xcodeproj/project.pbxproj"
            project.write_text("MARKETING_VERSION = 2.2.2; CURRENT_PROJECT_VERSION = 13;\n")
            with self.assertRaisesRegex(ValueError, "marketing versions"):
                validate(root)


if __name__ == "__main__":
    unittest.main()
