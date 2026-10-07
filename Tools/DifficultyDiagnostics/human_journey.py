"""Build a community-anchored journey; replay complexity is not human difficulty.

Redux provides an ordinal reference, not equal-sized difficulty measurements.
Classic counterparts remain different variants. Replay-backed fan placements
use explicit uncertainty bounds and remain candidates for human review.
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
POLICY = 'redux-calibrated-2'
VERSION = 'learning-14'
BASE_TARGET = 292
TARGET = 294
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
    # Compare the demands of actual routes, not rescue percentage or stock alone.
    value = sum(weight * abs(math.log1p(a[k]) - math.log1p(b[k])) for k, weight in
                [('assignments', 1.4), ('workers', .8), ('jobChanges', 1.2),
                 ('peakAssignmentsInTwoSeconds', 1.0), ('narrowActions', 1.0)])
    value += .45 * len(set(a['usedSkills']) ^ set(b['usedSkills']))
    def pressure(c):
        scarcity = sum(n / max(1, n + max(0, c['spareUsedSkills'][skill]))
                       for skill, n in c['usedSkills'].items()) / max(1, len(c['usedSkills']))
        # A high quota matters more when the recorded route has little recovery room.
        rescue = c['rescueFraction'] / (1 + c['savedAboveRequirement'])
        crowd = min(1, c['peakAssignmentsInTwoSeconds'] / 6) / max(.2, c['initialHatchIntervalSeconds'])
        return scarcity, rescue, crowd
    value += sum(abs(x-y)*w for x,y,w in zip(pressure(a), pressure(b), [.8, .5, .3]))
    return value


def estimate(context, anchors):
    nearest = sorted(anchors, key=lambda a: (distance(context, a['context']), a['reference']['ordinal']))[:5]
    weighted = sorted([(a['placement']['position'], 1 / (.2 + distance(context, a['context']))**2)
                       for a in nearest])
    def quantile(fraction):
        total = sum(w for _, w in weighted); accumulated = 0
        for position, weight in weighted:
            accumulated += weight
            if accumulated >= fraction * total: return position
        return weighted[-1][0]
    centre = quantile(.6)
    # Discovery is not measured. Leave room after the references for uncertain
    # routes, rather than calling a short replay an easy puzzle.
    uncertainty = 15 + (10 if not context['timingProbeComplete'] else 0)
    value = min(800, max(40, centre + uncertainty))
    lower, upper = max(35, quantile(.1) - uncertainty), min(850, quantile(.9) + uncertainty)
    return value, min(lower, value), max(upper, value), nearest


def stage(value):
    return 'Fun' if value < 180 else 'Intermediate' if value < 360 else 'Difficult' if value < 600 else 'Expert'


def build(pool, witnesses, resources, reference, reviews):
    additions = read(OUT / 'required-additions.json')
    required = {key(r) for r in additions}
    required_candidates = {}
    resource_by_id = {key(r): r for r in resources}
    excluded = {key(r) for r in read(ROOT / 'Resources/Progression/exclusions.json')}
    references = {r['reference']: r for r in reference}
    rejected = {(key(r), r['sourceRevision'], r['replayRevision']) for r in read(OUT / 'replay-rejections.json')}
    by_title = collections.defaultdict(list)
    contexts, candidates, pending, selected, variant_holds = {}, {}, [], [], {}
    for row in pool:
        ident = key(row)
        witness = witnesses.get(row['profile']['key']['replayRevision']) or witnesses.get(row.get('initialHash'))
        source = resource_by_id.get(ident)
        if (ident, row['entry']['sourceRevision'], row['profile']['key']['replayRevision']) in rejected:
            pending.append({'identity': row['entry']['identity'], 'title': row['entry']['levelNameSnapshot'],
                            'status': 'exact native replay failed; retained in replay-rejections.json'})
            continue
        if ident in excluded or not source or source['sourceRevision'] != row['entry']['sourceRevision'] or not valid_witness(row, witness):
            pending.append({'identity': row['entry']['identity'], 'title': row['entry']['levelNameSnapshot'],
                            'status': 'excluded or missing exact source/winning replay evidence'})
            continue
        context = solution_context(row, witness, source)
        if any(value < 0 for value in context['spareUsedSkills'].values()):
            pending.append({'identity': row['entry']['identity'], 'title': row['entry']['levelNameSnapshot'],
                            'status': 'replay assignment count exceeds inventory; successful-input audit required'})
            continue
        if ident in required:
            required_candidates[ident] = (row, context)
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
        visibility = resource_by_id[ident].get('interactiveVisibility')
        if visibility is None or any(v['visibleFraction'] < .2 for v in visibility):
            hold.append('Initial exit/trap visibility is missing or mostly concealed')
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
    # Keep the reference spine and fill the full campaign-length path. Placement
    # estimates never change to fit a vacancy. Prefer close comparisons and pack
    # variety when several candidates fill the same part of the progression.
    calibration_errors = sorted(abs(estimate(a['context'], [b for b in anchor_rows if b is not a])[0]
                                    - a['placement']['position']) for a in anchor_rows)
    calibration_deviation = calibration_errors[len(calibration_errors)//2]
    extras = []
    for ident, row in sorted(candidates.items()):
        if any(key(item['row']) == ident for item in selected): continue
        context = contexts[ident]
        visibility = resource_by_id[ident].get('interactiveVisibility')
        if visibility is None or not any(v['effect'] == 1 for v in visibility) or any(v['visibleFraction'] < .2 for v in visibility):
            continue
        if context['assignments'] > 40 or context['usedSkills'].get('builder', 0) > 24:
            continue  # Avoid padding the journey with long repetitive witnesses.
        value, lower, upper, neighbours = estimate(context, anchor_rows)
        if value < 180 and (context['narrowActions'] or len(context['usedSkills']) > 3
                or context['jobChanges'] > 1
                or (len(context['usedSkills']) > 1 and context['exhaustedUsedSkills'] and context['savedAboveRequirement'] == 0)):
            continue  # Uncertain beginner placement needs a more forgiving route.
        lower = min(lower, max(0, value - calibration_deviation))
        upper = max(upper, min(1000, value + calibration_deviation))
        extras.append({'row': row, 'context': context, 'reference': neighbours[0]['reference'],
            'placement': {'basis': 'solutionEstimate', 'reference': neighbours[0]['reference']['reference'],
                'sourceURL': SOURCE, 'position': value, 'lower': lower, 'upper': upper,
                'sourceRevision': row['entry']['sourceRevision'], 'replayRevision': context['replayRevision']},
            'variantDifferences': variant_holds.get(ident, []),
            'comparisons': [{'reference': n['reference']['reference'], 'position': n['placement']['position'],
                'distance': round(distance(context, n['context']), 4)} for n in neighbours]})
    pack_counts = collections.Counter(item['row']['entry']['identity']['packID'] for item in selected)
    slots = BASE_TARGET - len(selected)
    for index in range(slots):
        target = 40 + (760 * index / max(1, slots - 1))
        used_titles = {normalized(item['row']['entry']['levelNameSnapshot']) for item in selected}
        options = [item for item in extras if normalized(item['row']['entry']['levelNameSnapshot']) not in used_titles
                   and (item['row']['official'] or pack_counts[item['row']['entry']['identity']['packID']] < 4)]
        assert options, 'Insufficient verified candidates for the full journey; do not shorten it silently'
        def selection_cost(item):
            p = item['placement']; pack = item['row']['entry']['identity']['packID']
            return (abs(p['position'] - target) + .18 * (p['upper'] - p['lower'])
                    + 4 * pack_counts[pack] + 4 * len(risks(item['context'])), key(item['row']))
        chosen = min(options, key=selection_cost)
        extras.remove(chosen); selected.append(chosen)
        pack_counts[chosen['row']['entry']['identity']['packID']] += 1
    # Preserve the existing selection, then insert the two promised additions.
    # Required entries still need exact source resources and winning native routes.
    assert len(required) == TARGET - BASE_TARGET
    for addition in additions:
        ident = key(addition)
        assert ident in required_candidates, f'Missing exact evidence for required addition: {ident}'
        row, context = required_candidates[ident]
        visibility = resource_by_id[ident].get('interactiveVisibility')
        assert visibility and any(v['effect'] == 1 for v in visibility)
        assert all(v['visibleFraction'] >= .2 for v in visibility)
        if addition['basis'] == 'reduxPortCounterpart':
            reference = references[addition['reference']]
            assert normalized(row['entry']['levelNameSnapshot']) == normalized(reference['title'])
            value = reference['ordinal'] * 5.0
            lower, upper = max(0, value - 10), min(1000, value + 10)
            neighbours = []
        else:
            assert addition['basis'] == 'solutionEstimate'
            value, lower, upper, neighbours = estimate(context, anchor_rows)
            lower = min(lower, max(0, value - calibration_deviation))
            upper = max(upper, min(1000, value + calibration_deviation))
            reference = neighbours[0]['reference']
        placement = {'basis': addition['basis'], 'reference': reference['reference'],
            'sourceURL': SOURCE, 'position': value, 'lower': lower, 'upper': upper,
            'sourceRevision': row['entry']['sourceRevision'], 'replayRevision': context['replayRevision']}
        item = {'row': row, 'context': context, 'reference': reference, 'placement': placement,
            'variantDifferences': addition.get('variantDifferences', []),
            'comparisons': [{'reference': n['reference']['reference'], 'position': n['placement']['position'],
                'distance': round(distance(context, n['context']), 4)} for n in neighbours]}
        selected.append(item)
        pending.append({'identity': row['entry']['identity'], 'sourceRevision': row['entry']['sourceRevision'],
            'title': row['entry']['levelNameSnapshot'], 'pack': row['entry']['packNameSnapshot'],
            'status': 'included with port counterpart evidence; human variant review still needed'
                if addition['basis'] == 'reduxPortCounterpart' else 'included with an estimated grade; human review still needed',
            'context': context, 'risks': risks(context) + item['variantDifferences'],
            'comparisons': item['comparisons'], 'placement': placement})
    assert len(selected) == TARGET
    admitted = {key(item['row']): item for item in selected}
    for row in pending:
        if key(row) in admitted:
            if admitted[key(row)]['placement']['basis'] != 'reduxPortCounterpart':
                row['status'] = 'included with an estimated grade; human review still needed'
            row['placement'] = admitted[key(row)]['placement']
    calibration = []
    for anchor in anchor_rows:
        predicted, _, _, _ = estimate(anchor['context'], [a for a in anchor_rows if a is not anchor])
        calibration.append(abs(predicted - anchor['placement']['position']))
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
        objective = 'community:' + item['reference']['reference'] if placement['basis'] in ['reduxClassicCounterpart', 'reduxPortCounterpart'] else 'placement:' + key(row)
        lesson = {'entry': row['entry'], 'objective': objective, 'score': row['profile']['overallScore'],
                  'intrinsicDemand': row['profile']['overallScore'], 'demand': value, 'stage': stage(value),
                  'preparationGaps': new if len(concepts) > 1 and item['reference']['ordinal'] > 7 else [], 'concepts': concepts, 'introduced': new, 'focus': focus,
                  'needsSupport': bool(context['narrowActions'] or delta > 35 or placement['basis'] in ['solutionEstimate', 'reduxPortCounterpart']), 'placement': placement}
        lessons.append(lesson)
        curriculum.append({'identity': row['entry']['identity'], 'objective': objective, 'lesson': focus,
                           'level': row['entry']['levelNameSnapshot'], 'purpose': 'Community-ordered practice with an exact native winning witness',
                           'reference': item['reference'], 'placement': placement, 'context': context,
                           'variantDifferences': item['variantDifferences'], 'risks': risks(context),
                           'comparisons': item.get('comparisons', [])})
        transitions.append({'step': i + 1, 'level': row['entry']['levelNameSnapshot'], 'demand': value,
                            'referenceStep': delta / 5, 'rawReplayScore': row['profile']['overallScore'],
                            'rawReplayScoreChange': row['profile']['overallScore'] - lessons[-2]['score'] if i else 0,
                            'newSkills': new, 'risks': risks(context), 'variantDifferences': item['variantDifferences']})
        practiced.update(concepts)
    manifest = {'version': VERSION, 'placementPolicy': POLICY, 'lessons': lessons}
    plan = {'version': 'curriculum-8', 'poolSize': len(pool), 'targetSize': TARGET,
            'calibration': {'method': 'leave-one-reference-out', 'samples': len(calibration),
                'medianAbsolutePositionError': sorted(calibration)[len(calibration)//2],
                'meaning': 'Diagnostic error against community order; not a human playtest pass.'}, 'lessons': curriculum,
            'selectionPolicy': '294 levels: existing 292-level selection plus the required Macintosh and DOS additions. Redux reference spine plus resource-aware solution comparisons, repeated practice and pack diversity. Estimated grades retain uncertainty. No score clamping.',
            'limits': 'Redux ordinal positions are not equal human-difficulty units. Classic counterparts differ from Redux. A replay proves a route, not novice discovery. Solution comparisons are estimated grades, not claims of human review.'}
    pending.sort(key=lambda r: key(r))
    return manifest, plan, pending, transitions


def report(manifest, plan, pending, transitions):
    lessons = manifest['lessons']
    summary = {'version': manifest['version'], 'placementPolicy': POLICY,
               'candidatePool': plan['poolSize'], 'levels': len(lessons),
               'official': sum(not l['entry']['identity']['packID'].startswith('fan:') for l in lessons),
               'fan': sum(l['entry']['identity']['packID'].startswith('fan:') for l in lessons),
               'stages': dict(collections.Counter(l['stage'] for l in lessons)),
               'pendingReview': len(pending), 'estimatedPlacements': sum(l['placement']['basis'] == 'solutionEstimate' for l in lessons),
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
        'Full 294-level size; solution estimates are distinguished from human reviews',
        'No fabricated precision, rank floors, cumulative clamps or application-pattern deduplication',
        'Adjacent reference gaps are checked without changing any placement score'],
        'limits': plan['limits']})
    lines = ['# Oh My! All Lemmings! progression', '',
        f"{len(lessons)} curated Classic-mechanics levels: a full journey equivalent to Classic, Oh No! and the Christmas campaigns combined.", '',
        f"[Redux's community order]({SOURCE}) supplies the reference spine. The remaining official and fan levels are placed by comparisons with five reference solutions. Actual assignments, worker changes, skill combinations, bursts of input, timing evidence and resource pressure inform those comparisons.", '',
        'Resource pressure uses the skills actually spent and the route’s rescue margin. Release cadence is considered alongside input density. High rescue percentages, rapid release rates and large inventories never assign a grade by themselves. All selected levels have an exact-version winning replay. Explicit unsuitable-level exclusions remain in force. Estimated additions need an initial-state visibility audit and exclude mostly concealed exits or traps. This pixel-visibility check does not prove that the route or all visual information is obvious.', '',
        'The first seven teaching levels stay intact. Repeated practice is retained. Selection targets coverage across the curve, limits repeated fan packs and avoids long repetitive witnesses. Estimated beginner additions cannot have measured narrow timing, more than three skill types, multiple worker role changes, or an exhausted combination with no rescue margin. It does not raise or lower grades to make adjacent numbers look smooth. The production generator fails if it cannot supply all 294 levels. The two promised 1.8.2 additions are mandatory and retain exact native witnesses. Port counterparts use the Redux position with recorded conversion differences; they do not claim human variant review.', '',
        '## Estimated grades and review', '',
        'A solutionEstimate is an estimate of solving demands against the references, not a human-reviewed difficulty label. Its lower and upper bounds include disagreement among comparable solutions and at least the median held-out calibration error. They are uncertainty ranges, not confidence intervals. Unknown discovery and incomplete timing tests add uncertainty. A named, exact-version human review can replace that estimate. human-review-queue.json includes both selected estimates and reserves; inclusion is explicitly recorded.', '',
        'For human review, record an ordinary completion, what had to be discovered, hints used, execution retries and whether spare resources offered recovery. Compare nearby reference levels played by the same person. Hidden-information checks remain a human-review requirement. No human observations are fabricated.', '',
        'The curriculum records leave-one-reference-out error. That diagnostic measures how imperfectly route features recover community order. It is not proof of a smooth novice experience. Classic and Redux have different physics, time limits and sometimes different skill or rescue budgets.', '',
        '## Saved journeys', '',
        'Older built-in queues migrate to this full path. Completed or visited entries remain history, ownership and progress stay intact, and the remaining queue follows the current order. Custom playlists and newer saved versions are unchanged.', '',
        'Regenerate with `zsh Scripts/generate-learning-journey.sh BUNDLED_RESOURCES`. Check with `python3 Tools/DifficultyDiagnostics/human_journey.py --check`.', '',
        '## Current order', '', '| Step | Comparison reference | Level | Stage | Evidence |', '| ---: | --- | --- | --- | --- |']
    for i, (lesson, goal) in enumerate(zip(lessons, plan['lessons']), 1):
        ref = goal['reference']
        lines.append(f"| {i} | {ref['rank']} {ref['number']} | {lesson['entry']['levelNameSnapshot'].replace('|', '/')} | {lesson['stage']} | {lesson['placement']['basis']} |")
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
    bundled = read(ROOT / 'Resources/Progression/solutions.json')
    by_identity = {key(r): r for r in pool}
    for lesson in manifest['lessons']:
        row = by_identity[key(lesson)]
        replay = witnesses.get(row['profile']['key']['replayRevision']) or witnesses[row['initialHash']]
        bundled[row['initialHash']] = replay
    outputs = {ROOT / 'Resources/Progression/learning.json': manifest,
               ROOT / 'Resources/Progression/solutions.json': bundled, OUT / 'curriculum.json': plan,
               OUT / 'human-review-queue.json': pending, OUT / 'transitions.json': transitions,
               OUT / 'redux-reference.json': {'sourceURL': SOURCE, 'levels': redux_reference()}}
    if args.check:
        for path, value in outputs.items():
            assert read(path) == value, f'Stale output: {path}'
    else:
        for path, value in outputs.items(): write(path, value)
        report(manifest, plan, pending, transitions)
    print(f'{len(manifest["lessons"])} community-anchored lessons; {len(pending)} candidates in the review queue (including selected estimates).')

if __name__ == '__main__':
    main()
