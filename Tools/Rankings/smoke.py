#!/usr/bin/env python3
"""Exercise a deployed service using a temporary player, then delete that player."""
import argparse
import hashlib
import json
import secrets
import urllib.request
import urllib.error
import uuid
from server import canonical, checked_conditions

parser = argparse.ArgumentParser()
parser.add_argument('endpoint')
args = parser.parse_args()
base = args.endpoint.rstrip('/')
token = secrets.token_hex(32)

def call(path, method='GET', payload=None, movie=None, auth=False, return_headers=False):
    headers = {"User-Agent": "UltimateLemmings/1.9.2 DeploymentCheck"}
    if auth: headers['Authorization'] = 'Bearer ' + token
    data = None
    if payload is not None:
        data = canonical(payload).encode(); headers['Content-Type'] = 'application/json'
    if movie is not None:
        data = movie; headers['Content-Type'] = 'video/mp4'
    with urllib.request.urlopen(urllib.request.Request(base + path, data=data, headers=headers, method=method),timeout=30) as r:
        return r.headers if return_headers else r.status, r.read()

c = dict(gameID='rankings-smoke', packID='deployment', levelID=str(uuid.uuid4()), levelFingerprint='smoke-v1',
         rulesetVersion='v1', physicsMode='test', population=10, rescueRequirement=5, startingSkills={}, modifiers={}, rewindPolicy='separate-assisted-v1')
key = checked_conditions(canonical(c))[1]
rid = str(uuid.uuid4())
movie = b'\x00\x00\x00\x18ftypisom' + b'\x00'*12
registered = False
try:
    assert json.loads(call('/v1/health')[1])['status']=='ok'
    call('/v1/players','POST',dict(name='TST'),auth=True); registered=True
    payload=dict(id=rid, conditionsJSON=canonical(c), assisted=True, saved=10, population=10, skills=0, milliseconds=10000, won=True)
    call('/v1/runs','POST',payload,auth=True)
    call('/v1/runs','POST',payload,auth=True)
    call('/v1/replays/'+rid,'PUT',movie=movie,auth=True)
    actions=dict(version=1,runID=rid,conditions=c,engine='classic',engineFingerprint='deployment-check',
                 initialStateHash='a'*64,finalStateHash='b'*64,ticks=170,saved=10,population=10,
                 skills=0,won=True,assisted=True,commands=[])
    call('/v1/actions/'+rid,'PUT',payload=actions,auth=True)
    headers,received=call('/v1/actions/'+rid,return_headers=True)
    assert json.loads(received)==actions
    assert headers['X-Replay-SHA256']==hashlib.sha256(received).hexdigest()

    board=json.loads(call('/v1/boards?conditions='+key+'&board=fastestAllSaved&assisted=1&page=0')[1])
    assert len(board['entries'])==1 and board['entries'][0]['score']==10000 and board['entries'][0]['replay'] and board['entries'][0]['actionReplay']
    assert json.loads(call('/v1/boards?conditions='+key+'&board=fastestAllSaved&assisted=0&page=0')[1])['entries']==[]
    assert hashlib.sha256(call('/v1/replays/'+rid)[1]).digest()==hashlib.sha256(movie).digest()
    try: call('/v1/runs','POST',payload)
    except urllib.error.HTTPError as e: assert e.code==401; e.close()
    else: raise AssertionError('Unauthenticated submission accepted')
    print('PASS live health, authenticated idempotent score, rewind separation, action/movie upload/download and authentication')
finally:
    if registered: call('/v1/player','DELETE',auth=True)
assert json.loads(call('/v1/boards?conditions='+key+'&board=fastestAllSaved&assisted=1&page=0')[1])['entries']==[]
try: call('/v1/replays/'+rid)
except urllib.error.HTTPError as e: assert e.code==404; e.close()
else: raise AssertionError('Deleted movie remains public')
print('PASS temporary player, records and movie removed')

try: call('/v1/actions/'+rid)
except urllib.error.HTTPError as e: assert e.code==404; e.close()
else: raise AssertionError('Deleted action replay remains public')
print('PASS temporary action replay removed')
