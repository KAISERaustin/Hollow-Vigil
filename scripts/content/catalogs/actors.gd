extends RefCounted

const ENEMIES := {
	"ruin_knight": {"name": "Eclipse Knight", "role": "SANCTUARY · ELITE", "description": "An oathbound guardian in crescent-crowned armor. Bloodmoon Sanctuary portals summon this enduring knight beneath a crimson mantle.", "push_resistance": 50.0, "hp": 1200.0, "speed": 38.0, "payout": 95.0, "color": "ae879b"},
	"sepulcher": {"name": "Sepulcher Colossus", "role": "DUNGEON · COLOSSAL", "description": "A walking royal tomb crowned with ruined battlements. Castle ruin portals alone release this slow, immensely durable foe, whose stone bulk resists knockback.", "push_resistance": 90.0, "hp": 2200.0, "speed": 24.0, "payout": 165.0, "color": "99948c"},
	"basic": {"name": "Moss Hollow", "role": "FOREST · COMMON", "description": "A moss-draped wanderer with a cracked bone mask, drawn from the Forest's tangled roots. Its steady march gives new towers time to strike.", "push_resistance": 0.0, "hp": 45.0, "speed": 39.0, "payout": 5.0, "color": "95aa83"},
	"fast": {"name": "Bramble Wraith", "role": "FOREST · SWIFT", "description": "A leaf-crowned woodland spirit trailing thorn tendrils. This fragile Forest foe races along the roads toward the core.", "push_resistance": 0.0, "hp": 36.0, "speed": 74.0, "payout": 8.0, "color": "93c9bc"},
	"heavy": {"name": "Rootbound Revenant", "role": "FOREST · ROOTED", "description": "An ancient woodland husk wrapped in bark and heavy roots. Its slow, sturdy frame resists knockback and rewards heavy damage.", "push_resistance": 75.0, "hp": 340.0, "speed": 25.0, "payout": 24.0, "color": "95aa83"},
	"lantern": {"name": "Ember Keeper", "role": "FORGE · STEADFAST", "description": "A soot-robed furnace tender carrying a stolen ember. Ashen Forge portals harden its frame for a steady march through tower fire.", "push_resistance": 0.0, "hp": 120.0, "speed": 46.0, "payout": 14.0, "color": "bb8c76"},
	"cinder_imp": {"name": "Cinder Imp", "role": "FORGE · COMMON", "description": "A small horned coal creature with a glowing furnace belly. The first inhabitant to emerge from an Ashen Forge portal.", "push_resistance": 0.0, "hp": 45.0, "speed": 39.0, "payout": 5.0, "color": "db8d73"},
	"slag_golem": {"name": "Slag Golem", "role": "FORGE · DURABLE", "description": "A lumbering pile of blackened iron with an anvil-shaped head and molten seams. Its weight resists knockback.", "push_resistance": 75.0, "hp": 340.0, "speed": 25.0, "payout": 24.0, "color": "bb8c76"},
	"drowned_thrall": {"name": "Drowned Thrall", "role": "CRYPT · COMMON", "description": "A waterlogged pilgrim tangled in reeds and burial cloth. Drowned Crypt portals send it down the roads with a restless current at its back.", "push_resistance": 0.0, "hp": 45.0, "speed": 39.0, "payout": 5.0, "color": "7fa6aa"},
	"mire_wraith": {"name": "Mire Wraith", "role": "CRYPT · SWIFT", "description": "A thin, streaming ghost wearing a shell mask. Its trailing fins and torn shroud cut swiftly through the Drowned Crypt's mist.", "push_resistance": 0.0, "hp": 36.0, "speed": 74.0, "payout": 8.0, "color": "93c9bc"},
	"bell_hulk": {"name": "Bell Hulk", "role": "CRYPT · DURABLE", "description": "A sunken bronze bell carried by a hulking drowned body. Heavy chains and a sealed bell casing resist knockback.", "push_resistance": 75.0, "hp": 340.0, "speed": 25.0, "payout": 24.0, "color": "7fa6aa"},
	"blood_acolyte": {"name": "Blood Acolyte", "role": "SANCTUARY · COMMON", "description": "A crimson-robed worshipper carrying a crescent staff. The Bloodmoon Sanctuary restores its wounds throughout its journey.", "push_resistance": 0.0, "hp": 45.0, "speed": 39.0, "payout": 5.0, "color": "ae879b"},
	"crescent_wisp": {"name": "Crescent Wisp", "role": "SANCTUARY · SWIFT", "description": "A floating crescent shrine with a veiled red eye and long prayer ribbons. Its slight form moves quickly beneath the blood moon.", "push_resistance": 0.0, "hp": 36.0, "speed": 74.0, "payout": 8.0, "color": "c4b6b1"},
	"shade": {"name": "Abyss Shade", "role": "DUNGEON · SWIFT", "description": "A swift shadow born only in castle ruin portals. Its dense shroud withstands sustained fire.", "push_resistance": 0.0, "hp": 240.0, "speed": 56.0, "payout": 30.0, "color": "9182ad"},
	"sentinel": {"name": "Crypt Sentinel", "role": "DUNGEON · ARMORED", "description": "A dark iron guardian summoned only by castle ruin portals. A deep health pool guards a rich bounty.", "push_resistance": 0.0, "hp": 680.0, "speed": 28.0, "payout": 55.0, "color": "74798c"},
	"briarling": {"name": "Briarling", "role": "ORCHARD · SWIFT", "description": "A bone-faced thornling that darts from the Mourning Orchard’s portals. Fast attacks and slowing needles catch its fragile wooden frame.", "push_resistance": 0.0, "hp": 85.0, "speed": 86.0, "payout": 13.0, "color": "b9bd8a"},
	"veil_widow": {"name": "Veil Widow", "role": "ORCHARD · ENDURING", "description": "A mourning spirit in a split burial veil, born only through the Orchard portal. Its steady pace and dense shroud reward sustained fire.", "push_resistance": 25.0, "hp": 260.0, "speed": 43.0, "payout": 28.0, "color": "c4b6b1"},
	"coffinbound": {"name": "Coffinbound", "role": "ORCHARD · ROOTED", "description": "A walking coffin lashed shut with pale roots. Only the Orchard portal releases it. Slow, durable, and resistant to knockback; heavy damage breaks its shell.", "push_resistance": 90.0, "hp": 820.0, "speed": 22.0, "payout": 64.0, "color": "a5aa73"}
}

