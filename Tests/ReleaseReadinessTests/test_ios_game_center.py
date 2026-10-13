import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

TOOLS = Path(__file__).resolve().parents[2] / 'Tools/IOSBeta'
sys.path.insert(0, str(TOOLS))
import game_center
import content


class IOSGameCenterTests(unittest.TestCase):
    def test_prepared_catalogue_matches_frozen_client_and_apple_limits(self):
        record = game_center.manifest()
        self.assertEqual(record['bundleID'], game_center.BUNDLE_ID)
        self.assertEqual(len(record['leaderboards']), 359)
        self.assertEqual(len(record['sets']), 4)
        self.assertTrue(all(len(group['leaderboards']) <= 100 for group in record['sets']))
        self.assertEqual(record['verification']['status'], 'pending')

    def test_activation_rejects_pending_wrong_app_and_changed_rules(self):
        with tempfile.TemporaryDirectory() as directory:
            file = Path(directory) / 'activation.json'
            record = game_center.manifest()
            file.write_text(json.dumps(record))
            with self.assertRaisesRegex(ValueError, 'verified iOS'):
                game_center.validate_activation(file)
            record['verification'] = {'status': 'verified', 'appID': '1234567890', 'verifiedAtUTC': '2026-10-12T00:00:00Z'}
            file.write_text(json.dumps(record))
            self.assertEqual(game_center.validate_activation(file), record)
            with self.assertRaisesRegex(ValueError, 'does not match'):
                game_center.validate_activation(file, bundle_id='academy.glasscode.lemmings')
            record['leaderboards'][0]['maximum'] += 1
            file.write_text(json.dumps(record))
            with self.assertRaisesRegex(ValueError, 'does not match'):
                game_center.validate_activation(file)

    def test_activation_changes_only_the_staged_bundle(self):
        with tempfile.TemporaryDirectory() as directory:
            app = Path(directory) / 'App'
            app.mkdir()
            with patch.dict(content.os.environ, {}, clear=True):
                content.copy_parity_resources(game_center.ROOT / 'Resources', app)
            self.assertFalse(json.loads((app / 'GameCenter/leaderboards.json').read_text())['enabled'])
            record = game_center.manifest()
            record['verification'] = {'status': 'verified', 'appID': '1234567890', 'verifiedAtUTC': '2026-10-12T00:00:00Z'}
            file = Path(directory) / 'activation.json'
            file.write_text(json.dumps(record))
            with patch.dict(content.os.environ, {'IOS_GAME_CENTER_ACTIVATION': str(file)}, clear=True):
                content.copy_parity_resources(game_center.ROOT / 'Resources', app)
            self.assertTrue(json.loads((app / 'GameCenter/leaderboards.json').read_text())['enabled'])
            self.assertFalse(json.loads((game_center.ROOT / 'Resources/GameCenter/leaderboards.json').read_text())['enabled'])
