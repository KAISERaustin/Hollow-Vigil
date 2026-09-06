# Boss equipment

There are **18 equipment types: three for each of the six bosses**. A victory awards the complete three-piece set once. Each piece occupies the shared tower relic slot and works on every tower and specialization. Old recorded victories receive any missing set pieces on load, without replacing existing equipment or repaying gold.

In a Creative world, open **Settings → Developer Controls → Gear** to select any piece and edit every numeric effect setting. Changes auto-save within that Creative world; descriptions update immediately. Reset selected restores only that piece. Equipment identity, boss theme and attached behavior are authored content; the editor changes their behavior settings.

| Boss | Equipment | Default attribute |
| --- | --- | --- |
| Briarbound Warden | Warden’s Rootheart | Every 6 seconds, a primary shot roots its target for 0.75s (0.35s for bosses). Root immunity lasts 3s. |
| Cinder Reliquary | Ember Fang | Repeated attacks on one target gain 8% attack speed per stack, up to 5 stacks. Changing targets or pausing 3s resets them. |
| Drowned Bell | Tollstone | Every 4 attacks, echo the primary shot after 0.18s for 0.5× base damage. The echo retains its blast and triggers no other effects. |
| Eclipse Prior | Eclipse Shard | Every 5 attacks, the primary shot and its blast deal 1.5× damage. Bypass boss defenses: 1 (0 off, 1 on). |
| Briarbound Warden | Briar Thornspindle | Every 3 attacks, wound the primary target for 0.3× base damage per second for 4s. Fire damage: 0 (0 off, 1 on). Reapplying refreshes this tower’s wound. |
| Briarbound Warden | Heartwood Lens | The primary shot and blast deal 1.35× damage to enemies currently rooted, slowed or stunned. |
| Cinder Reliquary | Ashen Censer | Every 2 attacks, burn the primary target for 0.4× base damage per second for 3s. Fire damage: 1 (0 off, 1 on). Reapplying refreshes this tower’s burn. |
| Cinder Reliquary | Crucible Seal | Every 4 attacks, expand the primary shot’s blast to at least 52 units. All enemies in the blast take its normal damage. |
| Drowned Bell | Undertow Chain | Every 4 attacks, push the primary target back 28 units along its road. Respects knockback resistance; immunity lasts 2s. |
| Drowned Bell | Hush Chime | Every 6 attacks, stun the primary target for 0.6s (0.2s for bosses). Immunity lasts 3s. |
| Eclipse Prior | Bloodmoon Rosary | Repeated attacks on one target add 6% primary-shot damage per stack, up to 6 stacks. Changing targets or pausing 3s resets them. |
| Eclipse Prior | Penumbral Mirror | Every 5 attacks, send up to 2 extra bolts to distinct enemies within 90 units of the primary target. Each deals 0.45× base damage with no blast or extra effects. |
| Ruined King | Kingsbane Crown | The primary shot and its blast deal 1.4× damage to bosses. Their defenses still apply. |
| Ruined King | Siege Signet | The primary shot and its blast deal 1.8× damage to targets at or above 90% health on impact. |
| Ruined King | Executioner’s Edge | The primary shot and its blast deal 1.6× damage to targets at or below 25% health on impact. |
| Mourning Matriarch | Mourning Veil | Every 2 attacks, slow the primary target by 30% for 2s (1s for bosses). The strongest slow applies. |
| Mourning Matriarch | Pale Mourning Fruit | Every 4 attacks, expose the primary target for 3s, increasing damage from all towers by 15%. The strongest exposure applies. |
| Mourning Matriarch | Wakekeeper’s Lantern | On changing target or resuming after 4s, the first 2 attacks gain 35% attack speed. |

## Shared rules

- Only primary attacks trigger equipment. Conditional and empowered damage apply across that primary shot's blast. Extra arrows, chains, fragments, echoes and mirror bolts cannot recursively activate equipment.
- Attack-speed effects change the equipped tower's attack interval. Stack and opening-burst counters belong to that equipment instance and reset on transfer or removal.
- Root, stun and knockback immunity are shared by the target, preventing multiple copies from bypassing protection. Knockback honors each enemy or boss's resistance.
- Slow and exposure use the strongest currently active value. Damage-over-time effects refresh per tower and can coexist across towers. Fire damage participates in boss fire defenses/weaknesses.
- A launched shot captures its damage and effect parameters. Editing settings changes future attacks; root cooldowns preserve their remaining fraction and existing stack/burst limits clamp immediately.
- Unequipping, transferring or selling removes the old owner's active statuses and progress. Old projectiles retain their damage but cannot reattach removed statuses. Recycled enemies start clean.
- Inventory, ownership and Creative settings persist. Combat counters and temporary statuses reset on load, matching the existing transient combat model.

## Extending content

`catalogs/gear.gd` owns gear stats, presentation, behavior assignments and boss drop sets. `catalogs/attributes.gd` registers immutable `Attribute` content nodes; `nodes/attributes/` implements reusable behavior. Bleed and fire share the same damage-over-time object; speed/damage momentum and conditional damage share their respective implementations.

Content definitions expose `with_component(new_id, slot, attribute, config)` and `without_component(new_id, slot)`. Both return a derived definition, preserving parents and siblings. A slot can be attached, replaced or removed explicitly. `GearNode` resolves components and gives each slot independent runtime state. Gameplay/equipment owners execute effects and clear them on removal. No shared node holds a game session or enemy reference.

For a new piece, author its numeric values, attach registered behavior, add field descriptors in `catalogs/tuning.gd`, and assign its boss, description and icon. For a new behavior, extend `AttributeNode` and register it. Do not branch on gear IDs inside combat.

Drop IDs preserve the original coordinate for each boss's first piece and use `coordinate#gear_kind` for the other two. Save validation checks both parts and retains legacy coordinate-only identities.

Validation: `tests/gear_runner.gd` covers catalog counts, every editable field, actual effects, composition, lifecycle and save migration. `tests/rendered/gear_menu_checks.gd` covers the eighteen-piece editor and mobile layouts. The unit checks also run in `tests/test_runner.gd`.
