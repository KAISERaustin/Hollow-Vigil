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
var combat: VigilCombat
var economy: VigilEconomy

func _ready() -> void:
	# A private mix bus prevents independent app instances from sharing settings.
	bus_name = StringName("VigilAudio_" + str(get_instance_id()))
	AudioServer.add_bus()
	var bus := AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus, bus_name)
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = -1.0
	AudioServer.add_bus_effect(bus, limiter)
	for cue in CATALOG:
		streams[cue] = load("res://assets/audio/" + cue + ".wav")
	for category in LIMITS:
		voices[category] = []
		for index in range(LIMITS[category]):
			var player := AudioStreamPlayer.new()
			player.bus = bus_name
			add_child(player)
			voices[category].append(player)
	music = AudioStreamPlayer.new()
	var loop: AudioStreamWAV = streams.lantern_watch.duplicate()
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_begin = 0
	loop.loop_end = roundi(loop.get_length() * loop.mix_rate)
	music.stream = loop
	music.bus = bus_name
	add_child(music)
	bind_game()
	apply_mix()
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

func bind_game() -> void:
	if combat != null and combat.sound_requested.is_connected(play):
		combat.sound_requested.disconnect(play)
	if economy != null and economy.sound_requested.is_connected(play):
		economy.sound_requested.disconnect(play)
	combat = app.game.combat
	economy = app.game.economy
	combat.sound_requested.connect(play)
	economy.sound_requested.connect(play)
	stop_effects()
	last_cue.clear()
	last_category.clear()
	apply_mix()

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
	return 0.55 * trim * volume("master") * volume(category)

func apply_mix() -> void:
	for category in voices:
		for player in voices[category]:
			player.volume_linear = gain(category) * float(player.get_meta("distance_gain", 1.0))
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

func play(cue: String, position: Vector2 = Vector2.INF) -> void:
	if not CATALOG.has(cue) or suspended:
		return
	var spec: Dictionary = CATALOG[cue]
	var category: String = spec.category
	if not voices.has(category) or gain(category) <= 0.0:
		return
	var distance_gain := 1.0
	if position.is_finite():
		if not is_instance_valid(app.field) or not app.field.is_visible_in_tree():
			return
		var point: Vector2 = app.field.screen(position)
		var view := Rect2(Vector2.ZERO, app.field.size)
		var distance := point.distance_to(point.clamp(view.position, view.end))
		distance_gain = clampf(1.0 - distance / 180.0, 0.0, 1.0)
		if distance_gain <= 0.0:
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
		player.set_meta("distance_gain", distance_gain)
		player.volume_linear = gain(category) * distance_gain
		player.play()
		last_cue[cue] = elapsed
		last_category[category] = elapsed
		accepted_events += 1
		return # Full pools drop events instead of queuing a delayed combat roar.

func observe_control(node: Node) -> void:
	if not app.is_ancestor_of(node):
		return
	if node is BaseButton and not node.has_meta("audio_preview"):
		node.pressed.connect(func():
			var text: String = node.text.to_lower() if node is Button else ""
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
