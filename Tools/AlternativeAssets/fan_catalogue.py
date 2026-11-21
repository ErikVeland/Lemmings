"""Read the approved Ultimate Lemmix level catalogue."""
import hashlib
import io
import os
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parents[2]
FOLDERS = {"LevelPacks", "NeoLemmix", "FanRuntime"}


def resources():
    data = (ROOT / "Resources/UltimateLemmix/FanCatalogue.zip").read_bytes()
    if hashlib.sha256(data).hexdigest() != "b454384f5483255fae4a69bbfee8d20fa3f980f52c90253130cb10dddb7cfd2a":
        raise ValueError("The fan catalogue differs from the approved archive.")
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        files = {name: archive.read(name) for name in archive.namelist()}
    runtime = Path(os.environ.get("ULTIMATE_LEMMIX_FAN_RUNTIME", ROOT / ".build/FanRuntime.zip")).read_bytes()
    if hashlib.sha256(runtime).hexdigest() != "5b573f15a6f3905670c6fa399f0bcd2012c40a7f6c2e5ce33db88b4bb0895a6b":
        raise ValueError("The fan runtime differs from the verified offline assets.")
    with zipfile.ZipFile(io.BytesIO(runtime)) as archive:
        files.update({name: archive.read(name) for name in archive.namelist()})
    return files


def verify_manifest(rows):
    actual = {row["path"]: row["sha256"] for row in rows if row["path"].split("/", 1)[0] in FOLDERS}
    expected = {name: hashlib.sha256(data).hexdigest() for name, data in resources().items()}
    if actual != expected:
        raise ValueError("The prepared fan catalogue differs from the approved files.")
