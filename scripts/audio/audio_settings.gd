extends VBoxContainer
const UI = preload("res://scripts/ui/shared/interface.gd")
var app: Control

func _ready() -> void:
	add_theme_constant_override("separation", 10)
	add_child(UI.paragraph("Type a percentage or use − / +. Set a category to 0% to silence it.", 13))
	var mute := CheckButton.new()
	mute.name = "MuteAudio"
	mute.text = "Mute all sound"
	mute.custom_minimum_size.y = 48
	mute.button_pressed = app.audio.preferences().get("muted", false)
	mute.toggled.connect(func(value):
		app.audio.set_muted(value)
		app.balance_changed()
	)
	add_child(UI.action_row("Mute all sound", mute))
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
		add_child(UI.number_row(category.capitalize(), number, preview))
	var reset := UI.button("Restore sound defaults", func():
		for category in app.audio.DEFAULTS:
			app.audio.set_volume(category, app.audio.DEFAULTS[category])
		app.audio.set_muted(false)
		app.persist()
		app.panels.show_sound_settings()
	)
	reset.name = "RestoreAudioDefaults"
	add_child(UI.action_row(reset.text, reset, "Restore"))

func preview_category(category: String) -> void:
	var cues := {"master": "menu_collect", "menu": "menu_open", "towers": "shot_heavy", "enemies": "death_basic", "bosses": "boss_bell_ability"}
	if cues.has(category):
		app.audio.play(cues[category])
	# Music is already looping and responds live, without restarting its phrase.
