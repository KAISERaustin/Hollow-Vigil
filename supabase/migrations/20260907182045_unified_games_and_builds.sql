-- Unified private recovery, with six active account slots and immutable private builds.
-- Existing Community data and legacy APIs remain readable by older installed clients.
create table public.private_games (
  player_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  game_type text not null check (game_type in ('campaign','infinite')),
  slot_number integer not null check (slot_number between 0 and 2),
  revision bigint not null default 1 check (revision > 0),
  content_hash text not null check (content_hash ~ '^[0-9a-f]{64}$'),
  snapshot jsonb not null check (jsonb_typeof(snapshot) = 'object' and octet_length(snapshot::text) <= 33554432),
  updated_at timestamptz not null default now(),
  primary key (player_id, game_type, slot_number)
);
alter table public.private_games enable row level security;
create policy private_games_read on public.private_games for select to authenticated using ((select auth.uid()) = player_id);
create policy private_games_insert on public.private_games for insert to authenticated with check ((select auth.uid()) = player_id);
create policy private_games_update on public.private_games for update to authenticated using ((select auth.uid()) = player_id) with check ((select auth.uid()) = player_id);
grant select, insert, update on public.private_games to authenticated;
revoke all on public.private_games from anon;

create table public.private_builds (
  player_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  build_hash text not null check (build_hash ~ '^[0-9a-f]{64}$'),
  configuration text not null check (octet_length(configuration) <= 16777216),
  created_at timestamptz not null default now(),
  primary key (player_id, build_hash)
);
alter table public.private_builds enable row level security;
create policy private_builds_read on public.private_builds for select to authenticated using ((select auth.uid()) = player_id);
create policy private_builds_insert on public.private_builds for insert to authenticated with check ((select auth.uid()) = player_id);
grant select, insert on public.private_builds to authenticated;
revoke all on public.private_builds from anon;

