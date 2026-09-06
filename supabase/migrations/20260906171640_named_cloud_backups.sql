-- Keep the existing identity/revision columns while adding readable restore labels.
drop function public.list_saves();
create function public.list_saves()
returns table(world_id uuid, seed bigint, revision bigint, updated_at timestamptz, mode text, title text)
language sql stable set search_path = '' as $$
 select w.id,w.seed,s.revision,s.updated_at,coalesce(r.mode,'creative'),
  coalesce(nullif(r.setup->>'name',''),'World '||w.seed::text)
 from public.worlds w join public.save_revisions s on s.world_id=w.id
 left join public.world_rules r on r.world_id=w.id
 order by s.updated_at desc;
$$;
revoke all on function public.list_saves() from public,anon;
grant execute on function public.list_saves() to authenticated;
