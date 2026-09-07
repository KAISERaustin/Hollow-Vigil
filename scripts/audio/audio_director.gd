extends Node
## Presentation only: never consumes gameplay RNG or feeds back into simulation.
const DEFAULTS := {"master": 0.8, "menu": 0.8, "towers": 0.65, "enemies": 0.4, "bosses": 0.75, "music": 0.5}
const LIMITS := {"menu": 3, "towers": 6, "enemies": 2, "bosses": 3}
const CATEGORY_GAPS := {"menu": 0.025, "towers": 0.0, "enemies": 0.22, "bosses": 0.12}
const CATALOG: Dictionary = preload("res://assets/audio/catalog.json").data
var app: Control
var streams: Dictionary = {}
var voices: Dictionary = {}
var last_cue: Dictionary = {}
var last_category: Dictionary = {}
var music: AudioStreamPlayer
var elapsed := 0.0
var suspended := false
var accepted_events := 0
var bus_name: StringName
var master_bus_name: StringName
var combat: VigilCombat
var pitch_rng := RandomNumberGenerator.new()
var economy: VigilEconomy

func _ready() -> void:
	pitch_rng.randomize()
	# A private mix bus prevents independent app instances from sharing settings.
	bus_name = StringName("VigilAudio_" + str(get_instance_id()))
	master_bus_name = StringName(str(bus_name) + "_Master")
	AudioServer.add_bus()
	AudioServer.set_bus_name(AudioServer.bus_count - 1, master_bus_name)
	AudioServer.set_bus_send(AudioServer.bus_count - 1, &"Master")
	AudioServer.add_bus()
	var bus := AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus, bus_name)
	AudioServer.set_bus_send(bus, master_bus_name)
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = -1.0
	AudioServer.add_bus_effect(bus, limiter)
	for cue in CATALOG:
		streams[cue] = load_stream(cue)
	for category in LIMITS:
		voices[category] = []
		for index in range(LIMITS[category]):
			var player := AudioStreamPlayer.new()
			player.bus = bus_name
			add_child(player)
			voices[category].append(player)
	music = AudioStreamPlayer.new()
	if streams.get("lantern_watch") is AudioStreamWAV:
		var loop: AudioStreamWAV = streams.lantern_watch.duplicate()
		loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
		loop.loop_begin = 0
		loop.loop_end = roundi(loop.get_length() * loop.mix_rate)
		music.stream = loop
	music.bus = bus_name
	add_child(music)
	bind_game()
	apply_mix()
	if music.stream != null:
		music.play()
	app.field.picked.connect(func(_region, _pad): play("menu_select"))
	app.field.core_picked.connect(func(): play("menu_open"))
	app.field.entrance_picked.connect(func(_region): play("menu_open"))
	app.field.expansion_picked.connect(func(_region): play("menu_open"))
	get_tree().node_added.connect(observe_control)
	for node in app.find_children("*", "BaseButton", true, false):
		observe_control(node)
	for node in app.find_children("*", "Slider", true, false):
		observe_control(node)

func load_stream(cue: String) -> AudioStream:
	var path := "res://assets/audio/" + cue + ".wav"
	return load(path) as AudioStream if ResourceLoader.exists(path) else null

func bind_game() -> void:
	if combat != null and combat.sound_requested.is_connected(play_game_sound):
		combat.sound_requested.disconnect(play_game_sound)
	if economy != null and economy.sound_requested.is_connected(play_game_sound):
		economy.sound_requested.disconnect(play_game_sound)
	combat = app.game.combat
	economy = app.game.economy
	combat.sound_requested.connect(play_game_sound)
	economy.sound_requested.connect(play_game_sound)
	stop_effects()
	last_cue.clear()
	last_category.clear()
	apply_mix()

func play_game_sound(cue: String, position: Vector2) -> void:
	# Transactions use INF but still belong to the world that produced them.
	# Direct UI cues and settings previews intentionally have no world owner.
	play(cue, position, app.field)

func preferences() -> Dictionary:
	return app.game.data.settings.get("audio", {})

func volume(category: String) -> float:
	return float(preferences().get(category, DEFAULTS.get(category, 1.0)))

func set_volume(category: String, value: float) -> void:
	if not DEFAULTS.has(category) or not is_finite(value):
		return
	if not app.game.data.settings.has("audio"):
		app.game.data.settings.audio = {}
	app.game.data.settings.audio[category] = clampf(value, 0.0, 1.0)
	apply_mix()

func set_muted(value: bool) -> void:
	if not app.game.data.settings.has("audio"):
		app.game.data.settings.audio = {}
	app.game.data.settings.audio.muted = value
	apply_mix()

func gain(category: String) -> float:
	if suspended or preferences().get("muted", false):
		return 0.0
	# Quiet deaths and underscoring leave space for weapon identities and UI.
	var trim: float = {"music": 0.35, "enemies": 0.6, "menu": 0.8}.get(category, 1.0)
	return 0.55 * trim * volume(category)

