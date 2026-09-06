# Campaign and Infinite backup design

Status: proposed design, September 6, 2026. No runtime or database changes are implemented by this document.

## Recommended behavior

Keep three independent Infinite slots and one independent Campaign progression record. Present all four through one private backup interface. Campaign does not consume an Infinite slot or depend on which world was open when the player entered Campaign. Recommend one active Campaign per account initially; multiple campaign playthroughs are a separate product feature.

Save to the device first. After the player connects each save to their account, synchronize changed saves automatically while the application is running, regardless of the visible game mode. A new account connection must never silently replace an existing local campaign or an existing cloud campaign. The Campaign entry is available even when no Infinite slot exists.

## Current implementation and gap

- `scripts/campaign/progress.gd` already inherits the checked writer in `scripts/persistence/save_store.gd`: checksum, validated temporary write, backup rotation, newest valid sequence recovery, and blocked writes when every candidate is unreadable.
- Campaign version 1 stores an array of medals and one preparation checkpoint containing level index, wave index, health, gold, and towers with socket, kind, level, branch, and target mode.
- `scripts/campaign/run.gd` retains the pre-wave checkpoint while combat is active. Midwave purchases are intentionally absent from that checkpoint. After a cleared wave, reward and the next preparation checkpoint belong to the same saved transition. Victory records the medal and removes the active checkpoint.
- The Campaign screen owns its progress object. `scripts/cloud/cloud_service.gd` instead references the active Infinite `VigilState`, including its save path, world identity, pending upload, and conflict.
- Opening Campaign suspends the Infinite game; the existing cloud timer returns while that game is suspended. Simply adding campaign fields to the world codec would retain the wrong ownership and lifecycle.
- Campaign resumes using installed mission definitions and tuning. There is currently no explicit campaign content-version contract for cross-version checkpoints.

## What Campaign backs up

| Data | Proposed contract |
| --- | --- |
| Identity | Independent random campaign UUID bound to the signed-in account. Never an Infinite world UUID. |
| Progress | Best medal per permanent mission key. Derive unlocks from the compatible campaign catalog. |
| Resume point | Optional mission key, wave index to start next, remaining flame/health, gold, and tower placements/upgrades/branches/targeting. |
| Compatibility | Save format version and campaign content version, including the mission/rules revision needed to interpret the checkpoint. |
| Sync metadata | Server revision, last successful mutation UUID, server update time; local account binding and durable pending upload. |

Do not upload rendered nodes, enemy/projectile arrays, camera, audio preferences, or Infinite-world accounting data in this campaign payload. Campaign gets no offline-income calculation. Auth stays shared; tokens do not enter either save format.

Recommend retaining preparation checkpoints for this release. Leaving during wave 4 resumes at the preparation point for wave 4, including its original gold, health, and towers. Changes made during that unfinished wave roll back together. Local and cloud restore must have identical behavior and say so visibly.

Exact midwave continuation would be a separate save-contract expansion: spawn schedule position, simulation time, RNG state, live enemies and boss state, projectiles, cooldowns, effects, targeting and ability counters would all need consistent capture. Cloud backup parity does not require that expansion.

## Application ownership and synchronization

Move the Campaign progress service to application lifetime. Its screen reads the service and requests saves; closing the screen does not destroy backup ownership.

Separate shared account/HTTP behavior from save-specific behavior. Preserve the existing Infinite codec and database contract behind an Infinite adapter; add a Campaign codec and adapter. A small application-owned coordinator schedules both. Public-build publishing can share account transport but remains a separate explicit action.

Each registered save owns its binding, local sequence, cloud revision, pending mutation, retry deadline, and conflict. One save's conflict pauses only that save. Register all occupied, linked Infinite slots and the Campaign record. An inactive Infinite slot uploads its last committed snapshot without loading its simulation or applying offline rewards.

Local save events mark that record dirty. Debounce rapid preparation edits; request upload soon after a completed wave or mission, and retain a 60-second retry/safety cadence. Skip unchanged records. Serialize account token refresh and schedule requests fairly so a failing save cannot starve the others.

Lifecycle rules:

1. Persist the validated local snapshot before reporting a local save success.
2. Persist an immutable pending payload, expected revision, and mutation UUID before sending it. A newly dirty snapshot waits behind an unacknowledged mutation instead of replacing it.
3. Retry the same mutation after a lost response; after acknowledgement, durably record the revision without replacing newer local gameplay. Then queue any later snapshot.
4. On app suspension, durably save and queue available checkpoints. Attempt network delivery only if execution time is available. Mobile background execution is not guaranteed; retry on foreground/relaunch after authentication.
5. On account changes, invalidate in-flight callbacks and keep queues bound to their original account. Never publish account A's pending campaign to account B. Explicit adoption/restore resolves a different account's local record.
6. On slot archive/reset, handle that slot's queued work explicitly and preserve recoverable files. Never retarget a pending upload to a new world occupying the same slot.

## Supabase shape

Add campaign-specific tables without rebuilding or repurposing the working Infinite tables:

