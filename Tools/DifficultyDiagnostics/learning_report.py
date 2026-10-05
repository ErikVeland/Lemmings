"""Collect validated native evidence and describe the generated learning path."""
import json
import os
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / 'Artifacts/LearningJourney'
BASE = pathlib.Path(os.environ.get('LEARNING_AUDIT_PATH', ROOT / 'Artifacts/ClassicProgression/audit.json'))

def read(path):
    return json.loads(path.read_text())

def key(row):
    return json.dumps(row['entry']['identity'], sort_keys=True)

def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + '\n')

if sys.argv[1] == 'collect':
    base = {key(r): r for r in read(BASE)}
    bundled_fan_packs = {'fan:lldb-' + str(pack['id'])
                         for pack in read(ROOT / 'Content/LevelPacks/packs.json')}
    best = dict(base)
    if (OUT / 'fan-evidence.json').exists():
        for row in read(OUT / 'fan-evidence.json'):
            if not row['official'] and row['entry']['identity']['packID'] not in bundled_fan_packs:
                continue
            original = base[key(row)]
            assert row['initialHash'] == original['initialHash']
            assert row['entry']['sourceRevision'] == original['entry']['sourceRevision']
            if row['profile']['confidence'] != 'low':
                best[key(row)] = row
    solutions = read(OUT / 'candidate-solutions.json')
    scenarios = read(OUT / 'scenarios.json') if (OUT / 'scenarios.json').exists() else {'official':[], 'fan':{}}
    for folder in map(pathlib.Path, sys.argv[2:]):
        if (folder / 'fan-scenarios.json').exists():
            scenarios['fan'].update(read(folder / 'fan-scenarios.json'))
            scenarios['official'] = sorted(set(scenarios['official']) | set(read(folder / 'official-scenarios.json')))
        folder_solutions = read(folder / 'solutions.json')
        solutions.update(folder_solutions)
        for row in read(folder / 'audit.json'):
            if not row['official'] and row['entry']['identity']['packID'] not in bundled_fan_packs:
                continue
            original = base[key(row)]
            if row['official'] or row['profile']['confidence'] == 'low':
                continue
            assert row['initialHash'] == original['initialHash']
            assert row['entry']['sourceRevision'] == original['entry']['sourceRevision']
            previous = best[key(row)]
            if previous['profile']['confidence'] == 'low' or row['profile']['overallScore'] < previous['profile']['overallScore']:
                best[key(row)] = row
                replay_revision = row['profile']['key']['replayRevision']
                replay = (folder_solutions.get(replay_revision) or solutions.get(replay_revision)
                          or folder_solutions.get(row['initialHash']))
                assert replay and replay['initialStateHash'] == row['initialHash'] and replay['expected']['didWin']
                if replay['rank'] != row['entry']['identity']['packID'] or replay['number'] != row['entry']['levelNumberSnapshot']:
                    replay = dict(replay, rank=row['entry']['identity']['packID'],
                                  number=row['entry']['levelNumberSnapshot'],
                                  title=row['entry']['levelNameSnapshot'] if replay['title'] else '')
                solutions[row['profile']['key']['replayRevision']] = replay
    changed = [r for k, r in sorted(best.items()) if r != base[k]]
    write(OUT / 'fan-evidence.json', changed)
    write(OUT / 'candidate-solutions.json', solutions)
    if scenarios['official']: write(OUT / 'scenarios.json', scenarios)
    print(f'Collected {len(changed)} upgraded fan profiles and {len(solutions)} replay references.')
