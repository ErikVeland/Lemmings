"""Check publication metadata and edition routing without building an app."""

import json
from pathlib import Path
import plistlib
import subprocess
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import publication


class PublicationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.manifest = {
            "schemaVersion": 2,
            "editions": {
                "ultimate-lemmings": {
                    "name": "Ultimate Lemmings", "storeArtwork": False,
                    "version": "2.4.3", "releaseBranch": "release/ultimate-lemmings",
                    "platforms": {
                        "macos": {"build": 106, "bundleIdentifier": "example.original",
                                  "infoPlist": "Original.plist", "buildScript": "Scripts/original.sh"},
                        "ios": {"build": 45, "bundleIdentifier": "example.original.ios",
                                "project": "Apps/Original.xcodeproj", "scheme": "Original", "appTarget": "Original"},
                    },
                },
                "ultimate-lemmix": {
                    "name": "Ultimate Lemmix", "storeArtwork": True,
                    "version": "2.4.2", "releaseBranch": "release/ultimate-lemmix",
                    "platforms": {
                        "macos": {"build": 108, "bundleIdentifier": "example.licensed",
                                  "infoPlist": "Licensed.plist", "buildScript": "Scripts/licensed.sh"},
                        "ios": {"build": 108, "bundleIdentifier": "example.licensed.ios",
                                "project": "Apps/Licensed.xcodeproj", "scheme": "Licensed", "appTarget": "Licensed"},
                    },
                },
            },
        }
        for filename, identifier in [("Original.plist", "example.original"), ("Licensed.plist", "example.licensed")]:
            (self.root / filename).write_bytes(plistlib.dumps({
                "CFBundleIdentifier": identifier, "CFBundleShortVersionString": "1.8.4", "CFBundleVersion": "1",
            }))

    def test_products_keep_independent_versions_and_build_counters(self):
        publication.sync_metadata(self.root, self.manifest, platforms={"macos"})
        original = plistlib.loads((self.root / "Original.plist").read_bytes())
        licensed = plistlib.loads((self.root / "Licensed.plist").read_bytes())
        self.assertEqual(original["CFBundleShortVersionString"], "2.4.3")
        self.assertEqual(licensed["CFBundleShortVersionString"], "2.4.2")
        self.assertEqual(original["CFBundleVersion"], "106")
        self.assertEqual(licensed["CFBundleVersion"], "108")
        self.assertEqual(original["CFBundleIdentifier"], "example.original")
        self.assertEqual(licensed["CFBundleIdentifier"], "example.licensed")

    def test_check_rejects_stale_metadata_for_either_edition(self):
        errors = publication.metadata_errors(self.root, self.manifest, platforms={"macos"})
        self.assertTrue(any("Original.plist" in error for error in errors))
        self.assertTrue(any("Licensed.plist" in error for error in errors))
        publication.sync_metadata(self.root, self.manifest, platforms={"macos"})
        self.assertEqual(publication.metadata_errors(self.root, self.manifest, platforms={"macos"}), [])

    def test_sync_one_product_does_not_touch_or_validate_the_other_release(self):
        original = (self.root / "Original.plist").read_bytes()
        self.manifest["editions"]["ultimate-lemmix"]["version"] = "3.1"
        publication.sync_metadata(self.root, self.manifest, platforms={"macos"},
                                  selected_edition="ultimate-lemmix")
        self.assertEqual((self.root / "Original.plist").read_bytes(), original)
        self.assertEqual(publication.metadata_errors(self.root, self.manifest, platforms={"macos"},
                         selected_edition="ultimate-lemmix"), [])
        self.assertTrue(publication.metadata_errors(self.root, self.manifest, platforms={"macos"},
                        selected_edition="ultimate-lemmings"))

    def write_manifests(self):
        directory = self.root / "Resources/Publishing"
        directory.mkdir(parents=True, exist_ok=True)
        index = {"schemaVersion": 2, "editions": {}}
        for key, edition in self.manifest["editions"].items():
            path = directory / (key + ".json")
            path.write_text(json.dumps(edition))
            index["editions"][key] = str(path.relative_to(self.root))
        (self.root / publication.MANIFEST).write_text(json.dumps(index))

    def test_loader_uses_separate_product_manifests(self):
        self.write_manifests()
        loaded = publication.load_manifest(self.root)
        self.assertEqual(loaded["editions"], self.manifest["editions"])
        index = self.root / publication.MANIFEST
        data = json.loads(index.read_text())
        data["version"] = "4.0"
        index.write_text(json.dumps(data))
        with self.assertRaisesRegex(ValueError, "shared release version"):
            publication.load_manifest(self.root)

    def test_loader_rejects_one_release_branch_for_both_products(self):
        self.manifest["editions"]["ultimate-lemmix"]["releaseBranch"] = "release/ultimate-lemmings"
        self.write_manifests()
        with self.assertRaisesRegex(ValueError, "separate release branches"):
            publication.load_manifest(self.root)

    def test_loader_rejects_a_nested_extension_bundle_identifier(self):
        profile = self.manifest["editions"]["ultimate-lemmix"]["platforms"]["ios"]
        profile["extensionBundleIdentifiers"] = {
            "DeskClockWidget": profile["bundleIdentifier"] + ".mobile.DeskClockWidget"
        }
        self.write_manifests()
        with self.assertRaisesRegex(ValueError, "one suffix"):
            publication.load_manifest(self.root)

    def test_release_branch_rejects_the_other_product(self):
        for edition in self.manifest["editions"]:
            own = self.manifest["editions"][edition]["releaseBranch"]
            publication.guard_product_branch(self.root, self.manifest, edition,
                                             require_release=True, branch=own)
            for branch in ["main", "feature/shared-fix", ""]:
                with self.assertRaises(ValueError):
                    publication.guard_product_branch(self.root, self.manifest, edition,
                                                     require_release=True, branch=branch)
            other = next(key for key in self.manifest["editions"] if key != edition)
            with self.assertRaises(ValueError):
                publication.guard_product_branch(self.root, self.manifest, other, branch=own)

    def test_selected_product_metadata_is_pinned_during_build(self):
        self.write_manifests()
        def change_product(*arguments, **options):
            path = self.root / "Resources/Publishing/ultimate-lemmix.json"
            path.write_text(path.read_text().replace('"2.4.2"', '"2.4.4"'))
            return SimpleNamespace(returncode=0)
        result = publication.run_build(self.root, self.manifest, "ultimate-lemmix", "macos", [],
                                       runner=change_product)
        self.assertEqual(result, 1)

    def test_product_marker_rejects_the_other_app_in_a_detached_checkout(self):
        (self.root / "Product.json").write_text('{"product":"ultimate-lemmix"}')
        publication.guard_product_branch(self.root, self.manifest, "ultimate-lemmix", branch="")
        with self.assertRaisesRegex(ValueError, "another product"):
            publication.guard_product_branch(self.root, self.manifest, "ultimate-lemmings", branch="")

    def test_other_product_metadata_does_not_invalidate_a_build(self):
        self.write_manifests()
        def change_other_product(*arguments, **options):
            path = self.root / "Resources/Publishing/ultimate-lemmings.json"
            path.write_text(path.read_text().replace('"2.4.3"', '"2.5"'))
            return SimpleNamespace(returncode=0)
        result = publication.run_build(self.root, self.manifest, "ultimate-lemmix", "macos", [],
                                       runner=change_other_product)
        self.assertEqual(result, 0)

    def test_branch_comparison_allows_product_metadata_but_rejects_shared_drift(self):
        def git(*arguments):
            return subprocess.check_output(["git", "-c", "user.name=Publication test",
                "-c", "user.email=test@example.invalid", *arguments], cwd=self.root, text=True).strip()
        git("init", "-q", "-b", "main")
        source = self.root / "Sources/Game/Feature.swift"
        source.parent.mkdir(parents=True)
        source.write_text("struct Feature {}\n")
        git("add", "Sources")
        git("commit", "-qm", "Add shared source")
        baseline = git("rev-parse", "HEAD")
        (self.root / "Product.json").write_text('{"product":"ultimate-lemmix"}')
        git("add", "Product.json")
        git("commit", "-qm", "Identify the separate product")
        publication.compare_shared_sources(self.root, baseline)
        source.write_text("struct ChangedFeature {}\n")
        git("add", "Sources")
        git("commit", "-qm", "Change shared source")
        with self.assertRaisesRegex(ValueError, "Sources/Game/Feature.swift"):
            publication.compare_shared_sources(self.root, baseline)

    def test_mobile_store_flags_and_version_apply_to_the_whole_build(self):
        command, _ = publication.build_command(self.root, self.manifest, "ultimate-lemmix", "ios", ["-configuration", "Release", "build"])
        self.assertIn("-xcconfig", command)
        self.assertIn(str(self.root / "Apps/UltimateLemmixSupport/Store.xcconfig"), command)
        self.assertIn("MARKETING_VERSION=2.4.2", command)
        self.assertIn("CURRENT_PROJECT_VERSION=108", command)
        self.assertIn(str(self.root / "Apps/Licensed.xcodeproj"), command)

    def test_original_mobile_does_not_receive_store_artwork_flags(self):
        command, _ = publication.build_command(self.root, self.manifest, "ultimate-lemmings", "ios", ["build"])
        self.assertNotIn("-xcconfig", command)
        self.assertIn("CURRENT_PROJECT_VERSION=45", command)

    def test_mac_editions_keep_their_resource_packagers(self):
        original, original_env = publication.build_command(self.root, self.manifest, "ultimate-lemmings", "macos", [])
        licensed, licensed_env = publication.build_command(self.root, self.manifest, "ultimate-lemmix", "macos", ["--reuse-core"])
        self.assertEqual(original[:2], ["zsh", str(self.root / "Scripts/original.sh")])
        self.assertEqual(licensed[:2], ["zsh", str(self.root / "Scripts/licensed.sh")])
        self.assertEqual(licensed[-1], "--reuse-core")
        self.assertEqual(original_env["LEMMINGS_PUBLICATION_VERSION"], "2.4.3")
        self.assertEqual(licensed_env["LEMMINGS_PUBLICATION_VERSION"], "2.4.2")

    def test_command_cannot_select_a_different_project_or_release_version(self):
        for argument in [["-project", "Other.xcodeproj"], ["-scheme", "Other"], ["MARKETING_VERSION=1.8.4"], ["CURRENT_PROJECT_VERSION=1"]]:
            with self.subTest(argument=argument), self.assertRaises(ValueError):
                publication.build_command(self.root, self.manifest, "ultimate-lemmix", "ios", argument)

    def test_matching_explicit_version_remains_compatible_with_old_wrappers(self):
        command, _ = publication.build_command(self.root, self.manifest, "ultimate-lemmix", "ios", ["CURRENT_PROJECT_VERSION=108", "build"])
        self.assertEqual(command.count("CURRENT_PROJECT_VERSION=108"), 1)

    def test_mobile_profile_owns_identity_plist_and_artwork_conditions(self):
        for argument in ["PRODUCT_BUNDLE_IDENTIFIER=example.original.ios", "INFOPLIST_FILE=Other.plist",
                         "INFOPLIST_KEY_CFBundleIdentifier=example.original.ios", "GENERATE_INFOPLIST_FILE=YES",
                         "OTHER_SWIFT_FLAGS=", "SWIFT_ACTIVE_COMPILATION_CONDITIONS=DEBUG"]:
            with self.subTest(argument=argument), self.assertRaises(ValueError):
                publication.build_command(self.root, self.manifest, "ultimate-lemmix", "ios", [argument])
        command, _ = publication.build_command(self.root, self.manifest, "ultimate-lemmix", "ios",
                                              ["DEVELOPMENT_TEAM=EXAMPLE", "CODE_SIGNING_ALLOWED=NO", "build"])
        self.assertIn("DEVELOPMENT_TEAM=EXAMPLE", command)
        self.assertIn("CODE_SIGNING_ALLOWED=NO", command)

    def test_profile_selects_artwork_independently_of_the_parent_environment(self):
        with patch.dict("os.environ", {"ULTIMATE_LEMMIX_STORE": "1"}):
            _, original = publication.build_command(self.root, self.manifest, "ultimate-lemmings", "macos", [])
            _, licensed = publication.build_command(self.root, self.manifest, "ultimate-lemmix", "macos", [])
        self.assertEqual(original["ULTIMATE_LEMMIX_STORE"], "0")
        self.assertEqual(licensed["ULTIMATE_LEMMIX_STORE"], "1")

    def test_sync_updates_only_release_scalars_in_mobile_project_text(self):
        project = self.root / "Apps/Original.xcodeproj/project.pbxproj"
        project.parent.mkdir(parents=True)
        original = "// retained header\nCURRENT_PROJECT_VERSION = 1;\nMARKETING_VERSION = 1.8.4;\nPRODUCT_BUNDLE_IDENTIFIER = example.original.ios;\n"
        project.write_text(original)
        manifest = json.loads(json.dumps(self.manifest))
        del manifest["editions"]["ultimate-lemmix"]["platforms"]["ios"]
        publication.sync_metadata(self.root, manifest, platforms={"ios"})
        self.assertEqual(project.read_text(), original.replace("CURRENT_PROJECT_VERSION = 1;", "CURRENT_PROJECT_VERSION = 45;").replace("MARKETING_VERSION = 1.8.4;", "MARKETING_VERSION = 2.4.3;"))

    def test_shared_snapshot_tracks_new_game_and_launcher_source(self):
        source = self.root / "Sources/Game/Feature.swift"
        source.parent.mkdir(parents=True)
        source.write_text("struct Feature {}\n")
        before = publication.source_snapshot(self.root)
        launcher = self.root / "Apps/SharedAppleMobile/AppDelegate.swift"
        launcher.parent.mkdir(parents=True)
        launcher.write_text("struct SharedLauncher {}\n")
        after = publication.source_snapshot(self.root)
        self.assertNotEqual(before["sourceFingerprint"], after["sourceFingerprint"])
        self.assertEqual([item["path"] for item in after["sources"]],
                         ["Apps/SharedAppleMobile/AppDelegate.swift", "Sources/Game/Feature.swift"])

    def test_publication_identity_does_not_fork_the_shared_source_fingerprint(self):
        source = self.root / "Sources/Game/Feature.swift"
        source.parent.mkdir(parents=True)
        source.write_text("struct Feature {}\n")
        before = publication.source_snapshot(self.root)
        (self.root / "Licensed.plist").write_bytes(plistlib.dumps({"CFBundleIdentifier": "different.edition"}))
        self.assertEqual(before, publication.source_snapshot(self.root))

    def test_build_record_rejects_source_changes_during_compilation(self):
        source = self.root / "Sources/Game/Feature.swift"
        source.parent.mkdir(parents=True)
        source.write_text("struct Feature {}\n")

        def compile_changed_source(*arguments, **options):
            source.write_text("struct ChangedFeature {}\n")
            return SimpleNamespace(returncode=0)

        result = publication.run_build(self.root, self.manifest, "ultimate-lemmix", "macos", [],
                                       runner=compile_changed_source)
        self.assertEqual(result, 1)
        record = json.loads((self.root / ".build/publications/ultimate-lemmix/macos/last-build.json").read_text())
        self.assertFalse(record["sharedSourcesUnchanged"])

    def test_both_build_records_identify_the_same_shared_source(self):
        source = self.root / "Sources/Game/Feature.swift"
        source.parent.mkdir(parents=True)
        source.write_text("struct Feature {}\n")
        fingerprints = []
        for edition in ["ultimate-lemmings", "ultimate-lemmix"]:
            result = publication.run_build(self.root, self.manifest, edition, "macos", [],
                                           runner=lambda *arguments, **options: SimpleNamespace(returncode=0))
            self.assertEqual(result, 0)
            record = json.loads((self.root / f".build/publications/{edition}/macos/last-build.json").read_text())
            fingerprints.append(record["sourceBefore"]["sourceFingerprint"])
        self.assertEqual(fingerprints[0], fingerprints[1])


if __name__ == "__main__":
    unittest.main()
