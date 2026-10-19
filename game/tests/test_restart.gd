extends TestCase

func test_scenario_arg() -> void:
	var script = load("res://scripts/main.gd")
	assert_eq(script.scenario_arg(["--scenario=night"]), "night")
	assert_eq(script.scenario_arg(["--something=else", "foo"]), "")
	assert_eq(script.scenario_arg(["--scenario=main_menu"]), "main_menu")
	assert_eq(script.scenario_arg(["--frames=120", "--scenario=night", "--screenshot=x.png"]), "night")
	assert_eq(script.scenario_arg([]), "")

func test_restart_leaks() -> void:
	for i in range(3):
		var refs: Array[WeakRef] = _tick_night_and_release(100 + i)
		for ref: WeakRef in refs:
			assert_true(ref.get_ref() == null, "Simulation should free cleanly on iteration " + str(i))

func _tick_night_and_release(seed_value: int) -> Array[WeakRef]:
	var data := GameData.load_default()
	var state := GameState.new(data, seed_value)
	state.waves.enabled = true
	var seconds: float = float(data.balance("day_length")) + 10.0
	for j: int in range(int(ceil(seconds / 0.5))):
		state.tick(0.5)
	assert_eq(state.clock.phase, GameClock.Phase.NIGHT, "Lifecycle setup reaches night 1")
	assert_eq(state.clock.day, 1)
	assert_gt(state.zombies.count(), 0, "Real enabled waves must spawn zombies before teardown")
	var refs: Array[WeakRef] = [weakref(state), weakref(state.flow), weakref(state.waves),
		weakref(state.zombies), weakref(state.buildings), weakref(state.map),
		weakref(state.pathfinder), weakref(state.survivors)]
	return refs

func test_main_menu_open() -> void:
	var data := GameData.load_default()
	var state := GameState.new(data, 1)
	
	var menu_scene = load("res://scenes/ui/main_menu.tscn")
	var menu = menu_scene.instantiate()
	menu.open(state)
	
	assert_true(state.clock.paused, "Menu should pause clock")
	assert_true(state.clock.locked, "Menu should lock clock")
	
	var tagline: Label = menu.get_node("Dim/Center/Panel/Margin/Content/Tagline")
	assert_eq(tagline.text, "Survive 20 nights. Build the Radio Tower. Get rescued.")
	
	menu.free()

func test_main_menu_disables_gameplay_processing() -> void:
	var state := GameState.new(GameData.load_default(), 1337)
	var main := Node2D.new()
	var world := Node2D.new()
	world.name = "World"
	main.add_child(world)
	for layer_name: String in ["HUD", "BuildBarLayer", "RosterPanel", "InfoPanel"]:
		var gameplay_layer := CanvasLayer.new()
		gameplay_layer.name = layer_name
		main.add_child(gameplay_layer)
	var menu: MainMenu = (load("res://scenes/ui/main_menu.tscn") as PackedScene).instantiate()
	main.add_child(menu)
	menu.open(state)
	for node_name: String in ["World", "HUD", "BuildBarLayer", "RosterPanel", "InfoPanel"]:
		assert_eq(main.get_node(node_name).process_mode, Node.PROCESS_MODE_DISABLED,
			"Menu must stop gameplay processing and input: " + node_name)
	for layer_name: String in ["HUD", "BuildBarLayer", "RosterPanel", "InfoPanel"]:
		assert_false(main.get_node(layer_name).visible, "Menu hides gameplay layer: " + layer_name)
	assert_true(menu.visible, "Menu stays visible")
	assert_ne(menu.process_mode, Node.PROCESS_MODE_DISABLED, "Menu buttons remain enabled")
	main.free()

func test_main_menu_uses_balance_and_locks_controls() -> void:
	var data := GameData.load_default()
	data._balance["nights_to_win"] = 27
	var state := GameState.new(data, 1337)
	var menu: MainMenu = (load("res://scenes/ui/main_menu.tscn") as PackedScene).instantiate()
	menu.bind(state)
	menu.open(state)
	var content: Node = menu.get_node("Dim/Center/Panel/Margin/Content")
	assert_eq(content.get_node("Tagline").text, "Survive 27 nights. Build the Radio Tower. Get rescued.")
	assert_eq(menu.layer, 30)
	assert_eq(menu.get_node("Dim").mouse_filter, Control.MOUSE_FILTER_STOP)
	assert_true(content.get_node("Buttons/NewGame").pressed.is_connected(Callable(menu, "_new_game")))
	assert_true(content.get_node("Buttons/Quit").pressed.is_connected(Callable(menu, "_quit")))
	state.clock.toggle_pause()
	state.clock.set_paused(false)
	for speed: int in [1, 2, 3]:
		state.clock.set_speed(speed)
	assert_true(state.clock.paused)
	assert_true(state.clock.locked)
	state.tick(1.0)
	assert_almost_eq(state.time_played, 0.0)
	menu.free()
