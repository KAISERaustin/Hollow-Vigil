# Shared performance data

Each combat owns `configuration_cache.gd`, `route_cache.gd`, and its shared enemy
index. These are derived data, excluded from save payloads. Route assignment goes
through `combat.set_enemy_route`: waypoints and suffix distances are immutable
and shared only between identical routes. Authored route assignments and boss escorts use the same boundary. Existing actors retain their immutable route snapshot. The weak route table is pruned during assignment and ticking;
recycling drops route and identifier references before reusing an enemy dictionary.

Resolved content definitions and tower statistics are session-local. Tuning and
equipment snapshots detect both replacement and in-place changes. Tier, branch
and relic changes invalidate tower signatures, while removed towers are pruned.
Mutable cooldowns, afflictions, component progress and effect timers stay on their
existing per-instance owners. New speed modifiers should compose with live enemy
state after base configuration is resolved, rather than modifying cached definitions.

Static presentation uses the independent PNG catalog documented in
[ARTWORK_IMAGES.md](ARTWORK_IMAGES.md). It never controls simulation, save state,
visibility queries, or gameplay random numbers. New content can register an image
independently of its behavior; dynamic artwork remains with its rendering component.

The shared HUD value helper skips unchanged formatting. Floating HUD layout is
invalidated by text, safe-area, theme, minimum-size or translation changes. Text
measurement storage is bounded to 64 entries. Income timing, animation, touch
handling and the owning screen's refresh cadence remain unchanged.

These systems follow the content/component boundaries in [NODE_SYSTEM.md](NODE_SYSTEM.md).
