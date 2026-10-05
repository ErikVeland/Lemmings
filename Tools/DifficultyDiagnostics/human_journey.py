"""Build a community-anchored journey; replay complexity is not human difficulty.

Redux provides an ordinal reference, not equal-sized difficulty measurements.
Classic counterparts remain different variants. Fan estimates are review aids,
never permission to put an unreviewed puzzle into the mandatory progression.
"""
from __future__ import annotations
import argparse
import collections
import hashlib
import json
import math
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / 'Artifacts/LearningJourney'
REFERENCE = ROOT / 'Content/NeoLemmix/levels/Lemmings_Redux'
SOURCE = 'https://www.lemmingsforums.net/index.php?topic=4374.0'
RANKS = ['Gentle', 'Quirky', 'Zany', 'Manic', 'Lunatic']
BASIC = {'climber', 'floater', 'bomber', 'blocker', 'builder', 'basher', 'miner', 'digger'}
POLICY = 'redux-community-1'
VERSION = 'learning-12'
# An explicit counterpart with a changed title, not a fuzzy fan-level match.
ALIASES = {'ataskforbombers': 'ataskforblockersandbombers'}


def read(path):
    return json.loads(path.read_text())


def write(path, value):
    path.write_text(json.dumps(value, indent=2, sort_keys=True, ensure_ascii=False) + '\n')


def key(row):
    return json.dumps(row.get('identity', row.get('entry', {}).get('identity')), sort_keys=True)


def normalized(title):
    return re.sub('[^a-z0-9]', '', title.lower())


def redux_reference(root=REFERENCE):
    result = []
    for rank_index, rank in enumerate(RANKS):
        folder = root / rank
        names = [line.strip()[6:] for line in (folder / 'levels.nxmi').read_text().splitlines()
                 if line.strip().startswith('LEVEL ')]
        for index, name in enumerate(names):
            data = (folder / name).read_bytes()
            values, skills = {}, {}
            in_skills = False
            for line in data.decode('utf-8-sig').splitlines():
                parts = line.strip().split(maxsplit=1)
                if not parts or parts[0].startswith('#'):
                    continue
                if parts[0] == '$SKILLSET':
                    in_skills = True
                elif parts[0] == '$END':
                    in_skills = False
                elif len(parts) == 2:
                    if in_skills:
                        skills[parts[0].lower()] = int(parts[1])
                    elif parts[0] in ('TITLE', 'AUTHOR', 'ID', 'LEMMINGS', 'SAVE_REQUIREMENT', 'MAX_SPAWN_INTERVAL', 'TIME_LIMIT'):
                        values[parts[0]] = parts[1]
            result.append({'reference': rank + '/' + name, 'rank': rank, 'rankIndex': rank_index,
                           'number': index + 1, 'ordinal': rank_index * 32 + index + 1,
                           'title': values['TITLE'], 'author': values.get('AUTHOR'), 'sourceURL': SOURCE,
                           'sha256': hashlib.sha256(data).hexdigest(), 'skills': skills,
                           'population': int(values['LEMMINGS']), 'required': int(values['SAVE_REQUIREMENT']),
                           'spawnInterval': int(values.get('MAX_SPAWN_INTERVAL', 4)),
                           'timeLimitSeconds': int(values['TIME_LIMIT']) if 'TIME_LIMIT' in values else None})
    assert len(result) == 160 and len({r['reference'] for r in result}) == 160
    return result


def replay_digest(replay):
    # Match JSONEncoder [.prettyPrinted, .sortedKeys], including empty objects
    # and escaped slashes. Verified against the native encoder's entire corpus.
    encoded = json.dumps(replay, indent=2, separators=(',', ' : '), sort_keys=True, ensure_ascii=False).replace('/', '\\/')
    encoded = re.sub(r'(?m)^(\s*[^\n]* : )(\{\}|\[\])',
                     lambda m: m[1] + m[2][0] + '\n\n' + re.match(r' *', m[1])[0] + m[2][1], encoded)
    return hashlib.sha256(encoded.encode()).hexdigest()


