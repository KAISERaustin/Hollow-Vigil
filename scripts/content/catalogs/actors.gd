extends RefCounted

const ENEMIES := {
	"ruin_knight": {"name": "Ruinbound Knight", "role": "DUNGEON · ELITE", "description": "An oathbound knight in broken royal armor, summoned only by castle ruin portals. Greater endurance and a relentless march demand upgraded towers.", "push_resistance": 50.0, "hp": 1200.0, "speed": 38.0, "payout": 95.0, "color": "9182ad"},
	"sepulcher": {"name": "Sepulcher Colossus", "role": "DUNGEON · COLOSSAL", "description": "A walking royal tomb crowned with ruined battlements. Castle ruin portals alone release this slow, immensely durable foe, whose stone bulk resists knockback.", "push_resistance": 90.0, "hp": 2200.0, "speed": 24.0, "payout": 165.0, "color": "99948c"},
	"basic": {"name": "Hollow", "role": "COMMON", "description": "A steady traveler from every rift. Its sturdy body rewards upgrading your sentinels.", "push_resistance": 0.0, "hp": 45.0, "speed": 39.0, "payout": 5.0, "color": "e8ddbd"},
	"fast": {"name": "Wraith", "role": "FAST", "description": "A swift spirit with less health than other foes. Its speed gives your towers less time to strike before it reaches the core.", "push_resistance": 0.0, "hp": 36.0, "speed": 74.0, "payout": 8.0, "color": "93c9bc"},
	"heavy": {"name": "Revenant", "role": "DURABLE", "description": "A slow, resilient foe with a rich bounty. High-damage towers help cut through its large health pool.", "push_resistance": 75.0, "hp": 340.0, "speed": 25.0, "payout": 24.0, "color": "db8d73"},
	"lantern": {"name": "Lantern Keeper", "role": "STEADFAST", "description": "A hooded pilgrim carrying a stolen ember through the rifts. Tougher than a Hollow and quicker than a Revenant, it rewards sustained fire with a generous bounty.", "push_resistance": 0.0, "hp": 120.0, "speed": 46.0, "payout": 14.0, "color": "b49dcc"},
	"shade": {"name": "Abyss Shade", "role": "DUNGEON · SWIFT", "description": "A swift shadow born only in castle ruin portals. Its dense shroud withstands sustained fire.", "push_resistance": 0.0, "hp": 240.0, "speed": 56.0, "payout": 30.0, "color": "9182ad"},
	"sentinel": {"name": "Crypt Sentinel", "role": "DUNGEON · ARMORED", "description": "A dark iron guardian summoned only by castle ruin portals. A deep health pool guards a rich bounty.", "push_resistance": 0.0, "hp": 680.0, "speed": 28.0, "payout": 55.0, "color": "74798c"},
	"briarling": {"name": "Briarling", "role": "ORCHARD · SWIFT", "description": "A bone-faced thornling that darts from the Mourning Orchard’s only portal. Fast attacks and slowing needles catch its fragile wooden frame.", "push_resistance": 0.0, "hp": 85.0, "speed": 86.0, "payout": 13.0, "color": "b9bd8a"},
	"veil_widow": {"name": "Veil Widow", "role": "ORCHARD · ENDURING", "description": "A mourning spirit in a split burial veil, born only through the Orchard portal. Its steady pace and dense shroud reward sustained fire.", "push_resistance": 25.0, "hp": 260.0, "speed": 43.0, "payout": 28.0, "color": "c4b6b1"},
	"coffinbound": {"name": "Coffinbound", "role": "ORCHARD · ROOTED", "description": "A walking coffin lashed shut with pale roots. Only the Orchard portal releases it. Slow, durable, and resistant to knockback; heavy damage breaks its shell.", "push_resistance": 90.0, "hp": 820.0, "speed": 22.0, "payout": 64.0, "color": "a5aa73"}
}

const BOSSES := {
	"warden": {"name": "Briarbound Warden", "push_resistance": 0.0, "hp": 3200.0, "speed": 27.0, "payout": 450.0, "color": "95aa83", "weakness": "Cinderfield: burns roots; blocks regrowth", "shield": 600.0, "regen_period": 10.0, "fire_multiplier": 2.0, "regrowth_suppression": 100.0},
	"cindermaw": {"name": "The Cinder Reliquary", "push_resistance": 0.0, "hp": 3600.0, "speed": 25.0, "payout": 500.0, "color": "db8d73", "weakness": "Frostneedle: +50% damage; quenches haste", "rage_threshold": 50.0, "haste_multiplier": 1.7, "armor_reduction": 30.0, "frost_multiplier": 1.5, "quench": 100.0},
	"bell": {"escort_kind": 0, "name": "The Drowned Bell", "push_resistance": 0.0, "hp": 2800.0, "speed": 32.0, "payout": 450.0, "color": "93c9bc", "weakness": "Thunderseal: stronger seals; delays tolls", "toll_period": 8.0, "escort_count": 3, "escort_limit": 6, "seal_multiplier": 4.5, "toll_delay": 2.0},
	"prior": {"name": "The Eclipse Prior", "push_resistance": 0.0, "hp": 3000.0, "speed": 30.0, "payout": 500.0, "color": "b49dcc", "weakness": "Doomstone: bypasses wards; curses regrowth", "wards": 3, "regen_period": 10.0, "doom_bypass": 1, "curse_threshold": 5, "regrowth_suppression": 100.0}
}

const UNLOCK_COSTS := {"fast": 90.0, "heavy": 180.0, "lantern": 140.0}

const DUNGEON_UNLOCK_COSTS := {"sentinel": 550.0, "ruin_knight": 1100.0, "sepulcher": 2000.0}

const ENEMY_SHARES := {"fast": 0.30, "heavy": 0.18, "lantern": 0.16}

const NORMAL_KINDS := ["basic", "fast", "heavy", "lantern"]

const DUNGEON_KINDS := ["shade", "sentinel", "ruin_knight", "sepulcher"]

const ORCHARD_KINDS := ["briarling", "veil_widow", "coffinbound"]

const ESCORT_KINDS := NORMAL_KINDS + DUNGEON_KINDS

# Per-type shared Enemy rules, separate from editable combat stats.
const ENEMY_RULES := {"heavy": {"escape_damage": 2}, "shade": {"escape_damage": 2}, "sentinel": {"escape_damage": 3}, "ruin_knight": {"escape_damage": 4}, "sepulcher": {"escape_damage": 5}}
