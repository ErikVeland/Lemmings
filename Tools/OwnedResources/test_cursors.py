import base64
import importlib.util
from pathlib import Path
import tempfile
import plistlib
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('owned_cursors', Path(__file__).with_name('cursors.py'))
cursors = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(cursors)


class CursorExportTests(unittest.TestCase):
    def fixture(self, name):
        return (ROOT / 'Tests/DialogCursorTests/Fixtures' / name).read_bytes()

    def test_reads_hash_pinned_base64_constants(self):
        cross = self.fixture('amiga-cursor.png')
        target = self.fixture('amiga-reticule.png')
        binary = b'MachO-fixture\0' + base64.b64encode(cross) + b'\0other\0' + base64.b64encode(target) + b'\0'
        self.assertEqual(cursors.extract(binary), {'Cursors/original-cross.png': cross, 'Cursors/original-reticule.png': target})

    def test_reads_only_pinned_raw_pngs(self):
        cross = self.fixture('amiga-cursor.png')
        changed = bytearray(cross)
        changed[-1] ^= 1
        self.assertEqual(cursors.extract(b'prefix' + bytes(changed) + b'suffix'), {})
        self.assertEqual(cursors.extract(b'prefix' + cross + b'suffix'), {'Cursors/original-cross.png': cross})

    def test_supplied_app_and_its_resources_recover_embedded_pair(self):
        with tempfile.TemporaryDirectory() as temporary:
            app = Path(temporary) / 'Full.app'
            resources = app / 'Contents/Resources'
            executable = app / 'Contents/MacOS/Full'
            resources.mkdir(parents=True)
            executable.parent.mkdir()
            (app / 'Contents/Info.plist').write_bytes(plistlib.dumps({'CFBundleExecutable': 'Full'}))
            executable.write_bytes(b'MachO-fixture\0' + base64.b64encode(self.fixture('amiga-cursor.png'))
                + b'\0' + base64.b64encode(self.fixture('amiga-reticule.png')) + b'\0')
            self.assertEqual(len(cursors.collect(app)), 2)
            self.assertEqual(cursors.collect(app), cursors.collect(resources))

    def test_executable_path_cannot_escape_supplied_app(self):
        with tempfile.TemporaryDirectory() as temporary:
            app = Path(temporary) / 'Full.app'
            (app / 'Contents/Resources').mkdir(parents=True)
            (app / 'Contents/Info.plist').write_bytes(plistlib.dumps({'CFBundleExecutable': '../../outside'}))
            with self.assertRaises(cursors.CursorError):
                cursors.collect(app)

    def test_executable_directory_symlink_cannot_escape_app(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            app = root / 'Full.app'
            (app / 'Contents/Resources').mkdir(parents=True)
            outside = root / 'outside'
            outside.mkdir()
            (outside / 'Full').write_bytes(base64.b64encode(self.fixture('amiga-cursor.png')) + b'\0'
                + base64.b64encode(self.fixture('amiga-reticule.png')) + b'\0')
            (app / 'Contents/MacOS').symlink_to(outside, target_is_directory=True)
            (app / 'Contents/Info.plist').write_bytes(plistlib.dumps({'CFBundleExecutable': 'Full'}))
            with self.assertRaises(cursors.CursorError):
                cursors.collect(app)

    def test_incomplete_resource_pair_fails(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / 'Cursors').mkdir()
            (root / 'Cursors/original-cross.png').write_bytes(self.fixture('amiga-cursor.png'))
            with self.assertRaises(cursors.CursorError):
                cursors.collect(root)

    def test_existing_resource_pair_is_preserved(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / 'Cursors').mkdir()
            (root / 'Cursors/original-cross.png').write_bytes(self.fixture('amiga-cursor.png'))
            (root / 'Cursors/original-reticule.png').write_bytes(self.fixture('amiga-reticule.png'))
            self.assertEqual(len(cursors.collect(root)), 2)


if __name__ == '__main__':
    unittest.main()
