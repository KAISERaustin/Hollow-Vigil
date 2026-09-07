-- Structural and bounded scheduling validation. Clients additionally validate registered stats and loadouts.
create function public.valid_campaign_playthrough_levels(levels jsonb)
returns boolean language plpgsql immutable security invoker set search_path = '' as $$
declare entry jsonb; rules jsonb; wave_record record; wave jsonb; group_row jsonb;
  idx integer; total integer; k integer; v numeric;
  wave_counts integer[] := array[3,4,4,4,4,4,4,5,5,5,5,5,5,5,5,5,5,5,6,6];
  lanes integer[] := array[1,1,2,1,1,1,2,1,2,2,1,2,1,3,2,1,2,3,2,3];
begin
  if jsonb_typeof(levels) is distinct from 'object' or (select count(*) from jsonb_object_keys(levels)) <> 20 then return false; end if;
  for idx in 0..19 loop
    entry := levels->idx::text;
    if jsonb_typeof(entry) is distinct from 'object' or (entry - 'overrides' - 'loadout') <> '{}'::jsonb then return false; end if;
    rules := entry->'overrides';
    if jsonb_typeof(rules) is distinct from 'object' or (rules - 'gold' - 'flame' - 'reward' - 'tuning' - 'waves') <> '{}'::jsonb then return false; end if;
    if jsonb_typeof(rules->'gold') is distinct from 'number' or (rules->>'gold')::numeric not between 0 and 1000000000000
       or jsonb_typeof(rules->'flame') is distinct from 'number' or (rules->>'flame')::numeric not between 1 and 10000
       or trunc((rules->>'flame')::numeric) <> (rules->>'flame')::numeric
       or jsonb_typeof(rules->'reward') is distinct from 'number' or (rules->>'reward')::numeric not between 0 and 1000000
       or jsonb_typeof(rules->'tuning') is distinct from 'object' or rules->'tuning' ? 'session'
       or jsonb_typeof(rules->'waves') is distinct from 'object' then return false; end if;
    if (select count(*) from jsonb_object_keys(rules->'waves')) <> wave_counts[idx+1] then return false; end if;
    for wave_record in select * from jsonb_each(rules->'waves') loop
      if wave_record.key !~ '^(0|[1-9][0-9]*)$' or wave_record.key::numeric not between 0 and wave_counts[idx+1]-1 then return false; end if;
      wave := wave_record.value;
      if jsonb_typeof(wave) is distinct from 'object' or (wave - 'groups' - 'reward' - 'tuning') <> '{}'::jsonb
         or jsonb_typeof(wave->'groups') is distinct from 'array'
         or jsonb_array_length(wave->'groups') not between 1 and 32
         or jsonb_typeof(wave->'reward') is distinct from 'number' or (wave->>'reward')::numeric not between 0 and 1000000
         or jsonb_typeof(wave->'tuning') is distinct from 'object' or wave->'tuning' ? 'session' then return false; end if;
      total := 0;
      for group_row in select * from jsonb_array_elements(wave->'groups') loop
        if jsonb_typeof(group_row) is distinct from 'array' or jsonb_array_length(group_row) <> 5
           or jsonb_typeof(group_row->0) is distinct from 'string' or length(group_row->>0) not between 1 and 80 then return false; end if;
        for k in 1..4 loop
          if jsonb_typeof(group_row->k) is distinct from 'number' then return false; end if;
          v := (group_row->>k)::numeric;
          if k = 1 and (v not between 1 and 1000 or trunc(v) <> v)
             or k = 2 and (v not between 0 and lanes[idx+1]-1 or trunc(v) <> v)
             or k = 3 and v not between 0 and 3600
             or k = 4 and v not between 0.05 and 120 then return false; end if;
        end loop;
        total := total + (group_row->>1)::integer;
      end loop;
      if total > 5000 then return false; end if;
    end loop;
    if entry ? 'loadout' and (
       jsonb_typeof(entry->'loadout') is distinct from 'object'
       or ((entry->'loadout') - 'towers' - 'next_tower' - 'relics' - 'balance') <> '{}'::jsonb
       or jsonb_typeof(entry->'loadout'->'towers') is distinct from 'object'
       or jsonb_typeof(entry->'loadout'->'relics') is distinct from 'object'
       or jsonb_typeof(entry->'loadout'->'next_tower') is distinct from 'number'
       or jsonb_typeof(entry->'loadout'->'balance') is distinct from 'number') then return false; end if;
  end loop;
  return true;
exception when others then return false;
end $$;
revoke all on function public.valid_campaign_playthrough_levels(jsonb) from public;
grant execute on function public.valid_campaign_playthrough_levels(jsonb) to anon, authenticated;

