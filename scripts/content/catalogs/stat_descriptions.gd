extends RefCounted

## Player-facing explanations shared by every entity's selection catalog.
const Gear = preload("res://scripts/content/catalogs/gear.gd")
const FIELDS := {
"hp": "Damage this enemy can take before being defeated.",
"speed": "Distance the enemy travels along its road each second, before slows or haste.",
"payout": "Gold awarded when this enemy is defeated.",
"escape_damage": "Core health lost when this enemy reaches the end of its road.",
"damage": "Base damage of one tower hit before bonuses, enemy defenses and secondary effects.",
"period": "Seconds between attacks. A smaller interval means faster attacks.",
"range": "Maximum distance from the tower at which it can acquire targets.",
"cost": "Gold required to build this tower or purchase this upgrade tier.",
"splash": "Distance around an impact that receives blast damage. Zero disables the blast.",
"targets": "Maximum number of enemies selected in one attack cycle.",
"projectile_speed": "Distance a projectile travels each second; higher values shorten its flight where the attack uses travel time.",
"pierce_count": "Maximum enemies a projectile can hit on each pass. A returning blade counts outward and return passes separately.",
"pierce_loss": "Fraction of base damage lost after each pierced victim, bounded by the minimum pierce damage.",
"pierce_floor": "Lowest fraction of base damage a piercing bolt can retain after successive hits.",
"projectile_width": "Collision radius around the projectile path; a wider radius catches enemies farther from its center.",
"volley_count": "Parallel bolts fired per attack. An enemy can be hit only once by the same volley.",
"volley_spacing": "Distance between neighboring parallel bolts in a volley.",
"return_speed": "Multiplier on the returning blade's speed during its trip back to the tower.",
"trap_capacity": "Maximum number of this tower's traps that may remain deployed at once.",
"trap_duration": "Seconds a deployed trap remains before expiring unused.",
"trap_arm_time": "Seconds after deployment before a trap can trigger.",
"trap_count": "Number of traps deployed per attack cycle, subject to the stored-trap limit.",
"trap_radius": "Distance at which a nearby enemy triggers an armed trap.",
"duration": "Seconds poison remains on its target. Hits from the same tower refresh it without stacking.",
"dot_multiplier": "Poison damage each second as a multiple of base hit damage.",
"slow_percent": "Percentage removed from the target's movement speed before ice resistance. Repeated slows do not add together.",
"slow_duration": "Seconds the movement slow lasts after a hit; later hits refresh it.",
"burn_duration": "Seconds the burning ground remains after impact.",
"burn_multiplier": "Burning-ground damage each second as a multiple of hit damage; overlapping fire from one tower does not stack.",
"push_distance": "Distance the target is pushed backward along its road, reduced by knockback resistance.",
"push_immunity": "Seconds after a push during which the target cannot be pushed again.",
"fragment_count": "Maximum seeking fragments released on impact, each aimed at a different enemy other than the original target.",
"fragment_range": "Maximum distance from impact in which fragments can find other enemies.",
"fragment_multiplier": "Damage of each seeking fragment as a multiple of the original hit damage.",
"curse_limit": "Maximum curse stacks built by repeated hits on the same enemy; changing targets resets them.",
"curse_multiplier": "Additional fraction of hit damage granted by each focused-curse stack.",
"arc_range": "Distance from a struck enemy within which chain lightning can find an additional victim, even beyond tower range.",
"arc_multiplier": "Damage dealt by each secondary lightning arc as a multiple of hit damage.",
"seal_hits": "Hits from this tower required on a target to detonate a seal; the charge count then resets.",
"seal_damage": "Bonus damage from a charged-seal detonation as a multiple of hit damage.",
"stun_duration": "Seconds a seal detonation stops the target from moving, unless stun immunity is active.",
"stun_immunity": "Seconds during which the target cannot be stunned again after a stun.",
"vulnerability_percent": "Additional percentage of tower damage received by a marked target. Only the strongest mark applies, reduced by hex resistance.",
"mark_duration": "Seconds a hex mark increases incoming tower damage.",
"mark_spread_count": "Maximum nearby enemies marked when a directly marked enemy dies. Spread marks cannot spread again.",
"mark_spread_radius": "Maximum distance from a marked death within which its mark can spread.",
"aura_damage_percent": "Damage bonus for other towers within this tower's range. Only the strongest nearby aura applies.",
"boss_damage_multiplier": "Multiplier on this tower's damage against bosses, before their defenses.",
"shield": "Shield health that absorbs incoming damage before the enemy's health is reduced.",
"fire_multiplier": "Multiplier on fire damage against the shield; it does not multiply damage to health.",
"wards": "Number of incoming hits blocked completely by protective wards; each blocked hit consumes one ward.",
"doom_bypass": "When enabled, attacks with Focused curse pass through wards without consuming them.",
"regen_period": "Seconds between restoring assigned shields and wards to their configured amounts. Does not restore health.",
"regrowth_suppression": "Percentage by which sufficient curse stacks slow the defense-regrowth timer while their source tower remains in range.",
"curse_threshold": "Curse stacks needed from an in-range tower to suppress defense regrowth.",
"rage_threshold": "Health percentage at or below which haste replaces high-health armor.",
"haste_multiplier": "Movement-speed multiplier while health is at or below the wounded threshold.",
"armor_reduction": "Percentage of incoming damage blocked while health is above the wounded threshold, unless the hit bypasses defenses.",
"frost_multiplier": "Multiplier on damage received from attacks with Ice slow.",
"quench": "Percentage of the wounded haste bonus suppressed while the enemy is slowed.",
"toll_period": "Seconds between attempts to summon escorts.",
"escort_kind": "Enemy type spawned as an escort, using the numbered choices in this stat's title.",
"escort_count": "Escorts spawned per summon, limited by the living escort cap.",
"escort_limit": "Maximum living escorts allowed for this summoner at once.",
"seal_multiplier": "Charged-seal bonus damage received as a multiple of the attacking tower's hit damage.",
"toll_delay": "Seconds added to the next summon timer by a charged-seal detonation.",
"poison_resistance": "Percentage reduction to non-fire damage over time, including poison. At 100%, that damage is prevented.",
"ice_resistance": "Percentage reduction to movement-slow strength. At 100%, slows no longer reduce movement speed.",
"hex_resistance": "Percentage reduction to the extra damage granted by hex marks and exposure. Does not reduce the underlying hit damage.",
"push_resistance": "Percentage reduction to backward knockback distance. At 100%, the enemy cannot be pushed back."
}
const ABILITIES := {
"piercing_attack": "Fires straight bolts through multiple enemies, losing damage per victim down to a configured minimum. Parallel bolts cannot hit the same victim twice in one volley.",
"returning_attack": "Throws one blade outward and back, hitting each enemy once per leg up to the per-pass limit. Only one blade may fly at a time.",
"orbit_attack": "Three blades sweep nearby enemies once per attack interval. Each enemy takes one hit per sweep, not one per blade.",
"road_traps": "Deploys single-use traps on nearby roads, subject to a capacity limit. Traps need time to arm, expire if unused and never block movement.",
"frostneedle": "Hits slow the target for the configured duration. Repeated hits refresh the slow without stacking, and ice resistance reduces its strength.",
"thorn_volley": "Hits poison their target, dealing a fraction of hit damage each second for the configured duration. This tower refreshes its own poison without stacking it.",
"cinderfield": "Impacts leave burning ground that damages enemies inside each second. Overlapping fire from the same tower does not stack.",
"rupture_pyre": "Impacts push enemies backward along their road, reduced by knockback resistance. A temporary immunity prevents immediate repeated pushes.",
"grave_echo": "Impacts release seeking fragments toward distinct nearby enemies, excluding the original target. Each fragment deals a configured fraction of hit damage; unused fragments fade.",
"doomstone": "Consecutive hits on one enemy build stacks that increase this tower's damage against it. Changing targets resets the stacks.",
"tempest_web": "Each strike arcs to an additional distinct nearby enemy for a fraction of hit damage. Arcs can reach beyond the tower's normal range.",
"thunderseal": "Repeated hits from this tower charge a seal on the target, then detonate for bonus damage and a brief stun. Charges reset after detonation, and stun immunity prevents continuous lockdown.",
"vulnerability_mark": "Marks enemies to increase damage received from towers; only the strongest mark applies. If spread is configured, directly marked deaths pass the mark to nearby enemies, but spread marks never spread again.",
"damage_aura": "Increases the damage of other towers within this tower's range. Only the strongest overlapping aura applies; the source does not buff itself.",
"tower_boss_damage": "Multiplies this tower's damage against bosses. Boss defenses still apply.",
"shield": "Adds a shield that absorbs damage before health is lost. Fire damages the shield using its configured multiplier; restoring the shield requires Defense regrowth.",
"wards": "Blocks incoming hits completely, consuming one ward per blocked hit. Focused curse can bypass wards when that option is enabled; restoration requires Defense regrowth.",
"regrowth": "Periodically restores assigned shields and wards, without healing health. Sufficient curse stacks from an in-range tower slow or stop its regrowth timer.",
"rage": "Reduces incoming damage above the configured health threshold and grants movement haste at or below it. Ice-slow attacks have a configurable damage multiplier, and being slowed can suppress the haste bonus.",
"summon": "Periodically summons the selected enemy type up to a living escort limit. Charged seals can delay the next summon; summoned escorts cannot summon recursively."
}

