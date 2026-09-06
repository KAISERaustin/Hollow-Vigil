-- One duration per territory, including territories with no earned sample yet.
alter table public.regions add column history_time double precision not null default 0 check (history_time between 0 and 180);
update public.regions r set history_time = coalesce((select max(p.sample_seconds) from public.production p where p.world_id=r.world_id and p.region_id=r.id),0);
alter table public.production drop column sample_seconds;
