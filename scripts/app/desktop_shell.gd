extends Control
## Windows owns only the surrounding workspace. The portrait app stays shared.
const MOBILE_SCENE = preload("res://scenes/main.tscn")
const UI = preload("res://scripts/ui/shared/interface.gd")
const PORTRAIT_SIZE := Vector2i(540, 960)

@export var load_saved_progress := true
var app: VigilApp
var game_container: SubViewportContainer
var game_viewport: SubViewport
var workspace: Control

func _ready() -> void:
	var background := ColorRect.new()
	background.color = UI.BG
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	game_container = SubViewportContainer.new()
	game_container.name = "PortraitGame"
	game_container.stretch = true
	add_child(game_container)
	game_viewport = SubViewport.new()
	game_viewport.name = "MobileViewport"
	game_viewport.size_2d_override = PORTRAIT_SIZE
	game_viewport.size_2d_override_stretch = true
	game_viewport.gui_embed_subwindows = true
	game_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	game_container.add_child(game_viewport)

	workspace = Control.new()
	workspace.name = "DesktopWorkspace"
	workspace.clip_contents = true
	workspace.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(workspace)
	resized.connect(fit)
	fit()

	app = MOBILE_SCENE.instantiate()
	app.load_saved_progress = load_saved_progress
	if not load_saved_progress:
		app.game.save_path = "user://desktop-shell-" + str(Time.get_ticks_usec()) + ".save"
	game_viewport.add_child(app)

func fit() -> void:
	if not is_instance_valid(game_container): return
	# Only the desktop window is wide; the game always sees upright portrait.
	var height := minf(size.y, size.x * PORTRAIT_SIZE.y / PORTRAIT_SIZE.x)
	var width := floorf(height * PORTRAIT_SIZE.x / PORTRAIT_SIZE.y)
	game_container.position = Vector2.ZERO
	game_container.size = Vector2(width, height)
	workspace.position = Vector2(width, 0)
	workspace.size = Vector2(maxf(0, size.x - width), size.y)
