begin;
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', gen_random_uuid(), 'role', 'authenticated', 'user_metadata', json_build_object('display_name', 'Configuration tester'))::text, true);
do $$
declare kind text; format text; snapshot jsonb; envelope jsonb; payload text; fixture_id uuid;
begin
  foreach kind in array array['stats', 'campaign_stats', 'campaign_build'] loop
    snapshot := '{"version":1,"setup":{"name":"Shared configuration contract","description":"Rules test"}}'::jsonb;
    if kind = 'stats' then
      format := 'hollow-vigil-stat-configuration-v1';
      snapshot := snapshot || '{"tuning":{"enemies":{"basic":{"hp":222}}}}'::jsonb;
    else
      format := 'hollow-vigil-campaign-build-v1';
      snapshot := snapshot || '{"level":0,"overrides":{"waves":{"1":{"reward":432}}}}'::jsonb;
      if kind = 'campaign_build' then
        snapshot := snapshot || '{"loadout":{"towers":{},"next_tower":1,"relics":{},"balance":500}}'::jsonb;
      end if;
    end if;
    payload := snapshot::text;
    envelope := jsonb_build_object('format',format,'payload',payload,'checksum',encode(sha256(convert_to(payload,'UTF8')),'hex'));
    fixture_id := gen_random_uuid();
    if public.publish_public_build(fixture_id,envelope,now()) <> fixture_id then raise exception 'Publication failed'; end if;
    if public.publish_public_build(fixture_id,envelope,now()) <> fixture_id then raise exception 'Retry failed'; end if;
    if public.read_public_build(fixture_id)->'configuration' <> envelope then raise exception 'Rules lost'; end if;
    if not exists(select 1 from public.list_shared_configurations(kind,0) b where b.id = fixture_id) then raise exception 'Missing typed listing'; end if;
    if exists(select 1 from public.list_public_builds(0) b where b.id = fixture_id) then raise exception 'Old world catalog contaminated'; end if;
    if kind <> 'stats' and exists(select 1 from public.list_shared_configurations(kind,0,1) b where b.id = fixture_id) then raise exception 'Wrong level listed'; end if;
  end loop;
  payload := '{"version":1,"setup":{"name":"Bad stats","description":""},"tuning":{},"towers":{}}';
  envelope := jsonb_build_object('format','hollow-vigil-stat-configuration-v1','payload',payload,'checksum',encode(sha256(convert_to(payload,'UTF8')),'hex'));
  begin
    perform public.publish_public_build(gen_random_uuid(),envelope,now());
    raise exception 'Stats accepted world state';
  exception when raise_exception then
    if sqlerrm <> 'Stats cannot contain a world' then raise; end if;
  end;
  if public.shared_configuration_kind('{"format":"hollow-vigil-campaign-build-v1","payload":"bad"}') <> '' then raise exception 'Malformed entry not filtered'; end if;
end $$;
set local role anon;
do $$ begin
  if not exists(select 1 from public.list_shared_configurations('stats',0) where title = 'Shared configuration contract') then raise exception 'Anonymous stats read failed'; end if;
  if not exists(select 1 from public.list_shared_configurations('campaign_stats',0,0) where title = 'Shared configuration contract') then raise exception 'Anonymous campaign read failed'; end if;
  begin
    perform public.publish_public_build(gen_random_uuid(),'{}'::jsonb,now());
    raise exception 'Anonymous publish allowed';
  exception when insufficient_privilege then null; end;
end $$;
rollback;
