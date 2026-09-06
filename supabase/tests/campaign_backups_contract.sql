-- Synthetic records only; every change is rolled back.
begin;
do $$
declare actor uuid := gen_random_uuid(); other_actor uuid := gen_random_uuid(); mutation uuid := gen_random_uuid(); result jsonb; bad jsonb;
begin
 insert into auth.users(id, raw_user_meta_data) values(actor,'{}'),(other_actor,'{}');
 perform set_config('request.jwt.claims',jsonb_build_object('sub',actor,'role','authenticated')::text,true);
 set local role authenticated;
 if public.read_campaign_backup() is not null then raise exception 'Fresh account has a backup'; end if;
 result := public.publish_campaign_backup('{"format":1.0,"catalog_version":1.0,"completed_levels":5.0}',0,mutation);
 if result->>'status' <> 'ok' or result->>'revision' <> '1' then raise exception 'Initial upload failed'; end if;
 result := public.publish_campaign_backup('{"format":1,"catalog_version":1,"completed_levels":5}',0,mutation);
 if result->>'revision' <> '1' then raise exception 'Retry advanced revision'; end if;
 result := public.publish_campaign_backup('{"format":1,"catalog_version":1,"completed_levels":6}',0,gen_random_uuid());
 if result->>'status' <> 'conflict' then raise exception 'Stale write accepted'; end if;
 if public.read_campaign_backup()->>'completed_levels' <> '5' then raise exception 'Conflict changed backup'; end if;
 foreach bad in array array[
 '{"format":1,"catalog_version":1,"completed_levels":21}'::jsonb,
 '{"format":1,"catalog_version":1,"completed_levels":-1}'::jsonb,
 '{"format":1,"catalog_version":1,"completed_levels":2.5}'::jsonb,
 '{"format":1,"catalog_version":1,"completed_levels":"5"}'::jsonb,
 '{"format":1,"catalog_version":1,"completed_levels":null}'::jsonb,
 '{"format":1,"catalog_version":1}'::jsonb,
 '{"format":2,"catalog_version":1,"completed_levels":5}'::jsonb,
 '{"format":1,"catalog_version":2,"completed_levels":5}'::jsonb,
 '{"format":1,"catalog_version":1,"completed_levels":5,"medals":[]}'::jsonb,
 '{"format":1,"catalog_version":1,"completed_levels":5,"checkpoint":{}}'::jsonb
 ] loop
  begin
   perform public.publish_campaign_backup(bad,1,gen_random_uuid());
   raise exception 'Accepted invalid payload' using errcode='P9999';
  exception when others then
   if sqlstate='P9999' then raise; end if;
  end;
 end loop;
 begin
  update public.campaign_backups set completed_levels=20;
  raise exception 'Direct writes allowed' using errcode='P9999';
 exception when insufficient_privilege then null; end;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',other_actor,'role','authenticated')::text,true);
 if public.read_campaign_backup() is not null or exists(select 1 from public.campaign_backups) then raise exception 'Another account can read backup'; end if;
 perform public.publish_campaign_backup('{"format":1,"catalog_version":1,"completed_levels":2}',0,gen_random_uuid());
 if public.read_campaign_backup()->>'completed_levels' <> '2' then raise exception 'Second account upload failed'; end if;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',actor,'role','authenticated')::text,true);
 perform public.publish_campaign_backup('{"format":1,"catalog_version":1,"completed_levels":3}',1,gen_random_uuid());
 if public.read_campaign_backup()->>'completed_levels' <> '3' then raise exception 'Explicit older replacement failed'; end if;
 set local role anon;
 begin
  perform public.read_campaign_backup();
  raise exception 'Anonymous read allowed' using errcode='P9999';
 exception when insufficient_privilege then null; end;
 reset role;
end $$;
rollback;
