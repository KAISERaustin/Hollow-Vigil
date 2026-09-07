-- No persistent rows: verifies both supported build sizes and bounded new levels.
begin;
do $$
declare levels jsonb := '{}'::jsonb; old_levels jsonb; waves jsonb; resources jsonb := '{}'::jsonb;
  fixture jsonb; idx integer; wave integer;
  counts integer[] := array[3,4,4,4,4,4,4,5,5,5,5,5,5,5,5,5,5,5,6,6,5,5,5,5,5,5,5,5,5,5];
begin
  for idx in 0..29 loop
    waves := '{}'::jsonb;
    for wave in 0..counts[idx+1]-1 loop
      waves := waves || jsonb_build_object(wave::text, jsonb_build_object('groups','[["basic",12,0,0,1]]'::jsonb,'reward',99,'tuning','{}'::jsonb));
    end loop;
    levels := levels || jsonb_build_object(idx::text, jsonb_build_object('overrides',jsonb_build_object('gold',1500,'flame',3,'reward',99,'tuning','{}'::jsonb,'waves',waves)));
    resources := resources || jsonb_build_object(idx::text,'{"stats":{},"waves":{},"resources":{"gold":1500,"flame":3}}'::jsonb);
    if idx=19 then old_levels := levels; end if;
  end loop;
  if not public.valid_campaign_playthrough_levels(levels) then raise exception 'Thirty-level campaign rejected'; end if;
  if not public.valid_campaign_playthrough_levels(old_levels) then raise exception 'Legacy campaign rejected'; end if;
  if public.valid_campaign_playthrough_levels(levels - '29') then raise exception 'Incomplete expansion accepted'; end if;
  if public.valid_campaign_playthrough_levels(jsonb_set(levels,'{29,overrides,waves,4,groups,0,2}','2')) then raise exception 'Out-of-range orchard lane accepted'; end if;
  fixture := jsonb_build_object('version',2,'setup','{"name":"Six-biome contract","description":""}'::jsonb,'game_type','campaign','scope','all','level',-1,'contents','{"resources":true}'::jsonb,'data',jsonb_build_object('levels',resources));
  if not public.valid_reusable_build(fixture) then raise exception 'Thirty-level reusable build rejected'; end if;
  for idx in 20..29 loop resources := resources - idx::text; end loop;
  fixture := jsonb_set(fixture,'{data,levels}',resources);
  if not public.valid_reusable_build(fixture) then raise exception 'Legacy reusable build rejected'; end if;
  fixture := jsonb_set(fixture,'{data,levels}',(resources - '19') || jsonb_build_object('29',resources->'19'));
  if public.valid_reusable_build(fixture) then raise exception 'Noncontiguous legacy indices accepted'; end if;
  fixture := jsonb_set(jsonb_set(fixture,'{scope}','"level"'),'{level}','29');
  fixture := jsonb_set(fixture,'{data,levels}',jsonb_build_object('29',resources->'19'));
  if not public.valid_reusable_build(fixture) then raise exception 'New single-level build rejected'; end if;
  fixture := jsonb_set(fixture,'{level}','30');
  if public.valid_reusable_build(fixture) then raise exception 'Nonexistent level accepted'; end if;
end $$;
rollback;
