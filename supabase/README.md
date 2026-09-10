# Campaign account backend

`client.cfg` configures the existing hosted account service. The game uses email sign-in, private Campaign backups, private build synchronization and explicit Community sharing. Keep service credentials outside the game.

See [the client contract](../docs/CLOUD_SAVES.md) and [the September 9 live audit](../docs/CLOUD_CAMPAIGN_AUDIT.md). The Campaign-only migrations were applied to the existing Hollow Vigil project. They are incremental migrations, not a fresh-project bootstrap. The first migration contains the explicitly authorized test-account reset; never replay it as a routine cleanup.

Migration filenames match their deployed Supabase versions. Earlier migration history remains on the server. Do not use a blanket database push against a fresh project or attempt to replay missing historical migrations.

When content fields change, run `tools/campaign_cloud_contract.gd` with Godot, create an empty migration with `supabase migration new`, then run `tools/update_campaign_cloud_schema.py <new-migration-path>`. Review and apply it, run the game-generated fixtures against the live validators, and run `tests/campaign_cloud_acceptance.sql` in a transaction. That test creates temporary accounts and rolls them back.
