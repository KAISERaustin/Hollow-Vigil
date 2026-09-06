begin;
set local role authenticated;
-- Transaction-local identities and fixtures leave no public test builds behind.
select set_config('request.jwt.claims', json_build_object('sub', gen_random_uuid(), 'role', 'authenticated', 'user_metadata', json_build_object('display_name', 'Build tester'))::text, true);
do $$
declare build uuid := gen_random_uuid(); payload text := '{"mode":"creative","setup":{"name":"Contract build","description":"Test"},"settings":{"low_power":false,"developer_balance":{}}}'; envelope jsonb; returned uuid;
begin
 envelope := jsonb_build_object('format','hollow-vigil-creative-build-v1','payload',payload,'checksum',encode(sha256(convert_to(payload,'UTF8')),'hex'));
 returned := public.publish_public_build(build,envelope,now());
 if returned <> build then raise exception 'Wrong identity'; end if;
 if public.publish_public_build(build,envelope,now()) <> build then raise exception 'Retry failed'; end if;
 if (select count(*) from public.public_builds where id=build) <> 1 then raise exception 'Duplicate build'; end if;
 if (select author_name from public.public_builds where id=build) <> 'Build tester' then raise exception 'Missing author'; end if;
 if public.read_public_build(build)->'configuration' <> envelope then raise exception 'Lost configuration'; end if;
 begin
   update public.public_builds set title='Changed' where id=build;
   raise exception 'Update unexpectedly allowed';
 exception when insufficient_privilege then null; end;
 begin
   delete from public.public_builds where id=build;
   raise exception 'Delete unexpectedly allowed';
 exception when insufficient_privilege then null; end;
 perform set_config('request.jwt.claims', json_build_object('sub',gen_random_uuid(),'role','authenticated','user_metadata',json_build_object('display_name','Other player'))::text,true);
 begin
   perform public.publish_public_build(build,envelope,now());
   raise exception 'Cross-account ID unexpectedly allowed';
 exception when raise_exception then
   if sqlerrm <> 'Build ID already used' then raise; end if;
 end;
end $$;
set local role anon;
select count(*) as visible_builds from public.list_public_builds(0);
do $$ begin
 if not exists(select 1 from public.list_public_builds(0) where title='Contract build') then raise exception 'Anonymous read failed'; end if;
 begin
  perform public.publish_public_build(gen_random_uuid(),'{}'::jsonb,now());
  raise exception 'Anonymous publish allowed';
 exception when insufficient_privilege then null; end;
end $$;
rollback;