def valid_witness(row, replay):
    expected = (replay or {}).get('expected', {})
    return bool(replay and row['profile']['key']['replayRevision'].removeprefix('SHA256 digest: ') == replay_digest(replay)
                and expected.get('didWin') and expected.get('ticks', 0) > 0
                and replay.get('initialStateHash') == row.get('initialHash')
                and not replay.get('sourceRules')
                and all((0 if e.get('afterTick') else 1) <= e['tick'] <= expected['ticks'] for e in replay['events']))


def solution_context(row, replay, resource):
    """Keep execution, spare resources and unknown discovery separate."""
    events = sorted(replay['events'], key=lambda e: (e['tick'], e.get('afterTick', False)))
    assignments = [e for e in events if 'assign' in e['action']]
    counts = collections.Counter(e['action']['assign']['skill'] for e in assignments)
    workers = collections.defaultdict(list)
    for e in assignments:
        action = e['action']['assign']; workers[action['lemmingID']].append(action['skill'])
    changes = sum(sum(a != b for a, b in zip(chain, chain[1:])) for chain in workers.values())
    skills = resource['skills']
    spare = {skill: skills.get(skill, 0) - count for skill, count in counts.items()}
    # 99 skills is effectively unrestricted in the Classic level format.
    finite = [skill for skill in counts if skills.get(skill, 0) < 99]
    exhausted = [skill for skill in finite if spare[skill] == 0]
    ticks = replay['expected']['ticks']
    deadline = resource['timeLimitTicks'] or None
    precision = row['profile'].get('precision') or {}
    burst = max((sum(e['tick'] <= other['tick'] < e['tick'] + 34 for other in assignments)
                 for e in assignments), default=0)
    rate = resource['releaseRate']
    # Native DOS release cadence. This is exposure, not difficulty by itself.
    hatch_ticks = 4 + (99 - min(99, max(1, rate))) // 2
    return {'assignments': len(assignments), 'workers': len(workers), 'jobChanges': changes,
            'usedSkills': dict(sorted(counts.items())), 'spareUsedSkills': spare,
            'exhaustedUsedSkills': exhausted, 'peakAssignmentsInTwoSeconds': burst,
            'population': resource['population'], 'required': resource['required'],
            'allowedLosses': resource['population'] - resource['required'],
            'savedAboveRequirement': replay['expected']['saved'] - resource['required'],
            'rescueFraction': resource['required'] / max(1, resource['population']),
            'startingReleaseRate': rate, 'initialHatchIntervalSeconds': hatch_ticks / 17,
            'completionSeconds': ticks / 17,
            'remainingSeconds': (deadline - ticks) / 17 if deadline else None,
            'timingProbeComplete': precision.get('completed', False),
            'probedAssignments': len(precision.get('actions', [])),
            'narrowActions': len(row['profile'].get('criticalActions', [])),
            'spatialToleranceMeasured': bool(precision.get('selectionOutcomes')),
            'discoveryDifficulty': 'unknown from replay',
            'replayRevision': row['profile']['key']['replayRevision']}


def risks(context):
    result = []
    if not context['timingProbeComplete']:
        result.append('incomplete timing probes')
    if not context['spatialToleranceMeasured']:
        result.append('spatial tolerance unmeasured')
    if context['narrowActions']:
        result.append('narrow measured timing')
    if context['remainingSeconds'] is not None and context['remainingSeconds'] < 30:
        result.append('less than 30 seconds spare on the witness')
    if context['exhaustedUsedSkills']:
        result.append('witness exhausts at least one used skill')
    if context['peakAssignmentsInTwoSeconds'] >= 4:
        result.append('four or more assignments within two seconds')
    return result


def variant_differences(resource, reference, context):
    result = ['Classic mechanics differ from NeoLemmix; title correspondence is not variant equivalence']
    if resource['population'] != reference['population']:
        result.append('different population')
    if resource['required'] / max(1, resource['population']) != reference['required'] / reference['population']:
        result.append('different rescue fraction')
    if any(resource['skills'].get(s, 0) != reference['skills'].get(s, 0) for s in BASIC):
        result.append('different skill inventory')
    if resource['timeLimitTicks'] and reference['timeLimitSeconds'] is None:
        result.append('Classic retains a time limit')
    if 'bomber' in context['usedSkills']:
        result.append('Classic bomber countdown needs additional execution review')
    return result


