extends TestCase

var _state: GameState

func before_each() -> void:
	_state = GameState.new(GameData.load_default(), 1337)
	_state.waves.enabled = false
	_state.clock.day = 5

func _lab() -> Building:
	return _state.buildings.add("field_lab", _state.map.command_center_origin() + Vector2i(4, 0), true)

func test_researcher_shared_dropdown_round_trip_and_roster_activity() -> void:
	var s: Survivor = _state.survivors.all()[0]
	assert_true(JobOptions.apply(_state, s.uid, 7))
	assert_eq(s.job, Survivor.Job.RESEARCHER)
	assert_eq(JobOptions.index_for(s), 7)
	var selection := SelectionController.new()
	selection.bind(_state)
	var roster := load("res://scenes/ui/roster_panel.tscn").instantiate() as RosterPanel
	roster.bind(_state, selection)
	roster.toggle()
	s.activity = Survivor.Activity.RESEARCHING
	var lab: Building = _lab()
	s.work_uid = lab.uid
	roster.refresh()
	var row: Node = roster._vbox.get_child(0)
	var options: OptionButton = row.get_child(1)
	assert_eq(options.get_item_count(), 8)
	assert_eq(options.get_item_text(7), "Research")
	assert_eq(options.selected, 7)
	assert_eq((row.get_child(2) as Label).text, "Researching · 1/2")
	options.item_selected.emit(6)
	assert_eq(s.job, Survivor.Job.GUARD)
	options.item_selected.emit(7)
	assert_eq(s.job, Survivor.Job.RESEARCHER)
	roster.free()
	selection.free()

func test_header_rate_hunger_morale_adjacency_suspension_and_night() -> void:
	var lab: Building = _lab()
	var people: Array[Survivor] = _state.survivors.all()
	for i: int in range(2):
		var s: Survivor = people[i]
		_state.set_job(s.uid, Survivor.Job.RESEARCHER)
		s.pos = Grid.tile_to_world(lab.origin + Vector2i(-1, i))
		s.path.clear()
		s.work_uid = lab.uid
		s.activity = Survivor.Activity.RESEARCHING
		s.morale = 50
	assert_almost_eq(TechTreeScreen.rate_per_day(_state), 20.0)
	people[0].hungry_days = 1
	people[1].morale = 30
	var expected: float = 10.0 * float(_state.data.balance("food_hungry_speed")) + 10.0 * Morale.work_mult(_state, people[1])
	assert_almost_eq(TechTreeScreen.rate_per_day(_state), expected)
	_state.clock.set_paused(true)
	assert_almost_eq(TechTreeScreen.rate_per_day(_state), expected, 0.0001, "potential rate remains visible while paused")
	people[0].day_off = true
	people[1].refusing = true
	assert_almost_eq(TechTreeScreen.rate_per_day(_state), 0.0)
	people[0].day_off = false
	people[0].pos = Grid.tile_to_world(lab.origin + Vector2i(-5, 0))
	assert_almost_eq(TechTreeScreen.rate_per_day(_state), 0.0)
	people[0].pos = Grid.tile_to_world(lab.origin + Vector2i(-1, 0))
	people[0].away = true
	assert_almost_eq(TechTreeScreen.rate_per_day(_state), 0.0)
	people[0].away = false
	_state.clock.phase = GameClock.Phase.NIGHT
	assert_almost_eq(TechTreeScreen.rate_per_day(_state), 0.0)

