extends TestCase

func test_ui_font_constants_and_crisp_helper() -> void:
	assert_eq(UiFont.NATIVE, 11)
	assert_eq(UiFont.SMALL, 11)
	assert_eq(UiFont.BODY, 22)
	assert_eq(UiFont.LARGE, 33)
	assert_eq(UiFont.TITLE, 44)
	assert_eq(UiFont.BANNER, 66)

	assert_true(UiFont.is_crisp(11), "11 is crisp")
	assert_true(UiFont.is_crisp(22), "22 is crisp")
	assert_true(UiFont.is_crisp(33), "33 is crisp")
	assert_true(UiFont.is_crisp(44), "44 is crisp")
	assert_true(UiFont.is_crisp(55), "55 is crisp")
	assert_true(UiFont.is_crisp(66), "66 is crisp")

	assert_false(UiFont.is_crisp(0), "0 is not crisp")
	assert_false(UiFont.is_crisp(-11), "negative is not crisp")
	assert_false(UiFont.is_crisp(12), "12 is not crisp")
	assert_false(UiFont.is_crisp(14), "14 is not crisp")
	assert_false(UiFont.is_crisp(16), "16 is not crisp")
	assert_false(UiFont.is_crisp(18), "18 is not crisp")
	assert_false(UiFont.is_crisp(20), "20 is not crisp")
	assert_false(UiFont.is_crisp(24), "24 is not crisp")
	assert_false(UiFont.is_crisp(30), "30 is not crisp")
	assert_false(UiFont.is_crisp(32), "32 is not crisp")
	assert_false(UiFont.is_crisp(64), "64 is not crisp")
	assert_false(UiFont.is_crisp(72), "72 is not crisp")

func test_theme_default_and_all_font_sizes_are_crisp() -> void:
	var theme: Theme = load("res://assets/pixel/ui/game_theme.tres") as Theme
	assert_not_null(theme, "Theme loads")
	assert_eq(theme.default_font_size, 22, "Theme default font size is 22")
	assert_true(UiFont.is_crisp(theme.default_font_size), "Default font size is crisp")

	assert_eq(theme.get_font_size("font_size", "Label"), 22, "Label font size is 22")
	assert_eq(theme.get_font_size("font_size", "Button"), 22, "Button font size is 22")
	assert_eq(theme.get_font_size("font_size", "PopupMenu"), 22, "PopupMenu font size is 22")
	assert_eq(theme.get_font_size("font_size", "OptionButton"), 22, "OptionButton font size is 22")
	assert_eq(theme.get_font_size("font_size", "LineEdit"), 22, "LineEdit font size is 22")
	assert_true(theme.get_font_size("font_size", "TooltipLabel") in [11, 22], "TooltipLabel font size is 11 or 22")

	for type_name: StringName in theme.get_type_variation_list(&""):
		for size_name: StringName in theme.get_font_size_list(type_name):
			var sz: int = theme.get_font_size(size_name, type_name)
			assert_true(UiFont.is_crisp(sz), "Theme %s/%s (%d) must be crisp" % [type_name, size_name, sz])

	for type_name: StringName in [&"Label", &"Button", &"PopupMenu", &"OptionButton", &"LineEdit", &"TooltipLabel"]:
		for size_name: StringName in theme.get_font_size_list(type_name):
			var sz: int = theme.get_font_size(size_name, type_name)
			assert_true(UiFont.is_crisp(sz), "Theme %s/%s (%d) must be crisp" % [type_name, size_name, sz])

func test_font_import_settings() -> void:
	var config := ConfigFile.new()
	var err := config.load("res://assets/pixel/ui/font/siege_pixel.ttf.import")
	assert_eq(err, OK, "Font .import file loads")
	assert_eq(int(config.get_value("params", "antialiasing", -1)), 0, "antialiasing is 0")
	assert_eq(int(config.get_value("params", "hinting", -1)), 0, "hinting is 0")
	assert_eq(int(config.get_value("params", "subpixel_positioning", -1)), 0, "subpixel_positioning is 0")
	assert_almost_eq(float(config.get_value("params", "oversampling", 0.0)), 1.0, 0.01, "oversampling is 1.0")
	assert_eq(bool(config.get_value("params", "multichannel_signed_distance_field", true)), false, "MSDF is false")

func test_runtime_sources_use_siege_pixel_only() -> void:
	var paths: Array[String] = ["res://assets/pixel/ui/game_theme.tres"]
	for directory: String in ["res://scripts", "res://scenes", "res://dev/scenarios"]:
		_collect_files(directory, paths)
	for path: String in paths:
		assert_false(FileAccess.get_file_as_string(path).contains("pixelify_sans.ttf"), path + " must not reference source font")
		assert_false(FileAccess.get_file_as_string(path).contains("siege_pixel.ttf"), path + " must use the no-ligature font wrapper")
	var hud := preload("res://scenes/ui/hud.tscn").instantiate()
	var label := hud.get_node("TopBar/Margin/HBox/Resources/WoodBox/Label") as Label
	var theme: Theme = load("res://assets/pixel/ui/game_theme.tres") as Theme
	assert_eq(label.label_settings.font, theme.default_font, "Explicit HUD font shares the theme's no-ligature font")
	hud.free()

func test_source_scan_no_uncrisp_font_size_literals() -> void:
	var scan_dirs: Array[String] = ["res://scripts", "res://scenes"]
	var files_to_scan: Array[String] = []

	for d in scan_dirs:
		_collect_files(d, files_to_scan)

	var override_regex := RegEx.new()
	override_regex.compile("add_theme_font_size_override\\s*\\(\\s*[\"']font_size[\"']\\s*,\\s*([a-zA-Z0-9_.]+)\\s*\\)")

	var tscn_regex := RegEx.new()
	tscn_regex.compile("theme_override_font_sizes/font_size\\s*=\\s*(\\d+)")

	var label_settings_regex := RegEx.new()
	label_settings_regex.compile("font_size\\s*=\\s*(\\d+)")

	for file_path in files_to_scan:
		var file := FileAccess.open(file_path, FileAccess.READ)
		if file == null:
			continue
		var content := file.get_as_text()
		var lines := content.split("\n")

		for line_idx in range(lines.size()):
			var line := lines[line_idx]
			if line.strip_edges().begins_with("#"):
				continue

			if file_path.ends_with(".gd"):
				var m := override_regex.search(line)
				if m != null:
					var arg := m.get_string(1).strip_edges()
					if arg.is_valid_int():
						var val := int(arg)
						assert_true(UiFont.is_crisp(val), "%s:%d literal font_size %d is not crisp" % [file_path, line_idx + 1, val])

			elif file_path.ends_with(".tscn"):
				var m1 := tscn_regex.search(line)
				if m1 != null:
					var val := int(m1.get_string(1))
					assert_true(UiFont.is_crisp(val), "%s:%d tscn font_size %d is not crisp" % [file_path, line_idx + 1, val])

				if line.contains("font_size"):
					var m2 := label_settings_regex.search(line)
					if m2 != null:
						var val := int(m2.get_string(1))
						assert_true(UiFont.is_crisp(val), "%s:%d font_size %d is not crisp" % [file_path, line_idx + 1, val])

func _collect_files(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while name != "":
		if not name.begins_with("."):
			var full_path := dir_path + "/" + name
			if dir.current_is_dir():
				_collect_files(full_path, out)
			elif name.ends_with(".gd") or name.ends_with(".tscn"):
				out.append(full_path)
		name = dir.get_next()
	dir.list_dir_end()
