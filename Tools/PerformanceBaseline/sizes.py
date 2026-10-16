#!/usr/bin/env python3
"""Record host module sizes and existing bundle resources without rebuilding slices."""
import argparse
from collections import defaultdict
import json
from pathlib import Path
import platform
import subprocess
import tempfile


def measure(build, reference, output):
    host = []
    for path in [build / "LemmingsLocal", *sorted(build.glob("lib*.dylib"))]:
        host.append(dict(name=path.name, fileBytes=path.stat().st_size, architecture=platform.machine(),
                         segments=subprocess.check_output(["xcrun", "size", "-arch", platform.machine(), str(path)], text=True)))
    reference = reference / "Contents"
    historical = []
    with tempfile.TemporaryDirectory(dir=output.parent) as temporary:
        for path in [reference / "MacOS/LemmingsLocal", *sorted((reference / "Frameworks").glob("lib*.dylib"))]:
            architectures = subprocess.check_output(["xcrun", "lipo", "-archs", str(path)], text=True).split()
            slices = {}
            for architecture in architectures:
                if len(architectures) == 1:
                    slices[architecture] = path.stat().st_size
                else:
                    thin = Path(temporary) / f"{path.name}-{architecture}"
                    subprocess.run(["xcrun", "lipo", str(path), "-thin", architecture, "-output", str(thin)], check=True)
                    slices[architecture] = thin.stat().st_size
            historical.append(dict(name=path.name, fileBytes=path.stat().st_size, sliceFileBytes=slices,
                                   segments=subprocess.check_output(["xcrun", "size", "-arch", "all", str(path)], text=True)))
    directories, extensions = defaultdict(int), defaultdict(int)
    for path in (reference / "Resources").rglob("*"):
        if path.is_file():
            directories[path.relative_to(reference / "Resources").parts[0]] += path.stat().st_size
            extensions[path.suffix.lower() or "(none)"] += path.stat().st_size
    output.write_text(json.dumps(dict(snapshotHost=host, build83ReferenceOnly=historical,
                                     referenceBundle=str(reference.parent.resolve()),
                                     build83ResourcesByDirectory=dict(directories),
                                     build83ResourcesByExtension=dict(extensions)), indent=2) + "\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("build", type=Path)
    parser.add_argument("reference_app", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    measure(args.build, args.reference_app, args.output)