elif sys.argv[1] == 'report':
    current = read(ROOT / 'Resources/Progression/learning.json')
    if current.get('placementPolicy') == 'redux-community-1':
        from human_journey import report
        report(current, read(OUT / 'curriculum.json'), read(OUT / 'human-review-queue.json'),
               read(OUT / 'transitions.json'))
        print(f"Reported {len(current['lessons'])} community-anchored lessons.")
        raise SystemExit(0)
    rows = {key(r): r for r in read(BASE)}
    for row in read(OUT / 'fan-evidence.json'):
        original = rows.get(key(row), {})
        for field in ('startingReleaseRate', 'rescueRequirementRatio'):
            if row.get(field) is None:
                row[field] = original.get(field)
        rows[key(row)] = row
    manifest = read(ROOT / 'Resources/Progression/learning.json')
    lessons = manifest['lessons']
    selected = [rows[key(l)] for l in lessons]
    curriculum = read(OUT / 'curriculum.json')
    goals = {json.dumps(g['identity'],sort_keys=True):g for g in curriculum['lessons']}
    assert set(goals) == {key(l) for l in lessons}
    assert len({g['objective'] for g in goals.values()}) == len(lessons)
    assert len({g['applicationSignature'] for g in goals.values()}) == len(lessons)
    introductions = [g for g in goals.values() if g['objective'].startswith('introduce:')]
    assert len(introductions) <= 8
    scores = [l['score'] for l in lessons]
    demands = [l['demand'] for l in lessons]
    stages = ['Fun','Intermediate','Difficult','Expert']
    assert all(int(a/35) <= int(b/35) for a,b in zip(demands,demands[1:]))
    assert all(stages.index(a['stage']) <= stages.index(b['stage']) for a,b in zip(lessons,lessons[1:]))
    assert len({r['initialHash'] for r in selected}) == len(selected)
    assert not any(any(token in (r['entry']['packNameSnapshot']+' '+r['entry']['identity']['levelID']).lower()
                       for token in ('versus','2p','two player')) for r in selected)
    assert all(l['score'] == r['profile']['overallScore'] for l,r in zip(lessons,selected))
    assert all(l['stage'] in {'Difficult', 'Expert'} for l,r in zip(lessons,selected)
               if r.get('startingReleaseRate') is None
               or r.get('rescueRequirementRatio') is None
               or r.get('startingReleaseRate') == 99
               or bool(r['profile'].get('criticalActions'))
               or (r.get('rescueRequirementRatio') or 0) >= .95)
    assert all(l['stage'] in {'Difficult', 'Expert'} for l in lessons
               if goals[key(l)].get('skillAssignmentCount', 0) >= 12)
    fan = [r for r in selected if not r['official']]
    scenarios = read(OUT/'scenarios.json')
    signatures = [scenarios['fan'][r['entry']['identity']['packID']+'\0'+r['entry']['identity']['levelID']] for r in fan]
    assert len(set(signatures)) == len(signatures)
    assert not set(signatures).intersection(scenarios['official'])
    witnesses = read(OUT/'candidate-solutions.json')
    solutions = {r['initialHash']:witnesses[r['profile']['key']['replayRevision']] for r in fan}
    assert all(replay['expected']['didWin'] for replay in solutions.values())
    assert not any(replay.get('sourceRules') for replay in solutions.values())
    full_rescue_count = 0
    for row in selected:
        expected = witnesses.get(row['profile']['key']['replayRevision'], {}).get('expected', {})
        if expected.get('required') is not None and expected.get('required') == expected.get('released'):
            full_rescue_count += 1
    # Removing a recommendation must not remove a library level's existing hints.
    library_solutions = read(ROOT/'Resources/Progression/solutions.json')
    library_solutions.update(solutions)
    write(ROOT/'Resources/Progression/solutions.json',library_solutions)
    summary = {'version':manifest['version'], 'candidatePool':curriculum['poolSize'],
        'targetSize':curriculum['targetSize'], 'levels':len(lessons), 'official':sum(r['official'] for r in selected), 'fan':len(fan),
        'fanPacks':len({r['entry']['identity']['packID'] for r in fan}),
        'stages':{stage:sum(l['stage']==stage for l in lessons) for stage in stages},
        'startingRate99Levels':sum(r.get('startingReleaseRate') == 99 for r in selected),
        'highRescueQuotaLevels':sum((r.get('rescueRequirementRatio') or 0) >= .95 for r in selected),
        'unverifiedSourceSettings':sum(r.get('startingReleaseRate') is None or r.get('rescueRequirementRatio') is None for r in selected),
        'narrowTimingLevels':sum(bool(r['profile'].get('criticalActions')) for r in selected),
        'highAssignmentLoadLevels':sum(g.get('skillAssignmentCount', 0) >= 12 for g in goals.values()),
        'skillIntroductions':len(introductions), 'duplicateObjectives':0,
        'fullRescueRequirements':full_rescue_count,
        'largestDemandStep':max(b-a for a,b in zip(demands,demands[1:])),
        'largestScoreStep':max(b-a for a,b in zip(scores,scores[1:])),
        'preparationGaps':sum(bool(l['preparationGaps']) for l in lessons),
        'supportTransitions':sum(l['needsSupport'] for l in lessons),
        'ohNoLevels':sum(r['entry']['packNameSnapshot']=='Oh No! More Lemmings' for r in selected)}
    write(OUT/'summary.json',summary)
    expected = {'Lemmings':120, 'Oh No! More Lemmings':100, 'Xmas Lemmings 1991':4,
                'Xmas Lemmings 1992':4, 'Holiday Lemmings 1993':32, 'Holiday Lemmings 1994':32}
    corpus = []
    for pack, count in expected.items():
        source = [r for r in read(BASE) if r['official'] and r['entry']['packNameSnapshot'] == pack]
        assert len(source) == count, (pack, len(source), count)
        corpus.append({'pack':pack, 'corpusLevels':len(source),
                       'confirmedScored':sum(r['profile']['confidence'] != 'low' for r in source),
                       'selected':sum(l['entry']['packNameSnapshot'] == pack for l in lessons)})
    write(OUT/'corpus-coverage.json', {'sizeReference':292, 'campaigns':corpus,
        'scope':'Classic mechanics only, per user direction. L2/L3 evidence remains outside this journey.',
        'eligiblePool':curriculum['poolSize']})
    exposure = {k:0 for k in selected[0]['profile']['components']}
    transitions = []
    for i,(lesson,row) in enumerate(zip(lessons,selected)):
        c = row['profile']['components']
        prior = selected[i-1]['profile']['components'] if i else c
        reasons = []
        jump = demands[i]-demands[i-1] if i else 0
        highs = {k:max(0,c[k]-exposure[k]) for k in c}
        if jump > 65: reasons.append('Curriculum demand rises by '+str(round(jump,1)))
        if max(highs.values()) > 150: reasons.append('New component high: '+', '.join(k for k,v in highs.items() if v>150))
        if lesson['preparationGaps']: reasons.append('Preparation: '+', '.join(lesson['preparationGaps']))
        if len(lesson['introduced']) > 1: reasons.append('Several new concepts')
        transitions.append({'step':i+1,'level':lesson['entry']['levelNameSnapshot'],'stage':lesson['stage'],
            'objective':goals[key(lesson)]['objective'], 'demand':lesson['demand'], 'rawScore':lesson['score'],
            'componentChanges':{k:c[k]-prior[k] for k in c}, 'newComponentHighs':highs,
            'preparationGaps':lesson['preparationGaps'],'needsSupport':lesson['needsSupport'],'reasons':reasons})
        exposure = {k:max(exposure[k],c[k]) for k in c}
    write(OUT/'transitions.json',transitions)
    write(OUT/'oh-no-placements.json',[{'step':i+1,'level':l['entry']['levelNameSnapshot'],'objective':goals[key(l)]['objective']}
          for i,l in enumerate(lessons) if l['entry']['packNameSnapshot']=='Oh No! More Lemmings'])
    lines = ['# Oh My! All Lemmings!','',
        f"{len(lessons)} selected lessons from {curriculum['poolSize']} validated, deduplicated single-player candidates. {summary['official']} official levels and {len(fan)} library levels.",'',
        '## Selection before ordering','',
        'The recommended journey is a selective curriculum. The complete library and original campaigns remain available separately. It has no requirement to include every official level or every validated fan level.','',
        'Skill introductions no longer force their way into the opening lessons. The order uses source rank and winning replay evidence. Fun, Easy and Tame levels can start the path only when their measured demand and route workload are low. A low-demand witness from another rank can introduce a skill in Intermediate when no beginner-ranked witness qualifies. Levels with a Tricky or higher rank, unknown rank, a full-rescue requirement, or at least 12 skill assignments in the winning route have a higher placement floor. The model still needs novice playtesting.','',
        'The target is roughly 292 levels: the combined size of Classic, Oh No! and the 72 seasonal levels. The path uses Classic mechanics only. Confirmed L2/L3 levels remain outside this journey. All six source campaigns are checked in corpus-coverage.json.','',
        'Packs identified as Lemmini are excluded from this Classic learning path. Two levels in those packs have native Classic wins, but source-engine behaviour is unverified. See `../DifficultyEvaluation/source-engine-families.json` and its validation notes.','',
        'Official levels take priority within comparable 35-point demand bands. Library levels supply missing applications. An application signature records the skill set, job changes, three-step sequences and worker roles. Identical signatures are excluded even across different titles. Repeated assignments, worker counts and score buckets do not create new lessons. These are evidence-based distinctions that still need human review.', '',
        'The Fun stage contains beginner-ranked levels below the demand threshold and with fewer than 12 skill assignments in the winning route. Unknown ranks and Tricky or higher ranks move to later stages. A source level with starting release rate 99, a rescue quota of at least 95%, a narrow measured timing window, unverified source settings, or at least 12 skill assignments starts at Difficult. A winning route that must save every released lemming also starts at Difficult. Position sensitivity is not measured.','',
        '## Evidence and limits','',
        'Objectives are inferred from winning replay commands and measured profiles. They describe an observed route, not a proved necessary technique or a human difficulty rating. Geometry-specific lessons such as steel recognition and safe digging depth are not reliably detected by the current evidence. Those require authored review before claiming complete teaching coverage.','',
        'The selector retains multiplayer and port-duplicate exclusions. The generator checks each selected fan witness against its profile digest and source identity. Basic introductions, unique objectives, source coverage of the selected list and reversed-input ordering are checked.','',
        f"Stages: {summary['stages']}. Source levels at release rate 99: {summary['startingRate99Levels']}. Rescue quotas at or above 95%: {summary['highRescueQuotaLevels']}. Narrow timing levels: {summary['narrowTimingLevels']}. High assignment-load levels: {summary['highAssignmentLoadLevels']}. Levels with unverified source settings: {summary['unverifiedSourceSettings']}. Skill introductions: {summary['skillIntroductions']}. Full-rescue witness routes: {summary['fullRescueRequirements']}. Duplicate objectives: 0. Largest demand increase: {summary['largestDemandStep']:.2f}/1000. Preparation gaps: {summary['preparationGaps']}.",'',
        '## Transitions for playtesting','',
        *[f"- {t['step']}. {t['level']}: {'; '.join(t['reasons'])}." for t in transitions if t['needsSupport']], '',
        'A support flag remains a review request. An absent flag is not proof that a novice will find a solution obvious.','',
        '## Reproduce','',
        'Run `zsh Scripts/generate-learning-journey.sh`, then `python3 Tools/DifficultyDiagnostics/learning_report.py report`. The generator exports the eligible pool, selects distinct objectives with `curate_learning.py`, and builds the ordered journey. `curriculum.json` records the reason for every selection.','',
        'Solved and parked levels stay saved by identity. A new curriculum version rebuilds the remaining order. Removing a level from this recommendation does not remove it from the library.','',
        '## Full order','', '| Step | Stage | Level | Source | Lesson purpose |','| ---: | --- | --- | --- | --- |']
    for i,l in enumerate(lessons,1):
        values=[str(i),l['stage'],l['entry']['levelNameSnapshot'],l['entry']['packNameSnapshot'],goals[key(l)]['purpose']]
        lines.append('| '+' | '.join(v.replace('|',r'\|') for v in values)+' |')
    (OUT/'README.md').write_text('\n'.join(lines)+'\n')
    # Forum drafts belong outside the repository.
    posts = None if os.environ.get('LEMMINGS_SKIP_POST_EXPORT') == '1' else pathlib.Path.home()/'Documents/Ultimate Lemmings/Posts'
    if posts is not None: posts.mkdir(parents=True,exist_ok=True)
    bbcode = ['[b]Oh My! All Lemmings![/b]','',
        f"A selective learning journey of {len(lessons)} levels. The complete library and original campaigns remain available separately.",'',
        'Low-demand Fun, Easy and Tame levels form the opening. A skill without a suitable beginner-ranked witness can be introduced in Intermediate using a low-demand verified route.','',
        'Official levels take priority where they fit the lesson and difficulty. The corpus includes all Classic, Oh No! and seasonal levels. This journey uses Classic mechanics only.', '',
        'This is a replay-informed candidate curriculum. The objectives and difficulty curve still need novice playtesting. It is not a certified wall-free path.','',
        '[b]Full order[/b]','']
    for stage in stages:
        group=[(i,l) for i,l in enumerate(lessons,1) if l['stage']==stage]
        bbcode += [f"[b]{stage} ({len(group)} lessons)[/b]",'[list]']
        for i,l in group:
            bbcode.append(f"[*][b]{i}. {l['entry']['levelNameSnapshot']}[/b] — {l['entry']['packNameSnapshot']}. [i]{goals[key(l)]['purpose']}[/i]")
        bbcode += ['[/list]','']
    if posts is not None: (posts/'Oh My! All Lemmings! - BBCode.txt').write_text('\n'.join(bbcode)+'\n')
    print(json.dumps(summary,indent=2))
else:
    raise SystemExit('Usage: learning_report.py collect OUTPUT... | report')
