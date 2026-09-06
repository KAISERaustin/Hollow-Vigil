#!/usr/bin/env python3
"""Generate read-only SQL comparing a paused, synced local save with backend rows.

Usage: python3 tools/backend_verify_save.py /absolute/path/to/qa.save
Pause gameplay, press Sync in game, then run this tool. Execute the generated
artifacts/backend-verify-save.sql using Supabase SQL/MCP. No credentials needed.
The rolling clock and visual-only fields are intentionally excluded.
"""
import argparse
import hashlib
import json
from pathlib import Path


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('save',type=Path)
    args=parser.parse_args()
    envelope=json.loads(args.save.read_text())
    if hashlib.sha256(envelope['payload'].encode()).hexdigest()!=envelope['checksum']:
        raise SystemExit('Local save checksum mismatch')
    data=json.loads(envelope['payload'])
    cloud=data.get('cloud',{})
    if not cloud.get('world_id') or cloud.get('revision',0)<1:
        raise SystemExit('This local save has no confirmed cloud revision')
    expected={'world_id':cloud['world_id'],'revision':cloud['revision'],'seed':data['seed'],
        'mode':data.get('mode','creative'),'setup':data.get('setup',{}),
        'tuning':data['settings'].get('developer_balance',{}),
        'progress':{k:data[v] for k,v in {'gold':'balance','reserve':'reserve','kills':'kills','escapes':'escapes','lifetime_earnings':'lifetime_earnings','next_tower':'next_tower','automation':'automation'}.items()},
        'regions':{k:{f:r[f] for f in ('parent','side','bend','traffic')} for k,r in data['regions'].items()},
        'towers':{k:{f:t.get(f,{'branch':'','target_mode':'first','rebuild_remaining':0,'relic':''}.get(f)) for f in ('kind','region','pad','level','branch','target_mode','rebuild_remaining','earnings','relic')} for k,t in data['towers'].items()},
        'relics':data.get('relics',{}),
        'unlocks':{k:sorted(r['unlocks']) for k,r in data['regions'].items()},
        'audio':data['settings'].get('audio',{}) if cloud.get('include_audio') else None}
    value="'"+json.dumps(expected,separators=(',',':')).replace("'","''")+"'::jsonb"
    sql="""begin;
create function pg_temp.canonical(v jsonb) returns jsonb language plpgsql immutable as $$
declare result jsonb;
begin
 case jsonb_typeof(v)
 when 'number' then return to_jsonb((v#>>'{}')::double precision);
 when 'array' then select coalesce(jsonb_agg(pg_temp.canonical(value) order by ord),'[]') into result from jsonb_array_elements(v) with ordinality as a(value,ord);
 when 'object' then select coalesce(jsonb_object_agg(key,pg_temp.canonical(value)),'{}') into result from jsonb_each(v);
 else return v;
 end case;
 return result;
end $$;
create temporary table acceptance_results(check_name text, passed boolean) on commit drop;
do $test$
declare e jsonb := pg_temp.canonical("""+value+"""); wid uuid; actual jsonb;
begin
 wid := (e->>'world_id')::uuid;
 insert into acceptance_results select 'world identity and confirmed revision',exists(select 1 from public.worlds w join public.save_revisions s on s.world_id=w.id where w.id=wid and w.seed=(e->>'seed')::bigint and s.revision>=(e->>'revision')::bigint);
 select jsonb_build_object('gold',gold,'reserve',reserve,'kills',kills,'escapes',escapes,'lifetime_earnings',lifetime_earnings,'next_tower',next_tower,'automation',automation) into actual from public.progress where world_id=wid;
 insert into acceptance_results values('progress and economy',pg_temp.canonical(actual)=e->'progress');
 select jsonb_build_object('mode',mode,'setup',setup,'tuning',tuning) into actual from public.world_rules where world_id=wid;
 insert into acceptance_results values('mode, configuration and tuning',actual=jsonb_build_object('mode',e->'mode','setup',e->'setup','tuning',e->'tuning'));
 select coalesce(jsonb_object_agg(r.local_key,jsonb_build_object('parent',coalesce(parent.local_key,''),'side',r.side,'bend',r.bend,'traffic',r.traffic)),'{}') into actual from public.regions r left join public.regions parent on parent.id=r.parent_id where r.world_id=wid;
 insert into acceptance_results values('territories and traffic',pg_temp.canonical(actual)=e->'regions');
 select coalesce(jsonb_object_agg(t.local_key,jsonb_build_object('kind',t.kind,'region',r.local_key,'pad',t.pad,'level',t.level,'branch',t.branch,'target_mode',t.target_mode,'rebuild_remaining',t.rebuild_remaining,'earnings',t.earnings,'relic',coalesce(re.source_key,''))),'{}') into actual from public.towers t join public.regions r on r.id=t.region_id left join public.relics re on re.id=t.relic_id where t.world_id=wid;
 insert into acceptance_results values('towers, upgrades, targeting and equipment',pg_temp.canonical(actual)=e->'towers');
 select coalesce(jsonb_object_agg(source_key,kind),'{}') into actual from public.relics where world_id=wid;
 insert into acceptance_results values('relic inventory',pg_temp.canonical(actual)=e->'relics');
 select jsonb_object_agg(r.local_key,coalesce((select jsonb_agg(u.kind order by u.kind) from public.unlocks u where u.region_id=r.id),'[]')) into actual from public.regions r where r.world_id=wid;
 insert into acceptance_results values('enemy unlocks',pg_temp.canonical(actual)=e->'unlocks');
 if e->'audio'<>'null'::jsonb then
  select to_jsonb(p)-'id'-'world_id' into actual from public.preferences p where world_id=wid;
  -- Check saved explicit values and row presence. Engine defaults have their own codec regression.
  insert into acceptance_results values('opted-in sound preferences',actual is not null and pg_temp.canonical(actual) @> (e->'audio'));
 end if;
 if exists(select 1 from acceptance_results where passed is distinct from true) then
  raise exception 'Backend mismatch: %',(select string_agg(check_name,', ') from acceptance_results where passed is distinct from true);
 end if;
end $test$;
select check_name,'PASS' as result from acceptance_results order by check_name;
rollback;
"""
    Path('artifacts/backend-verify-save.sql').write_text(sql)
    print('Generated read-only comparison for confirmed revision',int(cloud['revision']))

if __name__=='__main__':main()
