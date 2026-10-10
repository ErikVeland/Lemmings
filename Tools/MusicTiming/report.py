#!/usr/bin/env python3
"""Build the reviewable report from the measured timing catalogue."""
from collections import Counter
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def cell(value):
    return str(value).replace('|', '\\|').replace('\n', ' ')


def main():
    data = json.loads((ROOT / 'Resources/Music/timing.json').read_text())
    rows = data['variants']
    modules = [r for r in rows if r['tracker']]
    changing = [r for r in modules if len(r['tracker']['segments']) > 1]
    bpm = sum(r['bpmStatus'] == 'estimated-stable' for r in rows)
    bars = sum(r['barStatus'] == 'estimated-stable' for r in rows)
    meters = Counter(r['beatsPerBar'] for r in rows if r['barStatus'] == 'estimated-stable')
    reasons = Counter(reason for r in rows for reason in r['reviewReasons'])
    formats = Counter(Path(r['path']).suffix for r in rows)
    lines = [
        '# Music timing audit', '',
        f"Generated {data['generatedAt']} from the installed playable catalogue.", '',
        f"**{len(rows)} versions across {len({r['trackID'] for r in rows})} track identities analysed.** "
        f"{bpm} have stable BPM estimates and {bars} have stable bar estimates. "
        f"{len(rows) - bpm} BPM estimates and {len(rows) - bars} bar estimates need review. "
        f"Analysis failures: {len(data['failures'])}.", '',
        'These are automated estimates. No listening review or manual downbeat correction has been completed. '
        'A regular detected pulse can still have the wrong musical beat or bar phase.', '',
        '## Coverage', '',
        'Each catalogue version is measured separately. Ports and remixes do not inherit the tempo of another arrangement. '
        'Archive originals, conversion inputs, and `By Track` symlink duplicates are outside this playable-file count.', '',
        f"Formats: {', '.join(f'{count} {ext}' for ext, count in sorted(formats.items()))}.", '',
        '| Catalogue game | Versions | Stable BPM estimates | Stable bar estimates |',
        '| --- | ---: | ---: | ---: |',
    ]
    for game in sorted({r['game'] for r in rows}):
        group = [r for r in rows if r['game'] == game]
        lines.append(f"| {game} | {len(group)} | {sum(r['bpmStatus'] == 'estimated-stable' for r in group)} | "
                     f"{sum(r['barStatus'] == 'estimated-stable' for r in group)} |")
    lines += ['', '## What the numbers mean', '',
        '`baseBPM` is the detected musical pulse at normal playback speed. It is not the gameplay speed multiplier. '
        'Speed pitch changes do not change this tempo. DJ tempo matching scales the effective BPM separately.', '',
        'Native modules also have an exact tracker clock. For four rows per pulse, '
        '`fourRowBPM = tickBPM × 6 / ticksPerRow`. Four rows do not establish a musical beat, meter, or downbeat. '
        'The report preserves this source clock beside the detected pulse instead of treating them as interchangeable.', '',
        'BPM values below use one decimal for readability. The JSON retains three decimals, '
        'but that precision does not imply measurement accuracy. The range is the 10th–90th percentile '
        'of local tempo estimates, not a statistical confidence interval.', '',
        '## Method and acceptance rules', '',
        'Recordings are decoded completely by FFmpeg to mono 22,050 Hz PCM. '
        'Modules are rendered through the shipped ProTracker player for one traversal, including any opening section. '
        'The scanner records tempo commands and the loop start. It rejects traversals longer than 600 seconds. '
        'No scanned module exceeded that limit or used an unsupported timing command.', '',
        '[Beat This!](https://github.com/CPJKU/beat_this) `final0`, package '
        f"`{data['method']['beatThisVersion']}`, supplies beat and downbeat positions. "
        'The minimal postprocessor has a 20 ms timestamp resolution. '
        'The model runs locally. Its first use downloads the model weights.', '',
        'The summary uses median tempo over 16-beat spans where possible. '
        'It excludes spans outside 70–130% of the median beat period. '
        'This reduces timestamp quantisation without forcing every file to one assumed BPM.', '',
        'A stable BPM estimate requires at least 32 beats, at least 12 seconds of audio, '
        '80% beat coverage, 92% regular beat intervals, and at most 4% spread between local tempo percentiles. '
        'Regular intervals are within 10% of the median period. '
        'Modules with clock changes need review. A detected module pulse must also agree with the opening '
        'four-row clock, half that clock, or twice that clock within 3%.', '',
        'A stable bar estimate also requires at least eight complete bars and 90% agreement on beats per bar. '
        'Accepted candidate meters contain 2–12 beats per bar. '
        'Uncertain candidates remain visible below, but the DJ does not use them for bar alignment.', '',
        'Stable meter candidates: ' + ', '.join(f'{count} with {meter} beats per bar' for meter, count in sorted(meters.items())) + '.', '',
        'These checks favour conservative automatic use. They do not prove meter or phrase structure. '
        'Waltzes, pickups, sparse arrangements, and half/double-time ambiguity still need listening review. '
        'No 8-bar or 16-bar phrase labels are inferred.', '',
        '## Native modules with clock changes', '',
        f'{len(changing)} modules contain more than one tracker tempo segment. '
        'These keep timed fades and do not use fixed-BPM matching. '
        'Each entry below lists four-row BPM at source seconds. The JSON also records order, row, tick tempo, and speed.', '',
        '| File | Four-row BPM @ seconds |', '| --- | --- |']
    for row in changing:
        segments = ', '.join(f"{s['fourRowBPM']:.1f} @ {s['seconds']:.2f}" for s in row['tracker']['segments'])
        lines.append(f"| `{cell(row['path'])}` | {segments} |")
    lines += ['', '## Review queue', '',
        'Reason counts overlap. One file can need review for several reasons.', '',
        '| Reason | Versions |', '| --- | ---: |']
    lines += [f'| `{reason}` | {count} |' for reason, count in reasons.most_common()]
    silent = [r for r in rows if r['baseBPM'] is None]
    lines += ['', f'{len(silent)} versions have no reliable pulse estimate:', '']
    lines += [f"- `{row['path']}`" for row in silent]
    lines += ['', '## How DJ mixing uses this data', '',
        'Classic, Lemmings 2, and Lemmings 3 use the shared DJ player. '
        'The player verifies the current audio hash before using a timing grid. '
        'Packaging filters timing data to the installed catalogue and records hashes for converted playback files.', '',
        'Stable beat grids provide source-position timing and nearby tempo matching, within the existing 8% limit. '
        'A grid marked for review does not trigger automatic beat or bar matching. '
        'Without analysed timing, native modules retain their existing four-row clock fallback. '
        'Recordings without timing retain a timed gain fade.', '',
        'Bar alignment requires matching candidate meters and effective BPM within 1%. '
        'The incoming first downbeat must be within two seconds. The outgoing start wait is capped at four seconds. '
        'A short incoming pickup plays silently, then the gain fade covers whole measured outgoing bars.', '',
        'The planner also checks both local grids across the complete fade. '
        'Each bar must be within 4% of the expected period, and corresponding boundaries must agree within 80 ms. '
        'Missing boundaries, irregular local bars, long introductions, and incompatible grids keep the timed fade. '
        'The player does not extrapolate beyond the last analysed beat.', '',
        'This is approximate musical alignment. Beat detection uses 20 ms frames, and audio processing latency '
        'and main-actor scheduling can add error. The gain envelopes are not sample-accurate or phrase-aware. '
        'Loop positions follow the source duration and the native module loop start. '
        'No listening test of every possible transition has been completed.', '',
        '## Validation and reproduction', '',
        'The timing suite checks catalogue coverage, audio hashes, measured beat positions, tempo scaling, '
        'loop positions, pickups, whole bars, uncertain grids, local irregular bars, and packaging. '
        'The playback suite checks real audio loading, timing routing, stale-grid rejection, '
        'tempo-unit settings, speed pitch, all three game journeys, and suspended fades.', '',
        'Run instructions and dependencies are in [Tools/MusicTiming](../Tools/MusicTiming/README.md). '
        'Run `zsh Scripts/run-music-timing-tests.sh`, `zsh Scripts/run-music-catalogue-tests.sh`, '
        'and `zsh Scripts/run-adaptive-dj-playback-tests.sh "$PWD/Sources/Music"` after changes.', '',
        '## Sources and provenance', '',
        '- [Playable catalogue](../Resources/Music/catalogue.json): version identities and source paths.',
        '- [Timing data](../Resources/Music/timing.json): per-file SHA-256, all beat/downbeat timestamps, and review reasons.',
        '- [Source audit](MusicSourceAudit.md): collection provenance and known collection limits.',
        '- [Native ProTracker implementation](../Sources/NxlvKit/ProTrackerModule.swift): module audio and tracker timing.',
        '- [Beat This! implementation](https://github.com/CPJKU/beat_this): beat/downbeat detector.', '',
        f"Catalogue SHA-256: `{data['catalogueSHA256']}`.", '',
        f"Model SHA-256: `{data['method']['modelSHA256']}`.", '',
        'The timing JSON records decoder and dependency versions. '
        'Audio, model, decoder, dependency, or renderer changes invalidate the corresponding cache.', '',
        '## Every playable version', '',
        '**Stable** means the automated checks passed. **Review** means the estimate is retained for inspection only. '
        'The beats/bar column is a candidate meter, including rows marked Review. '
        'The clock column applies only to native modules. A range there means the module changes clock.', '']
    for game in sorted({r['game'] for r in rows}):
        lines += [f'### {game}', '',
                  '| Track / port | Source file | Estimated BPM (p10–p90) | Four-row clock | Beats/bar | BPM | Bars |',
                  '| --- | --- | ---: | ---: | ---: | --- | --- |']
        for row in sorted((r for r in rows if r['game'] == game), key=lambda r: (r['trackID'], r['path'])):
            estimate = '—' if row['baseBPM'] is None else f"{row['baseBPM']:.1f} ({row['bpmRange'][0]:.1f}–{row['bpmRange'][1]:.1f})"
            clock = '—'
            if row['tracker']:
                values = [s['fourRowBPM'] for s in row['tracker']['segments']]
                clock = f'{min(values):.1f}' if min(values) == max(values) else f'{min(values):.1f}–{max(values):.1f}'
            status = lambda name: 'Stable' if row[name] == 'estimated-stable' else 'Review'
            lines.append(f"| {cell(row['title'])} / {cell(row['port'])} | `{cell(row['path'])}` | {estimate} | {clock} | "
                         f"{row['beatsPerBar'] or '—'} | {status('bpmStatus')} | {status('barStatus')} |")
        lines.append('')
    (ROOT / 'Documentation/MusicTiming.md').write_text('\n'.join(lines))
    print(f'Reported {len(rows)} versions: {bpm} stable BPM estimates, {bars} stable bar estimates')


if __name__ == '__main__':
    main()
