import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('report', Path(__file__).resolve().parents[2] / 'Tools/Lemmings2Completion/report.py')
report = importlib.util.module_from_spec(spec)
spec.loader.exec_module(report)


def route(number, population, saved=1):
    return {'tribe': 'classic', 'level': number, 'startingPopulation': population, 'saved': saved}


class ChainTests(unittest.TestCase):
    def test_independent_wins_do_not_prove_a_chain(self):
        self.assertEqual(report.chain_counts([route(n, 60) for n in range(1, 11)], []), {'classic': 1})

    def test_variants_prove_only_the_matching_incoming_population(self):
        base = [route(n, 60) for n in range(1, 11)]
        variants = [route(n, 1) for n in range(2, 11)]
        self.assertEqual(report.chain_counts(base, variants), {'classic': 10})
        variants[3]['startingPopulation'] = 2
        self.assertEqual(report.chain_counts(base, variants), {'classic': 4})

    def test_missing_level_cannot_be_skipped(self):
        self.assertEqual(report.chain_counts([route(1, 60), route(3, 1)], []), {'classic': 1})

    def test_ambiguous_routes_fail(self):
        with self.assertRaisesRegex(ValueError, 'Ambiguous'):
            report.chain_counts([route(1, 60)], [route(1, 60, 2)])


if __name__ == '__main__':
    unittest.main()
