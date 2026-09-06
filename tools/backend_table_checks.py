#!/usr/bin/env python3
"""Build rollback-only SQL tests from Godot's real durable-save fixtures.

Run tools/cloud_payload_fixtures.gd first, then this script. Execute the output
as postgres using Supabase SQL/MCP or psql. No real player rows are changed.
"""
import json
from pathlib import Path

GROUPS = ('progress', 'checkpoints', 'regions', 'unlocks', 'towers', 'relics',
          'encounters', 'production', 'preferences', 'world_rules')

def literal(value):
    return "'" + json.dumps(value, separators=(',', ':')).replace("'", "''") + "'::jsonb"

def main():
    fixtures = json.loads(Path('artifacts/cloud-payload-fixtures.json').read_text())
    build = json.loads(Path('artifacts/cloud-public-fixture.json').read_text())
    for group in GROUPS:
        if not any(p[group] for p in fixtures):
            raise ValueError(f'No populated fixture for {group}; coverage would be misleading')
    sql = """begin;
-- PostgreSQL prints float8 values with fewer decimal digits than Godot's full
-- precision JSON writer. Compare their actual double values, not decimal spelling.
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
create temporary table backend_results(table_name text, result text) on commit drop;
grant insert, select on backend_results to authenticated;
insert into auth.users(id, raw_user_meta_data) values
 ('10000000-0000-4000-8000-000000000091','{"display_name":"Backend acceptance"}'),
 ('10000000-0000-4000-8000-000000000092','{}');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000091","role":"authenticated","user_metadata":{"display_name":"Backend acceptance"}}',true);
do $test$
declare p jsonb; actual jsonb; expected jsonb; response jsonb; g text; wid uuid; mutation uuid; n bigint;
begin
 if (select display_name from public.player_profiles where id=auth.uid()) is distinct from 'Backend acceptance' then raise exception 'Profile trigger failed'; end if;
 insert into backend_results values ('player_profiles','PASS: auth metadata projected to owned profile');
"""
    sql += ' for p in select value from jsonb_array_elements(' + literal(fixtures) + ') loop\n'
    sql += """ wid := (p->'world'->>'id')::uuid; mutation := gen_random_uuid();
 response := public.publish_save(p,0,mutation);
 if response->>'revision' is distinct from '1' then raise exception 'First publish failed: %',response; end if;
 if public.publish_save(p,0,mutation)->>'revision' is distinct from '1' then raise exception 'Retry duplicated revision'; end if;
 if public.publish_save(p,0,gen_random_uuid())->>'status' is distinct from 'conflict' then raise exception 'Stale revision accepted'; end if;
 if not exists(select 1 from public.list_saves() where world_id=wid and revision=1) then raise exception 'Listing omitted world'; end if;
 actual := public.read_save(wid)->'payload';
 if actual->'world' <> p->'world' or actual->'format' <> p->'format' then raise exception 'World identity or format lost'; end if;
"""
    sql += " foreach g in array array[" + ','.join("'"+g+"'" for g in GROUPS) + "] loop\n"
    sql += """ select coalesce(jsonb_agg(value order by value->>'id'),'[]') into expected from jsonb_array_elements(p->g);
 if pg_temp.canonical(actual->g) is distinct from pg_temp.canonical(expected) then raise exception 'Readback differs for %',g; end if;
 execute format('select coalesce(jsonb_agg(to_jsonb(r)-''world_id'' order by r.id),''[]'') from public.%I r where world_id=$1',g) into actual using wid;
 if pg_temp.canonical(actual) is distinct from pg_temp.canonical(expected) then raise exception 'Physical rows differ for %',g; end if;
 insert into backend_results values(g,'PASS: exact physical rows and RPC restore ('||jsonb_array_length(expected)||' rows)');
 actual := public.read_save(wid)->'payload';
 end loop;
 p := jsonb_set(p,'{progress,0,gold}',to_jsonb((p->'progress'->0->>'gold')::numeric+17.25));
 response := public.publish_save(p,1,gen_random_uuid());
 if response->>'revision' is distinct from '2' or (select gold from public.progress where world_id=wid) <> (p->'progress'->0->>'gold')::double precision then raise exception 'Changed progress did not persist'; end if;
 if (select count(*) from public.save_revisions where world_id=wid) <> 1 then raise exception 'Duplicate revision row'; end if;
 begin
 perform public.publish_save(jsonb_set(p,'{world_rules,0,mode}','"invalid"'),2,gen_random_uuid());
 raise exception 'Invalid mode accepted';
 exception when check_violation then null; end;
 if (select revision from public.save_revisions where world_id=wid)<>2 then raise exception 'Invalid save partially wrote'; end if;
 begin
 perform public.publish_save(jsonb_set(p-'world_rules','{format}','1'),2,gen_random_uuid());
 raise exception 'Legacy client erased custom rules';
 exception when sqlstate '22023' then null; end;
 perform set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000092","role":"authenticated"}',true);
 if public.read_save(wid) is not null then raise exception 'Another account read world'; end if;
"""
    sql += " foreach g in array array[" + ','.join("'"+g+"'" for g in GROUPS) + "] loop\n"
    sql += """ execute format('select count(*) from public.%I where world_id=$1',g) into n using wid;
 if n<>0 then raise exception 'Cross-account rows exposed: %',g; end if;
 end loop;
 perform set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000091","role":"authenticated","user_metadata":{"display_name":"Backend acceptance"}}',true);
 end loop;
 insert into backend_results values ('worlds','PASS: identity, owner, format, list, account isolation'),('save_revisions','PASS: updates, idempotency, conflicts, atomic failures, legacy overwrite denied');
end $test$;
"""
    sql += "do $test$ declare b uuid:=gen_random_uuid(); e jsonb:=" + literal(build) + "; begin\n"
    sql += """ perform public.publish_public_build(b,e,now());
 perform public.publish_public_build(b,e,now());
 if (select count(*) from public.public_builds where id=b) <> 1 or public.read_public_build(b)->'configuration' is distinct from e then raise exception 'Public build exact round trip failed'; end if;
 if (select author_name from public.public_builds where id=b) <> 'Backend acceptance' then raise exception 'Public author missing'; end if;
 insert into backend_results values('public_builds','PASS: real exported build, exact readback, author, idempotency');
end $test$;
select table_name, string_agg(distinct result, '; ' order by result) as result from backend_results group by table_name order by table_name;
rollback;
"""
    Path('artifacts/backend-table-checks.sql').write_text(sql)
    print('Generated rollback-only checks for all 14 application tables from', len(fixtures), 'real save fixtures')

if __name__ == '__main__':
    main()
