# Save and cloud acceptance — 6 September 2026

## Outcome

The backend now accepts saves with custom Creative rules and restores their mode, name, description and tuning. The app no longer overwrites restored cloud rules with the current slot's rules. Opting into sound sync also uploads default values, even before a player changes a sound setting. Switching slots clears the previous slot's success message.

The save menus separate three actions:

- **Saved games:** three playable slots with automatic local saving; start fresh or use a build, then choose Creative or Survival.
- **Account & cloud backups:** private progress backup, explicit upload, refresh and restore. Backups show a readable name, mode and update time. Refresh explicitly does not upload.
- **Upload build:** the bottom of Settings opens a form with **Save to My builds** (private, local) and **Upload public build** (public). The form explains what sharing includes. Primary creation/export actions stay at the bottom while longer content scrolls.

Creative permits rule editing and build creation. Survival retains the selected build's rules and disables Developer Controls. Both modes support cloud backup.

## Failures found and fixed

| Failure | Fix and evidence |
|---|---|
| Custom developer settings prevented cloud encoding | Format 2 includes an owner-protected `world_rules` record. Real HTTP sync and backend readback preserve enemy HP 200. |
| Restoring into another mode kept local mode/rules | Actual restore handler now applies validated cloud mode, setup and tuning. Six app regression checks pass; manual Creative-to-Survival restore verified. |
| Default sound preferences could silently omit a row | Opted-in encoding supplies defaults. New-world backend readback verified all default values. |
| Switching games displayed stale sync success | Reload pending state and show the new slot's own link status. Regression check passes. |
| Backups were hard to identify | `list_saves()` now returns readable title and mode. Legacy worlds retain a seed-based fallback. |
| Public sharing and ordinary saving were easy to confuse | Separate private library saving, public upload, private backup and game-slot terminology. |

Two additive backend migrations were applied: `20260906163234_cloud_save_modes_and_rules.sql` and `20260906171640_named_cloud_backups.sql`. Legacy format-1 saves still load. Legacy clients cannot overwrite a format-2 world and silently erase its rules.

## Actual game actions and backend evidence

A dedicated, email-confirmed QA account uses normal Supabase password authentication. No authentication bypass or shared credentials were added to the shipped game. Credentials live outside the repository with file mode 0600. Launch the isolated QA game with `python3 tools/cloud_qa.py` and use its QA sign-in button. The user's ordinary device saves are separate from these QA slots.

| Action through the running game | Observed backend result |
|---|---|
| Save player name | `player_profiles` shows Hollow Vigil QA. |
| Back up the Creative world | World, revision, regions, progress and checkpoints created. |
| Build Ashneedle | Tower level 1 and gold 120 persisted. |
| Upgrade Ashneedle | Level 2 and gold 60 persisted. |
| Change target to Most HP | `towers.aim = most_hp` persisted. |
| Change master volume to 35% | `preferences.master = 0.35` persisted. |
| Change Hollow HP to 200 | `world_rules.tuning` preserves the custom value. |
| Upload the named QA build | `public_builds` preserves tower and rules, with correct author; account identity and sound settings excluded. |
| Browse and import the public build as Survival | Local Survival game created with shared rules, then private backend backup verified. |
| Back up a fresh world with default sound enabled | Preferences row contains all expected defaults. |
| Restore a Survival backup into a Creative slot | Mode, setup, tuning and world identity restored; prior local world kept as recovery data. |
| Pause, sync and compare the durable save | Eight read-only comparisons pass: progress, identity/revision, regions/traffic, towers/equipment, rules, preferences, relic inventory and unlocks. |

The principal manually edited Creative world is `7f57283c-3f39-4ab0-95a8-c99f28b61d41`. The restored Survival world is `f454cb6c-5490-45e0-b904-98e9bdd0ae7b`. The public fixture is titled **QA cloud playthrough 2026-09-06**. QA worlds and the explicitly marked public build remain available for inspection.

