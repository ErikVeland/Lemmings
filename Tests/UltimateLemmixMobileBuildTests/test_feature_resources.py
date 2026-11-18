"""Check the restored authored feature data and requested icon boundaries."""
from pathlib import Path
import hashlib
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'Tools/AlternativeAssets'))
import store_resources
import feature_resources


class RestoredFeatureResourceTests(unittest.TestCase):
    def test_common_features_have_their_data_without_game_payloads(self):
        files = store_resources.collect()
        for name in ('Progression/learning.json', 'Progression/exclusions.json', 'Progression/solutions.json',
                     'Hints/classic.json', 'Hints/solutions.json', 'Trolley/engine-fingerprint.txt',
                     'Trolley/verified-maxima.json', 'GameCenter/leaderboards.json'):
            self.assertIn(name, files)
        self.assertFalse(any(name.startswith(('Ports/', 'MacArtwork/', 'Sounds/')) for name in files))

    def test_project_icon_is_preserved_with_its_separate_rights_record(self):
        files = store_resources.collect()
        self.assertEqual(hashlib.sha256(files['AppIcon.png']).hexdigest(),
                         hashlib.sha256((ROOT / 'Resources/AppIcon/AppIcon.png').read_bytes()).hexdigest())
        self.assertIn('Provenance/project-icon-source.json', files)

    def test_embedded_game_payloads_are_rejected(self):
        for value in ({'levelData': 'payload'}, {'nested': {'terrain': []}},
                      {'input': list(range(128))}, {'payload': 'A' * 512}):
            with self.subTest(valueType=type(value).__name__), self.assertRaises(ValueError):
                feature_resources.inspect_metadata(value)

    def test_current_recovery_stamp_does_not_relabel_old_certificates(self):
        files = feature_resources.collect()
        self.assertEqual(files['Trolley/verified-maxima.json'],
                         (ROOT / 'Resources/Trolley/verified-maxima.json').read_bytes())
        self.assertEqual(files['Hints/classic.json'], (ROOT / 'Resources/Hints/classic.json').read_bytes())
        self.assertNotEqual(files['Trolley/engine-fingerprint.txt'],
                            (ROOT / 'Resources/Trolley/engine-fingerprint.txt').read_bytes())


if __name__ == '__main__':
    unittest.main()