def counterpart_review_reasons(resource, reference, context):
    """Materially harder variants cannot inherit the reference's position."""
    result = []
    if context['rescueFraction'] > reference['required'] / reference['population'] + .10:
        result.append('Classic rescue fraction exceeds Redux by more than ten percentage points')
    scarce = [skill for skill in context['usedSkills']
              if min(99, resource['skills'].get(skill, 0)) < min(99, reference['skills'].get(skill, 0))]
    if scarce:
        result.append('Classic has fewer available solution skills than Redux: ' + ', '.join(sorted(scarce)))
    return result


def review_approved(review, row, context, references):
    """A review must identify the exact variant and an ordinary human solution."""
    if review.get('status') != 'approved' or not review.get('reviewer') or not review.get('sourceURL', '').startswith('https://'):
        return False
    if review.get('sourceRevision') != row['entry']['sourceRevision'] or review.get('replayRevision') != context['replayRevision']:
        return False
    if not review.get('ordinarySolution') or not review.get('discoveryNotes') or not review.get('resourceNotes'):
        return False
    lower = references.get(review.get('afterReference'))
    upper = references.get(review.get('beforeReference'))
    return bool(lower and upper and 0 < upper['ordinal'] - lower['ordinal'] <= 4
                and review.get('hiddenInformation') is False)


def distance(a, b):
    # Comparisons describe a route's execution only. They cannot certify insight.
    continuous = [('assignments', 24), ('jobChanges', 12), ('workers', 12),
                  ('peakAssignmentsInTwoSeconds', 6), ('narrowActions', 4)]
    value = sum(min(2, abs(a[k] - b[k]) / scale) for k, scale in continuous)
    value += len(set(a['usedSkills']) ^ set(b['usedSkills'])) * .5
    value += abs(a['rescueFraction'] - b['rescueFraction'])
    value += abs(len(a['exhaustedUsedSkills']) - len(b['exhaustedUsedSkills'])) * .2
    return value


def stage(value):
    return 'Fun' if value < 180 else 'Intermediate' if value < 360 else 'Difficult' if value < 600 else 'Expert'


