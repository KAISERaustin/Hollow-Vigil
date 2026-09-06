extends VBoxContainer
const UI = preload("res://scripts/ui/shared/interface.gd")
var app: Control

func _ready() -> void:
	add_theme_constant_override("separation", 10)
	add_child(UI.heading("Sound", 20))
	add_child(UI.paragraph("Set any slider to 0% to silence that category. Changes apply immediately.", 13))
	var mute := CheckButton.new()
	mute.name = "MuteAudio"
	mute.text = "Mute all sound"
	mute.custom_minimum_size.y = 48
	mute.button_pressed = app.audio.preferences().get("muted", false)
	mute.toggled.connect(func(value):
		app.audio.set_muted(value)
		app.balance_changed()
	)
	add_child(mute)
	for category in app.audio.DEFAULTS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		add_child(row)
		var title := UI.label(category.capitalize(), 14)
		title.custom_minimum_size.x = 65
		row.add_child(title)
		var slider := HSlider.new()
		slider.name = "Audio_" + category
		slider.set_meta("audio_slider", true)
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 1
		slider.value = app.audio.volume(category) * 100
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.custom_minimum_size = Vector2(64, 48)
		slider.accessibility_name = category.capitalize() + " volume"
		row.add_child(slider)
		var amount := UI.label("%d%%" % slider.value, 14)
		amount.custom_minimum_size.x = 44
		amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(amount)
		slider.value_changed.connect(func(value):
			amount.text = "%d%%" % value
			app.audio.set_volume(category, value / 100.0)
			app.balance_changed()
		)
		var preview := UI.button("▶", func(): preview_category(category))
		preview.set_meta("audio_preview", true)
		preview.name = "Preview_" + category
		preview.custom_minimum_size.x = 48
		preview.size_flags_horizontal = Control.SIZE_SHRINK_END
		preview.accessibility_name = "Preview " + category + " volume"
		preview.tooltip_text = preview.accessibility_name
		if category == "music":
			preview.text = "♪"
			preview.disabled = true
			preview.accessibility_name = "Music is playing; adjust its slider to listen"
			preview.tooltip_text = preview.accessibility_name
		row.add_child(preview)
	var reset := UI.button("Restore sound defaults", func():
		for category in app.audio.DEFAULTS:
			app.audio.set_volume(category, app.audio.DEFAULTS[category])
		app.audio.set_muted(false)
		app.persist()
		app.panels.show_settings()
	)
	reset.name = "RestoreAudioDefaults"
	add_child(reset)

func preview_category(category: String) -> void:
	var cues := {"master": "menu_collect", "menu": "menu_open", "towers": "shot_heavy", "enemies": "death_basic", "bosses": "boss_bell_ability"}
	if cues.has(category):
		app.audio.play(cues[category])
	# Music is already looping and responds live, without restarting its phrase.