const GEAR_FIELDS := {
"attack_count": "Number of attacks required to trigger the effect; fewer attacks activate it more often.",
"health_threshold": "Target health percentage checked at impact to decide whether the damage bonus applies.",
"damage_multiplier": "Multiplier applied to primary-shot and blast damage when this effect's condition is met.",
"duration": "Seconds the wound, ground patch, slow, stun or exposure lasts after activation.",
"boss_duration": "Effect duration in seconds against bosses, replacing the ordinary enemy duration.",
"root_period": "Seconds between primary shots that can apply this root effect.",
"root_duration": "Seconds an ordinary enemy is held in place by the root.",
"boss_root_duration": "Seconds a boss is held in place by the root.",
"root_immunity": "Seconds of protection against another root after one is applied.",
"speed_per_stack": "Attack-speed percentage added per repeated-target stack.",
"damage_per_stack": "Primary-shot and blast damage percentage added per kill stack.",
"stack_limit": "Maximum stacks this effect can accumulate on its owning tower.",
"stack_timeout": "Seconds without a qualifying attack or kill before the accumulated stacks reset.",
"echo_delay": "Seconds between the original shot and its delayed echo.",
"echo_multiplier": "Echo damage as a multiple of base shot damage; echoes trigger no other effects.",
"dot_multiplier": "Damage dealt each second as a multiple of base shot damage.",
"fire_damage": "One makes this effect's damage over time fire; zero makes it non-fire damage affected by poison resistance.",
"area_radius": "Distance from impact reached by this ground or area effect.",
"blast_radius": "Minimum blast radius granted when this effect activates.",
"blast_multiplier": "Multiplier on the shot's existing blast radius; the larger of this result and the minimum radius is used.",
"fork_count": "Maximum extra bolts sent to distinct secondary enemies when the effect activates.",
"fork_radius": "Maximum distance from the primary target in which extra bolts search for enemies.",
"fork_multiplier": "Each extra bolt's damage as a multiple of base shot damage, without blast or additional effects.",
"range_percent": "Percentage added to this tower's attack range, including targeting and its displayed range circle.",
"defense_bypass": "One lets the empowered shot bypass boss defenses; zero leaves those defenses active."
}

