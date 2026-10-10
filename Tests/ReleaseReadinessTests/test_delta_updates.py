import plistlib
from pathlib import Path
import sys
import tempfile
import unittest
from xml.etree import ElementTree as ET
import zipfile

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "Tools/ReleaseReadiness"))
from automatic_updates import SPARKLE_NAMESPACE as NS, validate_appcast
from delta_updates import delta_assets, prepare_base, preserve_published_items, normalize_delta_names


class DeltaUpdateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.updates = self.root / "updates"
        self.updates.mkdir()
        self.base = self.root / ".build/release-1.9/updates/base.zip"
        self.base.parent.mkdir(parents=True)
        self.zip(self.base, 75)
        self.zip(self.updates / "new.zip", 76)
        self.feed = self.root / "appcast.xml"
        self.patch = self.updates / "Ultimate Lemmings76-75.delta"
        self.patch.write_bytes(b"patch")
        self.write_feed()

    def zip(self, path, build):
        with zipfile.ZipFile(path, "w") as archive:
            archive.writestr("Game.app/Contents/Info.plist",
                             plistlib.dumps({"CFBundleVersion": str(build)}))

    def write_feed(self, **delta_attrs):
        root = ET.Element("rss")
        channel = ET.SubElement(root, "channel")
        for build, name, length in ((76, "new.zip", 10),
                                    (75, "base.zip", self.base.stat().st_size)):
            item = ET.SubElement(channel, "item")
            ET.SubElement(item, f"{{{NS}}}version").text = str(build)
            ET.SubElement(item, f"{{{NS}}}shortVersionString").text = "1.9"
            ET.SubElement(item, "enclosure", {
                "url": f"https://example.invalid/{name}", "length": str(length),
                f"{{{NS}}}edSignature": "signed"})
            if build == 76:
                deltas = ET.SubElement(item, f"{{{NS}}}deltas")
                attrs = {"url": "https://example.invalid/Ultimate%20Lemmings76-75.delta",
                         "length": "5", f"{{{NS}}}edSignature": "signed",
                         f"{{{NS}}}deltaFrom": "75"}
                attrs.update(delta_attrs)
                ET.SubElement(deltas, "enclosure", attrs)
        ET.ElementTree(root).write(self.feed)

    def test_stages_previous_shipped_archive_from_release_directory(self):
        prepare_base(self.root, self.updates, self.feed)
        self.assertEqual((self.updates / "base.zip").read_bytes(), self.base.read_bytes())

    def test_missing_previous_archive_stops_generation(self):
        self.base.unlink()
        with self.assertRaisesRegex(ValueError, "PREVIOUS_UPDATE_ZIP"):
            prepare_base(self.root, self.updates, self.feed)

    def test_previous_archive_with_wrong_build_is_rejected(self):
        self.zip(self.base, 74)
        with self.assertRaisesRegex(ValueError, "wrong application build"):
            prepare_base(self.root, self.updates, self.feed)

    def test_signed_local_delta_is_ready_for_upload(self):
        self.assertEqual(delta_assets(self.feed, 76, self.updates), [self.patch])

    def test_missing_delta_from_latest_shipped_build_stops_publication(self):
        self.write_feed(**{f"{{{NS}}}deltaFrom": "74"})
        with self.assertRaisesRegex(ValueError, "previous shipped build 75"):
            delta_assets(self.feed, 76, self.updates)

    def test_missing_delta_file_stops_publication(self):
        self.patch.unlink()
        with self.assertRaisesRegex(ValueError, "Missing local delta"):
            delta_assets(self.feed, 76, self.updates)

    def test_delta_length_mismatch_stops_publication(self):
        self.patch.write_bytes(b"different")
        with self.assertRaisesRegex(ValueError, "length differs"):
            delta_assets(self.feed, 76, self.updates)

    def test_invalid_delta_metadata_is_rejected(self):
        for attrs, error in (({"url": "http://example.invalid/patch.delta"}, "HTTPS"),
                             ({f"{{{NS}}}edSignature": ""}, "edSignature"),
                             ({f"{{{NS}}}deltaFrom": "76"}, "older numeric build"),
                             ({"length": "0"}, "positive length")):
            with self.subTest(attrs=attrs):
                self.write_feed(**attrs)
                with self.assertRaisesRegex(ValueError, error):
                    validate_appcast(self.feed)

    def test_duplicate_delta_base_is_rejected(self):
        tree = ET.parse(self.feed)
        deltas = tree.find(f"./channel/item/{{{NS}}}deltas")
        ET.SubElement(deltas, "enclosure", dict(deltas[0].attrib))
        tree.write(self.feed)
        with self.assertRaisesRegex(ValueError, "Duplicate delta base"):
            validate_appcast(self.feed)

    def test_generation_keeps_published_base_urls_and_notes(self):
        previous = self.root / "previous.xml"
        previous.write_text(self.feed.read_text())
        self.feed.write_text(self.feed.read_text().replace(
            "https://example.invalid/base.zip", "https://example.invalid/new-release/base.zip"))
        preserve_published_items(previous, self.feed, 76)
        self.assertEqual(self.feed.read_text(), previous.read_text())
        self.assertEqual(delta_assets(self.feed, 76, self.updates), [self.patch])

    def test_normalizes_github_delta_filename_without_changing_signed_bytes(self):
        normalize_delta_names(self.feed, 76, self.updates)
        canonical = self.updates / "UltimateLemmings-build76-from75.delta"
        self.assertEqual(canonical.read_bytes(), self.patch.read_bytes())
        self.assertEqual(delta_assets(self.feed, 76, self.updates), [canonical])
        normalize_delta_names(self.feed, 76, self.updates)
        self.assertEqual(delta_assets(self.feed, 76, self.updates), [canonical])