const BOSS_PRESENTATION := {"ruined_king": {"sound_family": "prior"}, "mourning_matriarch": {"sound_family": "warden"}}

const BOSSES := {
	"ruined_king": {"name": "The Ruined King", "description": "The fallen sovereign of Castle Ruin, enthroned in shattered masonry beneath a broken crown. Slow and immensely durable, his stone body resists knockback.", "push_resistance": 90.0, "hp": 4200.0, "speed": 23.0, "payout": 550.0, "color": "99948c", "weakness": "Sustained heavy damage breaks his stone body"},
	"mourning_matriarch": {"name": "The Mourning Matriarch", "description": "A veiled orchard spirit rising from a rootbound coffin, crowned with pale fruit and funeral boughs. Her relentless procession rewards slowing attacks and focused fire.", "push_resistance": 50.0, "hp": 3400.0, "speed": 29.0, "payout": 500.0, "color": "a5aa73", "weakness": "Slowing attacks extend the time available for focused fire"},
	"warden": {"name": "Briarbound Warden", "push_resistance": 0.0, "hp": 3200.0, "speed": 27.0, "payout": 450.0, "color": "95aa83", "weakness": "Cinderfield: double root shield damage", "shield": 600.0, "regen_period": 10.0, "fire_multiplier": 2.0, "regrowth_suppression": 100.0},
	"cindermaw": {"name": "The Cinder Reliquary", "push_resistance": 0.0, "hp": 3600.0, "speed": 25.0, "payout": 500.0, "color": "db8d73", "weakness": "Frostneedle: +50% damage; quenches haste", "rage_threshold": 50.0, "haste_multiplier": 1.7, "armor_reduction": 30.0, "frost_multiplier": 1.5, "quench": 100.0},
	"bell": {"escort_kind": 0, "name": "The Drowned Bell", "push_resistance": 0.0, "hp": 2800.0, "speed": 32.0, "payout": 450.0, "color": "93c9bc", "weakness": "Thunderseal: stronger seals; delays tolls", "toll_period": 8.0, "escort_count": 3, "escort_limit": 6, "seal_multiplier": 4.5, "toll_delay": 2.0},
	"prior": {"name": "The Eclipse Prior", "push_resistance": 0.0, "hp": 3000.0, "speed": 30.0, "payout": 500.0, "color": "b49dcc", "weakness": "Doomstone: bypasses wards; curses regrowth", "wards": 3, "regen_period": 10.0, "doom_bypass": 1, "curse_threshold": 5, "regrowth_suppression": 100.0}
}




const NORMAL_KINDS := ["basic", "fast", "heavy"]

const DUNGEON_KINDS := ["shade", "sentinel", "sepulcher"]

const ORCHARD_KINDS := ["briarling", "veil_widow", "coffinbound"]

# Stable authored mission IDs and numeric boss escort slots predate portal rosters.
const CAMPAIGN_KINDS := ["basic", "fast", "heavy", "lantern", "shade", "sentinel", "ruin_knight", "sepulcher"]
const ESCORT_KINDS := CAMPAIGN_KINDS

# Each family inherits Enemy once; every shipped enemy belongs to exactly one.
const FAMILIES := {
	"forest": NORMAL_KINDS,
	"ashen_forge": ["cinder_imp", "lantern", "slag_golem"],
	"drowned_crypt": ["drowned_thrall", "mire_wraith", "bell_hulk"],
	"bloodmoon_sanctuary": ["blood_acolyte", "crescent_wisp", "ruin_knight"],
	"castle_ruin": DUNGEON_KINDS,
	"mourning_orchard": ORCHARD_KINDS
}

# Presentation assets are assigned independently of stats and mutable instances.
const PRESENTATION := {
	"cinder_imp": {"art": "themed", "death_cue": "death_lantern"},
	"slag_golem": {"art": "themed", "death_cue": "death_heavy"},
	"drowned_thrall": {"art": "themed", "death_cue": "death_basic"},
	"mire_wraith": {"art": "themed", "death_cue": "death_fast"},
	"bell_hulk": {"art": "themed", "death_cue": "death_sentinel"},
	"blood_acolyte": {"art": "themed", "death_cue": "death_lantern"},
	"crescent_wisp": {"art": "themed", "death_cue": "death_shade"}
}

# Per-type shared Enemy rules, separate from editable combat stats.
const ENEMY_RULES := {"heavy": {"escape_damage": 2}, "shade": {"escape_damage": 2}, "sentinel": {"escape_damage": 3}, "ruin_knight": {"escape_damage": 4}, "sepulcher": {"escape_damage": 5}}
