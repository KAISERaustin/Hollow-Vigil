-- Hollow Vigil: only the explicit cloud-save projection is stored.
-- No game assets, raw save blobs, developer tuning, device data, or telemetry.
create schema if not exists vigil_private;
revoke all on schema vigil_private from public;
grant usage on schema vigil_private to authenticated;

create table public.player_profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 display_name text check (length(display_name) between 1 and 40)
);
create table public.worlds (
 id uuid primary key,
 player_id uuid not null references public.player_profiles(id) on delete cascade,
 seed bigint not null check (seed between 0 and 1000000000000000),
 save_version integer not null check (save_version = 2),
 created_at timestamptz not null default now()
);
create index worlds_player on public.worlds(player_id);
create table public.save_revisions (
 id uuid primary key default gen_random_uuid(),
 world_id uuid not null unique references public.worlds(id) on delete cascade,
 revision bigint not null default 0 check (revision >= 0),
 mutation_id uuid,
 updated_at timestamptz not null default now()
);

create table public.progress (
 id uuid primary key,
 world_id uuid not null references public.worlds(id) on delete cascade,
 unique(world_id,id),
 gold double precision not null check (gold between 0 and 1e150),
 reserve double precision not null check (reserve between 0 and 1e150),
 lifetime_earnings double precision not null check (lifetime_earnings between 0 and 1e150),
 kills double precision not null check (kills between 0 and 1e150),
 escapes double precision not null check (escapes between 0 and 1e150),
 next_tower bigint not null check (next_tower between 1 and 1000000000000000),
 automation boolean not null,
 first_property_required boolean not null,
 unique(world_id)
);

create table public.checkpoints (
 id uuid primary key,
 world_id uuid not null references public.worlds(id) on delete cascade,
 unique(world_id,id),
 last_accounted double precision not null check (last_accounted between 0 and 1e150),
 active_seconds double precision not null check (active_seconds between 0 and 1e150),
 unique(world_id)
);

create table public.regions (
 id uuid primary key,
 world_id uuid not null references public.worlds(id) on delete cascade,
 unique(world_id,id),
 local_key text not null check (local_key ~ '^-?[0-9]{1,8},-?[0-9]{1,8}$'),
 parent_id uuid,
 side integer not null check (side between 0 and 3),
 bend integer not null check (bend in (-24,24)),
 traffic integer not null check (traffic between 0 and 12),
 style text not null check (length(style) between 1 and 32),
 road_version integer not null check (road_version in (1,2)),
 unique(world_id, local_key),
 check ((local_key = '0,0') = (parent_id is null)),
 foreign key(world_id, parent_id) references public.regions(world_id,id) deferrable initially deferred
);

create table public.relics (
 id uuid primary key,
 world_id uuid not null references public.worlds(id) on delete cascade,
 unique(world_id,id),
 source_key text not null check (source_key ~ '^-?[0-9]{1,8},-?[0-9]{1,8}$'),
 kind text not null check (kind in ('warden','cindermaw','bell','prior')),
 unique(world_id,source_key)
);

create table public.towers (
 id uuid primary key,
 world_id uuid not null references public.worlds(id) on delete cascade,
 unique(world_id,id),
 local_key text not null check (local_key ~ '^[1-9][0-9]{0,14}$'),
 region_id uuid not null,
 kind text not null check (kind in ('rapid','splash','heavy')),
 pad integer not null check (pad between 0 and 3),
 level integer not null check (level between 1 and 4),
 branch text not null check (length(branch) <= 40),
 earnings double precision not null check (earnings between 0 and 1e150),
 target_mode text not null check (target_mode in ('first','last','most_hp')),
 rebuild_remaining double precision not null check (rebuild_remaining between 0 and 180),
 relic_id uuid,
 unique(world_id,local_key), unique(world_id,region_id,pad), unique(world_id,relic_id),
 foreign key(world_id,region_id) references public.regions(world_id,id) deferrable initially deferred,
 foreign key(world_id,relic_id) references public.relics(world_id,id) deferrable initially deferred
);

create table public.unlocks (
 id uuid primary key,
 world_id uuid not null references public.worlds(id) on delete cascade,
 unique(world_id,id),
 region_id uuid not null,
 kind text not null check (length(kind) between 1 and 32),
 unique(world_id,region_id,kind),
 foreign key(world_id,region_id) references public.regions(world_id,id) deferrable initially deferred
);

