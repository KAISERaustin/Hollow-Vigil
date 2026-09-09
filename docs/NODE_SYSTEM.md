# Reusable Campaign content nodes

`scripts/content/registry.gd` builds one discoverable content tree. These lightweight RefCounted nodes are independent of visual scene nodes. Definitions hold configuration; spawned instances hold timers, counters and effect state. Saves contain stable content IDs and validated dictionaries.

## Families

- Entity → Tower → eight tower families → levels and level-four specializations.
- Entity → Enemy → chapter families → ordinary enemy types; Boss is an Enemy subtype.
- Entity → Gear → eighteen equipment types with attachable attributes.
- Level → Campaign → six chapters → 30 authored missions. Creative and Survival define editor access.
- Wave → authored enemy groups, entrance lanes, timing and rewards.
- Projectile, Ability and Targeting → reusable combat behavior.
- World → Region and Portal → authored placement anchors, biome identity and presentation.
- Build contents → reusable Campaign rule groups and resource selection.

## Adding or changing content

Identify the family, shared rules and composable parts first. Extend existing nodes before introducing a new family. Define optional abilities, mechanics, modifiers and effects as attachable attribute/component objects. Attach, replace and remove them through the owning service. Clean up removed effects and reset state when pooled instances are reused.

One component may serve several assigned types. Its configuration must not mutate parents, siblings or unrelated sessions. Mutable cooldowns, counters and effect progress belong to each recipient. Validate reuse across multiple recipients, unchanged unassigned types, independent runtime state and cleanup after removal. Add persistence coverage when configuration or state should survive saves.

Register stable namespaced IDs, such as `tower/heavy` and `enemy/heavy`. Expose identity and rules through the catalog, balance aliases and editor schema. Resolve placed tower stats through `Balance.tower_stats`; costs and transactions stay in the economy. Change targeting through `VigilState.set_tower_target` to invalidate locks consistently.

## Campaign composition

Level and Wave nodes own authored roads, spawn groups, resources, rewards and portal effects. `campaign/run.gd` connects them to shared combat. Campaign supplies placement roads and bounds; towers stay off roads and portals and cannot overlap. Coordinate helpers keep older socket keys readable.

Campaign Level nodes attach `investment_refund` in the `setup_refund` slot during initial planning. Starting the first wave removes that attachment for the rest of the attempt. The economy resolves both sale previews and payouts. This exception does not change later-wave refunds.

Menu → Edit rules uses an isolated draft for content rules and level resources. Waves → Edit wave saves each completed field or selection immediately through the campaign owner. Wave editing is Creative-only and locked during active combat, even when paused. Survival plays the saved composition. Reset wave restores authored defaults; Reset all waves restores the level's original sequence.

`campaign/wave_editor.gd` composes proposed wave changes without mutating shared nodes. Optional `wave_count` overrides the authored count; old sparse saves retain their original interpretation. New waves start empty with the first configured wave's settings. Empty waves are saved placeholders and skipped during play without rewards; a level must retain at least one enemy. Validation retains 32 groups, 1,000 enemies per group, 5,000 enemies per wave, and a 10,000-wave safety ceiling.

Wave groups retain their five legacy columns (enemy, count, portal, delay, spacing). An optional sixth column sets gold per defeated enemy for that group. The Wave node puts it on scheduled spawns, the Campaign run assigns it to each enemy instance, and combat credits it on death. This is independent of global entity Stats. Counts edited on summary cards are distributed proportionally across existing groups without changing portals or timing. Campaign builds, full playthroughs, checkpoints and reusable builds preserve the custom wave count and optional group rewards.

## Stats and assignable capabilities

Stats → Entity → Tower / Enemy → Boss supplies common save-local stat ownership. The frozen September 9 baseline lives in `scripts/content/catalogs/stats_defaults.gd`; new content can register its own baseline through the registry. `stat_capabilities.gd` declares reusable abilities and their parameter dependencies. `stats.gd` resolves enabled values, independent tier overrides, catalog compatibility, and reset membership. Keep mutable shields, wards, timers, stacks, and effect progress on individual recipients.

Edit rules uses `ui/shared/stats_editor.gd` for searchable Stats, Abilities and Attributes. The Campaign save applies one entity rule set across all levels; level/wave entity tuning cannot change a boss's base values between encounters. Slot migration flattens legacy tier scaling, retains configured values, and removes the retired early-Warden reduction. World portal modifiers remain separate.

Enemy capability nodes provide reusable shields, wards, regrowth, rage and summoning. Resistance nodes handle poison, ice, hex and knockback. Tower composition reuses attack and equipment components; one primary attack may be assigned at a time. Save updates live recipients while preserving health/cooldown proportions and cleaning up removed capabilities. Reset restores the frozen entity values and attachments, without resetting the save's progression.

Run `tests/stats_system_runner.gd` for defaults, composition, removal, runtime isolation, live edits, save slots and exports; `tests/rendered/stats_editor_runner.gd` exercises the editor at the three portrait phone sizes.

## Ownership and verification

Content nodes provide definitions; gameplay services own transactions and simulation; persistence validates and serializes; rendering owns artwork; UI owns navigation and input. Keep imports in that direction. Campaign saves, builds, editor controls, descriptions, artwork and tests must agree when content changes.

Run the relevant Campaign runners plus `tools/check_structure.py`. Use rendered portrait checks for UI changes and keep physical phone validation distinct from desktop simulation.

Portal Attributes adds save-local armor (percentage damage reduction, bypassed by armor-piercing hits) and health regeneration (percentage maximum health per second) to every portal type. The reusable portal_enemy_effects attribute resolves immutable configuration through Portal nodes; combat applies it to source-portal recipients. Campaign bosses retain portal_effect_style separately from legacy biome effects. Zero removes an effect, default values remain zero, and regeneration adds to existing biome regeneration. Verify with tests/portal_attributes_runner.gd and tests/rendered/portal_attributes_runner.gd.

Portal recipient components also expose Electric, Slow, Poison and Knockback Resistance, each defaulting to 0%. Existing enemy resistance and portal resistance multiply the remaining effect; 100% removes that damage or effect. Stormspire's primary damage is electric through the Tower content rule and projectile snapshot. Chain lightning and charged seals explicitly deal electric damage even when assigned to another tower. Fire and poison gear retain their own damage types; armor bypass does not bypass electric resistance. Portal shields were not added.
