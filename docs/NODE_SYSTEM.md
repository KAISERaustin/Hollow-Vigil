# Reusable game content nodes

`scripts/content/registry.gd` builds the game's content tree. Each node inherits attributes, rules and fresh-instance defaults from its parent. Types override only their differences. The running game uses these definitions through the existing Balance, economy, combat, world and campaign APIs.

These are lightweight `RefCounted` **content nodes**, independent of Godot's visual scene nodes. One definition can serve many live entities, levels and headless simulations. Rendering still owns its `Node2D` objects; saves still contain ordinary dictionaries and stable content IDs. The portal roster update preserves those IDs and refunds retired attunements through the save owner.

```mermaid
graph TD
    Content --> Entity
    Entity --> Tower
    Tower --> Ashneedle
    Tower --> Pyre
    Tower --> Obelisk
    Tower --> Stormspire
    Ashneedle --> Tier2[Level 2]
    Tier2 --> Tier3[Level 3]
    Tier3 --> Frostneedle
    Tier3 --> ThornVolley[Thorn Volley]
    Entity --> Enemy
    Enemy --> Forest
    Enemy --> Forge
    Enemy --> Crypt
    Enemy --> Sanctuary
    Enemy --> Castle
    Enemy --> Orchard
    Enemy --> Boss
    Boss --> Warden
    Boss --> Reliquary
    Boss --> Bell
    Boss --> Prior
    Boss --> RuinedKing[Ruined King]
    Boss --> MourningMatriarch[Mourning Matriarch]
    Entity --> Gear
    Content --> World
    World --> Region
    World --> Portal
    World --> Socket
    World --> Landmark
    Content --> Level
    Level --> OpenWorld[Open world]
    OpenWorld --> Creative
    OpenWorld --> Survival
    Level --> Campaign
    Campaign --> Chapters
    Chapters --> Missions[20 missions]
    Content --> Wave
    Content --> Projectile
    Content --> Ability
    Content --> Targeting
```

The four relics, eighteen ordinary enemies, six terrain/portal types, four projectile profiles, eight abilities, every tower tier, and every campaign wave have individual entries. IDs are namespaced: `tower/heavy` is Obelisk; `enemy/heavy` is Rootbound Revenant. Bosses inherit Enemy in both the content tree and the GDScript class hierarchy.

## Using a node

```gdscript
const Content = preload("res://scripts/content/registry.gd")
var tower = Content.tower("rapid")
var can_build = tower.can_place("plus", true, false)
var fresh_tower = tower.create("42", "1,0", 2)
var upgraded_stats = tower.stats(4, game.tuning, "frostneedle")
var enemy_types = Content.catalog().descendants("enemy")
var specializations = Content.catalog().children("tower/rapid/3")
var mission = Content.level(0).layout()
var spawns = Content.wave(0, 0).schedule()
```

`attributes()` returns an independent deep copy. `rule(key)` reads an inherited rule. `definition(tuning)` applies the owning game's sparse overrides. `make_record(fields)` creates independent mutable instance state. `derive()` keeps the parent's implementation and overrides supplied values. Nested dictionaries merge; child arrays replace parent arrays. Shared catalog tables are recursively read only.

A tower tier node's `stats()` resolves its own tier through the base tower exactly once; its `create()` keeps the original save kind and sets its level/branch. Use `Balance.tower_stats()` for existing tower dictionaries, and the existing Balance helpers for quotes and displayed descriptions.

## Rules and ownership

