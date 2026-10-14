"""Bundle the same sequel and NeoLemmix data used by the Mac app."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
PORTS = ROOT / "Sources/Ports"
NEOLEMMIX = ROOT / "Content/NeoLemmix"
# Match Scripts/bundle-game-data.sh. Native interpreters do not use DOS code or saves.
EXCLUDED = {".exe", ".com", ".bat", ".rko", ".rkb", ".ini", ".sav"}
REQUIRED = {
    "Lemm2": ("LEVELS/LEVEL000.DAT", "STYLES/CLASSIC.DAT", "VLEMMS.DAT", "MASKS.DAT",
              "INTERN.DAT", "FONT.DAT", "PANEL.DAT", "ICONS.DAT",
              "FRONTEND/GFXIFFS/MENU.IFF", "FRONTEND/SCREENS/MENU.DAT", "PROCESS.RKO", "VGA.RKO"),
    "LEM3CD": ("LEVELS/LEVEL001.DAT", "STYLES", "GRAPHICS"),
}
SOUNDS = {name + ".wav" for name in
          ("chain", "electric", "fire", "slurp", "teleporter", "tenton", "thud", "thunk", "weedgulp")}


def ignored(directory, names):
    return [name for name in names if name == ".DS_Store" or name == "LEM3CD-2"
            or Path(name).suffix.lower() in EXCLUDED]


def copy_into_app(app_resources, source_gate=False):
    if app_resources.suffix != ".app" or app_resources.is_symlink():
        raise ValueError("Game data can only be copied into a local app bundle.")
    targets = [app_resources / "Ports" / name for name in REQUIRED] + [app_resources / "NeoLemmix"]
    if (app_resources / "Ports").is_symlink() or any(path.is_symlink() for path in targets):
        raise ValueError("Game-data destination must not be a link.")
    for target in targets:
        if target.exists():
            shutil.rmtree(target)

    # Only the explicit unsigned source gate may build without the local corpus.
    for name, required in REQUIRED.items():
        source = PORTS / name
        missing = [path for path in required if not (source / path).exists()]
        if missing:
            if source_gate:
                print(f"SKIP {name} data in the unsigned source-only gate.")
                continue
            raise ValueError(f"Missing {name} source data: {', '.join(missing)}")
        target = app_resources / "Ports" / name
        shutil.copytree(source, target, ignore=ignored)
        if name == "Lemm2":
            subprocess.run([sys.executable, str(ROOT / "Tools/Lemmings2Reference/prepare-assets.py"),
                            str(source), str(target)], check=True)

    required = ("manifest.json", "levels", "styles/default")
    if not all((NEOLEMMIX / path).exists() for path in required):
        if source_gate:
            print("SKIP NeoLemmix data in the unsigned source-only gate.")
            return
        raise ValueError("Missing NeoLemmix data. Run Scripts/prepare-neolemmix-content.sh.")
    manifest = json.loads((NEOLEMMIX / "manifest.json").read_text())
    hashes = manifest.get("soundSHA256", {})
    if set(hashes) != SOUNDS:
        raise ValueError("Missing NeoLemmix stock sound manifest. Run Scripts/prepare-neolemmix-content.sh.")
    for name, expected in hashes.items():
        path = NEOLEMMIX / "sound" / name
        if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != expected:
            raise ValueError(f"Invalid NeoLemmix stock sound: {name}")
    shutil.copytree(NEOLEMMIX, app_resources / "NeoLemmix", ignore=shutil.ignore_patterns(".DS_Store"))


def is_source_gate():
    return os.environ.get("IOS_SOURCE_GATE_ONLY") == "1" and os.environ.get("CODE_SIGNING_ALLOWED") == "NO"
