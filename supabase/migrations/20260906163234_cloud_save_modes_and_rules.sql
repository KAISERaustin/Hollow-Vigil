-- Cloud format 2 preserves Creative/Survival rules without uploading device settings.
-- Format 1 remains readable; older clients cannot overwrite a format 2 save.
create table public.world_rules (
 id uuid primary key,
 world_id uuid not null unique references public.worlds(id) on delete cascade,
 mode text not null check (mode in ('creative','survival')),
 setup jsonb not null check (jsonb_typeof(setup) = 'object' and (setup = '{}'::jsonb or
   (setup ?& array['name','description'] and setup - array['name','description'] = '{}'::jsonb
    and jsonb_typeof(setup->'name') = 'string' and length(btrim(setup->>'name')) between 1 and 80
    and jsonb_typeof(setup->'description') = 'string' and length(setup->>'description') <= 4000))),
 tuning jsonb not null check (jsonb_typeof(tuning) = 'object' and octet_length(tuning::text) <= 1048576)
);
alter table public.world_rules enable row level security;
revoke all on public.world_rules from public, anon, authenticated;
grant select on public.world_rules to authenticated;
create policy owner_read on public.world_rules for select to authenticated
 using (exists(select 1 from public.worlds w where w.id=world_rules.world_id and w.player_id=(select auth.uid())));

create or replace function vigil_private.publish_save(payload jsonb, expected_revision bigint, mutation uuid)
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
 groups text[] := array['progress','checkpoints','regions','unlocks','towers','relics','encounters','production','preferences'];
begin
 if actor is null then raise exception 'Sign in required' using errcode = '42501'; end if;
 if mutation is null or expected_revision is null or expected_revision < 0 or octet_length(payload::text) > 4194304 then
  raise exception 'Invalid save request' using errcode = '22023';
 end if;
 -- JSON parsers (including Godot's save loader) represent whole numbers as
 -- floats. Normalize only the integer contract fields; never round fractions.
 payload := vigil_private.integral_fields(payload, array['format']);
 if payload->>'format' = '2' then groups := groups || array['world_rules']; end if;
 payload := jsonb_set(payload, '{world}', vigil_private.integral_fields(payload->'world', array['seed','save_version']));
 foreach t in array groups loop
  columns := case t
   when 'progress' then array['next_tower']
   when 'regions' then array['side','bend','traffic','road_version']
   when 'towers' then array['pad','level']
   when 'encounters' then array['steps','wards','segment']
   else array[]::text[] end;
  if cardinality(columns) > 0 and jsonb_typeof(payload->t) = 'array' then
   payload := jsonb_set(payload, array[t], coalesce(
    (select jsonb_agg(vigil_private.integral_fields(value, columns) order by ordinal)
     from jsonb_array_elements(payload->t) with ordinality as rows(value, ordinal)), '[]'::jsonb));
  end if;
 end loop;
 perform vigil_private.assert_keys(payload, array['format','world'] || groups);
 perform vigil_private.assert_keys(payload->'world', array['id','seed','save_version']);
 if payload->>'format' not in ('1','2') then raise exception 'Unsupported cloud format'; end if;
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
 if payload->>'format' = '1' and exists(select 1 from public.world_rules where world_id = wid) then
  raise exception 'Update the game to sync this save with its mode and custom rules' using errcode = '22023';
 end if;
 select last_accounted into old_checkpoint from public.checkpoints where world_id = wid;
 foreach t in array groups loop
  if jsonb_typeof(payload->t) is distinct from 'array' or jsonb_array_length(payload->t) > 10000 then raise exception 'Invalid collection'; end if;
  if t in ('progress','checkpoints','world_rules') and jsonb_array_length(payload->t) <> 1 then raise exception 'Missing checkpoint or progress'; end if;
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

create or replace function public.read_save(world uuid) returns jsonb
language sql stable security invoker set search_path = '' as $$
 select jsonb_build_object('revision',s.revision,'updated_at',s.updated_at,'payload',
 jsonb_build_object('format',case when exists(select 1 from public.world_rules r where r.world_id=w.id) then 2 else 1 end,'world',jsonb_build_object('id',w.id,'seed',w.seed,'save_version',w.save_version),
 'progress',coalesce((select jsonb_agg(to_jsonb(r) - 'world_id' order by r.id) from public.progress r where r.world_id=w.id),'[]'::jsonb),
 'checkpoints',coalesce((select jsonb_agg(to_jsonb(r) - 'world_id' order by r.id) from public.checkpoints r where r.world_id=w.id),'[]'::jsonb),
 'regions',coalesce((select jsonb_agg(to_jsonb(r) - 'world_id' order by r.id) from public.regions r where r.world_id=w.id),'[]'::jsonb),
 'relics',coalesce((select jsonb_agg(to_jsonb(r) - 'world_id' order by r.id) from public.relics r where r.world_id=w.id),'[]'::jsonb),
 'towers',coalesce((select jsonb_agg(to_jsonb(r) - 'world_id' order by r.id) from public.towers r where r.world_id=w.id),'[]'::jsonb),
 'unlocks',coalesce((select jsonb_agg(to_jsonb(r) - 'world_id' order by r.id) from public.unlocks r where r.world_id=w.id),'[]'::jsonb),
 'encounters',coalesce((select jsonb_agg(to_jsonb(r) - 'world_id' order by r.id) from public.encounters r where r.world_id=w.id),'[]'::jsonb),
 'production',coalesce((select jsonb_agg(to_jsonb(r) - 'world_id' order by r.id) from public.production r where r.world_id=w.id),'[]'::jsonb),
 'preferences',coalesce((select jsonb_agg(to_jsonb(r) - 'world_id' order by r.id) from public.preferences r where r.world_id=w.id),'[]'::jsonb)
 ) || case when exists(select 1 from public.world_rules r where r.world_id=w.id) then jsonb_build_object('world_rules',(select jsonb_agg(to_jsonb(r)-'world_id' order by r.id) from public.world_rules r where r.world_id=w.id)) else '{}'::jsonb end) from public.worlds w join public.save_revisions s on s.world_id=w.id where w.id=world;
$$;
