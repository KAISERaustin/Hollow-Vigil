create table public.change_log (
  id uuid primary key default gen_random_uuid(),
  change_date date not null default (now() at time zone 'America/Chicago')::date,
  summary text not null check (char_length(btrim(summary)) between 1 and 300),
  published boolean not null default true,
  source_commit text unique,
  created_at timestamptz not null default now()
);
comment on table public.change_log is 'Player-facing changes. Add a short summary; date and publication default automatically. Unpublish to hide a row.';
alter table public.change_log enable row level security;
revoke all on public.change_log from public, anon, authenticated;
grant select on public.change_log to anon, authenticated;
grant all on public.change_log to service_role;
create policy "Read published changes" on public.change_log for select to anon, authenticated
using (published and change_date <= (now() at time zone 'America/Chicago')::date);
create index change_log_feed_idx on public.change_log (change_date desc, created_at desc, id desc) where published;

create function public.read_change_log(before_date date default null, before_created_at timestamptz default null, before_id uuid default null)
returns table (id uuid, change_date date, created_at timestamptz, summary text)
language sql stable security invoker set search_path = '' as $$
  select c.id, c.change_date, c.created_at, c.summary from public.change_log c
  where c.published and c.change_date <= (now() at time zone 'America/Chicago')::date
    and (before_date is null or (c.change_date, c.created_at, c.id) < (before_date, before_created_at, before_id))
  order by c.change_date desc, c.created_at desc, c.id desc limit 31;
$$;
revoke all on function public.read_change_log(date, timestamptz, uuid) from public;
grant execute on function public.read_change_log(date, timestamptz, uuid) to anon, authenticated, service_role;
