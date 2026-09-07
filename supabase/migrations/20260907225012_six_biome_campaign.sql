-- Six five-level chapters. Accept legacy twenty-level builds without rewriting player data.
-- Existing function privileges, authentication and ownership checks are preserved.


create or replace function public.valid_campaign_playthrough_levels(levels jsonb)
returns boolean language plpgsql immutable security invoker set search_path = '' as $$
declare entry jsonb; rules jsonb; wave_record record; wave jsonb; group_row jsonb;
  idx integer; total integer; k integer; v numeric;
  wave_counts integer[] := array[3,4,4,4,4,4,4,5,5,5,5,5,5,5,5,5,5,5,6,6,5,5,5,5,5,5,5,5,5,5];
  lanes integer[] := array[1,1,2,1,1,1,2,1,2,2,1,2,1,3,2,1,2,3,2,3,1,2,1,2,2,1,2,1,3,2];
begin
  if jsonb_typeof(levels) is distinct from 'object' or (select count(*) from jsonb_object_keys(levels)) not in (20,30) then return false; end if;
  for idx in 0..(select count(*)::integer - 1 from jsonb_object_keys(levels)) loop
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

create or replace function public.shared_configuration_kind(configuration jsonb)
returns text language plpgsql immutable security invoker set search_path = '' as $$
declare snapshot jsonb;
begin
  snapshot := (configuration->>'payload')::jsonb;
  if jsonb_typeof(snapshot) is distinct from 'object' then return ''; end if;
  if configuration->>'format' = 'hollow-vigil-campaign-build-v1' and (
    jsonb_typeof(snapshot->'level') is distinct from 'number'
    or (snapshot->>'level')::numeric not between 0 and 29) then return ''; end if;
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
    if octet_length(configuration::text) > (case when kind = 'campaign' then 8388608 else 1048576 end) or snapshot->'version' is distinct from '1'::jsonb
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
         or (snapshot->>'level')::numeric not between 0 and 29
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

create or replace function public.valid_reusable_build(value jsonb) returns boolean
language plpgsql immutable security invoker set search_path = '' as $$
declare item record; part jsonb; level_entry record; wave_entry record; selected jsonb; category text; kind text;
begin
  if jsonb_typeof(value) is distinct from 'object' or value->'version' is distinct from '2'::jsonb
     or not (value ?& array['version','setup','game_type','scope','level','contents','data'])
     or (value - 'version' - 'setup' - 'game_type' - 'scope' - 'level' - 'contents' - 'data') <> '{}'::jsonb
     or jsonb_typeof(value->'game_type') is distinct from 'string' or jsonb_typeof(value->'scope') is distinct from 'string'
     or value->>'game_type' not in ('campaign','infinite') or value->>'scope' not in ('all','level')
     or jsonb_typeof(value->'level') is distinct from 'number'
     or (value->>'level')::numeric not between -1 and 29 or trunc((value->>'level')::numeric) <> (value->>'level')::numeric
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
       or (value->>'scope'='all' and (select count(*) from jsonb_object_keys(value->'data'->'levels')) not in (20,30))
       or (value->>'scope'='level' and (select count(*) from jsonb_object_keys(value->'data'->'levels')) <> 1) then return false; end if;
    for level_entry in select * from jsonb_each(value->'data'->'levels') loop
      if level_entry.key !~ '^(0|[1-9][0-9]*)$' or level_entry.key::numeric not between 0 and 29
         or (value->>'scope' = 'all' and level_entry.key::numeric >= (select count(*) from jsonb_object_keys(value->'data'->'levels')))
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