The revised UI was played again after the layout changes. Saving **QA private build - revised save UI** produced zero matching public rows. Explicit Sync saved revision **19**, and all eight durable-save/backend comparisons passed again, including its new private setup name. Concurrent Orchard QA created a different public fixture; it was identified by title and excluded from the private-build check. The game subsequently displayed successful revision 20 from autosync.

Save-screen interaction checks pass **26/26** across 360×640, 390×844 and 540×960 layouts, including the fixed Start action, mode selection and private-only library saving. Community-build UI checks pass **17/17**.

## Repeatable coverage

`tools/cloud_payload_fixtures.gd` creates eight real game saves and reloads them before encoding. `tools/backend_table_checks.py` turns them into rollback-only SQL that checks exact physical rows and RPC restoration, including nonempty late-game fixtures. All 14 application tables pass:

| Table | Coverage |
|---|---|
| player_profiles | Auth metadata/name projection, ownership |
| worlds | Identity, owner, format, list and account isolation |
| save_revisions | Updates, idempotency, conflicts, atomic rejection and legacy overwrite protection |
| progress | Gold and progress fields, exact restoration |
| checkpoints | Reward watermark, exact restoration |
| regions | World reconstruction and traffic across multiple expansions |
| towers | Tower state and equipped relic references |
| relics | Populated inventory and exact restoration |
| unlocks | Populated unlocks and exact restoration |
| encounters | Active/completed boss states |
| production | Populated production state |
| preferences | Opted-in sound values |
| world_rules | Mode, setup, custom tuning, ownership |
| public_builds | Real exported payload, author, idempotency and readback |

The existing cloud, public-build and player-name SQL contracts also pass against the deployed backend. The SQL fixtures roll back their inserts. They do not rewrite real players' rows.

The real HTTP runner passed 21 checks including authenticated upload/readback, token refresh, offline retry, idempotency, conflict handling, autosync and custom rules. Unit checks: cloud codec 41/41, cloud service 41/41, save modes 25/25, public builds 9/9. The restore handler passes 6/6; its headless teardown still reports two leaked audio objects, which is recorded rather than counted as a clean shutdown.

Final whole-game validation passed **32,278 checks with zero failures** after the concurrent Orchard fixture update. Touch scrolling, safe row text, explicit Sync, and numeric input/step controls passed at all three sizes using the headless interaction path. The rendered mobile runner was interrupted after its window stopped advancing during concurrent GUI tests; save-layout screenshots and the actual menu playthrough were verified separately. Supabase security advisors returned zero findings.

## Concurrent work included at delivery

Repository policy requires including all pending work. This delivery also preserves the concurrent Orchard and campaign implementation. A newly added campaign runner completed **915 checks with one failure**, `Campaign checkpoint survives a disk round trip`. That separate checkpoint path needs follow-up in the campaign work; the game-slot/cloud acceptance results above do not cover it. The existing full gameplay suite passed before this additional campaign runner was evaluated.

## Limits and follow-up

- This validates the updated local desktop source and deployed Supabase backend. The user's installed iPhone **1.0.5** remains an older client; an updated iOS build must be distributed and tested on the phone before claiming its issue is resolved there.
- The default email sender's quota blocked repeated OTP tests. The confirmed QA account permits testing normal authenticated cloud behavior; production email delivery still needs a reliable configured sender/quota.
- Late-game boss, relic and production cases use real engine-generated save fixtures, not hours of manual gameplay. The manual playthrough covers the menus, building, upgrading, rules, sound, sharing, importing, backup and restore.
- Local archives are retained recovery files; there is no in-app archive browser yet. The confirmation now says this explicitly. A restore/archive browser would improve recovery further.
- A visible last-successful-backup time and a richer offline queue indicator would make cloud status easier to trust.

Campaign follow-up: the campaign save reader now validates JSON socket numbers as integers, and its round-trip regression checks the restored game representation. The completed campaign run passed **917 checks with zero failures**, the full sandbox suite passed **32,278 checks with zero failures**, all **20 legal mission playthroughs and sequential unlocks passed**, and native campaign UI coverage passed **39 checks with zero failures** at three phone sizes. This resolves the campaign checkpoint limitation noted above; campaign progress remains a separate local save format. See `docs/CAMPAIGN.md`.
