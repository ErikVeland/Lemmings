import importlib.util
import hashlib
import json
from datetime import datetime
from pathlib import Path
import plistlib
import stat
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile


TOOLS = Path(__file__).resolve().parents[2] / "Tools/IOSBeta"
sys.path.insert(0, str(TOOLS))
SPEC = importlib.util.spec_from_file_location("ios_beta_build", TOOLS / "build.py")
BUILD = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BUILD)


class IOSBetaBuildTests(unittest.TestCase):
    def test_source_freeze_includes_shared_art_code_and_used_artwork(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in ("Package.swift", "Package.resolved", "Scripts/run-swift-tests.sh",
                         "Sources/LemmingsGameArt/GameStoneArt.swift", "Tools/IOSMenuAudit/main.swift"):
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("source")
            art = root / ".build/mac-artwork/export/lemmings"
            art.mkdir(parents=True)
            (art / "charset.png").write_bytes(b"font pixels")
            (art / "not-copied.png").write_bytes(b"terrain pixels")
            (art / "manifest.json").write_text(json.dumps({
                "names": {"font": "Charset1", "unused": "Terrain"},
                "banks": {"font": [{"file": "charset.png"}], "unused": [{"file": "not-copied.png"}]}
            }))
            with patch.object(BUILD, "ROOT", root), patch.dict(BUILD.os.environ, {}, clear=True):
                before = BUILD.source_manifest()
                self.assertIn("Sources/LemmingsGameArt/GameStoneArt.swift", before)
                self.assertIn("Tools/IOSMenuAudit/main.swift", before)
                self.assertIn("MacArtworkInput/lemmings/charset.png", before)
                self.assertIn("MacArtworkInput/lemmings/not-copied.png", before)
                (art / "charset.png").write_bytes(b"changed font pixels")
                self.assertNotEqual(before, BUILD.source_manifest())

    def make_package(self, root, devices):
        package = root / "beta.ipa"
        info = {"CFBundleIdentifier": "test.beta", "CFBundleVersion": "2",
                "UIDeviceFamily": [1, 2], "CFBundleExecutable": "Beta", "MinimumOSVersion": "16.0"}
        profile = {"ExpirationDate": datetime(2030, 1, 1), "ProvisionedDevices": devices}
        with zipfile.ZipFile(package, "w") as bundle:
            executable = zipfile.ZipInfo("Payload/Beta.app/Beta")
            executable.external_attr = (stat.S_IFREG | 0o755) << 16
            bundle.writestr(executable, b"executable")
            bundle.writestr("Payload/Beta.app/Info.plist", plistlib.dumps(info))
            bundle.writestr("Payload/Beta.app/embedded.mobileprovision", b"profile")
            bundle.writestr("Payload/Beta.app/BetaGameData/manifest.json", b"manifest")
        record = {"bundleID": "test.beta", "build": 2, "symbolUUIDs": [["UUID", "arm64"]],
                  "contentManifestSHA256": hashlib.sha256(b"manifest").hexdigest()}
        return package, profile, record

    def validate(self, package, root, profile, record, device):
        with patch.object(BUILD, "run"), patch.object(BUILD, "uuids", return_value=record["symbolUUIDs"]), \
                patch.object(BUILD, "verify"), patch.object(BUILD, "signing_capabilities", return_value=profile):
            return BUILD.validate_export(package, root, record, device, "debugging")

    def test_export_preserves_executable_permissions_and_checks_device(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            package, profile, record = self.make_package(root, ["ipad"])
            result = self.validate(package, root, profile, record, "ipad")
            self.assertTrue(result["requestedDeviceIncluded"])
            self.assertEqual((root / "Install/Payload/Beta.app/Beta").stat().st_mode & 0o777, 0o755)

    def test_export_rejects_profile_without_requested_ipad(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            package, profile, record = self.make_package(root, ["iphone"])
            with self.assertRaisesRegex(ValueError, "does not include"):
                self.validate(package, root, profile, record, "ipad")

    def test_export_rejects_paths_outside_install_directory(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            package = root / "unsafe.ipa"
            with zipfile.ZipFile(package, "w") as bundle:
                bundle.writestr("../outside", b"unsafe")
            with self.assertRaisesRegex(ValueError, "unsafe file path"):
                BUILD.validate_export(package, root, {}, None, "debugging")
            self.assertFalse((root.parent / "outside").exists())