create or replace function public.put_private_game(game_type text, slot_number integer, snapshot jsonb, expected_revision bigint, content_hash text)
returns jsonb language plpgsql security invoker set search_path = '' as $$
declare current_row public.private_games; next_revision bigint;
begin
  if auth.uid() is null then raise exception 'Sign in to back up'; end if;
  if game_type is null or slot_number is null or expected_revision is null or content_hash is null or game_type not in ('campaign','infinite') or slot_number not between 0 and 2 or expected_revision < 0
     or content_hash !~ '^[0-9a-f]{64}$' or jsonb_typeof(snapshot) is distinct from 'object'
     or coalesce(snapshot->>'mode','') not in ('creative','survival') then raise exception 'Invalid saved game'; end if;
  if game_type='campaign' then
    if snapshot->>'game_type' is distinct from 'campaign' or snapshot->'version' is distinct from '1'::jsonb
       or jsonb_typeof(snapshot->'levels') is distinct from 'object' or jsonb_typeof(snapshot->'checkpoint') is distinct from 'object'
       or jsonb_typeof(snapshot->'completed') is distinct from 'number' or (snapshot->>'completed')::numeric not between 0 and 30
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

create or replace function public.list_private_games() returns jsonb
language sql stable security invoker set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object('game_type',g.game_type,'slot_number',g.slot_number,'revision',g.revision,'content_hash',g.content_hash,
    'name',coalesce(g.snapshot->>'name',g.snapshot->'setup'->>'name','Saved game'),'mode',g.snapshot->>'mode','updated_at',g.updated_at,
    'progress',case when g.game_type='campaign' then coalesce(g.snapshot->>'completed','0') || ' of 30 levels completed' else 'Saved Infinite world' end)
    order by g.game_type,g.slot_number),'[]'::jsonb) from public.private_games g where g.player_id=auth.uid();
$$;

alter table public.campaign_backups drop constraint campaign_backups_completed_levels_check;
alter table public.campaign_backups add constraint campaign_backups_completed_levels_check check (completed_levels between 0 and 30);

create or replace function vigil_private.publish_campaign_backup(payload jsonb, expected_revision bigint, mutation uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); previous public.campaign_backups; completed integer;
begin
 if actor is null then raise exception 'Sign in required' using errcode = '42501'; end if;
 if mutation is null or expected_revision is null or expected_revision < 0 or payload is null
    or jsonb_typeof(payload) <> 'object' or octet_length(payload::text) > 1024 then
  raise exception 'Invalid campaign backup' using errcode = '22023';
 end if;
 perform vigil_private.assert_keys(payload, array['format','catalog_version','completed_levels']);
 if not (payload ?& array['format','catalog_version','completed_levels']) then
  raise exception 'Missing campaign fields' using errcode = '22023';
 end if;
 payload := vigil_private.integral_fields(payload, array['format','catalog_version','completed_levels']);
 if payload->>'format' is distinct from '1' or payload->>'catalog_version' is distinct from '1' then
  raise exception 'Unsupported campaign format' using errcode = '22023';
 end if;
 completed := (payload->>'completed_levels')::integer;
 if completed is null or completed < 0 or completed > 30 then
  raise exception 'Invalid completed-level count' using errcode = '22023';
 end if;
 perform pg_advisory_xact_lock(hashtextextended(actor::text, 27));
 select * into previous from public.campaign_backups where player_id = actor for update;
 if found then
  if previous.mutation_id = mutation then
   return jsonb_build_object('status','ok','revision',previous.revision);
  end if;
  if previous.revision <> expected_revision then
   return jsonb_build_object('status','conflict','revision',previous.revision);
  end if;
 elsif expected_revision <> 0 then
  return jsonb_build_object('status','conflict','revision',0);
 end if;
 insert into public.campaign_backups(player_id, completed_levels, revision, mutation_id)
 values(actor, completed, coalesce(previous.revision,0) + 1, mutation)
 on conflict(player_id) do update set completed_levels=excluded.completed_levels,
 revision=excluded.revision, mutation_id=excluded.mutation_id, updated_at=now();
 return jsonb_build_object('status','ok','revision',coalesce(previous.revision,0)+1);
end $$;
