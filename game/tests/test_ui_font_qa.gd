extends TestCase
## T-122: button bounds alone do not prove their clipped child captions fit.

func test_day2_build_captions_fit_without_clipping() -> void:
	_check_build_captions(2)

func test_victory_day_build_captions_fit_without_clipping() -> void:
	# The required Victory capture uses day 21 and the fully unlocked build bar.
	_check_build_captions(21)

func test_day2_build_name_rows_reserve_a_full_text_line() -> void:
	_check_build_name_line_heights(2)

func test_victory_build_name_rows_reserve_a_full_text_line() -> void:
	_check_build_name_line_heights(21)

func _check_build_name_line_heights(day: int) -> void:
	var state := GameState.new(GameData.load_default(), 1337)
	state.clock.day = day
	var bar := preload("res://scenes/ui/build_bar.tscn").instantiate() as BuildBar
	bar.bind(state)
	for button: Button in bar._hbox().get_children():
		var content := button.get_node("Content") as VBoxContainer
		for child: Control in content.get_children():
			if not child is Label or (child.name != &"Name" and not str(child.name).begins_with("NameContinuation")):
				continue
			var label := child as Label
			label.notification(Control.NOTIFICATION_THEME_CHANGED)
			# Off-tree containers never sort. Compare the row's reserved minimum
			# against an equivalent unwrapped label's intrinsic single-line height.
			var probe := Label.new()
			probe.text = label.text
			probe.add_theme_font_override("font", label.get_theme_font("font"))
			probe.add_theme_font_size_override("font_size", label.get_theme_font_size("font_size"))
			probe.notification(Control.NOTIFICATION_THEME_CHANGED)
			var required_height: float = probe.get_minimum_size().y
			var reserved_height: float = maxf(label.get_minimum_size().y, label.custom_minimum_size.y)
			assert_true(reserved_height >= required_height,
				"Day %d %s %s '%s' reserves %.1fpx but a complete text line needs %.1fpx" %
				[day, button.get_meta("type_id"), label.name, label.text, reserved_height, required_height])
			probe.free()
	bar.free()

func _check_build_captions(day: int) -> void:
	var state := GameState.new(GameData.load_default(), 1337)
	state.clock.day = day
	var bar := preload("res://scenes/ui/build_bar.tscn").instantiate() as BuildBar
	bar.bind(state)
	for button: Button in bar._hbox().get_children():
		button.notification(Control.NOTIFICATION_THEME_CHANGED)
		var available: Vector2 = button.get_minimum_size().max(button.custom_minimum_size)
		var content := button.get_node("Content") as VBoxContainer
		var content_height: float = 0.0
		for child: Control in content.get_children():
			child.notification(Control.NOTIFICATION_THEME_CHANGED)
			content_height += child.get_minimum_size().max(child.custom_minimum_size).y
			if child is Label:
				var label := child as Label
				var font: Font = label.get_theme_font("font")
				var font_size: int = label.get_theme_font_size("font_size")
				var text_width: float = 0.0
				for line in label.text.split("\n"):
					text_width = maxf(text_width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
				if label.name == "Name":
					var building_name: String = state.data.get_building(str(button.get_meta("type_id"))).get("name", "")
					var displayed_lines: Array[String] = []
					for name_row: Control in content.get_children():
						if name_row is Label and (name_row.name == &"Name" or str(name_row.name).begins_with("NameContinuation")):
							var row := name_row as Label
							displayed_lines.append(row.text)
							var row_font: Font = row.get_theme_font("font")
							var probe := Label.new()
							probe.text = row.text
							probe.add_theme_font_override("font", row_font)
							probe.add_theme_font_size_override("font_size", UiFont.BODY)
							probe.notification(Control.NOTIFICATION_THEME_CHANGED)
							assert_true(row.custom_minimum_size.y >= probe.get_minimum_size().y,
								"Day %d %s name row must reserve a full BODY line" % [day, button.get_meta("type_id")])
							probe.free()
					var displayed_name := " ".join(displayed_lines) if building_name.contains(" ") else "".join(displayed_lines)
					assert_eq(displayed_name.replace(" ", ""), building_name.replace(" ", ""),
						"Name caption must preserve the complete building name")
					assert_true(text_width <= available.x,
						"Day %d %s %s caption '%s' needs %.1fpx but clipped parent provides %.1fpx" %
						[day, button.get_meta("type_id"), label.name, label.text, text_width, available.x])
				else:
					assert_true(text_width <= available.x,
						"Day %d %s %s caption '%s' needs %.1fpx but clipped parent provides %.1fpx" %
						[day, button.get_meta("type_id"), label.name, label.text, text_width, available.x])
		content_height += content.get_theme_constant("separation") * maxi(0, content.get_child_count() - 1)
		assert_true(content_height <= available.y,
			"Day %d %s child content must fit button height" % [day, button.get_meta("type_id")])
	bar.free()
