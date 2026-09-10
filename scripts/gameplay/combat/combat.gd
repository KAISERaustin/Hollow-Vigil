class_name VigilCombat
extends RefCounted
const EnemyCapabilities = preload("res://scripts/gameplay/combat/enemy_capabilities.gd")
const StatComposition = preload("res://scripts/gameplay/combat/stat_composition.gd")

const ShotFactory = preload("res://scripts/gameplay/combat/shot_factory.gd")

signal sound_requested(cue: String, position: Vector2)
signal enemy_escaped(enemy: Dictionary)

const Targeting = preload("res://scripts/gameplay/combat/targeting.gd")
const Projectiles = preload("res://scripts/gameplay/combat/projectiles.gd")
const TowerAbilities = preload("res://scripts/gameplay/combat/tower_abilities.gd")
const EffectFields = preload("res://scripts/gameplay/combat/effect_fields.gd")
const TowerComponents = preload("res://scripts/gameplay/combat/tower_components.gd")
const LineProjectiles = preload("res://scripts/gameplay/combat/line_projectiles.gd")
const RoadTraps = preload("res://scripts/gameplay/combat/road_traps.gd")

const Relics = preload("res://scripts/gameplay/progression/relics.gd")
const Bosses = preload("res://scripts/gameplay/encounters/bosses.gd")

var data: Dictionary
var tuning: Dictionary:
	get: return data.settings.get("developer_balance", {})
var economy: VigilEconomy
var paths: Dictionary
var route_exits: Dictionary = {}
var branching_routes: Dictionary = {}
var enemies: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var pending_shots: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var simulation_time := 0.0
var enemy_serial := 0
var tick_count := 0
var enemy_pool: Array[Dictionary] = []
var burning_ground: Array[Dictionary] = []
var effect_fields: Array[Dictionary] = []
var curses: Dictionary = {}
var relic_progress: Dictionary = {}
var relic_epochs: Dictionary = {}
var relic_drops: Array[String] = []
# Runtime IDs avoid retaining pooled enemy dictionaries or saving stale locks.
var target_locks: Dictionary = {}
var enemy_index := preload("res://scripts/gameplay/combat/enemy_index.gd").new()
var spatial_ready := false
var indexed_enemy_count := -1
var ticking := false
# Authored missions own their spawn schedule; ordinary worlds keep rift timers.
var scripted_spawns := true
var road_geometry := preload("res://scripts/gameplay/combat/road_geometry.gd").new()
var authored_roads: Array = []:
	set(value):
		authored_roads = value
		road_geometry.rebuild(authored_roads if scripted_spawns else paths.values())
var tower_overrides: Dictionary = {}
var tower_component_state: Dictionary = {}
var component_serial := 0
var line_projectiles: Array[Dictionary] = []
var traps: Array[Dictionary] = []
var route_cache := preload("res://scripts/gameplay/combat/route_cache.gd").new()
var configuration := preload("res://scripts/gameplay/combat/configuration_cache.gd").new()
var configuration_active := false

func resolved_definition(category: String, kind: String) -> Dictionary:
	if not configuration_active: configuration.synchronize(tuning, data.relics)
	return configuration.definition(category, kind)

func tower_stats(tower: Dictionary) -> Dictionary:
	if not configuration_active: configuration.synchronize(tuning, data.relics)
	var stats := configuration.tower_stats(tower).duplicate(true)
	TowerComponents.apply_auras(self, tower, stats)
	return stats

func tower_aura_bonus(tower: Dictionary) -> float:
	if not configuration_active: configuration.synchronize(tuning, data.relics)
	return TowerComponents.aura_bonus(self, tower)

func enemy_identifiers() -> Dictionary:
	if not ticking: rebuild_enemy_index()
	return enemy_index.identifiers

func set_enemy_route(enemy: Dictionary, route: Array) -> void:
	route_cache.assign(enemy, route)

func launch_line_attack(tower: Dictionary, origin: Vector2, target: Dictionary, stats: Dictionary, returning: bool) -> void:
	LineProjectiles.launch(self, tower, origin, target, stats, returning)

func can_deploy_road_traps(tower: Dictionary, origin: Vector2, stats: Dictionary) -> bool:
	return not RoadTraps.positions(self, tower, origin, {}, stats).is_empty()

func deploy_road_traps(tower: Dictionary, origin: Vector2, target: Dictionary, stats: Dictionary) -> void:
	RoadTraps.deploy(self, tower, origin, target, stats)

