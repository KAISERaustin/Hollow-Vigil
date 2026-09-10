# Archived boss equipment

Gear is removed from active gameplay. Acquisition, equipment and effects are disabled, and Gear buttons are disabled. All 18 source images remain in `assets/retained_gear/` for future use. The descriptions below document the former system. See [Simplified rules](SIMPLIFIED_RULES.md).

There are **18 equipment types: three for each of the six bosses**. A victory awards the complete three-piece set once. Each piece occupies the shared tower relic slot and works on every tower and specialization. Old recorded victories receive any missing set pieces on load, without replacing existing equipment or repaying gold.

In Campaign Creative, open **Menu → Edit rules → Gear** to select a piece and edit its numeric effect settings. Apply commits the draft to the Campaign configuration; descriptions reflect the selected values. Reset selected restores only that piece. Equipment identity, boss theme and attached behavior remain authored content.

| Boss | Equipment | Default attribute |
| --- | --- | --- |
| Briarbound Warden | Warden’s Rootheart | Every 6 seconds, a primary shot roots its target for 0.75s (0.35s for bosses). Root immunity lasts 3s. |
| Cinder Reliquary | Ember Fang | Repeated attacks on one target gain 8% attack speed per stack, up to 5 stacks. Changing targets or pausing 3s resets them. |
| Drowned Bell | Tollstone | Every 4 attacks, echo the primary shot after 0.18s for 0.5× base damage. The echo retains its blast and triggers no other effects. |
| Eclipse Prior | Eclipse Shard | Every 5 attacks, the primary shot and its blast deal 1.5× damage and bypass boss defenses. |
| Briarbound Warden | Briar Thornspindle | Every 3 attacks, wound the primary target for 0.3× base damage per second for 4s as non-fire damage. Reapplying refreshes this tower’s wound. |
| Briarbound Warden | Heartwood Lens | The primary shot and blast deal 1.35× damage to enemies currently rooted, slowed or stunned. |
| Cinder Reliquary | Ashen Censer | Every 3 attacks, create burning ground within 45 units of impact for 3s. Enemies inside take 0.2× base shot damage per second. One tower's overlapping gear patches do not stack damage. |
| Cinder Reliquary | Crucible Seal | Every 4 attacks, use a blast radius of 52 units or 1.25× the normal blast radius, whichever is larger. All enemies inside take normal shot damage. |
| Drowned Bell | Undertow Chain | Every 4 attacks, push the primary target back 28 units along its road. Respects knockback resistance; immunity lasts 2s. |
| Drowned Bell | Hush Chime | Every 6 attacks, stun enemies within 60 units of impact for 0.5s (0.2s for bosses). Immunity lasts 3s. |
| Eclipse Prior | Bloodmoon Rosary | Each credited kill grants 5% primary-shot and blast damage, up to 5 stacks (25%). Kills refresh the stacks; 6s without a kill clears them. Switching targets preserves stacks. |
| Eclipse Prior | Penumbral Mirror | Every 5 attacks, send up to 2 extra bolts to distinct enemies within 90 units of the primary target. Each deals 0.45× base damage with no blast or extra effects. |
| Ruined King | Kingsbane Crown | The primary shot and its blast deal 1.4× damage to bosses. Their defenses still apply. |
| Ruined King | Siege Signet | The primary shot and its blast deal 1.8× damage to targets at or above 90% health on impact. |
| Ruined King | Executioner’s Edge | The primary shot and its blast deal 1.6× damage to targets at or below 25% health on impact. |
| Mourning Matriarch | Mourning Veil | Every 2 attacks, slow the primary target by 30% for 2s (1s for bosses). The strongest slow applies. |
| Mourning Matriarch | Pale Mourning Fruit | Every 4 attacks, expose the primary target for 3s, increasing damage from all towers by 15%. The strongest exposure applies. |
| Mourning Matriarch | Wakekeeper’s Lantern | Increase the equipped tower's attack range by 20%, including targeting, the range circle, and displayed reach. |

## Shared rules

