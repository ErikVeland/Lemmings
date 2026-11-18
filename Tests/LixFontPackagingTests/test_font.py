"""Check separate Lix font rights, exact source bytes and bundle boundaries."""
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'Tools/AlternativeAssets'))
import mobile_resources
import prepare_lix_font as font
import store_resources


class LixFontPackagingTests(unittest.TestCase):
    def test_exact_font_and_complete_official_notice(self):
        files = font.expected_files()
        self.assertEqual(set(files), {'Fonts/Lix/djvusans.ttf', 'Licences/Lix-font-LICENSE.txt',
                                     'Provenance/lix-font-source.json'})
        self.assertEqual(font.sha(files['Fonts/Lix/djvusans.ttf']), font.FONT_SHA256)
        self.assertEqual(font.sha(files['Licences/Lix-font-LICENSE.txt']), font.NOTICE_SHA256)
        self.assertIn(b'Arev Fonts Copyright', files['Licences/Lix-font-LICENSE.txt'])
        self.assertIn(b'Bitstream Vera Fonts Copyright', files['Licences/Lix-font-LICENSE.txt'])
        self.assertFalse(json.loads(files['Provenance/lix-font-source.json'])['licence']['cc0'])

    def test_font_cannot_be_relabelled_as_cc0(self):
        lock = json.loads(font.PIN.read_text())
        lock['licence']['id'] = 'CC0-1.0'
        lock['licence']['cc0'] = True
        read = font.regular
        with patch.object(font, 'regular', side_effect=lambda path:
                          font.encoded(lock) if path == font.PIN else read(path)):
            with self.assertRaises(ValueError):
                font.expected_files()

    def test_truncated_full_notice_is_rejected(self):
        notice = ROOT / 'Resources/AlternativeAssets/lix-font-LICENSE.txt'
        read = font.regular
        with patch.object(font, 'regular', side_effect=lambda path:
                          read(path)[:-20] if path == notice else read(path)):
            with self.assertRaises(ValueError):
                font.expected_files()

    def test_changed_source_font_is_rejected(self):
        with patch.object(font.prepare_lix, 'read_archive',
                          return_value={'data/fonts/djvusans.ttf': b'changed font'}):
            with self.assertRaises(ValueError):
                font.expected_files()

    def test_extra_files_and_forged_prepared_inventory_are_rejected(self):
        files = font.expected_files()
        with tempfile.TemporaryDirectory(dir=ROOT / '.build', prefix='lix-font-test-') as temporary:
            output = Path(temporary)
            for name, data in files.items():
                path = output / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(data)
            (output / 'manifest.json').write_bytes(font.encoded(font.manifest(files)))
            font.verify(output, files)
            extra = output / 'Fonts/Original/uncleared.ttf'
            extra.parent.mkdir()
            extra.write_bytes(b'unapproved')
            with self.assertRaises(ValueError):
                font.verify(output, files)
            extra.unlink()
            changed = dict(files, **{'Fonts/Lix/djvusans.ttf': b'changed font'})
            (output / 'Fonts/Lix/djvusans.ttf').write_bytes(changed['Fonts/Lix/djvusans.ttf'])
            (output / 'manifest.json').write_bytes(font.encoded(font.manifest(changed)))
            with self.assertRaises(ValueError):
                font.verify(output, files)

    def test_all_clean_manifests_keep_font_rights_separate(self):
        files = {'Fonts/Lix/djvusans.ttf': b'font', 'Music/Lix/track.mp3': b'music'}
        for inventory in (store_resources.resource_manifest(files), mobile_resources.inventory(files)):
            self.assertEqual(inventory['mediaLicence'], 'mixed')
            record = next(row for row in inventory['mediaLicences']
                          if row['scope'] == 'Fonts/Lix/djvusans.ttf')
            self.assertEqual(record['licence'], font.LICENCE)
            self.assertFalse(record['modified'])
        pin = json.loads((ROOT / 'Resources/AlternativeAssets/lix-source.json').read_text())
        self.assertEqual(pin['licence']['spdx'], 'CC0-1.0')
        self.assertIn('data/fonts/', pin['excluded'])

    def test_font_source_links_are_rejected(self):
        with tempfile.TemporaryDirectory(dir=ROOT / '.build', prefix='lix-font-link-test-') as temporary:
            path = Path(temporary) / 'font.ttf'
            path.symlink_to(ROOT / 'Resources/AlternativeAssets/lix-font-LICENSE.txt')
            with self.assertRaises(ValueError):
                font.regular(path)

    def test_unrelated_font_output_is_preserved(self):
        with tempfile.TemporaryDirectory(dir=ROOT / '.build', prefix='lix-font-output-test-') as temporary:
            output = Path(temporary)
            sentinel = output / 'keep.txt'
            sentinel.write_text('keep')
            with patch.object(font, 'OUTPUT', output), self.assertRaises(ValueError):
                font.prepare()
            self.assertEqual(sentinel.read_text(), 'keep')


if __name__ == '__main__':
    unittest.main()
