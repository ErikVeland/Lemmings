"""Small malformed-input and format checks for the build-time Mac decoder."""
import struct
import unittest
from prepare import decode_bank, unpack

class DecoderTests(unittest.TestCase):
    def test_overlapping_lzss_copy(self):
        self.assertEqual(unpack(bytes([4, 65, 66, 0x30, 1]), 8), b'ABABABAB')

    def test_truncated_lzss(self):
        with self.assertRaises((IndexError, struct.error)):
            unpack(bytes([0]), 1)
        with self.assertRaises(IndexError):
            unpack(bytes([1, 0, 0]), 3)

    def test_color_runs_and_origins(self):
        palette = [(0, 0, 0, 255), (12, 34, 56, 255)]
        for version in [1, 2]:
            prefix = struct.pack('>HH', 32, 20) if version == 2 else b''
            bank = struct.pack('>I', 4) + prefix + struct.pack('>hhHH', -1, 3, 2, 1) + bytes([0, 1, 128])
            frame = decode_bank(bank, palette, version)[0]
            self.assertEqual(frame[:4], (-1, 3, 2, 1))
            self.assertEqual(frame[4], bytes([12, 34, 56, 255, 0, 0, 0, 0]))

    def test_monochrome_words_and_padding(self):
        # Bit 0 is transparent even with image ink. Bits 1/2 are black/white.
        for version in [1, 2]:
            prefix = bytes(4) if version == 2 else b''
            bank = struct.pack('>I', 4) + prefix + struct.pack('>hhHHHH', -3, 2, 3, 1, 0x9FFF, 0xC000)
            frame = decode_bank(bank, None, version)[0]
            self.assertEqual(frame[:4], (-3, 2, 16, 1))
            self.assertEqual(frame[4][:12], bytes([0, 0, 0, 0, 0, 0, 0, 255, 255, 255, 255, 255]))
            self.assertEqual(frame[4][12:], bytes(13 * 4))

    def test_monochrome_truncated_and_empty_slots(self):
        bank = struct.pack('>IIhhHH', 8, 0, 0, 0, 1, 1) + bytes(4)
        self.assertIsNone(decode_bank(bank, None, 1)[1])
        with self.assertRaises(ValueError):
            decode_bank(bank[:-1], None, 1)

    def test_invalid_run(self):
        bank = struct.pack('>IhhHH', 4, 0, 0, 1, 1) + bytes([129])
        with self.assertRaises(ValueError):
            decode_bank(bank, [(0, 0, 0, 255)], 1)

if __name__ == '__main__':
    unittest.main()
