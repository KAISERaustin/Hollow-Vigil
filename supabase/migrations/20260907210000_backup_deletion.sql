-- Deletion is scoped by Auth and RLS; tombstones prevent older devices re-uploading private builds.
create table public.deleted_private_builds (
 player_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 build_hash text not null check (build_hash ~ '^[0-9a-f]{64}$'),
 primary key (player_id,build_hash)
);
alter table public.deleted_private_builds enable row level security;
revoke all on public.deleted_private_builds from public,anon,authenticated;
grant select,insert on public.deleted_private_builds to authenticated;
create policy deleted_builds_read on public.deleted_private_builds for select to authenticated using ((select auth.uid())=player_id);
create policy deleted_builds_insert on public.deleted_private_builds for insert to authenticated with check ((select auth.uid())=player_id);
grant delete on public.private_games,public.private_builds,public.public_builds to authenticated;
create policy private_games_delete on public.private_games for delete to authenticated using ((select auth.uid())=player_id);
create policy private_builds_delete on public.private_builds for delete to authenticated using ((select auth.uid())=player_id);
create policy public_builds_delete on public.public_builds for delete to authenticated using ((select auth.uid())=author_id);
create function public.skip_deleted_private_build() returns trigger language plpgsql security invoker set search_path='' as $$
begin
 perform pg_advisory_xact_lock(hashtextextended(new.player_id::text || ':' || new.build_hash,0));
 if exists(select 1 from public.deleted_private_builds d where d.player_id=new.player_id and d.build_hash=new.build_hash) then return null; end if;
 return new;
end $$;
create trigger skip_deleted_private_build before insert on public.private_builds for each row execute function public.skip_deleted_private_build();
create function public.list_deleted_private_builds() returns jsonb language sql stable security invoker set search_path='' as $$
 select coalesce(jsonb_agg(d.build_hash),'[]'::jsonb) from public.deleted_private_builds d where d.player_id=auth.uid();
$$;
create function public.delete_private_build(build_hash text) returns boolean language plpgsql security invoker set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Sign in to delete'; end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text || ':' || build_hash,0));
 insert into public.deleted_private_builds(build_hash) values(build_hash) on conflict do nothing;
 delete from public.private_builds b where b.player_id=auth.uid() and b.build_hash=delete_private_build.build_hash;
 return true;
end $$;
create function public.delete_private_game(game_type text,slot_number integer,expected_revision bigint) returns boolean language plpgsql security invoker set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Sign in to delete'; end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text || ':' || game_type || ':' || slot_number::text,0));
 delete from public.private_games g where g.player_id=auth.uid() and g.game_type=delete_private_game.game_type and g.slot_number=delete_private_game.slot_number and g.revision=expected_revision;
 return found;
end $$;
create function public.delete_public_build(build_id uuid) returns boolean language plpgsql security invoker set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Sign in to delete'; end if;
 delete from public.public_builds b where b.id=build_id and b.author_id=auth.uid();
 return found;
end $$;
revoke all on function public.skip_deleted_private_build(),public.list_deleted_private_builds(),public.delete_private_build(text),public.delete_private_game(text,integer,bigint),public.delete_public_build(uuid) from public,anon;
grant execute on function public.list_deleted_private_builds(),public.delete_private_build(text),public.delete_private_game(text,integer,bigint),public.delete_public_build(uuid) to authenticated;
create or replace function public.list_build_library(page_number integer default 0) returns jsonb
language sql stable security invoker set search_path = '' as $$
  select coalesce(jsonb_agg(to_jsonb(b)),'[]'::jsonb) from (
    select p.id,p.author_id,p.title,p.description,p.author_name,p.created_at,
      case when p.configuration->>'format'='hollow-vigil-reusable-build-v2' then
        (select string_agg(case c.key when 'resources' then 'Starting resources' when 'layout' then 'Tower layout and equipment' when 'terrain' then 'Explored tiles' when 'timing' then 'Wave timing and counts' when 'composition' then 'Enemy types and entrances' when 'rewards' then 'Wave rewards' else initcap(c.key) end,', ' order by c.key) from jsonb_each(((p.configuration->>'payload')::jsonb)->'contents') c)
      else case public.shared_configuration_kind(p.configuration) when 'world' then 'Infinite layout and rules' when 'stats' then 'Starting stats' else 'Campaign content' end end as contents_summary
    from public.public_builds p order by p.published_at desc,p.id desc limit 20 offset (greatest(0,least(page_number,1000000))::bigint*20)
  ) b;
$$;
