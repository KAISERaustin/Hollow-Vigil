extends SceneTree

const UI = preload("res://scripts/ui/shared/interface.gd")
const Harness = preload("res://tests/rendered/visual_smoke.gd")
var app: VigilApp
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	preload("res://tests/support/timeout.gd").arm(self, 180)
	call_deferred("run")

func settle() -> void:
	for frame in range(8):
		await process_frame

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func check_heading(title: Label, context: String) -> void:
	var text_width := title.get_theme_font("font").get_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, title.get_theme_font_size("font_size")).x
	check(title.get_line_count() == 1, context + ": heading wraps")
	check(text_width <= title.size.x + 1, context + ": heading text is clipped: " + title.text)
	check(title.get_theme_font_size("font_size") >= UI.BODY, context + ": heading is too small")

func check_header(context: String) -> void:
	var header := app.panels.header_content.get_child(0) as Control
	var close := header.find_child("CloseSheet", true, false) as Button
	var back := header.get_child(0) as Button
	check(close.size.is_equal_approx(Vector2(UI.TARGET, UI.TARGET)), context + ": close must stay square")
	check(back.size.is_equal_approx(close.size), context + ": back and close sizes differ")
	check(is_equal_approx(close.get_global_rect().end.x, header.get_global_rect().end.x), context + ": close is not right aligned")
	check(is_equal_approx(close.global_position.y, header.global_position.y), context + ": close is not top aligned")
	check(header.size.y == UI.TARGET, context + ": header consumes more than one control row")
	check_heading(header.find_child("SheetTitle", true, false), context)
	check(app.panels.get_global_rect().encloses(header.get_global_rect()), context + ": header leaves panel")

func check_editor(controls: Control, context: String) -> void:
	check_header(context)
	check_heading(controls.identity_title, context + " identity")
	var scroll := app.panels.content_scroll
	check(scroll.get_global_rect().grow(1).encloses(controls.selector.get_global_rect()), context + ": selector is not initially visible")
	if controls.tier_selector.visible:
		check(scroll.get_global_rect().grow(1).encloses(controls.tier_selector.get_global_rect()), context + ": tier selector is not initially visible")
	for selector: Button in [controls.selector, controls.tier_selector]:
		if not selector.visible:
			continue
		var text_width := selector.get_theme_font("font").get_string_size(selector.text, HORIZONTAL_ALIGNMENT_LEFT, -1, selector.get_theme_font_size("font_size")).x
		var reserved := selector.get_theme_stylebox("normal").get_minimum_size().x
		check(selector.autowrap_mode != TextServer.AUTOWRAP_OFF or text_width + reserved <= selector.size.x + 1, context + ": selector text is clipped: " + selector.text)
	for child in controls.find_children("*", "Control", true, false):
		if child.is_visible_in_tree():
			check(child.get_global_rect().position.x >= scroll.global_position.x - 1 and child.get_global_rect().end.x <= scroll.get_global_rect().end.x + 1, context + ": horizontal overflow in " + str(child.name))

func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/developer-layout-" + label + ".png")