func test_effective_production_beds_info_and_build_cards_apply_immediately() -> void:
	_state._weather_day_cache_key = [_state.map_seed, _state.clock.day, _state.data.weather_config().hash()]
	_state._weather_day_cache_result = "clear"
	assert_eq(BuildInfoCard.output_line(_state.data, "farm", _state), "8 food / farmer / day")
	assert_eq(BuildInfoCard.output_line(_state.data, "workshop", _state), "12 ammo / scrap")
	assert_eq(BuildInfoCard.output_line(_state.data, "shelter", _state), "4 beds")
	_state.tech.done.append_array(["crop_rotation", "ammo_press", "bunk_beds"])
	assert_eq(BuildInfoCard.output_line(_state.data, "farm", _state), "10 food / farmer / day")
	assert_eq(BuildInfoCard.output_line(_state.data, "workshop", _state), "15 ammo / scrap")
	assert_eq(BuildInfoCard.output_line(_state.data, "shelter", _state), "6 beds")
	assert_true(BuildInfoCard.stats_line(_state.data, "shelter", _state).contains("+6 beds"))
	_state._weather_day_cache_result = "rain"
	assert_eq(BuildInfoCard.output_line(_state.data, "farm", _state), "15 food / farmer / day")
	var selection := SelectionController.new()
	selection.bind(_state)
	var info := load("res://scenes/ui/info_panel.tscn").instantiate() as InfoPanel
	info.bind(_state, selection)
	for id: String in ["workshop", "farm", "shelter", "field_lab"]:
		var b: Building = _state.buildings.add(id, Vector2i(4, 4), true)
		selection.select_building(b.uid)
		assert_true(info._workers_label.text.contains(BuildInfoCard.output_line(_state.data, id, _state)))
		if id == "field_lab":
			assert_true(info._workers_label.text.begins_with("Workers: 0/2"))
	info.free()
	selection.free()

func test_upgraded_tower_ground_ring_info_and_fog_preview_match_guard() -> void:
	_state.tech.done.append("spotters")
	var tower: Building = _state.buildings.add("watchtower", Vector2i(4, 4), true)
	var guard: Survivor = _state.survivors.all()[0]
	guard.job = Survivor.Job.GUARD
	guard.on_tower = true
	guard.post_uid = tower.uid
	var mode := BuildMode.new()
	mode.bind(_state)
	var selection := SelectionController.new()
	selection.bind(_state)
	var info := load("res://scenes/ui/info_panel.tscn").instantiate() as InfoPanel
	info.bind(_state, selection)
	_state.clock.day = 6
	_state.data.weather_config().fog.chance = 1.0
	_state.data.weather_config().fog.no_repeat = false
	for phase: int in [GameClock.Phase.DAY, GameClock.Phase.NIGHT]:
		_state.clock.phase = phase
		var expected: float = GuardJob.effective_range_px(_state, guard, tower)
		assert_almost_eq(float(mode.range_preview_for("watchtower", tower.origin, true).radius), expected)
		selection.select_building(tower.uid)
		assert_almost_eq(float(selection.range_preview().radius), expected)
		info.refresh()
		assert_true(info._range_label.text.begins_with("Range: %s tiles" % TechUpgradeCard.number(expected / Grid.TILE)))
		selection.select_survivor(guard.uid)
		assert_almost_eq(float(selection.range_preview().radius), expected)
	guard.on_tower = false
	guard.post_uid = 0
	assert_almost_eq(float(selection.range_preview().radius), GuardJob.effective_range_px(_state, guard))
	assert_almost_eq(float(mode.range_preview_for("watchtower", tower.origin, true).forecast_fog_radius_tiles), 8.0)
	info.free()
	selection.free()
	mode.free()

func test_lab_singleton_placement_reason_and_shelter_sized_night_light() -> void:
	var lab: Building = _lab()
	_state.resources.add("wood", 100)
	_state.resources.add("scrap", 100)
	assert_eq(Placement.result_text(Placement.check(_state, "field_lab", lab.origin + Vector2i(4, 0))), "Only one Field Lab")
	var lights := NightLights.new()
	lights.bind(_state)
	assert_true(lights._lights.has(lab.uid))
	var light: PointLight2D = lights._lights[lab.uid]
	assert_almost_eq(light.texture.get_width() * light.texture_scale / 2.0, 2.0 * Grid.TILE)
	assert_eq(light.color, NightLights.WARM_COLOR)
	_state.clock.phase = GameClock.Phase.NIGHT
	lights._process(0.0)
	assert_almost_eq(light.energy, 1.0)
	_state.buildings.remove(lab.uid)
	assert_false(lights._lights.has(lab.uid))
	lights.free()

