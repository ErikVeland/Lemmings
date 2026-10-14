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
POLICY = 'redux-calibrated-3'
VERSION = 'learning-23'
MAINLINE_PACKS = {'lemmings-LEVEL-120', 'ohNoMoreLemmings-DLVEL-100',
                  'ohYesMoreLemmings-OHYES-60'}
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


def seasonal(row):
    metadata = row['entry']['identity']['packID'] + ' ' + row['entry']['packNameSnapshot']
    return bool(re.search(r'xmas|christmas|holiday', metadata, re.I))


def official_rank_floor(row):
    # Retail rank is a conservative floor for unmatched official variants.
    rank = (row['profile'].get('sourceRank') or '').lower().split(' ')[0]
    return {'fun': 0, 'tame': 0, 'tricky': 180, 'crazy': 600, 'taxing': 360,
            'wild': 600, 'wicked': 600, 'mayhem': 600, 'havoc': 600}.get(rank, 360)


def fills_reviewed_gap(item, selected):
    """Admit a fan bridge only inside a real gap, within its reviewed bounds."""
    official = sorted((r for r in selected if r['row']['official']),
                      key=lambda r: r['placement']['position'])
    placement = item['placement']
    return any(right['placement']['position'] - left['placement']['position'] > 10
               and left['placement']['position'] <= placement['lower']
               and placement['upper'] <= right['placement']['position']
               and set(item['context']['usedSkills']) <= set().union(
                   *(set(r['context']['usedSkills']) for r in official
                     if r['placement']['position'] <= left['placement']['position']))
               for left, right in zip(official, official[1:]))


