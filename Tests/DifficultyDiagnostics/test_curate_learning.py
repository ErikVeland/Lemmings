import copy
import importlib.util
import json
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('human_journey', ROOT / 'Tools/DifficultyDiagnostics/human_journey.py')
journey = importlib.util.module_from_spec(spec)
spec.loader.exec_module(journey)


class CommunityJourneyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.reference = journey.redux_reference()
        cls.plan = journey.read(ROOT / 'Artifacts/LearningJourney/curriculum.json')
        cls.manifest = journey.read(ROOT / 'Resources/Progression/learning.json')
        cls.resources = journey.read(ROOT / 'Artifacts/LearningJourney/source-resources.json')
        cls.pool = journey.load_pool(cls.resources)
        cls.witnesses = journey.read(ROOT / 'Artifacts/LearningJourney/candidate-solutions.json')
        cls.witnesses.update(journey.read(ROOT / 'Resources/Hints/solutions.json'))

    def fixture(self):
        row = next(r for r in self.pool if r['official'] and r['entry']['levelNameSnapshot'] == 'Just dig!')
        replay = self.witnesses.get(row['profile']['key']['replayRevision']) or self.witnesses[row['initialHash']]
        source = next(r for r in self.resources if journey.key(r) == journey.key(row))
        return copy.deepcopy(row), copy.deepcopy(replay), copy.deepcopy(source)

    def test_reference_is_pinned_to_real_pack_order_and_bytes(self):
        self.assertEqual(len(self.reference), 160)
        self.assertEqual([r['ordinal'] for r in self.reference], list(range(1, 161)))
        self.assertEqual(self.reference[0]['title'], 'Just dig!')
        self.assertEqual(self.reference[31]['rank'], 'Gentle')
        self.assertEqual(self.reference[32]['rank'], 'Quirky')
        stored = journey.read(ROOT / 'Artifacts/LearningJourney/redux-reference.json')
        self.assertEqual(stored['levels'], self.reference)

    def test_real_tutorials_are_not_replaced_by_low_scoring_fan_puzzles(self):
        titles = [r['entry']['levelNameSnapshot'] for r in self.manifest['lessons'][:7]]
        self.assertEqual(titles, ['Just dig!', 'Only floaters can survive this', 'Tailor-made for blockers',
                                 'Now use miners and climbers', 'You need bashers this time',
                                 'A task for blockers and bombers', 'Builders will help you here'])
        self.assertTrue(all(l['stage'] == 'Fun' for l in self.manifest['lessons'][:7]))

    def test_full_rescue_does_not_automatically_make_a_tutorial_difficult(self):
        goal = next(g for g in self.plan['lessons'] if g['level'] == 'Now use miners and climbers')
        self.assertEqual(goal['context']['rescueFraction'], 1)
        self.assertLess(goal['placement']['position'], 180)

    def test_rate_is_exposure_not_an_automatic_difficulty_floor(self):
        row, replay, source = self.fixture()
        source['releaseRate'] = 99
        context = journey.solution_context(row, replay, source)
        self.assertAlmostEqual(context['initialHatchIntervalSeconds'], 4 / 17)
        self.assertNotIn('difficulty', context)
        self.assertEqual(context['discoveryDifficulty'], 'unknown from replay')

    def test_skill_budget_uses_actual_used_skills_not_total_stock(self):
        row, replay, source = self.fixture()
        source['skills']['digger'] = 1
        source['skills']['builder'] = 99
        context = journey.solution_context(row, replay, source)
        self.assertEqual(context['exhaustedUsedSkills'], ['digger'])
        self.assertEqual(context['spareUsedSkills']['digger'], 0)

    def test_unknown_precision_does_not_become_zero_human_difficulty(self):
        row, replay, source = self.fixture()
        row['profile'].pop('precision', None)
        context = journey.solution_context(row, replay, source)
        self.assertFalse(context['timingProbeComplete'])
        self.assertIn('incomplete timing probes', journey.risks(context))
        self.assertFalse(context['spatialToleranceMeasured'])

    def test_published_win_is_not_a_discovery_review(self):
        row, replay, source = self.fixture()
        context = journey.solution_context(row, replay, source)
        self.assertTrue(journey.valid_witness(row, replay))
        self.assertFalse(journey.review_approved({}, row, context, {}))

    def approved_review(self, row, context):
        return {'status': 'approved', 'reviewer': 'Test human', 'sourceURL': 'https://example.test/review',
                'sourceRevision': row['entry']['sourceRevision'], 'replayRevision': context['replayRevision'],
                'ordinarySolution': 'Test ordinary completion', 'discoveryNotes': 'Visible route',
                'resourceNotes': 'Spare builders allow mistakes', 'hiddenInformation': False,
                'afterReference': self.reference[0]['reference'], 'beforeReference': self.reference[1]['reference']}

    def test_reviews_are_bound_to_exact_variant_and_ordinary_solution(self):
        row, replay, source = self.fixture(); context = journey.solution_context(row, replay, source)
        references = {r['reference']: r for r in self.reference}
        review = self.approved_review(row, context)
        self.assertTrue(journey.review_approved(review, row, context, references))
        for field in ['sourceRevision', 'replayRevision', 'ordinarySolution', 'discoveryNotes', 'resourceNotes', 'reviewer']:
            changed = dict(review); changed[field] = ''
            self.assertFalse(journey.review_approved(changed, row, context, references), field)
        self.assertFalse(journey.review_approved(dict(review, hiddenInformation=True), row, context, references))
        self.assertFalse(journey.review_approved(dict(review, beforeReference=self.reference[20]['reference']), row, context, references))

    def test_counterparts_do_not_claim_variant_equivalence(self):
        for goal in self.plan['lessons']:
            if goal['placement']['basis'] == 'reduxClassicCounterpart':
                self.assertIn('not variant equivalence', goal['variantDifferences'][0])

    def test_harder_classic_variant_is_held_for_review(self):
        titles = {l['entry']['levelNameSnapshot'] for l in self.manifest['lessons']}
        for lesson in self.manifest['lessons']:
            if lesson['entry']['levelNameSnapshot'] == 'A Block from Home':
                self.assertNotEqual(lesson['placement']['basis'], 'reduxClassicCounterpart')
        queue = journey.read(ROOT / 'Artifacts/LearningJourney/human-review-queue.json')
        block = next(r for r in queue if r['title'] == 'A Block from Home')
        self.assertTrue(any('ten percentage points' in r for r in block['risks']))

    def test_full_journey_and_estimates_remain_explicit(self):
        self.assertEqual(len(self.manifest['lessons']), 294)
        fans = [l for l in self.manifest['lessons'] if l['entry']['identity']['packID'].startswith('fan:')]
        self.assertGreater(len(fans), 100)
        for lesson in fans:
            self.assertIn(lesson['placement']['basis'], ['solutionEstimate', 'reviewedFan', 'reduxPortCounterpart'])
            if lesson['placement']['basis'] == 'solutionEstimate':
                self.assertTrue(lesson['needsSupport'])
                self.assertGreater(lesson['placement']['upper'] - lesson['placement']['lower'], 20)
        self.assertEqual(self.plan['targetSize'], 294)

    def test_promised_182_additions_have_natural_positions_and_native_routes(self):
        lessons = {journey.key(l): l for l in self.manifest['lessons']}
        required = journey.read(journey.OUT / 'required-additions.json')
        self.assertEqual(len(required), 2)
        mac = lessons[journey.key(required[0])]
        six = lessons[journey.key(required[1])]
        self.assertEqual((mac['stage'], mac['demand']), ('Fun', 160))
        self.assertEqual(mac['placement']['basis'], 'reduxPortCounterpart')
        self.assertEqual((six['stage'], six['demand']), ('Intermediate', 345))
        self.assertEqual(six['placement']['basis'], 'solutionEstimate')
        self.assertTrue(mac['needsSupport'])
        pool = {journey.key(r): r for r in self.pool}
        witnesses = copy.deepcopy(self.witnesses)
        row = pool[journey.key(required[0])]
        witnesses.pop(row['initialHash'], None)
        witnesses.pop(row['profile']['key']['replayRevision'], None)
        with self.assertRaisesRegex(AssertionError, 'Missing exact evidence'):
            journey.build(self.pool, witnesses, self.resources, self.reference, [])

    def test_failed_native_proofs_and_duplicate_titles_do_not_fill_slots(self):
        titles = [journey.normalized(l['entry']['levelNameSnapshot']) for l in self.manifest['lessons']]
        self.assertEqual(len(titles), len(set(titles)))
        rejected = {journey.key(r) for r in journey.read(journey.OUT / 'replay-rejections.json')}
        self.assertTrue(rejected.isdisjoint({journey.key(l) for l in self.manifest['lessons']}))

    def test_estimated_beginner_routes_are_forgiving(self):
        for lesson in self.plan['lessons']:
            if lesson['placement']['basis'] == 'solutionEstimate' and lesson['placement']['position'] < 180:
                c = lesson['context']
                self.assertEqual(c['narrowActions'], 0)
                self.assertLessEqual(len(c['usedSkills']), 3)
                self.assertLessEqual(c['jobChanges'], 1)
                self.assertFalse(len(c['usedSkills']) > 1 and c['exhaustedUsedSkills'] and c['savedAboveRequirement'] == 0)

    def test_estimated_additions_have_visible_interactive_objects(self):
        sources = {journey.key(r): r for r in self.resources}
        for lesson in self.manifest['lessons']:
            visible = sources[journey.key(lesson)]['interactiveVisibility']
            self.assertTrue(any(v['effect'] == 1 for v in visible))
            self.assertTrue(all(v['visibleFraction'] >= .2 for v in visible))

    def test_every_lesson_has_its_exact_bundled_solution(self):
        bundled = journey.read(ROOT / 'Resources/Progression/solutions.json')
        pool = {journey.key(r): r for r in self.pool}
        for lesson in self.manifest['lessons']:
            row = pool[journey.key(lesson)]
            self.assertTrue(journey.valid_witness(row, bundled[row['initialHash']]))

    def test_order_uses_independent_reference_positions_without_clamping(self):
        for lesson, goal in zip(self.manifest['lessons'], self.plan['lessons']):
            self.assertEqual(lesson['demand'], lesson['placement']['position'])
            if lesson['placement']['basis'] == 'reduxClassicCounterpart':
                self.assertEqual(lesson['demand'], goal['reference']['ordinal'] * 5)
        for a, b in zip(self.manifest['lessons'], self.manifest['lessons'][1:]):
            self.assertGreaterEqual(b['demand'], a['demand'])
            self.assertLessEqual(b['demand'] - a['demand'], 65)

    def test_repeated_practice_is_allowed(self):
        skills = [tuple(l['concepts']) for l in self.manifest['lessons']]
        self.assertLess(len(set(skills)), len(skills))

    def test_excluded_hidden_exit_and_unhelpful_fan_puzzles_stay_out(self):
        titles = {l['entry']['levelNameSnapshot'] for l in self.manifest['lessons']}
        self.assertNotIn('Lost something?', titles)
        self.assertNotIn('Mienrs <--- lol, typo', titles)

    def test_generation_is_deterministic_and_resource_complete(self):
        args = (self.witnesses, self.resources, self.reference, [])
        actual = journey.build(self.pool, *args)
        self.assertEqual(actual, journey.build(list(reversed(self.pool)), *args))
        self.assertEqual(actual[0], self.manifest)
        self.assertEqual(actual[1], self.plan)

    def test_all_selected_routes_have_exact_native_winning_proofs(self):
        proofs = journey.read(ROOT / 'Artifacts/LearningJourney/native-replay-validation.json')
        expected = {(journey.key(r['entry']), r['entry']['sourceRevision'], r['placement']['replayRevision'])
                    for r in self.manifest['lessons']}
        actual = {(journey.key(r), r['sourceRevision'], r['replayRevision']) for r in proofs if r['passed']}
        self.assertEqual(len(proofs), 294)
        self.assertTrue(all(r['passed'] for r in proofs))
        self.assertEqual(actual, expected)

    def test_altered_winning_route_cannot_reuse_a_difficulty_profile(self):
        row, replay, _ = self.fixture()
        self.assertTrue(journey.valid_witness(row, replay))
        replay['events'][0]['tick'] += 1
        self.assertFalse(journey.valid_witness(row, replay))

    def test_source_only_or_out_of_range_replay_is_rejected(self):
        row, replay, _ = self.fixture()
        replay['sourceRules'] = {'some': 'rule'}
        self.assertFalse(journey.valid_witness(row, replay))
        replay.pop('sourceRules')
        replay['events'][0]['tick'] = replay['expected']['ticks'] + 1
        self.assertFalse(journey.valid_witness(row, replay))

if __name__ == '__main__':
    unittest.main()
