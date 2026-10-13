#!/usr/bin/env python3
"""Private opaque cloud saves. No public profiles, email addresses or game data."""
import argparse
import base64
import hashlib
import hmac
import json
import re
import sqlite3
import threading
import time
from collections import deque
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit

MAX_SAVE = 8 * 1024 * 1024 + 28
MAX_STORAGE = 2 * 1024 * 1024 * 1024
UUID = r"[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}"
TOKEN = re.compile(r"[a-f0-9]{64}")


class Rejected(Exception):
    def __init__(self, status, message):
        self.status, self.message = status, message


class Store:
    def __init__(self, path, clock=time.time):
        self.clock = clock
        self.lock = threading.RLock()
        self.db = sqlite3.connect(path, check_same_thread=False)
        self.db.execute("PRAGMA journal_mode=WAL")
        self.db.execute("PRAGMA foreign_keys=ON")
        self.db.execute("PRAGMA busy_timeout=5000")
        self.db.executescript("""
        CREATE TABLE IF NOT EXISTS vaults(id TEXT PRIMARY KEY, token TEXT NOT NULL, created REAL NOT NULL);
        CREATE TABLE IF NOT EXISTS saves(vault TEXT REFERENCES vaults(id) ON DELETE CASCADE,
          device TEXT NOT NULL, data BLOB NOT NULL, etag TEXT NOT NULL, updated REAL NOT NULL,
          PRIMARY KEY(vault,device));
        CREATE TABLE IF NOT EXISTS links(code TEXT PRIMARY KEY, payload TEXT NOT NULL, expires REAL NOT NULL);
        """)

    @staticmethod
    def credential(token):
        if not isinstance(token, str) or not TOKEN.fullmatch(token):
            raise Rejected(401, "Library key required")
        return hashlib.sha256(token.encode()).hexdigest()

    def authorize(self, vault, token):
        digest = self.credential(token)
        row = self.db.execute("SELECT token FROM vaults WHERE id=?", (vault,)).fetchone()
        if row is None:
            raise Rejected(404, "Library unavailable")
        if not hmac.compare_digest(row[0], digest):
            raise Rejected(401, "Library unavailable")
        return digest

    def manifest(self, vault, token):
        with self.lock:
            self.authorize(vault, token)
            return {"devices": [r[0] for r in self.db.execute("SELECT device FROM saves WHERE vault=? ORDER BY device", (vault,))]}

    def read(self, vault, device, token):
        with self.lock:
            self.authorize(vault, token)
            row = self.db.execute("SELECT data,etag FROM saves WHERE vault=? AND device=?", (vault, device)).fetchone()
            if row is None:
                raise Rejected(404, "Save unavailable")
            return row

    def write(self, vault, device, token, data, match):
        if not 28 < len(data) <= MAX_SAVE:
            raise Rejected(413, "Save size exceeds its limit")
        digest = self.credential(token)
        etag = hashlib.sha256(data).hexdigest()
        with self.lock, self.db:
            existing = self.db.execute("SELECT token FROM vaults WHERE id=?", (vault,)).fetchone()
            if existing is None:
                if match != "*":
                    raise Rejected(412, "Fetch the library before saving")
                if self.db.execute("SELECT COUNT(*) FROM vaults").fetchone()[0] >= 10000:
                    raise Rejected(507, "Cloud capacity reached")
                self.db.execute("INSERT INTO vaults VALUES(?,?,?)", (vault, digest, self.clock()))
            elif not hmac.compare_digest(existing[0], digest):
                raise Rejected(401, "Library unavailable")
            previous = self.db.execute("SELECT etag,length(data) FROM saves WHERE vault=? AND device=?", (vault, device)).fetchone()
            if previous is None:
                if match != "*":
                    raise Rejected(412, "Fetch the save before updating")
                if self.db.execute("SELECT COUNT(*) FROM saves WHERE vault=?", (vault,)).fetchone()[0] >= 32:
                    raise Rejected(507, "Library device limit reached")
            elif previous[0] != match:
                # A repeated identical request is safe after an uncertain outcome.
                if previous[0] == etag:
                    return etag
                raise Rejected(412, "The save changed. Fetch and merge again")
            used = self.db.execute("SELECT COALESCE(SUM(length(data)),0) FROM saves").fetchone()[0]
            if used - (previous[1] if previous else 0) + len(data) > MAX_STORAGE:
                raise Rejected(507, "Cloud capacity reached")
            self.db.execute("INSERT INTO saves VALUES(?,?,?,?,?) ON CONFLICT(vault,device) DO UPDATE SET data=excluded.data,etag=excluded.etag,updated=excluded.updated",
                            (vault, device, data, etag, self.clock()))
            return etag

    def link(self, value):
        if not isinstance(value, dict) or set(value) != {"code", "payload"} or not isinstance(value["code"], str) or not TOKEN.fullmatch(value["code"]):
            raise Rejected(400, "Invalid link")
        try:
            raw = base64.b64decode(value["payload"], validate=True)
        except (ValueError, TypeError):
            raise Rejected(400, "Invalid link")
        if not 28 < len(raw) <= 16384:
            raise Rejected(400, "Invalid link")
        with self.lock, self.db:
            self.db.execute("DELETE FROM links WHERE expires<=?", (self.clock(),))
            if self.db.execute("SELECT COUNT(*) FROM links").fetchone()[0] >= 1000:
                raise Rejected(429, "Try again later")
            try:
                self.db.execute("INSERT INTO links VALUES(?,?,?)", (value["code"], value["payload"], self.clock() + 600))
            except sqlite3.IntegrityError:
                raise Rejected(409, "Create another code")

    def redeem(self, code):
        with self.lock, self.db:
            row = self.db.execute("SELECT payload,expires FROM links WHERE code=?", (code,)).fetchone()
            if row is None or row[1] <= self.clock():
                raise Rejected(404, "Code expired or already used")
            self.db.execute("DELETE FROM links WHERE code=?", (code,))
            return {"code": code, "payload": row[0]}

    def delete(self, vault, token):
        with self.lock, self.db:
            self.authorize(vault, token)
            self.db.execute("DELETE FROM vaults WHERE id=?", (vault,))


