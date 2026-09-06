"""Manual live check. Set HOLLOW_SIGN_IN_LINK to a fresh owner email link.

Uses one new test world (seed 424242), never modifies existing worlds, and
writes only non-secret verification results to artifacts/. Credentials remain
in process memory. Run only against the configured Hollow Vigil project.
"""
import configparser
import json
import os
import ssl
import urllib.error
import urllib.parse
import urllib.request
import uuid
from pathlib import Path

cfg = configparser.ConfigParser()
cfg.read('supabase/client.cfg')
base = cfg['supabase']['url'].strip('"')
key = cfg['supabase']['publishable_key'].strip('"')
headers = {'apikey': key, 'Content-Type': 'application/json'}
context = ssl.create_default_context(cafile='/etc/ssl/cert.pem')

def post(path, data):
    req = urllib.request.Request(base + path, data=json.dumps(data).encode(), headers=headers)
    with urllib.request.urlopen(req, timeout=20, context=context) as response:
        return json.load(response)

def uid():
    return str(uuid.uuid4())

def main():
    link = urllib.parse.urlparse(os.environ['HOLLOW_SIGN_IN_LINK'])
    if link.scheme + '://' + link.netloc != base or link.path != '/auth/v1/verify':
        raise ValueError('Use a sign-in link for the configured project')
    params = urllib.parse.parse_qs(link.query)
    session = post('/auth/v1/verify', {'token_hash': params['token'][0], 'type': params['type'][0]})
    headers['Authorization'] = 'Bearer ' + session['access_token']
    print('Email authentication: passed')
    worlds = post('/rest/v1/rpc/list_saves', {})
    print('Authenticated save listing: passed; existing worlds:', len(worlds))
    wid, rid, tid = uid(), uid(), uid()
    p = {'format': 1, 'world': {'id': wid, 'seed': 424242, 'save_version': 2},
         'progress': [{'id': uid(), 'gold': 280, 'reserve': 0, 'lifetime_earnings': 0,
                       'kills': 0, 'escapes': 0, 'next_tower': 2, 'automation': False, 'first_property_required': False}],
         'checkpoints': [{'id': uid(), 'last_accounted': 1000, 'active_seconds': 0}],
         'regions': [{'id': rid, 'local_key': '0,0', 'parent_id': None, 'side': 0, 'bend': 24,
                      'traffic': 0, 'style': 'forest', 'road_version': 2, 'history_time': 0}],
         'relics': [], 'towers': [{'id': tid, 'local_key': '1', 'region_id': rid, 'kind': 'electric',
                                  'pad': 0, 'level': 1, 'branch': '', 'earnings': 15, 'target_mode': 'first',
                                  'rebuild_remaining': 0, 'relic_id': None}],
         'unlocks': [], 'encounters': [], 'production': [], 'preferences': []}
    mutation = uid()
    args = {'payload': p, 'expected_revision': 0, 'mutation': mutation}
    saved = post('/rest/v1/rpc/publish_save', args)
    assert saved['status'] == 'ok' and saved['revision'] == 1, saved
    restored = post('/rest/v1/rpc/read_save', {'world': wid})
    assert restored['payload'] == p, 'restore differs'
    assert post('/rest/v1/rpc/publish_save', args)['revision'] == 1, 'duplicate revision'
    args['mutation'] = uid()
    assert post('/rest/v1/rpc/publish_save', args)['status'] == 'conflict', 'missing conflict'
    # A future content type and enemy unlock require no table or enum changes.
    p['towers'][0]['kind'] = 'future_test_tower'
    p['unlocks'] = [{'id': uid(), 'region_id': rid, 'kind': 'future_test_enemy'}]
    assert post('/rest/v1/rpc/publish_save', {'payload': p, 'expected_revision': 1, 'mutation': uid()})['revision'] == 2
    newer = post('/rest/v1/rpc/read_save', {'world': wid})
    assert newer['payload']['towers'][0]['kind'] == 'future_test_tower'
    assert newer['payload']['unlocks'][0]['kind'] == 'future_test_enemy'
    # Leave the test world readable by today's game.
    p['towers'][0]['kind'] = 'electric'
    p['unlocks'] = []
    assert post('/rest/v1/rpc/publish_save', {'payload': p, 'expected_revision': 2, 'mutation': uid()})['revision'] == 3
    report = {'passed': True, 'world_id': wid, 'checks': ['email authentication', 'authenticated list',
              'live tower upload', 'exact restore', 'idempotent retry', 'stale revision rejection',
              'future tower and enemy keys without schema changes']}
    Path('artifacts/cloud-live-result.json').write_text(json.dumps(report, indent=2))
    print(json.dumps(report))

if __name__ == '__main__':
    try:
        main()
    except urllib.error.HTTPError as error:
        detail = json.loads(error.read())
        print('HTTP', error.code, detail.get('msg', detail.get('message', 'Request failed')))
        raise SystemExit(1)
