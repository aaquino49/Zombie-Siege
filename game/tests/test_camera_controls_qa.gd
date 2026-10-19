extends TestCase
## T-005 input bindings and screenshot scenario regressions.

func test_required_physical_key_and_wheel_bindings() -> void:
	var keys: Dictionary = {
		"cam_left": [KEY_A, KEY_LEFT], "cam_right": [KEY_D, KEY_RIGHT],
		"cam_up": [KEY_W, KEY_UP], "cam_down": [KEY_S, KEY_DOWN],
		"zoom_in": [KEY_EQUAL], "zoom_out": [KEY_MINUS],
		"pause": [KEY_SPACE], "speed_1": [KEY_1], "speed_2": [KEY_2],
		"speed_3": [KEY_3], "build_menu": [KEY_B], "cancel": [KEY_ESCAPE], "roster": [KEY_R]
	}
	for action: String in keys:
		assert_true(InputMap.has_action(action), "Missing action: " + action)
		if not InputMap.has_action(action):
			continue
		for key: int in keys[action]:
			var found: bool = false
			for event: InputEvent in InputMap.action_get_events(action):
				if event is InputEventKey and event.physical_keycode == key:
					found = true
			assert_true(found, "Missing physical key %s for %s" % [key, action])
	for action: String in ["zoom_in", "zoom_out"]:
		var button: int = MOUSE_BUTTON_WHEEL_UP if action == "zoom_in" else MOUSE_BUTTON_WHEEL_DOWN
		var found: bool = false
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventMouseButton and event.button_index == button:
				found = true
		assert_true(found, "Missing wheel binding for " + action)

func test_camera_zoomed_scenario_moves_existing_world_camera_to_corner() -> void:
	# Main already owns the world used by normal launch. Scenario setup must
	# move that camera; a second unbound world's camera cannot show its map.
	var scene: PackedScene = load("res://scenes/main.tscn")
	var main: Node2D = scene.instantiate() as Node2D
	var camera: Camera2D = main.get_node("World/Camera2D") as Camera2D
	var data: GameData = GameData.load_default()
	var map_size: float = float(data.balance("map_size")) * Grid.TILE
	camera.set("map_px", Vector2(map_size, map_size))
	camera.position = Vector2(map_size, map_size) / 2.0
	var scenario: GDScript = load("res://dev/scenarios/camera_zoomed.gd")
	scenario.setup(main)
	assert_eq(camera.zoom, Vector2(2.0, 2.0), "Rendered world's camera must be 2x")
	# The synchronous runner has no live viewport; allow setup to aim near
	# the corner and let the controller clamp once the scene enters the tree.
	var clamped: Vector2 = CameraMath.clamp_position(camera.position, 2.0, Vector2(1280, 720), Vector2(map_size, map_size))
	assert_eq(clamped, Vector2(320, 180), "1280x720 at 2x must clamp to top-left corner")
	main.free()
