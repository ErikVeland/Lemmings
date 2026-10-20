"""The installed version's history must exist before the update feed is published."""
import importlib.util
from pathlib import Path
import plistlib
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("bundle_about", ROOT / "Scripts/bundle-about.py")
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class AboutBundleTests(unittest.TestCase):
    def test_current_notes_precede_feed_and_are_not_duplicated(self):
        for published in (False, True):
            with self.subTest(published=published), tempfile.TemporaryDirectory() as temp:
                root = Path(temp)
                for folder in ("Resources/About", "Documentation", "Tools/Telemetry"):
                    (root / folder).mkdir(parents=True)
                (root / "Resources/Info.plist").write_bytes(plistlib.dumps({
                    "CFBundleShortVersionString": "2.0.7", "CFBundleVersion": "91"}))
                (root / "Documentation/ReleaseNotes-2.0.7-build91.md").write_text(
                    "# Ultimate Lemmings 2.0.7\n\nBuild: 91\nRelease base: v2.0.6\n\n"
                    "## Changes\n\n- First improvement\n- Second improvement\n")
                (root / "Tools/Telemetry/contributors.md").write_text("# Supporters\n\nA supporter\n")
                (root / "Resources/About/Heritage.md").write_text("# Original creators\n\nOffline heritage credits\n")
                def entry(version, build):
                    return (f"<item><sparkle:shortVersionString>{version}</sparkle:shortVersionString>"
                            f"<sparkle:version>{build}</sparkle:version>"
                            "<description><![CDATA[<p>iOS build 16<br/>tvOS build 6</p><h3>Earlier changes</h3><ul><li>One</li><li>Two</li></ul>]]>"
                            "</description></item>")
                (root / "appcast.xml").write_text(
                    '<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"><channel>'
                    + (entry("2.0.7", "91") if published else "") + entry("2.0.6", "90") + '</channel></rss>')
                destination = root / "About"
                MODULE.bundle(destination, root)
                history = (destination / "VersionHistory.md").read_text()
                self.assertTrue(history.startswith("# 2.0.7 · Build 91\n"))
                self.assertEqual(history.count("# 2.0.7 · Build 91"), 1)
                self.assertNotIn("Release base:", history)
                self.assertNotIn("\nBuild:", history)
                self.assertIn("## Changes\n\n- First improvement\n- Second improvement", history)
                self.assertIn("# 2.0.6 · Build 90", history)
                self.assertIn("- One\n- Two", history)
                self.assertIn("iOS build 16\n\ntvOS build 6", history)
                self.assertEqual((destination / "Contributors.md").read_text(), "# Supporters\n\nA supporter\n")
                self.assertEqual((destination / "Heritage.md").read_text(), "# Original creators\n\nOffline heritage credits\n")


if __name__ == "__main__":
    unittest.main()
