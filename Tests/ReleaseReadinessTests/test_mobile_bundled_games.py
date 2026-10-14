import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

TOOLS = Path(__file__).resolve().parents[2] / "Tools/IOSBeta"
sys.path.insert(0, str(TOOLS))
import games


class MobileBundledGamesTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.app = self.root / "Mobile.app"
        self.app.mkdir()
        self.ports = self.root / "Ports"
        self.neo = self.root / "NeoLemmix"
        self.addCleanup(patch.stopall)
        patch.object(games, "PORTS", self.ports).start()
        patch.object(games, "NEOLEMMIX", self.neo).start()
        for name, required in games.REQUIRED.items():
            for relative in required:
                path = self.ports / name / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                if relative in ("STYLES", "GRAPHICS"):
                    path.mkdir()
                else:
                    path.write_bytes(relative.encode())
            (self.ports / name / "GAME.EXE").write_bytes(b"code")
            (self.ports / name / "SAVE.SAV").write_bytes(b"save")
        (self.neo / "levels").mkdir(parents=True)
        (self.neo / "styles/default").mkdir(parents=True)
        (self.neo / "levels/example.nxlv").write_bytes(b"level")
        (self.neo / "sound").mkdir()
        for name in games.SOUNDS:
            (self.neo / "sound" / name).write_bytes(name.encode())
        self.manifest = {"soundSHA256": {name: hashlib.sha256(name.encode()).hexdigest()
                                       for name in games.SOUNDS}}
        (self.neo / "manifest.json").write_text(json.dumps(self.manifest))

    def test_bundles_sequels_and_all_neo_assets_and_extracts_native_l2_art(self):
        with patch.object(games.subprocess, "run") as extract:
            games.copy_into_app(self.app)
        self.assertEqual(extract.call_count, 1)
        for name in games.REQUIRED:
            self.assertFalse((self.app / "Ports" / name / "GAME.EXE").exists())
            self.assertFalse((self.app / "Ports" / name / "SAVE.SAV").exists())
            self.assertTrue((self.app / "Ports" / name / games.REQUIRED[name][0]).is_file())
        self.assertEqual((self.app / "NeoLemmix/levels/example.nxlv").read_bytes(), b"level")
        for name in games.SOUNDS:
            self.assertEqual((self.app / "NeoLemmix/sound" / name).read_bytes(), name.encode())

    def test_missing_game_fails_normal_build(self):
        (self.ports / "Lemm2/LEVELS/LEVEL000.DAT").unlink()
        with self.assertRaisesRegex(ValueError, "Missing Lemm2"):
            games.copy_into_app(self.app)

    def test_source_gate_cleans_stale_data_and_can_build_without_corpus(self):
        with patch.object(games.subprocess, "run"):
            games.copy_into_app(self.app)
        with patch.object(games, "PORTS", self.root / "missing"), patch.object(games, "NEOLEMMIX", self.root / "missing"):
            games.copy_into_app(self.app, source_gate=True)
        self.assertFalse((self.app / "Ports/Lemm2").exists())
        self.assertFalse((self.app / "Ports/LEM3CD").exists())
        self.assertFalse((self.app / "NeoLemmix").exists())

    def test_tampered_neo_sound_fails_build(self):
        (self.neo / "sound/chain.wav").write_bytes(b"changed")
        with patch.object(games.subprocess, "run"), self.assertRaisesRegex(ValueError, "Invalid NeoLemmix"):
            games.copy_into_app(self.app)