func apply_mix() -> void:
	var master := AudioServer.get_bus_index(master_bus_name)
	if master > 0:
		AudioServer.set_bus_volume_db(master, linear_to_db(volume("master")))
		AudioServer.set_bus_mute(master, suspended or preferences().get("muted", false) or volume("master") <= 0.0)
	for category in voices:
		for player in voices[category]:
			player.volume_linear = gain(category) * float(player.get_meta("distance_gain", 1.0))
			# Discard muted transients so raising the volume cannot revive old events.
			if gain(category) <= 0.0 or volume("master") <= 0.0:
				player.stop()
	if is_instance_valid(music):
		music.volume_linear = gain("music")

func stop_effects() -> void:
	for pool in voices.values():
		for player in pool:
			player.stop()

func set_suspended(value: bool) -> void:
	suspended = value
	stop_effects()
	if is_instance_valid(music):
		music.stream_paused = value
	apply_mix()

func _process(delta: float) -> void:
	elapsed += delta
	# Re-evaluate visibility when the camera moves or a world is covered/closed.
	for pool in voices.values():
		for player in pool:
			if player.playing and player.has_meta("active_when"):
				var active: Callable = player.get_meta("active_when")
				if not active.is_valid() or not active.call():
					player.stop()
			if player.playing and player.has_meta("source_field"):
				var source = player.get_meta("source_field").get_ref()
				if not audible_at(source, player.get_meta("source_position")):
					player.stop()

func audible_at(source: Control, position: Vector2) -> bool:
	if not is_instance_valid(source) or not source.is_visible_in_tree():
		return false
	if source == app.field and (not app.slot_active or (is_instance_valid(app.slot_menu) and app.slot_menu.visible)):
		return false
	return not position.is_finite() or Rect2(Vector2.ZERO, source.size).has_point(source.screen(position))

func play(cue: String, position: Vector2 = Vector2.INF, source_field: Control = null, active_when: Callable = Callable()) -> void:
	if not CATALOG.has(cue) or streams.get(cue) == null or suspended:
		return
	if not active_when.is_null() and (not active_when.is_valid() or not active_when.call()):
		return
	var spec: Dictionary = CATALOG[cue]
	var category: String = spec.category
	if not voices.has(category) or gain(category) <= 0.0 or volume("master") <= 0.0:
		return
	var distance_gain := 1.0
	if position.is_finite() and source_field == null:
		source_field = app.field
	if source_field != null:
		if not audible_at(source_field, position):
			return
	if elapsed - float(last_cue.get(cue, -100.0)) < float(spec.cooldown):
		return
	var priority := cue.begins_with("power_") or (category == "bosses" and not cue.ends_with("_step"))
	if not priority and elapsed - float(last_category.get(category, -100.0)) < float(CATEGORY_GAPS[category]):
		return
	for player in voices[category]:
		if player.playing:
			continue
		player.stream = streams[cue]
		player.pitch_scale = playback_pitch(cue)
		if player.has_meta("active_when"):
			player.remove_meta("active_when")
		if not active_when.is_null():
			player.set_meta("active_when", active_when)
		if player.has_meta("source_field"):
			player.remove_meta("source_field")
			player.remove_meta("source_position")
		if source_field != null:
			player.set_meta("source_field", weakref(source_field))
			player.set_meta("source_position", position)
		player.set_meta("distance_gain", distance_gain)
		player.volume_linear = gain(category) * distance_gain
		player.play()
		last_cue[cue] = elapsed
		last_category[category] = elapsed
		accepted_events += 1
		return # Full pools drop events instead of queuing a delayed combat roar.

func playback_pitch(cue: String) -> float:
	# Every effect category shares a fresh +/-0.2 shift around normal pitch.
	# Music and unknown cues keep normal pitch; RNG belongs to this director.
	var varied := LIMITS.has(CATALOG.get(cue, {}).get("category", ""))
	return pitch_rng.randf_range(0.8, 1.2) if varied else 1.0

func observe_control(node: Node) -> void:
	if not app.is_ancestor_of(node):
		return
	if node is BaseButton and not node.has_meta("audio_preview"):
		node.pressed.connect(func():
			var text: String = node.text.to_lower() if node is Button else ""
			if text.is_empty():
				text = node.accessibility_name.to_lower()
			var cue := "menu_click"
			if text == "×" or text.contains("close") or text.contains("cancel") or text.begins_with("back"):
				cue = "menu_close"
			elif text.contains("settings") or text.contains("controls") or text.contains("info"):
				cue = "menu_open"
			play(cue)
		)
		if node is OptionButton:
			node.item_selected.connect(func(_index): play("menu_select"))
	elif node is Slider and not node.has_meta("audio_slider"):
		node.value_changed.connect(func(_value): play("menu_slider"))

func _exit_tree() -> void:
	stop_effects()
	if is_instance_valid(music):
		music.stop()
	var index := AudioServer.get_bus_index(bus_name)
	if index > 0:
		AudioServer.remove_bus(index)
	index = AudioServer.get_bus_index(master_bus_name)
	if index > 0:
		AudioServer.remove_bus(index)
