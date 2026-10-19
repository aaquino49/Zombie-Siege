extends TestCase
## Morale 2 levers and bar: feast/day-off clicks with invalid cases,
## refusal refresh, sim departure de-dup, Campfire art/light, responsive
## 12-button bar with canonical F1-F9 and the 200 px bound at 1280x720.

var _state: GameState
var _data: GameData

func before_each() -> void:
	_data = GameData.load_default()
	_state = GameState.new(_data, 1337)
	_state.waves.enabled = false

func after_each() -> void:
	_data = null
	_state = null

# --- Feast clicks: success spends, re-click/night/cooldown/poor refuse. ---

func test_feast_click_spends_and_reclick_is_rejected() -> void:
	_state.clock.day = 5
	_state.resources.add("food", 1000)
	var before: int = _state.resources.get_amount("food")
	assert_true(Morale.hold_feast(_state))
	assert_eq(_state.last_feast_day, 5)
	assert_eq(_state.resources.get_amount("food"), before - 2 * _state.survivors.count())
	assert_false(Morale.hold_feast(_state), "cooldown re-click spends nothing")
	assert_eq(_state.resources.get_amount("food"), before - 2 * _state.survivors.count())
	assert_eq(Morale.feast_block_reason(_state), "Next feast: day 8")

func test_feast_block_reason_order() -> void:
	_state.game_over = true
	assert_eq(Morale.feast_block_reason(_state), "Game over")
	_state.game_over = false
	_state.clock.phase = GameClock.Phase.NIGHT
	assert_eq(Morale.feast_block_reason(_state), "Night")
	_state.clock.phase = GameClock.Phase.DAY
	_state.last_feast_day = _state.clock.day
	assert_eq(Morale.feast_block_reason(_state), "Next feast: day 4")
	_state.last_feast_day = 0
	_state.resources.take("food", _state.resources.get_amount("food"))
	assert_eq(Morale.feast_block_reason(_state), "Need 8 food")

func test_feast_button_click_toasts_only_on_success() -> void:
	var selection := SelectionController.new()
	selection.bind(_state)
	var panel := load("res://scenes/ui/info_panel.tscn").instantiate() as InfoPanel
	panel.bind(_state, selection)
	var cc: Building = _state.buildings.all_of_type("command_center")[0]
	selection.select_building(cc.uid)
	var feast_btn: Button = panel.get_node("PanelContainer/VBoxContainer/FeastButton") as Button
	_state.resources.add("food", 1000)
	feast_btn.emit_signal("pressed")
	assert_eq(_state.last_feast_day, _state.clock.day, "click holds the feast")
	var food_after: int = _state.resources.get_amount("food")
	feast_btn.emit_signal("pressed")
	assert_eq(_state.resources.get_amount("food"), food_after, "invalid re-click spends nothing")
	panel.free()
	selection.free()

# --- Day-off clicks: morning only, with ordered block reasons. ---

func test_day_off_click_and_invalid_cases() -> void:
	_state.clock.elapsed = 5.0
	var s: Survivor = _state.survivors.all()[0]
	assert_true(Morale.give_day_off(_state, s.uid))
	assert_true(s.day_off)
	assert_eq(Morale.day_off_block_reason(_state, s), "Already off")
	assert_false(Morale.give_day_off(_state, s.uid), "re-click rejected")
	var other: Survivor = _state.survivors.all()[1]
	_state.clock.elapsed = 28.0
	assert_eq(Morale.day_off_block_reason(_state, other), "Not morning")
	assert_false(Morale.give_day_off(_state, other.uid))
	_state.clock.elapsed = 5.0
	other.refusing = true
	assert_eq(Morale.day_off_block_reason(_state, other), "Refusing work")

func test_day_off_block_reason_order() -> void:
	var s: Survivor = _state.survivors.all()[0]
	_state.game_over = true
	assert_eq(Morale.day_off_block_reason(_state, s), "Game over")
	_state.game_over = false
	var ghost := Survivor.new()
	ghost.uid = 999999
	assert_eq(Morale.day_off_block_reason(_state, ghost), "Missing survivor")

func test_day_off_button_click_sets_flag() -> void:
	var selection := SelectionController.new()
	selection.bind(_state)
	var panel := load("res://scenes/ui/info_panel.tscn").instantiate() as InfoPanel
	panel.bind(_state, selection)
	_state.clock.elapsed = 5.0
	var s: Survivor = _state.survivors.all()[0]
	selection.select_survivor(s.uid)
	var day_off_btn: Button = panel.get_node("PanelContainer/VBoxContainer/SurvivorActions/DayOffButton") as Button
	day_off_btn.emit_signal("pressed")
	assert_true(s.day_off, "click gives the day off")
	panel.free()
	selection.free()

# --- Refusal refresh and sim departure de-dup. ---

