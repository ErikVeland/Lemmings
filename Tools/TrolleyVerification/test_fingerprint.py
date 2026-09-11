"""Keep presentation edits separate from replay-engine changes."""
import tempfile
import unittest
from pathlib import Path
import catalogue


class FingerprintTests(unittest.TestCase):
    def test_presentation_is_ignored_but_engine_changes_retire_proofs(self):
        previous = catalogue.PROJECT
        try:
            with tempfile.TemporaryDirectory() as directory:
                catalogue.PROJECT = Path(directory)
                sources = catalogue.PROJECT / 'Sources/NxlvKit'
                sources.mkdir(parents=True)
                engine = sources / 'ClassicDOSSimulation.swift'
                engine.write_text('engine version one')
                baseline = catalogue.fingerprint()
                for name in sorted(catalogue.PRESENTATION_FILES):
                    (sources / name).write_text('new presentation preference or input binding')
                    self.assertEqual(catalogue.fingerprint(), baseline)
                engine.write_text('changed simulation')
                self.assertNotEqual(catalogue.fingerprint(), baseline)
                engine.write_text('engine version one')
                (sources / 'NewPhysics.swift').write_text('new simulation dependency')
                self.assertNotEqual(catalogue.fingerprint(), baseline)
        finally:
            catalogue.PROJECT = previous


if __name__ == '__main__':
    unittest.main()
