"""Check that parity reports reject catalogue, pixel and reopen drift."""
import contextlib
import copy
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('asset_parity_compare', Path(__file__).with_name('compare.py'))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class CompareTests(unittest.TestCase):
    def fixture(self):
        baseline = {'catalogue': [{'id': 'classic', 'levels': [1]}], 'homeActions': ['play'], 'browserCatalogue': ['classic-0'],
                    'captures': {'home': {'pixelHash': 'same', 'controls': ['play']}},
                    'menu': ['pause'], 'originalSkin': True, 'coverage': 'current source only',
                    'contentID': 'owned-content', 'profileSurvivedReopen': True,
                    'neoNative': {'catalogue': ['neo'], 'packID':'neo','levelID':'1','terrainHash':'same','stateMatchesReference':True,'tick':17,'capture':{'pixelHash':'same'},'restoredAcrossProcesses':True},
                    'persistence': {'roster': ['YOU','PAL'], 'nextTurnIndex': 1, 'queueIndex': 1, 'archivedQueue':True, 'checkpointTick':17, 'checkpointStateHash':'same', 'homeActions':['resume'], 'savedHome': {'pixelHash':'same'}, 'restoredAcrossProcesses':True},
                    'mobileHostSessions': {engine: {'catalogue': [1], 'frameHash': 'same',
                        'width': 320, 'height': 200, 'checkpointHash': 'same'} for engine in ('l2', 'l3')}}
        return {phase: copy.deepcopy(baseline) for phase in ('reference', 'import', 'reopen')}

    def run_fixture(self, runs):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            for phase, result in runs.items():
                (root / phase).mkdir()
                (root / phase / 'result.json').write_text(json.dumps(result))
            with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
                return module.compare(root)

    def test_equal_resources_pass(self):
        self.assertTrue(self.run_fixture(self.fixture()))

    def test_catalogue_drift_fails(self):
        runs = self.fixture()
        runs['import']['catalogue'] = []
        self.assertFalse(self.run_fixture(runs))

    def test_browser_identity_drift_fails(self):
        runs = self.fixture()
        runs['import']['browserCatalogue'] = ['imported-path-id']
        self.assertFalse(self.run_fixture(runs))

    def test_neo_state_drift_fails(self):
        runs = self.fixture()
        runs['reopen']['neoNative']['stateMatchesReference'] = False
        self.assertFalse(self.run_fixture(runs))

    def test_saved_queue_drift_fails(self):
        runs = self.fixture()
        runs['reopen']['persistence']['queueIndex'] = 0
        self.assertFalse(self.run_fixture(runs))

    def test_pixel_drift_fails(self):
        runs = self.fixture()
        runs['reopen']['captures']['home']['pixelHash'] = 'different'
        self.assertFalse(self.run_fixture(runs))

    def test_checkpoint_drift_fails(self):
        runs = self.fixture()
        runs['import']['mobileHostSessions']['l3']['checkpointHash'] = 'different'
        self.assertFalse(self.run_fixture(runs))

    def test_activation_drift_fails(self):
        runs = self.fixture()
        runs['reopen']['contentID'] = 'different'
        self.assertFalse(self.run_fixture(runs))

    def test_roster_drift_fails(self):
        runs = self.fixture()
        runs['reopen']['profileSurvivedReopen'] = False
        self.assertFalse(self.run_fixture(runs))


if __name__ == '__main__':
    unittest.main()
