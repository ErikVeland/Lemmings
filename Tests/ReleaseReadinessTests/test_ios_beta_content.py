import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

MODULE_PATH = Path(__file__).resolve().parents[2] / "Tools/IOSBeta/content.py"
spec = importlib.util.spec_from_file_location("ios_beta_content", MODULE_PATH)
content = importlib.util.module_from_spec(spec)
spec.loader.exec_module(content)


class IOSBetaContentTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.source = self.root / "source"
        self.source.mkdir()
        for name in content.REQUIRED:
            (self.source / name.lower()).write_bytes(name.encode())
        self.destination = self.root / "staged"

    def test_excludes_original_executables_and_records_exact_inputs(self):
        (self.source / "VGALEMMI.EXE").write_bytes(b"engine")
        content.stage(self.source, self.destination)
        manifest = content.verify(self.destination)
        self.assertEqual(set(manifest["files"]), content.REQUIRED)
        self.assertFalse((self.destination / "VGALEMMI.EXE").exists())
        with self.assertRaises(ValueError):
            content.stage(self.source, self.destination)

    def test_rejects_missing_duplicate_and_linked_inputs(self):
        (self.source / "main.dat").unlink()
        with self.assertRaises(ValueError):
            content.stage(self.source, self.destination)
        self.assertFalse(self.destination.exists())
        (self.source / "main.dat").write_bytes(b"main")
        # macOS usually has a case-insensitive filesystem. Model a provider
        # that returns two names for the same native data input.
        with patch.object(Path, "iterdir", return_value=iter([
            self.source / "main.dat", self.source / "MAIN.DAT",
        ])):
            with self.assertRaises(ValueError):
                content.stage(self.source, self.destination)
        (self.source / "main.dat").unlink()
        (self.source / "main.dat").symlink_to(self.source / "oddtable.dat")
        with self.assertRaises(ValueError):
            content.stage(self.source, self.destination)

    def test_rejects_tampering_extra_files_and_manifest_path_traversal(self):
        content.stage(self.source, self.destination)
        original = (self.destination / "MAIN.DAT").read_bytes()
        (self.destination / "MAIN.DAT").write_bytes(b"changed")
        with self.assertRaises(ValueError):
            content.verify(self.destination)
        (self.destination / "MAIN.DAT").write_bytes(original)
        (self.destination / "extra.dat").write_bytes(b"extra")
        with self.assertRaises(ValueError):
            content.verify(self.destination)
        (self.destination / "extra.dat").unlink()
        manifest = json.loads((self.destination / "manifest.json").read_text())
        manifest["files"]["../secret"] = "0" * 64
        (self.destination / "manifest.json").write_text(json.dumps(manifest))
        with self.assertRaises(ValueError):
            content.verify(self.destination)

    def test_source_only_build_removes_stale_bundled_data(self):
        content.stage(self.source, self.destination)
        app = self.root / "Test.app"
        app.mkdir()
        bundled = app / "BetaGameData"
        content.copy_into_app(str(self.destination), bundled)
        content.verify(bundled)
        content.copy_into_app("", bundled)
        self.assertFalse(bundled.exists())
        with self.assertRaises(ValueError):
            content.copy_into_app("", self.root / "BetaGameData")

    def test_local_debug_build_stages_campaign_without_original_executables(self):
        (self.source / "VGALEMMI.EXE").write_bytes(b"engine")
        app = self.root / "Debug.app"
        app.mkdir()
        bundled = app / "BetaGameData"
        content.copy_into_app("", bundled, str(self.source))
        self.assertEqual(set(content.verify(bundled)["files"]), content.REQUIRED)
        self.assertFalse((bundled / "VGALEMMI.EXE").exists())
        (self.source / "main.dat").write_bytes(b"updated local data")
        content.copy_into_app("", bundled, str(self.source))
        self.assertEqual((bundled / "MAIN.DAT").read_bytes(), b"updated local data")

    def test_missing_local_data_keeps_source_only_build_without_stale_campaign(self):
        app = self.root / "Debug.app"
        app.mkdir()
        bundled = app / "BetaGameData"
        content.copy_into_app("", bundled, str(self.source))
        content.copy_into_app("", bundled, str(self.root / "missing"))
        self.assertFalse(bundled.exists())

    def test_invalid_local_data_fails_build(self):
        app = self.root / "Debug.app"
        app.mkdir()
        (self.source / "main.dat").unlink()
        with self.assertRaises(ValueError):
            content.copy_into_app("", app / "BetaGameData", str(self.source))

    def test_frozen_candidate_overrides_local_debug_data(self):
        content.stage(self.source, self.destination)
        (self.source / "main.dat").write_bytes(b"different local data")
        app = self.root / "Debug.app"
        app.mkdir()
        bundled = app / "BetaGameData"
        content.copy_into_app(str(self.destination), bundled, str(self.source))
        self.assertEqual((bundled / "MAIN.DAT").read_bytes(), b"MAIN.DAT")
