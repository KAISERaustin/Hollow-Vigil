-- Accept mathematically integral JSON numbers from loaded Godot saves and
-- durable outboxes, while rejecting fractional values rather than rounding.
create function vigil_private.integral_fields(record jsonb, fields text[])
returns jsonb language plpgsql immutable set search_path = '' as $$
declare field text; value numeric;
begin
 if jsonb_typeof(record) is distinct from 'object' then
  raise exception 'Invalid integer record' using errcode = '22023';
 end if;
 foreach field in array fields loop
  if record ? field and record->field <> 'null'::jsonb then
   if jsonb_typeof(record->field) <> 'number' then
    raise exception 'Invalid integer field: %', field using errcode = '22023';
   end if;
   value := (record->>field)::numeric;
   if value <> trunc(value) then
    raise exception 'Fractional integer field: %', field using errcode = '22023';
   end if;
   record := jsonb_set(record, array[field], to_jsonb(value::bigint));
  end if;
 end loop;
 return record;
end $$;
revoke all on function vigil_private.integral_fields(jsonb,text[]) from public, anon, authenticated;

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
 groups constant text[] := array['progress','checkpoints','regions','unlocks','towers','relics','encounters','production','preferences'];
begin
 if actor is null then raise exception 'Sign in required' using errcode = '42501'; end if;
 if mutation is null or expected_revision is null or expected_revision < 0 or octet_length(payload::text) > 4194304 then
  raise exception 'Invalid save request' using errcode = '22023';
 end if;
 -- JSON parsers (including Godot's save loader) represent whole numbers as
 -- floats. Normalize only the integer contract fields; never round fractions.
 payload := vigil_private.integral_fields(payload, array['format']);
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
