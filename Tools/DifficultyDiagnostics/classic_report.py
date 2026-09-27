"""Write inspectable coverage and playlist reports from the native Classic audit."""
import collections
import csv
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
rows = json.loads((root / "audit.json").read_text())
playlist = json.loads((root / "playlist.json").read_text())
failures = json.loads((root / "failures.json").read_text())


def identity(entry):
    value = entry["identity"]
    return value["engine"], value["packID"], value["levelID"]


by_id = {identity(row["entry"]): row for row in rows}
ordered = [by_id[identity(entry)] for entry in playlist["entries"]]
official = [row for row in rows if row["official"]]
assert [identity(r["entry"]) for r in ordered if r["official"]] == [identity(r["entry"]) for r in official]
assert len({identity(r["entry"]) for r in ordered}) == len(ordered)
assert all(r["playable"] for r in ordered)
assert len({r["initialHash"] for r in ordered if not r["official"]}) == sum(not r["official"] for r in ordered)
assert not ({r["initialHash"] for r in ordered if not r["official"]} & {r["initialHash"] for r in official})


def score(row):
    return row["profile"]["overallScore"]


def label(row):
    entry = row["entry"]
    return f'{entry["packNameSnapshot"]} / {entry["levelNameSnapshot"]}'


grades = ["Beginner", "Easy", "Moderate", "Tricky", "Challenging", "Hard", "Very Hard", "Expert", "Extreme", "Master"]
fields = ["position", "pack", "level", "official", "score", "grade", "confidence", "playable", "concepts", "issue", "pack_id", "level_id"]
for filename, data in [("all-levels.csv", rows), ("playlist.csv", ordered)]:
    with (root / filename).open("w", newline="") as stream:
        writer = csv.writer(stream)
        writer.writerow(fields)
        for index, row in enumerate(data, 1):
            entry, profile = row["entry"], row["profile"]
            writer.writerow([index, entry["packNameSnapshot"], entry["levelNameSnapshot"], row["official"],
                             round(score(row), 2), grades[min(9, int(score(row) // 100))], profile["confidence"], row["playable"],
                             ";".join(profile["detectedTechniques"]), row.get("issue", ""),
                             entry["identity"]["packID"], entry["identity"]["levelID"]])

gaps = []
previous = None
bridges = []
for row in ordered:
    if not row["official"]:
        bridges.append(row)
        continue
    if previous is not None:
        path = [previous, *bridges, row]
        direct = score(row) - score(previous)
        largest = max(score(b) - score(a) for a, b in zip(path, path[1:]))
        if direct > 100 or bridges:
            gaps.append({"from": label(previous), "to": label(row), "direct_increase": round(direct, 2),
                         "largest_playlist_increase": round(largest, 2), "bridges": [label(b) for b in bridges],
                         "estimated_bridges": sum(b["profile"]["confidence"] == "low" for b in bridges),
                         "unresolved_numeric_gap": largest > 100})
    previous, bridges = row, []
(root / "gaps.json").write_text(json.dumps(gaps, indent=2) + "\n")

confidence = collections.Counter(r["profile"]["confidence"] for r in rows)
fans = [r for r in ordered if not r["official"]]
unresolved = sum(g["unresolved_numeric_gap"] for g in gaps)
improved = sum(bool(g["bridges"]) and g["largest_playlist_increase"] < g["direct_increase"] for g in gaps)
lines = ["# Classic Complete + Fan Bridges", "",
         f"The saved playlist contains **{len(ordered)} levels: {len(official)} official Classic levels and {len(fans)} fan bridges**.", "",
         "Every official level occurs once, in the application's campaign order. The playlist is not limited to 100 entries.", "",
         "To play the complete saved sequence, set Settings → Gameplay → Level Select to All. "
         "The current Player Unlocked setting blocks playlists that contain locked campaign levels. "
         "This audit does not change that preference or campaign progress.", "",
         "## Evidence and limits", "",
         f"Audited {len(rows)} levels: {len(official)} official and {len(rows)-len(official)} fan levels. "
         f"{sum(r['playable'] for r in rows)} passed native loading, rendering and simulation construction.", "",
         f"Confidence: {confidence['high']} high, {confidence['medium']} medium, {confidence['low']} low. "
         "Winning replays were checked with a budget of ten timing perturbations each.", "",
         f"{sum(r['profile']['confidence']=='low' for r in fans)} selected fan bridges have metadata-only estimates. "
         "These are provisional placements, not demonstrated measures of human puzzle difficulty or proof that the levels are solvable.", "",
         f"The inserted levels reduce the largest estimated score step in {improved} official transitions. "
         f"{sum(r['profile']['confidence']!='low' for r in fans)} selected fan levels have validated native winning replays.", "",
         f"{unresolved} transitions still exceed a 100-point score increase. "
         "The installed corpus and available replay evidence do not support claiming every gap is closed.", "",
         "Fan copies with the same initial simulation hash as an official level are excluded. "
         "Repeated fan copies are excluded from selection. Official repeats remain because this playlist retains the complete campaigns.", "",
         "Scope: all Classic campaigns and Classic-format fan archives discovered by the existing app loaders. "
         "Standalone NeoLemmix levels and Lemmings 2/3 are outside this Classic playlist. "
         "The earlier NeoLemmix audit remains separate because those levels lack playable catalogue routes.", "",
         "Source: `.build/local/Ultimate Lemmings.app/Contents/Resources`, downloaded fan packs, bundled solutions and recorded Classic routes. "
         "The source snapshot manifest is `.build/classic-progression-audit/source-manifest.sha256`.", "",
         f"Pack/decode failures: {len(failures)}. Per-level load or replay issues: {sum(bool(r.get('issue')) for r in rows)}. "
         "See `failures.json` and `all-levels.csv`.", "",
         "## Official coverage", "", "| Campaign | Levels |", "| --- | ---: |"]
for name, count in collections.Counter(r["entry"]["packNameSnapshot"] for r in official).items():
    lines.append(f"| {name} | {count} |")
lines += ["", "## Files", "",
          "- `playlist.json`: native saved playlist, including catalogue revisions and source fingerprints.",
          "- `playlist.csv`: full order, grades' underlying scores and confidence.",
          "- `all-levels.csv` and `audit.json`: every audited level and its evidence.",
          "- `selections.json`: graph-selection reasons and costs.",
          "- `gaps.json`: original jumps, inserted bridges and remaining jumps.", "",
          "## Inserted fan levels", "", "| Position | Fan level | Score | Confidence |", "| ---: | --- | ---: | --- |"]
for index, row in enumerate(ordered, 1):
    if not row["official"]:
        lines.append(f"| {index} | {label(row).replace('|', '/')} | {score(row):.1f} | {row['profile']['confidence']} |")
lines += ["", "## Largest remaining jumps", "", "| From | To | Largest step | Fan bridges |", "| --- | --- | ---: | ---: |"]
for gap in sorted(gaps, key=lambda g: -g["largest_playlist_increase"])[:20]:
    lines.append(f"| {gap['from'].replace('|', '/')} | {gap['to'].replace('|', '/')} | {gap['largest_playlist_increase']:.1f} | {len(gap['bridges'])} |")
(root / "README.md").write_text("\n".join(lines) + "\n")
print(f"Verified {len(ordered)} unique catalogue entries; all {len(official)} official anchors retained; {unresolved} unresolved jumps.")