- Only primary attacks trigger equipment. Conditional and empowered damage apply across that primary shot's blast. Extra arrows, chains, fragments, echoes and mirror bolts cannot recursively activate equipment.
- Attack-speed effects change the equipped tower's attack interval. Attack and kill counters belong to that equipment instance and reset on transfer or removal.
- Ground fields resolve once at the impact position, including when the original target has died. They use launch damage, stay fixed as enemies move, and expire after their authored duration. Overlap from the same tower/component uses the strongest single contribution; independent towers contribute independently. Gear ground fire and Cinderfield are separate capabilities.
- Root, stun and knockback immunity are shared by the target, preventing multiple copies from bypassing protection. Knockback honors each enemy or boss's resistance.
- Slow and exposure use the strongest currently active value. Damage-over-time effects refresh per tower and can coexist across towers. Fire damage participates in boss fire defenses/weaknesses.
- A launched shot captures its damage and effect parameters. Editing settings changes future attacks; root cooldowns preserve their remaining fraction and existing stack/burst limits clamp immediately.
- Unequipping, transferring or selling removes the old owner's active statuses and progress. Old projectiles retain their damage but cannot reattach removed statuses. Recycled enemies start clean.
- Inventory, ownership and Creative settings persist. Combat counters, ground fields and temporary statuses reset on load and campaign wave transitions, matching the existing transient combat model. Retired Lantern opening fields remain accepted in old configurations but are hidden from editing and have no gameplay effect.

## Extending content

`catalogs/gear.gd` owns gear stats, presentation, behavior assignments and boss drop sets. `catalogs/attributes.gd` registers immutable `Attribute` content nodes; `nodes/attributes/` implements reusable behavior. Wounds and Poison Arrow share the target damage-over-time object. Ground damage, kill momentum and passive range are reusable components; the existing blast and stun components also support radius scaling and area recipients.

Passive `modify_stats` runs before targeting through `Balance.tower_stats(tower, tuning, inventory)`, and is used by combat, the range circle and tower details. `credited_kill` runs once after the combat owner marks a target dead. `arrive` runs once per primary projectile at impact; per-enemy `impact` retains the existing splash semantics. `combat/effect_fields.gd` owns field time, damage, overlap and cleanup. Component definitions retain no mutable runtime state.

Content definitions expose `with_component(new_id, slot, attribute, config)` and `without_component(new_id, slot)`. Both return a derived definition, preserving parents and siblings. A slot can be attached, replaced or removed explicitly. `GearNode` resolves components and gives each slot independent runtime state. Gameplay/equipment owners execute effects and clear them on removal. No shared node holds a game session or enemy reference.

For a new piece, author its numeric values, attach registered behavior, add field descriptors in `catalogs/tuning.gd`, and assign its boss, description and icon. For a new behavior, extend `AttributeNode` and register it. Do not branch on gear IDs inside combat.

Drop IDs preserve the original coordinate for each boss's first piece and use `coordinate#gear_kind` for the other two. Save validation checks both parts and retains legacy coordinate-only identities.

## Native illustrations

The September 7 gear direction follows the user's detailed portal references: layered angular silhouettes, solid black outlines, parchment/bone, carved wood, stone and iron, small brass fittings and restrained biome accents. The eighteen names and saved IDs are unchanged. Generic colored-circle badges are replaced by complete objects.

`rendering/actors/relic_art.gd` selects the Gear node's presentation family. The six families in `rendering/actors/gear/` compose the shared `illustration.gd` drawing kit. Menus, developer portraits, equipped badges and drops all use that renderer. There are no bitmap dependencies in gameplay; the gear art runner writes transparent 256px exports to ignored `artifacts/gear/` of all eighteen native designs for inspection and reuse.

Validation: `tests/content_node_runner.gd` checks shared definitions, composition and isolated instances. `tests/rendered/illustrated_picker_touch_runner.gd` exercises equipment selection and touch ownership. `tools/previews/gear_art_preview.gd` regenerates all eighteen PNGs and the lineup, checking transparent padding and small silhouettes.
