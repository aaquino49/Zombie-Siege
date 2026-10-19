extends TestCase

var _state: GameState
var _selection: SelectionController
var _info: InfoPanel
var _hud: CanvasLayer
var _weather_layer: WeatherLayer

func before_each() -> void:
	_state = GameState.new(GameData.load_default(), 1337)
	_selection = SelectionController.new()
	_selection.bind(_state)
	_info = (load("res://scenes/ui/info_panel.tscn") as PackedScene).instantiate() as InfoPanel
	_info.bind(_state, _selection)
	_hud = (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate() as CanvasLayer
	_hud.set("_state", _state)
	_hud.set("rain_tag", _hud.get_node("TopBar/Margin/HBox/DayArea/RainTag"))
	_weather_layer = WeatherLayer.new()
	_weather_layer.bind(_state)

func after_each() -> void:
	_hud.free()
	_info.free()
	_selection.free()
	_weather_layer.free()
	_state = null

func _seed_for_day_weather(wanted: String, day: int) -> int:
	for seed: int in range(10000):
		if Weather.day_weather(_state.data, seed, day) == wanted:
			return seed
	return 0

func _seed_for_night_weather(wanted: String, night: int) -> int:
	for seed: int in range(10000):
		if Weather.night_weather(_state.data, seed, night) == wanted:
			return seed
	return 0

func _add_turret() -> Building:
	var origin: Vector2i = _state.map.command_center_origin() + Vector2i(6, 0)
	return _state.buildings.add("turret", origin, true)

func test_weather_layer_selects_only_rain_day_and_fog_night() -> void:
	_state.clock.day = 3
	_state.map_seed = _seed_for_day_weather("rain", 3)
	_weather_layer._refresh_target()
	assert_eq(_weather_layer._target_kind, "rain")
	assert_almost_eq(_weather_layer._target_opacity, WeatherLayer.RAIN_ALPHA)
	_state.clock.phase = GameClock.Phase.NIGHT
	_weather_layer._refresh_target()
	assert_eq(_weather_layer._target_kind, "")
	_state.clock.day = 5
	_state.map_seed = _seed_for_night_weather("fog", 5)
	_weather_layer._refresh_target()
	assert_eq(_weather_layer._target_kind, "fog")
	assert_almost_eq(_weather_layer._target_opacity, WeatherLayer.FOG_ALPHA)
	_state.clock.phase = GameClock.Phase.DAY
	_weather_layer._refresh_target()
	assert_eq(_weather_layer._target_kind, "")

func test_rain_tag_uses_data_multiplier_and_is_hidden_otherwise() -> void:
	_state.clock.day = 3
	_state.map_seed = _seed_for_day_weather("rain", 3)
	_hud.call("_refresh_rain_tag")
	var tag: Label = _hud.get("rain_tag")
	assert_true(tag.visible)
	assert_eq(tag.text, "Rain: farms +50%")
	_state.clock.phase = GameClock.Phase.NIGHT
	_hud.call("_refresh_rain_tag")
	assert_false(tag.visible)
	_state.clock.phase = GameClock.Phase.DAY
	_state.map_seed = _seed_for_day_weather("clear", 3)
	_hud.call("_refresh_rain_tag")
	assert_false(tag.visible)

func test_rain_tag_matches_top_bar_pixel_font_and_body_size() -> void:
	var day_label: Label = _hud.get_node("TopBar/Margin/HBox/DayArea/DayLabel") as Label
	var tag: Label = _hud.get_node("TopBar/Margin/HBox/DayArea/RainTag") as Label
	assert_eq(tag.label_settings.font, day_label.label_settings.font)
	assert_eq(tag.label_settings.font_size, UiFont.BODY)

func test_selected_turret_range_and_info_forecast_follow_fog() -> void:
	var turret: Building = _add_turret()
	_selection.select_building(turret.uid)
	_state.clock.day = 5
	_state.clock.phase = GameClock.Phase.DAY
	_state.map_seed = _seed_for_night_weather("fog", 5)
	var clear_preview: Dictionary = _selection.range_preview()
	assert_eq(float(clear_preview["radius_tiles"]), 6.0, "day ring stays clear range")
	_info.refresh()
	assert_eq(_info._range_label.text, "Range: 6 tiles · 5 in fog tonight")
	_state.clock.day = 5
	_state.map_seed = _seed_for_night_weather("fog", 5)
	_state.clock.phase = GameClock.Phase.NIGHT
	var fog_preview: Dictionary = _selection.range_preview()
	assert_eq(float(fog_preview["radius_tiles"]), 5.0, "night ring uses fogged range")
	_info.refresh()
	assert_eq(_info._range_label.text, "Range: 5 tiles")

func test_build_ghost_ring_stays_clear_by_day_and_fogs_at_night() -> void:
	var mode := BuildMode.new()
	mode.bind(_state)
	var origin: Vector2i = _state.map.command_center_origin() + Vector2i(7, 2)
	_state.clock.day = 5
	_state.map_seed = _seed_for_night_weather("fog", 5)
	_state.clock.phase = GameClock.Phase.DAY
	assert_eq(float(mode.range_preview_for("turret", origin, true)["radius_tiles"]), 6.0)
	_state.clock.phase = GameClock.Phase.NIGHT
	assert_eq(float(mode.range_preview_for("turret", origin, true)["radius_tiles"]), 5.0)
	mode.free()

func test_rain_tag_recomputes_bonus_from_changed_data() -> void:
	_state.clock.day = 3
	_state.map_seed = _seed_for_day_weather("rain", 3)
	_state.data.weather_config()["rain"]["farm_mult"] = 1.75
	_hud.call("_refresh_rain_tag")
	var tag: Label = _hud.get("rain_tag")
	assert_true(tag.visible)
	assert_eq(tag.text, "Rain: farms +75%", "tag must follow balance data")

func test_weather_layer_fades_and_clears_on_phase_changes() -> void:
	_state.data.weather_config()["rain"]["chance"] = 1.0
	_state.data.weather_config()["fog"]["chance"] = 0.0
	_state.clock.day = 3
	_weather_layer._process(0.5)
	assert_eq(_weather_layer._display_kind, "rain")
	assert_gt(_weather_layer._opacity, 0.0)
	assert_lt(_weather_layer._opacity, WeatherLayer.RAIN_ALPHA, "rain fades in")
	_weather_layer._process(1.0)
	assert_almost_eq(_weather_layer._opacity, WeatherLayer.RAIN_ALPHA)
	_state.clock.phase = GameClock.Phase.NIGHT
	_weather_layer._process(2.0)
	assert_eq(_weather_layer._display_kind, "")
	assert_almost_eq(_weather_layer._opacity, 0.0, 0.00001, "clear night removes rain")
	_state.data.weather_config()["rain"]["chance"] = 0.0
	_state.data.weather_config()["fog"]["chance"] = 1.0
	_state.data.weather_config()["fog"]["no_repeat"] = false
	_state.clock.day = 5
	_weather_layer._process(2.0)
	assert_eq(_weather_layer._display_kind, "fog")
	assert_almost_eq(_weather_layer._opacity, WeatherLayer.FOG_ALPHA)
	assert_lt(_weather_layer._opacity, 0.25, "fog preserves entity contrast")
	_state.clock.day = 6
	_state.clock.phase = GameClock.Phase.DAY
	_weather_layer._process(2.0)
	assert_eq(_weather_layer._display_kind, "")
	assert_almost_eq(_weather_layer._opacity, 0.0, 0.00001, "clear dawn removes fog")

func test_rain_to_fog_transition_never_renders_over_fog_alpha_cap() -> void:
	_state.map_seed = 58
	_state.clock.day = 5
	_state.clock.phase = GameClock.Phase.DAY
	assert_eq(Weather.day_weather(_state.data, 58, 5), "rain")
	assert_eq(Weather.night_weather(_state.data, 58, 5), "fog")
	_weather_layer._process(2.0)
	assert_eq(_weather_layer._display_kind, "rain")
	_state.clock.phase = GameClock.Phase.NIGHT
	_weather_layer._process(1.0 / 60.0)
	assert_eq(_weather_layer._display_kind, "fog")
	assert_gt(_weather_layer._opacity, WeatherLayer.FOG_ALPHA, "transition state retains the fade")
	assert_true(_weather_layer._rendered_fog_alpha() <= 0.25, "first fog frame is capped")
	for frame: int in range(60):
		_weather_layer._process(1.0 / 60.0)
		assert_true(_weather_layer._rendered_fog_alpha() <= 0.25, "fog transition frame %d is capped" % frame)

func test_guard_and_tower_ranges_forecast_and_clear_night() -> void:
	_state.clock.day = 5
	_state.data.weather_config()["fog"]["chance"] = 1.0
	_state.data.weather_config()["fog"]["no_repeat"] = false
	var delta_tiles: float = float(_state.data.weather_config()["fog"]["range_delta_tiles"])
	var base_tiles: float = float(_state.data.balance("guard_range_tiles"))
	var guard: Survivor = _state.survivors.all()[0]
	guard.job = Survivor.Job.GUARD
	guard.post_uid = 0
	_selection.select_survivor(guard.uid)
	assert_almost_eq(float(_selection.range_preview()["radius"]), base_tiles * Grid.TILE)
	_info.refresh()
	assert_eq(_info._range_label.text, "Range: 5 tiles · 4 in fog tonight")
	_state.clock.phase = GameClock.Phase.NIGHT
	assert_almost_eq(float(_selection.range_preview()["radius"]), (base_tiles + delta_tiles) * Grid.TILE)
	_info.refresh()
	assert_eq(_info._range_label.text, "Range: 4 tiles")
	var tower: Building = _state.buildings.add("watchtower", _state.map.command_center_origin() + Vector2i(6, 0), true)
	var tower_tiles: float = base_tiles * float(_state.data.get_building("watchtower")["guard_range_mult"])
	_selection.select_building(tower.uid)
	assert_almost_eq(float(_selection.range_preview()["radius"]), (tower_tiles + delta_tiles) * Grid.TILE)
	_info.refresh()
	assert_eq(_info._range_label.text, "Range: 6.5 tiles")
	guard.post_uid = tower.uid
	_selection.select_survivor(guard.uid)
	assert_almost_eq(float(_selection.range_preview()["radius"]), (tower_tiles + delta_tiles) * Grid.TILE)
	var mode := BuildMode.new()
	mode.bind(_state)
	assert_almost_eq(float(mode.range_preview_for("watchtower", tower.origin, true)["radius"]), (tower_tiles + delta_tiles) * Grid.TILE)
	_state.clock.day = 6
	_state.data.weather_config()["fog"]["chance"] = 0.0
	assert_almost_eq(float(_selection.range_preview()["radius"]), tower_tiles * Grid.TILE, 0.00001, "clear night restores tower range")
	assert_almost_eq(float(mode.range_preview_for("watchtower", tower.origin, true)["radius"]), tower_tiles * Grid.TILE)
	_info.refresh()
	assert_eq(_info._range_label.text, "Range: 7.5 tiles")
	_state.clock.phase = GameClock.Phase.DAY
	_info.refresh()
	assert_eq(_info._range_label.text, "Range: 7.5 tiles", "clear forecast has no fog suffix")
	mode.free()

func test_turret_preview_uses_custom_range_and_fog_data() -> void:
	_state.data.get_building("turret")["range_tiles"] = 6.25
	_state.data.weather_config()["fog"]["range_delta_tiles"] = -2.0
	_state.data.weather_config()["fog"]["chance"] = 1.0
	_state.data.weather_config()["fog"]["no_repeat"] = false
	_state.clock.day = 5
	_state.clock.phase = GameClock.Phase.NIGHT
	var turret: Building = _add_turret()
	_selection.select_building(turret.uid)
	assert_almost_eq(float(_selection.range_preview()["radius"]), Combat.turret_range_px(_state))
	assert_almost_eq(float(_selection.range_preview()["radius_tiles"]), 4.25)
	var mode := BuildMode.new()
	mode.bind(_state)
	assert_almost_eq(float(mode.range_preview_for("turret", turret.origin, true)["radius"]), Combat.turret_range_px(_state))
	mode.free()
