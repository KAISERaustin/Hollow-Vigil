-- A build's independent UUID is never a world, save-slot, or account key.
create table public.public_builds (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null default auth.uid(),
  author_name text not null default (auth.jwt()->'user_metadata'->>'display_name') check (char_length(btrim(author_name)) between 1 and 40),
  title text not null check (char_length(btrim(title)) between 1 and 80),
  description text not null default '' check (char_length(description) <= 4000),
  configuration jsonb not null check (jsonb_typeof(configuration) = 'object' and octet_length(configuration::text) <= 16777216),
  created_at timestamptz not null,
  published_at timestamptz not null default now()
);
create index public_builds_published_idx on public.public_builds (published_at desc, id desc);
alter table public.public_builds enable row level security;
revoke all on public.public_builds from anon, authenticated;
grant select on public.public_builds to anon, authenticated;
grant insert (id, title, description, configuration, created_at) on public.public_builds to authenticated;
create policy public_builds_read on public.public_builds for select to anon, authenticated using (true);
create policy public_builds_insert on public.public_builds for insert to authenticated with check ((select auth.uid()) = author_id);

create function public.publish_public_build(build_id uuid, configuration jsonb, exported_at timestamptz)
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
     or (snapshot->'settings' - 'low_power' - 'developer_balance') <> '{}'::jsonb then
    raise exception 'Invalid public configuration';
  end if;
  insert into public.public_builds (id, title, description, configuration, created_at)
  values (build_id, snapshot->'setup'->>'name', coalesce(snapshot->'setup'->>'description', ''), configuration, exported_at);
  return build_id;
end $$;

create function public.list_public_builds(page_number integer default 0)
returns table (id uuid, title text, description text, author_name text, created_at timestamptz)
language sql stable security invoker set search_path = '' as $$
  select b.id, b.title, b.description, b.author_name, b.created_at
  from public.public_builds b order by b.published_at desc, b.id desc
  limit 20 offset (greatest(0, least(page_number, 1000000))::bigint * 20);
$$;
create function public.read_public_build(build_id uuid) returns jsonb
language sql stable security invoker set search_path = '' as $$
  select jsonb_build_object('title', title, 'description', description, 'configuration', configuration)
  from public.public_builds where id = build_id;
$$;
revoke all on function public.publish_public_build(uuid,jsonb,timestamptz) from public, anon;
grant execute on function public.publish_public_build(uuid,jsonb,timestamptz) to authenticated;
revoke all on function public.list_public_builds(integer), public.read_public_build(uuid) from public;
grant execute on function public.list_public_builds(integer), public.read_public_build(uuid) to anon, authenticated;
