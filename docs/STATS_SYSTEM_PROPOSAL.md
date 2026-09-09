# Stats system: scope, baseline, and compatibility review

September 9, 2026. Planning document; no Stats runtime or editor implementation yet.

## Confirmed requirements

- Changes apply to every level in the selected Campaign save slot, without changing other slots.
- Separate Stats, Abilities, and Attributes, with assignable catalog entries for each compatible recipient.
- Offer the complete existing gameplay catalog, not user-created stat definitions. Add poison, ice-effect, and hex resistance to the proposed Attribute catalog.
- Preserve current attachments and values by default. Reset restores the frozen pre-migration defaults, not the last saved edit or future balancing changes.
- Every enemy, boss, tower tier, and tower branch has independent editable values. Editing a base tower must not implicitly rescale other tiers.
- Select an entity, inspect enabled entries, add entries from rows, type values, Save, or Reset to Default.
- Review incompatible combinations before implementing the system. Towers do not have health.

## Frozen reference

`references/stats-baseline-2026-09-09.json` captures shipped definitions and resolved editable values from commit `5188cb4d16b81d6389884c8857621555a583aaa0`. It includes 18 enemies, 6 bosses, 40 tower tier/branch entries, ability and equipment definitions, projectile settings, portal modifiers, escape damage, component attachments, retired controls, source hashes, and all 30 authored level tuning records.

This is a checked-in migration reference, not yet a runtime reset implementation. It contains shipped defaults, not private player save edits. Equipment bonuses, portal effects, and active combat state must remain distinct from base values. The commit preserves the source behavior behind those values. JSON represents projectile Vector2 presentation fields as strings; these are reference metadata rather than numeric stat inputs.

Reset should restore both values and enabled membership, remove user-added entries, and preserve progression, currency, placements, and unrelated entity edits. New resistance attributes should default to absent (neutral) so they do not change current balance. Optional entries can retain disabled values within a draft/save; essential health and timing fields need valid minimums.

## Current stat inventory and dependencies

| Group | Existing values | Proposed recipients and dependencies |
| --- | --- | --- |
| Survival and movement | Health, movement speed, gold per defeat, knockback resistance, core damage on escape | Enemies and bosses. No tower health, bounty, road speed, core escape damage, or defensive resistance while towers cannot be attacked. |
| Basic offense and economy | Damage, attack interval, range, splash radius, targets per attack, build/upgrade cost | Towers. Enemies currently walk to the core rather than fight towers; attack stats on enemies require new combat rules. Cost is distinct from gold earned by killing an enemy. |
| Projectile attacks | Victims per pass, damage loss per victim, minimum pierce damage, projectile hit radius, parallel bolt count/spacing, return speed; projectile travel speed and flight limits | Require a compatible attack ability. Travel/visual timing fields need classification; electric attacks and traps cannot meaningfully use every projectile field. One primary attack mode recommended. |
| Poison and burning | Poison DPS multiplier and duration; burn DPS multiplier and duration; gear fire flag, ground-effect radius | Require poison or ground-damage abilities. Poison and burn multipliers use base/hit damage; the editor should distinguish absolute DPS from a multiplier. Damage type is a selector, not an arbitrary numeric toggle. |
| Slow, push, stun, root | Slow strength/duration; push distance/immunity; stun duration/immunity; gear root interval, normal/boss root duration, root immunity | Applied by offensive abilities on towers; resisted by attributes on enemies/bosses. Root/stun are distinct from ice slow. Existing immunity windows are not the same as resistance percentages. |
| Fragments and lightning | Fragment count/reach/damage multiplier; chain reach/damage multiplier; seal hit count, bonus damage, stun settings | Require corresponding fragment, chain, or seal abilities. These numbers alone cannot create the behavior. |
| Curse and hex | Curse stack limit/damage per stack; vulnerability strength/duration; spread count/radius | Doomstone's focused curse and Hex Lantern's damage-taken mark are separate mechanics. Decide whether Hex Resistance covers both and equipment exposure. |
| Support | Nearby tower damage bonus and range | Tower support aura. Putting it on an enemy would otherwise strengthen the player's towers; enemy-allied aura semantics require a separate recipient policy. |
| Traps | Capacity, lifetime, arming delay, deployment count, trigger radius | Require trap deployment. Traps use roads and do not block movement. Tower traps assigned to enemies have no useful target under current combat rules. |
| Shields and wards | Shield HP, ward hit count, defense regrowth interval | Enemy/boss defensive abilities. Shield consumes damage; ward consumes hits. Need explicit ordering if combined. No tower recipient while towers have no health. |
| Conditional defenses and haste | Health threshold, haste multiplier, high-health damage reduction, frost damage multiplier, haste suppression | Enemy/boss attributes and abilities. Cinder Reliquary currently owns this behavior; general attachment requires extracting reusable behavior and choosing effect-based versus named-tower triggers. |
| Summoning | Escort type, count, living limit, summon interval, seal damage multiplier, summon delay | Enemy/boss summoning ability. Escort type should be an illustrated selector. Tower assignment requires defining friendly units. Recursive summoning must be bounded. |
| Boss counters | Fire shield multiplier, regrowth suppression, Doomstone ward bypass, curse suppression threshold, frost and Thunderseal counters | Require their associated defense/ability. Current counters partly check tower branch identities; moving abilities between towers raises an explicit design choice. |
| Equipment-derived capabilities | Effect radius, blast radius/multiplier, range bonus, echo delay/damage, per-stack damage/speed, stack limit/timeout, activation attack count, conditional health threshold/damage multiplier, extra bolt count/radius/damage, defense bypass, opening attack count/speed/reset | Existing reusable capability library; direct assignment to towers is plausible, but overlapping equipped gear needs stacking rules. Enemy/boss assignment only where the behavior has a compatible recipient and trigger. |

