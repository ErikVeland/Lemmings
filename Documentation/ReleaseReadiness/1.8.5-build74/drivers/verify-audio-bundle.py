import hashlib, json, sys
from pathlib import Path
repo = Path.cwd()
res = Path(sys.argv[1]) / "Contents/Resources"
music = res / "Music"
def read(path): return json.loads(path.read_text())
hashes = {}
def sha(path):
    if path not in hashes:
        digest = hashlib.sha256()
        with path.open("rb") as file:
            for chunk in iter(lambda: file.read(1024 * 1024), b""):
                digest.update(chunk)
        hashes[path] = digest.hexdigest()
    return hashes[path]
cat = read(music / "catalogue.json")
assert cat == read(repo / "Resources/Music/catalogue.json"), "Catalogue identity/arrangement mismatch"
variants = [variant for track in cat["tracks"] for variant in track["variants"]]
assert {row["variantID"] for row in read(music / "timing.json")["variants"]} == {variant["id"] for variant in variants}
assert read(music / "bundle.json")["scope"] == "full"
assert read(music / "bundle.json")["trackCount"] == len(variants)
for name in ("timing.json", "rhythm.json", "recording-playback.json"):
    for row in read(music / name)["variants"]:
        assert sha(music / row["path"]) == row.get("playbackSHA256", row["sourceSHA256"]), (name, row["path"])
        if "loopPath" in row:
            assert sha(music / row["loopPath"]) == row["sha256"], row["loopPath"]
profiles = read(music / "recording-playback.json")["variants"]
expected = {row["variantID"]: row for row in read(repo / "Resources/Music/recording-playback.json")["variants"]}
assert {row["variantID"] for row in profiles} == set(expected)
for row in profiles:
    assert {key: value for key, value in row.items() if key != "playbackSHA256"} == expected[row["variantID"]], row["path"]
assert sha(res / "Sounds/yippee.mp3") == sha(repo / "Resources/Sounds/yippee.mp3")
files = ["Lemm2/MUSIC/SBLAST.VOC", "Lemm2/LEVELS/LEVEL000.DAT", "LEM3CD/LEVELS/LEVEL001.DAT"]
files += ["LEM3CD/AUDIO/GRAVIS/" + name for name in ("I_DOOR.PAT", "I_LETSGO.PAT", "I_OK.PAT", "I_YIPEE.PAT", "I_LEMDIE.PAT", "I_OHNO.PAT")]
for name in files:
    assert sha(res / "Ports" / name) == sha(repo / "Sources/Ports" / name), name
source_inputs = read(repo / ".build/release-1.8.5/source-inputs.json")
assert all(sha(repo / name) == digest for name, digest in source_inputs.items()), "Source changed during test build"
print(f"PASS {len(variants)} music versions, {len(profiles)} gain/loop profiles, playback hashes, rescue MP3, sequel assets and unchanged build sources")
