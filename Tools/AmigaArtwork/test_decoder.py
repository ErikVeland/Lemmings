import importlib.util
from pathlib import Path
import struct
import unittest
import prepare

spec = importlib.util.spec_from_file_location('extract',Path(__file__).with_name('extract-disks.py'))
extract = importlib.util.module_from_spec(spec)
spec.loader.exec_module(extract)

class ArtworkDecoderTests(unittest.TestCase):
    def test_backward_literals_and_checksum(self):
        bits = '00'+'001'+'01000010'+'01000001'
        value = (1<<len(bits)) | sum(int(b)<<i for i,b in enumerate(bits))
        packed = struct.pack('>III',value,value,2)
        self.assertEqual(extract.unpack(packed),b'AB')
        with self.assertRaises(ValueError):
            extract.unpack(struct.pack('>III',value,value^1,2))

    def test_planar_mask_and_channel_order(self):
        # Two colour planes, followed by a mask. Pixel 1 is transparent.
        pixels = prepare.planar(bytes.fromhex('8000 4000 8000'),16,1,2,
                                [(0,0,0),(255,0,0),(0,255,0),(0,0,255)],mask=4)
        self.assertEqual(pixels[:8],bytes([255,0,0,255,0,255,0,0]))
        with self.assertRaises(ValueError):
            prepare.planar(b'\0',16,1,2,[(0,0,0)]*4)

    def test_mfm_and_checksum(self):
        value = bytes.fromhex('deadbeef')
        encoded = bytes(x>>1 & 0x55 for x in value)+bytes(x&0x55 for x in value)
        self.assertEqual(extract.mfm(encoded),value)
        self.assertEqual(extract.checksum(value),0x11514110)

if __name__ == '__main__': unittest.main()