create function public.valid_reusable_build(value jsonb) returns boolean
language plpgsql immutable security invoker set search_path = '' as $$
declare item record; part jsonb; level_entry record; wave_entry record; selected jsonb; category text; kind text;
begin
  if jsonb_typeof(value) is distinct from 'object' or value->'version' is distinct from '2'::jsonb
     or not (value ?& array['version','setup','game_type','scope','level','contents','data'])
     or (value - 'version' - 'setup' - 'game_type' - 'scope' - 'level' - 'contents' - 'data') <> '{}'::jsonb
     or value->>'game_type' not in ('campaign','infinite') or value->>'scope' not in ('all','level')
     or jsonb_typeof(value->'level') is distinct from 'number'
     or (value->>'level')::numeric not between -1 and 19 or trunc((value->>'level')::numeric) <> (value->>'level')::numeric
     or ((value->>'scope' = 'level') <> ((value->>'level')::integer >= 0))
     or (value->>'game_type' = 'infinite' and value->>'scope' <> 'all')
     or jsonb_typeof(value->'contents') is distinct from 'object' or value->'contents' = '{}'::jsonb
     or jsonb_typeof(value->'data') is distinct from 'object'
     or jsonb_typeof(value->'setup'->'name') is distinct from 'string'
     or char_length(btrim(value->'setup'->>'name')) not between 1 and 80
     or jsonb_typeof(value->'setup'->'description') is distinct from 'string'
     or char_length(value->'setup'->>'description') > 4000
     or ((value->'setup') - 'name' - 'description') <> '{}'::jsonb then return false; end if;
  for item in select * from jsonb_each(value->'contents') loop
    if item.key in ('enemies','bosses','towers','gear','rifts') then
      if jsonb_typeof(item.value) <> 'array' or jsonb_array_length(item.value) not between 1 and 10000 then return false; end if;
      for selected in select * from jsonb_array_elements(item.value) loop
        if jsonb_typeof(selected) <> 'string' or char_length(selected #>> '{}') not between 1 and 100 then return false; end if;
      end loop;
    elsif item.key in ('resources','layout','terrain','timing','composition','rewards') then
      if item.value <> 'true'::jsonb then return false; end if;
      if item.key = 'terrain' and value->>'game_type' <> 'infinite' then return false; end if;
      if item.key in ('timing','composition','rewards') and value->>'game_type' <> 'campaign' then return false; end if;
    else return false; end if;
  end loop;
  if value->>'game_type' = 'infinite' then
    part := value->'data';
    if (part - 'stats' - 'resources' - 'layout' - 'map') <> '{}'::jsonb or jsonb_typeof(part->'stats') is distinct from 'object' then return false; end if;
    if (part ? 'resources') <> (value->'contents' ? 'resources') or (part ? 'layout') <> (value->'contents' ? 'layout')
       or (part ? 'map') <> ((value->'contents' ? 'terrain') or (value->'contents' ? 'layout')) then return false; end if;
  else
    if (value->'data' - 'levels') <> '{}'::jsonb or jsonb_typeof(value->'data'->'levels') is distinct from 'object'
       or (select count(*) from jsonb_object_keys(value->'data'->'levels')) <> (case when value->>'scope'='all' then 20 else 1 end) then return false; end if;
    for level_entry in select * from jsonb_each(value->'data'->'levels') loop
      if level_entry.key !~ '^(0|[1-9][0-9]*)$' or level_entry.key::numeric not between 0 and 19
         or (value->>'scope' = 'level' and level_entry.key::integer <> (value->>'level')::integer) then return false; end if;
      part := level_entry.value;
      if jsonb_typeof(part) <> 'object' or (part - 'stats' - 'waves' - 'resources' - 'layout') <> '{}'::jsonb
         or jsonb_typeof(part->'stats') is distinct from 'object' or jsonb_typeof(part->'waves') is distinct from 'object' then return false; end if;
      for wave_entry in select * from jsonb_each(part->'waves') loop
        if wave_entry.key !~ '^(0|[1-9][0-9]*)$' or wave_entry.key::numeric > 10000
           or jsonb_typeof(wave_entry.value) <> 'object' or (wave_entry.value - 'stats' - 'timing' - 'composition' - 'reward') <> '{}'::jsonb
           or jsonb_typeof(wave_entry.value->'stats') is distinct from 'object' then return false; end if;
      end loop;
    end loop;
  end if;
  return true;
exception when others then return false;
end $$;

create function public.put_private_game(game_type text, slot_number integer, snapshot jsonb, expected_revision bigint, content_hash text)
returns jsonb language plpgsql security invoker set search_path = '' as $$
declare current_row public.private_games; next_revision bigint;
begin
  if auth.uid() is null then raise exception 'Sign in to back up'; end if;
  if game_type not in ('campaign','infinite') or slot_number not between 0 and 2 or expected_revision < 0
     or content_hash !~ '^[0-9a-f]{64}$' or jsonb_typeof(snapshot) is distinct from 'object'
     or coalesce(snapshot->>'mode','') not in ('creative','survival') then raise exception 'Invalid saved game'; end if;
  if game_type='campaign' then
    if snapshot->>'game_type' is distinct from 'campaign' or snapshot->'version' is distinct from '1'::jsonb
       or jsonb_typeof(snapshot->'levels') is distinct from 'object' or jsonb_typeof(snapshot->'checkpoint') is distinct from 'object'
       or jsonb_typeof(snapshot->'completed') is distinct from 'number' or (snapshot->>'completed')::numeric not between 0 and 20
       or jsonb_typeof(snapshot->'name') is distinct from 'string' or char_length(btrim(snapshot->>'name')) not between 1 and 80
       or (snapshot->>'id')::uuid is null then raise exception 'Incomplete Campaign backup'; end if;
  else
    if jsonb_typeof(snapshot->'regions') is distinct from 'object' or jsonb_typeof(snapshot->'towers') is distinct from 'object'
       or jsonb_typeof(snapshot->'settings') is distinct from 'object' or jsonb_typeof(snapshot->'balance') is distinct from 'number'
       or jsonb_typeof(snapshot->'seed') is distinct from 'number' then raise exception 'Incomplete Infinite backup'; end if;
  end if;
  -- Serialize even the first insert, avoiding the absent-row race between devices.
  perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text || ':' || game_type || ':' || slot_number::text, 0));
  select * into current_row from public.private_games g where g.player_id=auth.uid() and g.game_type=put_private_game.game_type and g.slot_number=put_private_game.slot_number for update;
  if found then
    if current_row.content_hash=put_private_game.content_hash and current_row.snapshot=put_private_game.snapshot then
      return jsonb_build_object('revision',current_row.revision,'conflict',false);
    end if;
    if current_row.revision <> expected_revision then
      return jsonb_build_object('revision',current_row.revision,'conflict',true,'game_type',game_type,'slot_number',slot_number);
    end if;
    update public.private_games g set snapshot=put_private_game.snapshot, content_hash=put_private_game.content_hash, revision=g.revision+1, updated_at=now()
      where g.player_id=auth.uid() and g.game_type=put_private_game.game_type and g.slot_number=put_private_game.slot_number returning revision into next_revision;
  else
    if expected_revision <> 0 then return jsonb_build_object('revision',0,'conflict',true,'game_type',game_type,'slot_number',slot_number); end if;
    insert into public.private_games(game_type,slot_number,snapshot,content_hash) values(game_type,slot_number,snapshot,content_hash) returning revision into next_revision;
  end if;
  return jsonb_build_object('revision',next_revision,'conflict',false);
end $$;