| Proposed table | Purpose |
| --- | --- |
| `campaign_saves` | Campaign UUID, owner UUID, save/content versions, revision, latest mutation UUID, creation/update times. Unique owner for the initial one-campaign-per-account policy. |
| `campaign_medals` | Campaign UUID, permanent mission key, medal value 1–3. Missing compatible missions mean no medal. |
| `campaign_checkpoints` | At most one checkpoint per campaign: mission key, next-wave index, flame, gold, mission/rules version. No row after mission victory until another mission starts. |
| `campaign_checkpoint_towers` | Checkpoint/campaign reference, unique socket, tower kind, tier, specialization, targeting. |

Add authenticated `list_campaign_saves`, `read_campaign_save`, and `publish_campaign_save` functions, following the existing world APIs. The UI combines their results into a common list; old Infinite clients retain their existing APIs.

Enable owner-only row-level security on every new table; anonymous access and direct client writes are denied. Validate exact payload shape, finite numeric ranges, bounded collection sizes, duplicate sockets, references, and format compatibility. Server validation must explicitly define supported mission/wave/socket limits for each content version rather than assume the client validates everything.

Publication uses a transaction and an account/campaign lock. Compare the expected revision, recognize the latest repeated mutation, and replace medals/checkpoint/towers atomically. A uniqueness rule protects simultaneous first uploads from creating two active campaigns for one account. A failed constraint leaves the old campaign intact.

## Conflicts and recovery

Use the existing explicit conflict model initially. Show both versions' completed missions, medals, resume mission/wave, and server sync time. Device clocks are informational, not the authority for selecting a winner.

Offer “Use this device” and “Restore cloud campaign.” Preserve the losing snapshot in a validated local recovery archive before replacement; when replacing cloud progress, fetch and archive the exact conflicting cloud revision first. Use revision checks again during resolution so a third device cannot be silently overwritten.

Do not automatically combine checkpoints, gold, or towers. Also do not auto-merge medals in the first version: merging can defeat an intentional campaign reset and needs a reset-generation policy. A future best-medal merge must treat progression and the selected active checkpoint separately.

Restore validates the full remote snapshot and content compatibility before touching the active record. Archive existing local progress, choose a local sequence above every valid recovery candidate, write atomically, and refresh the Campaign screen safely. If a battle is active, pause it and confirm replacement. Corrupt local progress can be recovered from cloud without first requiring that corrupt data to validate as a new save; preserve original candidate files before recovery.

Cloud revision counters provide conflict protection, not historical rollback. Keep parity with Infinite initially. If selectable older backups are desired, design bounded revision retention for both save types together.

## Migration and compatibility

1. Keep the existing campaign file and recovery candidates. Select the newest valid legacy candidate using current recovery rules.
2. Add a pure versioned migration that maps the current 20 medal indices and checkpoint index to permanent mission keys. The legacy mapping is fixed, not generated from future catalog order.
3. Preserve earned medals, checkpoint gold/health/towers, and an original recovery copy. Persist once through the normal writer so conversion is idempotent.
4. Introduce a content-version policy before uploading checkpoints. An incompatible client must preserve the payload and ask for an update; it must not silently remove unfamiliar medals or restart a mission. Compatible upgrades may use an explicit checkpoint migration. If replay is unavoidable, preserve medals and explain the required restart.
5. On first connection, distinguish local-only progress, cloud-only progress, identical bound progress, and independently played progress. Never infer that a fresh empty local campaign is permission to overwrite cloud progress.
6. Leave Infinite file formats, world IDs, cloud rows, and existing outboxes intact. Reconcile the repository/live Supabase migration-history discrepancy before deploying new migrations.

## Player interface

Provide one Account & backups screen from both Campaign and Infinite menus. Show Campaign as its own row alongside occupied Infinite saves, with separate states: saved on device, waiting for sign-in, queued, syncing, backed up, or needs a choice. Show the last successful cloud time separately from local-save status.

Campaign controls: Back up campaign, Sync now, and Restore campaign. Summaries include completed missions, medal total, and the resumable mission/wave. Restoring Campaign cannot replace an Infinite slot; restoring an Infinite backup cannot replace Campaign.

Once a record is connected, backup is automatic. Initial backup/restore choices remain explicit. Do not describe an offline queued upload as already backed up. Sign-in persistence remains a separate existing account behavior; with memory-only tokens, automatic sync resumes after the user signs in again.

## Delivery and acceptance

Implement in this order: local schema/identity migration; application-owned progress service; campaign codec and server contract; shared scheduling with Infinite regression coverage; unified backup UI; live two-device acceptance.

Required checks include local interrupted-write recovery, invalid payload rejection, legacy migration idempotency, stable mission IDs, account isolation, duplicate mutation retries, lost responses, concurrent first creation, revision conflicts, conflict-resolution races, both restore choices, and incompatible content versions.

Gameplay acceptance: finish a wave and earn its reward exactly once; finish a mission and preserve its medal; interrupt a wave and restore the same preparation checkpoint locally and from cloud. Finish the final mission and verify there is no out-of-range active checkpoint.

Integration acceptance: queue an Infinite save, enter Campaign, complete a wave, and verify both reach their correct Supabase records. Restart offline and retain both queues. Verify one conflict does not block another record. Verify account switching cannot mix queued data.

Live acceptance must use the actual menus on two devices: create progress, back it up, inspect corresponding Supabase rows, restore and compare medals/flame/gold/towers/target modes, progress further, synchronize again, and exercise an offline divergence. Automated SQL and codec checks support but do not replace this path.
