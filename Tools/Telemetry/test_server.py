import http.client
import json
from datetime import datetime, timedelta, timezone
from pathlib import Path
import sqlite3
import tempfile
import threading
import unittest

from server import CountStore, TelemetryServer, validate_event


class TelemetryTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.store = CountStore(Path(self.temporary.name) / "counts.sqlite3")

    def tearDown(self):
        self.temporary.cleanup()

    def test_accepts_only_fixed_anonymous_fields(self):
        good = {"v": 1, "event": "level_start", "game": "lemmings",
                "level": "level-54", "mode": "hot_seat"}
        self.assertEqual(validate_event(good), ("level_start", "lemmings", "level-54", "hot_seat", 1))
        self.assertEqual(validate_event(dict(good, game="lemmings2", level="practice")),
                         ("level_start", "lemmings2", "practice", "hot_seat", 1))
        saved = dict(good, event="lemmings_saved", amount=23)
        self.assertEqual(validate_event(saved), ("lemmings_saved", "lemmings", "level-54", "hot_seat", 23))
        for bad in [
            dict(good, playerID="someone"),
            dict(good, level="Private level name"),
            dict(good, game="fan", level="my-pack"),
            dict(good, mode="someone"),
            dict(good, event=[]),
            dict(good, game=[]),
            dict(good, v=True),
            dict(good, amount=3),
            dict(saved, amount=0),
            dict(saved, amount=True),
            dict(saved, amount=1_000_001),
            {key: value for key, value in saved.items() if key != "amount"},
        ]:
            with self.subTest(bad=bad), self.assertRaises(ValueError):
                validate_event(bad)

    def test_store_contains_aggregate_counts_only(self):
        event = ("level_win", "lemmings", "level-54", "solo", 1)
        self.store.add(event)
        self.store.add(event)
        rows = self.store.summary(7)["counts"]
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["count"], 2)
        with sqlite3.connect(self.store.path) as db:
            columns = [row[1] for row in db.execute("PRAGMA table_info(counts)")]
        self.assertEqual(columns, ["day", "event", "game", "level", "mode", "count"])
        self.assertEqual(self.store.path.stat().st_mode & 0o777, 0o600)

    def test_lifetime_saved_total_survives_daily_pruning(self):
        saved = ("lemmings_saved", "fan", "all", "hot_seat", 42)
        self.store.add(saved)
        self.store.add(saved)
        self.assertEqual(self.store.saved_total(), 84)
        self.assertEqual(self.store.summary(7)["counts"][0]["count"], 84)
        old_day = (datetime.now(timezone.utc).date() - timedelta(days=91)).isoformat()
        with sqlite3.connect(self.store.path) as db:
            db.execute("UPDATE counts SET day = ?", (old_day,))
        self.assertEqual(self.store.summary(7)["counts"], [])
        self.assertEqual(self.store.saved_total(), 84)

    def test_summary_groups_days_and_prunes_old_counts(self):
        today = datetime.now(timezone.utc).date()
        with sqlite3.connect(self.store.path) as db:
            for age, count in [(0, 1), (6, 2), (8, 3), (91, 4)]:
                db.execute("""INSERT INTO counts VALUES (?, ?, ?, ?, ?, ?)""",
                           ((today - timedelta(days=age)).isoformat(),
                            "level_fail", "lemmings", "level-3", "solo", count))
        self.assertEqual(self.store.summary(7)["counts"][0]["count"], 3)
        self.assertEqual(self.store.summary(30)["counts"][0]["count"], 6)
        with sqlite3.connect(self.store.path) as db:
            self.assertEqual(db.execute("SELECT COUNT(*) FROM counts").fetchone()[0], 3)

    def test_http_auth_and_validation(self):
        token = "a" * 32
        server = TelemetryServer(("127.0.0.1", 0), self.store, token)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            connection = http.client.HTTPConnection("127.0.0.1", server.server_port)
            payload = {"v": 1, "event": "level_fail", "game": "lemmings2",
                       "level": "t3-l4", "mode": "solo"}
            connection.request("POST", "/v1/event", json.dumps(payload),
                               {"Content-Type": "application/json"})
            self.assertEqual(connection.getresponse().status, 204)
            connection.request("GET", "/v1/dashboard?days=30")
            self.assertEqual(connection.getresponse().status, 401)
            connection.request("GET", "/v1/dashboard?days=30",
                               headers={"Authorization": "Bearer " + token})
            response = connection.getresponse()
            self.assertEqual(response.status, 200)
            self.assertEqual(json.loads(response.read())["counts"][0]["count"], 1)
            connection.request("GET", "/v1/saved")
            response = connection.getresponse()
            self.assertEqual(response.status, 200)
            self.assertEqual(json.loads(response.read()), {"saved": 0})
            connection.request("POST", "/v1/event", json.dumps(dict(payload, event="lemmings_saved", amount=7)),
                               {"Content-Type": "application/json"})
            self.assertEqual(connection.getresponse().status, 204)
            connection.request("GET", "/v1/saved")
            self.assertEqual(json.loads(connection.getresponse().read()), {"saved": 7})
            connection.request("GET", "/v1/saved?days=30")
            self.assertEqual(connection.getresponse().status, 400)
            connection.request("POST", "/v1/event", json.dumps(dict(payload, profile="LEM")),
                               {"Content-Type": "application/json"})
            self.assertEqual(connection.getresponse().status, 400)
            connection.close()
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=2)


if __name__ == "__main__":
    unittest.main()