func test_refusal_refresh_lists_names() -> void:
	var report := {"left": [] as Array}
	var people: Array[Survivor] = _state.survivors.all()
	people[0].morale = 10
	Morale._apply_breaking(_state, report)
	assert_true(people[0].refusing)
	Morale.refresh_report(_state, report)
	var refusing: Array = (report["morale"] as Dictionary)["refusing"]
	assert_true(refusing.has(people[0].name))

func test_sim_departure_writes_each_leaver_once() -> void:
	var people: Array[Survivor] = _state.survivors.all()
	for s: Survivor in people:
		s.morale = 5
	var report := {"left": [] as Array}
	Morale._apply_breaking(_state, report)
	Morale._apply_breaking(_state, report)
	var left: Array = report["left"]
	var left_morale: Array = report.get("left_morale", [])
	assert_eq(left.size(), 1, "at most one morale leaver per dawn")
	assert_eq(left, left_morale)
	assert_eq(_state.survivors.count(), people.size() - 1)

# --- Campfire: lit animation only when complete, unlit ghost otherwise. ---

func _campfire_spot() -> Vector2i:
	var origin: Vector2i = _state.map.command_center_origin()
	for candidate: Vector2i in [origin + Vector2i(-3, 2), origin + Vector2i(3, 2),
			origin + Vector2i(-3, -3), origin + Vector2i(3, -3)]:
		if _state.buildings.get_at(candidate) == null and _state.map.occupant_at(candidate) == WorldMap.Occupant.NONE:
			return candidate
	return origin + Vector2i(-3, 2)

func test_completed_campfire_animates_four_frames_at_6fps() -> void:
	var b: Building = _state.buildings.add("campfire", _campfire_spot(), true)
	var node: Node2D = BuildingSprites.make(_data, b, null)
	var sprite: AnimatedSprite2D = node.get_node_or_null("Sprite") as AnimatedSprite2D
	assert_not_null(sprite, "completed Campfire uses an AnimatedSprite2D")
	assert_true(sprite.is_playing())
	assert_eq(sprite.sprite_frames.get_frame_count("default"), 4)
	assert_eq(sprite.sprite_frames.get_animation_speed("default"), 6.0)
	assert_not_null(node.get_node_or_null("HpBar"), "HP bar kept")
	node.free()

func test_campfire_blueprint_is_static_unlit_ghost() -> void:
	var b: Building = _state.buildings.add("campfire", _campfire_spot(), false)
	var node: Node2D = BuildingSprites.make(_data, b, null)
	assert_not_null(node.get_node_or_null("ProgressFill"), "blueprint keeps its progress bar")
	var sprite: Sprite2D = node.get_node_or_null("Sprite") as Sprite2D
	assert_not_null(sprite, "blueprint uses a static sprite")
	assert_true(str(sprite.texture.resource_path).ends_with("campfire.png"), "unlit ghost texture")
	assert_false(str(sprite.texture.resource_path).ends_with("campfire_lit.png"), "never the lit strip")
	assert_eq(sprite.modulate, Color(0.6, 0.8, 1.0, 0.55), "ghost tint")
	node.free()

func test_campfire_light_is_small_warm_and_removed() -> void:
	var lights := NightLights.new()
	lights.bind(_state)
	var shelter: Building = _state.buildings.add("shelter", _campfire_spot(), true)
	var fire: Building = _state.buildings.add("campfire", _campfire_spot(), true)
	lights._add_light(shelter)
	lights._add_light(fire)
	var stored: Dictionary = lights.get("_lights")
	assert_true(stored.has(fire.uid), "complete Campfire casts light")
	var fire_light: PointLight2D = stored[fire.uid]
	assert_eq(fire_light.color, NightLights.WARM_COLOR)
	assert_eq(fire_light.texture_scale, (stored[shelter.uid] as PointLight2D).texture_scale * 0.75)
	lights._remove_light(fire)
	assert_false((lights.get("_lights") as Dictionary).has(fire.uid), "destroyed fire loses its light")
	var ghost: Building = _state.buildings.add("campfire", _campfire_spot(), false)
	lights._add_light(ghost)
	assert_false((lights.get("_lights") as Dictionary).has(ghost.uid), "blueprints cast no light")
	lights.free()

# --- Responsive build bar at day 8 with the Field Lab merged. ---

func _day_eight_bar() -> BuildBar:
	_state.clock.day = 8
	var bar := load("res://scenes/ui/build_bar.tscn").instantiate() as BuildBar
	bar.bind(_state)
	bar.refresh(8)
	return bar

func test_day_eight_bar_shows_twelve_buttons_in_two_rows() -> void:
	var bar: BuildBar = _day_eight_bar()
	var hb: GridContainer = bar.get_node("Panel/HBox") as GridContainer
	var order: Array[String] = []
	for child: Node in hb.get_children():
		order.append(str((child as Button).get_meta("type_id")))
	assert_eq(order, ["wooden_wall", "gate", "farm", "shelter", "campfire", "storage",
		"watchtower", "workshop", "lumber_yard", "field_lab", "turret", "radio_tower"] as Array[String])
	assert_eq(hb.columns, 6, "overflow splits into two rows of six")
	bar.free()

