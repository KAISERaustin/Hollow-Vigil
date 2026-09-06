-- Campaign is one private completed-level count per account. No medals or runs.
create table public.campaign_backups (
 player_id uuid primary key references auth.users(id) on delete cascade,
 format integer not null default 1 check (format = 1),
 catalog_version integer not null default 1 check (catalog_version = 1),
 completed_levels integer not null check (completed_levels between 0 and 20),
 revision bigint not null check (revision between 1 and 1000000000000000),
 mutation_id uuid not null,
 updated_at timestamptz not null default now()
);
alter table public.campaign_backups enable row level security;
revoke all on public.campaign_backups from public, anon, authenticated;
grant select on public.campaign_backups to authenticated;
create policy owner_read on public.campaign_backups for select to authenticated
 using (player_id = (select auth.uid()));

create function vigil_private.publish_campaign_backup(payload jsonb, expected_revision bigint, mutation uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); previous public.campaign_backups; completed integer;
begin
 if actor is null then raise exception 'Sign in required' using errcode = '42501'; end if;
 if mutation is null or expected_revision is null or expected_revision < 0 or payload is null
    or jsonb_typeof(payload) <> 'object' or octet_length(payload::text) > 1024 then
  raise exception 'Invalid campaign backup' using errcode = '22023';
 end if;
 perform vigil_private.assert_keys(payload, array['format','catalog_version','completed_levels']);
 if not (payload ?& array['format','catalog_version','completed_levels']) then
  raise exception 'Missing campaign fields' using errcode = '22023';
 end if;
 payload := vigil_private.integral_fields(payload, array['format','catalog_version','completed_levels']);
 if payload->>'format' is distinct from '1' or payload->>'catalog_version' is distinct from '1' then
  raise exception 'Unsupported campaign format' using errcode = '22023';
 end if;
 completed := (payload->>'completed_levels')::integer;
 if completed is null or completed < 0 or completed > 20 then
  raise exception 'Invalid completed-level count' using errcode = '22023';
 end if;
 perform pg_advisory_xact_lock(hashtextextended(actor::text, 27));
 select * into previous from public.campaign_backups where player_id = actor for update;
 if found then
  if previous.mutation_id = mutation then
   return jsonb_build_object('status','ok','revision',previous.revision);
  end if;
  if previous.revision <> expected_revision then
   return jsonb_build_object('status','conflict','revision',previous.revision);
  end if;
 elsif expected_revision <> 0 then
  return jsonb_build_object('status','conflict','revision',0);
 end if;
 insert into public.campaign_backups(player_id, completed_levels, revision, mutation_id)
 values(actor, completed, coalesce(previous.revision,0) + 1, mutation)
 on conflict(player_id) do update set completed_levels=excluded.completed_levels,
 revision=excluded.revision, mutation_id=excluded.mutation_id, updated_at=now();
 return jsonb_build_object('status','ok','revision',coalesce(previous.revision,0)+1);
end $$;
revoke all on function vigil_private.publish_campaign_backup(jsonb,bigint,uuid) from public, anon, authenticated;
grant execute on function vigil_private.publish_campaign_backup(jsonb,bigint,uuid) to authenticated;

create function public.publish_campaign_backup(payload jsonb, expected_revision bigint, mutation uuid)
returns jsonb language sql security invoker set search_path = '' as $$
 select vigil_private.publish_campaign_backup(payload, expected_revision, mutation);
$$;
revoke all on function public.publish_campaign_backup(jsonb,bigint,uuid) from public, anon, authenticated;
grant execute on function public.publish_campaign_backup(jsonb,bigint,uuid) to authenticated;

create function public.read_campaign_backup() returns jsonb
language sql stable security invoker set search_path = '' as $$
 select jsonb_build_object('format',format,'catalog_version',catalog_version,
 'completed_levels',completed_levels,'revision',revision,'updated_at',updated_at)
 from public.campaign_backups where player_id=(select auth.uid());
$$;
revoke all on function public.read_campaign_backup() from public, anon, authenticated;
grant execute on function public.read_campaign_backup() to authenticated;
