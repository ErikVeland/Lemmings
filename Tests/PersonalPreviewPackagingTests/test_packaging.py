import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'Tools/AlternativeAssets'))
import personal_preview as preview


class PersonalPreviewSafetyTests(unittest.TestCase):
    def test_only_personal_output_is_allowed(self):
        self.assertEqual(preview.validate_output(preview.OUTPUT), preview.OUTPUT)
        with self.assertRaises(ValueError):
            preview.validate_output(ROOT / '.build/ultimate-lemmix-app-store-universal')
        with self.assertRaises(ValueError):
            preview.validate_output(ROOT / '.build/ultimate-lemmix-personal-preview')
        self.assertEqual(preview.validate_output(ROOT / '.build/ultimate-lemmix-personal-preview-build3'),
                         ROOT / '.build/ultimate-lemmix-personal-preview-build3')

    def test_unsafe_resource_and_source_paths_are_rejected(self):
        for name in ('../MAIN.DAT', '/MAIN.DAT', './MAIN.DAT', 'a//b', 'a\\b', 'a\nb'):
            with self.subTest(name=name), self.assertRaises(ValueError):
                preview.safe_resource(name)
        with self.assertRaises(ValueError):
            preview.read_regular(ROOT / '../outside-source')

    def test_original_campaign_data_cannot_enter_artwork_lock(self):
        lock = {'personalPreviewOnly': True, 'redistributionCleared': False,
                'officialCampaignsIncluded': False, 'files': [{
                    'source': 'Sources/Ports/level000.dat',
                    'path': 'Ports/lemmings_dos_1991-07-30/LEVEL000.DAT',
                    'bytes': 4, 'sha256': preview.sha(b'data')}]}
        with patch.object(preview, 'read_regular', return_value=preview.encoded(lock)):
            with self.assertRaises(ValueError):
                preview.artwork_files()

    def test_extra_files_and_forged_inventory_are_rejected(self):
        with tempfile.TemporaryDirectory(dir=ROOT / '.build', prefix='personal-package-test-') as temporary:
            directory = Path(temporary)
            files = {'Fonts/font.rgba': b'approved'}
            (directory / 'Fonts').mkdir()
            target = directory / 'Fonts/font.rgba'
            target.write_bytes(files['Fonts/font.rgba'])
            inventory = directory / preview.RESOURCE_MANIFEST
            inventory.write_bytes(preview.encoded(preview.manifest(files)))
            preview.verify_resources(directory, files)
            extra = directory / 'LEVEL000.DAT'
            extra.write_bytes(b'not approved')
            with self.assertRaises(ValueError):
                preview.verify_resources(directory, files)
            extra.unlink()
            target.write_bytes(b'changed')
            inventory.write_bytes(preview.encoded(preview.manifest({'Fonts/font.rgba': b'changed'})))
            with self.assertRaises(ValueError):
                preview.verify_resources(directory, files)

    def test_unrelated_resources_are_never_replaced(self):
        with tempfile.TemporaryDirectory(dir=ROOT / '.build', prefix='personal-output-test-') as temporary:
            output = Path(temporary)
            resources = output / 'Ultimate Lemmix.app/Contents/Resources'
            resources.mkdir(parents=True)
            sentinel = resources / 'keep.txt'
            sentinel.write_text('keep')
            with patch.object(preview, 'OUTPUT', output):
                with self.assertRaises(ValueError):
                    preview.prepare_resources(output, {'owned.txt': b'new'})
            self.assertEqual(sentinel.read_text(), 'keep')

    def test_unrelated_file_with_existing_inventory_is_not_deleted(self):
        with tempfile.TemporaryDirectory(dir=ROOT / '.build', prefix='personal-output-test-') as temporary:
            output = Path(temporary)
            with patch.object(preview, 'OUTPUT', output):
                preview.prepare_resources(output, {'owned.txt': b'old'})
                resources = output / 'Ultimate Lemmix.app/Contents/Resources'
                sentinel = resources / 'keep.txt'
                sentinel.write_text('keep')
                with self.assertRaises(ValueError):
                    preview.prepare_resources(output, {'owned.txt': b'new'})
                self.assertEqual(sentinel.read_text(), 'keep')
                self.assertEqual((resources / 'owned.txt').read_bytes(), b'old')

    def test_universal_binary_headers_are_not_dependencies(self):
        output = ('/Users/test/Ultimate Lemmix (architecture arm64):\n'
                  '\t@rpath/libNxlvKit.dylib (compatibility version 0.0.0, current version 0.0.0)\n'
                  '/Users/test/Ultimate Lemmix (architecture x86_64):\n'
                  '\t/usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 1.0.0)\n')
        self.assertEqual(preview.dependency_paths(output),
                         ['@rpath/libNxlvKit.dylib', '/usr/lib/libSystem.B.dylib'])
        with self.assertRaises(ValueError):
            preview.dependency_paths(output + '\t/Users/test/local.dylib (compatibility version 1.0.0)\n')

    def test_compiler_output_changes_are_rejected(self):
        with tempfile.TemporaryDirectory(dir=ROOT / '.build', prefix='personal-code-test-') as temporary:
            path = Path(temporary) / 'NxlvKit.swiftmodule'
            path.write_bytes(b'compiled module')
            rows = [preview.artifact(path, 'arm64')]
            preview.verify_artifacts(rows)
            path.write_bytes(b'changed module')
            with self.assertRaises(ValueError):
                preview.verify_artifacts(rows)

    def test_personal_version_and_archive_follow_reviewed_metadata(self):
        with patch.object(preview, 'community_count', return_value=5051):
            info = preview.app_info({})
        self.assertEqual(info['CFBundleVersion'], '4')
        self.assertTrue(info['UltimateLemmixPersonalPreview'])
        self.assertEqual(preview.archive_name(info), 'Ultimate-Lemmix-0.1-build4-personal-macOS.zip')
        with self.assertRaises(ValueError):
            preview.archive_name(dict(info, CFBundleVersion='../build2'))


if __name__ == '__main__':
    unittest.main()
