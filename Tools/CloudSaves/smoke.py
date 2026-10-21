#!/usr/bin/env python3
"""Verify the private API with temporary opaque saves and remove the test vault."""
import base64
import hashlib
import json
import secrets
import sys
import urllib.error
import urllib.request
import uuid

endpoint = sys.argv[1].rstrip('/')
vault, device = str(uuid.uuid4()), str(uuid.uuid4())
token = secrets.token_hex(32)
data = secrets.token_bytes(512)
created = False

def request(path, method='GET', body=None, auth=True, match=None):
    headers = {'Content-Type': 'application/octet-stream', 'User-Agent': 'UltimateLemmingsCloudSmoke/2'}
    if auth: headers['Authorization'] = 'Bearer ' + token
    if match: headers['If-Match'] = match
    req = urllib.request.Request(endpoint + path, body, headers=headers, method=method)
    with urllib.request.urlopen(req, timeout=20) as response:
        return response.read(), response.headers.get('ETag')

root = '/v1/vaults/' + vault
try:
    request('/v1/health', auth=False)
    _, etag = request(root + '/devices/' + device, 'PUT', data, match='*')
    created = True
    fetched, _ = request(root + '/devices/' + device)
    assert fetched == data
    assert json.loads(request(root)[0])['devices'] == [device]
    for action in [lambda: request(root, auth=False),
                   lambda: request(root + '/devices/' + device, 'PUT', data + b'new', match='*')]:
        try: action(); raise AssertionError('Unsafe request accepted')
        except urllib.error.HTTPError as error: assert error.code in (401, 412); error.close()
    request(root + '/devices/' + device, 'PUT', data + b'new', match=etag)
    code = hashlib.sha256(secrets.token_bytes(16)).hexdigest()
    payload = json.dumps({'code': code, 'payload': base64.b64encode(data).decode()}).encode()
    request('/v1/links', 'POST', payload, auth=False)
    assert json.loads(request('/v1/links/' + code, 'POST', auth=False)[0])['payload'] == base64.b64encode(data).decode()
    try: request('/v1/links/' + code, 'POST', auth=False); raise AssertionError('Code reused')
    except urllib.error.HTTPError as error: assert error.code == 404; error.close()
finally:
    if created:
        request(root, 'DELETE')
print('Private cloud API: encrypted bytes round trip, ownership, stale writes and one-use links passed. Temporary vault removed.')
