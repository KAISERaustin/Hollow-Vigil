#!/usr/bin/env python3
"""Opt-in live REST verification; leaves one clearly labeled QA report for admin readback."""
import configparser,json,urllib.request,urllib.error,uuid
from pathlib import Path
cfg=configparser.ConfigParser(); cfg.read(Path(__file__).resolve().parents[1] / 'supabase/client.cfg')
base=cfg['supabase']['url'].strip('"'); key=cfg['supabase']['publishable_key'].strip('"')
id=str(uuid.uuid4()); payload={'id':id,'title':'QA 1.1.1 bug report integration','description':'Automated release verification. Steps: open main menu Settings, Bug report, enter title and description, Upload. Expected: private report stored once.','app_version':'1.1.1','platform':'macOS'}
def req(method,data=None,path=''):
 r=urllib.request.Request(base+'/rest/v1/bug_reports'+path,data=json.dumps(data).encode() if data is not None else None,method=method,headers={'apikey':key,'Content-Type':'application/json'})
 try:
  with urllib.request.urlopen(r,timeout=25) as response: return response.status,response.read().decode()
 except urllib.error.HTTPError as e: return e.code,e.read().decode()
checks=[]
status,body=req('POST',payload); checks.append((status==201,'valid insert',status))
status,body=req('POST',payload); checks.append((status==409 and '23505' in body,'duplicate rejected',status))
for field,value in [('title',''),('description',' '*4),('description','x'*5001),('platform','unknown')]:
 bad=payload|{'id':str(uuid.uuid4()),field:value}; status,_=req('POST',bad); checks.append((status==400,'invalid '+field,status))
for method,data in [('GET',None),('PATCH',{'title':'changed'}),('DELETE',None)]:
 status,_=req(method,data,'?id=eq.'+id); checks.append((status in [401,403],method+' denied',status))
print(json.dumps({'id':id,'checks':checks},indent=2))
assert all(x[0] for x in checks)
