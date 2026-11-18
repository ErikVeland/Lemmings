import hashlib
import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

TOOLS = Path(__file__).resolve().parents[2] / 'Tools/AlternativeAssets'
sys.path.insert(0, str(TOOLS))
sys.path.insert(0, str(TOOLS.parent / 'Build'))
import refresh_mobile


class RefreshGuards(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.application = self.root / 'Apps/UltimateLemmixIOS'
        self.payloads = {
            'Package.swift': b'package', 'Package.resolved': b'resolved',
            'Sources/NxlvKit/Core.swift': b'core',
            'Apps/UltimateLemmixIOS/main.swift': b'application',
        }
        self.rows = []
        for name, payload in self.payloads.items():
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(payload)
            self.rows.append(dict(path=name, bytes=len(payload), sha256=hashlib.sha256(payload).hexdigest()))
        for name in ('LemmingsMobileCore', 'LemmingsMobileUI'):
            (self.root / 'Sources' / name).mkdir(parents=True)
        self.evidence = {'sourceFiles': self.rows}
        self.patch = patch.object(refresh_mobile, 'ROOT', self.root)
        self.patch.start()

    def tearDown(self):
        self.patch.stop()
        self.temporary.cleanup()

    def test_unchanged_compiled_inputs_accept_reuse(self):
        result = refresh_mobile.verify_compiled_sources(self.evidence, self.application)
        self.assertEqual(len(result), 4)

    def test_changed_swift_rejects_reuse(self):
        (self.root / 'Sources/NxlvKit/Core.swift').write_bytes(b'changed physics')
        with self.assertRaises(ValueError):
            refresh_mobile.verify_compiled_sources(self.evidence, self.application)

    def test_new_swift_rejects_reuse(self):
        (self.root / 'Sources/NxlvKit/New.swift').write_bytes(b'new')
        with self.assertRaises(ValueError):
            refresh_mobile.verify_compiled_sources(self.evidence, self.application)

    def test_changed_dependency_pin_rejects_reuse(self):
        (self.root / 'Package.resolved').write_bytes(b'another revision')
        with self.assertRaises(ValueError):
            refresh_mobile.verify_compiled_sources(self.evidence, self.application)

    def test_changed_binary_rejects_reuse(self):
        binary = self.root / 'executable'
        binary.write_bytes(b'changed')
        with self.assertRaises(ValueError):
            refresh_mobile.verify_binary(binary, hashlib.sha256(b'original').hexdigest())

    def test_build_number_is_the_only_project_change_allowed(self):
        source = b'CURRENT_PROJECT_VERSION = 4;\nSWIFT_VERSION = 6.0;'
        previous = b'CURRENT_PROJECT_VERSION = 3;\nSWIFT_VERSION = 6.0;'
        self.assertEqual(refresh_mobile.normalise_project(source, '4', '3'), previous)
        changed = source.replace(b'6.0', b'7.0')
        self.assertNotEqual(refresh_mobile.normalise_project(changed, '4', '3'), previous)

    def test_resource_normalisation_keeps_source_phase_changes_visible(self):
        source = b'D = {isa = PBXSourcesBuildPhase; files = (B00000000000000000000038,); };\n'
        self.assertEqual(refresh_mobile.normalise_project(source, '4', '3'), source)

    def test_bundle_variables_expand_without_old_icon_metadata(self):
        old = {'CFBundleExecutable': 'Game', 'CFBundleIdentifier': 'example.game',
               'CFBundleName': 'Game', 'CFBundleVersion': '3',
               'DTSDKName': 'iphoneos27.2', 'CFBundleIcons': {'old': True}}
        source = {'CFBundleExecutable': '$(EXECUTABLE_NAME)', 'CFBundleVersion': '4'}
        value = refresh_mobile.updated_info(old, source, {'CFBundleIcons': {'new': True}})
        self.assertEqual(value['CFBundleExecutable'], 'Game')
        self.assertEqual(value['CFBundleVersion'], '4')
        self.assertEqual(value['CFBundleIcons'], {'new': True})
        self.assertEqual(value['DTSDKName'], 'iphoneos27.2')

    def test_unresolved_bundle_variable_is_rejected(self):
        with self.assertRaises(ValueError):
            refresh_mobile.updated_info({}, {'CFBundleName': '$(UNREVIEWED)'}, {})

    def test_finished_audit_rejects_changed_generated_metadata(self):
        app = self.root / 'review/UltimateLemmix.app'
        app.mkdir(parents=True)
        (app / 'Info.plist').write_bytes(b'build5')
        (app / 'Assets.car').write_bytes(b'icons')
        (self.root / 'review.zip').write_bytes(b'archive')
        evidence = {'sourceFiles': [], 'refreshTool': {}, 'products': [{
            'appPath': 'review/UltimateLemmix.app', 'resources': {}, 'binary': {},
            'assetCatalogue': {'assetsSHA256': hashlib.sha256(b'icons').hexdigest()},
            'reviewArchive': {'path': 'review.zip', 'sha256': hashlib.sha256(b'archive').hexdigest()},
            'generatedFiles': [{'path': 'Assets.car', 'bytes': 5,
                                'sha256': hashlib.sha256(b'icons').hexdigest()},
                               {'path': 'Info.plist', 'bytes': 6,
                                'sha256': hashlib.sha256(b'build4').hexdigest()}],
        }]}
        with patch.object(refresh_mobile, 'refresh_inputs', return_value=([], {})), \
             patch.object(refresh_mobile.mobile_resources, 'audit_app', return_value={}), \
             patch.object(refresh_mobile.build_mobile, 'audit_binary', return_value={}):
            with self.assertRaises(ValueError):
                refresh_mobile.verify_finished(self.root, evidence, 'ios', {}, self.application)


if __name__ == '__main__':
    unittest.main()