func run() -> void:
	app = VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://developer-layout.save"
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	# Audio has its own suite; avoid transient playback surviving this fast sweep.
	app.audio.set_muted(true)
	app.audio.music.stop()
	Engine.max_fps = 240
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for dimensions in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		app.panels.show_developer_controls()
		await settle()
		var controls := app.panels.find_child("DeveloperControls", true, false)
		check_header("home " + str(dimensions))
		await capture("home-" + str(dimensions.x))
		for category in controls.categories:
			app.panels.content_scroll.ensure_control_visible(controls.tabs[category])
			await settle()
			await Harness.tap(app, controls.tabs[category].get_global_rect().get_center(), dimensions.x == 360)
			await settle()
			check(controls.editor.visible and controls.category == category, "Category tap opens " + category)
			check(app.panels.content_scroll.scroll_vertical == 0, "Category opens at the top")
			var longest_title := 0.0
			for index in range(controls.selector.item_count):
				controls.selector.select(index)
				controls.selector.item_selected.emit(index)
				for tier in range(controls.tier_selector.item_count if category == "towers" else 1):
					if category == "towers":
						controls.tier_selector.select(tier)
						controls.tier_selector.item_selected.emit(tier)
					await settle()
					var context := "%s/%s/%d at %s" % [category, controls.selected_kind, tier, dimensions]
					check_editor(controls, context)
					var title_width: float = controls.identity_title.get_theme_font("font").get_string_size(controls.identity_title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, UI.OBJECT_TITLE).x
					if title_width > longest_title:
						longest_title = title_width
						await capture(category + "-" + str(dimensions.x))
					for row in controls.fields.get_children():
						app.panels.content_scroll.ensure_control_visible(row)
						await settle()
						check(app.panels.content_scroll.get_global_rect().grow(1).encloses(row.get_global_rect()), context + ": numeric row is not fully reachable")
						for label in row.find_children("*", "Label", true, false):
							check(label.get_visible_line_count() == label.get_line_count(), context + ": numeric label is clipped")
					check_header(context + " after scrolling")
					app.panels.content_scroll.scroll_vertical = 0
					await settle()
			controls.selector.show_popup()
			await settle()
			var popup: PopupPanel = controls.selector.get_popup()
			check(popup.visible and popup.size.y <= 560, "Selection menu height is bounded: " + category)
			check(Rect2i(Vector2i.ZERO, dimensions).encloses(Rect2i(popup.position, popup.size)), "Selection menu stays on screen: " + category)
			check(controls.selector.rows.get_child_count() == controls.selector.item_count, "Every choice has a separating rule: " + category)
			var first_choice: Button = controls.selector.rows.find_child("Choice_0", true, false)
			var first_row := first_choice.get_parent() as Control
			check(first_row.has_meta("scroll_action_row") and not first_row is BaseButton, "Picker reuses passive settings row: " + category)
			check(first_choice.size.x < first_row.size.x * 0.5 and is_equal_approx(first_choice.get_global_rect().end.x, first_row.get_global_rect().end.x), "Selection button is confined to the right: " + category)
			controls.selector.scroll.ensure_control_visible(first_row)
			await settle()
			check(controls.selector.scroll.get_global_rect().encloses(first_choice.get_global_rect()), "First choice is reachable: " + category)
			await capture(category + "-picker-" + str(dimensions.x))
			first_choice.pressed.emit()
			await settle()
			check(not popup.visible and controls.selected_kind == controls.selector.get_item_metadata(0), "Choice returns to matching editor: " + category)
			if category == "towers":
				controls.tier_selector.show_popup()
				await settle()
				var branch_choice: Button = controls.tier_selector.rows.find_child("Choice_4", true, false)
				controls.tier_selector.scroll.ensure_control_visible(branch_choice)
				await settle()
				branch_choice.pressed.emit()
				await settle()
				check(controls.selected_level == 4 and controls.selected_branch != "", "Illustrated tier choice applies specialization")
			popup.hide()
			for reset_name in ["ResetSelectedBalance", "ResetAllBalance"]:
				var reset := controls.find_child(reset_name, true, false) as Button
				app.panels.content_scroll.ensure_control_visible(reset.get_parent())
				await settle()
				check(app.panels.content_scroll.get_global_rect().grow(1).encloses(reset.get_parent().get_global_rect()), "Reset row is reachable: " + category)
			await capture(category + "-fields-" + str(dimensions.x))
			var back := app.panels.find_child("BackToCategories", true, false) as Button
			await Harness.tap(app, back.get_global_rect().get_center(), dimensions.x == 360)
			await settle()
			check(controls.category_list.visible and app.panels.content_scroll.scroll_vertical == 0, "Back returns to category list at top")
			check_header("home after " + category)
		var close := app.panels.find_child("CloseSheet", true, false) as Button
		await Harness.tap(app, close.get_global_rect().get_center(), dimensions.x == 360)
		check(not app.panels.visible, "Close button dismisses Developer Controls")
	app.queue_free()
	await process_frame
	print("DEVELOPER_LAYOUT: %d checks, %d failures; all registered categories, every type and tower tier at three viewport sizes" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