-- Full campaign builds reuse publication, ownership, retries and the typed catalog.
create or replace function public.shared_configuration_kind(configuration jsonb)
returns text language plpgsql immutable security invoker set search_path = '' as $$
declare snapshot jsonb;
begin
  snapshot := (configuration->>'payload')::jsonb;
  if jsonb_typeof(snapshot) is distinct from 'object' then return ''; end if;
  if configuration->>'format' = 'hollow-vigil-campaign-build-v1' and (
    jsonb_typeof(snapshot->'level') is distinct from 'number'
    or (snapshot->>'level')::numeric not between 0 and 19) then return ''; end if;
  return case configuration->>'format'
    when 'hollow-vigil-creative-build-v1' then 'world'
    when 'hollow-vigil-stat-configuration-v1' then 'stats'
    when 'hollow-vigil-campaign-playthrough-v1' then 'campaign'
    when 'hollow-vigil-campaign-build-v1' then
      case when snapshot ? 'loadout' then 'campaign_build' else 'campaign_stats' end
    else '' end;
exception when others then return '';
end;
$$;

create or replace function public.publish_public_build(build_id uuid, configuration jsonb, exported_at timestamptz)
returns uuid language plpgsql security invoker set search_path = '' as $$
declare snapshot jsonb; existing public.public_builds; kind text;
begin
  if auth.uid() is null then raise exception 'Sign in to publish'; end if;
  select * into existing from public.public_builds where id = build_id;
  if found then
    if existing.author_id <> auth.uid() or existing.configuration <> configuration then
      raise exception 'Build ID already used';
    end if;
    return existing.id;
  end if;
  if jsonb_typeof(configuration) is distinct from 'object'
     or (configuration - 'format' - 'payload' - 'checksum') <> '{}'::jsonb
     or jsonb_typeof(configuration->'payload') is distinct from 'string'
     or configuration->>'checksum' is distinct from encode(sha256(convert_to(configuration->>'payload', 'UTF8')), 'hex') then
    raise exception 'Invalid export envelope';
  end if;
  snapshot := (configuration->>'payload')::jsonb;
  kind := public.shared_configuration_kind(configuration);
  if jsonb_typeof(snapshot) is distinct from 'object' or kind = ''
     or jsonb_typeof(snapshot->'setup') is distinct from 'object'
     or jsonb_typeof(snapshot->'setup'->'name') is distinct from 'string'
     or jsonb_typeof(snapshot->'setup'->'description') is distinct from 'string' then
    raise exception 'Invalid configuration metadata';
  end if;
  if kind = 'world' then
    if snapshot->>'mode' is distinct from 'creative' or snapshot ? 'cloud'
       or jsonb_typeof(snapshot->'settings') is distinct from 'object'
       or ((snapshot->'settings') - 'low_power' - 'developer_balance') <> '{}'::jsonb then
      raise exception 'Invalid public world';
    end if;
  else
    if octet_length(configuration::text) > case when kind = 'campaign' then 8388608 else 1048576 end or snapshot->'version' is distinct from '1'::jsonb
       or ((snapshot->'setup') - 'name' - 'description') <> '{}'::jsonb then
      raise exception 'Invalid rules configuration';
    end if;
    if kind = 'campaign' then
      if (snapshot - 'version' - 'setup' - 'levels') <> '{}'::jsonb
         or not public.valid_campaign_playthrough_levels(snapshot->'levels') then
        raise exception 'Invalid campaign playthrough';
      end if;
    elsif kind = 'stats' then
      if (snapshot - 'version' - 'setup' - 'tuning') <> '{}'::jsonb
         or jsonb_typeof(snapshot->'tuning') is distinct from 'object' then
        raise exception 'Stats cannot contain a world';
      end if;
    else
      if (snapshot - 'version' - 'setup' - 'level' - 'overrides' - 'loadout') <> '{}'::jsonb
         or jsonb_typeof(snapshot->'level') is distinct from 'number'
         or (snapshot->>'level')::numeric not between 0 and 19
         or trunc((snapshot->>'level')::numeric) <> (snapshot->>'level')::numeric
         or jsonb_typeof(snapshot->'overrides') is distinct from 'object'
         or ((snapshot->'overrides') - 'gold' - 'flame' - 'reward' - 'tuning' - 'waves') <> '{}'::jsonb then
        raise exception 'Invalid campaign rules';
      end if;
      if kind = 'campaign_build' and (
         jsonb_typeof(snapshot->'loadout') is distinct from 'object'
         or ((snapshot->'loadout') - 'towers' - 'next_tower' - 'relics' - 'balance') <> '{}'::jsonb
         or jsonb_typeof(snapshot->'loadout'->'towers') is distinct from 'object'
         or jsonb_typeof(snapshot->'loadout'->'relics') is distinct from 'object'
         or jsonb_typeof(snapshot->'loadout'->'next_tower') is distinct from 'number'
         or jsonb_typeof(snapshot->'loadout'->'balance') is distinct from 'number') then
        raise exception 'Invalid campaign loadout';
      end if;
    end if;
  end if;
  insert into public.public_builds (id, title, description, configuration, created_at)
  values (build_id, snapshot->'setup'->>'name', snapshot->'setup'->>'description', configuration, exported_at);
  return build_id;
end $$;


revoke all on function public.publish_public_build(uuid,jsonb,timestamptz) from public, anon;
grant execute on function public.publish_public_build(uuid,jsonb,timestamptz) to authenticated;
