extends TestCase

var _state: GameState
var _bar: BuildBar

func before_each() -> void:
	_state = GameState.new(GameData.load_default(), 1337)
	_bar = preload("res://scenes/ui/build_bar.tscn").instantiate() as BuildBar
	_bar.bind(_state)

func after_each() -> void:
	if _bar != null:
		_bar.free()
	_bar = null
	_state = null

func _placeable_types() -> Array[String]:
	var out: Array[String] = []
	for id: String in _state.data.building_ids():
		if Placement.is_placeable_type(_state.data, id):
			out.append(id)
	return out

func test_every_placeable_has_name_blurb_stats() -> void:
	var types := _placeable_types()
	assert_true(types.size() > 0, "There are placeable buildings")
	for type_id: String in types:
		var lines: Array[String] = BuildInfoCard.lines_for(_state.data, _state.resources, type_id)
		assert_true(lines.size() >= 3, "%s yields name, blurb and stats" % type_id)
		if lines.size() >= 3:
			assert_true(lines[0].length() > 0, "%s name non-empty" % type_id)
			assert_true(lines[1].length() > 0, "%s blurb non-empty" % type_id)
			assert_true(lines[2].length() > 0, "%s stats non-empty" % type_id)
			assert_true(lines[2].contains("HP "), "%s stats show HP" % type_id)

func test_workshop_stats_contain_live_craft_time() -> void:
	var craft: String = str(int(_state.data.get_building("workshop").get("craft_time")))
	var stats: String = BuildInfoCard.stats_line(_state.data, "workshop")
	assert_true(stats.contains(craft), "Workshop stats contain craft_time %s: %s" % [craft, stats])
	assert_true(stats.contains("ammo every"), "Workshop stats mention ammo timing: %s" % stats)

func test_shelter_shows_beds() -> void:
	var stats: String = BuildInfoCard.stats_line(_state.data, "shelter")
	assert_true(stats.contains("+4 beds"), "Shelter stats show +4 beds: %s" % stats)

func test_turret_range_and_workers_phrasing() -> void:
	var turret_stats: String = BuildInfoCard.stats_line(_state.data, "turret")
	var expected_range: String = "range %d tiles" % int(_state.data.get_building("turret").get("range_tiles"))
	assert_true(turret_stats.contains(expected_range), "Turret stats show %s: %s" % [expected_range, turret_stats])
	assert_true(BuildInfoCard.stats_line(_state.data, "farm").contains("up to 2 workers"), "Farm shows up to 2 workers")
	assert_true(BuildInfoCard.stats_line(_state.data, "watchtower").contains("1 worker"), "Watchtower shows 1 worker")

func test_unaffordable_need_exact_short() -> void:
	# Shelter costs 30 wood: leave exactly 5 short.
	var have: int = _state.resources.get_amount("wood")
	_state.resources.take("wood", have - 25)
	var need: String = BuildInfoCard.need_line(_state.data, _state.resources, "shelter")
	assert_eq(need, "Need 5 more wood")
	var lines: Array[String] = BuildInfoCard.lines_for(_state.data, _state.resources, "shelter")
	assert_eq(lines[lines.size() - 1], "Need 5 more wood")

func test_affordable_has_no_need_line() -> void:
	_state.resources.add("wood", 500)
	_state.resources.add("scrap", 500)
	assert_eq(BuildInfoCard.need_line(_state.data, _state.resources, "wooden_wall"), "")
	var lines: Array[String] = BuildInfoCard.lines_for(_state.data, _state.resources, "wooden_wall")
	assert_false(lines[lines.size() - 1].begins_with("Need "), "Affordable type gets no Need line")

func test_unknown_and_missing_blurb_no_crash() -> void:
	var unknown: Array[String] = BuildInfoCard.lines_for(_state.data, _state.resources, "nope_unknown")
	assert_true(unknown.size() >= 1, "Unknown type still returns a line")
	_state.data._buildings["farm"].erase("blurb")
	var lines: Array[String] = BuildInfoCard.lines_for(_state.data, _state.resources, "farm")
	assert_true(lines.size() >= 2, "Missing blurb does not crash")
	assert_true(lines[0].length() > 0, "Name still present without blurb")