Do not expose live HP remaining, cooldown progress, active curse/seal counters, current shield/ward charges, collected earnings, placement coordinates, IDs, appearance, sounds, or labels as base Stats. Keep level starting gold, core maximum health, wave reward/count/timing, and global sale/move/rebuild formulas under their existing level/economy owners unless explicitly expanding scope. These are not interchangeable entity stats.

Poison Arrow's old arrow-count/fan-angle controls and Matriarch Lantern's old opening-attack controls are retired for those recipients. Keep them readable for old data without advertising them as functioning attachments. The reusable opening ability still exists for other equipment.

## Resistance decisions to settle

Proposed new attributes use 0–100%, where 100% means immunity to the specified damage or effect. Leave them unattached on all defaults. Existing knockback values remain enabled exactly as captured.

- Poison Resistance: reduce poison damage per tick, leaving duration unchanged.
- Ice Resistance: reduce slow strength, leaving duration unchanged; do not automatically reduce the direct needle hit or block stun/root.
- Hex Resistance: reduce the damage amplification from a vulnerability mark, leaving duration unchanged. Decide whether this also covers equipment exposure and Doomstone's separate curse.
- Physical Armor and Magic Resistance: not existing general damage categories. They require a damage-type map for all attacks, fragments, traps, damage-over-time, and equipment. Cinder Reliquary's existing conditional reduction is not general physical armor.
- Fire, lightning, stun, and root resistance: sensible possible extensions, but not assumed approved additions. Distinguish damage resistance, control resistance, and resistance to a named tower family.
- Multiple applicable resistances: recommend multiplicative reductions rather than additive immunity. A 20% and a 30% reduction would leave 56% damage. Decide whether defense-bypass effects bypass these new defenses.

## Other compatibility decisions

1. Attack mode: piercing, returning, orbit, and road traps compete for primary attack ownership. Recommend one primary mode plus compatible secondary effects; replacement should be explicit in the editor.
2. Required ability: show every catalog entry with an availability explanation. Adding a dependent stat should offer its required ability rather than silently storing an ineffective number.
3. Boss portability: recommend allowing shields, wards, haste, and summoning on ordinary enemies after extraction into reusable components. Their special counters should follow the assigned ability if approved. Existing named-tower behavior must remain unchanged for defaults.
4. Authored exceptions: level 5's Warden has 1,800 HP, 300 shield, and a 12-second regrowth parameter versus catalog 3,200 HP, 600 shield, and 10 seconds. Recommend preserving authored differences on Reset, but making an explicit save-wide edit override that field in every level/wave. The current encounter update loop does not regenerate the Warden shield; preserving its parameter must not silently introduce regeneration.
5. Portal modifiers: Forge grants 25% health, Crypt 15% speed, Sanctuary regenerates 1% maximum health per second. Recommend retaining these as separately displayed modifiers; avoid accidentally applying them twice when adding an entity regeneration capability.
6. Saving during combat: recommend updating live and future recipients with health percentage preserved, avoiding free healing. Define effect cleanup, projectile ownership, shield/ward resizing, and cooldown behavior for ability removal or replacement before implementation.
7. Equipment overlap: preserve existing stacking behavior for default content; define merge/replace rules for newly duplicated direct and equipped capabilities. No implicit double attachment.
8. Mode access: existing developer editing is Creative-only. Save-slot rules should remain effective in both modes; changing who can open the editor is a separate decision.

## Implementation shape after decisions

Add a reusable Stats family and shared ownership through Entity, retaining Boss as an Enemy subtype. Separate the catalog's numerical Stats, active Abilities, and passive Attributes for presentation, while reusing composable components underneath. Definitions are immutable; attachments and values belong to the save slot; mutable combat progress belongs to instances.

Use independent tier/branch records with migration that resolves existing inherited tuning before flattening it. Preserve old configured saves and portable configurations, validate compatible attachments at persistence and simulation boundaries, and keep imported changes confined to the selected slot. Use explicit user overrides with higher priority than authored level/wave tuning, subject to the authored-default decision above.

Extend shared editor controls using parchment cards and portraits, Add Stat / Add Ability / Add Attribute catalog rows, readable units, typed numeric input, draft Save/Cancel, and entity-scoped Reset to Default. Validate selection, attachment dependencies, save isolation, reset parity, live updates, multiple-recipient reuse, instance-state isolation, old-save migration, equipment interactions, and portrait layout at 360×640, 390×844, and 540×960.
