import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
import zipfile


ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('byo_bundle', ROOT / 'Tools/AlternativeAssets/byo_bundle.py')
BUNDLE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BUNDLE)


class BYOIntegrationBundleTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='lemmings-byo-bundle-')
        self.addCleanup(self.temporary.cleanup)
        self.output = Path(self.temporary.name) / 'helper'

    def test_archive_contains_only_the_contract_guide_and_manifest(self):
        record = BUNDLE.build(self.output)
        archive = self.output / BUNDLE.ARCHIVE_NAME
        with zipfile.ZipFile(archive) as contents:
            self.assertEqual(set(contents.namelist()), {'byo-integration.json', 'README.txt', 'manifest.json'})
            self.assertEqual(contents.read('byo-integration.json'), BUNDLE.SOURCE.read_bytes())
        self.assertEqual(len(record['files']), 2)
        self.assertFalse(record['containsCommercialAssets'])
        self.assertFalse(record['containsExecutableCode'])
        self.assertEqual(BUNDLE.build(self.output), record)

    def test_added_archive_member_is_rejected(self):
        BUNDLE.build(self.output)
        with zipfile.ZipFile(self.output / BUNDLE.ARCHIVE_NAME, 'a') as archive:
            archive.writestr('unapproved.dat', b'fixture')
        with self.assertRaisesRegex(ValueError, 'unexpected or missing'):
            BUNDLE.verify(self.output)

    def test_changed_contract_and_checksum_are_rejected(self):
        BUNDLE.build(self.output)
        record_path = self.output / 'manifest.json'
        record = json.loads(record_path.read_text())
        record['archiveSHA256'] = '0' * 64
        record_path.write_text(json.dumps(record))
        with self.assertRaisesRegex(ValueError, 'checksum record'):
            BUNDLE.verify(self.output)
        source = Path(self.temporary.name) / 'invalid.json'
        contract = json.loads(BUNDLE.SOURCE.read_text())
        contract['downloads'] = ['https://example.invalid/game.zip']
        source.write_text(json.dumps(contract))
        with self.assertRaisesRegex(ValueError, 'asset-free'):
            BUNDLE.payloads(source)

    def test_extra_output_file_is_rejected(self):
        BUNDLE.build(self.output)
        (self.output / 'unapproved.dat').write_bytes(b'fixture')
        with self.assertRaisesRegex(ValueError, 'unrecorded files'):
            BUNDLE.verify(self.output)


if __name__ == '__main__':
    unittest.main()
