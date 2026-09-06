#!/usr/bin/env python3
"""Launch a real, authenticated QA playthrough without consuming sign-in emails.

--create-account uses the signed-in Supabase CLI's admin authority once. The
client receives only a normal QA user's password, never an admin/service key.
Credentials live outside the repository with owner-only permissions.
"""
import argparse
import configparser
import json
import os
from pathlib import Path
import secrets
import ssl
import subprocess
import urllib.request
import urllib.error

ROOT = Path(__file__).resolve().parents[1]
CREDENTIALS = Path.home() / '.config/hollow-vigil/qa-account.json'
PROJECT = 'sjjohzftzshgceamffhx'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--create-account', action='store_true')
    parser.add_argument('--runner', default='tools/cloud_playthrough.gd')
    parser.add_argument('--headless', action='store_true')
    args = parser.parse_args()
    cfg = configparser.ConfigParser()
    cfg.read(ROOT / 'supabase/client.cfg')
    base = cfg['supabase']['url'].strip('"')
    if base != f'https://{PROJECT}.supabase.co':
        raise SystemExit('QA launcher is restricted to the Hollow Vigil project')
    if not CREDENTIALS.exists():
        if not args.create_account:
            raise SystemExit('No QA account configured. Use --create-account with project admin authorization.')
        response = subprocess.run(['supabase','projects','api-keys','--project-ref',PROJECT,'--output','json'], capture_output=True, text=True, check=True)
        keys = json.loads(response.stdout)
        admin = next(k['api_key'] for k in keys if k['name'] == 'service_role')
        credentials = {'email': 'hollow-vigil-qa-' + secrets.token_hex(6) + '@example.com', 'password': secrets.token_urlsafe(36), 'project': PROJECT}
        body = {**{k:credentials[k] for k in ('email','password')}, 'email_confirm': True,
                'user_metadata': {'display_name':'Hollow Vigil QA', 'purpose':'cloud acceptance testing'}}
        req = urllib.request.Request(base+'/auth/v1/admin/users',data=json.dumps(body).encode(),
                headers={'apikey':admin,'Authorization':'Bearer '+admin,'Content-Type':'application/json'})
        context = ssl.create_default_context(cafile='/etc/ssl/cert.pem')
        with urllib.request.urlopen(req,context=context,timeout=30) as reply:
            account=json.load(reply)
        credentials['user_id']=account['id']
        CREDENTIALS.parent.mkdir(parents=True,exist_ok=True,mode=0o700)
        fd=os.open(CREDENTIALS,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600)
        with os.fdopen(fd,'w') as f: json.dump(credentials,f)
        print('Created pre-verified QA account:',account['id'],flush=True)
    credentials=json.loads(CREDENTIALS.read_text())
    if credentials['project'] != PROJECT:
        raise SystemExit('QA account belongs to a different project')
    os.chmod(CREDENTIALS,0o600)
    env=os.environ.copy()
    env['HOLLOW_QA_EMAIL']=credentials['email']
    env['HOLLOW_QA_PASSWORD']=credentials['password']
    godot=env.get('GODOT_PATH') or next(str(p) for p in [Path('/Applications/Godot.app/Contents/MacOS/Godot'),Path.home()/'Downloads/Godot.app/Contents/MacOS/Godot'] if p.exists())
    cmd=[godot,'--path',str(ROOT),'--audio-driver','Dummy','--script',args.runner]
    if args.headless: cmd.append('--headless')
    print('Launching QA with normal authenticated-user permissions; no credentials logged.',flush=True)
    raise SystemExit(subprocess.call(cmd,cwd=ROOT,env=env))

if __name__ == '__main__':
    try: main()
    except urllib.error.HTTPError as error:
        raise SystemExit(f'QA account request failed: HTTP {error.code}; credentials were not logged')
