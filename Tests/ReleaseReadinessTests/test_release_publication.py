import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from xml.etree import ElementTree


ROOT = Path(__file__).resolve().parents[2]
SPARKLE = "http://www.andymatuschak.org/xml-namespaces/sparkle"


class ReleasePublicationTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        root = Path(self.directory.name)
        self.commit = subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True
        ).strip()
        self.archive = root / "UltimateLemmings-1.5-build45.zip"
        self.archive.write_bytes(b"test update archive")
        self.notes = root / "ReleaseNotes.md"
        self.notes.write_text(f"Build: 45\nRelease commit: {self.commit}\n")
        self.appcast = root / "appcast.xml"
        self.write_appcast()

    def write_appcast(self, *, length=None, commit=None):
        root = ElementTree.Element("rss")
        channel = ElementTree.SubElement(root, "channel")
        item = ElementTree.SubElement(channel, "item")
        ElementTree.SubElement(item, f"{{{SPARKLE}}}version").text = "45"
        ElementTree.SubElement(item, f"{{{SPARKLE}}}shortVersionString").text = "1.5"
        ElementTree.SubElement(item, "description").text = (
            f"Release commit: {commit or self.commit}"
        )
        ElementTree.SubElement(item, "enclosure", {
            "url": f"https://example.invalid/{self.archive.name}",
            "length": str(length if length is not None else self.archive.stat().st_size),
            f"{{{SPARKLE}}}edSignature": "signed",
        })
        ElementTree.ElementTree(root).write(self.appcast, encoding="utf-8")

    def run_publication(self, *options, **extra):
        env = dict(os.environ, RELEASE_TAG="v1.5.0", RELEASE_VERSION="1.5",
                   RELEASE_COMMIT=self.commit, RELEASE_NOTES_PATH=str(self.notes),
                   APPCAST_PATH=str(self.appcast), **extra)
        return subprocess.run(
            ["zsh", "Scripts/publish-github-release.sh", *options, str(self.archive)],
            cwd=ROOT, env=env, capture_output=True, text=True, check=False
        )

    def test_check_accepts_matching_inputs_without_publication(self):
        result = self.run_publication("--check")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("PASS publication inputs", result.stdout)

    def test_check_rejects_wrong_archive_length(self):
        self.write_appcast(length=1)
        result = self.run_publication("--check")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("archive length", result.stderr)

    def test_check_rejects_wrong_feed_commit(self):
        self.write_appcast(commit="0" * 40)
        result = self.run_publication("--check")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("frozen commit", result.stderr)

    def test_check_accepts_a_matching_slim_download(self):
        slim = self.archive.with_name("UltimateLemmings-1.5-build45-slim.zip")
        slim.write_bytes(b"slim download")
        result = self.run_publication("--check", DOWNLOAD_ZIP=str(slim))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_check_rejects_a_misnamed_slim_download(self):
        slim = self.archive.with_name("UltimateLemmings-1.5-build44-slim.zip")
        slim.write_bytes(b"slim download")
        result = self.run_publication("--check", DOWNLOAD_ZIP=str(slim))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("download archive name", result.stderr)

    def test_publication_requires_approval(self):
        result = self.run_publication()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("RELEASE_APPROVED=1", result.stderr)


if __name__ == "__main__":
    unittest.main()
