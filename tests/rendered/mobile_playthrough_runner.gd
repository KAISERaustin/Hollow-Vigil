extends "res://tests/rendered/unified_menu_runner.gd"
## Reuse the complete offline game/menu flow, driven by physical touch events.
const UI = preload("res://scripts/ui/shared/interface.gd")
const Touch = preload("res://tests/rendered/visual_smoke.gd")

func _initialize() -> void:
	Input.emulate_touch_from_mouse = true
	super._initialize()

func press(key: String) -> void:
	await frames()
	var target := button(key)
	check(target != null, "Touch action exists: " + key)
	if target == null: return
	var ancestor := target.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer: ancestor.ensure_control_visible(target)
		ancestor = ancestor.get_parent()
	await frames()
	var rect := target.get_global_rect()
	if target.get_window() != root: rect.position += Vector2(target.get_window().position)
	check(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(rect), "Touch action fits: " + key)
	await Touch.tap(app, rect.get_center(), true)
	await frames()
	for frame in 120:
		if not app.private_backups.busy and not app.public_builds.busy: break
		await process_frame
	await frames()

func choose(key: String, index: int) -> void:
	await press(key)
	var picker: OptionButton = menu.find_child(key, true, false)
	if picker == null: return
	var popup := picker.get_popup()
	check(popup.visible, "Touch opens dropdown: " + key)
	if not popup.visible: return
	var chosen := [-1]
	picker.item_selected.connect(func(value: int): chosen[0] = value)
	var style := popup.get_theme_stylebox("panel")
	# Long lists are viewport-bounded; their rows retain their full touch height.
	var item_height := ceili(popup.get_theme_font("font").get_height(popup.get_theme_font_size("font_size"))) + popup.get_theme_constant("v_separation")
	var point := Vector2(popup.position) + Vector2(popup.size.x * 0.5, style.content_margin_top + item_height * (index + 0.5))
	await Touch.tap(app, point, true)
	await frames()
	check(chosen[0] == index and (not is_instance_valid(popup) or not popup.visible), "Touch selects dropdown item: " + key)

func capture(key: String) -> void:
	Engine.max_fps = 240
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await super.capture("mobile-" + key)
