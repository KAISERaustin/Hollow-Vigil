-- Content definitions live in the game. New type keys need no DB migration.
alter table public.towers drop constraint towers_kind_check;
alter table public.towers add constraint towers_kind_check check (kind ~ '^[a-z][a-z0-9_.:-]{0,127}$');
alter table public.relics drop constraint relics_kind_check;
alter table public.relics add constraint relics_kind_check check (kind ~ '^[a-z][a-z0-9_.:-]{0,127}$');
alter table public.encounters drop constraint encounters_kind_check;
alter table public.encounters add constraint encounters_kind_check check (kind ~ '^[a-z][a-z0-9_.:-]{0,127}$');
alter table public.unlocks drop constraint unlocks_kind_check;
alter table public.unlocks add constraint unlocks_kind_check check (kind ~ '^[a-z][a-z0-9_.:-]{0,127}$');
alter table public.towers drop constraint towers_branch_check;
alter table public.towers add constraint towers_branch_check check (branch = '' or branch ~ '^[a-z][a-z0-9_.:-]{0,127}$');
alter table public.towers drop constraint towers_target_mode_check;
alter table public.towers add constraint towers_target_mode_check check (target_mode ~ '^[a-z][a-z0-9_.:-]{0,127}$');
alter table public.regions drop constraint regions_style_check;
alter table public.regions add constraint regions_style_check check (style ~ '^[a-z][a-z0-9_.:-]{0,127}$');