| Family | Shared behavior | Runtime owner |
| --- | --- | --- |
| Tower | Free plus socket on owned land; relic slot; target modes; initial state; tier scaling | Economy authorizes spending, construction, relocation, upgrades and equipment |
| Enemy | Identity, health, movement defaults, escape damage, clean pooled records | Combat owns live enemies, movement and payouts |
| Boss → Enemy | Encounter state; overridable movement speed and damage absorption | Encounter service owns discovery, routing, regeneration and escort timers |
| Gear | Equipment compatibility and attack progress; overridable attack effect | Relic service owns drops, ownership and effect timing |
| Projectile | Muzzle, flight bounds, impact timing and fresh effect records | Combat owns flight and impact; rendering draws effects |
| Ability | Specialization parameters and resolution against launched tower stats | Ability/projectile services execute effects on the simulation clock |
| Region | Saved terrain identity and fresh history, traffic and unlock state | World service owns geography and routes |
| Portal | Enemy family, exclusivity and biome tuning | Combat owns spawn clocks |
| Socket / landmark | Plus geometry and capacity; landmark properties | World and economy enforce placement and topology |
| Level | Open-world/mode rules or authored campaign layout and allowed sockets | State/campaign run owns progress and saves |
| Wave | Spawn groups and stable schedule ordering | Campaign run advances the schedule |
| Targeting | Per-mode lock policy | Combat owns locks; First/Last keep switching |

Nodes never retain the owning game, visual objects, live enemy dictionaries or mutable progress. Parents point upward; child discovery uses the registry, avoiding parent/child reference cycles. Factories construct records; services still validate ownership, affordability, stale actions and save contracts.

## Shared tower presentation

Campaign and Infinite Worlds instantiate the same `VigilTowerActions`, `VigilTowerDialog`, relic picker and tower move components. The campaign screen supplies the active mission's `game` and `field` plus the host callbacks for persistence, selection and feedback. The shared dialogs accept a `Control` host rather than requiring the Infinite Worlds application. Add tower menu features to these shared components, never to a separate campaign management dialog. Campaign only owns its authored socket validation and construction entry point; upgrades, specialization confirmation, equipment, targeting, sales and relocation remain shared transactions. Mission inventory stays isolated from Infinite Worlds, and campaign completion persistence retains its existing semantics.

## Adding a tower such as Pike

This creates a prototype inheriting Ashneedle's behavior in an isolated catalog:

```gdscript
var prototypes = Content.new()
var ashneedle = prototypes.get_node("tower/rapid")
var pike = ashneedle.derive(
    "tower/pike",
    {"name": "Pike", "damage": 8.0},
    {"kind": "pike"}
)
prototypes.register_node(pike, "towers", "pike")
var record = pike.create("43", "1,0", 0)
```

This also inherits Ashneedle's authored upgrades and branches. Supply different `upgrades`, `branches`, `abilities` and `multipliers` rules when designing another progression. Prototype registration does not automatically add a type to shipped menus or save validation.

To ship a tower, add its rows to `scripts/content/catalogs/towers.gd`: `TOWERS`, `TOWER_UPGRADES`, `BRANCHES`, `PROJECTILES`, and relevant ability definitions. The registry creates the type and descendant tiers automatically. Existing menus and validators use the same source tables through Balance aliases. Add art, audio and new attack mechanics, then test construction, combat, upgrades, equipment and saving. Existing tower names and IDs are preserved; Pike is an extension example, not an added playable tower.

## Other extensions

### Biome bosses

Every region subtype supplies `boss_kind()` from `catalogs/world.gd`'s `BIOME_BOSSES`. Forest uses Briarbound Warden, Ashen Forge uses Cinder Reliquary, Drowned Crypt uses Drowned Bell, Bloodmoon Sanctuary uses Eclipse Prior, Castle Ruin uses Ruined King, and Mourning Orchard uses Mourning Matriarch. Each connected biome cluster has exactly one seeded encounter tile, independent of purchase order. The shared world cluster service uses visible terrain after castle and Orchard overlays, so disconnected patches are separate clusters. Only purchasing the encounter tile awakens its boss. Castle gates retain their discovery encounter; the Orchard uses its seeded entrance. Other tiles in the cluster never awaken additional bosses. The starting core is excluded from encounter selection.

