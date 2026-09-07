begin;
insert into auth.users(id,raw_user_meta_data) values
 ('10000000-0000-4000-8000-000000000099','{"display_name":"Deletion fixture"}'),
 ('20000000-0000-4000-8000-000000000099','{"display_name":"Other fixture"}');
insert into public.public_builds(id,author_id,author_name,title,configuration,created_at)
 values ('30000000-0000-4000-8000-000000000099','10000000-0000-4000-8000-000000000099','Deletion fixture','Deletion test','{}',now());
insert into public.private_games(player_id,game_type,slot_number,content_hash,snapshot)
 values ('10000000-0000-4000-8000-000000000099','infinite',0,repeat('a',64),'{}');
insert into public.private_builds(player_id,build_hash,configuration)
 values ('10000000-0000-4000-8000-000000000099',repeat('a',64),'{}');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"20000000-0000-4000-8000-000000000099","role":"authenticated"}',true);
do $$ begin
 assert not public.delete_public_build('30000000-0000-4000-8000-000000000099'), 'Cannot delete another author build';
 assert not public.delete_private_game('infinite',0,1), 'Cannot delete another account game';
 assert public.delete_private_build(repeat('a',64)), 'Own tombstone allowed';
 assert public.list_deleted_private_builds()=jsonb_build_array(repeat('a',64)), 'Only own tombstones visible';
end $$;
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000099","role":"authenticated"}',true);
do $$ begin
 assert (select count(*) from public.private_builds)=1, 'Other account deletion preserved owner build';
 assert public.list_deleted_private_builds()='[]', 'Tombstones account isolated';
 assert not public.delete_private_game('infinite',0,2), 'Stale revision rejected';
 assert public.delete_private_game('infinite',0,1), 'Owner can delete game';
 assert public.delete_public_build('30000000-0000-4000-8000-000000000099'), 'Author can delete public build';
 assert public.delete_private_build(repeat('a',64)), 'Owner can delete private build';
 assert (select count(*) from public.private_builds)=0, 'Private build removed';
 insert into public.private_builds(build_hash,configuration) values(repeat('a',64),'{}');
 assert (select count(*) from public.private_builds)=0, 'Stale client cannot resurrect deleted build';
 assert not has_function_privilege('anon','public.delete_public_build(uuid)','EXECUTE'), 'Anonymous cannot delete';
 assert not has_function_privilege('anon','public.delete_private_game(text,integer,bigint)','EXECUTE'), 'Anonymous cannot delete games';
 assert not has_function_privilege('anon','public.delete_private_build(text)','EXECUTE'), 'Anonymous cannot delete private builds';
end $$;
rollback;
