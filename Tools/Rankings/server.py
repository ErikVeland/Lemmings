#!/usr/bin/env python3
"""Community leaderboards, isolated from anonymous aggregate telemetry."""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import re
import sqlite3
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlsplit
import uuid

MAX_MOVIE = 64 * 1024 * 1024
MAX_STORAGE = 1024 * 1024 * 1024
BOARDS = {
    "mostSaved": ("saved DESC, skills ASC, milliseconds ASC", "1"),
    "leastSkills": ("skills ASC, saved DESC, milliseconds ASC", "won=1"),
    "fastestClear": ("milliseconds ASC, saved DESC, skills ASC", "won=1 AND milliseconds>0"),
    "fastestAllSaved": ("milliseconds ASC, saved DESC, skills ASC", "won=1 AND saved=population AND milliseconds>0"),
}
CAREER = {"stars": "SUM(best)", "clears": "COUNT(*)", "perfect": "SUM(best=3)"}

def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False, allow_nan=False)

def integer(value, low=0, high=1000000):
    if type(value) is not int or not low <= value <= high:
        raise ValueError("Invalid count")
    return value

def checked_conditions(raw):
    if not isinstance(raw, str) or len(raw.encode()) > 12000:
        raise ValueError("Invalid conditions")
    c = json.loads(raw)
    required = {"gameID", "packID", "levelID", "levelFingerprint", "rulesetVersion", "physicsMode",
                "population", "rescueRequirement", "startingSkills", "modifiers", "rewindPolicy"}
    if not isinstance(c, dict) or not required <= c.keys() or c.keys() - required - {"timeLimitSeconds"}:
        raise ValueError("Invalid conditions")
    for key in required - {"population", "rescueRequirement", "startingSkills", "modifiers"}:
        if not isinstance(c[key], str) or not 1 <= len(c[key]) <= 1024:
            raise ValueError("Invalid condition identity")
    integer(c["population"], 1)
    integer(c["rescueRequirement"], 0, c["population"])
    for key in ("startingSkills", "modifiers"):
        if not isinstance(c[key], dict) or len(c[key]) > 100:
            raise ValueError("Invalid conditions")
        for k, v in c[key].items():
            if not isinstance(k, str) or not 1 <= len(k) <= 100:
                raise ValueError("Invalid conditions")
            if key == "startingSkills":
                integer(v, -1)
            elif not isinstance(v, str) or len(v) > 256:
                raise ValueError("Invalid modifier")
    limit = c.get("timeLimitSeconds")
    if limit is not None and (type(limit) not in (int, float) or not math.isfinite(limit) or not 0 <= limit <= 1e9):
        raise ValueError("Invalid time")
    # The app supplies its sorted JSON encoding, so the key is identical on both sides.
    normalized = canonical(c)
    if raw != normalized:
        raise ValueError("Conditions must use canonical JSON")
    return c, hashlib.sha256(raw.encode()).hexdigest()

