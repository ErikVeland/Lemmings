"""Choose one evidenced example per teaching objective from the validated pool.

Replay actions establish what a route does, not what a novice must discover.
Keep the curriculum separate from the complete catalogue and original campaigns.
"""
import collections
import hashlib
import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / 'Artifacts/LearningJourney'
BASIC = {'climber', 'floater', 'bomber', 'blocker', 'builder', 'basher', 'miner', 'digger'}


def key(row):
    return json.dumps(row['entry']['identity'], sort_keys=True)


def beginner_rank(row):
    source = (row['profile'].get('sourceRank', '') + ' ' + row['entry'].get('packNameSnapshot', '')).lower()
    return any(re.search(r'\b' + rank + r'\b', source) for rank in ('fun', 'easy', 'tame'))


def demand(row):
    p = row['profile']; c = p['components']
    observed = max(p['overallScore'], c['techniqueBurden']*.85, c['solutionComplexity']*.7,
               c['executionPrecision']*.85, c['concurrencyBurden']*.85,
               c['deductionComplexityProxy']*.85, c['constraintPressure']*.5,
               max(0, len(p['detectedTechniques'])-1)*90)
    constrained = (row.get('startingReleaseRate') is None
                   or row.get('rescueRequirementRatio') is None
                   or row.get('startingReleaseRate') == 99
                   or bool(p.get('criticalActions'))
                   or (row.get('rescueRequirementRatio') or 0) >= .95)
    action_heavy = (row.get('skillAssignmentCount') or 0) >= 12
    return max(observed, 360 if constrained or action_heavy else 0)


def requires_full_rescue(row, replay):
    expected = replay.get('expected', {})
    return expected.get('required') is not None and expected.get('required') == expected.get('released')


def features(row, replay):
    workers = collections.defaultdict(list)
    completion_tick = replay.get('expected', {}).get('ticks', float('inf'))
    active_events = (event for event in replay['events'] if event['tick'] <= completion_tick)
    for event in sorted(active_events, key=lambda e: (e['tick'], e.get('afterTick', False))):
        action = event['action'].get('assign')
        if action and (not workers[action['lemmingID']] or workers[action['lemmingID']][-1] != action['skill']):
            workers[action['lemmingID']].append(action['skill'])
    chains = list(workers.values())
    return {'skills': set(row['profile']['detectedTechniques']) & BASIC,
            'concepts': set(row['profile']['detectedTechniques']),
            'pairs': {(a,b) for chain in chains for a,b in zip(chain,chain[1:])},
            'triples': {tuple(chain[i:i+3]) for chain in chains for i in range(len(chain)-2)
                        if len(set(chain[i:i+3])) == 3},
            'chains': chains}


def application_signature(f):
    """Repeated jobs, worker IDs and source titles do not create new lessons."""
    return json.dumps({'concepts': sorted(f['concepts']),
                       'changes': sorted(f['pairs']), 'sequences': sorted(f['triples']),
                       'roles': sorted({tuple(sorted(set(c))) for c in f['chains']})}, sort_keys=True)


