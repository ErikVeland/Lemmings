#!/usr/bin/env python3
"""Run one native UI test app at a time on this Mac."""
import fcntl
import os
from pathlib import Path
import subprocess
import sys
import tempfile

if len(sys.argv) < 2:
    raise SystemExit("Usage: run.py command [arguments ...]")
lock = Path(tempfile.gettempdir()) / f"lemmings-ui-tests-{os.getuid()}.lock"
with lock.open("a") as handle:
    fcntl.flock(handle, fcntl.LOCK_EX)
    environment = os.environ.copy()
    environment.setdefault("NSUnbufferedIO", "YES")
    result = subprocess.run(sys.argv[1:], check=False, env=environment)
    raise SystemExit(result.returncode if result.returncode >= 0 else 128 - result.returncode)
