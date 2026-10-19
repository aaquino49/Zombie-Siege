extends TestCase

func test_all_menus_share_theme_typography_and_button_dimensions() -> void:
	for scene_name: String in ["main_menu", "pause_menu", "dawn_report", "game_over", "victory", "settings_screen", "how_to_play", "credits_screen"]:
		var menu: CanvasLayer = load("res://scenes/ui/" + scene_name + ".tscn").instantiate()
		var prefix: String = "Center/Panel" if scene_name == "dawn_report" else "Dim/Center/Panel"
		var panel: PanelContainer = menu.get_node(prefix)
		var content: Control = panel.get_node("Margin/Content")
		var color: Color = MenuStyle.BLOOD if scene_name == "game_over" else MenuStyle.NEUTRAL if scene_name == "pause_menu" else MenuStyle.CREAM
		MenuStyle.apply(content, color, scene_name == "main_menu")
		assert_false(panel.has_theme_stylebox_override("panel"), scene_name + " inherits pixel panel")
		assert_almost_eq(menu.get_node("Dim").color.a, 0.24 if scene_name == "main_menu" else 0.55)
		var title: Label = content.get_node("Title")
		assert_eq(title.get_theme_font_size("font_size"), UiFont.BANNER if scene_name == "main_menu" else UiFont.TITLE)
		assert_eq(title.get_theme_color("font_color"), color)
		assert_eq(title.get_theme_color("font_outline_color"), MenuStyle.INK)
		var buttons: VBoxContainer = content.get_node("Buttons")
		for button: Button in buttons.get_children():
			assert_eq(button.custom_minimum_size, MenuStyle.BUTTON_SIZE)
			assert_eq(button.get_theme_font_size("font_size"), UiFont.BODY)
		menu.free()

func test_dawn_grid_preserves_every_report_value_and_wraps_long_names() -> void:
	var report: Dictionary = {"zombies_killed": 25, "cc_damage": 40,
		"survivors_killed": ["Avery", "Brook", "Casey"], "food_eaten": 4,
		"objective": "Build the Radio Tower. 19 nights to go."}
	var rows: Array[Array] = DawnReportPanel.report_rows(report)
	assert_eq(rows, [["Zombies killed", "25"], ["Lost", "Avery, Brook, Casey"],
		["Command Center damage", "40"], ["Food eaten", "4"],
		["Objective", "Build the Radio Tower. 19 nights to go."]] as Array[Array])
	var grid := GridContainer.new()
	grid.columns = 2
	MenuStyle.fill_stats(grid, rows)
	assert_eq(grid.get_child_count(), 10)
	for index: int in range(rows.size()):
		var value: Label = grid.get_child(index * 2 + 1)
		assert_eq(value.text, rows[index][1])
		assert_eq(value.horizontal_alignment, HORIZONTAL_ALIGNMENT_RIGHT)
		assert_eq(value.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART)
	grid.free()
