-- Run as postgres; all synthetic accounts and changes are rolled back.
begin;
do $$
declare actor uuid := gen_random_uuid(); other_actor uuid := gen_random_uuid(); invalid jsonb;
begin
 insert into auth.users(id, raw_user_meta_data) values(actor, '{}'::jsonb);
 if not exists(select 1 from public.player_profiles where id=actor and display_name is null) then
  raise exception 'Unnamed signup did not create a profile';
 end if;
 insert into auth.users(id, raw_user_meta_data)
 values(other_actor, '{"display_name":"Other player"}'::jsonb);
 update auth.users set raw_user_meta_data=jsonb_build_object('display_name','  Éowyn 星  ','id',other_actor) where id=actor;
 if (select display_name from public.player_profiles where id=actor) is distinct from 'Éowyn 星' then
  raise exception 'Name save did not persist to profile';
 end if;
 if (select display_name from public.player_profiles where id=other_actor) is distinct from 'Other player' then
  raise exception 'Metadata changed another account';
 end if;
 update auth.users set raw_user_meta_data=jsonb_build_object('display_name',repeat('星',32)) where id=actor;
 if (select display_name from public.player_profiles where id=actor) is distinct from repeat('星',32) then
  raise exception 'Unicode length limit failed';
 end if;
 foreach invalid in array array['{}'::jsonb, '{"display_name":42}'::jsonb,
  '{"display_name":null}'::jsonb, '{"display_name":"   "}'::jsonb,
  jsonb_build_object('display_name',repeat('x',33)), jsonb_build_object('display_name',E'Line\nBreak')] loop
  update auth.users set raw_user_meta_data=invalid where id=actor;
  if (select display_name from public.player_profiles where id=actor) is not null then
   raise exception 'Malformed metadata was projected as a player name';
  end if;
 end loop;
 update auth.users set raw_user_meta_data='{"display_name":"Renamed"}'::jsonb where id=actor;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',actor,'role','authenticated')::text,true);
 execute 'set local role authenticated';
 if (select display_name from public.player_profiles where id=actor) is distinct from 'Renamed' then
  raise exception 'Owner cannot read saved name';
 end if;
 if exists(select 1 from public.player_profiles where id=other_actor) then
  raise exception 'Other account profile visible';
 end if;
 begin
  update public.player_profiles set display_name='Unauthorized' where id=other_actor;
  raise exception 'Direct profile write allowed';
 exception when insufficient_privilege then null; end;
 if has_function_privilege(current_user,'vigil_private.sync_player_profile()','EXECUTE') then
  raise exception 'Client can execute private trigger';
 end if;
end $$;
reset role;
rollback;
