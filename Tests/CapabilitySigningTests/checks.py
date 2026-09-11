import copy, datetime, hashlib, importlib.util, pathlib, plistlib, subprocess
from unittest.mock import patch
spec = importlib.util.spec_from_file_location('signing', 'Scripts/sign-capabilities.py')
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
certificate = b'test certificate'
fingerprint = hashlib.sha1(certificate).hexdigest().upper()
p = {'Platform':['OSX'], 'ExpirationDate':datetime.datetime(2099,1,1), 'DeveloperCertificates':[certificate],
     'Entitlements':dict.fromkeys(m.CAPABILITIES, True)}
p['Entitlements'].update({'com.apple.application-identifier':'TEAM.'+m.BUNDLE_ID, 'com.apple.developer.team-identifier':'TEAM'})
def select(profile, identity=fingerprint):
    with patch.object(m.subprocess,'run',return_value=subprocess.CompletedProcess([],0,stdout=plistlib.dumps(profile))):
        return m.select_profile([pathlib.Path('test.provisionprofile')],identity)
assert select(p)[2] == fingerprint
for kind in ('capability','expired','bundle','platform','identity'):
    bad=copy.deepcopy(p)
    if kind == 'capability': bad['Entitlements'][m.CAPABILITIES[1]]=False
    if kind == 'expired': bad['ExpirationDate']=datetime.datetime(2000,1,1)
    if kind == 'bundle': bad['Entitlements']['com.apple.application-identifier']='TEAM.other'
    if kind == 'platform': bad['Platform']=['iOS']
    try: select(bad, '' if kind == 'identity' else fingerprint)
    except SystemExit: pass
    else: raise AssertionError(kind)
print('Signing validation: matching profile accepted; missing capability, expiry, wrong app/platform and unavailable identity rejected.')
