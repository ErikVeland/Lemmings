#!/usr/bin/env python3
"""Aggregate identifier-free game counts behind an HTTPS reverse proxy."""

from __future__ import annotations

import argparse
from datetime import datetime, timedelta, timezone
from hmac import compare_digest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import re
import sqlite3
import sys
from urllib.parse import parse_qs, urlsplit


LEVEL_EVENTS = {"level_start", "level_win", "level_fail", "level_abandon"}
SAVED_EVENT = "lemmings_saved"
SIMPLE_EVENTS = {"active_day", "all_soundtracks_selected", "all_soundtracks_downloaded"}
CLASSIC_GAMES = {
    "lemmings": 120,
    "ohNoMoreLemmings": 100,
    "xmasLemmings1991": 4,
    "xmasLemmings1992": 4,
    "holidayLemmings1993": 32,
    "holidayLemmings1994": 32,
    "ohYesMoreLemmings": 60,
}
L2_LEVEL = re.compile(r"t([1-9]|1[0-2])-l([1-9]|10)\Z")
L3_LEVEL = re.compile(r"level-([1-9][0-9]?)\Z")
MAX_BODY = 512
RETENTION_DAYS = 90


def validate_event(value: object) -> tuple[str, str, str, str, int]:
    """Accept only fixed counts. Never store names, paths or supplied dates."""
    if not isinstance(value, dict):
        raise ValueError("Invalid event fields")
    fields = {"v", "event", "game", "level", "mode"}
    if set(value) != (fields | {"amount"} if value.get("event") == SAVED_EVENT else fields):
        raise ValueError("Invalid event fields")
    if type(value["v"]) is not int or value["v"] != 1:
        raise ValueError("Unsupported event version")
    event, game, level, mode = (value[key] for key in ("event", "game", "level", "mode"))
    if not isinstance(event, str) or (game is not None and not isinstance(game, str)):
        raise ValueError("Invalid event kind or game")
    if level is not None and not isinstance(level, str):
        raise ValueError("Invalid level")
    if mode is not None and not isinstance(mode, str):
        raise ValueError("Invalid mode")
    if event in SIMPLE_EVENTS and game is None and level is None and mode is None:
        return event, "", "", "", 1
    if event not in LEVEL_EVENTS | {SAVED_EVENT} or mode not in {"solo", "hot_seat"}:
        raise ValueError("Invalid event kind or mode")
    amount = value.get("amount", 1)
    if type(amount) is not int or not 1 <= amount <= 1_000_000:
        raise ValueError("Invalid saved amount")
    if game == "fan" and level == "all":
        return event, game, level, mode, amount
    if game == "lemmings2" and isinstance(level, str) and (level == "practice" or L2_LEVEL.fullmatch(level)):
        return event, game, level, mode, amount
    if game == "lemmings3" and isinstance(level, str):
        match = L3_LEVEL.fullmatch(level)
        if match and int(match.group(1)) <= 90:
            return event, game, level, mode, amount
    if game in CLASSIC_GAMES and isinstance(level, str) and level.startswith("level-"):
        number = level[6:]
        if number.isascii() and number.isdecimal() and str(int(number)) == number:
            if 1 <= int(number) <= CLASSIC_GAMES[game]:
                return event, game, level, mode, amount
    raise ValueError("Invalid game or level")