def build(pool, witnesses, resources, reference, reviews):
    resource_by_id = {key(r): r for r in resources}
    excluded = {key(r) for r in read(ROOT / 'Resources/Progression/exclusions.json')}
    references = {r['reference']: r for r in reference}
    by_title = collections.defaultdict(list)
    contexts, candidates, pending, selected, variant_holds = {}, {}, [], [], {}
    for row in pool:
        ident = key(row)
        witness = witnesses.get(row['profile']['key']['replayRevision']) or witnesses.get(row.get('initialHash'))
        source = resource_by_id.get(ident)
        if ident in excluded or not source or source['sourceRevision'] != row['entry']['sourceRevision'] or not valid_witness(row, witness):
            pending.append({'identity': row['entry']['identity'], 'title': row['entry']['levelNameSnapshot'],
                            'status': 'excluded or missing exact source/winning replay evidence'})
            continue
        context = solution_context(row, witness, source)
        if any(value < 0 for value in context['spareUsedSkills'].values()):
            pending.append({'identity': row['entry']['identity'], 'title': row['entry']['levelNameSnapshot'],
                            'status': 'replay assignment count exceeds inventory; successful-input audit required'})
            continue
        contexts[ident], candidates[ident] = context, row
        if row['official']:
            by_title[normalized(row['entry']['levelNameSnapshot'])].append(row)
    matched = set()
    for anchor in reference:
        title = ALIASES.get(normalized(anchor['title']), normalized(anchor['title']))
        options = by_title.get(title, [])
        if len(options) != 1:
            continue
        row = options[0]; ident = key(row); context = contexts[ident]
        if ident in matched:
            continue
        hold = counterpart_review_reasons(resource_by_id[ident], anchor, context)
        if hold:
            variant_holds[ident] = hold
            continue
        matched.add(ident)
        # Keep the community's ordering, not a ranking of polished replay clicks.
        # The first seven reference positions are explicit basic teaching levels.
        value = anchor['ordinal'] * 5.0
        selected.append({'row': row, 'context': context, 'reference': anchor,
                         'placement': {'basis': 'reduxClassicCounterpart', 'reference': anchor['reference'],
                                       'sourceURL': SOURCE, 'position': value, 'lower': max(0, value - 10),
                                       'upper': min(1000, value + 10), 'sourceRevision': row['entry']['sourceRevision'],
                                       'replayRevision': context['replayRevision']},
                         'variantDifferences': variant_differences(resource_by_id[ident], anchor, context)})
    anchor_rows = list(selected)
    reviewed = {key(r): r for r in reviews}
    for ident, row in sorted(candidates.items()):
        if ident in matched:
            continue
        context = contexts[ident]; review = reviewed.get(ident, {})
        if not row['official'] and review_approved(review, row, context, references):
            lower, upper = references[review['afterReference']], references[review['beforeReference']]
            value = (lower['ordinal'] + upper['ordinal']) * 2.5
            selected.append({'row': row, 'context': context, 'reference': lower,
                             'placement': {'basis': 'reviewedFan', 'reference': lower['reference'],
                                           'sourceURL': review['sourceURL'], 'position': value,
                                           'lower': lower['ordinal'] * 5, 'upper': upper['ordinal'] * 5,
                                           'sourceRevision': row['entry']['sourceRevision'],
                                           'replayRevision': context['replayRevision']},
                             'variantDifferences': [], 'review': review})
            continue
        nearest = sorted(anchor_rows, key=lambda a: (distance(context, a['context']), a['reference']['ordinal']))[:3]
        pending.append({'identity': row['entry']['identity'], 'sourceRevision': row['entry']['sourceRevision'],
                        'title': row['entry']['levelNameSnapshot'], 'pack': row['entry']['packNameSnapshot'],
                        'status': 'needs human discovery/variant review', 'context': context, 'risks': risks(context) + variant_holds.get(ident, []),
                        'comparisons': [{'reference': a['reference']['reference'], 'level': a['row']['entry']['levelNameSnapshot'],
                                         'ordinal': a['reference']['ordinal'], 'executionDistance': round(distance(context, a['context']), 3)}
                                        for a in nearest]})
    selected.sort(key=lambda r: (r['placement']['position'], key(r['row'])))
    assert selected and selected[0]['reference']['ordinal'] == 1, 'The tutorial opening must not silently disappear'
    lessons, curriculum, transitions = [], [], []
    practiced = set()
    for i, item in enumerate(selected):
        row, placement, context = item['row'], item['placement'], item['context']
        value = placement['position']
        delta = value - lessons[-1]['demand'] if lessons else 0
        assert 0 <= delta <= 65, f'Unbridged community-order gap before {row["entry"]["levelNameSnapshot"]}'
        concepts = sorted(set(context['usedSkills']))
        new = sorted(set(concepts) - practiced)
        focus = ('Discover: ' if new else 'Practise: ') + ' + '.join(s.capitalize() for s in (new or concepts)[:2])
        objective = 'community:' + item['reference']['reference'] if row['official'] else 'review:' + key(row)
        lesson = {'entry': row['entry'], 'objective': objective, 'score': row['profile']['overallScore'],
                  'intrinsicDemand': row['profile']['overallScore'], 'demand': value, 'stage': stage(value),
                  'preparationGaps': new if len(concepts) > 1 and item['reference']['ordinal'] > 7 else [], 'concepts': concepts, 'introduced': new, 'focus': focus,
                  'needsSupport': bool(context['narrowActions'] or delta > 35), 'placement': placement}
        lessons.append(lesson)
        curriculum.append({'identity': row['entry']['identity'], 'objective': objective, 'lesson': focus,
                           'level': row['entry']['levelNameSnapshot'], 'purpose': 'Community-ordered practice with an exact native winning witness',
                           'reference': item['reference'], 'placement': placement, 'context': context,
                           'variantDifferences': item['variantDifferences'], 'risks': risks(context)})
        transitions.append({'step': i + 1, 'level': row['entry']['levelNameSnapshot'], 'demand': value,
                            'referenceStep': delta / 5, 'rawReplayScore': row['profile']['overallScore'],
                            'rawReplayScoreChange': row['profile']['overallScore'] - lessons[-2]['score'] if i else 0,
                            'newSkills': new, 'risks': risks(context), 'variantDifferences': item['variantDifferences']})
        practiced.update(concepts)
    manifest = {'version': VERSION, 'placementPolicy': POLICY, 'lessons': lessons}
    plan = {'version': 'curriculum-6', 'poolSize': len(pool), 'targetSize': 160, 'lessons': curriculum,
            'selectionPolicy': 'Redux community order for verified Classic counterparts; exact human review required for fan insertion; no cumulative score clamping or skill-pattern deduplication.',
            'limits': 'Redux ordinal positions are not equal human-difficulty units. Classic counterparts differ from Redux. A replay proves a route, not novice discovery. Fan comparisons are unapproved review aids.'}
    pending.sort(key=lambda r: key(r))
    return manifest, plan, pending, transitions


