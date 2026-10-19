extends TestCase
## T-109: preserve native 2x pixels in rendered frames and theme job popups.

func test_generated_copies_preserve_every_native_pixel() -> void:
	for filename: String in DirAccess.get_files_at("res://assets/pixel/ui"):
		if not filename.ends_with(".png"):
			continue
		var native := Image.load_from_file("res://assets/pixel/ui/" + filename)
		var doubled := Image.load_from_file("res://assets/pixel/ui/x2/" + filename)
		assert_not_null(native)
		assert_not_null(doubled)
		if native == null or doubled == null:
			continue
		native.resize(native.get_width() * 2, native.get_height() * 2, Image.INTERPOLATE_NEAREST)
		assert_eq(doubled.get_data(), native.get_data(), filename + " must be an exact nearest-neighbour copy")

func test_button_states_use_visibly_distinct_bitmaps() -> void:
	var theme: Theme = load("res://assets/pixel/ui/game_theme.tres") as Theme
	var images: Array[PackedByteArray] = []
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var style := theme.get_stylebox(state, "Button") as StyleBoxTexture
		assert_not_null(style)
		if style == null:
			continue
		images.append(style.texture.get_image().get_data())
	var toggle := theme.get_stylebox("pressed", "ToggleButton") as StyleBoxTexture
	assert_not_null(toggle)
	if toggle:
		images.append(toggle.texture.get_image().get_data())
	for a: int in range(images.size()):
		for b: int in range(a + 1, images.size()):
			assert_ne(images[a], images[b], "State textures must differ visually")

func test_theme_frames_tile_to_preserve_two_pixel_details() -> void:
	var theme: Theme = load("res://assets/pixel/ui/game_theme.tres") as Theme
	for type_name: StringName in [&"Panel", &"PanelContainer", &"Button", &"ToggleButton", &"OptionButton", &"TooltipPanel"]:
		for style_name: StringName in theme.get_stylebox_list(type_name):
			var style := theme.get_stylebox(style_name, type_name) as StyleBoxTexture
			if style == null:
				continue
			assert_eq(style.axis_stretch_horizontal, StyleBoxTexture.AXIS_STRETCH_MODE_TILE,
				"%s/%s must tile horizontally: stretching 2x frame details changes their pixel scale" % [type_name, style_name])
			assert_eq(style.axis_stretch_vertical, StyleBoxTexture.AXIS_STRETCH_MODE_TILE,
				"%s/%s must tile vertically to retain 2x frame details" % [type_name, style_name])

func test_hud_ninepatch_preserves_two_pixel_details() -> void:
	var hud: Node = preload("res://scenes/ui/hud.tscn").instantiate()
	var bar: NinePatchRect = hud.get_node("TopBar") as NinePatchRect
	assert_eq(bar.axis_stretch_horizontal, NinePatchRect.AXIS_STRETCH_MODE_TILE,
		"The 1280px HUD must tile its 2x frame rather than stretching the 40px centre to 1256px")
	assert_eq(bar.axis_stretch_vertical, NinePatchRect.AXIS_STRETCH_MODE_TILE,
		"The HUD must preserve 2x pixels vertically")
	hud.free()

func test_in_game_job_dropdown_has_pixel_panel() -> void:
	var info: Node = preload("res://scenes/ui/info_panel.tscn").instantiate()
	var option: OptionButton = info.get_node("PanelContainer/VBoxContainer/JobButton") as OptionButton
	var popup_style: StyleBox = option.get_popup().get_theme_stylebox("panel")
	assert_true(popup_style is StyleBoxTexture,
		"Opening an in-game job dropdown must show a pixel panel, not the default grey PopupMenu StyleBoxFlat")
	if popup_style is StyleBoxTexture:
		var texture_style := popup_style as StyleBoxTexture
		assert_true(texture_style.texture.resource_path.begins_with("res://assets/pixel/ui/x2/"),
			"Job dropdown must use the shared 2x pixel kit")
	info.free()

func test_build_selection_keeps_toggle_theme_after_affordability_refresh() -> void:
	var state := GameState.new(GameData.load_default(), 1337)
	var bar: BuildBar = preload("res://scenes/ui/build_bar.tscn").instantiate() as BuildBar
	bar.bind(state)
	bar.set_active_type("farm")
	state.resources.take("wood", state.resources.get_amount("wood"))
	for button: Button in bar._hbox().get_children():
		button.notification(Control.NOTIFICATION_THEME_CHANGED)
		assert_eq(button.theme_type_variation, &"ToggleButton")
		assert_eq(button.button_pressed, str(button.get_meta("type_id")) == "farm")
		if button.button_pressed:
			var style := button.get_theme_stylebox("pressed") as StyleBoxTexture
			assert_not_null(style)
			if style:
				assert_true(style.texture.resource_path.ends_with("x2/button_toggle_on.png"))
	bar.free()
