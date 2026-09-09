# Campaign account backend

`client.cfg` configures the existing hosted account service. The game uses email sign-in, private Campaign backups, private build synchronization and explicit Community sharing. Keep service credentials outside the game.

See [the client contract](../docs/CLOUD_SAVES.md). This folder does not bootstrap a new backend. Inspect deployed schema and migration history before making backend changes. Existing remote records are preserved.
