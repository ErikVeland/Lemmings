"""Collect validated native evidence and describe the generated learning path."""
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / 'Artifacts/LearningJourney'
BASE = ROOT / 'Artifacts/ClassicProgression/audit.json'

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
    rows = {key(r): r for r in read(BASE)}
    rows.update({key(r): r for r in read(OUT / 'fan-evidence.json')})
    manifest = read(ROOT / 'Resources/Progression/learning.json')
    lessons = manifest['lessons']
    selected = [rows[key(l)] for l in lessons]
    curriculum = read(OUT / 'curriculum.json')
    goals = {json.dumps(g['identity'],sort_keys=True):g for g in curriculum['lessons']}
    assert set(goals) == {key(l) for l in lessons}
    assert len({g['objective'] for g in goals.values()}) == len(lessons)
    introductions = [g for g in goals.values() if g['objective'].startswith('introduce:')]
    assert len(introductions) == 8
    assert all(goals[key(l)]['objective'].startswith('introduce:') for l in lessons[:8])
    assert not any(goals[key(l)]['objective'].startswith('introduce:') for l in lessons[8:])
    scores = [l['score'] for l in lessons]
    demands = [l['demand'] for l in lessons]
    stages = ['Fun','Intermediate','Difficult','Expert']
    assert all(int(a/35) <= int(b/35) for a,b in zip(demands,demands[1:]))
    assert all(stages.index(a['stage']) <= stages.index(b['stage']) for a,b in zip(lessons,lessons[1:]))
    assert len({r['initialHash'] for r in selected}) == len(selected)
    assert not any(any(token in (r['entry']['packNameSnapshot']+' '+r['entry']['identity']['levelID']).lower()
                       for token in ('versus','2p','two player')) for r in selected)
    assert all(l['score'] == r['profile']['overallScore'] for l,r in zip(lessons,selected))
    fan = [r for r in selected if not r['official']]
    scenarios = read(OUT/'scenarios.json')
    signatures = [scenarios['fan'][r['entry']['identity']['packID']+'\0'+r['entry']['identity']['levelID']] for r in fan]
    assert len(set(signatures)) == len(signatures)
    assert not set(signatures).intersection(scenarios['official'])
    witnesses = read(OUT/'candidate-solutions.json')
    solutions = {r['initialHash']:witnesses[r['profile']['key']['replayRevision']] for r in fan}
    assert all(replay['expected']['didWin'] for replay in solutions.values())
    # Removing a recommendation must not remove a library level's existing hints.
    library_solutions = read(ROOT/'Resources/Progression/solutions.json')
    library_solutions.update(solutions)
    write(ROOT/'Resources/Progression/solutions.json',library_solutions)
    summary = {'version':manifest['version'], 'candidatePool':curriculum['poolSize'],
        'levels':len(lessons), 'official':sum(r['official'] for r in selected), 'fan':len(fan),
        'fanPacks':len({r['entry']['identity']['packID'] for r in fan}),
        'stages':{stage:sum(l['stage']==stage for l in lessons) for stage in stages},
        'skillIntroductions':len(introductions), 'duplicateObjectives':0,
        'largestDemandStep':max(b-a for a,b in zip(demands,demands[1:])),
        'largestScoreStep':max(b-a for a,b in zip(scores,scores[1:])),
        'preparationGaps':sum(bool(l['preparationGaps']) for l in lessons),
        'supportTransitions':sum(l['needsSupport'] for l in lessons),
        'ohNoLevels':sum(r['entry']['packNameSnapshot']=='Oh No! More Lemmings' for r in selected)}
    assert summary['stages']['Intermediate'] > max(v for k,v in summary['stages'].items() if k != 'Intermediate')
    write(OUT/'summary.json',summary)
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
        'The first eight lessons introduce the eight basic skills once each. Later lessons need a distinct objective: change one worker’s job, split jobs between workers, plan a three-skill sequence, control spacing, coordinate work, or combine planning, timing and resource demands. A repeated tutorial is not a bridge.','',
        'One level represents each objective. Repeated assignments of the same skill collapse when detecting worker sequences. Three-skill sequences use one representative per skill set rather than every permutation. Passive levels and unassigned extra practice are omitted.','',
        'The Fun stage contains only the eight introductions. Simple combinations begin Intermediate even when their numerical demand is low. Difficult and Expert retain the existing demand boundaries. Intermediate lessons are the majority of the path. Candidates are selected for their teaching role before the existing demand model orders them. No score is altered to make the chart look smoother.','',
        '## Evidence and limits','',
        'Objectives are inferred from winning replay commands and measured profiles. They describe an observed route, not a proved necessary technique or a human difficulty rating. Geometry-specific lessons such as steel recognition and safe digging depth are not reliably detected by the current evidence. Those require authored review before claiming complete teaching coverage.','',
        'The selector retains multiplayer and port-duplicate exclusions. The generator checks each selected fan witness against its profile digest and source identity. Basic introductions, unique objectives, source coverage of the selected list and reversed-input ordering are checked.','',
        f"Stages: {summary['stages']}. Basic introductions: 8. Duplicate objectives: 0. Largest demand increase: {summary['largestDemandStep']:.2f}/1000. Preparation gaps: {summary['preparationGaps']}.",'',
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
    posts = pathlib.Path.home()/'Documents/Ultimate Lemmings/Posts'
    posts.mkdir(parents=True,exist_ok=True)
    bbcode = ['[b]Oh My! All Lemmings![/b]','',
        f"A selective learning journey of {len(lessons)} levels. The complete library and original campaigns remain available separately.",'',
        'The first eight lessons introduce each basic skill once. Most of the following teaching work is in combinations, sequences and intermediate strategy. Every selected level has a distinct objective. Two-player levels and repeated port puzzles are excluded.','',
        'This is a replay-informed candidate curriculum. The objectives and difficulty curve still need novice playtesting. It is not a certified wall-free path.','',
        '[b]Full order[/b]','']
    for stage in stages:
        group=[(i,l) for i,l in enumerate(lessons,1) if l['stage']==stage]
        bbcode += [f"[b]{stage} ({len(group)} lessons)[/b]",'[list]']
        for i,l in group:
            bbcode.append(f"[*][b]{i}. {l['entry']['levelNameSnapshot']}[/b] — {l['entry']['packNameSnapshot']}. [i]{goals[key(l)]['purpose']}[/i]")
        bbcode += ['[/list]','']
    (posts/'Oh My! All Lemmings! - BBCode.txt').write_text('\n'.join(bbcode)+'\n')
    print(json.dumps(summary,indent=2))
else:
    raise SystemExit('Usage: learning_report.py collect OUTPUT... | report')
