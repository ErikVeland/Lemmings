"""Check shared publication sources and reject drift in isolated projects."""

import json
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "Tools/Publication"))
from check_sources import check_sources


class SharedMobileSourcesTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="lemmings-publication-sources-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.manifest = json.loads((ROOT / "Resources/Publishing/editions.json").read_text())
        self.projects = {}
        for edition, details in self.manifest["editions"].items():
            details["platforms"].pop("macos", None)
            for platform, settings in details["platforms"].items():
                relative = settings["project"] + "/project.pbxproj"
                data = json.loads(subprocess.check_output(
                    ["plutil", "-convert", "json", "-o", "-", str(ROOT / relative)]))
                self.projects[edition, platform] = (relative, data)
        for value in self.manifest["shared"].values():
            for relative in value if isinstance(value, list) else [value]:
                path = self.root / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.touch()
        self.write_projects()

    def write_projects(self):
        for relative, data in self.projects.values():
            path = self.root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(plistlib.dumps(data))

    def objects(self, edition="ultimate-lemmix", platform="ios"):
        return self.projects[edition, platform][1]["objects"]

    def test_publication_targets_share_mobile_sources(self):
        self.assertEqual(check_sources(ROOT, json.loads(
            (ROOT / "Resources/Publishing/editions.json").read_text())), [])

    def test_isolated_projects_pass(self):
        self.assertEqual(check_sources(self.root, self.manifest), [])

    def test_copied_launcher_fails_even_when_its_contents_match(self):
        self.objects()["100000000000000000000011"]["path"] = "AppDelegate.swift"
        copied = self.root / "Apps/UltimateLemmixIOS/AppDelegate.swift"
        copied.write_text((ROOT / "Apps/SharedAppleMobile/AppDelegate.swift").read_text())
        self.write_projects()
        self.assertTrue(any("source files" in error for error in check_sources(self.root, self.manifest)))

    def test_missing_store_guard_fails(self):
        phase = self.objects()["100000000000000000000040"]
        phase["files"].remove("A77100000000000000000013")
        self.write_projects()
        self.assertTrue(any("StoreBuildGuard.swift" in error for error in check_sources(self.root, self.manifest)))

    def test_wrong_package_root_fails(self):
        self.objects()["100000000000000000000080"]["relativePath"] = "../wrong-package"
        self.write_projects()
        self.assertTrue(any("package" in error for error in check_sources(self.root, self.manifest)))

    def testEngineEditionConditional(self):
        engine = self.root / "Sources/NxlvKit/Nested/Simulation.swift"
        engine.parent.mkdir(parents=True)
        for token in ("#if ULTIMATE_LEMMIX_STORE", "AppDistribution.isStore",
                      "MobileResourceAccess.isStore"):
            with self.subTest(token=token):
                engine.write_text(token)
                self.assertTrue(any("engine" in error for error in check_sources(self.root, self.manifest)))
        engine.write_text("struct NeoLemmixSimulation {}")
        self.assertEqual(check_sources(self.root, self.manifest), [])

    def test_original_artwork_phase_in_store_project_fails(self):
        phase = next(item for item in self.objects().values()
                     if item.get("isa") == "PBXShellScriptBuildPhase")
        phase["shellScript"] = 'python3 "$SRCROOT/../../Tools/IOSBeta/artwork.py" --destination "$TARGET_BUILD_DIR"'
        self.write_projects()
        self.assertTrue(any("original assets" in error for error in check_sources(self.root, self.manifest)))

    def test_group_relative_source_paths_resolve_to_the_shared_file(self):
        objects = self.objects()
        objects["100000000000000000000011"].update(
            path="AppDelegate.swift", sourceTree="<group>")
        objects["100000000000000000000031"]["path"] = "../SharedAppleMobile"
        self.write_projects()
        self.assertEqual(check_sources(self.root, self.manifest), [])

    def test_group_relative_copied_launcher_fails(self):
        objects = self.objects()
        objects["100000000000000000000011"].update(
            path="AppDelegate.swift", sourceTree="<group>")
        copied = self.root / "Apps/UltimateLemmixIOS/AppDelegate.swift"
        copied.touch()
        self.write_projects()
        self.assertTrue(any("source files" in error for error in check_sources(self.root, self.manifest)))


if __name__ == "__main__":
    unittest.main()
