create or replace function public.publish_public_build(build_id uuid, configuration jsonb, exported_at timestamptz)
returns uuid language plpgsql security invoker set search_path = '' as $$
declare snapshot jsonb; existing public.public_builds;
begin
  if auth.uid() is null then raise exception 'Sign in to publish'; end if;
  select * into existing from public.public_builds where id = build_id;
  if found then
    if existing.author_id <> auth.uid() or existing.configuration <> configuration then
      raise exception 'Build ID already used';
    end if;
    return existing.id;
  end if;
  if configuration->>'format' is distinct from 'hollow-vigil-creative-build-v1'
     or jsonb_typeof(configuration->'payload') is distinct from 'string'
     or configuration->>'checksum' is distinct from encode(sha256(convert_to(configuration->>'payload', 'UTF8')), 'hex') then
    raise exception 'Invalid export envelope';
  end if;
  snapshot := (configuration->>'payload')::jsonb;
  if snapshot->>'mode' is distinct from 'creative' or snapshot ? 'cloud'
     or jsonb_typeof(snapshot->'settings') is distinct from 'object'
     or ((snapshot->'settings') - 'low_power' - 'developer_balance') <> '{}'::jsonb then
    raise exception 'Invalid public configuration';
  end if;
  insert into public.public_builds (id, title, description, configuration, created_at)
  values (build_id, snapshot->'setup'->>'name', coalesce(snapshot->'setup'->>'description', ''), configuration, exported_at);
  return build_id;
end $$;
