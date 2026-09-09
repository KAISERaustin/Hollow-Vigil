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

Menu → Edit rules uses an isolated draft for content rules and level resources. Waves → Edit wave owns groups, timing, entrance lanes and completion gold. Apply and Cancel keep draft edits separate from live settings. The campaign owner applies approved changes and preserves unrelated authored values.

## Ownership and verification

Content nodes provide definitions; gameplay services own transactions and simulation; persistence validates and serializes; rendering owns artwork; UI owns navigation and input. Keep imports in that direction. Campaign saves, builds, editor controls, descriptions, artwork and tests must agree when content changes.

Run the relevant Campaign runners plus `tools/check_structure.py`. Use rendered portrait checks for UI changes and keep physical phone validation distinct from desktop simulation.
