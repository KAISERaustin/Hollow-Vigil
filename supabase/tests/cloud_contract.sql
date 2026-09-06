-- Disposable fixtures exist only inside this transaction. No real player data.
begin;
insert into auth.users(id) values('10000000-0000-4000-8000-000000000001'),('10000000-0000-4000-8000-000000000002');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
do $test$
declare
 p jsonb := '{"format":1,"world":{"id":"20000000-0000-4000-8000-000000000001","seed":42,"save_version":2},"progress":[{"id":"30000000-0000-4000-8000-000000000001","gold":280,"reserve":0,"lifetime_earnings":0,"kills":0,"escapes":0,"next_tower":1,"automation":false,"first_property_required":true}],"checkpoints":[{"id":"40000000-0000-4000-8000-000000000001","last_accounted":1000,"active_seconds":0}],"regions":[{"id":"50000000-0000-4000-8000-000000000001","local_key":"0,0","parent_id":null,"side":0,"bend":24,"traffic":0,"style":"forest","road_version":2,"history_time":0}],"relics":[],"towers":[],"unlocks":[],"encounters":[],"production":[],"preferences":[]}';
 r jsonb;
 rejected boolean;
begin
 r:=public.publish_save(p,0,'60000000-0000-4000-8000-000000000001');
 if r->>'status'<>'ok' or r->>'revision'<>'1' then raise exception 'First upload failed: %',r; end if;
 r:=public.read_save('20000000-0000-4000-8000-000000000001');
 if r->'payload'<>p then raise exception 'Round trip differs: %',r; end if;
 r:=public.publish_save(p,0,'60000000-0000-4000-8000-000000000001');
 if r->>'revision'<>'1' then raise exception 'Retry duplicated revision'; end if;
 r:=public.publish_save(p,0,'60000000-0000-4000-8000-000000000002');
 if r->>'status'<>'conflict' then raise exception 'Stale save was accepted'; end if;
 rejected:=false;
 begin perform public.publish_save(p||'{"camera":[0,0,1]}'::jsonb,1,gen_random_uuid()); exception when sqlstate '22023' then rejected:=true; end;
 if not rejected then raise exception 'Unknown field accepted'; end if;
 rejected:=false;
 begin perform public.publish_save(jsonb_set(p,'{progress,0,gold}','-1'),1,gen_random_uuid()); exception when check_violation then rejected:=true; end;
 if not rejected then raise exception 'Negative gold accepted'; end if;
 if (select revision from public.save_revisions where world_id='20000000-0000-4000-8000-000000000001')<>1 then raise exception 'Failed upload mutated revision'; end if;
 rejected:=false;
 begin update public.progress set gold=999; exception when insufficient_privilege then rejected:=true; end;
 if not rejected then raise exception 'Direct writes bypass revision guard'; end if;
 perform set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
 if public.read_save('20000000-0000-4000-8000-000000000001') is not null or exists(select 1 from public.list_saves()) then raise exception 'Another player can read saves'; end if;
 rejected:=false;
 begin perform public.publish_save(p,1,gen_random_uuid()); exception when insufficient_privilege then rejected:=true; end;
 if not rejected then raise exception 'Another player can write world'; end if;
 perform set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
 r:=public.publish_save(jsonb_set(p,'{checkpoints,0,last_accounted}','900'),1,gen_random_uuid());
 if r->>'revision'<>'2' or (select last_accounted from public.checkpoints where world_id='20000000-0000-4000-8000-000000000001')<>1000 then raise exception 'Reward watermark moved backwards'; end if;
end $test$;
reset role;
select 'PASS: round trip, idempotency, conflicts, allowlist, constraints, atomic rollback, direct-write denial, player isolation and reward watermark' as result;
rollback;