func test_dawn_empty_active_completion_order_and_bank_floor() -> void:
	var report := {"research": {"active": "", "progress": 0.0, "cost": 0, "banked": 4.9, "done_today": []}}
	assert_eq(DawnReportPanel.research_rows(report, _state.tech.data), [["Research", "banked 4 RP"]] as Array[Array])
	report.research.done_today = ["spotters", "better_tools"]
	var rows: Array[Array] = DawnReportPanel.research_rows(report, _state.tech.data)
	assert_eq(rows[0], ["Research done", "Spotters, Better Tools"] as Array)
	report.research.active = "oiled_turrets"
	report.research.progress = 12.9
	report.research.cost = 35
	assert_eq(DawnReportPanel.research_rows(report, _state.tech.data)[1], ["Research", "Oiled Turrets 12/35"] as Array)
	assert_true(DawnReportPanel.research_rows({}, _state.tech.data).is_empty())

func test_research_hint_complete_only_one_shot_off_seen_and_how_to_play() -> void:
	var hints := TutorialHints.new()
	hints.shown = {"welcome": true, "farm": true, "night_soon": true, "ammo": true, "scavenge": true, "hungry": true, "radio": true, "spitters": true, "morale": true}
	var blueprint: Building = _state.buildings.add("field_lab", Vector2i(4, 4), false)
	assert_eq(hints.check(_state, 0.0), "")
	_state.buildings.finish(blueprint.uid)
	hints.enabled = false
	assert_eq(hints.check(_state, 0.0), "")
	hints.enabled = true
	assert_eq(hints.check(_state, 0.0), "research")
	assert_eq(hints.check(_state, 0.0), "")
	var restored := TutorialHints.new()
	restored.shown = hints.shown.duplicate(true)
	assert_eq(restored.check(_state, 0.0), "")
	assert_true(TutorialHints.text("research").contains("press T"))
	var help := load("res://scenes/ui/how_to_play.tscn").instantiate() as HowToPlay
	help.bind(_state.data)
	assert_eq(help.get_node(HowToPlay.CONTENT + "Scroll/Sections/Research").text, HowToPlay.research_text())
	assert_true(HowToPlay.research_text().contains("Radio Tower never needs it"))
	help.free()

func test_completion_toast_once_and_restored_done_do_not_replay() -> void:
	var hud: CanvasLayer = load("res://scenes/ui/hud.tscn").instantiate() as CanvasLayer
	hud.set("_state", _state)
	_state.tech.choose("spotters")
	_state.tech.add_points(20.0)
	assert_eq(hud.call("take_research_toasts"), ["Research done: Spotters"] as Array[String])
	assert_true(hud.call("take_research_toasts").is_empty())
	_state.tech.take_dawn_report(_state)
	assert_true(hud.call("take_research_toasts").is_empty())
	_state.tech.restore(_state.tech.capture())
	hud.set("_research_seen", {"spotters": true})
	assert_true(hud.call("take_research_toasts").is_empty())
	assert_eq(HudText.research_text(_state), "")
	_lab()
	assert_eq(HudText.research_text(_state), "Pick research")
	_state.tech.choose("oiled_turrets")
	_state.tech.add_points(12.75)
	assert_eq(HudText.research_text(_state), "Oiled Turrets 12/35")
	hud.free()

func test_real_hud_bind_does_not_toast_restored_research() -> void:
	_state.tech.restore({"done": ["spotters"]})
	var hud: CanvasLayer = load("res://scenes/ui/hud.tscn").instantiate() as CanvasLayer
	hud.set("top_bar", hud.get_node("TopBar"))
	for kind: String in ResourceStore.KINDS:
		var path: String = "TopBar/Margin/HBox/Resources/%sBox" % kind.capitalize()
		hud.set(kind + "_icon", hud.get_node(path + "/Icon"))
		hud.set(kind + "_label", hud.get_node(path + "/Label"))
	hud.set("day_label", hud.get_node("TopBar/Margin/HBox/DayArea/DayLabel"))
	hud.set("time_label", hud.get_node("TopBar/Margin/HBox/ClockArea/TimeLabel"))
	for item: String in ["Pause", "1x", "2x", "3x"]:
		hud.set("btn_" + item.to_lower(), hud.get_node("TopBar/Margin/HBox/ClockArea/SpeedButtons/Btn" + item))
	hud.call("_ready")
	hud.call("bind", _state)
	assert_eq((hud.get("_research_button") as Button).custom_minimum_size, Vector2(88, 40), "icon has space beside T")
	assert_eq((hud.get_node("ToastLayer") as CanvasLayer).layer, 19)
	assert_true(hud.get("_active_toasts").is_empty())
	assert_true(hud.call("take_research_toasts").is_empty())
	_state.tech.choose("oiled_turrets")
	_state.tech.add_points(35.0)
	hud.call("_process", 0.0)
	assert_eq(hud.get("_active_toasts").size(), 1)
	hud.call("_process", 0.0)
	assert_eq(hud.get("_active_toasts").size(), 1)
	hud.free()

