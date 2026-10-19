extends TestCase

var _state: GameState
var _mode: BuildMode
var _selection: SelectionController
var _info: InfoPanel

func before_each() -> void:
	_state = GameState.new(GameData.load_default(), 188)
	_mode = BuildMode.new()
	_mode.bind(_state)
	_selection = SelectionController.new()
	_selection.bind(_state)
	_info = (load("res://scenes/ui/info_panel.tscn") as PackedScene).instantiate() as InfoPanel
	_info.bind(_state, _selection)

func after_each() -> void:
	_info.free()
	_selection.free()
	_mode.free()

func test_placement_rings_use_data_radius_and_validity_color() -> void:
	var origin: Vector2i = _state.map.command_center_origin() + Vector2i(5, 0)
	var turret: Dictionary = _mode.range_preview_for("turret", origin, true)
	assert_eq(float(turret["radius"]), float(_state.data.get_building("turret")["range_tiles"]) * Grid.TILE)
	assert_eq(turret["center"], Grid.tile_to_world(origin))
	assert_eq(turret["color"], Color(0.2, 1.0, 0.35))
	var invalid_tower: Dictionary = _mode.range_preview_for("watchtower", origin, false)
	var expected_tower_tiles: float = float(_state.data.balance("guard_range_tiles")) * float(_state.data.get_building("watchtower")["guard_range_mult"])
	assert_eq(float(invalid_tower["radius"]), expected_tower_tiles * Grid.TILE)
	assert_eq(invalid_tower["color"], Color(1.0, 0.2, 0.2))
	assert_true(_mode.range_preview_for("farm", origin, true).is_empty())

func test_selection_ring_and_info_line_only_show_for_live_defenses_and_guards() -> void:
	var origin: Vector2i = _state.map.command_center_origin() + Vector2i(5, 0)
	var turret: Building = _state.buildings.add("turret", origin, true)
	_selection.select_building(turret.uid)
	var preview: Dictionary = _selection.range_preview()
	assert_eq(float(preview["radius"]), float(_state.data.get_building("turret")["range_tiles"]) * Grid.TILE)
	_info.refresh()
	assert_true(_info._range_label.visible)
	assert_eq(_info._range_label.text, "Range: 6 tiles")

	var farm: Building = _state.buildings.add("farm", origin + Vector2i(3, 0), true)
	_selection.select_building(farm.uid)
	_info.refresh()
	assert_true(_selection.range_preview().is_empty())
	assert_false(_info._range_label.visible)

	var blueprint: Building = _state.buildings.add("turret", origin + Vector2i(0, 3), false)
	_selection.select_building(blueprint.uid)
	_info.refresh()
	assert_true(_selection.range_preview().is_empty(), "unfinished defenses have no active range")
	assert_false(_info._range_label.visible)

	var tower: Building = _state.buildings.add("watchtower", origin + Vector2i(3, 3), true)
	_selection.select_building(tower.uid)
	_info.refresh()
	var tower_range: float = float(_state.data.balance("guard_range_tiles")) * float(_state.data.get_building("watchtower")["guard_range_mult"])
	assert_eq(float(_selection.range_preview()["radius"]), tower_range * Grid.TILE)
	assert_eq(_info._range_label.text, "Range: 7.5 tiles")

	var guard: Survivor = _state.survivors.all()[0]
	guard.job = Survivor.Job.GUARD
	guard.post_uid = tower.uid
	guard.pos = tower.center_world() + Vector2(30, 12)
	_selection.select_survivor(guard.uid)
	_info.refresh()
	var guard_preview: Dictionary = _selection.range_preview()
	assert_eq(guard_preview["center"], tower.center_world(), "tower post center takes priority over guard sprite offset")
	assert_eq(float(guard_preview["radius"]), tower_range * Grid.TILE)
	assert_eq(_info._range_label.text, "Range: 7.5 tiles")