func test_fkeys_map_canonical_order() -> void:
	var bar: BuildBar = _day_eight_bar()
	assert_eq(bar._hotkey_for_type("wooden_wall"), "F1")
	assert_eq(bar._hotkey_for_type("campfire"), "F5")
	assert_eq(bar._hotkey_for_type("workshop"), "F8")
	assert_eq(bar._hotkey_for_type("lumber_yard"), "F9")
	assert_eq(bar._hotkey_for_type("field_lab"), "", "tenth button has no F-key")
	assert_eq(bar._hotkey_for_type("radio_tower"), "", "twelfth button has no F-key")
	bar.free()

func test_two_row_bar_stays_near_200px_at_1280() -> void:
	var bar: BuildBar = _day_eight_bar()
	var panel: PanelContainer = bar.get_node("Panel") as PanelContainer
	assert_lt(panel.get_combined_minimum_size().y, 201.0)
	bar.free()

func test_resize_relayouts_both_ways_preserving_selection_and_order() -> void:
	_state.clock.day = 8
	var bar := load("res://scenes/ui/build_bar.tscn").instantiate() as BuildBar
	bar.set_script(ResizableBar)
	bar.bind(_state)
	bar.set_active_type("campfire")
	var emissions: Array[String] = []
	bar.building_selected.connect(func(type_id: String) -> void: emissions.append(type_id))
	var expected: Array[String] = []
	for button: Button in bar._hbox().get_children():
		expected.append(str(button.get_meta("type_id")))
	for width: int in [1880, 1240, 1880, 1240]:
		bar.set("available_width", width)
		bar._on_viewport_size_changed()
		assert_eq(bar._hbox().columns, 12 if width == 1880 else 6)
		var actual: Array[String] = []
		for button: Button in bar._hbox().get_children():
			actual.append(str(button.get_meta("type_id")))
			assert_eq(button.button_pressed, button.get_meta("type_id") == "campfire")
		assert_eq(actual, expected, "resize keeps canonical child order")
		assert_eq(bar._active_type, "campfire")
		assert_eq(bar._hotkey_for_type("campfire"), "F5")
		assert_eq(bar._hotkey_for_type("lumber_yard"), "F9")
		if width == 1240:
			assert_lt(bar._panel().get_combined_minimum_size().y, 201.0)
		var first: Button = bar._hbox().get_child(0)
		bar._on_viewport_size_changed()
		assert_eq(bar._hbox().get_child(0), first, "unchanged width does not rebuild")
	assert_eq(emissions.size(), 0, "layout does not change the player's selection")
	bar.free()

class ResizableBar extends BuildBar:
	var available_width: int = 1240
	func _available_width() -> int:
		return available_width

func test_selected_info_panel_shrinks_after_survivor_selection() -> void:
	# Detached containers do not perform live layout passes. Model the
	# survivor -> building minimum-size change; the live fixture checks both.
	var panel := Control.new()
	panel.custom_minimum_size = Vector2(280, 160)
	panel.size = Vector2(280, 300) # height retained from the previous selection
	var survivor_height: float = panel.size.y
	BuildBar.position_above_bar(panel, 720.0, 512.0)
	assert_lt(panel.offset_bottom - panel.offset_top, survivor_height)
	assert_almost_eq(panel.offset_bottom - panel.offset_top, panel.get_combined_minimum_size().y, 0.01)
	assert_almost_eq(panel.offset_bottom, -216.0, 0.01)
	panel.free()

func test_info_card_sits_above_the_top_row() -> void:
	var bar: BuildBar = _day_eight_bar()
	var card: BuildInfoCard = bar.get_node("BuildInfoCard") as BuildInfoCard
	card.show_for(_data, _state.resources, "campfire", "F5")
	BuildBar.position_above_bar(card, 720.0, 520.0)
	assert_lt(card.offset_top, 520.0 - 8.0 - card.get_combined_minimum_size().y + 1.0)
	bar.free()

func test_push_to_hud_reuses_toast_queue() -> void:
	var mock := MockHud.new()
	assert_true(ScavengeToast.push_to_hud(mock, "Feast! Everyone +10 morale"))
	assert_eq(mock._toast_queue, [{"text": "Feast! Everyone +10 morale"}] as Array)
	assert_true(mock.pumped)
	assert_false(ScavengeToast.push_to_hud(mock, ""), "empty text is rejected")
	assert_false(ScavengeToast.push_to_hud(RefCounted.new(), "x"), "nodes without a toast queue are rejected")

class MockHud extends RefCounted:
	var _toast_queue: Array = []
	var pumped: bool = false
	func _pump_toasts() -> void:
		pumped = true
