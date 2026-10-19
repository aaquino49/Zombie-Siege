extends TestCase
## T-037: detached viewport fallback follows project settings.

func test_detached_node_uses_project_viewport_settings() -> void:
	var width_key: String = "display/window/size/viewport_width"
	var height_key: String = "display/window/size/viewport_height"
	var previous_width: int = int(ProjectSettings.get_setting(width_key))
	var previous_height: int = int(ProjectSettings.get_setting(height_key))
	ProjectSettings.set_setting(width_key, 960)
	ProjectSettings.set_setting(height_key, 540)
	var node: Node = Node.new()
	assert_false(node.is_inside_tree())
	assert_eq(CameraMath.viewport_size_for(node), Vector2(960, 540), "Detached fallback must follow settings")
	node.free()
	ProjectSettings.set_setting(width_key, previous_width)
	ProjectSettings.set_setting(height_key, previous_height)

func test_zoomed_scenario_without_game_state_uses_configured_viewport() -> void:
	var width_key: String = "display/window/size/viewport_width"
	var height_key: String = "display/window/size/viewport_height"
	var previous_width: int = int(ProjectSettings.get_setting(width_key))
	var previous_height: int = int(ProjectSettings.get_setting(height_key))
	var previous_state: GameState = Game.state
	ProjectSettings.set_setting(width_key, 960)
	ProjectSettings.set_setting(height_key, 540)
	Game.state = null
	var scene: PackedScene = load("res://scenes/main.tscn")
	var main: Node = scene.instantiate()
	var camera: CameraController = main.get_node("World/Camera2D")
	camera.map_px = Vector2(3072, 3072)
	var scenario: GDScript = load("res://dev/scenarios/camera_zoomed.gd")
	scenario.setup(main)
	assert_eq(camera.map_px, Vector2(3072, 3072), "Detached scenario keeps the bound map size")
	assert_eq(camera.zoom, Vector2(2, 2))
	assert_eq(camera.position, Vector2(240, 135), "Corner clamp must use configured viewport dimensions")
	main.free()
	Game.state = previous_state
	ProjectSettings.set_setting(width_key, previous_width)
	ProjectSettings.set_setting(height_key, previous_height)