create function public.list_private_games() returns jsonb
language sql stable security invoker set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object('game_type',g.game_type,'slot_number',g.slot_number,'revision',g.revision,'content_hash',g.content_hash,
    'name',coalesce(g.snapshot->>'name',g.snapshot->'setup'->>'name','Saved game'),'mode',g.snapshot->>'mode','updated_at',g.updated_at,
    'progress',case when g.game_type='campaign' then coalesce(g.snapshot->>'completed','0') || ' of 20 levels completed' else 'Saved Infinite world' end)
    order by g.game_type,g.slot_number),'[]'::jsonb) from public.private_games g where g.player_id=auth.uid();
$$;
create function public.read_private_game(game_type text, slot_number integer) returns jsonb
language sql stable security invoker set search_path = '' as $$
  select jsonb_build_object('snapshot',g.snapshot,'revision',g.revision,'content_hash',g.content_hash)
  from public.private_games g where g.player_id=auth.uid() and g.game_type=read_private_game.game_type and g.slot_number=read_private_game.slot_number;
$$;
create function public.put_private_build(build_hash text, configuration text) returns boolean
language plpgsql security invoker set search_path = '' as $$
declare envelope jsonb; value jsonb;
begin
  if auth.uid() is null or build_hash is distinct from encode(sha256(convert_to(configuration,'UTF8')),'hex') then raise exception 'Invalid private build'; end if;
  envelope := configuration::jsonb;
  if envelope->>'checksum' is distinct from encode(sha256(convert_to(envelope->>'payload','UTF8')),'hex') then raise exception 'Invalid private contents'; end if;
  if envelope->>'format' = 'hollow-vigil-reusable-build-v2' then
    if not public.valid_reusable_build((envelope->>'payload')::jsonb) then raise exception 'Invalid reusable build'; end if;
  elsif public.shared_configuration_kind(envelope) = '' then raise exception 'Unknown private build'; end if;
  insert into public.private_builds(build_hash,configuration) values(build_hash,configuration) on conflict do nothing;
  return true;
end $$;
create function public.list_private_builds(page_number integer default 0) returns jsonb
language sql stable security invoker set search_path = '' as $$
  select coalesce(jsonb_agg(to_jsonb(b)),'[]'::jsonb) from
    (select build_hash,configuration from public.private_builds where player_id=auth.uid() order by build_hash limit 1 offset greatest(0,least(page_number,1000000))) b;
$$;

create function public.publish_reusable_build(build_id uuid, configuration jsonb, exported_at timestamptz) returns uuid
language plpgsql security invoker set search_path = '' as $$
declare value jsonb; existing public.public_builds;
begin
  if auth.uid() is null then raise exception 'Sign in to share'; end if;
  if jsonb_typeof(configuration) is distinct from 'object' or configuration->>'format' is distinct from 'hollow-vigil-reusable-build-v2'
     or configuration->>'checksum' is distinct from encode(sha256(convert_to(configuration->>'payload','UTF8')),'hex') then raise exception 'Invalid build'; end if;
  value := (configuration->>'payload')::jsonb;
  if not public.valid_reusable_build(value) then raise exception 'Invalid build contents'; end if;
  select * into existing from public.public_builds where id=build_id;
  if found then
    if existing.author_id <> auth.uid() or existing.configuration <> configuration then raise exception 'Build already exists'; end if;
    return build_id;
  end if;
  insert into public.public_builds(id,title,description,configuration,created_at)
    values(build_id,value->'setup'->>'name',value->'setup'->>'description',configuration,exported_at);
  return build_id;
end $$;

create function public.list_build_library(page_number integer default 0) returns jsonb
language sql stable security invoker set search_path = '' as $$
  select coalesce(jsonb_agg(to_jsonb(b)),'[]'::jsonb) from (
    select p.id,p.title,p.description,p.author_name,p.created_at,
      case when p.configuration->>'format'='hollow-vigil-reusable-build-v2' then
        (select string_agg(initcap(replace(c.key,'_',' ')),', ' order by c.key) from jsonb_each(((p.configuration->>'payload')::jsonb)->'contents') c)
      else case public.shared_configuration_kind(p.configuration) when 'world' then 'Infinite layout and rules' when 'stats' then 'Starting stats' else 'Campaign content' end end as contents_summary
    from public.public_builds p order by p.published_at desc,p.id desc limit 20 offset (greatest(0,least(page_number,1000000))::bigint*20)
  ) b;
$$;

revoke all on function public.valid_reusable_build(jsonb),public.put_private_game(text,integer,jsonb,bigint,text),public.list_private_games(),public.read_private_game(text,integer),public.put_private_build(text,text),public.list_private_builds(integer),public.publish_reusable_build(uuid,jsonb,timestamptz),public.list_build_library(integer) from public,anon;
grant execute on function public.valid_reusable_build(jsonb),public.put_private_game(text,integer,jsonb,bigint,text),public.list_private_games(),public.read_private_game(text,integer),public.put_private_build(text,text),public.list_private_builds(integer),public.publish_reusable_build(uuid,jsonb,timestamptz),public.list_build_library(integer) to authenticated;
grant execute on function public.list_build_library(integer) to anon;
