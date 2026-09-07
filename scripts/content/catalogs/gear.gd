extends RefCounted

# Stable legacy IDs remain first; each boss owns exactly three equipment types.
const GEAR := {
	"warden": {"name": "Warden’s Rootheart", "root_period": 6.0, "root_duration": 0.75, "boss_root_duration": 0.35, "root_immunity": 3.0},
	"cindermaw": {"name": "Ember Fang", "speed_per_stack": 8.0, "stack_limit": 5.0, "stack_timeout": 3.0},
	"bell": {"name": "Tollstone", "attack_count": 4.0, "echo_multiplier": 0.5, "echo_delay": 0.18},
	"prior": {"name": "Eclipse Shard", "attack_count": 5.0, "damage_multiplier": 1.5, "defense_bypass": 1.0},
	"warden_thornspindle": {"name": "Briar Thornspindle", "attack_count": 3.0, "dot_multiplier": 0.3, "duration": 4.0, "fire_damage": 0.0},
	"warden_lens": {"name": "Heartwood Lens", "damage_multiplier": 1.35},
	"cinder_censer": {"name": "Ashen Censer", "attack_count": 3.0, "dot_multiplier": 0.2, "duration": 3.0, "fire_damage": 1.0, "area_radius": 45.0},
	"cinder_crucible": {"name": "Crucible Seal", "attack_count": 4.0, "blast_radius": 52.0, "blast_multiplier": 1.25},
	"bell_chain": {"name": "Undertow Chain", "attack_count": 4.0, "push_distance": 28.0, "push_immunity": 2.0},
	"bell_chime": {"name": "Hush Chime", "attack_count": 6.0, "duration": 0.5, "boss_duration": 0.2, "stun_immunity": 3.0, "area_radius": 60.0},
	"prior_rosary": {"name": "Bloodmoon Rosary", "damage_per_stack": 5.0, "stack_limit": 5.0, "stack_timeout": 6.0},
	"prior_mirror": {"name": "Penumbral Mirror", "attack_count": 5.0, "fork_count": 2.0, "fork_radius": 90.0, "fork_multiplier": 0.45},
	"ruined_king": {"name": "Kingsbane Crown", "damage_multiplier": 1.4},
	"king_signet": {"name": "Siege Signet", "health_threshold": 90.0, "damage_multiplier": 1.8},
	"king_edge": {"name": "Executioner’s Edge", "health_threshold": 25.0, "damage_multiplier": 1.6},
	"mourning_matriarch": {"name": "Mourning Veil", "attack_count": 2.0, "slow_percent": 30.0, "duration": 2.0, "boss_duration": 1.0},
	"matriarch_fruit": {"name": "Pale Mourning Fruit", "attack_count": 4.0, "vulnerability_percent": 15.0, "duration": 3.0},
	"matriarch_lantern": {"name": "Wakekeeper’s Lantern", "range_percent": 20.0, "opening_attacks": 2.0, "opening_speed": 35.0, "reset_timeout": 4.0}
}

