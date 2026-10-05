import importlib.util
import json
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('curation', ROOT/'Tools/DifficultyDiagnostics/curate_learning.py')
curation = importlib.util.module_from_spec(spec)
spec.loader.exec_module(curation)


class CurriculumTests(unittest.TestCase):
    def pool(self):
        rows, replays = [], {}
        for skill in sorted(curation.BASIC):
            for n in range(3):
                identity = {'engine':'classic','packID':'test','levelID':skill+str(n)}
                replay_id = skill+str(n)
                rows.append({'entry':{'identity':identity,'levelNameSnapshot':replay_id},
                    'initialHash':replay_id,'profile':{'overallScore':40+n,
                        'key':{'replayRevision':replay_id},'detectedTechniques':[skill],
                        'sourceRank':'Fun',
                        'components':{'techniqueBurden':65,'solutionComplexity':40+n,
                            'executionPrecision':0,'concurrencyBurden':0,
                            'constraintPressure':30,'deductionComplexityProxy':30,
                            'criticalActions':[]}},
                    'startingReleaseRate':50,'rescueRequirementRatio':.5})
                replays[replay_id] = {'initialStateHash':replay_id,'expected':{'didWin':True,'ticks':100},
                    'events':[{'tick':10,'action':{'assign':{'lemmingID':0,'skill':skill}}}]}
        return rows,replays

    def test_redundant_tutorials_do_not_pad_the_path(self):
        rows,replays = self.pool()
        result = curation.select(rows,replays)
        self.assertEqual(len(result['lessons']),8)
        self.assertEqual({l['objective'] for l in result['lessons']},
                         {'introduce:'+s for s in curation.BASIC})
        self.assertEqual(result,curation.select(list(reversed(rows)),replays))

    def test_introductions_prefer_beginner_rank_before_low_demand_fallback(self):
        rows,replays = self.pool()
        for row in rows:
            row['profile']['sourceRank'] = 'Mayhem'
            if row['entry']['levelNameSnapshot'].endswith('2'):
                row['profile']['sourceRank'] = 'Fun'
        preferred = curation.select(rows,replays)['lessons']
        self.assertTrue(all(l['level'].endswith('2') for l in preferred))
        for row in rows:
            row['profile']['sourceRank'] = 'Mayhem'
        fallback = curation.select(rows,replays)['lessons']
        self.assertEqual(len(fallback), len(curation.BASIC))
        self.assertTrue(all(not l['beginnerRank'] and l['intrinsicDemand'] < 180
                            and not l['requiresFullRescue'] for l in fallback))

    def test_replay_failure_cannot_supply_a_lesson(self):
        rows,replays = self.pool()
        for key,replay in replays.items():
            if key.startswith('floater'): replay['expected']['didWin'] = False
        self.assertIn('introduce:floater', curation.select(rows,replays)['unavailableOptionalObjectives'])

    def test_inputs_after_a_win_do_not_hide_a_valid_lesson(self):
        rows,replays = self.pool()
        for replay_id,replay in replays.items():
            if replay_id.endswith('0'):
                replay['events'].append({'tick':101,'action':{'nuke':{}}})
            if replay_id.endswith('1'):
                replay['events'][0]['tick'] = 0
        result = curation.select(rows,replays)
        self.assertTrue(all(l['level'].endswith('0') for l in result['lessons']))

    def test_inputs_after_a_win_do_not_add_teaching_skills(self):
        rows,replays = self.pool()
        replay = replays['miner0']
        replay['events'].append({'tick':101,'action':{'assign':{'lemmingID':0,'skill':'builder'}}})
        self.assertEqual(curation.features(rows[0],replay)['chains'],[['miner']])

    def test_demanding_introduction_stays_deferred_even_with_complete_probes(self):
        rows,replays = self.pool()
        for row in rows:
            if row['profile']['detectedTechniques'] == ['miner']:
                row['profile']['components']['executionPrecision'] = 275
                row['profile']['precision'] = {'completed': True}
        result = curation.select(rows,replays)
        self.assertIn('introduce:miner', result['unavailableOptionalObjectives'])
        self.assertFalse(any(l['objective'] == 'introduce:miner' for l in result['lessons']))

    def test_source_release_rate_and_rescue_quota_raise_candidate_demand(self):
        rows,replays = self.pool()
        row = rows[0]
        row['startingReleaseRate'] = 99
        self.assertEqual(curation.demand(row), 360)
        row['startingReleaseRate'] = 50
        row['rescueRequirementRatio'] = .95
        self.assertEqual(curation.demand(row), 360)
        row['rescueRequirementRatio'] = .949
        self.assertLess(curation.demand(row), 180)

    def test_unverified_source_constraints_are_deferred(self):
        rows,_ = self.pool()
        row = rows[0]
        row.pop('startingReleaseRate')
        self.assertGreaterEqual(curation.demand(row), 360)

    def test_narrow_timing_actions_are_deferred(self):
        rows,_ = self.pool()
        row = rows[0]
        row['profile']['criticalActions'] = [0]
        self.assertGreaterEqual(curation.demand(row), 360)

    def test_repeated_builders_are_not_new_sequences(self):
        rows,_ = self.pool()
        row=rows[0]
        events=[{'tick':i,'action':{'assign':{'lemmingID':0,'skill':s}}}
                for i,s in enumerate(['builder','builder','basher','builder'])]
        result=curation.features(row,{'events':events})
        self.assertEqual(result['chains'],[['builder','basher','builder']])
        self.assertEqual(result['triples'],set())
        self.assertEqual(result['pairs'],{('builder','basher'),('basher','builder')})

    def test_official_preference_stays_inside_comparable_difficulty(self):
        rows,replays = self.pool()
        for row in rows:
            row['official'] = row['entry']['levelNameSnapshot'].endswith('1')
        result = curation.select(rows,replays)
        self.assertTrue(all(l['level'].endswith('1') for l in result['lessons']))
        for row in rows:
            if row['official']: row['profile']['overallScore'] = 300
        result = curation.select(rows,replays)
        self.assertTrue(all(l['level'].endswith('0') for l in result['lessons']))

    def test_roles_not_worker_count_define_an_application(self):
        rows,_ = self.pool()
        def signature(ids):
            events=[{'tick':i,'action':{'assign':{'lemmingID':worker,'skill':'builder'}}}
                    for i,worker in enumerate(ids)]
            return curation.application_signature(curation.features(rows[0], {'events':events}))
        self.assertEqual(signature([0]), signature([1,2,3]))

    def test_current_path_is_selective_and_respects_placement_floors(self):
        plan=json.loads((ROOT/'Artifacts/LearningJourney/curriculum.json').read_text())
        manifest=json.loads((ROOT/'Resources/Progression/learning.json').read_text())
        goals={json.dumps(l['identity'],sort_keys=True):l for l in plan['lessons']}
        lessons=manifest['lessons']
        self.assertLess(len(lessons),plan['poolSize'])
        self.assertTrue(200 <= len(lessons) <= 305)
        self.assertEqual(len({g['applicationSignature'] for g in goals.values()}),len(lessons))
        self.assertEqual(len({g['objective'] for g in goals.values()}),len(lessons))
        introductions=0
        for i,lesson in enumerate(lessons):
            goal=goals[json.dumps(lesson['entry']['identity'],sort_keys=True)]
            self.assertEqual(lesson['focus'],goal['lesson'])
            if (goal.get('startingReleaseRate') is None
                    or goal.get('rescueRequirementRatio') is None
                    or goal['startingReleaseRate'] == 99
                    or goal.get('hasNarrowTiming', False)
                    or goal['rescueRequirementRatio'] >= .95):
                self.assertIn(lesson['stage'],('Difficult','Expert'))
            if goal['objective'].startswith('introduce:'):
                introductions+=1
                if not goal['beginnerRank']:
                    self.assertEqual(lesson['stage'],'Intermediate')
                self.assertFalse(goal['requiresFullRescue'])
                self.assertLess(goal['intrinsicDemand'],180)
            if lesson['stage']=='Fun': self.assertFalse(lesson['preparationGaps'])
        self.assertEqual(introductions,8)
        self.assertTrue(all(b['demand'] >= a['demand'] for a,b in zip(lessons,lessons[1:])))
        summary=json.loads((ROOT/'Artifacts/LearningJourney/summary.json').read_text())
        self.assertEqual(summary['levels'],len(lessons))
        self.assertEqual(summary['stages'],{stage:sum(l['stage']==stage for l in lessons)
                         for stage in ('Fun','Intermediate','Difficult','Expert')})
        for a,b in zip(lessons,lessons[1:]):
            if b['demand']-a['demand'] > 65:
                self.assertTrue(b['needsSupport'])

if __name__=='__main__': unittest.main()