def report(manifest, plan, pending, transitions):
    lessons = manifest['lessons']
    summary = {'version': manifest['version'], 'placementPolicy': POLICY,
               'candidatePool': plan['poolSize'], 'levels': len(lessons),
               'official': sum(not l['entry']['identity']['packID'].startswith('fan:') for l in lessons),
               'fan': sum(l['entry']['identity']['packID'].startswith('fan:') for l in lessons),
               'stages': dict(collections.Counter(l['stage'] for l in lessons)),
               'pendingReview': len(pending),
               'largestReferenceGap': max(t['referenceStep'] for t in transitions),
               'limits': plan['limits']}
    write(OUT / 'summary.json', summary)
    corpus = read(OUT / 'corpus-coverage.json')
    for campaign in corpus['campaigns']:
        campaign['selected'] = sum(l['entry']['packNameSnapshot'] == campaign['pack'] for l in lessons)
    corpus['eligiblePool'] = plan['poolSize']
    corpus['selectionPolicy'] = 'Community reference and exact-variant review; campaign size is not a quota.'
    write(OUT / 'corpus-coverage.json', corpus)
    write(OUT / 'oh-no-placements.json', [{'step': i + 1, 'level': l['entry']['levelNameSnapshot'],
        'objective': l['objective']} for i, l in enumerate(lessons)
        if l['entry']['packNameSnapshot'] == 'Oh No! More Lemmings'])

    write(OUT / 'validation.json', {'policy': POLICY, 'checks': [
        'Exact source revisions and native winning replay identities required',
        'Redux file hashes and community order pinned',
        'Fan admission requires an exact-version human review',
        'No fabricated precision, rank floors, cumulative clamps or application-pattern deduplication',
        'Adjacent reference gaps are checked without changing any placement score'],
        'limits': plan['limits']})
    lines = ['# Oh My! All Lemmings! progression', '',
        f"{len(lessons)} community-anchored Classic lessons. {len(pending)} candidates remain outside the mandatory path pending review.", '',
        'The previous curve sorted replay execution costs, imposed blanket rescue/rate floors, and raised later scores to the preceding score. Those operations could hide an easy–hard–easy sequence. The new production path does not use them.', '',
        f'[Lemmings Redux]({SOURCE}) supplies community-selected ordinal reference points. Its 160 levels were discussed, reordered and edited by players. This journey uses verified Classic counterparts where available. It does not claim that Classic and Redux variants have identical difficulty.', '',
        'A full rescue target or fast release rate is context, not an automatic hard rating. The audit records the actual population, permitted losses, spare skills in the winning route, release cadence, assignment bursts, remaining time and probe coverage. A saved-count margin or many spare skills cannot prove that a hidden idea is easy to discover.', '',
        'Repeated practice is allowed. One replay skill pattern is not one complete lesson. Optional all-save, speedrun and skill-economy routes must not be confused with an ordinary completion.', '',
        '## Fan admission', '',
        '`human-review-queue.json` records exact source/replay identities, route constraints, missing evidence and nearby reference routes. These comparisons are execution estimates, not human difficulty labels. Unknown discovery difficulty stays unknown. A pack named Fun or Tame is not global calibration.', '',
        '`human-reviews.json` accepts a named human review of the exact variant and an ordinary solution, with discovery/resource notes, an explicit hidden-information check, and nearby Redux anchors. No such reviews have been fabricated. Unreviewed fan levels remain in their packs and the full library, with their existing solutions, but no longer interrupt this mandatory progression.', '',
        'For a review, record an ordinary human completion of this exact version and its source. Note what had to be discovered, hints used, failed attempts caused by execution, and whether spare skills or rescue margin actually offered recovery. Compare it with nearby reference levels played by the same person. A polished replay, pack rank or a single completion time cannot replace those observations.', '',
        '## Saved journeys', '',
        'Older built-in queues migrate on load. A retained current level stays current. A withdrawn current level moves to the first unvisited reference. Past visits, progress records, run identity and Solo/Hot Seat ownership stay intact. Custom playlists and newer versions are not migrated. Exhausted queues close without adding wins.', '',
        '## Limits and validation', '',
        'Reference order is ordinal. Five stored position units represent one Redux position, not five units of measured human difficulty. The transition gate detects missing reference stretches; it is not evidence that all human difficulty jumps are solved. Original time limits, population, skills and timed bombers can change the experience. Every counterpart records those differences. A rescue fraction more than ten percentage points above Redux, or fewer available skills used by the solution, holds a counterpart for review. These are variant-transfer guards, not difficulty ratings. Novice observation remains necessary to approve these transfers and fan insertions.', '',
        'Timing probes cover one route, often only a small part of it. Unmeasured spatial tolerance and discovery are never recorded as zero difficulty. A replay that finishes at the time limit may simply leave blockers behind; remaining time alone does not prove pressure.', '',
        'Regenerate with `zsh Scripts/generate-learning-journey.sh BUNDLED_RESOURCES`. Check outputs with `python3 Tools/DifficultyDiagnostics/human_journey.py --check`.', '',
        '## Current order', '', '| Step | Reference | Classic level | Stage |', '| ---: | --- | --- | --- |']
    for i, (lesson, goal) in enumerate(zip(lessons, plan['lessons']), 1):
        ref = goal['reference']
        lines.append(f"| {i} | {ref['rank']} {ref['number']} | {lesson['entry']['levelNameSnapshot'].replace('|', '/')} | {lesson['stage']} |")
    (OUT / 'README.md').write_text('\n'.join(lines) + '\n')