func rebuild_enemy_index() -> void:
	enemy_index.rebuild(enemies)
	indexed_enemy_count = enemies.size()
	spatial_ready = true

func nearby_enemies(pos: Vector2, radius: float) -> Array[Dictionary]:
	# Standalone combat helpers also support editor/test changes between calls.
	if not ticking:
		rebuild_enemy_index()
	return enemy_index.query_radius(pos, radius)

func visible_enemies(view: Rect2) -> Array[Dictionary]:
	if not spatial_ready or indexed_enemy_count != enemies.size():
		rebuild_enemy_index()
	return enemy_index.query_rect(view)

func _init(shared_data: Dictionary, transactions: VigilEconomy, shared_paths: Dictionary) -> void:
	data = shared_data
	economy = transactions
	economy.relic_changed.connect(clear_relic_progress)
	economy.tower_changed.connect(clear_tower_components)
	paths = shared_paths
	rng.randomize()

func rebuild_routes() -> void:
	paths.clear()
	branching_routes.clear()
	route_exits.clear()
	road_geometry.rebuild(authored_roads)

func hit(enemy: Dictionary, damage: float, tower_id: String, branch: String = "", fire: bool = false, pierce: bool = false, damage_type: String = "") -> bool:
	if enemy.dead or not is_finite(damage) or damage <= 0.0 or not data.towers.has(tower_id):
		return false
	damage *= 1.0 + Relics.strength(enemy, "expose", simulation_time) * EnemyCapabilities.resistance(enemy, "hex_resistance", tuning) / 100.0
	var tags: Array = [branch]
	var owner: Dictionary = data.towers[tower_id]
	if damage_type.is_empty(): damage_type = "fire" if fire else Balance.Content.tower(owner.kind).rule("damage_type", "physical")
	for ability in ["frostneedle", "doomstone", "thunderseal"]:
		if Balance.Stats.ability_enabled("towers", Balance.tier_key(owner.kind, owner.level, owner.get("branch", "")), ability, tuning): tags.append(ability)
	var protection: float = enemy.get("shield", 0.0) + enemy.get("wards", 0)
	var portal = Balance.Content.portal(enemy.get("portal_effect_style", enemy.get("rift_style", "forest")))
	if portal != null and not pierce: damage = portal.incoming_damage(damage, tuning)
	if portal != null and damage_type == "electric": damage *= portal.resistance("electric_resistance", tuning)
	damage = EnemyCapabilities.damage(enemy, damage, tags, fire, tuning, pierce)
	if enemy.get("boss", false):
		if protection > 0.0 and enemy.get("shield", 0.0) + enemy.get("wards", 0) <= 0.0:
			sound_requested.emit("boss_" + enemy.kind + "_break", enemy.pos)
	enemy.hp -= damage
	if enemy.hp > 0.0:
		return false
	# Mark dead synchronously before any credit, so splash and simultaneous shots are safe.
	enemy.dead = true
	TowerComponents.killed(self, enemy)
	Relics.credited_kill(self, tower_id)
	TowerComponents.credited_kill(self, tower_id)
	sound_requested.emit(Balance.Content.boss(enemy.kind).sound_cue("death") if enemy.get("boss", false) else Balance.Content.enemy(enemy.kind).rule("death_cue"), enemy.pos)
	var is_boss: bool = enemy.get("boss", false)
	var reward: float = Balance.tuned_value("bosses", enemy.kind, "payout", tuning) if is_boss else Balance.tuned_value("enemies", enemy.kind, "payout", tuning)
	reward = float(enemy.get("campaign_payout", reward))
	if enemy.has("summoner"):
		reward = 0.0
	if is_boss:
		Bosses.record(self, enemy.source).boss = {"status": "defeated", "kind": enemy.kind}
		var drops := Relics.award_set(data, enemy.get("drop_source", enemy.source), enemy.kind)
		for index in range(drops.size()):
			var gear_kind: String = drops[index]
			relic_drops.append(gear_kind)
			add_effect({"kind": "relic_drop", "relic_kind": gear_kind, "pos": enemy.pos + Vector2((index - 1) * 28, 0), "life": 2.0, "max_life": 2.0, "color": Relics.DEFINITIONS[gear_kind].color})
	economy.credit(tower_id, reward)
	data.kills += 1.0
	# Encounter rewards remain separate from ordinary enemy earnings.
	if not is_boss and not enemy.has("summoner"):
		var r: Dictionary = data.regions[enemy.source]
		r.history[tower_id] = r.history.get(tower_id, 0.0) + reward
	add_effect({"kind": "death", "pos": enemy.pos, "life": 0.45, "max_life": 0.45, "color": Bosses.DEFINITIONS[enemy.kind].color if is_boss else Balance.ENEMIES[enemy.kind].color})
	return true