Ruined King and Mourning Matriarch inherit the shared Boss → Enemy node, with distinct stats, knockback resistance and native silhouettes. Their rewards are owned by the shared progression and equipment catalogs. Their sound families are assigned through boss presentation rules. No new special ability or mutable shared state is introduced. Optional future abilities should use attachable components.

On load, per-tile encounters from the previous release are reconciled by cluster. A defeated or escaped encounter completes the entire cluster. Otherwise, the active boss on the seeded encounter tile is retained, falling back to one stable existing source if that tile has not been purchased. Extra active records are removed without gold, kills or relic rewards. Completed records, earned relics and the retained boss's health and route remain intact. Old randomly assigned castle boss identities remain readable. New encounters resolve the owning region's current biome.

The node/component architecture is the default for every future game addition, not only attributes. Follow `AGENTS.md`: identify the reusable node/category and shared rules, reuse or extend existing nodes, and compose reusable objects for the new content or mechanic. Implement optional capabilities once, assign them explicitly to one or more types, and keep mutable state on each live instance. Inheritance supplies the shared category; composition supplies selectable behavior. The current hierarchy is the foundation for that work. The illustrative periodic speed boost has not been added.

- **Enemy:** add stats and assign exactly one biome family in `catalogs/actors.gd` (`FAMILIES`). Every shipped portal has three distinct inhabitants. Inherited `portal_style` identifies the family; `PRESENTATION` composes the drawing renderer and reusable death cue. Optional gameplay capabilities still require attachable component objects. Keep authored campaign and numeric escort IDs stable in `CAMPAIGN_KINDS` and `ESCORT_KINDS`.
- **Boss:** add stats in `catalogs/actors.gd`. For special defenses/speed, extend `nodes/boss_node.gd` and add the script to `BOSS_TYPES`. Warden, Reliquary and Prior demonstrate overrides; Bell uses shared defense behavior. Encounter summons and regeneration remain in the encounter service. Add a gear entry if a relic should drop.
- **Gear:** add stats/presentation in `catalogs/gear.gd`; extend `nodes/gear_node.gd`, override `_apply_attack()` and register the script in `GEAR_TYPES`. Shared code handles counters, targets and timestamps. Implement non-attack effects in their owning service.
- **Level:** add authored missions in `catalogs/levels.gd`. Update campaign count/progression and chapter assignment when expanding the campaign. Layout, allowed sockets and stable wave scheduling are reused.
- **Terrain/portal:** configure `PORTALS` in `catalogs/world.gd` and the matching actor family. Portal nodes expose `unlock_costs()`, `available_kinds(unlocks)`, `spawn_mix(unlocks)` and `choose_kind(unlocks, roll)`; the menu, economy and combat use these same rules. Every unlocked non-castle territory has an enemy portal; the core keeps its receiving portal and castles keep one dungeon portal per cluster. Enemies without a price are active immediately. Purchased IDs, timers and traffic remain per region. Castle portals offer Crypt Sentinel (550) and Sepulcher Colossus (2,000); all three Orchard inhabitants remain immediately available. See `docs/PORTAL_ROSTERS.md` for all rosters and save compatibility.
- **New family:** extend `nodes/content_node.gd`; register the parent before its subtypes. `register_node()` rejects duplicate identities, duplicate category keys and unregistered parents. Connect the family to its owning service and persistence contract before making it playable.

Tuning schemas live in `catalogs/tuning.gd`. Balance remains the compatibility API for editor bounds, validation, display text and prices. Keep one authored source per value; do not copy numeric defaults into new UI or behavior handlers.

## Validation

`tests/content_node_runner.gd` covers inheritance, subtype construction, nested-state isolation, registry guards, placement, equipment, pooling, boss effects and level/wave rules. The same checks run in `tests/test_runner.gd`. Run campaign and save-slot suites for shared level/mode changes. `tools/check_structure.py` checks resource links and dependency boundaries.
