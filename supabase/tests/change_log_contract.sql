begin;
insert into public.change_log (summary, published) values ('Unpublished contract fixture', false);
insert into public.change_log (summary, change_date) values ('Future contract fixture', '2999-01-01');
set local role anon;
do $$
begin
  if exists (select 1 from public.change_log where summary in ('Unpublished contract fixture', 'Future contract fixture')) then
    raise exception 'Hidden entries exposed';
  end if;
  if has_table_privilege(current_user, 'public.change_log', 'INSERT')
    or has_table_privilege(current_user, 'public.change_log', 'UPDATE')
    or has_table_privilege(current_user, 'public.change_log', 'DELETE') then
    raise exception 'Player write access exposed';
  end if;
  if (select count(*) from public.read_change_log()) > 31 then raise exception 'Page limit exceeded'; end if;
end $$;
reset role;
set local role authenticated;
do $$
begin
  if exists (select 1 from public.change_log where summary in ('Unpublished contract fixture', 'Future contract fixture')) then
    raise exception 'Hidden entries exposed to signed-in players';
  end if;
  if has_table_privilege(current_user, 'public.change_log', 'INSERT')
    or has_table_privilege(current_user, 'public.change_log', 'UPDATE')
    or has_table_privilege(current_user, 'public.change_log', 'DELETE') then
    raise exception 'Signed-in player write access exposed';
  end if;
end $$;
rollback;