func add_effect(fx: Dictionary) -> void:
	if effects.size() < 100:
		effects.append(fx)

func spawn_on_path(kind: String, route: Array[Vector2], style: String = "forest") -> Dictionary:
	var enemy_type := Balance.Content.enemy(kind)
	if not scripted_spawns or enemy_type == null or not enemy_type.rule("authored_paths", false) or route.size() < 2:
		return {}
	return _create_enemy("0,0", kind, route, style)

func _create_enemy(id: String, kind: String, route: Array[Vector2], style: String) -> Dictionary:
	enemy_serial += 1
	var e: Dictionary = enemy_pool.pop_back() if not enemy_pool.is_empty() else {}
	var multiplier := rift_health_multiplier({"rift_style": style})
	Balance.Content.enemy(kind).create_into(e, enemy_serial, id, route, style, tuning, multiplier)
	EnemyCapabilities.initialize(e, tuning)
	set_enemy_route(e, route)
	enemies.append(e)
	spatial_ready = false
	return e

func rift_health_multiplier(enemy: Dictionary) -> float:
	return Balance.rift_health_multiplier(enemy.get("rift_style", "forest"), tuning)

func advance_effects(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	for fx in effects:
		fx.life -= delta
	effects = effects.filter(func(fx): return fx.life > 0.0)

func enemy_speed(enemy: Dictionary) -> float:
	if enemy.get("stun_until", 0.0) > simulation_time or enemy.get("root_until", 0.0) > simulation_time or Relics.strength(enemy, "stun", simulation_time) > 0.0:
		return 0.0
	var speed: float = resolved_definition(EnemyCapabilities.category(enemy), enemy.kind).speed
	if enemy.get("rift_style", "forest") == "drowned_crypt": speed *= 1.0 + resolved_definition("rifts", "drowned_crypt").strength / 100.0
	var slow := Relics.strength(enemy, "slow", simulation_time)
	if enemy.get("slow_until", 0.0) > simulation_time: slow = maxf(slow, enemy.get("slow_percent", 25.0))
	slow *= EnemyCapabilities.resistance(enemy, "ice_resistance", tuning)
	speed *= EnemyCapabilities.speed(enemy, simulation_time, tuning, slow)
	return speed * (1.0 - slow / 100.0)

func tick(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	# Age existing effects first so a fresh projectile starts at its muzzle.
	configuration.synchronize(tuning, data.relics)
	configuration.prune(data.towers)
	configuration_active = true
	advance_effects(delta)
	simulation_time += delta
	data.active_seconds += delta
	tick_count += 1
	TowerComponents.sync(self)
	Bosses.advance(self, delta)
	EnemyCapabilities.advance(self, delta)
	Relics.advance(self, delta)
	for e in enemies:
		if e.dead:
			continue
		var portal = Balance.Content.portal(e.get("portal_effect_style", e.get("rift_style", "forest")))
		if portal != null: portal.advance_enemy(e, delta, tuning)
		var move := enemy_speed(e) * delta
		if e.get("rift_style", "forest") == "bloodmoon_sanctuary":
			e.hp = minf(e.max_hp, e.hp + e.max_hp * Balance.rift_strength("bloodmoon_sanctuary", tuning) / 100.0 * delta)
		var p: Array = e.path
		while move > 0.0 and not e.dead:
			var dist: float = e.pos.distance_to(p[e.segment])
			if move >= dist:
				e.pos = p[e.segment]
				e.segment += 1
				move -= dist
				if e.segment >= p.size():
					e.dead = true
					sound_requested.emit(Balance.Content.boss(e.kind).sound_cue("escape") if e.get("boss", false) else "escape", e.pos)
					if e.get("boss", false):
						Bosses.record(self, e.source).boss = {"status": "escaped", "kind": e.kind}
					data.escapes += 1.0
					enemy_escaped.emit(e)
					add_effect({"kind": "escape", "pos": e.pos, "life": 0.55, "max_life": 0.55, "color": "9bddd8"})
			else:
				e.pos = e.pos.move_toward(p[e.segment], move)
				move = 0.0
	# Build once after movement; knockback updates bucket membership immediately.
	rebuild_enemy_index()
	ticking = true
	for e in enemies:
		if not e.dead:
			e.distance_remaining = -1.0
	# Resolve arrivals at the same centers used by targeting and drawing.
	EffectFields.advance(self, delta)
	TowerComponents.advance(self, delta)
	advance_shots(delta)
	advance_fire(delta)
	var live_targets := enemy_index.identifiers
	for tower_id in target_locks.keys():
		var locked: Dictionary = live_targets.get(target_locks[tower_id], {})
		if not data.towers.has(tower_id) or locked.is_empty() or locked.dead:
			target_locks.erase(tower_id)
			continue
		var tower: Dictionary = data.towers[tower_id]
		if not Balance.Content.locks_target(tower.get("target_mode", "first")):
			target_locks.erase(tower_id)
			continue
		var radius: float = tower_stats(tower).range
		if VigilWorld.pad_position(tower.region, tower.pad).distance_squared_to(locked.pos) > radius * radius:
			target_locks.erase(tower_id)
	for t in data.towers.values():
		if t.get("rebuild_remaining", 0.0) > 0.0:
			t.rebuild_remaining = maxf(0.0, t.rebuild_remaining - delta)
			if t.rebuild_remaining <= 0.0:
				sound_requested.emit("menu_ready", VigilWorld.pad_position(t.region, t.pad))
			continue
		t.cooldown = maxf(0.0, t.cooldown - delta)
		# Decimal tier intervals can leave tiny positive floating-point residue.
		# Do not turn a 0.40-second attack into a 0.45-second attack.
		if t.cooldown > 0.000001:
			continue
		var stats := tower_stats(t)
		var pos := VigilWorld.pad_position(t.region, t.pad)
		var attack := TowerComponents.attack_entry(self, t, stats)
		if not attack.is_empty():
			stats = attack.config
			if not attack.component.ready(self, t, pos, stats): continue
		var candidates := nearby_enemies(pos, stats.range)
		var target: Dictionary = live_targets.get(target_locks.get(t.id, -1), {})
		# Earlier towers can defeat a locked enemy during this same tick.
		if target.is_empty() or target.dead or pos.distance_squared_to(target.pos) > stats.range * stats.range:
			target = select_target(candidates, pos, stats.range, t.get("target_mode", "first"))
		if target.is_empty():
			if attack.is_empty() or not attack.component.has_method("allows_empty_target") or not attack.component.allows_empty_target(): continue
			target = {"id": -1, "pos": pos, "dead": false}
		var voice: String = t.get("branch", "")
		if voice.is_empty():
			voice = t.kind
		sound_requested.emit("shot_" + voice, pos)
		if target.id >= 0 and Balance.Content.locks_target(t.get("target_mode", "first")):
			target_locks[t.id] = target.id
		stats = Relics.prepare(self, t, target, stats)
		stats = TowerComponents.prepare_attributes(self, t, target, stats)
		t.cooldown = stats.period
		t.angle = pos.angle_to_point(target.pos)
		if not attack.is_empty():
			attack.component.attack(self, t, pos, {} if target.id == -1 else target, stats)
			continue
		if t.kind == "electric":
			# A new pulse replaces this tower's previous connections, even when
			# developer tuning makes attacks faster than the lightning fade.
			effects = effects.filter(func(fx): return not (fx.kind == "shot" and fx.get("tower_id", "") == t.id and fx.tower_kind == "electric"))
		if stats.get("targets", 1) > 1 or StatComposition.has(t, "tempest_web", tuning):
			# Pick distinct enemies in priority order before damage changes HP scores.
			var victims: Array[Dictionary] = [target]
			candidates.erase(target)
			for index in range(1, int(stats.targets)):
				var extra := select_target(candidates, pos, stats.range, t.get("target_mode", "first"))
				if extra.is_empty():
					break
				victims.append(extra)
				candidates.erase(extra)
			var used: Array = victims.map(func(e): return e.id)
			for victim in victims:
				launch_shot(t, pos, victim, stats, victim.id == target.id)
				if StatComposition.has(t, "tempest_web", tuning):
					for other in nearby_enemies(victim.pos, stats.arc_range):
						if not other.dead and other.id not in used and victim.pos.distance_to(other.pos) <= stats.arc_range:
							used.append(other.id)
							var arc := ShotFactory.shot("electric", victim.pos + Vector2(0, 29), other.pos, stats, other.id)
							arc.tower_id = t.id
							add_effect(arc)
							hit(other, stats.damage * stats.arc_multiplier, t.id, "tempest_web", false, false, "electric")
							break
			continue
		launch_shot(t, pos, target, stats)
	recycle_dead_enemies()
	indexed_enemy_count = enemies.size()
	ticking = false
	configuration_active = false
	if data.automation:
		economy.collect()

func launch_shot(tower: Dictionary, origin: Vector2, target: Dictionary, stats: Dictionary, primary: bool = true) -> void:
	Projectiles.launch_shot(self, tower, origin, target, stats, primary)

func advance_shots(delta: float) -> void:
	Projectiles.advance_shots(self, delta)

func resolve_shot(shot: Dictionary, target: Dictionary) -> void:
	Projectiles.resolve_shot(self, shot, target)

func distance_remaining(enemy: Dictionary) -> float:
	return Targeting.distance_remaining(enemy)

func select_target(candidates: Array, pos: Vector2, radius: float, mode: String) -> Dictionary:
	return Targeting.select_target(candidates, pos, radius, mode)

func recycle_dead_enemies() -> void:
	# Refresh after movement and attacks, before a dead dictionary can be reused.
	# Rendering uses these same enemy centers, so shots and impacts stay aligned.
	var targets := enemy_identifiers()
	for fx in effects:
		if fx.kind != "shot" or not fx.has("target_id"):
			continue
		var target: Dictionary = targets.get(fx.target_id, {})
		if not target.is_empty():
			fx.pos = target.pos
		if target.is_empty() or target.dead:
			fx.erase("target_id")
	var live: Array[Dictionary] = []
	for e in enemies:
		if not e.dead:
			live.append(e)
		else:
			enemy_index.remove(e)
			if enemy_pool.size() < 128:
				e.erase("_route_geometry")
				e.path = []
				enemy_pool.append(e)
	enemies = live
	if tick_count % 128 == 0: route_cache.prune()

# Branch state is transient: tower identity owns curses, enemy identity owns seals.
func branch_hit(shot: Dictionary, enemy: Dictionary) -> void:
	TowerAbilities.branch_hit(self, shot, enemy)

func push_back(enemy: Dictionary, distance: float) -> void:
	TowerAbilities.push_back(self, enemy, distance)

func ignite(shot: Dictionary) -> void:
	TowerAbilities.ignite(self, shot)

func advance_fire(delta: float) -> void:
	TowerAbilities.advance_fire(self, delta)

func launch_fragments(shot: Dictionary) -> void:
	Projectiles.launch_fragments(self, shot)

func advance_arrow(shot: Dictionary, delta: float, flying: Array[Dictionary]) -> void:
	Projectiles.advance_arrow(self, shot, delta, flying)

func clear_relic_progress(id: String) -> void:
	configuration.synchronize(tuning, data.relics)
	configuration.towers.erase(id)
	Relics.clear(self, id)
	TowerComponents.clear(self, id)

func set_tower_definition(id: String, definition) -> bool:
	return TowerComponents.set_definition(self, id, definition)

func clear_tower_components(id: String) -> void:
	configuration.towers.erase(id)
	TowerComponents.clear(self, id)

## Planning advances only preparable tower components, never enemies or income.
func prepare_defenses(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0: return
	simulation_time += delta
	TowerComponents.sync(self)
	for tower in data.towers.values():
		if tower.get("rebuild_remaining", 0.0) > 0.0: continue
		var stats := tower_stats(tower)
		var entry := TowerComponents.attack_entry(self, tower, stats)
		if entry.is_empty() or not entry.component.has_method("allows_empty_target"): continue
		stats = entry.config
		tower.cooldown = maxf(0.0, tower.cooldown - delta)
		var origin := VigilWorld.pad_position(tower.region, tower.pad)
		if tower.cooldown <= 0.000001 and entry.component.ready(self, tower, origin, stats):
			stats = Relics.prepare(self, tower, {"id": -1}, stats)
			stats = TowerComponents.prepare_attributes(self, tower, {"id": -1}, stats)
			entry.component.attack(self, tower, origin, {}, stats)
			tower.cooldown = stats.period
	preload("res://scripts/gameplay/combat/road_traps.gd").advance(self)
