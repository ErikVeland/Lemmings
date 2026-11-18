import io
import hashlib
import sqlite3
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
    def action_payload(self, p, **kw):
        return dict(dict(version=1, runID=p['id'], conditions=json.loads(p['conditionsJSON']),
                         engine='classic', engineFingerprint='engine-v1', initialStateHash='a'*64,
                         finalStateHash='b'*64, ticks=170, saved=p['saved'], population=p['population'],
                         skills=p['skills'], won=p['won'], assisted=p['assisted'],
                         commands=[dict(tick=50,action='assign',lemming=0,skill=2)]), **kw)
    def upload_actions(self, p, value=None, player=None):
        data=canonical(value or self.action_payload(p)).encode()
        self.store.upload_actions(player or self.a,p['id'],io.BytesIO(data),len(data))
        return data
    def test_native_bonus_actions_are_stored_for_each_engine(self):
        # These command envelopes use the native skill slots and L3 tool raw values.
        cases = [
            ('classic', 'lemmings', 170, {'builder': 11}, {'bonus-skill-v1': 'builder'},
             dict(tick=0, action='bonusSkill', skill=4)),
            ('neolemmix', 'neolemmix', 170, {'builder': 11}, {'bonus-skill-v1': 'builder'},
             dict(tick=0, action='bonusSkill', skill=0)),
            ('lemmings2', 'lemmings2', 175, {'builder': 11}, {'bonus-skill-v1': 'builder'},
             dict(tick=0, action='bonusSkill', skill=7)),
            ('lemmings3', 'lemmings3', 230, {},
             {'bonus-skill-v1': 'swimmer', 'bonus-original-tool-v1': 'swimmer'},
             dict(tick=0, action='bonusTool', lemming=0, skill=5008)),
        ]
        for raw, name in enumerate(('bricks', 'bomb', 'spade', 'shimmy', 'sucker', 'umbrella', 'hadoken', 'grenade', 'swimmer'), 5000):
            cases.append(('lemmings3', 'lemmings3', 230, {},
                          {'bonus-skill-v1': name, 'bonus-original-tool-v1': name},
                          dict(tick=0, action='bonusTool', lemming=0, skill=raw)))
        for engine, game, ticks, stock, modifiers, command in cases:
            with self.subTest(engine=engine):
                conditions = dict(CONDITIONS, gameID=game, startingSkills=stock, modifiers=modifiers)
                run = self.add(conditionsJSON=canonical(conditions), skills=0)
                value = self.action_payload(run, engine=engine, ticks=ticks, commands=[command])
                try:
                    self.upload_actions(run, value)
                except ValueError as error:
                    self.fail(f'Valid native {engine} bonus action was rejected: {error}')
                stored = json.loads((self.store.movies / (run['id'] + '.actions.json')).read_text())
                self.assertEqual(stored['commands'], [command])
                board = self.entries('mostSaved', key=checked_conditions(run['conditionsJSON'])[1])
                self.assertTrue(board[0]['actionReplay'])
                self.store.delete_player(self.a)
                self.assertFalse((self.store.movies / (run['id'] + '.actions.json')).exists())
                self.a = self.store.identity('a'*64, 'UVA')

    def test_bonus_actions_reject_extra_grants_and_invalid_native_fields(self):
        conditions = dict(CONDITIONS, startingSkills={'builder': 11}, modifiers={'bonus-skill-v1': 'builder'})
        grant = dict(tick=0, action='bonusSkill', skill=4)
        cases = [
            ('classic', CONDITIONS, [grant]),
            ('classic', dict(conditions, modifiers={'bonus-skill-v1': ''}), [grant]),
            ('classic', dict(conditions, startingSkills={'builder': 1}), [grant]),
            ('classic', conditions, [grant, dict(grant, tick=1)]),
            ('classic', conditions, [dict(grant, skill=True)]),
            ('classic', conditions, [dict(grant, skill=-1)]),
            ('classic', conditions, [dict(grant, skill=8)]),
            ('classic', conditions, [dict(grant, skill=3)]),
            ('classic', dict(conditions, modifiers={'bonus-skill-v1': 'builder', 'bonus-original-tool-v1': 'builder'}), [grant]),
            ('classic', conditions, [dict(grant, lemming=0)]),
            ('classic', conditions, [dict(tick=0, action='bonusTool', lemming=0, skill=5000)]),
            ('lemmings2', dict(conditions, gameID='lemmings2'), [dict(grant, skill=8)]),
            ('neolemmix', dict(conditions, gameID='neolemmix'), [dict(grant, skill=32)]),
        ]
        l3 = dict(CONDITIONS, gameID='lemmings3', startingSkills={},
                  modifiers={'bonus-skill-v1': 'bricks', 'bonus-original-tool-v1': 'bricks'})
        tool = dict(tick=0, action='bonusTool', lemming=0, skill=5000)
        cases.extend([
            ('lemmings3', l3, [dict(tool, skill=4999)]),
            ('lemmings3', l3, [dict(tool, skill=5009)]),
            ('lemmings3', l3, [dict(tool, skill=True)]),
            ('lemmings3', l3, [dict(tool, lemming=-1)]),
            ('lemmings3', l3, [dict(tool, skill=5001)]),
            ('lemmings3', l3, [dict(tick=0, action='bonusTool', skill=5000)]),
            ('lemmings3', l3, [dict(tick=0, action='bonusSkill', skill=0)]),
            ('lemmings3', l3, [tool, dict(tool, tick=1)]),
            ('lemmings3', dict(l3, modifiers={'bonus-skill-v1': 'bricks'}), [tool]),
        ])
        for engine, conditions, commands in cases:
            with self.subTest(engine=engine, commands=commands, conditions=conditions):
                ticks = {'classic': 170, 'neolemmix': 170, 'lemmings2': 175, 'lemmings3': 230}[engine]
                run = self.add(conditionsJSON=canonical(conditions), skills=0)
                with self.assertRaises(ValueError):
                    self.upload_actions(run, self.action_payload(run, engine=engine, ticks=ticks, commands=commands))
                self.assertFalse((self.store.movies / (run['id'] + '.actions.json')).exists())
        # A rewind can remove the grant while retaining the run's bonus conditions.
        run = self.add(conditionsJSON=canonical(dict(CONDITIONS, startingSkills={'builder': 11},
                       modifiers={'bonus-skill-v1': 'builder'})), skills=0)
        self.upload_actions(run, self.action_payload(run, commands=[]))
        self.assertTrue((self.store.movies / (run['id'] + '.actions.json')).is_file())

    def test_old_database_migration_preserves_credentials_scores_and_movies(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            player, run_id = str(uuid.uuid4()), str(uuid.uuid4())
            (root / 'replays').mkdir()
            (root / 'replays' / (run_id + '.mp4')).write_bytes(MOVIE)
            with sqlite3.connect(root / 'rankings.sqlite3') as db:
                db.executescript("""
                    CREATE TABLE players (id TEXT PRIMARY KEY, token TEXT UNIQUE NOT NULL, name TEXT NOT NULL);
                    CREATE TABLE runs (id TEXT PRIMARY KEY, player TEXT NOT NULL, conditions TEXT NOT NULL,
                        board_key TEXT NOT NULL, level_key TEXT NOT NULL, assisted INTEGER NOT NULL,
                        saved INTEGER NOT NULL, population INTEGER NOT NULL, skills INTEGER NOT NULL,
                        milliseconds INTEGER NOT NULL, won INTEGER NOT NULL, stars INTEGER NOT NULL,
                        submitted INTEGER NOT NULL, replay_bytes INTEGER NOT NULL DEFAULT 0);
                """)
                db.execute('INSERT INTO players VALUES(?,?,?)',
                           (player, hashlib.sha256(('a'*64).encode()).hexdigest(), 'OLD'))
                db.execute('INSERT INTO runs VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
                           (run_id, player, canonical(CONDITIONS), self.key, canonical(['lemmings','pack','1']),
                            0, 8, 10, 2, 10000, 1, 2, 123456, len(MOVIE)))
            migrated = Store(root)
            self.assertEqual(migrated.identity('a'*64), player)
            row = migrated.board(self.key, 'mostSaved', False)['entries'][0]
            self.assertEqual((row['name'], row['score'], row['runID'], row['replay'], row['actionReplay']),
                             ('OLD', 8, run_id, True, False))
            self.assertEqual((root / 'replays' / (run_id + '.mp4')).read_bytes(), MOVIE)
            with migrated.db() as db:
                self.assertEqual(db.execute('SELECT COUNT(*) FROM runs').fetchone()[0], 1)
                self.assertEqual(db.execute('SELECT action_bytes FROM runs').fetchone()[0], 0)
            restarted = Store(root)
            self.assertEqual(restarted.identity('a'*64), player)
            self.assertEqual(restarted.board(self.key, 'mostSaved', False)['entries'][0], row)

    def test_action_identity_ownership_immutability_delete_and_restart(self):
        p=self.add()
        with self.assertRaises(PermissionError): self.upload_actions(p,player=self.b)
        self.upload_actions(p)
        self.assertTrue(self.entries('mostSaved')[0]['actionReplay'])
        self.assertFalse(self.entries('mostSaved')[0]['replay'])
        with self.assertRaises(FileExistsError): self.upload_actions(p)
        self.store=Store(self.temp.name)
        self.assertTrue(self.entries('fastestClear')[0]['actionReplay'])
        self.assertFalse(self.entries('stars')[0]['actionReplay'])
        self.store.delete_player(self.a)
        self.assertEqual(list(self.store.movies.iterdir()),[])
    def test_action_rejects_snapshots_mismatches_and_bad_commands(self):
        p=self.add()
        valid=self.action_payload(p)
        bad=[dict(valid,initialState={}),dict(valid,runID=None),dict(valid,runID=str(uuid.uuid4())),dict(valid,saved=9),
             dict(valid,ticks=171),dict(valid,finalStateHash='bad'),dict(valid,assisted=1),
             dict(valid,conditions=dict(CONDITIONS,levelID='2')),
             dict(valid,commands=[dict(tick=171,action='nuke')]),
             dict(valid,commands=[dict(tick=2,action='nuke'),dict(tick=1,action='nuke')]),
             dict(valid,commands=[dict(tick=0,action='assign',skill=8,lemming=0)]),
             dict(valid,commands=[dict(tick=0,action='nuke',path='/private')])]
        for value in bad:
            with self.subTest(value=value):
                with self.assertRaises(ValueError): self.upload_actions(p,value)
        self.assertEqual(list(self.store.movies.iterdir()),[])
        self.assertFalse(self.entries('mostSaved')[0]['actionReplay'])
    def test_top_ten_per_category_conditions_and_assistance(self):
        players=[]
        for i in range(12):
            player=self.store.identity(f'{i+16:064x}',str(i))
            p=self.add(player=player,saved=10,milliseconds=10000+i*1000,skills=i)
            value=self.action_payload(p,ticks=170+i*17)
            self.upload_actions(p,value,player)
            players.append((player,p))
        self.assertTrue(all(e['actionReplay'] for page in (0,1) for e in self.entries('fastestClear',page=page)))
        self.assertFalse(any(e['actionReplay'] for e in self.entries('fastestClear',page=2)))
        self.assertFalse(self.store.top_ten(players[-1][1]['id']))
        # A slow run can still lead least skills, so its replay remains public.
        player,p=players[-1]
        improved=self.add(player=player,saved=10,milliseconds=30000,skills=0)
        self.upload_actions(improved,self.action_payload(improved,ticks=510),player)
        self.assertTrue(self.store.top_ten(improved['id']))
        # Separate assisted ranks do not displace unassisted entries.
        other=self.add(player=player,assisted=True,milliseconds=1000)
        self.upload_actions(other,self.action_payload(other,ticks=17,commands=[]),player)
        self.assertTrue(self.store.top_ten(other['id']))
    def test_zero_tick_end_run_actions(self):
        c=dict(CONDITIONS,gameID='lemmings3')
        p=self.add(conditionsJSON=canonical(c),milliseconds=0,saved=0,skills=0,won=False)
        value=self.action_payload(p,engine='lemmings3',ticks=0,commands=[dict(tick=0,action='abort')])
        self.upload_actions(p,value)
        self.assertTrue(self.entries('mostSaved',key=checked_conditions(p['conditionsJSON'])[1])[0]['actionReplay'])
        self.assertEqual(self.entries('fastestClear',key=checked_conditions(p['conditionsJSON'])[1]),[])
    def test_action_quota_and_incomplete_upload_preserve_score(self):
        p=self.add();data=canonical(self.action_payload(p)).encode()
        with self.assertRaises(ValueError): self.store.upload_actions(self.a,p['id'],io.BytesIO(data[:-1]),len(data))
        with patch('server.MAX_STORAGE',len(data)-1):
            with self.assertRaises(OverflowError): self.upload_actions(p)
        self.assertEqual(len(self.entries('mostSaved')),1)
        self.assertEqual(list(self.store.movies.iterdir()),[])
    def test_action_http_contract_and_hash(self):
        import hashlib
        p=self.add();data=canonical(self.action_payload(p)).encode()
        server=Server(('127.0.0.1',0),Handler);server.store=self.store
        thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
        url=f'http://127.0.0.1:{server.server_port}/v1/actions/'+p['id']
        try:
            request=urllib.request.Request(url,data=data,method='PUT',headers={'Content-Type':'application/json','Authorization':'Bearer '+'a'*64})
            with urllib.request.urlopen(request) as response: self.assertEqual(response.status,204)
            with urllib.request.urlopen(url) as response:
                self.assertEqual(response.read(),data)
                self.assertEqual(response.headers['X-Replay-SHA256'],hashlib.sha256(data).hexdigest())
                self.assertEqual(response.headers.get_content_type(),'application/json')
            self.store.delete_player(self.a)
            with self.assertRaises(urllib.error.HTTPError) as error: urllib.request.urlopen(url)
            self.assertEqual(error.exception.code,404);error.exception.close()
        finally: server.shutdown();server.server_close();thread.join()
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
        # Every career board sends all three totals so one row can show them as columns.
        row = self.entries('clears')[0]
        self.assertEqual((row['stars'], row['clears'], row['perfect']), (3, 1, 1))
        self.assertNotIn('stars', self.entries('mostSaved')[0])
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
