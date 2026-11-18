#!/usr/bin/env python3
"""Preview the website with the production route structure."""
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import unquote, urlsplit

ROOT = (Path(__file__).resolve().parent / 'dist').resolve()

class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT), **kwargs)

    def do_GET(self):
        path = unquote(urlsplit(self.path).path)
        resolved = (ROOT / path.lstrip('/')).resolve()
        if not resolved.is_relative_to(ROOT):
            self.send_error(404)
            return
        if resolved.is_dir():
            resolved /= 'index.html'
        if not resolved.is_file():
            self.send_response(404)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.end_headers()
            self.wfile.write((ROOT / '404/index.html').read_bytes())
            return
        self.path = '/' + str(resolved.relative_to(ROOT))
        super().do_GET()

print('Preview: http://127.0.0.1:4391', flush=True)
ThreadingHTTPServer(('127.0.0.1', 4391), Handler).serve_forever()
