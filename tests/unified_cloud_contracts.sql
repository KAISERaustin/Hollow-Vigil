-- Live contract verification: every fixture and write is rolled back.
begin;
insert into auth.users(id,raw_user_meta_data) values
 ('10000000-0000-4000-8000-000000000007','{"display_name":"Contract fixture"}'),
 ('20000000-0000-4000-8000-000000000007','{"display_name":"Other fixture"}');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000007","role":"authenticated","user_metadata":{"display_name":"Contract fixture"}}',true);
do $test$
declare campaign jsonb := '{"checkpoint":{"health":20,"level":0,"mode":"creative","phase":"wave","random_state":"-7464409895455334998","rules":{},"state":{"active_seconds":0.0,"balance":180.0,"escapes":0.0,"kills":0.0,"lifetime_earnings":0.0,"next_tower":2,"relics":{},"reserve":0.0,"towers":{"1":{"angle":0.0,"cooldown":0.0,"earnings":0.0,"id":"1","kind":"rapid","level":1,"pad":1,"rebuild_remaining":0.0,"region":"0,-1","target_mode":"first"}}},"wave":0},"completed":0.0,"game_type":"campaign","id":"05b40fb5-8850-4f27-837c-94eeacf39d8c","levels":{},"mode":"creative","name":"Campaign 1","saved_at":1788807763.888,"sequence":1.0,"version":1.0}'::jsonb;
world jsonb := '{"active_seconds":0.0,"automation":false,"balance":280.0,"camera":[0.0,0.0,1.0],"castles":{},"escapes":0.0,"first_property_required":true,"kills":0.0,"last_accounted":1788807763.901,"lifetime_earnings":0.0,"mode":"creative","next_tower":1,"regions":{"0,0":{"bend":24.0,"history":{},"history_time":0.0,"id":"0,0","parent":"","road_version":2,"side":0,"style":"forest","timer":0.25,"traffic":0,"unlocks":[]}},"relics":{},"reserve":0.0,"seed":7331,"sequence":0,"settings":{"developer_balance":{"bosses":{"warden":{"hp":4567.0}},"enemies":{"basic":{"hp":431.0}},"session":{"start":{"starting_gold":912.0}}},"low_power":false},"towers":{},"version":2}'::jsonb;
code text := '{"checksum":"5a67f4af965a58773895780dd14990de5e337b6623cdf30c4fb391f2f61afc2d","format":"hollow-vigil-reusable-build-v2","payload":"{\"contents\":{\"enemies\":[\"basic\"]},\"data\":{\"stats\":{\"enemies\":{\"basic\":{\"hp\":431.0,\"payout\":5.0,\"push_resistance\":0.0,\"speed\":39.0}}}},\"game_type\":\"infinite\",\"level\":-1,\"scope\":\"all\",\"setup\":{\"description\":\"Selected contents only\",\"name\":\"One enemy\"},\"version\":2}"}';
reply jsonb; initial jsonb; rejected boolean; envelope jsonb; payload jsonb;
begin
 envelope := code::jsonb; payload := (envelope->>'payload')::jsonb;
 assert public.valid_reusable_build(payload), 'client-generated build must validate';
 assert not public.valid_reusable_build(jsonb_set(payload,'{game_type}','null')), 'null game type rejected';
 assert not public.valid_reusable_build(jsonb_set(payload,'{scope}','null')), 'null scope rejected';
 for slot in 0..2 loop
  reply := public.put_private_game('campaign',slot,campaign,0,repeat('a',64));
  assert reply = '{"revision":1,"conflict":false}'::jsonb, 'Campaign first version';
  assert public.read_private_game('campaign',slot)->'snapshot'=campaign, 'Complete Campaign checkpoint and loadout round trip';
  reply := public.put_private_game('infinite',slot,world,0,repeat('b',64));
  assert reply = '{"revision":1,"conflict":false}'::jsonb, 'Infinite first version';
  assert public.read_private_game('infinite',slot)->'snapshot'=world, 'Complete Infinite rules and world round trip';
 end loop;
 assert jsonb_array_length(public.list_private_games())=6, 'six complete game slots';
 reply := public.put_private_game('campaign',0,campaign,0,repeat('a',64));
 assert (reply->>'revision')::int=1 and not (reply->>'conflict')::boolean, 'idempotent acknowledgement';
 initial := public.read_private_game('campaign',0);
 reply := public.put_private_game('campaign',0,jsonb_set(campaign,'{completed}','1'),0,repeat('c',64));
 assert (reply->>'conflict')::boolean and public.read_private_game('campaign',0)=initial, 'stale device cannot overwrite';
 reply := public.put_private_game('campaign',0,jsonb_set(campaign,'{completed}','1'),1,repeat('c',64));
 assert (reply->>'revision')::int=2 and not (reply->>'conflict')::boolean, 'explicit reviewed revision can replace';
 rejected := false;
 begin perform public.put_private_game('campaign',0,campaign,null,repeat('d',64));
 exception when others then rejected := true; end;
 assert rejected, 'null revision cannot bypass conflict checks';
 rejected := false;
 begin perform public.put_private_game('campaign',3,campaign,0,repeat('a',64));
 exception when others then rejected := true; end;
 assert rejected and jsonb_array_length(public.list_private_games())=6, 'no fourth slot';
 assert public.put_private_build(encode(sha256(convert_to(code,'UTF8')),'hex'),code), 'private reusable build';
 assert public.put_private_build(encode(sha256(convert_to(code,'UTF8')),'hex'),code), 'idempotent private build';
 assert jsonb_array_length(public.list_private_builds(0))=1 and public.list_private_builds(1)='[]', 'private pagination';
 perform public.publish_reusable_build('30000000-0000-4000-8000-000000000007',envelope,now());
 perform public.publish_reusable_build('30000000-0000-4000-8000-000000000007',envelope,now());
 assert exists(select 1 from jsonb_array_elements(public.list_build_library(0)) b where b->>'id'='30000000-0000-4000-8000-000000000007'), 'Community can list a published reusable build';
end $test$;
select set_config('request.jwt.claims','{"sub":"20000000-0000-4000-8000-000000000007","role":"authenticated","user_metadata":{"display_name":"Other fixture"}}',true);
do $test$
begin
 assert public.list_private_games()='[]' and public.list_private_builds(0)='[]', 'private data isolated by account';
 assert public.read_private_game('campaign',0) is null, 'another account cannot restore private game';
 assert (select count(*) from public.private_games)=0 and (select count(*) from public.private_builds)=0, 'direct table RLS isolation';
 assert not has_table_privilege('anon','public.private_games','select'), 'anonymous has no private table access';
 assert not has_function_privilege('anon','public.read_private_game(text,integer)','execute'), 'anonymous has no private restore access';
 assert has_function_privilege('anon','public.list_build_library(integer)','execute'), 'Community browsing works signed out';
end $test$;
rollback;
select 'Unified cloud contracts passed; all fixtures rolled back' as verification;
