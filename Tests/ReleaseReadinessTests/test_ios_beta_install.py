import importlib.util
import hashlib
import json
from datetime import datetime
from pathlib import Path
import plistlib
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile

TOOLS = Path(__file__).resolve().parents[2] / "Tools/IOSBeta"
sys.path.insert(0, str(TOOLS))
SPEC = importlib.util.spec_from_file_location("ios_beta_install", TOOLS / "install.py")
INSTALL = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(INSTALL)


class IOSBetaInstallTests(unittest.TestCase):
    def candidate(self, root):
        app = root / "Install/Payload/Beta.app"
        (app / "BetaGameData").mkdir(parents=True)
        (app / "BetaGameData/manifest.json").write_bytes(b"content")
        (app / "Beta").write_bytes(b"executable")
        (app / "embedded.mobileprovision").write_bytes(b"profile")
        (app / "Info.plist").write_bytes(plistlib.dumps({
            "CFBundleIdentifier": "test.beta", "CFBundleShortVersionString": "2.0",
            "CFBundleVersion": "3", "CFBundleExecutable": "Beta"}))
        ipa = root / "beta.ipa"
        with zipfile.ZipFile(ipa, "w") as package:
            package.writestr("Payload/Beta.app/Beta", b"executable")
        record = {"exported": True, "exportMethod": "debugging", "installApp": str(app),
                  "status": "signed archive and IPA exported", "signed": True,
                  "archiveSigned": True, "exportSignatureVerified": True,
                  "ipa": str(ipa), "ipaSHA256": INSTALL.digest(ipa),
                  "bundleID": "test.beta", "version": "2.0", "build": 3, "team": "54WU29TRTY",
                  "symbolUUIDs": [["UUID", "arm64"]],
                  "executableSHA256": hashlib.sha256(b"executable").hexdigest(),
                  "contentManifestSHA256": hashlib.sha256(b"content").hexdigest()}
        (root / "evidence.json").write_text(json.dumps(record))
        profile = {"ExpirationDate": datetime(2030, 1, 1), "ProvisionedDevices": ["ipad"],
                   "TeamIdentifier": ["54WU29TRTY"], "Entitlements": {
                       "com.apple.developer.team-identifier": "54WU29TRTY",
                       "application-identifier": "54WU29TRTY.test.beta"}}
        return app, profile, record

    def inspect(self, root, profile, device="ipad"):
        with patch.object(INSTALL, "uuids", return_value=[("UUID", "arm64")]), \
                patch.object(INSTALL, "verify"), patch.object(INSTALL.subprocess, "run"), \
                patch.object(INSTALL.subprocess, "check_output", return_value=plistlib.dumps(profile)):
            return INSTALL.inspect_candidate(root, device, {})

    def test_profile_allows_only_the_requested_device_and_team(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            _, profile, _ = self.candidate(root)
            self.assertEqual(self.inspect(root, profile)[0]["build"], 3)
            with self.assertRaisesRegex(ValueError, "does not include this device"):
                self.inspect(root, profile, "iphone")
            profile["TeamIdentifier"] = ["OTHERTEAM1"]
            with self.assertRaisesRegex(ValueError, "different developer team"):
                self.inspect(root, profile)

    def test_preflight_rejects_modified_executable(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            app, profile, _ = self.candidate(root)
            (app / "Beta").write_bytes(b"changed")
            with self.assertRaisesRegex(ValueError, "executable has changed"):
                self.inspect(root, profile)

    def test_preflight_accepts_export_resigning_with_matching_symbols(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            _, profile, record = self.candidate(root)
            record["executableSHA256"] = hashlib.sha256(b"archive before export resigning").hexdigest()
            (root / "evidence.json").write_text(json.dumps(record))
            self.assertEqual(self.inspect(root, profile)[0]["build"], 3)

    def test_preflight_rejects_distribution_only_export(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            _, profile, record = self.candidate(root)
            record["exportMethod"] = "app-store-connect"
            (root / "evidence.json").write_text(json.dumps(record))
            with self.assertRaisesRegex(ValueError, "development or ad hoc"):
                self.inspect(root, profile)

    def test_preflight_rejects_export_after_source_freeze_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            _, profile, record = self.candidate(root)
            record.update(status="blocked", error="Mobile source changed during the build.")
            (root / "evidence.json").write_text(json.dumps(record))
            with self.assertRaisesRegex(ValueError, "did not finish verification"):
                self.inspect(root, profile)

    def test_install_verification_rejects_a_previous_build(self):
        apps = {"result": {"apps": [{"bundleIdentifier": "test.beta", "version": "2.0", "bundleVersion": "2"}]}}
        with self.assertRaisesRegex(ValueError, "different installed"):
            INSTALL.verify_installed_apps(apps, "test.beta", "2.0", 3)
        apps["result"]["apps"][0]["bundleVersion"] = "3"
        self.assertEqual(INSTALL.verify_installed_apps(apps, "test.beta", "2.0", 3)["build"], "3")

    def test_install_verification_rejects_missing_or_duplicate_apps(self):
        for apps in ([], [{"bundleIdentifier": "other"}], [{"bundleIdentifier": "test.beta"}] * 2):
            with self.assertRaisesRegex(ValueError, "not found"):
                INSTALL.verify_installed_apps({"result": {"apps": apps}}, "test.beta", "2.0", 3)
