-- Keep existing build IDs, retry semantics and RLS; add typed catalog entries.
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
    if octet_length(configuration::text) > 1048576 or snapshot->'version' is distinct from '1'::jsonb
       or ((snapshot->'setup') - 'name' - 'description') <> '{}'::jsonb then
      raise exception 'Invalid rules configuration';
    end if;
    if kind = 'stats' then
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

-- Old clients continue to see only playable Infinite Worlds builds.
create or replace function public.list_public_builds(page_number integer default 0)
returns table (id uuid, title text, description text, author_name text, created_at timestamptz)
language sql stable security invoker set search_path = '' as $$
  select b.id, b.title, b.description, b.author_name, b.created_at
  from public.public_builds b where b.configuration->>'format' = 'hollow-vigil-creative-build-v1'
  order by b.published_at desc, b.id desc
  limit 20 offset (greatest(0, least(page_number, 1000000))::bigint * 20);
$$;

create function public.list_shared_configurations(content_kind text, page_number integer default 0, level_index integer default -1)
returns table (id uuid, title text, description text, author_name text, created_at timestamptz)
language sql stable security invoker set search_path = '' as $$
  select b.id, b.title, b.description, b.author_name, b.created_at
  from public.public_builds b
  where public.shared_configuration_kind(b.configuration) = content_kind
    and (level_index < 0 or case when public.shared_configuration_kind(b.configuration) in ('campaign_build', 'campaign_stats')
      then ((b.configuration->>'payload')::jsonb->>'level')::numeric = level_index else false end)
  order by b.published_at desc, b.id desc
  limit 20 offset (greatest(0, least(page_number, 1000000))::bigint * 20);
$$;
revoke all on function public.shared_configuration_kind(jsonb), public.list_shared_configurations(text,integer,integer) from public;
grant execute on function public.shared_configuration_kind(jsonb), public.list_shared_configurations(text,integer,integer) to anon, authenticated;
revoke all on function public.publish_public_build(uuid,jsonb,timestamptz) from public, anon;
grant execute on function public.publish_public_build(uuid,jsonb,timestamptz) to authenticated;
