extends TestCase
## T-218 QA: verify the second assignment UI and live, unstaffed previews.

var _state: GameState

func before_each() -> void:
	_state = GameState.new(GameData.load_default(), 1337)
	_state.waves.enabled = false
	_state.clock.day = 6

func test_info_dropdown_researcher_round_trip_and_live_slots() -> void:
	var selection := SelectionController.new()
	selection.bind(_state)
	var info := load("res://scenes/ui/info_panel.tscn").instantiate() as InfoPanel
	info.bind(_state, selection)
	var person: Survivor = _state.survivors.all()[0]
	selection.select_survivor(person.uid)
	assert_eq(info._job_btn.get_item_count(), 8)
	assert_eq(info._job_btn.get_item_text(7), "Researcher")
	info._job_btn.item_selected.emit(7)
	info._process(0.0)
	assert_eq(person.job, Survivor.Job.RESEARCHER)
	assert_eq(info._job_btn.selected, 7)
	var lab: Building = _state.buildings.add("field_lab", _state.map.command_center_origin() + Vector2i(4, 0), true)
	person.pos = Grid.tile_to_world(lab.origin + Vector2i(-1, 0))
	person.path.clear()
	ProductionJob.tick(_state, person, 0.0)
	info._process(0.0)
	assert_true(info._activity_label.text.contains("Researching"))
	assert_true(info._activity_label.text.contains("1/2"))
	info._job_btn.item_selected.emit(6)
	info._process(0.0)
	assert_eq(person.job, Survivor.Job.GUARD)
	assert_eq(info._job_btn.selected, 6)
	assert_eq(ProductionJob.workers_at(_state, lab), 0)
	info.free()
	selection.free()

func test_unstaffed_tower_ghost_ring_and_card_follow_live_spotters_and_fog() -> void:
	_state.data.weather_config().fog.chance = 1.0
	_state.data.weather_config().fog.no_repeat = false
	var tower: Building = _state.buildings.add("watchtower", Vector2i(4, 4), true)
	var mode := BuildMode.new()
	mode.bind(_state)
	var selection := SelectionController.new()
	selection.bind(_state)
	selection.select_building(tower.uid)
	var sample_guard := Survivor.new()
	sample_guard.on_tower = true
	for upgraded: bool in [false, true]:
		if upgraded:
			assert_true(_state.tech.choose("spotters"))
			_state.tech.add_points(float(_state.tech.data.upgrades.spotters.cost))
		for phase: int in [GameClock.Phase.DAY, GameClock.Phase.NIGHT]:
			_state.clock.phase = phase
			var expected: float = GuardJob.effective_range_px(_state, sample_guard, tower)
			assert_almost_eq(float(mode.range_preview_for("watchtower", tower.origin, true).radius), expected)
			assert_almost_eq(float(selection.range_preview().radius), expected)
			assert_true(BuildInfoCard.stats_line(_state.data, "watchtower", _state).contains("guard range %s tiles" % TechUpgradeCard.number(expected / Grid.TILE)))
	assert_almost_eq(float(mode.range_preview_for("watchtower", tower.origin, true).radius_tiles), 8.0)
	selection.free()
	mode.free()

func test_selected_production_and_beds_refresh_after_real_research_completion() -> void:
	_state._weather_day_cache_key = [_state.map_seed, _state.clock.day, _state.data.weather_config().hash()]
	_state._weather_day_cache_result = "clear"
	var selection := SelectionController.new()
	selection.bind(_state)
	var info := load("res://scenes/ui/info_panel.tscn").instantiate() as InfoPanel
	info.bind(_state, selection)
	var origin: Vector2i = _state.map.command_center_origin() + Vector2i(4, 0)
	for row: Array in [["farm", "crop_rotation", "10 food / farmer / day"], ["workshop", "ammo_press", "15 ammo / scrap"], ["shelter", "bunk_beds", "6 beds"]]:
		var building: Building = _state.buildings.add(str(row[0]), origin, true)
		selection.select_building(building.uid)
		var target: String = str(row[1])
		for id: String in _state.tech.data.upgrades:
			if _state.tech.data.upgrades[id].branch != _state.tech.data.upgrades[target].branch or int(_state.tech.data.upgrades[id].tier) > int(_state.tech.data.upgrades[target].tier) or _state.tech.is_done(id):
				continue
			assert_true(_state.tech.choose(id))
			_state.tech.add_points(float(_state.tech.data.upgrades[id].cost))
		info._process(0.0)
		assert_true(info._workers_label.text.contains(str(row[2])))
		assert_eq(BuildInfoCard.output_line(_state.data, str(row[0]), _state), str(row[2]))
		if row[0] == "shelter":
			assert_eq(_state.buildings.beds_for(building), 6)
		origin += Vector2i(3, 0)
	info.free()
	selection.free()
