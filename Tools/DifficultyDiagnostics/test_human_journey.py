"""Regression checks for admission evidence, independent of native UI or audio."""
import unittest
from unittest.mock import patch
import copy

import human_journey as journey


def item(position, lower=None, upper=None, skills=('basher',), official=True):
    return {'row': {'official': official}, 'context': {'usedSkills': dict.fromkeys(skills, 1)},
            'placement': {'position': position, 'lower': lower if lower is not None else position,
                          'upper': upper if upper is not None else position}}


class GoldenPathAdmissionTests(unittest.TestCase):
    def test_bridge_must_fit_reviewed_bounds_inside_an_actual_gap(self):
        spine = [item(100), item(130)]
        self.assertTrue(journey.fills_reviewed_gap(item(115, 105, 125, official=False), spine))
        self.assertFalse(journey.fills_reviewed_gap(item(115, 95, 125, official=False), spine))
        self.assertFalse(journey.fills_reviewed_gap(item(115, 105, 135, official=False), spine))
        self.assertFalse(journey.fills_reviewed_gap(item(105, 100, 110, official=False), [item(100), item(110)]))

    def test_bridge_cannot_introduce_an_unpractised_skill(self):
        spine = [item(100), item(130, skills=('builder',))]
        self.assertFalse(journey.fills_reviewed_gap(item(115, 105, 125, skills=('builder',), official=False), spine))
        self.assertTrue(journey.fills_reviewed_gap(item(115, 105, 125, skills=('basher',), official=False), spine))

    def test_human_review_requires_exact_variant_and_discovery_evidence(self):
        row = {'entry': {'sourceRevision': 'source'}}
        context = {'replayRevision': 'replay'}
        references = {'before': {'ordinal': 10}, 'after': {'ordinal': 12}}
        review = {'status': 'approved', 'reviewer': 'Human', 'sourceURL': 'https://example.com/review',
                  'sourceRevision': 'source', 'replayRevision': 'replay', 'ordinarySolution': True,
                  'discoveryNotes': 'Played without hints', 'resourceNotes': 'Recovery available',
                  'afterReference': 'before', 'beforeReference': 'after', 'hiddenInformation': False}
        self.assertTrue(journey.review_approved(review, row, context, references))
        for field, value in [('sourceRevision', 'different'), ('replayRevision', 'different'),
                             ('discoveryNotes', ''), ('hiddenInformation', True), ('reviewer', '')]:
            with self.subTest(field=field):
                self.assertFalse(journey.review_approved(dict(review, **{field: value}), row, context, references))

    def test_seasonal_source_is_detected_even_with_a_simple_title(self):
        for pack, name in [('xmasLemmings1992-LEVEL-4', 'Easy'), ('fan:example', 'Holiday Pack'),
                           ('fan:example', 'Christmas')]:
            self.assertTrue(journey.seasonal({'entry': {'identity': {'packID': pack}, 'packNameSnapshot': name}}))

    def test_every_seasonal_source_has_current_native_evidence_and_unique_coverage(self):
        manifest = journey.read(journey.ROOT / 'Resources/Progression/learning.json')
        result = journey.seasonal_coverage(manifest)
        self.assertEqual(result['sourceEntries'], 72)
        self.assertEqual(result['uniqueSeasonalSourcesAdded'], 70)
        self.assertEqual(result['exactStateAliases'], 2)
        self.assertTrue(all(level['nativeReplayPassed'] and level['step'] > 80 for level in result['levels']))
        self.assertEqual({level['step'] for level in result['levels'] if level['identity'] != level['representedBy']}, {296, 297})

    def test_a_duplicate_title_cannot_replace_an_exact_state_alias(self):
        manifest = journey.read(journey.ROOT / 'Resources/Progression/learning.json')
        original_read = journey.read
        course = copy.deepcopy(original_read(journey.OUT / 'seasonal-plan.json'))
        course['exactStateAliases'][0]['representedBy'] = manifest['lessons'][0]['entry']['identity']
        def read(path):
            return course if path == journey.OUT / 'seasonal-plan.json' else original_read(path)
        with patch.object(journey, 'read', side_effect=read), self.assertRaises(AssertionError):
            journey.seasonal_coverage(manifest)


if __name__ == '__main__':
    unittest.main()