class Server(ThreadingHTTPServer):
    daemon_threads = True
    def __init__(self, address, store):
        super().__init__(address, Handler)
        self.store = store
        self.rate_lock = threading.Lock()
        self.requests = deque()


class Handler(BaseHTTPRequestHandler):
    server_version = "PrivateSaves/2"
    protocol_version = "HTTP/1.1"
    def log_message(self, *_):
        pass

    def send(self, status, value, etag=None):
        binary = isinstance(value, bytes)
        body = value if binary else json.dumps(value, separators=(",", ":")).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/octet-stream" if binary else "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        if etag:
            self.send_header("ETag", etag)
        self.end_headers()
        self.wfile.write(body)

    def body(self, limit):
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            raise Rejected(400, "Invalid request size")
        if not 0 <= length <= limit or self.headers.get("Transfer-Encoding"):
            raise Rejected(413, "Request too large")
        self.connection.settimeout(20)
        data = self.rfile.read(length)
        if len(data) != length:
            raise Rejected(400, "Incomplete request")
        return data

    def route(self):
        path = urlsplit(self.path).path
        with self.server.rate_lock:
            now = time.monotonic()
            while self.server.requests and self.server.requests[0] <= now - 60:
                self.server.requests.popleft()
            if len(self.server.requests) >= 1200:
                raise Rejected(429, "Try again later")
            self.server.requests.append(now)
        if path == "/v1/health" and self.command == "GET":
            return self.send(200, {"version": 2, "status": "ok"})
        if path == "/v1/links" and self.command == "POST":
            self.server.store.link(json.loads(self.body(32768)))
            return self.send(201, {"expiresIn": 600})
        if re.fullmatch(r"/v1/links/[a-f0-9]{64}", path) and self.command == "POST":
            self.body(0)
            return self.send(200, self.server.store.redeem(path.rsplit("/", 1)[1]))
        match = re.fullmatch(r"/v1/vaults/(" + UUID + r")(?:/devices/(" + UUID + r"))?", path)
        if match:
            vault, device = match.groups()
            auth = self.headers.get("Authorization", "")
            token = auth[7:] if auth.startswith("Bearer ") else ""
            if self.command == "GET":
                if device:
                    data, etag = self.server.store.read(vault, device, token)
                    return self.send(200, data, etag)
                return self.send(200, self.server.store.manifest(vault, token))
            if self.command == "PUT" and device:
                etag = self.server.store.write(vault, device, token, self.body(MAX_SAVE), self.headers.get("If-Match"))
                return self.send(200, {"saved": True}, etag)
            if self.command == "DELETE" and not device:
                self.server.store.delete(vault, token)
                return self.send(200, {"deleted": True})
        raise Rejected(404, "Unavailable")

    def handle_request(self):
        try:
            self.route()
        except Rejected as error:
            self.close_connection = True
            self.send(error.status, {"error": error.message})
        except (ValueError, TypeError, json.JSONDecodeError):
            self.close_connection = True
            self.send(400, {"error": "Invalid request"})
        except (OSError, sqlite3.Error):
            self.close_connection = True
            self.send(503, {"error": "Cloud temporarily unavailable"})

    do_GET = do_PUT = do_POST = do_DELETE = handle_request


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--data", type=Path, required=True)
    parser.add_argument("--port", type=int, default=8798)
    args = parser.parse_args()
    args.data.mkdir(parents=True, exist_ok=True, mode=0o700)
    Server(("127.0.0.1", args.port), Store(args.data / "cloud-saves.sqlite3")).serve_forever()
