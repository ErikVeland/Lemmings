"""Full updates re-encode bundled music. Timing and rhythm must follow the copies."""
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'Tools/MusicCatalogue'))
import library


def sha(data):
    return hashlib.sha256(data).hexdigest()


class MusicPlaybackHashTests(unittest.TestCase):
    def test_playback_hashes_follow_reencoded_files_only(self):
        with tempfile.TemporaryDirectory() as temp:
            music = Path(temp) / 'Music'
            music.mkdir()
            (music / 'kept.mod').write_bytes(b'module')
            (music / 'encoded.m4a').write_bytes(b'aac copy')
            rows = [dict(path='kept.mod', sourceSHA256=sha(b'module')),
                    dict(path='encoded.m4a', sourceSHA256=sha(b'alac source'), playbackSHA256='0' * 64),
                    dict(path='not-bundled.m4a', sourceSHA256=sha(b'optional'))]
            for name in ('timing.json', 'rhythm.json'):
                (music / name).write_text(json.dumps(dict(schemaVersion=1, variants=rows)))
            library.playback(music)
            for name in ('timing.json', 'rhythm.json'):
                kept, encoded, missing = json.loads((music / name).read_text())['variants']
                self.assertNotIn('playbackSHA256', kept)
                self.assertEqual(encoded['playbackSHA256'], sha(b'aac copy'))
                self.assertEqual(encoded['sourceSHA256'], sha(b'alac source'))
                self.assertNotIn('playbackSHA256', missing)

    def test_library_payloads_follow_shipped_hashes(self):
        rows = [dict(path='a.m4a', sourceSHA256=sha(b'alac')), dict(path='b.mod', sourceSHA256=sha(b'mod'))]
        payloads = {'Music/timing.json': library.encoded(dict(variants=rows)),
                    'Music/rhythm.json': library.encoded(dict(variants=rows[:1]))}
        library.with_playback(payloads, {'a.m4a': sha(b'aac'), 'b.mod': sha(b'mod')})
        timing = json.loads(payloads['Music/timing.json'])['variants']
        self.assertEqual(timing[0]['playbackSHA256'], sha(b'aac'))
        self.assertNotIn('playbackSHA256', timing[1])
        self.assertEqual(json.loads(payloads['Music/rhythm.json'])['variants'][0]['playbackSHA256'], sha(b'aac'))


if __name__ == '__main__':
    unittest.main()
