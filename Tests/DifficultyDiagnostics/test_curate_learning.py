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
                replays[replay_id] = {'initialStateHash':replay_id,'expected':{'didWin':True},
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

    def test_repeated_builders_are_not_new_sequences(self):
        rows,_ = self.pool()
        row=rows[0]
        events=[{'tick':i,'action':{'assign':{'lemmingID':0,'skill':s}}}
                for i,s in enumerate(['builder','builder','basher','builder'])]
        result=curation.features(row,{'events':events})
        self.assertEqual(result['chains'],[['builder','basher','builder']])
        self.assertEqual(result['triples'],set())
        self.assertEqual(result['pairs'],{('builder','basher'),('basher','builder')})

    def test_current_path_is_selective_and_intermediate_led(self):
        plan=json.loads((ROOT/'Artifacts/LearningJourney/curriculum.json').read_text())
        manifest=json.loads((ROOT/'Resources/Progression/learning.json').read_text())
        goals={json.dumps(l['identity'],sort_keys=True):l for l in plan['lessons']}
        lessons=manifest['lessons']
        self.assertLess(len(lessons),plan['poolSize'])
        self.assertEqual(len({g['objective'] for g in goals.values()}),len(lessons))
        for i,lesson in enumerate(lessons):
            goal=goals[json.dumps(lesson['entry']['identity'],sort_keys=True)]
            self.assertEqual(goal['objective'].startswith('introduce:'),i<8)
            self.assertEqual(lesson['focus'],goal['lesson'])
            self.assertFalse(lesson['preparationGaps'])
        self.assertGreaterEqual(sum(l['stage']=='Intermediate' for l in lessons),len(lessons)/2)
        self.assertLessEqual(max(b['demand']-a['demand'] for a,b in zip(lessons,lessons[1:])),65)

if __name__=='__main__': unittest.main()