static func ability(stats, category: String, kind: String, id: String, tuning: Dictionary) -> String:
	if id.begins_with("gear_"):
		var gear_kind := id.trim_prefix("gear_")
		var values := {}
		for key in Gear.GEAR[gear_kind]:
			if key == "name": continue
			values[key] = stats.value(category, kind, id + "__" + key, tuning)
		values.damage_type = "fire damage" if values.get("fire_damage", 0) > 0 else "non-fire damage"
		values.defense_text = "This shot bypasses boss defenses." if values.get("defense_bypass", 0) > 0 else "Boss defenses still apply."
		return Gear.PRESENTATION[gear_kind].description.format(values)
	return ABILITIES.get(id, "") + (" Selecting this replaces the current primary attack." if stats.capabilities(category)[id].get("primary", false) else "")

static func field(stats, category: String, kind: String, id: String, tuning: Dictionary) -> String:
	if id.begins_with("gear_"):
		var owner := id.get_slice("__", 0)
		var label: String = stats.schema(category)[id].label.get_slice(" · ", 1)
		return str(GEAR_FIELDS.get(id.get_slice("__", 1), FIELDS.get(id.get_slice("__", 1), "Sets " + label.to_lower() + " for this effect."))) + " " + ability(stats, category, kind, owner, tuning)
	return FIELDS.get(id, "")