class CountStore:
    """Store daily aggregates and one lifetime saved total, without identifiers."""

    def __init__(self, path: Path):
        self.path = path
        self.path.parent.mkdir(parents=True, exist_ok=True)
        with self.connect() as db:
            db.execute("""
                CREATE TABLE IF NOT EXISTS counts (
                    day TEXT NOT NULL,
                    event TEXT NOT NULL,
                    game TEXT NOT NULL,
                    level TEXT NOT NULL,
                    mode TEXT NOT NULL,
                    count INTEGER NOT NULL CHECK (count > 0),
                    PRIMARY KEY (day, event, game, level, mode)
                )
            """)
            db.execute("""
                CREATE TABLE IF NOT EXISTS lifetime_totals (
                    name TEXT PRIMARY KEY,
                    count INTEGER NOT NULL CHECK (count >= 0)
                )
            """)
        self.path.chmod(0o600)

    def connect(self) -> sqlite3.Connection:
        db = sqlite3.connect(self.path, timeout=5)
        db.execute("PRAGMA busy_timeout=5000")
        return db

    def add(self, event: tuple[str, str, str, str, int]) -> None:
        today = datetime.now(timezone.utc).date()
        cutoff = (today - timedelta(days=RETENTION_DAYS - 1)).isoformat()
        kind, game, level, mode, amount = event
        with self.connect() as db:
            db.execute("DELETE FROM counts WHERE day < ?", (cutoff,))
            db.execute("""
                INSERT INTO counts (day, event, game, level, mode, count)
                VALUES (?, ?, ?, ?, ?, ?)
                ON CONFLICT (day, event, game, level, mode)
                DO UPDATE SET count = count + excluded.count
            """, (today.isoformat(), kind, game, level, mode, amount))
            if kind == SAVED_EVENT:
                db.execute("""
                    INSERT INTO lifetime_totals (name, count) VALUES (?, ?)
                    ON CONFLICT (name) DO UPDATE SET count = count + excluded.count
                """, (SAVED_EVENT, amount))

    def saved_total(self) -> int:
        with self.connect() as db:
            row = db.execute("SELECT count FROM lifetime_totals WHERE name = ?", (SAVED_EVENT,)).fetchone()
        return row[0] if row else 0

    def summary(self, days: int) -> dict[str, object]:
        today = datetime.now(timezone.utc).date()
        cutoff = (today - timedelta(days=days - 1)).isoformat()
        retention_cutoff = (today - timedelta(days=RETENTION_DAYS - 1)).isoformat()
        with self.connect() as db:
            db.execute("DELETE FROM counts WHERE day < ?", (retention_cutoff,))
            rows = db.execute("""
                SELECT CASE WHEN event = 'active_day' THEN day ELSE '' END AS shown_day,
                    event, game, level, mode, SUM(count)
                FROM counts WHERE day >= ?
                GROUP BY shown_day, event, game, level, mode
                ORDER BY shown_day, event, game, level, mode
            """, (cutoff,)).fetchall()
        return {
            "days": days,
            "counts": [
                {"day": day or None, "event": event, "game": game or None,
                 "level": level or None, "mode": mode or None, "count": count}
                for day, event, game, level, mode, count in rows
            ],
        }


class TelemetryServer(ThreadingHTTPServer):
    def __init__(self, address: tuple[str, int], store: CountStore, admin_token: str):
        super().__init__(address, TelemetryHandler)
        self.store = store
        self.admin_token = admin_token

    def handle_error(self, request: object, client_address: object) -> None:
        # socketserver's default traceback includes the source network address.
        print("Telemetry request failed", file=sys.stderr)


class TelemetryHandler(BaseHTTPRequestHandler):
    server: TelemetryServer

    def log_message(self, format: str, *args: object) -> None:
        # BaseHTTPRequestHandler logs client addresses by default.
        pass

    def respond(self, status: int, value: dict[str, object] | None = None) -> None:
        body = b"" if value is None else json.dumps(value, separators=(",", ":")).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        if body:
            self.wfile.write(body)

    def do_POST(self) -> None:
        if self.path != "/v1/event":
            self.respond(404)
            return
        if (self.headers.get("Origin") or self.headers.get("Transfer-Encoding")
                or len(self.headers.get_all("Content-Length", [])) != 1):
            self.respond(400)
            return
        if self.headers.get_content_type() != "application/json":
            self.respond(415)
            return
        try:
            length = int(self.headers.get("Content-Length", ""))
            if not 1 <= length <= MAX_BODY:
                raise ValueError("Invalid body size")
            value = json.loads(self.rfile.read(length))
            event = validate_event(value)
        except (ValueError, UnicodeDecodeError, json.JSONDecodeError):
            self.respond(400)
            return
        self.server.store.add(event)
        self.respond(204)

    def do_GET(self) -> None:
        parsed = urlsplit(self.path)
        if parsed.path == "/v1/saved":
            if parsed.query or parsed.fragment:
                self.respond(400)
            else:
                self.respond(200, {"saved": self.server.store.saved_total()})
            return
        if parsed.path != "/v1/dashboard":
            self.respond(404)
            return
        expected = "Bearer " + self.server.admin_token
        if not compare_digest(self.headers.get("Authorization", ""), expected):
            self.respond(401)
            return
        try:
            query = parse_qs(parsed.query, strict_parsing=True)
        except ValueError:
            self.respond(400)
            return
        if set(query) != {"days"} or query["days"] not in [["7"], ["30"]]:
            self.respond(400)
            return
        self.respond(200, self.server.store.summary(int(query["days"][0])))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", required=True, type=Path, help="Absolute SQLite database path")
    parser.add_argument("--port", type=int, default=8765)
    args = parser.parse_args()
    token = os.environ.get("LEMMINGS_TELEMETRY_ADMIN_TOKEN", "")
    if not args.db.is_absolute() or len(token) < 32 or not 1 <= args.port <= 65535:
        parser.error("Use an absolute --db, a 32-character admin token and a valid --port")
    server = TelemetryServer(("127.0.0.1", args.port), CountStore(args.db), token)
    server.serve_forever()


if __name__ == "__main__":
    main()
