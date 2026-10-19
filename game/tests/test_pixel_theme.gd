extends TestCase

func test_project_theme_loads_and_has_pixel_font() -> void:
	var theme_path: String = ProjectSettings.get_setting("gui/theme/custom", "")
	assert_eq(theme_path, "res://assets/pixel/ui/game_theme.tres", "gui/theme/custom is set in project.godot")
	var theme: Theme = load(theme_path) as Theme
	assert_not_null(theme, "Project theme loads successfully")
	assert_not_null(theme.default_font, "Default font must not be null")
	assert_true(theme.default_font.resource_path.ends_with("siege_pixel_noliga.tres"), "Default font is Siege Pixel without ligatures")
	assert_eq(theme.default_font_size, UiFont.BODY, "Default font size is 22")

func test_button_styleboxes_and_toggle_variation() -> void:
	var theme: Theme = load("res://assets/pixel/ui/game_theme.tres") as Theme
	assert_not_null(theme)
	var states: Array[String] = ["normal", "hover", "pressed", "disabled", "hover_pressed"]
	for state_name: String in states:
		var sb: StyleBoxTexture = theme.get_stylebox(state_name, "Button") as StyleBoxTexture
		assert_not_null(sb, "Button state %s must be a StyleBoxTexture" % state_name)
		assert_true(sb.texture.resource_path.contains("pixel/ui/x2/"), "Button state %s texture is from x2/" % state_name)
		assert_eq(int(sb.texture_margin_left), 12, "%s texture_margin_left is 12" % state_name)
		assert_eq(int(sb.texture_margin_top), 12, "%s texture_margin_top is 12" % state_name)
		assert_eq(int(sb.texture_margin_right), 12, "%s texture_margin_right is 12" % state_name)
		assert_eq(int(sb.texture_margin_bottom), 12, "%s texture_margin_bottom is 12" % state_name)

	var toggle_pressed: StyleBoxTexture = theme.get_stylebox("pressed", "ToggleButton") as StyleBoxTexture
	assert_not_null(toggle_pressed, "ToggleButton pressed stylebox must not be null")
	assert_true(toggle_pressed.texture.resource_path.ends_with("x2/button_toggle_on.png"), "ToggleButton pressed uses button_toggle_on.png")
	assert_eq(int(toggle_pressed.texture_margin_left), 12)

func test_x2_pngs_are_exactly_twice_native_sources() -> void:
	var dir := DirAccess.open("res://assets/pixel/ui")
	assert_not_null(dir, "pixel/ui directory must be accessible")
	dir.list_dir_begin()
	var filename: String = dir.get_next()
	var checked_count: int = 0
	while filename != "":
		if not dir.current_is_dir() and filename.ends_with(".png") and not filename.ends_with(".import"):
			var p1 := "res://assets/pixel/ui/" + filename
			var p2 := "res://assets/pixel/ui/x2/" + filename
			assert_true(FileAccess.file_exists(p2), "Matching x2 copy exists for %s" % filename)
			var im1 := Image.load_from_file(ProjectSettings.globalize_path(p1))
			var im2 := Image.load_from_file(ProjectSettings.globalize_path(p2))
			assert_not_null(im1, "Loaded native image %s" % p1)
			assert_not_null(im2, "Loaded 2x image %s" % p2)
			assert_eq(im2.get_width(), im1.get_width() * 2, "%s width is exactly 2x" % filename)
			assert_eq(im2.get_height(), im1.get_height() * 2, "%s height is exactly 2x" % filename)
			checked_count += 1
		filename = dir.get_next()
	dir.list_dir_end()
	assert_true(checked_count >= 35, "At least 35 native UI PNGs verified as exactly 2x (got %d)" % checked_count)