def select(pool, replays):
    excluded = {json.dumps(row['identity'], sort_keys=True) for row in json.loads(
        (ROOT / 'Resources/Progression/exclusions.json').read_text())}
    pool = [row for row in pool if key(row) not in excluded and not (replays.get(row['profile']['key']['replayRevision'])
                                      or replays.get(row['initialHash']) or {}).get('sourceRules')]
    pool = sorted(pool, key=lambda r: (demand(r), r['profile']['components']['solutionComplexity'],
                                     r['profile']['overallScore'], key(r)))
    evidence = {}
    for row in pool:
        replay = replays.get(row['profile']['key']['replayRevision']) or replays.get(row['initialHash'])
        row['skillAssignmentCount'] = (sum('assign' in event.get('action', {}) for event in replay.get('events', []))
                                       if replay else None)
        if (replay and replay.get('expected', {}).get('didWin')
                and replay['expected']['ticks'] > 0
                and replay['initialStateHash'] == row['initialHash']
                and all((0 if e.get('afterTick') else 1) <= e['tick'] <= replay['expected']['ticks']
                        for e in replay['events'])):
            evidence[key(row)] = features(row, replay)
    chosen = {}; missing = []; used_signatures = set()

    def choose(objective, lesson, purpose, predicate, lower=0, upper=1000):
        options = [r for r in pool if key(r) in evidence and key(r) not in chosen
                   and lower <= demand(r) <= upper and predicate(r, evidence[key(r)])
                   and application_signature(evidence[key(r)]) not in used_signatures]
        if objective.startswith('introduce:'):
            options = [r for r in options if demand(r) < 180
                       and not requires_full_rescue(r, replays.get(r['profile']['key']['replayRevision'])
                                                    or replays.get(r['initialHash'], {}))]
            beginner_options = [r for r in options if beginner_rank(r)]
            if beginner_options:
                options = beginner_options
        if not options:
            missing.append(objective)
            return
        # Prefer official evidence when it fits the same narrow demand window.
        floor = min(demand(r) for r in options)
        nearby = [r for r in options if demand(r) <= floor + 35]
        row = min(nearby, key=lambda r: (not r.get('official', False), demand(r), key(r)))
        witness = replays.get(row['profile']['key']['replayRevision']) or replays.get(row['initialHash'], {})
        used_signatures.add(application_signature(evidence[key(row)]))
        chosen[key(row)] = {'identity': row['entry']['identity'], 'objective': objective,
            'lesson': lesson, 'purpose': purpose, 'evidence': 'winning replay assignments and measured profile',
            'level': row['entry']['levelNameSnapshot'], 'intrinsicDemand': demand(row),
            'sourceRank': row['profile'].get('sourceRank'), 'beginnerRank': beginner_rank(row),
            'startingReleaseRate': row.get('startingReleaseRate'),
            'rescueRequirementRatio': row.get('rescueRequirementRatio'),
            'skillAssignmentCount': row.get('skillAssignmentCount'),
            'hasNarrowTiming': bool(row['profile'].get('criticalActions')),
            'requiresFullRescue': requires_full_rescue(row, witness)}

    # Prefer a low-demand Fun, Easy or Tame source. A low-demand witness from
    # another rank can prepare a skill in Intermediate when none is available.
    for skill in sorted(BASIC):
        choose('introduce:'+skill, 'Discover: '+skill.capitalize(),
               'First assignment of the '+skill+' skill.',
               lambda r,f,s=skill: f['concepts'] == {s} and r['profile']['components']['executionPrecision'] <= 180,
               upper=180)

    # Give Climbers a second, low-demand use before the selected three-skill
    # scouting route. The first Climber introduction alone leaves a gap there.
    choose('prepare:climber-spacing', 'Climber with crowd spacing',
           'Apply Climber again while changing the release rate.',
           lambda r,f: f['concepts'] == {'climber', 'release-rate-manipulation'},
           lower=120, upper=275)

    # A transition on one worker is different from assigning two independent jobs.
    # Only short, forgiving routes qualify as intermediate teaching examples.
    for a in sorted(BASIC):
        for b in sorted(BASIC-{a}):
            choose('chain:'+a+':'+b, a.capitalize()+' then '+b.capitalize(),
                   'Change the same worker from '+a+' to '+b+' in a winning route.',
                   lambda r,f,a=a,b=b: f['concepts'] == {a,b} and (a,b) in f['pairs'], upper=359)
    for i,a in enumerate(sorted(BASIC)):
        for b in sorted(BASIC)[i+1:]:
            choose('split:'+a+':'+b, 'Split jobs: '+a.capitalize()+' + '+b.capitalize(),
                   'Assign '+a+' and '+b+' to separate workers without changing their skills.',
                   lambda r,f,a=a,b=b: f['concepts'] == {a,b} and not f['pairs'], upper=359)

    # A three-step chain must add a sequence not already used as the lesson goal.
    # Keep one representative per three-skill set, rather than all permutations.
    triples = sorted({tuple(sorted(f['skills'])) for f in evidence.values() if len(f['skills']) == 3})
    for skills in triples:
        choose('sequence:'+':'.join(skills), 'Sequence: '+' + '.join(s.capitalize() for s in skills),
               'Plan a three-skill sequence on one worker: '+', '.join(skills)+'.',
               lambda r,f,s=set(skills): f['concepts'] == s and bool(f['triples']), lower=180, upper=359)

    strategies = [
        ('coordinate', 'Two active workers', 'Manage two working regions in one route.',
         lambda r,f: 'multiple-worker-coordination' in f['concepts'] and len(f['skills']) <= 2, 180,359),
        ('spacing', 'Control crowd spacing', 'Change the release rate while preparing a route.',
         lambda r,f: 'release-rate-manipulation' in f['concepts'] and len(f['skills']) <= 2,180,359),
        ('spacing-coordination', 'Space and coordinate', 'Combine release-rate changes with concurrent work.',
         lambda r,f: {'release-rate-manipulation','multiple-worker-coordination'} <= f['concepts'],180,359),
        ('sequence-coordination', 'Sequence and coordinate', 'Change a worker’s job while managing another working region.',
         lambda r,f: bool(f['pairs']) and 'multiple-worker-coordination' in f['concepts'] and len(f['skills']) <= 3,180,359),
        ('sequence-spacing', 'Sequence and space', 'Change a worker’s job and control the flow of followers.',
         lambda r,f: bool(f['pairs']) and 'release-rate-manipulation' in f['concepts'] and len(f['skills']) <= 3,180,359),
        ('return-to-skill', 'Return to an earlier skill', 'Reuse a worker by returning to an earlier job after a different assignment.',
         lambda r,f: any(any(c[i] == c[i+2] != c[i+1] for i in range(len(c)-2)) for c in f['chains']) and len(f['skills']) == 2,180,359),
        ('contain-route', 'Contain and prepare', 'Use a blocker while two terrain-changing skills prepare the route.',
         lambda r,f: 'blocker' in f['skills'] and len(f['skills'] & {'builder','basher','miner','digger'}) == 2 and len(f['skills']) == 3 and len(f['chains']) > 1,180,359),
        ('scout-route', 'Scout and prepare', 'Give a permanent skill to one worker while other workers modify the route.',
         lambda r,f: bool(f['skills'] & {'climber','floater'}) and len(f['skills']) == 3 and len(f['chains']) > 1,180,359),
        ('resource-planning', 'Plan the skill budget', 'Complete a short route with higher measured resource pressure.',
         lambda r,f: len(f['skills']) in (2,3) and r['profile']['components']['constraintPressure'] >= 600,300,359),
        ('long-plan', 'Plan four skills', 'Organise a route using four familiar skills.',
         lambda r,f: len(f['skills']) == 4 and bool(f['pairs']),360,599),
        ('three-regions', 'Coordinate a busier route', 'Manage a route with higher measured coordination demands.',
         lambda r,f: r['profile']['components']['concurrencyBurden'] >= 300 and 'multiple-worker-coordination' in f['concepts'],360,599),
        ('tight-budget', 'Budget a longer route', 'Combine four skills under high measured resource pressure.',
         lambda r,f: len(f['skills']) >= 4 and r['profile']['components']['constraintPressure'] >= 800,360,599),
        ('precision-spacing', 'Time the crowd', 'Combine timing-sensitive assignments with release-rate control.',
         lambda r,f: r['profile']['components']['executionPrecision'] >= 350 and 'release-rate-manipulation' in f['concepts'],360,599),
        ('long-sequence', 'Chain a longer plan', 'Manage several changes of job on one worker.',
         lambda r,f: any(len(c) >= 6 for c in f['chains']) and len(f['skills']) >= 3,360,599),
        ('integrated-plan', 'Bring the plan together', 'Integrate five skills, worker coordination and crowd spacing.',
         lambda r,f: len(f['skills']) >= 5 and {'multiple-worker-coordination','release-rate-manipulation'} <= f['concepts'],450,599),
        ('sequence-economy', 'Sequence on a budget', 'Combine a long single-worker sequence with a restricted skill budget.',
         lambda r,f: any(len(c) >= 5 for c in f['chains']) and r['profile']['components']['constraintPressure'] >= 800,420,499),
        ('timing-coordination', 'Time two work areas', 'Combine measured timing pressure with concurrent work.',
         lambda r,f: r['profile']['components']['executionPrecision'] >= 350 and 'multiple-worker-coordination' in f['concepts'],450,549),
        ('spacing-long-plan', 'Space a longer plan', 'Control crowd spacing through a route that uses five skills.',
         lambda r,f: len(f['skills']) == 5 and 'release-rate-manipulation' in f['concepts'],470,549),
        ('economy-coordination', 'Share scarce skills', 'Combine a high resource pressure with work across several regions.',
         lambda r,f: r['profile']['components']['constraintPressure'] >= 800 and r['profile']['components']['concurrencyBurden'] >= 300,510,599),
        ('sequence-five-skills', 'Plan five linked jobs', 'Use five distinct skills in one worker’s sequence.',
         lambda r,f: any(len(set(c)) >= 5 for c in f['chains']),550,649),
        ('precision-economy', 'Precision on a budget', 'Combine substantial timing and resource pressure.',
         lambda r,f: r['profile']['components']['executionPrecision'] >= 600 and r['profile']['components']['constraintPressure'] >= 800,630,719),
        ('growing-coordination', 'Coordinate a larger plan', 'Bridge moderate coordination and expert concurrency with a busier familiar-skill route.',
         lambda r,f: 600 <= r['profile']['components']['concurrencyBurden'] <= 640,500,599),
        ('expert-scout', 'Expert: scout and construct', 'Carry permanent skills through a complex construction sequence.',
         lambda r,f: any({'climber','floater','builder'} <= set(c) and len(c) >= 5 for c in f['chains']),640,679),
        ('expert-sequencing', 'Expert: linked work areas', 'Combine substantial coordination with long worker sequences.',
         lambda r,f: r['profile']['components']['concurrencyBurden'] >= 400 and any(len(c) >= 7 for c in f['chains']),725,755),
        ('expert-integration', 'Expert: combine demands', 'Combine long worker sequences, crowd spacing and concurrent work.',
         lambda r,f: any(len(c) >= 8 for c in f['chains']) and {'multiple-worker-coordination','release-rate-manipulation'} <= f['concepts'],690,759),
        ('expert-budget', 'Expert: skill economy', 'Combine a complex multi-skill route with high resource pressure.',
         lambda r,f: len(f['skills']) >= 5 and r['profile']['components']['constraintPressure'] >= 900,600,1000),
        ('expert-coordination', 'Expert: coordination', 'Apply the learned techniques across highly concurrent work.',
         lambda r,f: r['profile']['components']['concurrencyBurden'] >= 700,600,1000),
        ('expert-precision', 'Expert: precision', 'Apply familiar skills with demanding assignment timing.',
         lambda r,f: r['profile']['components']['executionPrecision'] >= 650,600,750),
    ]
    for objective,lesson,purpose,predicate,lower,upper in strategies:
        choose(objective,lesson,purpose,predicate,lower,upper)
    # Grow applications of skills, not more introductions. An application is
    # distinct only when the observed worker roles or skill transitions differ.
    # No title, pack, score bucket or worker count makes a new application.
    targets = [('Intermediate', 160, 0, 359.999),
               ('Difficult', 90, 360, 599.999), ('Expert', 34, 600, 750)]
    for stage, target, lower, upper in targets:
        def in_stage(row):
            return lower <= demand(row) <= upper
        current = [r for r in pool if key(r) in chosen and in_stage(r)
                   and not chosen[key(r)]['objective'].startswith('introduce:')]
        while len(current) < target:
            options = [r for r in pool if key(r) in evidence and key(r) not in chosen
                       and in_stage(r) and len(evidence[key(r)]['skills']) >= 2
                       and application_signature(evidence[key(r)]) not in used_signatures]
            if not options:
                break
            # Spread applications across demand bands. In comparable windows,
            # choose official puzzles before library alternatives.
            points = sorted([max(lower, 90), upper] + [demand(r) for r in current])
            available_bands = sorted({int(demand(r)/35) for r in options})
            def band_priority(band):
                count = sum(int(demand(r)/35) == band for r in current)
                distance = min(abs(band*35+17.5-p) for p in points)
                return (count, -distance, band)
            band = min(available_bands, key=band_priority)
            nearby = [r for r in options if int(demand(r)/35) == band]
            row = min(nearby, key=lambda r: (not r.get('official', False), demand(r), key(r)))
            f = evidence[key(row)]
            signature = application_signature(f)
            objective = 'apply:' + hashlib.sha256(signature.encode()).hexdigest()[:20]
            chains = sorted({tuple(c) for c in f['chains'] if len(c) > 1}, key=lambda c: (len(c), c))
            roles = sorted({tuple(sorted(set(c))) for c in f['chains']})
            extras = sorted(f['concepts'] - BASIC)
            purpose = 'Worker roles: ' + '; '.join(' + '.join(c) for c in roles) + '.'
            if f['pairs']:
                purpose += ' Job changes: ' + '; '.join(a+' → '+b for a,b in sorted(f['pairs'])) + '.'
            if f['triples']:
                purpose += ' Three-step plans: ' + '; '.join(' → '.join(c) for c in sorted(f['triples'])) + '.'
            if extras:
                purpose += ' Also practise ' + ', '.join(extras) + '.'
            focus = ('Link: ' + ' + '.join(s.capitalize() for s in chains[0][:3])) if chains else ('Share: ' + ' + '.join(s.capitalize() for s in sorted(f['skills'])[:3]))
            chosen[key(row)] = {'identity': row['entry']['identity'], 'objective': objective,
                'lesson': focus, 'purpose': purpose,
                'evidence': 'winning replay assignments and measured profile',
                'level': row['entry']['levelNameSnapshot'], 'intrinsicDemand': demand(row),
                'sourceRank': row['profile'].get('sourceRank'), 'beginnerRank': beginner_rank(row),
                'startingReleaseRate': row.get('startingReleaseRate'),
                'rescueRequirementRatio': row.get('rescueRequirementRatio'),
                'skillAssignmentCount': row.get('skillAssignmentCount'),
                'hasNarrowTiming': bool(row['profile'].get('criticalActions')),
                'requiresFullRescue': requires_full_rescue(row, replays.get(row['profile']['key']['replayRevision'])
                                                           or replays.get(row['initialHash'], {}))}
            used_signatures.add(signature)
            current.append(row)
    lessons = list(chosen.values())
    for lesson in lessons:
        lesson['applicationSignature'] = application_signature(evidence[json.dumps(lesson['identity'], sort_keys=True)])
    assert len({l['objective'] for l in lessons}) == len(lessons)
    return {'version':'curriculum-5', 'targetSize':292, 'poolSize':len(pool), 'lessons':lessons,
            'selectionPolicy':'Official first within comparable 35-point demand bands; distinct observed applications; editorial exclusions, source-only replay commands and known Lemmini source packs excluded from the Classic path; replay events must end by the winning tick.',
            'unavailableOptionalObjectives':missing,
            'limits':'Objectives describe observed routes. Starting release rate 99, source rescue quotas of at least 95% of the population, narrow measured timing windows, levels without verified source settings, and routes with at least 12 skill assignments start at Difficult. Opening introductions prefer a low-demand Fun, Easy or Tame candidate. Full-rescue witnesses are excluded from introductions. Novice readability and technique necessity require playtesting.'}


if __name__ == '__main__':
    pool = json.loads((ROOT/'.build/learning-journey/pool.json').read_text())
    replays = json.loads((OUT/'candidate-solutions.json').read_text())
    replays.update(json.loads((ROOT/'Resources/Hints/solutions.json').read_text()))
    result = select(pool,replays)
    (OUT/'curriculum.json').write_text(json.dumps(result,indent=2,sort_keys=True)+'\n')
    print(f"Selected {len(result['lessons'])} distinct teaching objectives from {result['poolSize']} candidates.")