def build(pool, witnesses, resources, reference, reviews):
    additions = read(OUT / 'required-additions.json')
    required = {key(r) for r in additions}
    required_candidates = {}
    resource_by_id = {key(r): r for r in resources}
    exclusions = read(ROOT / 'Resources/Progression/exclusions.json')
    excluded = {key(r) for r in exclusions}
    references = {r['reference']: r for r in reference}
    rejected = {(key(r), r['sourceRevision'], r['replayRevision']) for r in read(OUT / 'replay-rejections.json')}
    by_title = collections.defaultdict(list)
    contexts, candidates, pending, selected, variant_holds = {}, {}, [], [], {}
    reviewed_bridges = []
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
        if row['official'] and not seasonal(row):
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
        if review_approved(review, row, context, references):
            lower, upper = references[review['afterReference']], references[review['beforeReference']]
            value = (lower['ordinal'] + upper['ordinal']) * 2.5
            reviewed_bridges.append({'row': row, 'context': context, 'reference': lower,
                             'placement': {'basis': 'reviewedVariant' if row['official'] else 'reviewedFan', 'reference': lower['reference'],
                                           'sourceURL': review['sourceURL'], 'position': value,
                                           'lower': lower['ordinal'] * 5, 'upper': upper['ordinal'] * 5,
                                           'sourceRevision': row['entry']['sourceRevision'],
                                           'replayRevision': context['replayRevision']},
                             'variantDifferences': [], 'review': review})
        nearest = sorted(anchor_rows, key=lambda a: (distance(context, a['context']), a['reference']['ordinal']))[:3]
        value, lower, upper, neighbours = estimate(context, anchor_rows)
        pending.append({'identity': row['entry']['identity'], 'sourceRevision': row['entry']['sourceRevision'],
                        'title': row['entry']['levelNameSnapshot'], 'pack': row['entry']['packNameSnapshot'],
                        'status': 'seasonal level withheld pending exact human difficulty review' if seasonal(row)
                            else 'needs human discovery/variant review', 'context': context,
                        'risks': risks(context) + variant_holds.get(ident, [])
                            + ([] if row['official'] else ['short or simple-looking solutions can hide difficult discovery']),
                        'diagnosticEstimate': {'position': value, 'lower': lower,
                            'upper': upper if row['official'] else 1000,
                            'meaning': 'Official route comparison with unknown discovery' if row['official'] else
                                'Execution comparison only; a replay cannot bound fan puzzle discovery difficulty',
                            'eligibleForGoldenPath': row['official'] and not seasonal(row)},
                        'comparisons': [{'reference': a['reference']['reference'], 'level': a['row']['entry']['levelNameSnapshot'],
                                         'ordinal': a['reference']['ordinal'], 'executionDistance': round(distance(context, a['context']), 3)}
                                        for a in nearest]})
    # Mainline official levels form the path. A fixed size must never force
    # unreviewed fan puzzles or seasonal levels into beginner practice.
    calibration_errors = sorted(abs(estimate(a['context'], [b for b in anchor_rows if b is not a])[0]
                                    - a['placement']['position']) for a in anchor_rows)
    calibration_deviation = calibration_errors[len(calibration_errors)//2]
    extras = []
    for ident, row in sorted(candidates.items()):
        if any(key(item['row']) == ident for item in selected): continue
        if not row['official'] or row['entry']['identity']['packID'] not in MAINLINE_PACKS:
            continue
        context = contexts[ident]
        visibility = resource_by_id[ident].get('interactiveVisibility')
        if visibility is None or not any(v['effect'] == 1 for v in visibility) or any(v['visibleFraction'] < .2 for v in visibility):
            continue
        if context['assignments'] > 40 or context['usedSkills'].get('builder', 0) > 24:
            continue  # Avoid padding the journey with long repetitive witnesses.
        value, lower, upper, neighbours = estimate(context, anchor_rows)
        lower = min(lower, max(0, value - calibration_deviation))
        upper = max(upper, min(1000, value + calibration_deviation))
        # Unknown official variants use the cautious bound, never the easiest
        # comparable replay. Keep the underlying measured score unchanged.
        value = max(upper, official_rank_floor(row))
        upper = max(upper, value)
        if value < 180 and (context['narrowActions'] or len(context['usedSkills']) > 3
                or context['jobChanges'] > 1
                or (len(context['usedSkills']) > 1 and context['exhaustedUsedSkills'] and context['savedAboveRequirement'] == 0)):
            continue  # Uncertain beginner placement needs a more forgiving route.
        extras.append({'row': row, 'context': context, 'reference': neighbours[0]['reference'],
            'placement': {'basis': 'solutionEstimate', 'reference': neighbours[0]['reference']['reference'],
                'sourceURL': SOURCE, 'position': value, 'lower': lower, 'upper': upper,
                'sourceRevision': row['entry']['sourceRevision'], 'replayRevision': context['replayRevision']},
            'variantDifferences': variant_holds.get(ident, []),
            'comparisons': [{'reference': n['reference']['reference'], 'position': n['placement']['position'],
                'distance': round(distance(context, n['context']), 4)} for n in neighbours]})
    selected.extend(extras)
    assert not any(key(item['row']) in excluded for item in selected)
    # Preserve the official port counterpart and promised official additions.
    # These do not authorise other fan levels with matching titles.
    for addition in additions:
        ident = key(addition)
        assert ident in required_candidates, f'Missing exact evidence for required addition: {ident}'
        row, context = required_candidates[ident]
        visibility = resource_by_id[ident].get('interactiveVisibility')
        assert visibility and any(v['effect'] == 1 for v in visibility)
        assert all(v['visibleFraction'] >= .2 for v in visibility)
        if addition['basis'] == 'userPlaytest':
            reference = references[addition['reference']]
            value = addition['minimumDemand']
            lower = upper = value
            neighbours = []
        elif addition['basis'] == 'reduxPortCounterpart':
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
            assert row['official'] and not seasonal(row), 'Unreviewed fan additions cannot enter the golden path'
            value = max(upper, official_rank_floor(row))
            upper = max(upper, value)
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
    calibration = []
    for anchor in anchor_rows:
        predicted, _, _, _ = estimate(anchor['context'], [a for a in anchor_rows if a is not anchor])
        calibration.append(abs(predicted - anchor['placement']['position']))
    # User playtest, 2026-10-11: Cellbash needs only one basher. Put it second,
    # immediately after Just Dig. This is a placement correction, not a
    # claim that the full human discovery-review checklist has been completed.
    cellbash = next({'row': row, 'context': contexts[key(row)], 'placement': {},
                     'variantDifferences': [], 'reference': {}} for row in candidates.values()
                    if row['entry']['identity'] == {
                        'engine': 'classic', 'packID': 'fan:lldb-547',
                        'levelID': 'Ji Hoon Heaven 1.DAT#5'})
    assert cellbash['row']['entry']['sourceRevision'] == '8d2daffec1cf660515ad4680e015d48b923b81b70afa10956729a179c81e3971'
    assert set(cellbash['context']['usedSkills']) == {'basher'}
    after = references['Gentle/Just_dig!.nxlv']
    cellbash['reference'] = after
    cellbash['placement'].update(basis='userPlaytest', sourceURL=SOURCE,
        sourceRevision=cellbash['row']['entry']['sourceRevision'],
        replayRevision=cellbash['context']['replayRevision'], position=7.5, lower=5.0, upper=10.0,
        reference=after['reference'],
        adjustment='User playtest 2026-10-11: single-basher practice as lesson 2, after Just Dig.')
    selected.append(cellbash)
    # The owner found the retail bridge route too tricky at journey lesson 32.
    # Keep its exact native witness, but defer it to established combination practice.
    careful = next(item for item in selected if item['row']['entry']['identity'] == {
        'engine': 'classic', 'packID': 'lemmings-LEVEL-120', 'levelID': '26:Fun:27:4:6'})
    careful['placement'].update(basis='userPlaytest', position=287.5, lower=280.0, upper=295.0,
        adjustment="User playtest 2026-10-14: Let's be careful out there is too tricky at lesson 32; move to later Intermediate combination practice.")
    # The owner also found Patience and Rainbow Island too early in Fun.
    # Keep their native routes and place them after more combination practice.
    for level_id, title, value in [
            ('11:Fun:12:0:7', 'Patience', 237.5),
            ('58:Tricky:29:2:0', 'Rainbow Island', 257.5),
            ('59:Tricky:30:1:7', 'The Crankshaft', 377.5)]:
        item = next(item for item in selected if item['row']['entry']['identity'] == {
            'engine': 'classic', 'packID': 'lemmings-LEVEL-120', 'levelID': level_id})
        item['placement'].update(basis='userPlaytest', position=value, lower=value - 7.5, upper=value + 7.5,
            adjustment=f'User playtest 2026-10-14: {title} is too early in Fun; move to {"Difficult" if value >= 360 else "Intermediate"} after more combination practice.')
    # The user's reported advanced routes cannot use an early estimated grade.
    # Match known variants and exact starting states, not a shared level title.
    safety = read(OUT / 'route-safety.json')['reportedLevels']
    by_identity = {key(row): row for row in safety}
    by_state = {row['initialHash']: row for row in safety}
    for item in selected:
        row = item['row']
        report = by_identity.get(key(row)) or by_state.get(row.get('initialHash'))
        if report:
            value = max(report['minimumDemand'], item['placement']['position'])
            item['placement'].update(basis='userPlaytest', position=value, lower=value, upper=value,
                adjustment=report['reason'])
    for item in reviewed_bridges:
        if item['row']['official'] or fills_reviewed_gap(item, selected):
            selected = [r for r in selected if key(r['row']) != key(item['row'])] + [item]
    assert sum(item['row']['official'] for item in selected) >= .8 * len(selected), 'The golden path must remain official-heavy'
    assert not any(not item['row']['official'] and item['placement']['basis'] == 'solutionEstimate' for item in selected)
    admitted = {key(item['row']): item for item in selected}
    for row in pending:
        if key(row) in admitted:
            item = admitted[key(row)]
            row['status'] = 'included with exact human review' if item['placement']['basis'] in ['reviewedFan', 'reviewedVariant'] else (
                'included from owner playtest' if item['placement']['basis'] == 'userPlaytest' else
                'included with port counterpart evidence; human variant review still needed' if item['placement']['basis'] == 'reduxPortCounterpart' else
                'included official variant with cautious estimated placement; human review still needed')
            row['placement'] = item['placement']
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
    plan = {'version': 'curriculum-9', 'poolSize': len(pool), 'targetSize': len(selected),
            'calibration': {'method': 'leave-one-reference-out', 'samples': len(calibration),
                'medianAbsolutePositionError': sorted(calibration)[len(calibration)//2],
                'meaning': 'Diagnostic error against community order; not a human playtest pass.'}, 'lessons': curriculum,
            'selectionPolicy': 'Official mainline spine and cautious official reserves. Seasonal levels require exact human review. Fan bridges require exact human discovery review and comparable reference bounds. No level-count quota or unreviewed fan estimates.',
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
        'At least 80% official levels; no fixed-size padding',
        'Unreviewed fan estimates never enter the golden path',
        'Seasonal levels need exact human difficulty review',
        'Reviewed fan bridges stay inside a real gap without introducing unpractised skills',
        'No fabricated human reviews or score clamps; official variant floors remain editorial',
        'Adjacent reference gaps are checked without changing any placement score'],
        'limits': plan['limits']})
    lines = ['# Oh My! All Lemmings! progression', '',
        f"{len(lessons)} Classic-mechanics lessons: {summary['official']} official levels and {summary['fan']} entries from fan archives.", '',
        f"[Redux's community order]({SOURCE}) supplies the official reference spine. Mainline official levels take priority. Unmatched official variants use the cautious upper estimate and a retail-rank floor. Original measured replay scores remain unchanged.", '',
        'The path has no level-count quota. Unreviewed fan and NeoLemmix levels remain in the review queue, even when their artwork or winning replay looks easy. A short solution cannot establish how hard the trick is to discover. Reviewed fan bridges must fit between nearby official lessons, stay within their human-reviewed difficulty bounds and use previously practised skills. They fill real gaps rather than add variety.', '',
        'Xmas and Holiday levels are withheld unless an exact-version human difficulty review supports their placement. Seasonal rank names, visual simplicity and Redux title counterparts do not establish suitability in Classic physics.', '',
        'Cellbash remains lesson 2 from the owner’s single-basher playtest. Going their separate ways is the official Macintosh exclusive delivered through a Classic fan archive. Its Redux counterpart and conversion differences are recorded. Neither exception authorises unrelated fan estimates.', '',
        'The owner’s reported walls remain deferred: Patience and Rainbow Island to Intermediate, Let’s be careful out there to later Intermediate, and The Crankshaft to Difficult. Time waits for no Lemming and This Corrosion retain their late-Expert floors. Come back! and Stop, Block and Blow are withheld with other unreviewed fan routes.', '',
        '## Evidence limits', '',
        'Every lesson requires exact source resources and a matching winning replay. A native win proves one route, not novice discovery or the easiest solution. Official estimates remain uncertain. The curriculum records leave-one-reference-out calibration error and variant differences. These diagnostics do not certify a smooth human difficulty curve.', '',
        'For fan or seasonal review, record the exact source and replay revisions, an ordinary human completion, discovery notes, hints, retries and recovery resources. Compare nearby reference levels played by the same person. Do not infer a human review from machine analysis.', '',
        '## Saved journeys', '',
        'Older built-in queues migrate to the current path. Past visits, completed records, ownership and run identity remain intact. Unvisited retired fan and seasonal entries leave the queue. Reported official walls move to their later positions. Custom playlists and newer saved versions remain unchanged.', '',
        'The bundled path uses Classic mechanics. Lemmings 2 and Lemmings 3 keep their existing campaigns and saved queues. Direct NeoLemmix playlist routing remains unsupported. No untested bridge is substituted for that gap.', '',
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