class Store:
    def __init__(self, root, catalogue=None):
        self.root = Path(root)
        self.root.mkdir(parents=True, exist_ok=True)
        self.movies = self.root / "replays"
        self.movies.mkdir(exist_ok=True)
        for pending in self.movies.glob("*.pending"):
            pending.unlink()
        self.upload_lock = threading.Lock()
        self.targets = {}
        if catalogue:
            for row in json.loads(Path(catalogue).read_text())["levels"]:
                c = row.get("conditions")
                w = row.get("witness")
                if c and w and w["completed"] and w["didWin"]:
                    self.targets[hashlib.sha256(canonical(c).encode()).hexdigest()] = w["saved"]
        with self.db() as db:
            db.executescript("""
              CREATE TABLE IF NOT EXISTS players (id TEXT PRIMARY KEY, token TEXT UNIQUE NOT NULL, name TEXT NOT NULL);
              CREATE TABLE IF NOT EXISTS runs (
                id TEXT PRIMARY KEY, player TEXT NOT NULL, conditions TEXT NOT NULL, board_key TEXT NOT NULL,
                level_key TEXT NOT NULL, assisted INTEGER NOT NULL, saved INTEGER NOT NULL, population INTEGER NOT NULL,
                skills INTEGER NOT NULL, milliseconds INTEGER NOT NULL, won INTEGER NOT NULL, stars INTEGER NOT NULL,
                submitted INTEGER NOT NULL, replay_bytes INTEGER NOT NULL DEFAULT 0);
              CREATE INDEX IF NOT EXISTS board_lookup ON runs(board_key,assisted,player);
              CREATE INDEX IF NOT EXISTS player_runs ON runs(player);
            """)
            # A new shipped solution can change the rescue target without changing a run.
            for key, target in self.targets.items():
                db.execute("""UPDATE runs SET stars=CASE WHEN won=0 THEN 0 WHEN saved>=? THEN 3
                           WHEN saved>=MIN(json_extract(conditions,'$.rescueRequirement')+1,?) THEN 2 ELSE 1 END
                           WHERE board_key=?""", (target, target, key))
        os.chmod(self.root / "rankings.sqlite3", 0o600)

    def db(self):
        db = sqlite3.connect(self.root / "rankings.sqlite3", timeout=10)
        db.row_factory = sqlite3.Row
        db.execute("PRAGMA busy_timeout=10000")
        db.execute("PRAGMA max_page_count=32768")
        return db

    def identity(self, token, name=None):
        if not re.fullmatch(r"[a-f0-9]{64}", token or ""):
            raise PermissionError("Sign in to share records")
        digest = hashlib.sha256(token.encode()).hexdigest()
        with self.db() as db:
            if name is not None:
                if not isinstance(name, str) or not re.fullmatch(r"[A-Z0-9]{1,3}", name):
                    raise ValueError("Use player initials")
                db.execute("BEGIN IMMEDIATE")
                existing = db.execute("SELECT id FROM players WHERE token=?", (digest,)).fetchone()
                if not existing and db.execute("SELECT COUNT(*) FROM players").fetchone()[0] >= 10000:
                    raise OverflowError("Registration capacity reached")
                db.execute("INSERT INTO players VALUES(?,?,?) ON CONFLICT(token) DO UPDATE SET name=excluded.name",
                           (str(uuid.uuid4()), digest, name))
            row = db.execute("SELECT id FROM players WHERE token=?", (digest,)).fetchone()
        if not row:
            raise PermissionError("Sign in to share records")
        return row["id"]

    def submit(self, player, payload):
        if set(payload) != {"id", "conditionsJSON", "assisted", "saved", "population", "skills", "milliseconds", "won"}:
            raise ValueError("Invalid run fields")
        if not isinstance(payload["id"], str):
            raise ValueError("Invalid run ID")
        rid = str(uuid.UUID(payload["id"])).lower()
        c, key = checked_conditions(payload["conditionsJSON"])
        saved = integer(payload["saved"])
        population = integer(payload["population"], c["population"])
        cloners = c["startingSkills"].get("cloner", 0)
        if cloners >= 0 and population > c["population"] + cloners:
            raise ValueError("Invalid population")
        if saved > population or type(payload["assisted"]) is not bool or type(payload["won"]) is not bool:
            raise ValueError("Invalid outcome")
        skills = integer(payload["skills"], 0, 100000000)
        ms = integer(payload["milliseconds"], 0, 2147483647)
        won = payload["won"] and saved >= c["rescueRequirement"]
        target = self.targets.get(key)
        ceiling = c["population"] + cloners if cloners >= 0 else None
        full = saved >= target if target is not None else ceiling is not None and saved >= ceiling
        stars = 0 if not won else 3 if full else 2 if saved >= min(c["rescueRequirement"] + 1, target or ceiling or c["rescueRequirement"] + 1) else 1
        level_key = canonical([c["gameID"], c["packID"], c["levelID"]])
        values = (rid, player, payload["conditionsJSON"], key, level_key, int(payload["assisted"]),
                  saved, population, skills, ms, int(won), stars)
        with self.db() as db:
            db.execute("BEGIN IMMEDIATE")
            old = db.execute("SELECT * FROM runs WHERE id=?", (rid,)).fetchone()
            if old:
                if tuple(old[k] for k in ("id","player","conditions","board_key","level_key","assisted",
                                          "saved","population","skills","milliseconds","won")) != values[:-1]:
                    raise ValueError("Run ID already has different content")
                return rid
            if db.execute("SELECT COUNT(*) FROM runs WHERE player=?", (player,)).fetchone()[0] >= 20000:
                raise OverflowError("Player record capacity reached")
            db.execute("""INSERT INTO runs(id,player,conditions,board_key,level_key,assisted,saved,population,skills,milliseconds,won,stars,submitted)
                          VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)""", values + (int(time.time()),))
        return rid

    def board(self, key, category, assisted, page=0):
        integer(page, 0, 10000)
        if category in CAREER:
            sql = """WITH bests AS (SELECT player,level_key,MAX(stars) best FROM runs
                     WHERE assisted=? AND won=1 GROUP BY player,level_key),
                     scores AS (SELECT player, """ + CAREER[category] + """ score FROM bests GROUP BY player),
                     ranked AS (SELECT ROW_NUMBER() OVER(ORDER BY score DESC,player) rank,* FROM scores)
                     SELECT ranked.*,players.name FROM ranked JOIN players ON players.id=ranked.player
                     ORDER BY rank LIMIT 6 OFFSET ?"""
            args = (int(assisted), page * 5)
        else:
            if category not in BOARDS or not re.fullmatch("[a-f0-9]{64}", key or ""):
                raise ValueError("Unknown board")
            order, eligible = BOARDS[category]
            sql = """WITH candidates AS (SELECT *,ROW_NUMBER() OVER(PARTITION BY player ORDER BY """ + order + """,submitted,id) choice
                     FROM runs WHERE board_key=? AND assisted=? AND """ + eligible + """),
                     ranked AS (SELECT ROW_NUMBER() OVER(ORDER BY """ + order + """,submitted,id) rank,*
                     FROM candidates WHERE choice=1)
                     SELECT ranked.*,players.name FROM ranked JOIN players ON players.id=ranked.player
                     ORDER BY rank LIMIT 6 OFFSET ?"""
            args = (key, int(assisted), page * 5)
        with self.db() as db:
            rows = db.execute(sql, args).fetchall()
        return {"entries": [{"rank": r["rank"], "name": r["name"],
                            "score": r["score"] if category in CAREER else r["milliseconds"] if category.startswith("fastest") else r["skills"] if category == "leastSkills" else r["saved"],
                            "runID": None if category in CAREER else r["id"],
                            "replay": False if category in CAREER else r["replay_bytes"] > 0} for r in rows[:5]],
                "page": page, "hasMore": len(rows) > 5, "verification": "community"}

    def upload(self, player, rid, stream, length):
        integer(length, 16, MAX_MOVIE)
        rid = str(uuid.UUID(rid))
        with self.upload_lock:
            with self.db() as db:
                row = db.execute("SELECT player,replay_bytes FROM runs WHERE id=?", (rid,)).fetchone()
                if not row or row["player"] != player:
                    raise PermissionError("Not your run")
                if row["replay_bytes"]:
                    raise FileExistsError("Replay already stored")
                used = sum(p.stat().st_size for p in self.movies.iterdir() if p.is_file())
                personal = db.execute("SELECT COALESCE(SUM(replay_bytes),0) FROM runs WHERE player=?", (player,)).fetchone()[0]
                if used + length > MAX_STORAGE or personal + length > 256 * 1024 * 1024:
                    raise OverflowError("Replay storage is full")
            tmp = self.movies / (rid + ".pending")
            target = self.movies / (rid + ".mp4")
            try:
                with tmp.open("wb") as output:
                    remaining = length
                    first = True
                    while remaining:
                        chunk = stream.read(min(65536, remaining))
                        if not chunk:
                            raise ValueError("Incomplete upload")
                        if first and (len(chunk) < 12 or chunk[4:8] != b"ftyp"):
                            raise ValueError("Expected an MP4 movie")
                        first = False
                        output.write(chunk)
                        remaining -= len(chunk)
                os.replace(tmp, target)
                with self.db() as db:
                    db.execute("UPDATE runs SET replay_bytes=? WHERE id=?", (length, rid))
            except Exception:
                tmp.unlink(missing_ok=True)
                target.unlink(missing_ok=True)
                raise

    def delete_player(self, player):
        with self.upload_lock:
            with self.db() as db:
                rows = db.execute("SELECT id FROM runs WHERE player=?", (player,)).fetchall()
                for row in rows:
                    (self.movies / (row["id"] + ".mp4")).unlink(missing_ok=True)
                db.execute("DELETE FROM runs WHERE player=?", (player,))
                db.execute("DELETE FROM players WHERE id=?", (player,))

