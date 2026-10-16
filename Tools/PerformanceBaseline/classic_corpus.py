#!/usr/bin/env python3
"""Add baseline output fields to a generated copy of the existing Classic audit."""
import argparse
from pathlib import Path


def generate(source, output):
    text = (source / "Tools/ClassicValidation/main.swift").read_text()
    changes = {
        '    var initialHash: String? = nil': '    var outcomeHash: String? = nil\n    var ticks: Int? = nil\n    var saved: Int? = nil\n    var initialHash: String? = nil',
        'let candidateSolutions = fixtureRoot.appendingPathComponent("Artifacts/LearningJourney/candidate-solutions.json")':
            'let candidateSolutions = URL(fileURLWithPath: ProcessInfo.processInfo.environment["BASELINE_CANDIDATES"] ?? fixtureRoot.appendingPathComponent("Artifacts/LearningJourney/candidate-solutions.json").path)',
        '                    row.status = "winning-replay"; row.witness = path; break':
            '                    row.outcomeHash = first.stateHash; row.ticks = first.ticks; row.saved = first.saved\n                    row.status = "winning-replay"; row.witness = path; break',
        '            row.status = "rendered-and-smoke-tested-only"':
            '            row.outcomeHash = ClassicDOSReplayRecorder.stateHash(of: simulation)\n            row.ticks = simulation.tickCount; row.saved = simulation.savedCount\n            row.status = "rendered-and-smoke-tested-only"',
    }
    for before, after in changes.items():
        if text.count(before) != 1:
            raise ValueError(f"Audit source changed. Review instrumentation anchor: {before}")
        text = text.replace(before, after)
    output.write_text(text)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    generate(args.source, args.output)
