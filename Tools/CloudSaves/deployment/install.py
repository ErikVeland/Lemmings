#!/usr/bin/env python3
"""Install the private service with rollback. Existing rankings stay running."""
from pathlib import Path
import datetime
import shutil
import subprocess
import time
import urllib.request

source = Path(__file__).resolve().parent
site = Path('/etc/nginx/sites-enabled/glasscode.academy.conf').resolve()
original = site.read_text()
include = '  include /etc/nginx/snippets/lemmings-cloud.conf;\n'
if 'listen 443 ssl http2;' not in original:
    raise SystemExit('Expected GlassCode TLS server not found')
stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
backup = Path('/var/backups/lemmings-cloud-configuration') / stamp
backup.mkdir(parents=True, mode=0o700)
application = Path('/opt/lemmings-cloud')
application.mkdir(mode=0o755, exist_ok=True)
files = {
    source.parent / 'server.py': application / 'server.py',
    source / 'lemmings-cloud.service': Path('/etc/systemd/system/lemmings-cloud.service'),
    source / 'nginx-location.conf': Path('/etc/nginx/snippets/lemmings-cloud.conf'),
    source / 'nginx-limit.conf': Path('/etc/nginx/conf.d/lemmings-cloud-limit.conf'),
}
prior = {}
for target in [site, *files.values()]:
    prior[target] = target.exists()
    if target.exists(): shutil.copy2(target, backup / target.name)
was_active = subprocess.run(['systemctl', 'is-active', '--quiet', 'lemmings-cloud']).returncode == 0
try:
    for origin, target in files.items(): shutil.copy2(origin, target)
    if include.strip() not in original:
        site.write_text(original.replace('  listen 443 ssl http2;\n', '  listen 443 ssl http2;\n' + include, 1))
    subprocess.run(['nginx', '-t'], check=True)
    subprocess.run(['systemctl', 'daemon-reload'], check=True)
    subprocess.run(['systemctl', 'restart', 'lemmings-cloud'], check=True)
    for _ in range(20):
        try:
            with urllib.request.urlopen('http://127.0.0.1:8798/v1/health', timeout=2) as response:
                if response.status == 200: break
        except OSError: time.sleep(0.25)
    else: raise RuntimeError('Private save health check failed')
    subprocess.run(['systemctl', 'enable', 'lemmings-cloud'], check=True)
    subprocess.run(['systemctl', 'reload', 'nginx'], check=True)
except Exception:
    subprocess.run(['systemctl', 'stop', 'lemmings-cloud'])
    for target, existed in prior.items():
        if existed: shutil.copy2(backup / target.name, target)
        else: target.unlink(missing_ok=True)
    subprocess.run(['systemctl', 'daemon-reload'], check=True)
    if was_active: subprocess.run(['systemctl', 'start', 'lemmings-cloud'], check=True)
    subprocess.run(['nginx', '-t'], check=True)
    subprocess.run(['systemctl', 'reload', 'nginx'], check=True)
    raise
print('Private saves installed. Configuration backup:', backup)
