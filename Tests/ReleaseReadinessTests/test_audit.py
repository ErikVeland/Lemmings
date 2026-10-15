"""Reject changed evidence and incomplete release closure."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("audit", Path(__file__).resolve().parents[2] / "Tools/ReleaseReadiness/audit.py")
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)


class AuditTests(unittest.TestCase):
    def test_fan_audit_matches_retained_release_manifest(self):
        repository = Path(__file__).resolve().parents[2]
        readiness = repository / "Documentation/ReleaseReadiness"
        fan_audit = json.loads((readiness / "ClassicFanBundleAudit-2026-10-15.json").read_text())
        release_manifest = json.loads((readiness / "MacOS2Preparation-2026-10-15/bundle-inputs.json").read_text())
        archives = fan_audit["bundle"]["archives"]
        files = release_manifest["files"]

        self.assertEqual(len(archives), 535)
        self.assertEqual(fan_audit["bundle"]["levelCount"], 6020)
        self.assertEqual(release_manifest["baselineVersion"], "1.9.7")
        self.assertEqual(release_manifest["baselineBuild"], 82)
        for archive in archives:
            with self.subTest(archive=archive["archive"]):
                resource = files.get("LevelPacks/" + archive["archive"])
                self.assertIsNotNone(resource)
                self.assertEqual(resource["sha256"], archive["sha256"])

    def test_classic_scope_keeps_shared_and_unknown_gates(self):
        gates = [
            {"area": "Classic", "status": "open", "scopes": ["all", "classic-1.0"]},
            {"area": "Sequel fidelity", "status": "open", "scopes": ["all"]},
            {"area": "New unclassified blocker", "status": "open"},
        ]
        selected = audit.scoped_gates(gates, "classic-1.0")
        self.assertEqual([gate["area"] for gate in selected], ["Classic", "New unclassified blocker"])
        self.assertEqual(audit.scoped_gates(gates, "all"), gates)
        self.assertEqual(audit.exit_status([{"status": "passed"}], [], selected, True), 2)

    def test_classic_campaign_requires_missing_routes(self):
        self.assertIn("--require-all", audit.campaign_command("classic-1.0"))
        self.assertIn("--classic-only", audit.campaign_command("classic-1.0"))
        self.assertIn("--require-all", audit.campaign_command("all"))
        self.assertIn("--require-all", audit.campaign_command("macos-2.0"))
        self.assertNotIn("--require-all", audit.campaign_command("minor"))

    def test_mac_scope_requires_bundle_closure_without_mobile_acceptance(self):
        gates = [
            {"area": "Bundled engine and content closure", "status": "open", "scopes": ["all", "macos-2.0"]},
            {"area": "iOS devices", "status": "open", "scopes": ["all"]},
            {"area": "New unclassified blocker", "status": "open"},
        ]
        selected = audit.scoped_gates(gates, "macos-2.0")
        self.assertEqual([g["area"] for g in selected], ["Bundled engine and content closure", "New unclassified blocker"])
        self.assertEqual(audit.exit_status([{"status": "passed"}], [], selected, True), 2)

    def test_closure_requires_all_checks_and_gates(self):
        passed = [{"status": "passed"}]
        closed = [{"status": "closed"}]
        self.assertEqual(audit.exit_status(passed, [], closed, True), 0)
        for status in ["open", "partial", "external", "not-implemented"]:
            self.assertEqual(audit.exit_status(passed, [], [{"status": status}], True), 2)
        self.assertEqual(audit.exit_status([{"status": "not-run"}], [], closed, True), 2)
        self.assertEqual(audit.exit_status([{"status": "failed"}], [], closed, False), 1)
        self.assertEqual(audit.exit_status(passed, ["asset.dat"], closed, False), 1)
        self.assertEqual(audit.exit_status(passed, [], [{"status": "open"}], False), 0)

    def test_assets_and_replay_evidence_are_hashed(self):
        original = audit.ROOT
        with tempfile.TemporaryDirectory() as temporary:
            audit.ROOT = Path(temporary)
            try:
                names = ["Sources/Ports/game.dat", "Resources/Info.plist",
                         "Documentation/CampaignCompletion/routes.json",
                         "Documentation/Lemmings2Completion/evidence.json",
                         "Documentation/ReleaseReadiness/gates.json",
                         "Documentation/ReleaseScope.md", "Documentation/FanLevelPruning.json",
                         ".build/local/Ultimate Lemmings.app/Contents/Resources/level.dat"]
                for name in names:
                    path = audit.ROOT / name
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.write_bytes(b"original")
                before = audit.manifest(audit.input_paths())
                self.assertTrue(set(names).issubset(before))
                for name in names:
                    (audit.ROOT / name).write_bytes(b"changed")
                after = audit.manifest(audit.input_paths())
                self.assertTrue(all(before[name] != after[name] for name in names))
                (audit.ROOT / names[0]).unlink()
                self.assertNotIn(names[0], audit.manifest(audit.input_paths()))
            finally:
                audit.ROOT = original


if __name__ == "__main__":
    unittest.main()
