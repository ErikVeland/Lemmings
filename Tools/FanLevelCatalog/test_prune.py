"""Check that pruning deletes only reviewed records and retains exact survivors."""
import io
import json
import struct
import unittest
import zipfile

from prune import prune, sections


class PruningTests(unittest.TestCase):
    def source(self):
        records = []
        for payload in [b"first", b"removed", b"last"]:
            header = bytearray(10)
            struct.pack_into(">H", header, 4, 2048)
            struct.pack_into(">H", header, 8, 10 + len(payload))
            records.append(bytes(header) + payload)
        output = io.BytesIO()
        with zipfile.ZipFile(output, "w") as archive:
            archive.writestr("levels.dat", b"".join(records))
            archive.writestr("author.txt", b"Original notes")
        return output.getvalue(), records

    def test_preserves_records_notes_and_original_slots(self):
        source, records = self.source()
        removals = [{"member": "levels.dat", "slot": 1}]
        result = prune(source, removals)
        self.assertEqual(result, prune(source, removals))
        with zipfile.ZipFile(io.BytesIO(result)) as archive:
            self.assertEqual(sections(archive.read("levels.dat")), [records[0], records[2]])
            self.assertEqual(archive.read("author.txt"), b"Original notes")
            self.assertEqual(json.loads(archive.read("classic-section-slots.json")), {"levels.dat": [0, 2]})
        with self.assertRaises(ValueError):
            prune(result, removals)

    def test_rejects_invalid_removal_and_truncated_dat(self):
        source, records = self.source()
        for removals in [
            [{"member": "missing.dat", "slot": 0}],
            [{"member": "levels.dat", "slot": -1}],
            [{"member": "levels.dat", "slot": 3}],
            [{"member": "levels.dat", "slot": 1}] * 2,
            [{"member": "levels.dat", "slot": i} for i in range(3)],
        ]:
            with self.assertRaises(ValueError):
                prune(source, removals)
        with self.assertRaises(ValueError):
            sections(records[0][:-1])


if __name__ == "__main__":
    unittest.main()