def load_pool(resources):
    # Reconstruct exported candidates from tracked evidence so checks do not
    # depend on a stale ignored pool file or a developer's build directory.
    identities = {key(r) for r in resources}
    rows = {key(r): r for r in read(ROOT / 'Artifacts/ClassicProgression/audit.json') if key(r) in identities}
    for candidate in read(OUT / 'fan-evidence.json'):
        original = rows.get(key(candidate))
        if not original or original['official'] or candidate['profile']['confidence'] == 'low':
            continue
        if (candidate['entry']['sourceRevision'] != original['entry']['sourceRevision']
                or candidate['initialHash'] != original['initialHash']):
            continue
        if original['profile']['confidence'] == 'low' or candidate['profile']['overallScore'] < original['profile']['overallScore']:
            rows[key(candidate)] = dict(candidate)
    assert set(rows) == identities, 'Resource evidence is missing its source profile'
    return [rows[k] for k in sorted(rows)]


def main():
    parser = argparse.ArgumentParser(); parser.add_argument('--check', action='store_true'); args = parser.parse_args()
    resources = read(OUT / 'source-resources.json')
    pool = load_pool(resources)
    witnesses = read(OUT / 'candidate-solutions.json')
    witnesses.update(read(ROOT / 'Resources/Hints/solutions.json'))
    manifest, plan, pending, transitions = build(pool, witnesses, resources,
                                               redux_reference(), read(OUT / 'human-reviews.json')['reviews'])
    outputs = {ROOT / 'Resources/Progression/learning.json': manifest, OUT / 'curriculum.json': plan,
               OUT / 'human-review-queue.json': pending, OUT / 'transitions.json': transitions,
               OUT / 'redux-reference.json': {'sourceURL': SOURCE, 'levels': redux_reference()}}
    if args.check:
        for path, value in outputs.items():
            assert read(path) == value, f'Stale output: {path}'
    else:
        for path, value in outputs.items(): write(path, value)
        report(manifest, plan, pending, transitions)
    print(f'{len(manifest["lessons"])} community-anchored lessons; {len(pending)} levels held for review.')

if __name__ == '__main__':
    main()
