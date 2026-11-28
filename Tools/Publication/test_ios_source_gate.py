import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

import ios_source_gate as gate


class IOSSourceGateTests(unittest.TestCase):
    def test_every_stage_uses_the_edition_project_and_targets(self):
        manifest = gate.load_manifest(gate.ROOT)
        for edition, entry in manifest["editions"].items():
            profile = entry["platforms"]["ios"]
            for stage in ("debug", "release", "device", "ui"):
                with self.subTest(edition=edition, stage=stage):
                    command = gate.build_command(edition, profile, stage, Path("/fixture"), "chosen-device", "run.xcresult")
                    self.assertEqual(command[command.index("-project") + 1], profile["project"])
                    self.assertTrue((gate.ROOT / profile["project"] / "project.pbxproj").is_file())
                    self.assertIn("CODE_SIGNING_ALLOWED=NO", command)
                    self.assertEqual("-xcconfig" in command, edition == "ultimate-lemmix")
                    target = profile["appTarget"]
                    if stage == "ui":
                        self.assertEqual(command[command.index("-scheme") + 1], profile["scheme"])
                        self.assertIn("-only-testing:" + target + "UITests/MobileCoreIOSSmokeTests", command)
                    else:
                        self.assertEqual(command[command.index("-target") + 1], target + ("UITests" if stage == "debug" else ""))

    def test_source_fixture_is_verified_and_restricted_to_unsigned_ios_checks(self):
        copier = gate.ROOT / "Apps/UltimateLemmixSupport/copy_resources.py"
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            fixture = root / "input"
            fixture.mkdir()
            gate.prepare_fixture(fixture)
            manifest = json.loads((fixture / "ultimate-lemmix-mobile-resources.json").read_text())
            self.assertTrue(all(row["path"].startswith(("Ports/ultimate_lemmix_starter/", "Localization.bundle/", "About/")) for row in manifest["files"]))
            about_files = {"About/Heritage.md", "About/Contributors.md", "About/VersionHistory.md"}
            self.assertEqual({row["path"] for row in manifest["files"] if row["path"].startswith("About/")}, about_files)
            self.assertEqual((fixture / "About/Heritage.md").read_bytes(), (gate.ROOT / "Resources/About/Heritage.md").read_bytes())
            self.assertEqual((fixture / "About/Contributors.md").read_bytes(), (gate.ROOT / "Tools/Telemetry/contributors.md").read_bytes())
            publication = json.loads((gate.ROOT / "Resources/Publishing/ultimate-lemmix.json").read_text())
            history = (fixture / "About/VersionHistory.md").read_text()
            self.assertTrue(history.startswith("# Ultimate Lemmix " + publication["version"]))
            self.assertNotIn("\nPlatform builds:", history)
            allowed = {**os.environ, "IOS_SOURCE_GATE_ONLY": "1", "CODE_SIGNING_ALLOWED": "NO", "ULTIMATE_LEMMIX_RELEASE_CHECKS": "0"}
            def copy(bundle, scope, **env):
                return subprocess.run([sys.executable, str(copier), "--source", str(fixture), "--destination", str(root / bundle),
                                       "--scope", scope], capture_output=True, env={**allowed, **env})
            for env in ({"CODE_SIGNING_ALLOWED": "YES"}, {"IOS_SOURCE_GATE_ONLY": "0"}, {"ULTIMATE_LEMMIX_RELEASE_CHECKS": "1"}):
                self.assertNotEqual(copy("UltimateLemmixIOS.app", "app", **env).returncode, 0)
            self.assertNotEqual(copy("UltimateLemmixTVOS.app", "app").returncode, 0)
            for bundle, scope in (("UltimateLemmixIOS.app", "app"), ("DeskClockWidget.appex", "widget")):
                result = copy(bundle, scope)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertTrue((root / bundle / "ultimate-lemmix-resource-receipt.json").exists())
            level = "Ports/ultimate_lemmix_starter/LEVEL000.DAT"
            self.assertEqual((fixture / level).read_bytes(), (root / "UltimateLemmixIOS.app" / level).read_bytes())
            for name in about_files:
                self.assertEqual((fixture / name).read_bytes(), (root / "UltimateLemmixIOS.app" / name).read_bytes())
            self.assertFalse((root / "DeskClockWidget.appex/About").exists())
            contributors = fixture / "About/Contributors.md"
            original = contributors.read_bytes()
            contributors.write_bytes(b"changed")
            self.assertNotEqual(copy("UltimateLemmixIOS.app", "app").returncode, 0)
            contributors.write_bytes(original)
            (fixture / level).write_bytes(b"changed")
            self.assertNotEqual(copy("UltimateLemmixIOS.app", "app").returncode, 0)
