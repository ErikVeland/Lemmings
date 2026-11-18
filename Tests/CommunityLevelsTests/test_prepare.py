"""Reject changed, ambiguous or unowned personal-preview level inputs."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    'prepare_community_levels', ROOT / 'Tools/AlternativeAssets/prepare_community_levels.py')
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class CommunityLevelsTests(unittest.TestCase):
    @unittest.skipUnless((MODULE.OUTPUT / MODULE.MANIFEST).is_file(), 'Prepare the personal corpus first.')
    def test_prepared_manifest_matches_native_runtime_contract(self):
        manifest = json.loads((MODULE.OUTPUT / MODULE.MANIFEST).read_text())
        included = set()
        for row in manifest['packs']:
            self.assertIsInstance(row['included'], bool)
            self.assertEqual(row['archiveSHA256'], row['sha256'])
            self.assertEqual(len(row['archiveSHA256']), 64)
            if row['included']:
                included.add(row['archive'])
        self.assertEqual(included, {path.name for path in MODULE.OUTPUT.glob('*.zip')})
        counts = json.loads((MODULE.OUTPUT / 'level-counts.json').read_text())
        self.assertEqual(set(counts), included)
        self.assertEqual(sum(counts.values()), manifest['summary']['includedLevels'])
        for row in manifest['entryExclusions']:
            self.assertIn(row['archive'], included)
            self.assertIn('section', row)
            self.assertEqual(len(row['archiveSHA256']), 64)

    def test_rejects_unsafe_member_paths(self):
        for value in ('/file.lvl', '../file.lvl', 'a/../file.lvl', 'a//file.lvl', 'a\\file.lvl', ''):
            with self.subTest(value=value), self.assertRaises(ValueError):
                MODULE.safe_name(value)

    def test_pinned_input_rejects_changed_bytes_and_links(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / 'pack.zip'
            path.write_bytes(b'original')
            row = {'bytes': 8, 'sha256': MODULE.sha(b'original')}
            self.assertEqual(MODULE.checked(path, row), b'original')
            path.write_bytes(b'changed!')
            with self.assertRaises(ValueError):
                MODULE.checked(path, row)
            target = path.with_name('linked.zip')
            target.symlink_to(path)
            with self.assertRaises(ValueError):
                MODULE.checked(target, {'bytes': 8, 'sha256': MODULE.sha(b'changed!')})

    def test_inventory_rejects_unreviewed_archive(self):
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            catalog = MODULE.encoded([{'id': 1, 'slug': 'custom', 'title': 'Custom'}])
            counts = MODULE.encoded({'0001-custom.zip': 1})
            (folder / 'packs.json').write_bytes(catalog)
            (folder / 'level-counts.json').write_bytes(counts)
            (folder / '0001-custom.zip').write_bytes(b'original')
            policy = {
                'catalogue': {'bytes': len(catalog), 'sha256': MODULE.sha(catalog)},
                'levelCounts': {'bytes': len(counts), 'sha256': MODULE.sha(counts)},
                'packs': [{'id': 1, 'archive': '0001-custom.zip', 'bytes': 8, 'sha256': MODULE.sha(b'original')}],
                'canonicalFiles': [], 'readerSources': [],
            }
            with patch.object(MODULE, 'SOURCE', folder):
                MODULE.source_inputs(policy)
                (folder / '0002-unreviewed.zip').write_bytes(b'unknown')
                with self.assertRaises(ValueError):
                    MODULE.source_inputs(policy)

    def test_exact_match_preserves_original_dat_slot(self):
        policy = {'packs': [
            {'archive': 'official.zip', 'include': False, 'sha256': 'OFFICIAL'},
            {'archive': 'mixed.zip', 'include': True, 'sha256': 'MIXED'},
        ]}
        decoded = [
            {'key': 'official.zip::Official.dat', 'records': [
                {'physicalSection': 0, 'sha256': 'same', 'rawSHA256': 'raw', 'title': 'Official'}]},
            {'key': 'mixed.zip::Mixed.dat', 'records': [
                {'physicalSection': 0, 'sha256': 'same', 'rawSHA256': 'raw', 'title': 'Official'},
                {'physicalSection': 1, 'sha256': 'changed', 'rawSHA256': 'changed-raw', 'title': 'Fan remake'}]},
        ]
        exclusions, counts = MODULE.exclusions_for(decoded, policy, {'mixed.zip::Mixed.dat': [7, 9]})
        self.assertEqual(len(exclusions), 1)
        self.assertEqual(exclusions[0]['section'], 7)
        self.assertEqual(exclusions[0]['archiveSHA256'], 'MIXED')
        self.assertEqual(counts['mixed.zip'], 2)

    def test_invalid_original_slot_map_is_rejected(self):
        policy = {'packs': [
            {'archive': 'official.zip', 'include': False, 'sha256': 'O'},
            {'archive': 'mixed.zip', 'include': True, 'sha256': 'M'},
        ]}
        decoded = [
            {'key': 'official.zip::One.dat', 'records': [
                {'physicalSection': 0, 'sha256': 'same', 'title': 'Same'}]},
            {'key': 'mixed.zip::One.dat', 'records': [
                {'physicalSection': 1, 'sha256': 'same', 'title': 'Same'}]},
        ]
        with self.assertRaises(ValueError):
            MODULE.exclusions_for(decoded, policy, {'mixed.zip::One.dat': [7]})

    def test_forged_output_manifest_does_not_clear_changed_zip(self):
        expected = {
            '0001-custom.zip': b'original',
            MODULE.MANIFEST: MODULE.encoded({'scope': 'personal-test-not-cleared'}),
        }
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            for name, data in expected.items():
                (folder / name).write_bytes(data)
            with patch.object(MODULE, 'collect', return_value=expected):
                MODULE.verify(folder)
                (folder / '0001-custom.zip').write_bytes(b'changed!')
                (folder / MODULE.MANIFEST).write_bytes(MODULE.encoded({
                    'scope': 'personal-test-not-cleared',
                    'files': [{'path': '0001-custom.zip', 'bytes': 8, 'sha256': MODULE.sha(b'changed!')}],
                }))
                with self.assertRaises(ValueError):
                    MODULE.verify(folder)

    def test_extra_output_and_link_are_rejected(self):
        expected = {MODULE.MANIFEST: b'{}'}
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            (folder / MODULE.MANIFEST).write_bytes(b'{}')
            with patch.object(MODULE, 'collect', return_value=expected):
                (folder / 'extra.zip').write_bytes(b'unknown')
                with self.assertRaises(ValueError):
                    MODULE.verify(folder)
                (folder / 'extra.zip').unlink()
                (folder / 'alias.zip').symlink_to(folder / MODULE.MANIFEST)
                with self.assertRaises(ValueError):
                    MODULE.verify(folder)

    def test_prepare_rejects_workspace_and_preserves_unowned_files(self):
        with self.assertRaises(ValueError):
            MODULE.prepare(ROOT)
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            folder = root / '.build/test/LevelPacks'
            folder.mkdir(parents=True)
            (folder / 'personal.txt').write_text('keep')
            with patch.object(MODULE, 'ROOT', root), patch.object(MODULE, 'collect', return_value={}):
                with self.assertRaises((ValueError, FileNotFoundError)):
                    MODULE.prepare(folder)
            self.assertEqual((folder / 'personal.txt').read_text(), 'keep')


if __name__ == '__main__':
    unittest.main()
