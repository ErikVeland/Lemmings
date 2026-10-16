#!/usr/bin/env python3
"""Write a source-linked Phase 2 report from retained baseline output."""
import argparse
import json
from pathlib import Path
import re
import statistics


def make_report(base):
    source = json.loads((base / "source-manifest.json").read_text())
    assets = json.loads((base / "assets-manifest.json").read_text())
    environment = json.loads((base / "results/environment.json").read_text())
    simulation = json.loads((base / "results/simulation.json").read_text())
    sizes = json.loads((base / "sizes.json").read_text())
    rows = []
    for row in simulation:
        samples = row["samples"]
        wall = statistics.median(sample["wallSeconds"] for sample in samples)
        cpu = statistics.median(sample["cpuSeconds"] for sample in samples)
        sample = row["allocationSample"]
        rates = [item["ticks"] / item["wallSeconds"] for item in samples]
        count = sample["allocations"] / sample["ticks"]
        scope = f'{sample["width"]} × {sample["height"]}, population {sample["population"]}, {sample["ticks"]} ticks'
        if not sample.get("recordedOutcomeMatches", True):
            scope += "; recorded outcome FAIL"
        rows.append(("Simulation", row["scenario"]["id"],
                     f'{sample["ticks"] / wall:,.0f} ticks/s; {wall * 1000:.3f} ms wall; {cpu * 1000:.3f} ms CPU; {count:.3f} allocations/tick',
                     scope + f'; sample range {min(rates):,.0f}–{max(rates):,.0f} ticks/s'))
    text = (base / "results/xctest.log").read_text()
    measurements = {}
    pattern = r"test(\w+)\]' measured \[([^]]+)\].*?values: \[([^]]+)\]"
    for name, metric, values in re.findall(pattern, text):
        measurements.setdefault(name, {})[metric] = [float(value.strip()) for value in values.split(",")]
    for name, values in measurements.items():
        clock = values.get("Clock Monotonic Time, s")
        if not clock:
            continue
        divisor = 100 if name.startswith("Decode") else 1
        cpu = statistics.mean(values["CPU Time, s"]) * 1000 / divisor
        memory = statistics.mean(values["Memory Peak Physical, kB"]) / 1000
        rows.append(("XCTest", name, f'{statistics.mean(clock) * 1000 / divisor:.3f} ms wall; {cpu:.3f} ms CPU; {memory:.2f} MB process peak',
                     "10 iterations; warmed filesystem; one operation"))
    if (base / "audio.json").exists():
        for name, values in json.loads((base / "audio.json").read_text()).items():
            rows.append(("Offline audio", name, f"{statistics.median(values):.3f} ms/block", "1,024 frames at 44,100 Hz; seven samples; no audio engine started"))
    if (base / "crt.json").exists():
        for name, values in json.loads((base / "crt.json").read_text()).items():
            rows.append(("Shipping CRT", name,
                         f'{statistics.median(values["cpuSubmitMS"]):.3f} ms CPU submit; {statistics.median(values["gpuMS"]):.3f} ms GPU; {statistics.median(values["wallMS"]):.3f} ms completion',
                         "640 × 320 Classic source; 1280 × 640 RGBA16 output; no window; seven × 32 frames; identical repeated pixels"))
    for row in sizes.get("snapshotHost", sizes.get("snapshotArm64", [])):
        rows.append(("Binary size", row["name"], f'{row["fileBytes"] / 1_000_000:.3f} MB', "frozen source; arm64; -O; unstripped shell build"))
    for row in sizes["build83ReferenceOnly"]:
        for architecture, count in row.get("sliceFileBytes", {}).items():
            rows.append(("Historical binary", row["name"] + " / " + architecture,
                         f"{count / 1_000_000:.3f} MB", "existing build 83 slice; extracted for sizing; not compiled"))
    for name, count in sorted(sizes["build83ResourcesByDirectory"].items(), key=lambda item: -item[1]):
        rows.append(("Bundle resources", name, f"{count / 1_000_000:.3f} MB", "existing build 83 directory reference; not a new package"))
    for extension, count in sorted(sizes["build83ResourcesByExtension"].items(), key=lambda item: -item[1]):
        rows.append(("Resource file type", extension, f"{count / 1_000_000:.3f} MB", "build 83 logical file lengths; not ZIP size or allocated disk space"))
    for name in ["Interactive cold launch", "Displayed frame pacing / Precision Zoom / CoverFlow", "Physical iOS / iPadOS / Duo / tvOS thermals", "Current-source Intel binary", "Cross-device energy and leaks"]:
        rows.append(("Unmeasured", name, "Not measured", "See limitations below"))
    output = [
        "# Ultimate Lemmings — Phase 2 performance baseline",
        "",
        "Phase 2 stops before optimisation. Engine and decoder source were not changed. Existing working-tree edits are included in the fixed source snapshot.",
        "",
        f'- Source: `{source["head"]}`, branch `{source["branch"]}`.',
        f'- Source snapshot: `{source["treeSHA256"]}` ({len(source["files"]):,} files).',
        f'- Asset snapshot: `{assets["treeSHA256"]}` ({len(assets["files"]):,} files).',
        f'- Resource origin: `{assets["origins"]["resources"]}`. NeoLemmix origin: `{assets["origins"]["neo"]}`. The external style set is separate from the packaged style subset.',
        f'- Host: {environment["architecture"]}, {environment["os"]}. Initial load average: {environment["loadAverage"]}.',
        f'- Swift: {environment["swift"].strip()}.',
        '- Simulations: one warm-up, seven uninstrumented samples and one separate allocation sample. Short routes use a fixed batch targeting at least 100 ms of tick work per sample; times are normalised per route. Decode, initial-state preparation and hashing are outside the tick timer.',
        '- Allocation counts cover successful malloc-family events on the benchmark thread. They exclude ARC operations, direct VM allocations and other threads.',
        '- The Classic corpus worker was paused during the timing run. External host activity was not controlled.',
        "",
        "## Baseline table",
        "",
        f'Sources: [simulation]({base / "results/simulation.json"}), [XCTest]({base / "results/xctest.log"}), [audio]({base / "audio.json"}), [CRT]({base / "crt.json"}), [sizes]({base / "sizes.json"}).',
        "",
        "| Area | Metric | Baseline | Scope |",
        "|---|---|---|---|",
        *["| " + " | ".join(row) + " |" for row in rows],
        "",
        "Peak memory is the XCTest process footprint, not memory attributable only to the named operation. Decoder values are divided by 100 operations per iteration. CPU texture submission does not measure GPU frame time or displayed fps.",
        "Sample ranges retain host scheduling and frequency noise. Assess small gains with paired repeated runs under comparable load.",
        "",
        "## Corpus results",
        "",
    ]
    for engine in ["neo", "l2", "l3"]:
        path = base / f"{engine}-corpus.json"
        if path.exists():
            records = json.loads(path.read_text())
            errors = [row for row in records if row.get("error")]
            mismatches = [row for row in records if not row.get("error") and not row["recordedOutcomeMatches"]]
            output.append(f'- {engine}: {len(records)} records, {len(errors)} preparation/input failures, {len(mismatches)} recorded-outcome mismatches. [Per-level results]({path}).')
            for row in errors + mismatches:
                output.append(f'  - Level {row["level"]}: {row.get("error") or "recorded outcome differs"}.')
    classic = base / "classic-corpus/summary.json"
    if classic.exists():
        summary = json.loads(classic.read_text())
        output.append(f'- Classic fan: `{json.dumps(summary.get("fan", {}), sort_keys=True)}`. [Per-level hashes and status]({base / "classic-corpus/levels.jsonl"}).')
        current = [json.loads(line) for line in (base / "classic-corpus/levels.jsonl").read_text().splitlines()]
        previous = {row["source"]: row for row in map(json.loads, (base / "source/Documentation/ReleaseReadiness/2.0-build83/classic-fan-build83-replay-levels.jsonl").read_text().splitlines()) if row["collection"] == "fan"}
        fan = [row for row in current if row["collection"] == "fan"]
        changed = sum((row.get("initialHash"), row["status"]) != (previous[row["source"]].get("initialHash"), previous[row["source"]]["status"]) for row in fan)
        output.append(f'- Classic: {changed} differences in per-level initial hashes/status versus the retained build 83 inventory. Final hashes are available for {sum(bool(row.get("outcomeHash")) for row in fan)} fan levels. The failed replay levels do not acquire a passing final-state proof.')
    l3 = json.loads((base / "l3-corpus.json").read_text())
    for row in l3:
        if not row.get("error") and not row["recordedOutcomeMatches"]:
            fixture = json.loads((base / f'source/Tests/Lemmings3CompletionTests/Fixtures/{int(row["level"]):03d}.json').read_text())
            output.extend(["", f'L3 level {row["level"]}: observed {row["saved"]} saved at tick {row["ticks"]}; the fixture expects {fixture["expected"]["saved"]} saved at tick {fixture["expected"]["ticks"]}. Fixtures and release evidence were not rebased.'])
    output.extend([
        "",
        f'The existing L3 replay verifier also rejects level 107. [Verifier log]({base / "logs/l3-reference-107.log"}). This is a baseline failure, not an optimisation regression.',
        "",
        "NeoLemmix has no external .nxrp replay files in the searched local corpus locations. The 794-level evidence uses the existing 256-tick plus 64-tick Codable-continuation contract. Simulation measurements use up to 4,096 no-input ticks, plus one explicitly scripted spawn/nuke stress trace. Neither establishes winning-replay compatibility.",
        "",
        "## Checks and limitations",
        "",
        "- The Metal test initially failed inside the filesystem sandbox because no MTLDevice was available. It passed offscreen with GPU access and exact texture readback. The complete final XCTest log records the final outcome.",
        "- No normal app was launched. Its startup path can request full screen and use player services. Interactive cold launch and its Instruments trace remain unmeasured.",
        "- GPU presentation, menu transitions, sustained energy, thermal pressure and device behaviour remain unmeasured. The shipping CRT pass benchmark uses completed command buffers and GPU timestamps, without a display. The XCTest texture test measures CPU composition/upload only.",
        "- Current-source builds use arm64 only. Existing build 83 arm64/x86_64 segment sizes are retained as historical references in sizes.json. No Intel or universal app was compiled.",
        "- Results do not certify release readiness, complete corpus compatibility or absence of leaks.",
        f'- Classic/L2/L3 use the existing replay-gate hash definitions. L2/L3 do not serialize every private runtime field. These are gate-state digests, not a complete bytewise runtime comparison. [L2 digest]({base / "source/Sources/NxlvKit/Lemmings2ReplayWitness.swift"}:320), [L3 digest]({base / "source/Tools/Lemmings3Completion/Replay.swift"}:29).',
        "",
        "## Evidence and repeatability",
        "",
        f'- [Simulation samples]({base / "results/simulation.json"}) and [environment/tool hashes]({base / "results/environment.json"}).',
        f'- [XCTest clock, CPU and memory metrics]({base / "results/xctest.log"}).',
        f'- [Binary and resource sizes]({base / "sizes.json"}).',
        f'- [Trace commands]({base / "traces/commands.json"}) and trace logs under `{base / "logs"}`.',
        f'- The four Time Profiler traces export successfully. The time-limited captures terminate their benchmark processes when the limit expires. The Allocations capture failed to attach; its saved container does not establish usable allocation profiling. [Allocations failure]({base / "logs/trace-allocations.log"}).',
        f'- [Source manifest]({base / "source-manifest.json"}) and [asset manifest]({base / "assets-manifest.json"}).',
        '- The maintained harness and measurement boundaries are in `Tools/PerformanceBaseline/README.md`.',
        "",
    ])
    return "\n".join(output)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("baseline", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    args.output.write_text(make_report(args.baseline.resolve()))
