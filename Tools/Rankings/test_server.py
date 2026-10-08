import io
import json
from pathlib import Path
import tempfile
import threading
import unittest
import urllib.request
import urllib.error
import uuid
from unittest.mock import patch
from server import Store, Server, Handler, canonical, checked_conditions

CONDITIONS = dict(gameID='lemmings', packID='pack', levelID='1', levelFingerprint='abc', rulesetVersion='v1', physicsMode='classic', population=10, rescueRequirement=5, startingSkills={'builder':10}, modifiers={}, rewindPolicy='separate-assisted-v1', timeLimitSeconds=300)
MOVIE = b'\x00\x00\x00\x18ftypisom' + b'\x00' * 12

class RankingsTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.store = Store(self.temp.name)
        self.a = self.store.identity('a'*64, 'UVA')
        self.b = self.store.identity('b'*64, 'EKV')
        self.key = checked_conditions(canonical(CONDITIONS))[1]
    def tearDown(self):
        self.temp.cleanup()
    def run_payload(self, **kw):
        return dict(dict(id=str(uuid.uuid4()), conditionsJSON=canonical(CONDITIONS), assisted=False, saved=8, population=10, skills=2, milliseconds=10000, won=True), **kw)
    def add(self, player=None, **kw):
        p = self.run_payload(**kw); self.store.submit(player or self.a, p); return p
    def entries(self, category, assisted=False, key=None, page=0):
        return self.store.board(key or self.key, category, assisted, page)['entries']
    def test_auth_identity_and_rename(self):
        self.assertEqual(self.a, self.store.identity('a'*64, 'ABC'))
        self.assertNotEqual(self.a, self.b)
        with self.assertRaises(PermissionError): self.store.identity('c'*64)
        with self.assertRaises(ValueError): self.store.identity('d'*64, 'name with email')
    def test_immutable_id_and_catalogue_changes(self):
        p = self.add()
        self.store.targets[self.key] = 8
        self.assertEqual(self.store.submit(self.a, p), p['id'])
        with self.assertRaises(ValueError): self.store.submit(self.b, p)
        with self.assertRaises(ValueError): self.store.submit(self.a, dict(p, saved=9))
    def test_speed_categories_and_assistance(self):
        self.add(saved=10, milliseconds=4000)
        self.add(saved=5, milliseconds=2000)
        self.add(saved=10, milliseconds=500, won=False)
        self.add(saved=10, milliseconds=0)
        self.add(saved=10, milliseconds=1, assisted=True)
        self.add(player=self.b, saved=10, milliseconds=3000)
        clear = self.entries('fastestClear'); full = self.entries('fastestAllSaved')
        self.assertEqual([(x['name'],x['score']) for x in clear], [('UVA',2000),('EKV',3000)])
        self.assertEqual([(x['name'],x['score']) for x in full], [('EKV',3000),('UVA',4000)])
        self.assertEqual(self.entries('fastestClear', True)[0]['score'], 1)
        self.assertEqual(self.entries('fastestClear', key='0'*64), [])
    def test_rescue_efficiency_and_career_dedup(self):
        self.add(saved=6, skills=1)
        self.add(saved=10, skills=4)
        self.add(saved=10, skills=3)
        self.add(saved=9, skills=0, won=False)
        self.assertEqual(self.entries('mostSaved')[0]['score'], 10)
        self.assertEqual(self.entries('leastSkills')[0]['score'], 1)
        self.assertEqual(self.entries('stars')[0]['score'], 3)
        self.assertEqual(self.entries('clears')[0]['score'], 1)
        self.assertEqual(self.entries('perfect')[0]['score'], 1)
    def test_catalogue_target_and_cloner_ceiling(self):
        self.store.targets[self.key] = 8
        self.add(saved=8)
        self.assertEqual(self.entries('stars')[0]['score'],3)
        c = dict(CONDITIONS, startingSkills={'cloner':2})
        self.add(player=self.b, saved=10, conditionsJSON=canonical(c))
        self.assertEqual(next(x for x in self.entries('stars') if x['name']=='EKV')['score'],2)
    def test_pagination_has_no_empty_extra_page(self):
        for i in range(5):
            p = self.store.identity(f'{i+16:064x}', str(i)); self.add(player=p)
        self.assertFalse(self.store.board(self.key,'mostSaved',False)['hasMore'])
        self.add()
        self.assertTrue(self.store.board(self.key,'mostSaved',False)['hasMore'])
        self.assertEqual(len(self.entries('mostSaved',page=1)),1)
    def test_replay_ownership_validation_and_delete(self):
        p = self.add(); rid=p['id']
        with self.assertRaises(PermissionError): self.store.upload(self.b,rid,io.BytesIO(MOVIE),len(MOVIE))
        with self.assertRaises(ValueError): self.store.upload(self.a,rid,io.BytesIO(b'bad'*10),30)
        with self.assertRaises(ValueError): self.store.upload(self.a,rid,io.BytesIO(MOVIE),100)
        self.assertEqual(list(self.store.movies.iterdir()), [])
        self.store.upload(self.a,rid,io.BytesIO(MOVIE),len(MOVIE))
        self.assertTrue(self.entries('mostSaved')[0]['replay'])
        with self.assertRaises(FileExistsError): self.store.upload(self.a,rid,io.BytesIO(MOVIE),len(MOVIE))
        self.store.delete_player(self.a)
        self.assertEqual(list(self.store.movies.iterdir()),[])
        self.assertEqual(self.entries('mostSaved'),[])
    def test_movie_quota_preserves_score(self):
        rid = self.add()['id']
        with patch('server.MAX_STORAGE', len(MOVIE)-1):
            with self.assertRaises(OverflowError): self.store.upload(self.a,rid,io.BytesIO(MOVIE),len(MOVIE))
        self.assertEqual(len(self.entries('mostSaved')),1)
        self.assertFalse(self.entries('mostSaved')[0]['replay'])
        self.assertEqual(list(self.store.movies.iterdir()),[])
    def test_catalogue_restart_reassesses_stars(self):
        self.add(saved=8)
        self.assertEqual(self.entries('stars')[0]['score'],2)
        catalogue = Path(self.temp.name) / 'catalogue.json'
        catalogue.write_text(canonical(dict(levels=[dict(conditions=CONDITIONS,witness=dict(completed=True,didWin=True,saved=8))])))
        self.store = Store(self.temp.name,catalogue)
        self.assertEqual(self.entries('stars')[0]['score'],3)
    def test_http_contract(self):
        server = Server(('127.0.0.1',0), Handler); server.store=self.store
        thread = threading.Thread(target=server.serve_forever,daemon=True); thread.start()
        base=f'http://127.0.0.1:{server.server_port}'
        try:
            with urllib.request.urlopen(base+'/v1/health') as response: self.assertEqual(response.status,200)
            request=urllib.request.Request(base+'/v1/runs',data=canonical(self.run_payload()).encode(), headers={'Content-Type':'application/json'})
            with self.assertRaises(urllib.error.HTTPError) as error: urllib.request.urlopen(request)
            self.assertEqual(error.exception.code,401); error.exception.close()
            request.add_header('Authorization','Bearer '+'a'*64)
            with urllib.request.urlopen(request) as response: self.assertEqual(response.status,200)
        finally: server.shutdown();server.server_close();thread.join()
    def test_reject_invalid_counts_and_condition_extensions(self):
        for changes in [dict(saved=11),dict(milliseconds=-1),dict(population=11),dict(assisted=1),dict(saved=True)]:
            with self.assertRaises(ValueError): self.store.submit(self.a,self.run_payload(**changes))
        with self.assertRaises(ValueError): checked_conditions(canonical(dict(CONDITIONS,email='secret')))

if __name__=='__main__': unittest.main()