create table public.encounters (
 id uuid primary key,
 world_id uuid not null references public.worlds(id) on delete cascade,
 unique(world_id,id),
 source_key text not null check (source_key ~ '^-?[0-9]{1,8},-?[0-9]{1,8}$'),
 is_castle boolean not null,
 kind text not null check (kind in ('warden','cindermaw','bell','prior')),
 status text not null check (status in ('active','defeated','escaped')),
 hp double precision check (hp > 0 and hp <= 1e150),
 tile text, previous text,
 steps bigint check (steps between 1 and 1000000000000000),
 shield double precision check (shield between 0 and 1e150),
 wards integer check (wards between 0 and 1000000),
 regen double precision check (regen between 0 and 1e150),
 toll double precision check (toll between 0 and 1e150),
 toll_delayed boolean,
 segment integer check (segment between 1 and 48),
 pos_x double precision check (pos_x between -1e12 and 1e12),
 pos_y double precision check (pos_y between -1e12 and 1e12),
 emergence boolean not null,
 unique(world_id,source_key),
 check (status <> 'active' or (hp is not null and tile is not null and previous is not null and steps is not null and shield is not null and wards is not null and regen is not null and toll is not null and toll_delayed is not null and segment is not null and pos_x is not null and pos_y is not null)),
 check (tile is null or tile ~ '^-?[0-9]{1,8},-?[0-9]{1,8}$'),
 check (previous is null or previous ~ '^-?[0-9]{1,8},-?[0-9]{1,8}$')
);

create table public.production (
 id uuid primary key,
 world_id uuid not null references public.worlds(id) on delete cascade,
 unique(world_id,id),
 region_id uuid not null,
 tower_id uuid not null,
 earned double precision not null check (earned between 0 and 1e150),
 sample_seconds double precision not null check (sample_seconds between 0 and 180),
 unique(world_id,region_id,tower_id),
 foreign key(world_id,region_id) references public.regions(world_id,id) deferrable initially deferred,
 foreign key(world_id,tower_id) references public.towers(world_id,id) deferrable initially deferred
);

create table public.preferences (
 id uuid primary key,
 world_id uuid not null references public.worlds(id) on delete cascade,
 unique(world_id,id),
 master double precision not null check (master between 0 and 1),
 menu double precision not null check (menu between 0 and 1),
 towers double precision not null check (towers between 0 and 1),
 enemies double precision not null check (enemies between 0 and 1),
 bosses double precision not null check (bosses between 0 and 1),
 music double precision not null check (music between 0 and 1),
 muted boolean not null,
 unique(world_id)
);

alter table public.player_profiles enable row level security;
revoke all on public.player_profiles from anon, authenticated;
grant select on public.player_profiles to authenticated;
create policy owner_read on public.player_profiles for select to authenticated using (id = (select auth.uid()));

alter table public.worlds enable row level security;
revoke all on public.worlds from anon, authenticated;
grant select on public.worlds to authenticated;
create policy owner_read on public.worlds for select to authenticated using (player_id = (select auth.uid()));

alter table public.save_revisions enable row level security;
revoke all on public.save_revisions from anon, authenticated;
grant select on public.save_revisions to authenticated;
create policy owner_read on public.save_revisions for select to authenticated using (exists (select 1 from public.worlds w where w.id = save_revisions.world_id and w.player_id = (select auth.uid())));

alter table public.progress enable row level security;
revoke all on public.progress from anon, authenticated;
grant select on public.progress to authenticated;
create policy owner_read on public.progress for select to authenticated using (exists (select 1 from public.worlds w where w.id = progress.world_id and w.player_id = (select auth.uid())));

alter table public.checkpoints enable row level security;
revoke all on public.checkpoints from anon, authenticated;
grant select on public.checkpoints to authenticated;
create policy owner_read on public.checkpoints for select to authenticated using (exists (select 1 from public.worlds w where w.id = checkpoints.world_id and w.player_id = (select auth.uid())));

alter table public.regions enable row level security;
revoke all on public.regions from anon, authenticated;
grant select on public.regions to authenticated;
create policy owner_read on public.regions for select to authenticated using (exists (select 1 from public.worlds w where w.id = regions.world_id and w.player_id = (select auth.uid())));

alter table public.relics enable row level security;
revoke all on public.relics from anon, authenticated;
grant select on public.relics to authenticated;
create policy owner_read on public.relics for select to authenticated using (exists (select 1 from public.worlds w where w.id = relics.world_id and w.player_id = (select auth.uid())));

alter table public.towers enable row level security;
revoke all on public.towers from anon, authenticated;
grant select on public.towers to authenticated;
create policy owner_read on public.towers for select to authenticated using (exists (select 1 from public.worlds w where w.id = towers.world_id and w.player_id = (select auth.uid())));

