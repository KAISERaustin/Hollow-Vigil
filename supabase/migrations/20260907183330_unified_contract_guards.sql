-- Keep API validation and Community labels aligned with the shared menu.
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

create or replace function public.list_build_library(page_number integer default 0) returns jsonb
language sql stable security invoker set search_path = '' as $$
  select coalesce(jsonb_agg(to_jsonb(b)),'[]'::jsonb) from (
    select p.id,p.title,p.description,p.author_name,p.created_at,
      case when p.configuration->>'format'='hollow-vigil-reusable-build-v2' then
        (select string_agg(case c.key when 'resources' then 'Starting resources' when 'layout' then 'Tower layout and equipment' when 'terrain' then 'Explored tiles' when 'timing' then 'Wave timing and counts' when 'composition' then 'Enemy types and entrances' when 'rewards' then 'Wave rewards' else initcap(c.key) end,', ' order by c.key) from jsonb_each(((p.configuration->>'payload')::jsonb)->'contents') c)
      else case public.shared_configuration_kind(p.configuration) when 'world' then 'Infinite layout and rules' when 'stats' then 'Starting stats' else 'Campaign content' end end as contents_summary
    from public.public_builds p order by p.published_at desc,p.id desc limit 20 offset (greatest(0,least(page_number,1000000))::bigint*20)
  ) b;
$$;
