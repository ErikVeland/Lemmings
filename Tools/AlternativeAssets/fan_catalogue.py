"""Read the approved Ultimate Lemmix level catalogue."""
import hashlib
import io
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parents[2]
FOLDERS = {"LevelPacks", "NeoLemmix"}


def resources():
    data = (ROOT / "Resources/UltimateLemmix/FanCatalogue.zip").read_bytes()
    if hashlib.sha256(data).hexdigest() != "b454384f5483255fae4a69bbfee8d20fa3f980f52c90253130cb10dddb7cfd2a":
        raise ValueError("The fan catalogue differs from the approved archive.")
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        return {name: archive.read(name) for name in archive.namelist()}


def verify_manifest(rows):
    actual = {row["path"]: row["sha256"] for row in rows if row["path"].split("/", 1)[0] in FOLDERS}
    expected = {name: hashlib.sha256(data).hexdigest() for name, data in resources().items()}
    if actual != expected:
        raise ValueError("The prepared fan catalogue differs from the approved files.")
