"""Verify the font bank that the clean Ultimate Lemmix package installs."""
import hashlib
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'Tools/AlternativeAssets'))
import prepare_project_pixel


class SharedPixelFontTests(unittest.TestCase):
    @unittest.skipUnless(
        Path(os.environ.get('ULTIMATE_LEMMIX_PIXEL_FONT_DIR',
                            ROOT / '.build/mac-artwork/export/lemmings')).is_dir(),
        'The reviewed Ultimate Lemmings font inputs are required for byte comparison.',
    )
    def test_package_has_the_same_glyphs_and_metrics_as_ultimate_lemmings(self):
        files = prepare_project_pixel.resources()
        prefix = 'Fonts/LixInterface/'
        manifest = json.loads(files[prefix + 'manifest.json'])
        data = {'manifest.json': json.dumps(manifest, sort_keys=True, separators=(',', ':')).encode()}
        for name, contents in files.items():
            if name.endswith('.rgba'):
                data[name.removeprefix(prefix)] = contents
        digest = hashlib.sha256()
        for name, contents in sorted(data.items()):
            digest.update(name.encode() + b'\0' + contents)
        self.assertEqual(len(data), 211)
        self.assertEqual(digest.hexdigest(), '0a11289b889d131a4ddbca48c427320f18ce842a5d9d1ba959fc38a0256b0dfa')

    def test_packaging_fails_when_the_shared_font_is_missing(self):
        with tempfile.TemporaryDirectory() as source, patch.dict(
            os.environ, {'ULTIMATE_LEMMIX_PIXEL_FONT_DIR': source},
        ):
            with self.assertRaisesRegex(ValueError, 'Ultimate Lemmings pixel font'):
                prepare_project_pixel.resources()
