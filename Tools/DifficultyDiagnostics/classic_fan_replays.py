"""Decode archived Lemmix witnesses with the existing importer, without certifying them."""
import importlib.util
import json
import pathlib
import sys
import tempfile
import zipfile

source = pathlib.Path(__file__).resolve().parents[1] / "ClassicCompletion/import_lemmix.py"
spec = importlib.util.spec_from_file_location("lemmix", source)
importer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(importer)
folder, output = map(pathlib.Path, sys.argv[1:3])
output.mkdir(parents=True, exist_ok=True)
candidates, failures = [], []
for pack in sorted(folder.glob("*.zip")):
    with zipfile.ZipFile(pack) as archive:
        for member in sorted(archive.namelist()):
            if not member.lower().endswith(".lrb"):
                continue
            with tempfile.TemporaryDirectory() as temporary:
                file = pathlib.Path(temporary) / pathlib.Path(member).name
                file.write_bytes(archive.read(member))
                try:
                    candidate = importer.decode(file)
                    prefix = pack.name.split("-", 1)[0]
                    candidate["packID"] = "fan:" + ("lldb-" + str(int(prefix)) if prefix.isdigit() else "file-" + pack.name.lower())
                    candidate["archive"] = pack.name
                    candidate["member"] = member
                    candidates.append(candidate)
                except ValueError as error:
                    failures.append({"archive": pack.name, "member": member, "error": str(error).replace(str(file), member)})
(output / "imported-replay-candidates.json").write_text(json.dumps(candidates, indent=2) + "\n")
(output / "imported-replay-errors.json").write_text(json.dumps(failures, indent=2) + "\n")
print(f"Decoded {len(candidates)} candidates; rejected {len(failures)}. Native validation is still required.")
