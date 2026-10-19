extends TestCase

func test_live_title_replaces_static_art_behind_dim() -> void:
	var scene: PackedScene = load("res://scenes/ui/main_menu.tscn")
	var menu: MainMenu = scene.instantiate() as MainMenu
	var title: TitleScene = menu.get_node("TitleScene")
	var dim: ColorRect = menu.get_node("Dim")
	assert_true(menu.get_node_or_null("TitleArt") == null, "Static Kenney title removed")
	assert_eq(title.get_index(), 0, "Diorama sits behind Dim and buttons")
	assert_lt(title.get_index(), dim.get_index())
	assert_eq(title.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(title.stretch_shrink, 4)
	assert_almost_eq(dim.color.a, 0.24)
	menu.call("_ready")
	assert_eq(title.process_mode, Node.PROCESS_MODE_DISABLED, "Hidden menu stops backdrop")
	menu.visible = true
	assert_eq(title.process_mode, Node.PROCESS_MODE_INHERIT)
	menu.visible = false
	assert_eq(title.get_node("Viewport").render_target_update_mode, SubViewport.UPDATE_DISABLED)
	menu.free()

func test_project_app_icon_setting() -> void:
	var icon_setting: Variant = ProjectSettings.get_setting("application/config/icon")
	assert_eq(icon_setting, "res://assets/icon/icon.png", "application/config/icon setting must point to res://assets/icon/icon.png")
