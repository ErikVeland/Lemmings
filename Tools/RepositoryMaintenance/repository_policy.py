"""Shared file boundaries for repository checks and developer snapshots."""

import os
from pathlib import Path
import subprocess


LOCAL_DIRECTORIES = {".git", ".build", ".archive", ".swiftpm", "__pycache__", "xcuserdata"}
COMPILER_SUFFIXES = {".swiftmodule", ".swiftdoc", ".swiftsourceinfo", ".dylib", ".o", ".pyc"}
PRIVATE_SUFFIXES = {".p8", ".p12", ".pfx", ".pem", ".key", ".mobileprovision", ".provisionprofile"}


def exclusion_reason(relative):
    """Explain why a relative path must stay out of tracked source and snapshots."""
    if relative.is_absolute() or ".." in relative.parts:
        return "path must stay inside the repository"
    if (relative.parts[:1] == ("Content",)
            or relative.parts[:2] in {("Sources", "Ports"), ("Sources", "Music")}):
        return "local game content must stay untracked"
    evidence_build = (relative.parts[:2] == ("Documentation", "ReleaseReadiness")
                      and "build" in relative.parts[2:-1])
    if (evidence_build or relative.suffix in COMPILER_SUFFIXES
            or relative.name.endswith(".abi.json")):
        return "compiler output must stay in ignored build storage"
    if relative.suffix in PRIVATE_SUFFIXES:
        return "private signing inputs must stay untracked"
    if (any(part in LOCAL_DIRECTORIES or part.endswith(".app") for part in relative.parts)
            or relative.name == ".DS_Store" or relative.suffix == ".xcuserstate"):
        return "local state or generated output must stay untracked"
    return None


def repository_files(root):
    """List existing tracked and non-ignored working files, including symlinks."""
    result = subprocess.check_output(
        ["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"], cwd=root
    )
    paths = {Path(os.fsdecode(name)) for name in result.split(b"\0") if name}
    return sorted(path for path in paths if (root / path).exists() or (root / path).is_symlink())


def contains_symlink(root, relative):
    """Inspect each component without opening a symlink's target."""
    path = root
    for component in relative.parts:
        path = path / component
        if path.is_symlink():
            return True
    return False
