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
        titles = [r['entry']['levelNameSnapshot'] for r in self.manifest['lessons'][:8]]
        self.assertEqual(titles, ['Just dig!', 'Cellbash', 'Only floaters can survive this', 'Tailor-made for blockers',
                                 'Now use miners and climbers', 'You need bashers this time',
                                 'A task for blockers and bombers', 'Builders will help you here'])
        self.assertTrue(all(l['stage'] == 'Fun' for l in self.manifest['lessons'][:8]))

    def test_full_rescue_does_not_automatically_make_a_tutorial_difficult(self):
        goal = next(g for g in self.plan['lessons'] if g['level'] == 'Now use miners and climbers')
        self.assertEqual(goal['context']['rescueFraction'], 1)
        self.assertLess(goal['placement']['position'], 180)

    def test_release_rate_is_measured_without_claiming_discovery(self):
        row, replay, source = self.fixture()
        source['releaseRate'] = 99
        source['minimumReleaseRate'] = 99
        context = journey.solution_context(row, replay, source)
        self.assertAlmostEqual(context['initialHatchIntervalSeconds'], 4 / 17)
        self.assertNotIn('difficulty', context)
        self.assertEqual(context['discoveryDifficulty'], 'unknown from replay')

    def test_minimum_rate_hatches_and_per_tick_workload_are_recorded(self):
        row, replay, source = self.fixture()
        source.update(releaseRate=90, minimumReleaseRate=90, maximumReleaseRate=99, hatchCount=2)
        source['required'] = source['population']
        duplicate = copy.deepcopy(next(e for e in replay['events'] if 'assign' in e['action']))
        duplicate['action']['assign']['lemmingID'] += 1
        replay['events'].append(duplicate)
        context = journey.solution_context(row, replay, source)
        self.assertEqual(context['minimumReleaseRate'], 90)
        self.assertFalse(context['canSlowReleaseBelowStartingRate'])
        self.assertAlmostEqual(context['slowestHatchIntervalSeconds'], 8 / 17)
        self.assertEqual(context['hatchCount'], 2)
        self.assertEqual(context['peakAssignmentsPerTick'], 2)
        self.assertEqual(context['ticksWithMultipleAssignments'], 1)
        self.assertEqual(context['peakDistinctWorkersPerSecond'], 2)
        warnings = journey.early_pressure_warnings(context)
        self.assertTrue(any('minimum release rate' in warning for warning in warnings))
        self.assertTrue(any('multiple hatches' in warning for warning in warnings))
        self.assertTrue(any('assignment workload' in warning for warning in warnings))

    def test_resource_export_has_exact_rate_limits_and_native_hatch_counts(self):
        for source in self.resources:
            self.assertEqual(source['minimumReleaseRate'], min(99, max(0, source['releaseRate'])))
            self.assertEqual(source['maximumReleaseRate'], 99)
            self.assertGreaterEqual(source['hatchCount'], 1)
            self.assertLessEqual(source['hatchCount'], 4)

    def test_quicky_and_comparable_pressure_routes_cannot_return_to_early_teaching(self):
        quicky = next(g for g in self.plan['lessons'] if g['identity']['levelID'] == '45:Wild:6:7:5')
        self.assertEqual(quicky['difficultyVerdict'], 'tooHardForEarlyJourney')
        self.assertEqual(quicky['context']['rescueFraction'], 1)
        self.assertEqual(len(quicky['context']['exhaustedUsedSkills']), 4)
        self.assertGreaterEqual(quicky['placement']['position'], 700)
        self.assertTrue(quicky['requiredPreparation'])
        for lesson in self.plan['lessons']:
            if lesson['teachingPhase'] is None and journey.early_pressure_warnings(lesson['context']):
                self.assertGreaterEqual(lesson['placement']['position'], 600)

    def test_pinned_builder_bridges_are_low_pressure_before_combined_puzzles(self):
        bridges = [g for g in self.plan['lessons'] if g['teachingPhase'] == 'bridgePractice']
        self.assertEqual(len(bridges), 2)
        for bridge in bridges:
            c = bridge['context']
            self.assertEqual(set(c['usedSkills']), {'builder'})
            self.assertEqual(c['jobChanges'], 0)
            self.assertEqual(c['narrowActions'], 0)
            self.assertGreaterEqual(c['spareUsedSkills']['builder'], 4)
            self.assertGreater(c['savedAboveRequirement'], 0)
            self.assertLess(bridge['placement']['position'], 360)

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
        self.assertIn('withheld pending exact human difficulty review', block['status'])

    def test_full_journey_and_estimates_remain_explicit(self):
        self.assertLess(len(self.manifest['lessons']), 295)
        fans = [l for l in self.manifest['lessons'] if l['entry']['identity']['packID'].startswith('fan:')]
        self.assertEqual(len(fans), 2)
        for lesson in fans:
            self.assertIn(lesson['placement']['basis'], ['userPlaytest', 'reviewedFan', 'reduxPortCounterpart'])
        self.assertEqual(self.plan['targetSize'], len(self.manifest['lessons']))

    def test_promised_182_additions_have_natural_positions_and_native_routes(self):
        lessons = {journey.key(l): l for l in self.manifest['lessons']}
        required = journey.read(journey.OUT / 'required-additions.json')
        self.assertTrue(all(journey.key(r) in lessons for r in required))
        mac = lessons[journey.key(required[0])]
        six = lessons[journey.key(required[1])]
        self.assertEqual(mac['stage'], 'Expert')
        self.assertGreaterEqual(mac['demand'], 600)
        self.assertEqual(mac['placement']['basis'], 'userPlaytest')
        self.assertGreaterEqual(six['demand'], journey.teaching_floor(six['entry']))
        self.assertEqual(six['placement']['basis'], 'teachingCurriculum')
        pool = {journey.key(r): r for r in self.pool}
        witnesses = copy.deepcopy(self.witnesses)
        row = pool[journey.key(required[0])]
        witnesses.pop(row['initialHash'], None)
        witnesses.pop(row['profile']['key']['replayRevision'], None)
        with self.assertRaisesRegex(AssertionError, 'Missing exact evidence'):
            journey.build(self.pool, witnesses, self.resources, self.reference, [])

    def test_failed_native_proofs_and_duplicate_identities_do_not_fill_slots(self):
        identities = [journey.key(l) for l in self.manifest['lessons']]
        self.assertEqual(len(identities), len(set(identities)))
        rejected = {journey.key(r) for r in journey.read(journey.OUT / 'replay-rejections.json')}
        self.assertTrue(rejected.isdisjoint({journey.key(l) for l in self.manifest['lessons']}))

    def test_beginner_practice_routes_are_forgiving(self):
        for lesson in self.plan['lessons']:
            if lesson['teachingPhase'] == 'simplePractice':
                c = lesson['context']
                self.assertEqual(c['narrowActions'], 0)
                self.assertLessEqual(len(c['usedSkills']), 3)
                self.assertLessEqual(c['jobChanges'], 1)
                self.assertFalse(len(c['usedSkills']) > 1 and c['exhaustedUsedSkills'] and c['savedAboveRequirement'] == 0)
            if lesson['teachingPhase'] == 'openPractice':
                c = lesson['context']
                self.assertEqual(c['minimumReleaseRate'], 1)
                self.assertEqual(c['rescueFraction'], .5)
                self.assertTrue(all(count > 0 for count in c['spareUsedSkills'].values()))

    def test_entire_course_has_pinned_chapters_and_transition_reviews(self):
        course = journey.read(journey.OUT / 'course-plan.json')
        report = journey.read(journey.OUT / 'course-review.json')
        self.assertEqual(len(course['chapters']), 13)
        self.assertEqual(len(course['lessons']), 227)
        self.assertEqual(report, journey.course_review_document(self.manifest, self.plan))
        for authored, lesson, review in zip(course['lessons'], self.manifest['lessons'], report['lessons']):
            self.assertEqual(journey.key(authored), journey.key(lesson))
            self.assertEqual(authored['sourceRevision'], lesson['entry']['sourceRevision'])
            self.assertEqual(authored['replayRevision'], lesson['placement']['replayRevision'])
            self.assertTrue(review['placementReason'])
            self.assertTrue(review['goal'])
            self.assertTrue(all(example['step'] < review['step'] for example in review['preparationExamples']))
            if review['step'] > 30:
                self.assertLessEqual(sum(value > 30 for value in review['pressureRises'].values()), 2)
                self.assertLessEqual(len(review['newPressurePeaks']), 2)

    def test_transition_review_rejects_a_compound_pressure_wall(self):
        plan = copy.deepcopy(self.plan)
        for lesson in plan['lessons'][:31]:
            lesson['humanPressureAxes'] = dict.fromkeys(lesson['humanPressureAxes'], 0)
        axes = plan['lessons'][30]['humanPressureAxes']
        for axis in list(axes)[:3]:
            axes[axis] = 100
        with self.assertRaisesRegex(AssertionError, 'Too many new pressure peaks'):
            journey.course_transition_review(plan)
        # Familiar pressures can still form an abrupt compound jump after a recovery.
        for lesson in plan['lessons'][:2]:
            lesson['humanPressureAxes'] = axes.copy()
        with self.assertRaisesRegex(AssertionError, 'Compound pressure jump'):
            journey.course_transition_review(plan)

    def test_quota_timing_does_not_mistake_replay_shutdown_for_a_deadline(self):
        titles = ['Get a little extra help', 'How on Earth?', 'The Steel Mines of Kessel',
                  'Ice Ice Lemming', 'PoP TiL YoU DrOp!']
        for title in titles:
            context = next(g['context'] for g in self.plan['lessons'] if g['level'] == title)
            self.assertTrue(context['quotaTimingVerified'], title)
            self.assertGreater(context['remainingSeconds'], 120, title)
            self.assertEqual(context['remainingSecondsAtReplayEnd'], 0, title)

    def test_commands_after_rescue_quota_do_not_inflate_execution_demand(self):
        row, replay, source = self.fixture()
        proof = copy.deepcopy(next(p for p in journey.read(journey.OUT / 'native-replay-validation.json')
                                   if journey.key(p) == journey.key(row)))
        baseline = journey.solution_context(row, replay, source, proof)
        extra = copy.deepcopy(next(e for e in replay['events'] if 'assign' in e['action']))
        extra.update(tick=proof['firstQuotaTick'], afterTick=True)
        replay['events'].append(extra)
        self.assertEqual(baseline, journey.solution_context(row, replay, source, proof))
        extra['afterTick'] = False
        with self.assertRaisesRegex(AssertionError, 'native successful tool use'):
            journey.solution_context(row, replay, source, proof)

    def test_available_tool_scarcity_is_independent_of_witness_waste(self):
        row, replay, source = self.fixture()
        plentiful = journey.solution_context(row, replay, source)
        extra = copy.deepcopy(next(e for e in replay['events'] if 'assign' in e['action']))
        replay['events'].append(extra)
        wasted = journey.solution_context(row, replay, source)
        self.assertEqual(plentiful['sourceToolScarcity'], wasted['sourceToolScarcity'])
        source['skills'] = {skill: min(count, 1) for skill, count in source['skills'].items()}
        scarce = journey.solution_context(row, replay, source)
        self.assertGreater(scarce['sourceToolScarcity'], plentiful['sourceToolScarcity'])

    def test_slow_single_skill_rescue_practice_precedes_strict_combinations(self):
        rows = self.plan['lessons']
        index = next(i for i, g in enumerate(rows) if g['level'] == 'We all fall down')
        context = rows[index]['context']
        self.assertGreaterEqual(index, 30)
        self.assertLess(index, 45)
        self.assertEqual(context['minimumReleaseRate'], 1)
        self.assertEqual(set(context['usedSkills']), {'digger'})
        self.assertEqual(context['jobChanges'], 0)
        self.assertEqual(context['rescueFraction'], 1)
        for title, chapter in [("It's Lemmingentry Watson", 'small-budgets'),
                               ('PoP YoR ToP!!!', 'hatches'), ('Just A Quicky', 'combined-plans')]:
            lesson = next(g for g in rows if g['level'] == title)
            self.assertEqual(lesson['courseChapter']['id'], chapter)
        self.assertEqual([g['level'] for g in rows[-2:]], ['Time waits for no Lemming', 'This Corrosion'])

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

    def test_beginner_section_is_authored_generous_practice_before_puzzles(self):
        beginner = [l for l in self.manifest['lessons'] if l['stage'] == 'Fun']
        self.assertEqual(len(beginner), 30)
        self.assertEqual(sum(':Tame:' in l['entry']['identity']['levelID'] for l in beginner), 20)
        for lesson in self.manifest['lessons']:
            self.assertGreaterEqual(lesson['demand'], journey.teaching_floor(lesson['entry']))
        names = [l['entry']['levelNameSnapshot'] for l in self.manifest['lessons']]
        self.assertLess(names.index('Honey, I Saved The Lemmings'), names.index('PoP YoR ToP!!!'))
        self.assertGreater(names.index("It's Lemmingentry Watson"), 44)

    def test_teaching_plan_rejects_stricter_resources_and_stale_witnesses(self):
        plan = journey.read(journey.OUT / 'teaching-plan.json')['lessons']
        for phase in ['simplePractice', 'openPractice']:
            lesson = next(l for l in plan if l['phase'] == phase)
            row = copy.deepcopy(next(r for r in self.pool if journey.key(r) == journey.key(lesson)))
            source = copy.deepcopy(next(r for r in self.resources if journey.key(r) == journey.key(lesson)))
            replay = self.witnesses.get(row['profile']['key']['replayRevision']) or self.witnesses[row['initialHash']]
            context = journey.solution_context(row, replay, source)
            candidates = {journey.key(r): r for r in self.pool}
            resources = {journey.key(r): r for r in self.resources}
            contexts = {journey.key(g): g['context'] for g in self.plan['lessons']}
            candidates[journey.key(row)] = row
            resources[journey.key(row)] = source
            contexts[journey.key(row)] = context
            references = {r['reference']: r for r in self.reference}
            source['skills']['basher'] = 1
            with self.assertRaises(AssertionError):
                journey.apply_teaching_plan([], candidates, contexts, resources, references)
            source['skills']['basher'] = 20
            context['replayRevision'] = 'a different route'
            with self.assertRaises(AssertionError):
                journey.apply_teaching_plan([], candidates, contexts, resources, references)

    def test_reordering_retains_all_routes_and_measured_scores(self):
        pool = {journey.key(r): r for r in self.pool}
        for lesson in self.manifest['lessons']:
            self.assertEqual(lesson['score'], pool[journey.key(lesson)]['profile']['overallScore'])

    def test_negative_player_feedback_overrides_an_older_teaching_plan(self):
        row, replay, source = self.fixture()
        ident = journey.key(row)
        context = journey.solution_context(row, replay, source)
        candidates = {journey.key(r): r for r in self.pool}
        resources = {journey.key(r): r for r in self.resources}
        contexts = {journey.key(g): g['context'] for g in self.plan['lessons']}
        contexts[ident] = context
        item = {'row': row, 'context': context, 'reference': self.reference[0],
                'variantDifferences': [], 'reportedWall': {'minimumDemand': 650},
                'placement': {'basis': 'userPlaytest', 'position': 650, 'lower': 650, 'upper': 650}}
        result = journey.apply_teaching_plan([item], candidates, contexts, resources,
                                             {r['reference']: r for r in self.reference})
        changed = next(r for r in result if journey.key(r['row']) == ident)
        self.assertGreaterEqual(changed['placement']['position'], 650)
        self.assertNotIn('teaching', changed)

    def test_difficulty_wall_report_identifies_the_same_routes_and_positions(self):
        report = journey.read(journey.OUT / 'difficulty-walls.json')
        self.assertEqual(report['journeyVersion'], self.manifest['version'])
        expected = {journey.key(g): i + 1 for i, g in enumerate(self.plan['lessons'])
                    if g['difficultyVerdict'] or g['placement'].get('pressureWarnings')}
        self.assertEqual({journey.key(g): g['step'] for g in report['lessons']}, expected)
        self.assertTrue(report['easierPractice'])

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
        self.assertEqual(len(proofs), len(self.manifest['lessons']))
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
