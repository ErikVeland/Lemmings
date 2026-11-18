"""Check publication metadata and edition routing without building an app."""

import json
from pathlib import Path
import plistlib
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
            "schemaVersion": 1,
            "version": "2.4.2",
            "editions": {
                "ultimate-lemmings": {
                    "name": "Ultimate Lemmings", "storeArtwork": False,
                    "platforms": {
                        "macos": {"build": 106, "bundleIdentifier": "example.original",
                                  "infoPlist": "Original.plist", "buildScript": "Scripts/original.sh"},
                        "ios": {"build": 45, "bundleIdentifier": "example.original.ios",
                                "project": "Apps/Original.xcodeproj", "scheme": "Original", "appTarget": "Original"},
                    },
                },
                "ultimate-lemmix": {
                    "name": "Ultimate Lemmix", "storeArtwork": True,
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

    def test_one_version_updates_both_mac_editions_without_merging_build_counters(self):
        publication.sync_metadata(self.root, self.manifest, platforms={"macos"})
        original = plistlib.loads((self.root / "Original.plist").read_bytes())
        licensed = plistlib.loads((self.root / "Licensed.plist").read_bytes())
        self.assertEqual(original["CFBundleShortVersionString"], "2.4.2")
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
        self.assertEqual(original_env["LEMMINGS_PUBLICATION_VERSION"], licensed_env["LEMMINGS_PUBLICATION_VERSION"])

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
        self.assertEqual(project.read_text(), original.replace("CURRENT_PROJECT_VERSION = 1;", "CURRENT_PROJECT_VERSION = 45;").replace("MARKETING_VERSION = 1.8.4;", "MARKETING_VERSION = 2.4.2;"))

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
