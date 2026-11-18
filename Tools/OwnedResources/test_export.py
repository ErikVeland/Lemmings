"""Check the local asset exporter without changing installed applications."""
from pathlib import Path
import tempfile
import unittest

import export


class ExportSafetyTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.source = self.root / 'source'
        self.source.mkdir()

    def tearDown(self):
        self.temporary.cleanup()

    def put(self, name, data=b'owned asset'):
        path = self.source / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        return path

    def test_preserves_asset_paths_and_omits_trusted_metadata(self):
        self.put('Ports/Classic/MAIN.DAT')
        self.put('Hints/classic.json', b'untrusted metadata')
        output = self.root / 'export'
        record = export.export(self.source, output)
        self.assertEqual([row['path'] for row in record['files']], ['Ports/Classic/MAIN.DAT'])
        self.assertFalse((output / 'Hints').exists())
        self.assertFalse(record['redistributionCleared'])

    def test_extra_files_and_changed_bytes_are_rejected(self):
        self.put('Ports/Classic/MAIN.DAT')
        output = self.root / 'export'
        export.export(self.source, output)
        (output / 'Ports/Classic/MAIN.DAT').write_bytes(b'changed')
        with self.assertRaises(ValueError):
            export.verify(output)

    def test_standalone_code_and_unknown_families_are_rejected(self):
        for name, data in [('Ports/run.sh', b'echo'), ('Ports/disguised.dat', b'MZ executable'),
                           ('Ports/amiga', b'\0\0\x03\xf3hunk'), ('Unknown/data.dat', b'data')]:
            path = self.put(name, data)
            with self.subTest(name=name), self.assertRaises(ValueError):
                export.collect(self.source)
            path.unlink()

    def test_links_and_unrelated_output_are_preserved(self):
        payload = self.put('Ports/Classic/MAIN.DAT')
        link = self.source / 'Ports/link.dat'
        link.symlink_to(payload)
        with self.assertRaises(ValueError):
            export.collect(self.source)
        link.unlink()
        output = self.root / 'export'
        output.mkdir()
        sentinel = output / 'keep.txt'
        sentinel.write_text('keep')
        with self.assertRaises(ValueError):
            export.export(self.source, output)
        self.assertEqual(sentinel.read_text(), 'keep')

    def test_legacy_standalone_code_is_omitted_only_from_an_existing_app(self):
        app = self.root / 'Owned.app'
        resources = app / 'Contents/Resources'
        resources.mkdir(parents=True)
        (resources / 'Ports/amiga_extracted/holiday').mkdir(parents=True)
        (resources / 'Ports/amiga_extracted/holiday/run').write_bytes(b'\0\0\x03\xf3hunk')
        (resources / 'Ports/data.dat').write_bytes(b'asset')
        selected, omissions, _ = export.collect(app)
        self.assertEqual(set(selected), {'Ports/data.dat'})
        self.assertEqual(omissions, ['Ports/amiga_extracted/holiday/run'])
        self.put('Ports/amiga_extracted/holiday/run', b'\0\0\x03\xf3hunk')
        with self.assertRaises(ValueError):
            export.collect(self.source)


if __name__ == '__main__':
    unittest.main()