alter table public.unlocks enable row level security;
revoke all on public.unlocks from anon, authenticated;
grant select on public.unlocks to authenticated;
create policy owner_read on public.unlocks for select to authenticated using (exists (select 1 from public.worlds w where w.id = unlocks.world_id and w.player_id = (select auth.uid())));

alter table public.encounters enable row level security;
revoke all on public.encounters from anon, authenticated;
grant select on public.encounters to authenticated;
create policy owner_read on public.encounters for select to authenticated using (exists (select 1 from public.worlds w where w.id = encounters.world_id and w.player_id = (select auth.uid())));

alter table public.production enable row level security;
revoke all on public.production from anon, authenticated;
grant select on public.production to authenticated;
create policy owner_read on public.production for select to authenticated using (exists (select 1 from public.worlds w where w.id = production.world_id and w.player_id = (select auth.uid())));

alter table public.preferences enable row level security;
revoke all on public.preferences from anon, authenticated;
grant select on public.preferences to authenticated;
create policy owner_read on public.preferences for select to authenticated using (exists (select 1 from public.worlds w where w.id = preferences.world_id and w.player_id = (select auth.uid())));

-- Narrow privileged boundary: owner identity is ALWAYS obtained from Auth.
-- Clients have no table-write grants, so they cannot bypass revision checks.
create function vigil_private.assert_keys(value jsonb, allowed text[]) returns void
language plpgsql immutable set search_path = '' as $$
begin
 if jsonb_typeof(value) is distinct from 'object' or
    exists (select 1 from jsonb_object_keys(value) k where not (k = any(allowed))) or
    not value ?& allowed then
  raise exception 'Unexpected or missing cloud-save fields' using errcode = '22023';
 end if;
end $$;
revoke all on function vigil_private.assert_keys(jsonb,text[]) from public;

