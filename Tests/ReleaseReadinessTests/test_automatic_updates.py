import base64
from pathlib import Path
import plistlib
import tempfile
import unittest
from xml.etree import ElementTree

ROOT = Path(__file__).resolve().parents[2]
import sys
sys.path.insert(0, str(ROOT / "Tools/ReleaseReadiness"))
from automatic_updates import validate_appcast, validate_info_plist, validate_repository


class AutomaticUpdateTests(unittest.TestCase):
    def test_current_inputs_are_valid_with_an_empty_development_feed(self):
        version, build, items = validate_repository(ROOT, allow_empty=True)
        self.assertEqual(version, "1.2")
        self.assertTrue(build.isdigit())
        self.assertEqual(items, 0)

    def test_info_plist_rejects_an_invalid_public_key(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "Info.plist"
            info = plistlib.loads((ROOT / "Resources/Info.plist").read_bytes())
            info["SUPublicEDKey"] = base64.b64encode(b"not a key").decode()
            path.write_bytes(plistlib.dumps(info))
            with self.assertRaisesRegex(ValueError, "Ed25519"):
                validate_info_plist(path)

    def test_release_feed_requires_signed_https_enclosures(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "appcast.xml"
            root = ElementTree.Element("rss")
            channel = ElementTree.SubElement(root, "channel")
            item = ElementTree.SubElement(channel, "item")
            ElementTree.SubElement(item, "enclosure", {
                "url": "http://example.invalid/update.zip",
                "{http://www.andymatuschak.org/xml-namespaces/sparkle}version": "40",
                "{http://www.andymatuschak.org/xml-namespaces/sparkle}shortVersionString": "1.2",
            })
            ElementTree.ElementTree(root).write(path, encoding="utf-8", xml_declaration=True)
            with self.assertRaisesRegex(ValueError, "HTTPS"):
                validate_appcast(path)

    def test_signed_https_feed_is_accepted(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "appcast.xml"
            namespace = "http://www.andymatuschak.org/xml-namespaces/sparkle"
            root = ElementTree.Element("rss")
            channel = ElementTree.SubElement(root, "channel")
            item = ElementTree.SubElement(channel, "item")
            ElementTree.SubElement(item, "enclosure", {
                "url": "https://example.invalid/update.zip",
                f"{{{namespace}}}version": "40",
                f"{{{namespace}}}shortVersionString": "1.2",
                f"{{{namespace}}}edSignature": "signed",
            })
            ElementTree.ElementTree(root).write(path, encoding="utf-8", xml_declaration=True)
            self.assertEqual(validate_appcast(path), 1)

    def test_empty_feed_is_not_valid_for_a_release(self):
        with self.assertRaisesRegex(ValueError, "update item"):
            validate_appcast(ROOT / "appcast.xml")


if __name__ == "__main__":
    unittest.main()
