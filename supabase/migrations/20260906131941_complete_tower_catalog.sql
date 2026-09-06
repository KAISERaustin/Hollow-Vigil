alter table public.towers drop constraint towers_kind_check;
alter table public.towers add constraint towers_kind_check check (kind in ('rapid','splash','heavy','electric'));
create index regions_parent on public.regions(world_id,parent_id);
create index production_tower on public.production(world_id,tower_id);
