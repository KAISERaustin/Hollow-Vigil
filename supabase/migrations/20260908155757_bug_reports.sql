-- Private, write-only feedback also works for players unable to sign in.
create table public.bug_reports (
    id uuid primary key,
    title text not null check (char_length(btrim(title)) between 1 and 120),
    description text not null check (char_length(btrim(description, E' \n\r\t')) between 1 and 5000),
    app_version text not null check (char_length(app_version) between 1 and 32),
    platform text not null check (platform in ('Android', 'iOS', 'macOS', 'Windows', 'Linux', 'Web')),
    created_at timestamptz not null default now()
);
alter table public.bug_reports enable row level security;
revoke all on public.bug_reports from public, anon, authenticated;
grant insert (id, title, description, app_version, platform) on public.bug_reports to anon, authenticated;
grant all on public.bug_reports to service_role;
create policy "Players submit private bug reports" on public.bug_reports
    for insert to anon, authenticated with check (true);
comment on table public.bug_reports is 'Private player feedback. Clients may only submit; reports are readable only by backend administrators.';
