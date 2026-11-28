"""Check current Store feature data and the boundary around original assets."""
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
        self.assertFalse(any(name.startswith(('MacArtwork/', 'Sounds/')) for name in files))
        self.assertTrue(all(not name.startswith('Ports/') or name.startswith('Ports/ultimate_lemmix_starter/')
                            for name in files))

    def test_store_icon_excludes_the_uncleared_personal_icon(self):
        files = store_resources.collect()
        self.assertNotEqual(hashlib.sha256(files['AppIcon.png']).hexdigest(),
                         hashlib.sha256((ROOT / 'Resources/AppIcon/AppIcon.png').read_bytes()).hexdigest())
        self.assertNotIn('Provenance/project-icon-source.json', files)
        self.assertFalse(any(name.startswith('Fonts/OriginalLemmings/') for name in files))

    def test_embedded_game_payloads_are_rejected(self):
        for value in ({'levelData': 'payload'}, {'nested': {'terrain': []}},
                      {'input': list(range(128))}, {'payload': 'A' * 512}):
            with self.subTest(valueType=type(value).__name__), self.assertRaises(ValueError):
                feature_resources.inspect_metadata(value)

    def test_packaging_preserves_reviewed_certificate_and_hint_bytes(self):
        files = store_resources.collect()
        self.assertEqual(files['Trolley/verified-maxima.json'],
                         (ROOT / 'Resources/Trolley/verified-maxima.json').read_bytes())
        self.assertEqual(files['Hints/classic.json'], (ROOT / 'Resources/Hints/classic.json').read_bytes())
        self.assertEqual(files['Trolley/engine-fingerprint.txt'],
                            (ROOT / 'Resources/Trolley/engine-fingerprint.txt').read_bytes())


if __name__ == '__main__':
    unittest.main()
