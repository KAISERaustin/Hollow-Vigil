extends VBoxContainer
const UI = preload("res://scripts/ui/shared/interface.gd")
var app: Control

func _ready() -> void:
	add_theme_constant_override("separation", 10)
	add_child(UI.paragraph("Type a percentage or use − / +. Set a category to 0% to silence it.", 13))
	var mute := UI.toggle_button(app.audio.preferences().get("muted", false), func(value):
		app.audio.set_muted(value)
		app.balance_changed()
	)
	mute.name = "MuteAudio"
	add_child(UI.action_row("Mute all sound", mute, mute.text))
	for category in app.audio.DEFAULTS:
		var number := SpinBox.new()
		number.name = "Audio_" + category
		number.min_value = 0
		number.max_value = 100
		number.step = 1
		number.suffix = "%"
		number.value = app.audio.volume(category) * 100
		number.accessibility_name = category.capitalize() + " volume"
		number.value_changed.connect(func(value):
			app.audio.set_volume(category, value / 100.0)
			app.balance_changed()
		)
		var preview := UI.button("▶", func(): preview_category(category))
		preview.set_meta("audio_preview", true)
		preview.name = "Preview_" + category
		preview.custom_minimum_size.x = 48
		preview.accessibility_name = "Preview " + category + " volume"
		preview.tooltip_text = preview.accessibility_name
		if category == "music":
			preview.text = "♪"
			preview.disabled = true
			preview.accessibility_name = "Music is playing; change its volume to listen"
			preview.tooltip_text = preview.accessibility_name
		add_child(UI.number_row(category.capitalize(), number, preview, category_art(category)))
	var reset := UI.button("Restore sound defaults", func():
		for category in app.audio.DEFAULTS:
			app.audio.set_volume(category, app.audio.DEFAULTS[category])
		app.audio.set_muted(false)
		app.persist()
		app.panels.show_sound_settings()
	)
	reset.name = "RestoreAudioDefaults"
	add_child(UI.action_row(reset.text, reset, "Restore"))

func category_art(category: String) -> Control:
	var art := Control.new()
	art.custom_minimum_size = Vector2(48, 48)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.draw.connect(func():
		var center := art.size * 0.5
		match category:
			"enemies":
				VigilEnemyArt.draw(art, "basic", center + Vector2(0, 3), 1.4)
			"bosses":
				preload("res://scripts/rendering/actors/boss_art.gd").portrait(art, "warden", center + Vector2(0, 2), 0.4)
			"music":
				for x in [-7, 7]:
					art.draw_circle(center + Vector2(x - 3, 10), 5, UI.TEXT)
					art.draw_line(center + Vector2(x, 10), center + Vector2(x, -12), UI.TEXT, 3, true)
				art.draw_line(center + Vector2(-7, -12), center + Vector2(7, -12), UI.TEXT, 4, true)
			_:
				# Shared sound-wave emblem for overall, interface and tower audio.
				for index in range(5):
					var height := 16 - absi(index - 2) * 5
					var x := center.x + (index - 2) * 7
					art.draw_line(Vector2(x, center.y - height), Vector2(x, center.y + height), UI.TEXT, 3, true)
	)
	return art

func preview_category(category: String) -> void:
	var cues := {"master": "menu_collect", "menu": "menu_open", "towers": "shot_heavy", "enemies": "death_basic", "bosses": "boss_bell_ability"}
	if cues.has(category):
		app.audio.play(cues[category])
	# Music is already looping and responds live, without restarting its phrase.
