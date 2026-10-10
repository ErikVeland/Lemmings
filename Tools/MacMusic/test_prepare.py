"""Silent checks for the render-to-bundle conversion boundary."""
import importlib.util
import math
from pathlib import Path
import struct
import tempfile
import unittest
import wave

spec = importlib.util.spec_from_file_location('mac_music_prepare', Path(__file__).with_name('prepare.py'))
prepare = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prepare)


def float_wave(samples):
    payload = struct.pack('<' + 'f' * len(samples), *samples)
    fmt = struct.pack('<HHIIHH', 3, 2, 22050, 176400, 8, 32)
    chunks = b'fmt ' + struct.pack('<I', len(fmt)) + fmt + b'data' + struct.pack('<I', len(payload)) + payload
    return b'RIFF' + struct.pack('<I', len(chunks) + 4) + b'WAVE' + chunks


class PCMConversionTests(unittest.TestCase):
    def convert(self, data):
        with tempfile.TemporaryDirectory() as folder:
            source, output = Path(folder) / 'source.wav', Path(folder) / 'pcm.wav'
            source.write_bytes(data)
            result = prepare.pcm_copy(source, output)
            with wave.open(str(output), 'rb') as pcm:
                self.assertEqual((pcm.getnchannels(), pcm.getsampwidth(), pcm.getframerate()), (2, 2, 22050))
                samples = struct.unpack('<' + 'h' * (pcm.getnframes() * 2), pcm.readframes(pcm.getnframes()))
            return result, samples

    def test_preserves_levels_below_headroom(self):
        metadata, samples = self.convert(float_wave([0.25, -0.25, 0.5, -0.5]))
        self.assertEqual(metadata['gain'], 1)
        self.assertEqual(metadata['frames'], 2)
        self.assertEqual(samples, (8192, -8192, 16384, -16384))

    def test_constant_trim_without_clipping(self):
        metadata, samples = self.convert(float_wave([2, -2, 1, -1]))
        self.assertAlmostEqual(metadata['gain'], 0.475)
        self.assertEqual(samples, (31129, -31129, 15564, -15564))

    def test_rejects_nonfinite_silent_partial_and_invalid_headers(self):
        for data in [float_wave([math.nan, 1]), float_wave([math.inf, 1]), float_wave([0, 0]),
                     float_wave([1, 1])[:-1], float_wave([1]), b'not a wave']:
            with self.subTest(data=data):
                with self.assertRaises(ValueError):
                    self.convert(data)


if __name__ == '__main__':
    unittest.main()