func test_hover_falls_back_to_active_or_hides() -> void:
	_bar.set_active_type("farm")
	_bar._on_btn_hovered("shelter")
	assert_eq(_bar._card().current_type(), "shelter")
	assert_true(_bar._card().visible, "Hover shows its card")
	_bar._on_btn_unhovered()
	assert_eq(_bar._card().current_type(), "farm", "Leaving falls back to selected type")
	assert_true(_bar._card().visible, "Fallback card is visible")
	_bar.set_active_type("")
	_bar.show_info("shelter")
	assert_true(_bar._card().visible, "Hover card shows without selection")
	_bar._on_btn_unhovered()
	assert_false(_bar._card().visible, "Leaving with no selection hides")

func test_build_menu_hides_bar_and_card() -> void:
	_bar.set_active_type("farm")
	assert_true(_bar._card().visible, "Card shows for active type")
	var event := InputEventAction.new()
	event.action = "build_menu"
	event.pressed = true
	_bar._unhandled_input(event)
	assert_false(_bar._panel().visible, "B hides the bar")
	assert_false(_bar._card().visible, "B hides the card together")
	_bar._unhandled_input(event)
	assert_true(_bar._panel().visible, "B shows the bar again")

func test_button_tooltips_empty() -> void:
	for child in _bar._hbox().get_children():
		var btn := child as Button
		assert_eq(btn.tooltip_text, "", "No tiny Godot tooltip for %s" % btn.get_meta("type_id"))

func test_card_fonts_sizes_wrap_and_filters() -> void:
	var card := BuildInfoCard.new()
	card.show_for(_state.data, _state.resources, "turret")
	var vbox := card.get_node("VBox") as VBoxContainer
	assert_not_null(vbox, "Card builds a VBox")
	assert_true(vbox.custom_minimum_size.x <= BuildInfoCard.MAX_WIDTH, "Card width at most 420 px")
	assert_eq(card.mouse_filter, Control.MOUSE_FILTER_IGNORE, "Card ignores the mouse")
	assert_eq((vbox.get_node("Name") as Label).get_theme_font_size("font_size"), UiFont.LARGE)
	assert_eq((vbox.get_node("Blurb") as Label).get_theme_font_size("font_size"), UiFont.BODY)
	assert_eq((vbox.get_node("Stats") as Label).get_theme_font_size("font_size"), UiFont.BODY)
	assert_eq((vbox.get_node("Need") as Label).get_theme_font_size("font_size"), UiFont.BODY)
	for label_name: String in ["Name", "Blurb", "Stats", "Need"]:
		var lbl := vbox.get_node(label_name) as Label
		assert_eq(lbl.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART, "%s wraps at whole words" % label_name)
		assert_eq(lbl.mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s ignores the mouse" % label_name)
	card.free()

func test_refresh_on_resource_change() -> void:
	_state.resources.add("wood", 500)
	_state.resources.add("scrap", 500)
	_bar.set_active_type("shelter")
	var vbox := _bar._card().get_node("VBox") as VBoxContainer
	assert_false((vbox.get_node("Need") as Label).visible, "Affordable shelter shows no Need")
	_state.resources.take("wood", _state.resources.get_amount("wood"))
	assert_true((vbox.get_node("Need") as Label).visible, "Need line refreshes when resources change")
	assert_true((vbox.get_node("Need") as Label).text.begins_with("Need "), "Refreshed Need text")

func test_pause_menu_lock_hides_card() -> void:
	_bar.set_active_type("farm")
	assert_true(_bar._card().visible, "Card visible before pause")
	_state.clock.locked = true
	_state.clock.set_paused(true)
	_bar._process(0.0)
	assert_false(_bar._card().visible, "Pause-menu lock hides the card")
	_state.clock.locked = false
	_state.clock.set_paused(false)
