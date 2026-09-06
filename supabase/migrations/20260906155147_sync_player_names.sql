-- Auth metadata is the account name used by the game. Keep its public profile
-- projection in the same transaction so a successful Auth save persists both.
create function vigil_private.profile_display_name(metadata jsonb)
returns text language sql immutable security invoker set search_path = '' as $$
 select case when jsonb_typeof(metadata->'display_name') = 'string'
   and char_length(btrim(metadata->>'display_name')) between 1 and 32
   and (metadata->>'display_name') !~ '[[:cntrl:]]'
 then btrim(metadata->>'display_name') else null end
$$;
revoke all on function vigil_private.profile_display_name(jsonb) from public, anon, authenticated;

-- Auth owns the source row; NEW.id, never user-editable metadata, determines
-- ownership. Definer rights are needed for the Auth service's private trigger
-- to maintain this read-only projection. It is not a client-callable RPC.
create function vigil_private.sync_player_profile()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
 insert into public.player_profiles(id, display_name)
 values(new.id, vigil_private.profile_display_name(new.raw_user_meta_data))
 on conflict(id) do update set display_name = excluded.display_name;
 return new;
end
$$;
revoke all on function vigil_private.sync_player_profile() from public, anon, authenticated;

create trigger sync_player_profile
after insert or update of raw_user_meta_data on auth.users
for each row execute function vigil_private.sync_player_profile();

-- Repair accounts created before the trigger, including players who saved a
-- name before ever backing up a world. Existing world ownership is unchanged.
insert into public.player_profiles(id, display_name)
select id, vigil_private.profile_display_name(raw_user_meta_data) from auth.users
on conflict(id) do update set display_name = excluded.display_name;