class Server(ThreadingHTTPServer):
    daemon_threads = True
    def handle_error(self, request, client_address):
        print("Rankings request failed", flush=True)

class Handler(BaseHTTPRequestHandler):
    def setup(self):
        super().setup()
        self.connection.settimeout(30)

    def log_message(self, *args):
        pass

    def response(self, status, value=None):
        body = b"" if value is None else canonical(value).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        self.wfile.write(body)

    def body(self):
        if self.headers.get_content_type() != "application/json":
            raise ValueError("Expected JSON")
        size = integer(int(self.headers.get("Content-Length", "0")), 1, 16384)
        value = json.loads(self.rfile.read(size))
        if not isinstance(value, dict):
            raise ValueError("Expected an object")
        return value

    def dispatch(self):
        if self.headers.get("Origin") or self.headers.get("Transfer-Encoding") or len(self.headers.get_all("Content-Length", [])) > 1:
            raise ValueError("Unsupported request")
        path = urlsplit(self.path)
        token = self.headers.get("Authorization", "").removeprefix("Bearer ")
        store = self.server.store
        if self.command == "GET":
            if path.path == "/v1/health":
                return self.response(200, {"status": "ok", "version": 1})
            if path.path == "/v1/boards":
                q = parse_qs(path.query, strict_parsing=True)
                if set(q) - {"conditions", "board", "assisted", "page"} or any(len(v) != 1 for v in q.values()):
                    raise ValueError("Invalid query")
                assisted = q.get("assisted", ["0"])[0]
                if assisted not in ("0", "1"):
                    raise ValueError("Invalid category")
                return self.response(200, store.board(q.get("conditions", [""])[0], q.get("board", ["mostSaved"])[0],
                                                     assisted == "1", int(q.get("page", ["0"])[0])))
            if path.path.startswith("/v1/replays/") and not path.query:
                rid = str(uuid.UUID(path.path.rsplit("/", 1)[1]))
                file = store.movies / (rid + ".mp4")
                if not file.is_file():
                    return self.response(404)
                with store.db() as db:
                    row = db.execute("SELECT replay_bytes FROM runs WHERE id=?", (rid,)).fetchone()
                if not row or row["replay_bytes"] != file.stat().st_size:
                    return self.response(404)
                self.send_response(200)
                self.send_header("Content-Type", "video/mp4")
                self.send_header("Content-Length", str(file.stat().st_size))
                self.send_header("Cache-Control", "private, no-store")
                self.send_header("X-Content-Type-Options", "nosniff")
                self.end_headers()
                with file.open("rb") as movie:
                    while chunk := movie.read(65536):
                        self.wfile.write(chunk)
                return
        elif self.command == "POST" and path.path == "/v1/players" and not path.query:
            payload = self.body()
            if set(payload) != {"name"}:
                raise ValueError("Invalid profile")
            return self.response(200, {"id": store.identity(token, payload["name"])})
        elif self.command == "POST" and path.path == "/v1/runs" and not path.query:
            return self.response(200, {"id": store.submit(store.identity(token), self.body())})
        elif self.command == "PUT" and path.path.startswith("/v1/replays/") and not path.query:
            if self.headers.get_content_type() != "video/mp4":
                raise ValueError("Expected movie")
            store.upload(store.identity(token), path.path.rsplit("/", 1)[1], self.rfile,
                         int(self.headers.get("Content-Length", "0")))
            return self.response(204)
        elif self.command == "DELETE" and path.path == "/v1/player" and not path.query:
            store.delete_player(store.identity(token))
            return self.response(204)
        self.response(404)

    def handle_method(self):
        try:
            self.dispatch()
        except PermissionError:
            self.response(401, {"error": "Authentication required"})
        except FileExistsError:
            self.response(409, {"error": "Replay already stored"})
        except (ValueError, TypeError, KeyError, json.JSONDecodeError):
            self.response(400, {"error": "Invalid request"})
        except (OverflowError, sqlite3.Error):
            self.response(507, {"error": "Storage unavailable; records remain local"})
        except (TimeoutError, ConnectionError, BrokenPipeError):
            pass

    do_GET = do_POST = do_PUT = do_DELETE = handle_method

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--data", required=True, type=Path)
    parser.add_argument("--catalogue", type=Path)
    parser.add_argument("--port", type=int, default=8797)
    args = parser.parse_args()
    server = Server(("127.0.0.1", args.port), Handler)
    server.store = Store(args.data, args.catalogue)
    server.serve_forever()

if __name__ == "__main__":
    main()