func test_hud_icon_texturerects_are_32x32_and_point_at_pixel_ui() -> void:
	var hud_scene: PackedScene = load("res://scenes/ui/hud.tscn") as PackedScene
	assert_not_null(hud_scene)
	var hud: Node = hud_scene.instantiate()
	var boxes: Array[String] = ["FoodBox", "WoodBox", "ScrapBox", "AmmoBox"]
	for b in boxes:
		var icon: TextureRect = hud.get_node("TopBar/Margin/HBox/Resources/" + b + "/Icon") as TextureRect
		assert_not_null(icon, "Icon node exists for %s" % b)
		assert_eq(icon.custom_minimum_size, Vector2(32, 32), "Icon minimum size is 32x32 for %s" % b)
		assert_not_null(icon.texture, "Icon texture is set for %s" % b)
		assert_true(icon.texture.resource_path.contains("pixel/ui/icon_"), "Icon %s points at pixel/ui/icon_*" % b)
	hud.free()

func test_no_stylebox_flat_in_ui_scenes() -> void:
	var scenes: Array[String] = [
		"res://scenes/ui/hud.tscn",
		"res://scenes/ui/build_bar.tscn",
		"res://scenes/ui/info_panel.tscn",
		"res://scenes/ui/roster_panel.tscn",
		"res://scenes/ui/hint_panel.tscn",
		"res://scenes/ui/dawn_report.tscn"
	]
	for scene_path: String in scenes:
		var scene: PackedScene = load(scene_path) as PackedScene
		assert_not_null(scene, "Scene loads: %s" % scene_path)
		var root: Node = scene.instantiate()
		var stack: Array[Node] = [root]
		while not stack.is_empty():
			var node: Node = stack.pop_back()
			for child in node.get_children():
				stack.append(child)
			if node is Control:
				var ctrl := node as Control
				for prop: Dictionary in ctrl.get_property_list():
					var prop_name: String = prop.get("name", "")
					if prop_name.begins_with("theme_override_styles/"):
						var val = ctrl.get(prop_name)
						assert_false(val is StyleBoxFlat, "No StyleBoxFlat in %s on node %s (property %s)" % [scene_path, ctrl.name, prop_name])
		root.free()

func test_day_night_icon_switches_with_phase() -> void:
	var state: GameState = GameState.new(GameData.load_default(), 1337)
	var hud_scene: PackedScene = load("res://scenes/ui/hud.tscn") as PackedScene
	var hud: CanvasLayer = hud_scene.instantiate() as CanvasLayer
	var phase_icon: TextureRect = hud.get_node("TopBar/Margin/HBox/DayArea/PhaseIcon") as TextureRect
	hud.set("top_bar", hud.get_node("TopBar"))
	for kind: String in ResourceStore.KINDS:
		var box_path: String = "TopBar/Margin/HBox/Resources/%sBox" % kind.capitalize()
		hud.set(kind + "_icon", hud.get_node(box_path + "/Icon"))
		hud.set(kind + "_label", hud.get_node(box_path + "/Label"))
	hud.set("day_label", hud.get_node("TopBar/Margin/HBox/DayArea/DayLabel"))
	hud.set("phase_icon", phase_icon)
	hud.set("time_label", hud.get_node("TopBar/Margin/HBox/ClockArea/TimeLabel"))
	hud.set("btn_pause", hud.get_node("TopBar/Margin/HBox/ClockArea/SpeedButtons/BtnPause"))
	hud.set("btn_1x", hud.get_node("TopBar/Margin/HBox/ClockArea/SpeedButtons/Btn1x"))
	hud.set("btn_2x", hud.get_node("TopBar/Margin/HBox/ClockArea/SpeedButtons/Btn2x"))
	hud.set("btn_3x", hud.get_node("TopBar/Margin/HBox/ClockArea/SpeedButtons/Btn3x"))
	hud.call("_ready")
	hud.call("bind", state)

	assert_not_null(phase_icon, "PhaseIcon exists")
	assert_true(phase_icon.texture.resource_path.ends_with("icon_day.png"), "Initial texture is icon_day.png")

	state.clock.phase = GameClock.Phase.NIGHT
	state.clock.phase_changed.emit(GameClock.Phase.NIGHT, 1)
	assert_true(phase_icon.texture.resource_path.ends_with("icon_night.png"), "Texture switches to icon_night.png on NIGHT")

	state.clock.phase = GameClock.Phase.DAY
	state.clock.phase_changed.emit(GameClock.Phase.DAY, 2)
	assert_true(phase_icon.texture.resource_path.ends_with("icon_day.png"), "Texture switches back to icon_day.png on DAY")

	hud.free()
