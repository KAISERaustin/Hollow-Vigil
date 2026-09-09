class_name VigilApp
extends Control
const UI = preload("res://scripts/ui/shared/interface.gd")
var slot_menu: Control
var audio: Node
var application_paused := false
var application_unfocused := false
var public_builds: Node
var private_backups: Node
var campaign_progress := preload("res://scripts/campaign/progress.gd").new()
var campaign_backup: Node
var cloud: Node
var bug_reports: Node
var change_log: Node
# Shared settings and test-path owner; no background gameplay is started.
var game := VigilState.new()
var campaign: Control
var toast_label: Label
var toast_timer := 0.0
@export var load_saved_progress := true

func _ready() -> void:
	if OS.has_feature("mobile"):
		# Use physical density to keep UI units near device-independent pixels.
		get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		get_window().content_scale_size = Vector2i.ZERO
		get_window().content_scale_factor = clampf(DisplayServer.screen_get_dpi() / 160.0, 1.0, 4.0)
	Engine.max_fps = 60
	get_tree().auto_accept_quit = false
	theme = UI.theme()
	build_interface()
	load_preferences()
	audio = preload("res://scripts/audio/audio_director.gd").new()
	audio.app = self
	add_child(audio)
	cloud = preload("res://scripts/cloud/cloud_service.gd").new()
	cloud.game = game
	cloud.enabled = load_saved_progress
	add_child(cloud)
	bug_reports = preload("res://scripts/cloud/bug_reports.gd").new()
	bug_reports.cloud = cloud
	add_child(bug_reports)
	change_log = preload("res://scripts/cloud/change_log.gd").new()
	change_log.cloud = cloud
	add_child(change_log)
	if not load_saved_progress:
		campaign_progress.path = game.save_path + ".campaign-test"
	campaign_progress.load_progress()
	campaign_backup = preload("res://scripts/cloud/campaign_backup.gd").new()
	campaign_backup.cloud = cloud
	campaign_backup.progress = campaign_progress
	campaign_backup.restored.connect(func():
		if is_instance_valid(campaign):
			campaign.run = null
			campaign.show_map()
	)
	add_child(campaign_backup)
	public_builds = preload("res://scripts/cloud/public_builds.gd").new()
	public_builds.cloud = cloud
	if not load_saved_progress:
		public_builds.outbox_path = game.save_path + ".public-builds-test"
	public_builds.set_process(load_saved_progress)
	add_child(public_builds)
	slot_menu = preload("res://scripts/ui/unified_menu.gd").new()
	slot_menu.app = self
	add_child(slot_menu)
	private_backups = preload("res://scripts/cloud/private_backups.gd").new()
	private_backups.app = self
	private_backups.cloud = cloud
	private_backups.enabled = load_saved_progress
	if not load_saved_progress:
		private_backups.slots.base_path = game.save_path + ".unified"
		private_backups.state_path = game.save_path + ".private-backups-test"
	private_backups.campaign_slots.base_path = private_backups.slots.base_path
	add_child(private_backups)

func build_interface() -> void:
	game.suspended = true
	toast_label = UI.paragraph("", 14)
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	toast_label.offset_left = 12
	toast_label.offset_right = -12
	toast_label.offset_top = -80
	toast_label.offset_bottom = -20
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_label.z_index = 300
	toast_label.hide()
	add_child(toast_label)

func preferences_path() -> String:
	return "user://vigil-preferences.cfg" if load_saved_progress else game.save_path + ".preferences-test"

func load_preferences() -> void:
	var config := ConfigFile.new()
	if config.load(preferences_path()) == OK:
		var settings: Variant = config.get_value("preferences", "settings", {})
		if settings is Dictionary: game.data.settings = settings

func persist() -> void:
	var config := ConfigFile.new()
	config.set_value("preferences", "settings", game.data.settings)
	if config.save(preferences_path()) != OK: toast("Couldn't save sound preferences.")

func apply_ui_preferences() -> void:
	theme = UI.theme()
	for node in find_children("*", "Control", true, false):
		if node.has_meta("ui_font_size"):
			node.add_theme_font_size_override("font_size", UI.type_size(node.get_meta("ui_font_size")))

func toast(message: String, seconds: float = 4.0, color: Color = UI.TEXT) -> void:
	toast_label.text = message
	toast_label.add_theme_color_override("font_color", color)
	toast_label.show()
	toast_timer = seconds

func _process(delta: float) -> void:
	toast_timer = maxf(0.0, toast_timer - delta)
	toast_label.visible = toast_timer > 0.0

func _notification(what: int) -> void:
	if not is_node_ready(): return
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if is_instance_valid(campaign): campaign.save_progress()
		persist()
		get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		application_paused = true
		audio.set_suspended(true)
		persist()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		application_paused = false
		audio.set_suspended(application_unfocused)
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		application_unfocused = true
		audio.set_suspended(true)
		persist()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		application_unfocused = false
		audio.set_suspended(application_paused)
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST: navigate_back()

func navigate_back() -> void:
	preload("res://scripts/ui/shared/back_navigation.gd").invoke(self, route_back)

func route_back() -> void:
	for popup in get_viewport().get_embedded_subwindows():
		if popup is Popup and popup.visible:
			popup.hide()
			return
	if is_instance_valid(slot_menu) and slot_menu.visible: slot_menu.go_back()
	elif is_instance_valid(campaign): campaign.go_back()

func show_backups() -> void:
	slot_menu.show_backups(slot_menu.open_game_menu if slot_menu.held else slot_menu.show_home)

func show_game_menu() -> void:
	if is_instance_valid(campaign): slot_menu.open_game_menu()

func queue_private_backup() -> void:
	if is_instance_valid(private_backups): private_backups.queue_backup()

func open_campaign_slot(slot: int, value: Dictionary) -> void:
	if is_instance_valid(campaign): return
	campaign = preload("res://scripts/campaign/screen.gd").new()
	campaign.app = self
	campaign.active_campaign_slot = slot
	campaign.campaign_save = value.duplicate(true)
	campaign.closed.connect(func():
		campaign = null
		slot_menu.show_home("campaign")
	)
	add_child(campaign)
	slot_menu.hide()
