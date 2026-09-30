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
                        'components':{'techniqueBurden':65,'solutionComplexity':40+n,
                            'executionPrecision':0,'concurrencyBurden':0,
                            'constraintPressure':30,'deductionComplexityProxy':30}}})
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

    def test_replay_failure_cannot_supply_a_lesson(self):
        rows,replays = self.pool()
        for key,replay in replays.items():
            if key.startswith('floater'): replay['expected']['didWin'] = False
        with self.assertRaises(AssertionError): curation.select(rows,replays)

    def test_replays_rejected_by_hints_cannot_supply_a_lesson(self):
        rows,replays = self.pool()
        for replay_id,replay in replays.items():
            if replay_id.endswith('0'):
                replay['events'].append({'tick':101,'action':{'nuke':{}}})
            if replay_id.endswith('1'):
                replay['events'][0]['tick'] = 0
        result = curation.select(rows,replays)
        self.assertTrue(all(l['level'].endswith('2') for l in result['lessons']))

    def test_demanding_introduction_requires_complete_probes(self):
        rows,replays = self.pool()
        for row in rows:
            if row['profile']['detectedTechniques'] == ['miner']:
                row['profile']['components']['executionPrecision'] = 275
                row['profile']['precision'] = {'completed': False}
        with self.assertRaises(AssertionError): curation.select(rows,replays)
        reviewed = next(r for r in rows if r['entry']['levelNameSnapshot'] == 'miner2')
        reviewed['profile']['precision']['completed'] = True
        result = curation.select(rows,replays)
        lesson = next(l for l in result['lessons'] if l['objective'] == 'introduce:miner')
        self.assertEqual(lesson['level'], 'miner2')
        self.assertGreaterEqual(lesson['intrinsicDemand'], 180)

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

    def test_current_path_is_selective_and_intermediate_led(self):
        plan=json.loads((ROOT/'Artifacts/LearningJourney/curriculum.json').read_text())
        manifest=json.loads((ROOT/'Resources/Progression/learning.json').read_text())
        goals={json.dumps(l['identity'],sort_keys=True):l for l in plan['lessons']}
        lessons=manifest['lessons']
        self.assertLess(len(lessons),plan['poolSize'])
        self.assertTrue(280 <= len(lessons) <= 305)
        self.assertEqual(len({g['applicationSignature'] for g in goals.values()}),len(lessons))
        self.assertEqual(len({g['objective'] for g in goals.values()}),len(lessons))
        for i,lesson in enumerate(lessons):
            goal=goals[json.dumps(lesson['entry']['identity'],sort_keys=True)]
            self.assertEqual(goal['objective'].startswith('introduce:'),i<8)
            self.assertEqual(lesson['focus'],goal['lesson'])
            self.assertFalse(lesson['preparationGaps'])
        self.assertGreaterEqual(sum(l['stage']=='Intermediate' for l in lessons),len(lessons)/2)
        for a,b in zip(lessons,lessons[1:]):
            if b['demand']-a['demand'] > 65:
                self.assertTrue(b['needsSupport'])

if __name__=='__main__': unittest.main()