const PRESENTATION := {
	"warden": {"name": "Warden’s Rootheart", "boss": "warden", "symbol": "root", "color": "a9d58b", "description": "Every {root_period} seconds, a primary shot roots its target for {root_duration}s ({boss_root_duration}s for bosses). Root immunity lasts {root_immunity}s."},
	"cindermaw": {"name": "Ember Fang", "boss": "cindermaw", "symbol": "fang", "color": "ffa568", "description": "Repeated attacks on one target gain {speed_per_stack}% attack speed per stack, up to {stack_limit} stacks. Changing targets or pausing {stack_timeout}s resets them."},
	"bell": {"name": "Tollstone", "boss": "bell", "symbol": "bell", "color": "8ce3dc", "description": "Every {attack_count} attacks, echo the primary shot after {echo_delay}s for {echo_multiplier}× base damage. The echo retains its blast and triggers no other effects."},
	"prior": {"name": "Eclipse Shard", "boss": "prior", "symbol": "eclipse", "color": "d2adf3", "description": "Every {attack_count} attacks, the primary shot and its blast deal {damage_multiplier}× damage. {defense_text}"},
	"warden_thornspindle": {"name": "Briar Thornspindle", "boss": "warden", "symbol": "spindle", "color": "8aa970", "description": "Every {attack_count} attacks, wound the primary target for {dot_multiplier}× base shot damage per second for {duration}s as {damage_type}. Reapplying refreshes this tower’s wound."},
	"warden_lens": {"name": "Heartwood Lens", "boss": "warden", "symbol": "lens", "color": "c4d894", "description": "The primary shot and blast deal {damage_multiplier}× damage to enemies currently rooted, slowed or stunned."},
	"cinder_censer": {"name": "Ashen Censer", "boss": "cindermaw", "symbol": "censer", "color": "d8754f", "description": "Every {attack_count} attacks, scorch the ground within {area_radius} units of impact for {duration}s. Enemies inside take {dot_multiplier}× base shot damage per second as {damage_type}. This tower’s overlapping gear patches do not stack damage."},
	"cinder_crucible": {"name": "Crucible Seal", "boss": "cindermaw", "symbol": "seal", "color": "e6b16a", "description": "Every {attack_count} attacks, the primary blast radius becomes {blast_radius} units or {blast_multiplier}× its normal radius, whichever is larger. Enemies inside take normal shot damage."},
	"bell_chain": {"name": "Undertow Chain", "boss": "bell", "symbol": "chain", "color": "77b3bd", "description": "Every {attack_count} attacks, push the primary target back {push_distance} units along its road. Respects knockback resistance; immunity lasts {push_immunity}s."},
	"bell_chime": {"name": "Hush Chime", "boss": "bell", "symbol": "chime", "color": "acd6cf", "description": "Every {attack_count} attacks, stun enemies within {area_radius} units of impact for {duration}s ({boss_duration}s for bosses). Immunity lasts {stun_immunity}s."},
	"prior_rosary": {"name": "Bloodmoon Rosary", "boss": "prior", "symbol": "rosary", "color": "cd8199", "description": "Kills credited to this tower add {damage_per_stack}% primary-shot and blast damage per stack, up to {stack_limit} stacks. Each kill refreshes them; {stack_timeout}s without a kill resets them. Switching targets keeps the stacks."},
	"prior_mirror": {"name": "Penumbral Mirror", "boss": "prior", "symbol": "mirror", "color": "aa93db", "description": "Every {attack_count} attacks, send up to {fork_count} extra bolts to distinct enemies within {fork_radius} units of the primary target. Each deals {fork_multiplier}× base damage with no blast or extra effects."},
	"ruined_king": {"name": "Kingsbane Crown", "boss": "ruined_king", "symbol": "crown", "color": "cfbb80", "description": "The primary shot and its blast deal {damage_multiplier}× damage to bosses. Their defenses still apply."},
	"king_signet": {"name": "Siege Signet", "boss": "ruined_king", "symbol": "signet", "color": "b3aa91", "description": "The primary shot and its blast deal {damage_multiplier}× damage to targets at or above {health_threshold}% health on impact."},
	"king_edge": {"name": "Executioner’s Edge", "boss": "ruined_king", "symbol": "blade", "color": "b9b6ae", "description": "The primary shot and its blast deal {damage_multiplier}× damage to targets at or below {health_threshold}% health on impact."},
	"mourning_matriarch": {"name": "Mourning Veil", "boss": "mourning_matriarch", "symbol": "veil", "color": "c5c8ae", "description": "Every {attack_count} attacks, slow the primary target by {slow_percent}% for {duration}s ({boss_duration}s for bosses). The strongest slow applies."},
	"matriarch_fruit": {"name": "Pale Mourning Fruit", "boss": "mourning_matriarch", "symbol": "fruit", "color": "c9ca8a", "description": "Every {attack_count} attacks, expose the primary target for {duration}s, increasing damage from all towers by {vulnerability_percent}%. The strongest exposure applies."},
	"matriarch_lantern": {"name": "Wakekeeper’s Lantern", "boss": "mourning_matriarch", "symbol": "lantern", "color": "d7d1ae", "description": "Increase this tower’s attack range by {range_percent}%. Its targeting, range circle and displayed reach include the bonus."}
}

const ATTRIBUTES := {
	"warden": ["root"],
	"cindermaw": ["momentum_speed"],
	"bell": ["echo"],
	"prior": ["empower"],
	"warden_thornspindle": ["damage_over_time"],
	"warden_lens": ["hindered_damage"],
	"cinder_censer": ["ground_damage"],
	"cinder_crucible": ["blast"],
	"bell_chain": ["knockback"],
	"bell_chime": ["stun"],
	"prior_rosary": ["kill_momentum"],
	"prior_mirror": ["fork"],
	"ruined_king": ["boss_damage"],
	"king_signet": ["healthy_damage"],
	"king_edge": ["wounded_damage"],
	"mourning_matriarch": ["slow"],
	"matriarch_fruit": ["expose"],
	"matriarch_lantern": ["range_bonus"]
}

const BOSS_DROPS := {
	"warden": ["warden", "warden_thornspindle", "warden_lens"],
	"cindermaw": ["cindermaw", "cinder_censer", "cinder_crucible"],
	"bell": ["bell", "bell_chain", "bell_chime"],
	"prior": ["prior", "prior_rosary", "prior_mirror"],
	"ruined_king": ["ruined_king", "king_signet", "king_edge"],
	"mourning_matriarch": ["mourning_matriarch", "matriarch_fruit", "matriarch_lantern"]
}
