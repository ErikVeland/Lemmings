import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "Tools/IOSBeta"))
import artwork


class MobileArtworkPackagingTests(unittest.TestCase):
    def test_linked_family_copies_all_sibling_banks(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            exported = root / "exported"
            for family in (*artwork.FAMILIES, *("monochrome/" + f for f in artwork.FAMILIES)):
                bank = exported / family
                bank.mkdir(parents=True)
                (bank / "manifest.json").write_text(json.dumps({"banks": {"1": [{"file": "1.rgba"}]}}))
                (bank / "1.rgba").write_bytes(family.encode())
            link = root / "staging/lemmings"
            link.parent.mkdir()
            link.symlink_to(exported / "lemmings", target_is_directory=True)
            destination = root / "TV.app/MacArtwork/lemmings"
            with patch.dict(artwork.os.environ, {"IOS_AMIGA_ARTWORK_DIR": str(root / "no-amiga")}):
                artwork.copy_into_app(link, destination)
            self.assertEqual(artwork.mac_root(link), exported.resolve())
            for family in (*artwork.FAMILIES, *("monochrome/" + f for f in artwork.FAMILIES)):
                self.assertEqual((destination.parent / family / "1.rgba").read_bytes(), family.encode())


if __name__ == "__main__":
    unittest.main()
