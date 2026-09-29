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
    lessons = read(ROOT / 'Resources/Progression/learning.json')['lessons']
    selected = [rows[key(l)] for l in lessons]
    scores = [l['score'] for l in lessons]
    demands = [l['demand'] for l in lessons]
    stages = ['Fun', 'Intermediate', 'Difficult', 'Expert']
    assert all(int(a/35) <= int(b/35) for a,b in zip(demands, demands[1:]))
    assert all(stages.index(a['stage']) <= stages.index(b['stage']) for a,b in zip(lessons,lessons[1:]))
    assert lessons[0]['concepts']
    official_rows = [r for r in read(BASE) if r['official'] and not any(token in (r['entry']['identity']['levelID'] + ' ' + (r['profile'].get('sourceRank') or '')).lower() for token in ('versus', '2p', 'two player'))]
    def normal_title(row):
        return ''.join(c for c in row['entry']['levelNameSnapshot'].lower() if c.isalnum())
    official_hashes, official_titles = set(), set()
    def official_priority(row):
        return {'Lemmings': 0, 'Oh No! More Lemmings': 1}.get(row['entry']['packNameSnapshot'], 2), row['order']
    for row in sorted(official_rows, key=official_priority):
        pack_title = (row['entry']['packNameSnapshot'], normal_title(row))
        if row['initialHash'] not in official_hashes and pack_title not in official_titles:
            official_hashes.add(row['initialHash'])
            official_titles.add(pack_title)
    assert sum(r['official'] for r in selected) == len(official_hashes)
    assert len({r['initialHash'] for r in selected}) == len(selected)
    assert len({(r['entry']['packNameSnapshot'], normal_title(r)) for r in selected}) == len(selected)
    assert not any(any(token in (r['entry']['packNameSnapshot'] + ' ' + r['entry']['identity']['levelID'] + ' ' + (r['profile'].get('sourceRank') or '')).lower() for token in ('versus', '2p', 'two player')) for r in selected)
    assert all(r['entry']['packNameSnapshot'] not in ('Amiga Fun', 'Amiga Tricky', 'Amiga Taxing', 'Amiga Mayhem') for r in selected if not r['official'])
    assert len({(r['entry']['packNameSnapshot'], normal_title(r)) for r in selected if r['official']}) == len(official_hashes)
    fan = [r for r in selected if not r['official']]
    assert not {normal_title(r) for r in fan}.intersection({normal_title(r) for r in selected if r['official']})
    assert all(r['profile']['confidence'] != 'low' and r['profile']['detectedTechniques'] for r in fan)
    scenarios = read(OUT / 'scenarios.json')
    fan_scenarios = [scenarios['fan'][r['entry']['identity']['packID']+'\0'+r['entry']['identity']['levelID']] for r in fan]
    assert len(set(fan_scenarios)) == len(fan_scenarios)
    assert not set(fan_scenarios).intersection(scenarios['official'])
    assert {r['initialHash'] for r in selected if r['official']} == official_hashes
    assert all(l['score'] == r['profile']['overallScore'] for l,r in zip(lessons,selected))
    all_solutions = read(OUT / 'candidate-solutions.json')
    solutions = {r['initialHash']: all_solutions.get(r['profile']['key']['replayRevision'], all_solutions.get(r['initialHash'])) for r in fan}
    assert all(s['expected']['didWin'] for s in solutions.values())
    write(ROOT / 'Resources/Progression/solutions.json', solutions)
    jumps = [b-a for a,b in zip(scores, scores[1:])]
    ohno = [(i+1,l,r) for i,(l,r) in enumerate(zip(lessons,selected)) if r['official'] and r['entry']['packNameSnapshot'] == 'Oh No! More Lemmings']
    original_ohno = [r for r in read(BASE) if r['official'] and r['entry']['packNameSnapshot'] == 'Oh No! More Lemmings']
    old_ohno_jump = max(b['profile']['overallScore']-a['profile']['overallScore'] for a,b in zip(original_ohno, original_ohno[1:]))
    new_ohno_jump = max(scores[i]-scores[i-1] for i in range(1,len(scores)) if selected[i]['entry']['packNameSnapshot'] == 'Oh No! More Lemmings')
    assert len(ohno) == 100
    summary = {'originalOhNoLargestStep':old_ohno_jump, 'newOhNoLargestIncomingStep':new_ohno_jump, 'levels':len(lessons), 'official':len(official_hashes), 'fan':len(fan),
               'fanPacks':len({r['entry']['identity']['packID'] for r in fan}),
               'largestScoreStep':max(jumps), 'scoreDecreases':sum(j < 0 for j in jumps),
               'largestDemandStep':max(b-a for a,b in zip(demands,demands[1:])),
               'stages':{stage:sum(l['stage']==stage for l in lessons) for stage in stages},
               'preparationGaps':sum(bool(l['preparationGaps']) for l in lessons),
               'supportTransitions':sum(l['needsSupport'] for l in lessons),
               'fanScoreRange':[min(r['profile']['overallScore'] for r in fan),max(r['profile']['overallScore'] for r in fan)],
               'ohNoLevels':len(ohno)}
    write(OUT / 'summary.json', summary)
    exposure = {k:0 for k in selected[0]['profile']['components']}
    transitions = []
    for i,(lesson,row) in enumerate(zip(lessons,selected)):
        components = row['profile']['components']
        prior = selected[i-1]['profile']['components'] if i else components
        transitions.append({'step':i+1, 'level':lesson['entry']['levelNameSnapshot'], 'stage':lesson['stage'],
            'rawScore':lesson['score'], 'intrinsicDemand':lesson['intrinsicDemand'], 'curriculumDemand':lesson['demand'],
            'componentChanges':{k:components[k]-prior[k] for k in components},
            'newComponentHighs':{k:max(0,components[k]-exposure[k]) for k in components},
            'introduced':lesson['introduced'], 'preparationGaps':lesson['preparationGaps'], 'needsSupport':lesson['needsSupport']})
        exposure = {k:max(exposure[k],components[k]) for k in components}
    write(OUT / 'transitions.json', transitions)
    write(OUT / 'oh-no-placements.json', [{'step':i,'level':l['entry']['levelNameSnapshot'],'rank':r['profile'].get('sourceRank'),'score':l['score']} for i,l,r in ohno])
    lines = ['# Oh My! All Lemmings!', '',
        f"{len(lessons)} distinct single-player levels: {summary['official']} official puzzles and {len(fan)} replay-validated library levels from {summary['fanPacks']} packs.", '',
        '## Ordering', '',
        'The path progresses through Fun, Intermediate, Difficult and Expert. A hard timing, coordination or planning demand cannot be cancelled by easy dimensions in a weighted average. Official levels take priority within comparable demand bands. Retail rank and campaign order do not determine placement. All Oh No! levels are interleaved with the rest of the pool.', '',
        f"Stages: {'; '.join(stage + ' ' + str(summary['stages'][stage]) for stage in stages)}. Largest upward curriculum-demand step: {summary['largestDemandStep']:.2f}/1000. Transitions requiring review: {summary['supportTransitions']}; missing basic-skill preparation: {summary['preparationGaps']}.", '',
        '| Stage | Steps | Teaching focus |', '| --- | ---: | --- |',
        *[f"| {stage} | {next(i+1 for i,l in enumerate(lessons) if l['stage']==stage)}–{max(i+1 for i,l in enumerate(lessons) if l['stage']==stage)} | {focus} |" for stage,focus in zip(stages, ['Single skills and simple combinations', 'Skill combinations and crowd management', 'Longer plans and tighter resources', 'Precision, complex plans and coordination']) if summary['stages'][stage]], '',
        'Curriculum demand is the maximum of the unchanged evidence score, 0.85 × technique, precision, concurrency and deduction, 0.70 × solution complexity, 0.50 × constraints, and 90 × additional concepts. A combination also waits for its easiest available isolated skill lessons. These weights and the stage thresholds (180, 360, 600) are editorial estimates, not player-calibrated difficulty measurements.', '',
        'Within each stage, 35-point bands allow spaced practice and small relief steps. Selection favours prepared combinations, avoids consecutive identical technique sets when comparable alternatives exist, and reduces upward component changes. Two-skill combinations require one earlier exposure per basic skill; larger combinations seek two. Exposure means a practice opportunity, not demonstrated mastery. New coordination and crowd-spacing concepts can be introduced through familiar skills.', '',
        f"Raw evidence scores remain unchanged and are reported separately. Their largest upward step is {max(jumps):.2f}, with {summary['scoreDecreases']} decreases. The curriculum demand does not certify every component transition as smooth; all component changes and support flags are retained in transitions.json.", '',
        f'Oh No! has all 100 levels in the shared path. Its original largest raw-score jump was {old_ohno_jump:.2f}; its largest incoming raw-score jump here is {new_ohno_jump:.2f}. This is a diagnostic, not the sequencing objective.', '',
        'The score uses validated solution techniques, solution complexity, timing perturbations, concurrent workers, constraints and a deduction proxy. It is an estimate of human difficulty, not direct measurement of insight. A winning route proves solvability; a low score does not prove that its solution is obvious. Unresolved component jumps stay visible in the report.', '',
        '## Remaining transition reviews', '',
        *[f"- Step {t['step']}, **{t['level']}** ({t['stage']}): new execution-demand high rises by {t['newComponentHighs']['executionPrecision']:.1f}/1000. Check timing forgiveness with a novice before calling this transition smooth." for t in transitions if t['needsSupport']], '',
        '## Fan evidence', '',
        'The full Classic corpus contains 6,374 entries. Additional routes are proposed from matching terrain, similar terrain and bounded reactive skill policies. Each accepted route is replayed against the complete candidate simulation, checked for a winning result, and analysed with timing perturbations. Source fingerprints and initial-state hashes must match. Blank/hands-free fan entries are excluded from bridges. Fan copies of official puzzles are excluded using a gameplay signature that ignores names and viewport positions, includes resources, objects and rendered masks, and is independent of the release variant. Duplicate official and fan initial states are excluded. Competitive two-player levels are excluded. Unsolved candidates retain low confidence and are not passed off as measured bridges.', '',
        'The bounded search is not a complete solver. Failure to find a route does not imply that a level is impossible. The chosen fan count is an outcome of evidence and deduplication, not a quota.', '',
        '## Validation', '',
        'The generator checks reversed-input determinism, distinct single-player official coverage and the exact replay digest for every selected fan level. See validation.json for the current test and build results. Human insight, stage calibration and novice frustration still need playtesting.', '',
        '## Saved progress', '',
        'Solved and parked levels remain saved by identity. Opening the main path rebuilds the remaining order when an older curriculum version is active. The old run remains in saved runs. Try later remains free and grants no win. It is a recovery action, not evidence that a difficulty gap is filled.', '',
        '## Reproduce', '',
        '1. Run `zsh Scripts/expand-learning-evidence.sh` against the built app resources. This snapshots and compiles the simulation sources, then searches and validates fan routes offline.',
        '2. Run `python3 Tools/DifficultyDiagnostics/learning_report.py collect .build/learning-evidence/output`.',
        '3. Run `zsh Scripts/generate-learning-journey.sh`.',
        '4. Run `python3 Tools/DifficultyDiagnostics/learning_report.py report`.', '',
        'The committed supplemental profiles and winning fan replays allow the playlist to be regenerated without rerunning the search. The generation tool checks full official coverage and reversed-input determinism.', '',
        '## Full order', '', '| Step | Stage | Level | Pack / rank | Raw score | Demand | Support |', '| ---: | --- | --- | --- | ---: | ---: | --- |']
    for i,(lesson,row) in enumerate(zip(lessons,selected),1):
        values=[str(i),lesson['stage'],lesson['entry']['levelNameSnapshot'],lesson['entry']['packNameSnapshot']+' / '+(row['profile'].get('sourceRank') or 'Fan'),f"{lesson['score']:.2f}",f"{lesson['demand']:.2f}",'Review' if lesson['needsSupport'] else '']
        lines.append('| '+' | '.join(v.replace('|','\\|') for v in values)+' |')
    (OUT / 'README.md').write_text('\n'.join(lines)+'\n')
    bbcode = [
        '[b]Oh My! All Lemmings![/b]',
        '[i]A proposed learning path through single-player Classic Lemmings, from Fun to Expert[/i]', '',
        f"The path has {len(lessons)} distinct puzzles: {summary['official']} official levels and {len(fan)} selected library levels from {summary['fanPacks']} packs. All 100 Oh No! More Lemmings levels are included.", '',
        'Official levels take priority when puzzles have comparable demands. Alternate ports of the original Classic campaign, repeated puzzles and two-player levels are excluded.', '',
        'The order uses measured solution, timing, coordination and resource demands. It introduces skills before combining them and spaces repeated practice. The stages are editorial estimates. Novice playtesting is still needed.', '',
        '[b]Full order[/b]', ''
    ]
    for stage in stages:
        stage_lessons = [(i, lesson, row) for i, (lesson, row) in enumerate(zip(lessons, selected), 1) if lesson['stage'] == stage]
        if not stage_lessons:
            continue
        bbcode.extend([f"[b]{stage} — levels {stage_lessons[0][0]}–{stage_lessons[-1][0]} ({len(stage_lessons)} levels)[/b]", '[list]'])
        for i, lesson, row in stage_lessons:
            origin = 'official' if row['official'] else 'library'
            bbcode.append(f"[*][b]{i}. {lesson['entry']['levelNameSnapshot']}[/b] — {lesson['entry']['packNameSnapshot']} (source entry {lesson['entry']['levelNumberSnapshot']}; {origin})")
        bbcode.extend(['[/list]', ''])
    (OUT / 'Oh My! All Lemmings! - BBCode.txt').write_text('\n'.join(bbcode).rstrip() + '\n')
    print(json.dumps(summary,indent=2))
else:
    raise SystemExit('Usage: learning_report.py collect OUTPUT... | report')
