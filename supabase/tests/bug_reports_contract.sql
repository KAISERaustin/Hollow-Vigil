begin;
set local role anon;
do $$
declare report_id uuid := gen_random_uuid();
begin
  insert into public.bug_reports(id,title,description,app_version,platform)
  values(report_id,'Contract test','Private feedback','1.1.1','Android');
  begin
    perform title from public.bug_reports;
    raise exception 'Anonymous report reads must fail';
  exception when insufficient_privilege then null; end;
  begin
    update public.bug_reports set title='Changed' where id=report_id;
    raise exception 'Anonymous report updates must fail';
  exception when insufficient_privilege then null; end;
  begin
    delete from public.bug_reports where id=report_id;
    raise exception 'Anonymous report deletion must fail';
  exception when insufficient_privilege then null; end;
  begin
    insert into public.bug_reports(id,title,description,app_version,platform,created_at)
    values(gen_random_uuid(),'Forged timestamp','Description','1.1.1','Android',now());
    raise exception 'Client timestamps must fail';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
set local role authenticated;
do $$
declare report_id uuid := gen_random_uuid();
begin
  insert into public.bug_reports(id,title,description,app_version,platform)
  values(report_id,'Contract test','Private feedback','1.1.1','iOS');
  begin
    perform title from public.bug_reports;
    raise exception 'Authenticated report reads must fail';
  exception when insufficient_privilege then null; end;
  begin
    update public.bug_reports set title='Changed' where id=report_id;
    raise exception 'Authenticated report updates must fail';
  exception when insufficient_privilege then null; end;
  begin
    delete from public.bug_reports where id=report_id;
    raise exception 'Authenticated report deletion must fail';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
select 'Bug report role contracts passed' as result;
rollback;
