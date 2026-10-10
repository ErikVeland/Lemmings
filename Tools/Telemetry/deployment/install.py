#!/usr/bin/env python3
"""Install the aggregate service on the existing GlassCode host (run as root)."""
from pathlib import Path
import datetime
import os
import secrets
import shutil
import subprocess

source = Path(__file__).resolve().parent
site = Path("/etc/nginx/sites-enabled/glasscode.academy.conf").resolve()
text = site.read_text()
include = "  include /etc/nginx/snippets/lemmings-telemetry.conf;\n"
if "listen 443 ssl http2;" not in text:
    raise SystemExit("Expected GlassCode TLS server not found")
stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
backup = Path("/var/backups/lemmings-telemetry") / stamp
backup.mkdir(parents=True, mode=0o700)
shutil.copy2(site, backup / "nginx-site.conf")
application = Path("/opt/lemmings-telemetry")
application.mkdir(mode=0o755, exist_ok=True)
shutil.copy2(source.parent / "server.py", application / "server.py")
env = Path("/etc/lemmings-telemetry.env")
if not env.exists():
    fd = os.open(env, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, "w") as output:
        output.write("LEMMINGS_TELEMETRY_ADMIN_TOKEN=" + secrets.token_urlsafe(48) + "\n")
shutil.copy2(source / "lemmings-telemetry.service", "/etc/systemd/system/lemmings-telemetry.service")
shutil.copy2(source / "nginx-location.conf", "/etc/nginx/snippets/lemmings-telemetry.conf")
shutil.copy2(source / "nginx-limit.conf", "/etc/nginx/conf.d/lemmings-telemetry-limit.conf")
if include.strip() not in text:
    text = text.replace("  listen 443 ssl http2;\n", "  listen 443 ssl http2;\n" + include, 1)
    site.write_text(text)
try:
    subprocess.run(["nginx", "-t"], check=True)
    subprocess.run(["systemctl", "daemon-reload"], check=True)
    subprocess.run(["systemctl", "enable", "--now", "lemmings-telemetry"], check=True)
    subprocess.run(["systemctl", "restart", "lemmings-telemetry"], check=True)
    subprocess.run(["systemctl", "reload", "nginx"], check=True)
except subprocess.CalledProcessError:
    shutil.copy2(backup / "nginx-site.conf", site)
    subprocess.run(["nginx", "-t"], check=True)
    subprocess.run(["systemctl", "reload", "nginx"], check=True)
    raise
print("Telemetry installed. Site backup:", backup)