func test_hint_seen_round_trips_dawn_save_and_panel_settings() -> void:
	var panel := load("res://scenes/ui/hint_panel.tscn").instantiate() as HintPanel
	panel.bind(_state)
	panel.set_shown({"research": true})
	panel.set_enabled(false)
	assert_eq(panel.get_shown(), {"research": true})
	panel.set_enabled(true)
	var save: Dictionary = SaveGame.capture(_state, {"hints": panel.get_shown()})
	assert_not_null(SaveGame.restore(_state.data, save))
	panel.set_shown(save.extra.hints)
	assert_true(panel.get_shown().has("research"))
	panel.show_hint("research")
	assert_true(panel.current_hint() == "research")
	assert_true(panel._label.text.contains("press T"))
	panel.set_enabled(false)
	assert_false(panel.is_showing())
	panel._process(0.0)
	panel.free()

func test_research_panel_and_hints_follow_real_hud_geometry_on_both_days() -> void:
	var root := Node.new()
	var hud: CanvasLayer = load("res://scenes/ui/hud.tscn").instantiate() as CanvasLayer
	root.add_child(hud)
	var roster := load("res://scenes/ui/roster_panel.tscn").instantiate() as RosterPanel
	root.add_child(roster)
	var hints := load("res://scenes/ui/hint_panel.tscn").instantiate() as HintPanel
	root.add_child(hints)
	var toggle: Button = roster.get_node("ToggleButton")
	hud.set("_state", _state)
	hud.set("_survivors_button", toggle)
	hud.call("_ensure_research_controls")
	toggle.item_rect_changed.connect(hud._layout_research_row)
	hud.call("_layout_research_row")
	hints.bind(_state)
	hints.show_hint("research")
	var row: HBoxContainer = hud.get_node("ResearchControls")
	var readout: Label = hud.get("_research_readout")
	var backing: PanelContainer = readout.get_parent() as PanelContainer
	assert_not_null(backing, "readout is backed by a panel")
	var style: StyleBoxTexture = backing.get_theme_stylebox("panel") as StyleBoxTexture
	assert_not_null(style, "readout uses the shared pixel panel")
	assert_eq(style.texture.resource_path, "res://assets/pixel/ui/x2/panel.png")
	assert_eq(row.get_child(0), hud.get("_research_button"), "T stays beside the readout")
	var unlock: int = int(_state.data.get_building("field_lab").unlock_day)
	_lab()
	_state.tech.restore({"done": ["spotters", "oiled_turrets"], "active": "reinforced_frames", "progress": {"reinforced_frames": 12.0}})
	for day: int in [unlock - 1, unlock, unlock - 1]:
		_state.clock.day = day
		hud.call("_refresh_research")
		assert_eq(row.visible, day >= unlock)
		assert_eq(readout.text, "Reinforced Frames 12/50")
		var expected_bottom: float = toggle.get_rect().end.y
		if row.visible:
			expected_bottom = row.position.y + maxf(row.size.y, row.get_combined_minimum_size().y)
		assert_almost_eq(hints._panel.position.y, expected_bottom + HintPanel.HUD_GAP)
		assert_true(hints._panel.position.y >= toggle.get_rect().end.y + HintPanel.HUD_GAP)
		# A moved/resized Survivors toggle and a taller row must move hints
		# through layout signals, without calling the hint process method.
		toggle.position.y += 10.0
		toggle.size.y += 4.0
		# Detached controls do not dispatch CanvasItem rect notifications.
		toggle.item_rect_changed.emit()
		assert_almost_eq(row.position.y, toggle.get_rect().end.y + 4.0)
		if row.visible:
			row.size.y += 20.0
			row.item_rect_changed.emit()
			expected_bottom = row.get_rect().end.y
		else:
			expected_bottom = toggle.get_rect().end.y
		assert_almost_eq(hints._panel.position.y, expected_bottom + HintPanel.HUD_GAP)
	root.free()
