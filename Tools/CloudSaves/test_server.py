import base64
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import tempfile
import threading
import unittest
import urllib.error
import urllib.request
import uuid
from server import Rejected, Server, Store, MAX_SAVE


class CloudTests(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.now = 1000
        self.store = Store(self.folder.name + "/saves.sqlite3", clock=lambda: self.now)
        self.vault = str(uuid.uuid4())
        self.device = str(uuid.uuid4())
        self.token = "a" * 64
        self.data = b"encrypted-not-game-data" * 20

    def tearDown(self):
        self.store.db.close()
        self.folder.cleanup()

    def test_ownership_and_conditional_writes(self):
        first = self.store.write(self.vault, self.device, self.token, self.data, "*")
        self.assertEqual(self.store.read(self.vault, self.device, self.token), (self.data, first))
        with self.assertRaises(Rejected) as wrong:
            self.store.read(self.vault, self.device, "b" * 64)
        self.assertEqual(wrong.exception.status, 401)
        with self.assertRaises(Rejected) as stale:
            self.store.write(self.vault, self.device, self.token, self.data + b"new", "*")
        self.assertEqual(stale.exception.status, 412)
        self.store.write(self.vault, self.device, self.token, self.data + b"new", first)
        self.assertEqual(self.store.manifest(self.vault, self.token)["devices"], [self.device])

    def test_retry_after_unknown_outcome_is_idempotent(self):
        self.store.write(self.vault, self.device, self.token, self.data, "*")
        self.store.write(self.vault, self.device, self.token, self.data, "*")
        self.assertEqual(self.store.db.execute("SELECT COUNT(*) FROM saves").fetchone()[0], 1)

    def test_parallel_devices_keep_independent_offline_saves(self):
        devices = [str(uuid.uuid4()) for _ in range(8)]
        with ThreadPoolExecutor(max_workers=8) as pool:
            list(pool.map(lambda device: self.store.write(self.vault, device, self.token, self.data + device.encode(), "*"), devices))
        self.assertEqual(set(self.store.manifest(self.vault, self.token)["devices"]), set(devices))

    def test_expiring_links_are_consumed_exactly_once(self):
        code = hashlib.sha256(b"random-code").hexdigest()
        self.store.link({"code": code, "payload": base64.b64encode(self.data).decode()})
        def claim(_):
            try:
                return self.store.redeem(code)
            except Rejected:
                return None
        with ThreadPoolExecutor(max_workers=4) as pool:
            self.assertEqual(sum(value is not None for value in pool.map(claim, range(4))), 1)
        self.store.link({"code": code, "payload": base64.b64encode(self.data).decode()})
        self.now += 600
        with self.assertRaises(Rejected):
            self.store.redeem(code)

    def test_size_limits_and_missing_auth_leave_no_registration(self):
        for token, data in [("", self.data), (self.token, b"x" * (MAX_SAVE + 1))]:
            with self.assertRaises(Rejected):
                self.store.write(self.vault, self.device, token, data, "*")
        self.assertEqual(self.store.db.execute("SELECT COUNT(*) FROM vaults").fetchone()[0], 0)

    def test_delete_requires_key_and_removes_all_private_saves(self):
        self.store.write(self.vault, self.device, self.token, self.data, "*")
        with self.assertRaises(Rejected):
            self.store.delete(self.vault, "b" * 64)
        self.store.delete(self.vault, self.token)
        self.assertEqual(self.store.db.execute("SELECT COUNT(*) FROM saves").fetchone()[0], 0)

    def test_online_backups_round_trip_and_keep_three_days(self):
        import sqlite3
        self.store.write(self.vault, self.device, self.token, self.data, "*")
        for day in range(5):
            self.now = 1700000000 + day * 86400
            self.store.backup()
        backups = sorted(self.store.path.parent.joinpath('backups').glob('*.sqlite3'))
        self.assertEqual(len(backups), 3)
        with sqlite3.connect(backups[-1]) as recovered:
            self.assertEqual(recovered.execute('SELECT data FROM saves').fetchone()[0], self.data)

    def test_http_contract_and_no_public_save_access(self):
        server = Server(("127.0.0.1", 0), self.store)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        url = "http://127.0.0.1:%d/v1/vaults/%s" % (server.server_port, self.vault)
        try:
            request = urllib.request.Request(url + "/devices/" + self.device, self.data, method="PUT",
                headers={"Authorization": "Bearer " + self.token, "If-Match": "*"})
            with urllib.request.urlopen(request) as response:
                self.assertTrue(json.load(response)["saved"])
            with self.assertRaises(urllib.error.HTTPError) as denied:
                urllib.request.urlopen(url)
            self.assertEqual(denied.exception.code, 401)
            denied.exception.close()
            request = urllib.request.Request(url, headers={"Authorization": "Bearer " + self.token})
            with urllib.request.urlopen(request) as response:
                self.assertEqual(json.load(response)["devices"], [self.device])
        finally:
            server.shutdown(); server.server_close(); thread.join()


if __name__ == "__main__":
    unittest.main()
