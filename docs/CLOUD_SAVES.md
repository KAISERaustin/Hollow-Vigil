# Campaign saves and account services

The local game supports three Campaign slots shared by Creative and Survival. Each snapshot contains mode, identity, completed levels, map selection, equipment and custom level rules. The current game starts unfinished levels fresh on reentry; older checkpoint payloads remain validated for compatibility. Local writes validate and checksum data, preserve recovery candidates, and reject incompatible content.

`private_backups.gd` synchronizes Campaign snapshots and My builds through the existing account-private APIs. It uploads only Campaign slots, filters remote game listings to Campaign, validates restored snapshots with `CampaignSlots.valid`, and skips incompatible library entries. Cloud revision conflicts wait for a reviewed player choice. Replaced local games remain available as recovery copies. Account changes invalidate in-flight requests.

The current backend provides `put_private_game`, `list_private_games`, `read_private_game`, `delete_private_game`, private-library synchronization, and Community build APIs. The client retains existing RPC payloads and account authentication. Deployed server data and historical migration records are not changed by client cleanup. Archived development history is maintained outside this working project; inspect the deployed schema before preparing future migrations.

Sign-in credentials use the dedicated account session store. Sound preferences use `vigil-preferences.cfg`, independently of playable slots. Private saving works offline. Community publication occurs only after an explicit Share to Community or Retry action; automatic backup never publishes.

Validate local persistence and synthetic backup transport with `./launch.ps1 -UnifiedTests`. Physical device sign-in and end-to-end server acceptance require separate verification.