create function vigil_private.publish_save(payload jsonb, expected_revision bigint, mutation uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
 actor uuid := auth.uid();
 wid uuid;
 current_revision bigint;
 last_mutation uuid;
 existing_seed bigint;
 t text;
 columns text[];
 item jsonb;
 old_checkpoint double precision;
 groups constant text[] := array['progress','checkpoints','regions','unlocks','towers','relics','encounters','production','preferences'];
begin
 if actor is null then raise exception 'Sign in required' using errcode = '42501'; end if;
 if mutation is null or expected_revision is null or expected_revision < 0 or octet_length(payload::text) > 4194304 then
  raise exception 'Invalid save request' using errcode = '22023';
 end if;
 perform vigil_private.assert_keys(payload, array['format','world'] || groups);
 perform vigil_private.assert_keys(payload->'world', array['id','seed','save_version']);
 if payload->>'format' <> '1' then raise exception 'Unsupported cloud format'; end if;
 wid := (payload->'world'->>'id')::uuid;
 -- Serializes first creation and later uploads for this world.
 perform pg_advisory_xact_lock(hashtextextended(wid::text, 0));
 select w.seed into existing_seed from public.worlds w where w.id = wid;
 if found then
  if not exists(select 1 from public.worlds w where w.id = wid and w.player_id = actor) then
   raise exception 'World is unavailable' using errcode = '42501';
  end if;
  if existing_seed <> (payload->'world'->>'seed')::bigint then raise exception 'World seeds are immutable'; end if;
 else
  if expected_revision <> 0 then return jsonb_build_object('status','conflict','revision',0); end if;
  -- Account lock prevents concurrent creation from bypassing the world limit.
  perform pg_advisory_xact_lock(hashtextextended(actor::text, 1));
  if (select count(*) from public.worlds where player_id = actor) >= 10 then raise exception 'World limit reached'; end if;
  insert into public.player_profiles(id) values(actor) on conflict(id) do nothing;
  insert into public.worlds(id,player_id,seed,save_version) values(wid,actor,(payload->'world'->>'seed')::bigint,(payload->'world'->>'save_version')::integer);
  insert into public.save_revisions(world_id) values(wid);
 end if;
 select revision, mutation_id into current_revision,last_mutation from public.save_revisions where world_id = wid for update;
 if last_mutation = mutation then
  return jsonb_build_object('status','ok','revision',current_revision,'world_id',wid);
 end if;
 if current_revision <> expected_revision then
  return jsonb_build_object('status','conflict','revision',current_revision,'world_id',wid);
 end if;
 select last_accounted into old_checkpoint from public.checkpoints where world_id = wid;
 foreach t in array groups loop
  if jsonb_typeof(payload->t) is distinct from 'array' or jsonb_array_length(payload->t) > 10000 then raise exception 'Invalid collection'; end if;
  if t in ('progress','checkpoints') and jsonb_array_length(payload->t) <> 1 then raise exception 'Missing checkpoint or progress'; end if;
  if t = 'preferences' and jsonb_array_length(payload->t) > 1 then raise exception 'Too many preferences'; end if;
  select array_agg(column_name::text order by ordinal_position) into columns from information_schema.columns
   where table_schema = 'public' and table_name = t and column_name <> 'world_id';
  for item in select value from jsonb_array_elements(payload->t) loop
   perform vigil_private.assert_keys(item, columns);
  end loop;
 end loop;
 -- Replacement, never addition, prevents retrying rewards or merging balances.
 -- The transaction and deferred FKs keep all entity links on one revision.
 foreach t in array groups loop
  execute format('delete from public.%I where world_id = $1',t) using wid;
 end loop;
 foreach t in array groups loop
  for item in select value from jsonb_array_elements(payload->t) loop
   execute format('insert into public.%I select * from jsonb_populate_record(null::public.%I, $1)',t,t)
    using item || jsonb_build_object('world_id',wid);
  end loop;
 end loop;
 if not exists(select 1 from public.regions where world_id = wid and local_key = '0,0') then raise exception 'Missing core territory'; end if;
 -- Never move the reward accounting watermark backwards, including conflicts.
 update public.checkpoints set last_accounted = greatest(last_accounted,coalesce(old_checkpoint,0)) where world_id = wid;
 update public.save_revisions set revision = current_revision + 1, mutation_id = mutation, updated_at = now() where world_id = wid;
 return jsonb_build_object('status','ok','revision',current_revision+1,'world_id',wid);
end $$;
revoke all on function vigil_private.publish_save(jsonb,bigint,uuid) from public;
grant execute on function vigil_private.publish_save(jsonb,bigint,uuid) to authenticated;

create function public.publish_save(payload jsonb, expected_revision bigint, mutation uuid)
returns jsonb language sql security invoker set search_path = '' as $$
 select vigil_private.publish_save(payload,expected_revision,mutation);
$$;
revoke all on function public.publish_save(jsonb,bigint,uuid) from public, anon;
grant execute on function public.publish_save(jsonb,bigint,uuid) to authenticated;

-- A single SQL statement provides a consistent MVCC snapshot across all tables.
create function public.read_save(world uuid) returns jsonb
language sql stable security invoker set search_path = '' as $$
 select jsonb_build_object('revision',s.revision,'updated_at',s.updated_at,'payload',
 jsonb_build_object('format',1,'world',jsonb_build_object('id',w.id,'seed',w.seed,'save_version',w.save_version),
 'progress',coalesce((select jsonb_agg(to_jsonb(r) - 'world_id' order by r.id) from public.progress r where r.world_id=w.id),'[]'::jsonb),
 'checkpoints',coalesce((select jsonb_agg(to_jsonb(r) - 'world_id' order by r.id) from public.checkpoints r where r.world_id=w.id),'[]'::jsonb),
 'regions',coalesce((select jsonb_agg(to_jsonb(r) - 'world_id' order by r.id) from public.regions r where r.world_id=w.id),'[]'::jsonb),
 'relics',coalesce((select jsonb_agg(to_jsonb(r) - 'world_id' order by r.id) from public.relics r where r.world_id=w.id),'[]'::jsonb),
 'towers',coalesce((select jsonb_agg(to_jsonb(r) - 'world_id' order by r.id) from public.towers r where r.world_id=w.id),'[]'::jsonb),
 'unlocks',coalesce((select jsonb_agg(to_jsonb(r) - 'world_id' order by r.id) from public.unlocks r where r.world_id=w.id),'[]'::jsonb),
 'encounters',coalesce((select jsonb_agg(to_jsonb(r) - 'world_id' order by r.id) from public.encounters r where r.world_id=w.id),'[]'::jsonb),
 'production',coalesce((select jsonb_agg(to_jsonb(r) - 'world_id' order by r.id) from public.production r where r.world_id=w.id),'[]'::jsonb),
 'preferences',coalesce((select jsonb_agg(to_jsonb(r) - 'world_id' order by r.id) from public.preferences r where r.world_id=w.id),'[]'::jsonb)
 )) from public.worlds w join public.save_revisions s on s.world_id=w.id where w.id=world;
$$;
revoke all on function public.read_save(uuid) from public,anon;
grant execute on function public.read_save(uuid) to authenticated;

create function public.list_saves() returns table(world_id uuid, seed bigint, revision bigint, updated_at timestamptz)
language sql stable security invoker set search_path = '' as $$
 select w.id,w.seed,s.revision,s.updated_at from public.worlds w join public.save_revisions s on s.world_id=w.id order by s.updated_at desc;
$$;
revoke all on function public.list_saves() from public,anon;
grant execute on function public.list_saves() to authenticated;
