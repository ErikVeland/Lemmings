"""Check the published Golems bytes behind the phase-corrected native routes."""

import hashlib
import json
import re
from pathlib import Path

from decode_golems_replays import decode, source_bytes


ROOT = Path(__file__).resolve().parents[2]
CACHE = ROOT / ".build/learning-evidence"
EVIDENCE = ROOT / "Artifacts/DifficultyEvaluation"


def main():
    records = []
    for name in ("classic-golems-phase-shift-alternatives.json",
                 "classic-golems-phase-shift-targeted.json",
                 "classic-golems-phase-shift-second.json",
                 "classic-golems-phase-shift-third.json",
                 "classic-golems-phase-shift-fourth.json",
                 "classic-golems-phase-shift-fifth.json",
                 "classic-golems-phase-shift-sixth.json",
                 "classic-golems-phase-shift-seventh.json",
                 "classic-golems-mining-rule.json",
                 "classic-golems-current-source-recheck.json",
                 "classic-golems-hatch-recovery.json",
                 "classic-golems-direct-digger-recovery.json"):
        records.extend(json.loads((EVIDENCE / name).read_text())["records"])
    records.extend(json.loads((EVIDENCE / "classic-golems-hatch-recovery.json").read_text())
                   ["additionalWinningInputs"])
    manifest = json.loads((CACHE / "lldb-all-records/manifest.json").read_text())
    matched = unmatched = translated = 0
    for record in records:
        source_identity = record.get("sourceOriginIdentity", record["identity"])
        source = [item for item in manifest if item["identity"] == source_identity
                  and item["sourceReplaySHA256"] == record["sourceReplaySHA256"]]
        assert len(source) == 1, record["identity"]
        source = source[0]
        assert source["url"] == record["sourceURL"]
        assert source["sourceSaved"] == record["sourceHeaderSaved"]
        assert source["sourceTicks"] == record["sourceHeaderTicks"]
        page_name = "-".join(re.search(r"/level/(\d+)/(\d+)", source["url"]).groups()) + ".html"
        raw = None
        for page in CACHE.glob("lldb-*/" + page_name):
            try:
                candidate = source_bytes(page, source["recordIndex"])
            except IndexError:
                continue
            if hashlib.sha256(candidate).hexdigest() == source["sourceReplaySHA256"]:
                raw = candidate
                break
        assert raw is not None, record["identity"]
        replay_data = (ROOT / record["replayPath"]).read_bytes()
        assert hashlib.sha256(replay_data).hexdigest() == record["nativeReplaySHA256"]
        replay = json.loads(replay_data)
        terminal_translation = record.get("terminalAbandonAsNuke", False)
        derived = replay["events"] == decode(
            raw, abandon_as_nuke=terminal_translation, native_tick_offset=-1)
        assert record["nativeTickOffsetFromSource"] == -1
        if terminal_translation:
            assert raw[-3] == 10 and derived
            assert not record["sourceActionDerivationVerified"]
            translated += 1
        elif derived:
            assert record["sourceActionDerivationVerified"]
            matched += 1
        else:
            assert record["title"] == "Snow Lev 8"
            assert not record["sourceActionDerivationVerified"]
            unmatched += 1
    assert (matched, unmatched, translated) == (147, 1, 2)
    print(f"Verified {matched} direct source mappings and {translated} terminal translations; "
          f"{unmatched} native win has open source provenance")


if __name__ == "__main__":
    main()
