import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "Tools/IOSBeta"))
import artwork


class MobileArtworkPackagingTests(unittest.TestCase):
    def make_fonts(self, bank):
        document = json.loads((bank / "manifest.json").read_text())
        document["names"] = {"1301": "Charset1", "1302": "Charset2"}
        for key in document["names"]:
            file = key + ".rgba"
            (bank / file).write_bytes(bytes([0, 96, 192, 255]))
            document["banks"][key] = [None] + [{"file": file, "x": 0, "y": 0, "width": 1, "height": 1}] * 94
        (bank / "manifest.json").write_text(json.dumps(document))

    def test_linked_family_copies_all_sibling_banks(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            exported = root / "exported"
            for family in (*artwork.FAMILIES, *("monochrome/" + f for f in artwork.FAMILIES)):
                bank = exported / family
                bank.mkdir(parents=True)
                (bank / "manifest.json").write_text(json.dumps({"banks": {"1": [{"file": "1.rgba"}]}}))
                (bank / "1.rgba").write_bytes(family.encode())
            self.make_fonts(exported / "lemmings")
            link = root / "staging/lemmings"
            link.parent.mkdir()
            link.symlink_to(exported / "lemmings", target_is_directory=True)
            destination = root / "TV.app/MacArtwork/lemmings"
            with patch.dict(artwork.os.environ, {"IOS_AMIGA_ARTWORK_DIR": str(root / "no-amiga")}):
                artwork.copy_into_app(link, destination)
            self.assertEqual(artwork.mac_root(link), exported.resolve())
            for family in (*artwork.FAMILIES, *("monochrome/" + f for f in artwork.FAMILIES)):
                self.assertEqual((destination.parent / family / "1.rgba").read_bytes(), family.encode())

    def test_broken_artwork_link_stops_packaging_before_writing_app(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            link = root / "lemmings"
            link.symlink_to(root / "deleted-release/MacArtwork/lemmings", target_is_directory=True)
            destination = root / "TV.app/MacArtwork/lemmings"
            with self.assertRaisesRegex(ValueError, "Missing or invalid menu fonts"):
                artwork.copy_into_app(link, destination)
            self.assertFalse(destination.parent.parent.exists())

    def test_missing_truncated_and_transparent_font_pixels_are_rejected(self):
        for failure in ("missing-bank", "missing-glyph", "missing-file", "truncated", "transparent"):
            with self.subTest(failure=failure), tempfile.TemporaryDirectory() as directory:
                bank = Path(directory)
                (bank / "manifest.json").write_text('{"banks": {}}')
                self.make_fonts(bank)
                document = json.loads((bank / "manifest.json").read_text())
                if failure == "missing-bank": del document["names"]["1302"]
                elif failure == "missing-glyph": document["banks"]["1301"][33] = None
                elif failure == "missing-file": (bank / "1301.rgba").unlink()
                elif failure == "truncated": (bank / "1301.rgba").write_bytes(b"\x00\x60")
                else: (bank / "1301.rgba").write_bytes(bytes(4))
                (bank / "manifest.json").write_text(json.dumps(document))
                with self.assertRaises(ValueError): artwork.verify_menu_fonts(bank)


if __name__ == "__main__":
    unittest.main()
