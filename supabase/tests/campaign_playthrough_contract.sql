begin;
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', gen_random_uuid(), 'role', 'authenticated', 'user_metadata', json_build_object('display_name', 'Campaign contract tester'))::text, true);
do $$
declare levels jsonb := '{}'::jsonb; waves jsonb; snapshot jsonb; envelope jsonb; payload text;
  fixture_id uuid := gen_random_uuid(); idx integer; wave integer;
  counts integer[] := array[3,4,4,4,4,4,4,5,5,5,5,5,5,5,5,5,5,5,6,6];
begin
  for idx in 0..19 loop
    waves := '{}'::jsonb;
    for wave in 0..counts[idx+1]-1 loop
      waves := waves || jsonb_build_object(wave::text, jsonb_build_object('groups',jsonb_build_array(jsonb_build_array('basic',12,0,2.5,0.25)), 'reward', 321, 'tuning','{"enemies":{"basic":{"hp":345}}}'::jsonb));
    end loop;
    levels := levels || jsonb_build_object(idx::text, jsonb_build_object('overrides',jsonb_build_object('gold',1234,'flame',30,'reward',99,'tuning','{}'::jsonb,'waves',waves)));
  end loop;
  snapshot := jsonb_build_object('version',1,'setup',jsonb_build_object('name','Complete campaign contract','description','All twenty levels'), 'levels', levels);
  payload := snapshot::text;
  envelope := jsonb_build_object('format','hollow-vigil-campaign-playthrough-v1','payload',payload,'checksum',encode(sha256(convert_to(payload,'UTF8')),'hex'));
  if not public.valid_campaign_playthrough_levels(levels) then raise exception 'Full campaign rejected'; end if;
  if public.publish_public_build(fixture_id,envelope,now()) <> fixture_id then raise exception 'Publication failed'; end if;
  if public.publish_public_build(fixture_id,envelope,now()) <> fixture_id then raise exception 'Idempotent retry failed'; end if;
  if public.read_public_build(fixture_id)->'configuration' <> envelope then raise exception 'Full rules lost on download'; end if;
  if not exists(select 1 from public.list_shared_configurations('campaign',0) b where b.id=fixture_id) then raise exception 'Missing campaign catalog entry'; end if;
  if exists(select 1 from public.list_public_builds(0) b where b.id=fixture_id) then raise exception 'Campaign leaked into Infinite catalog'; end if;
  if exists(select 1 from public.list_shared_configurations('campaign_build',0,0) b where b.id=fixture_id) then raise exception 'Campaign leaked into single level catalog'; end if;
  if public.valid_campaign_playthrough_levels(levels - '19') then raise exception 'Incomplete campaign accepted'; end if;
  if public.valid_campaign_playthrough_levels(jsonb_set(levels,'{0,overrides,waves,0,groups,0,2}','99')) then raise exception 'Invalid lane accepted'; end if;
  if public.valid_campaign_playthrough_levels(jsonb_set(levels,'{0,overrides,waves,0,groups,0,4}','-1')) then raise exception 'Negative interval accepted'; end if;
  if public.valid_campaign_playthrough_levels(jsonb_set(levels,'{0,overrides,cloud}','{}')) then raise exception 'Personal state accepted'; end if;
end $$;
set local role anon;
do $$ begin
  if not exists(select 1 from public.list_shared_configurations('campaign',0) where title='Complete campaign contract') then raise exception 'Anonymous browse failed'; end if;
  if not exists(select 1 from public.list_shared_configurations('campaign',0) b where public.read_public_build(b.id)->'configuration'->>'format'='hollow-vigil-campaign-playthrough-v1') then raise exception 'Anonymous download failed'; end if;
  begin
    perform public.publish_public_build(gen_random_uuid(),'{}'::jsonb,now());
    raise exception 'Anonymous publish allowed';
  exception when insufficient_privilege then null; end;
end $$;
rollback;
