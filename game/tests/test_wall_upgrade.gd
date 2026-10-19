extends TestCase

var _state: GameState
var _origin: Vector2i
var _selection: SelectionController
var _panel: InfoPanel

func before_each() -> void:
	_state = GameState.new(GameData.load_default(), 1337)
	_state.clock.day = 6
	_origin = _state.map.command_center_origin() + Vector2i(-1, 4)
	_selection = SelectionController.new()
	_selection.bind(_state)
	_panel = preload("res://scenes/ui/info_panel.tscn").instantiate() as InfoPanel
	_panel.bind(_state, _selection)

func after_each() -> void:
	_panel.free()
	_selection.free()

func _wall(complete: bool = true) -> Building:
	return _state.buildings.add("wooden_wall", _origin, complete)

func test_paid_upgrade_remains_solid_and_builder_completes() -> void:
	var wall: Building = _wall()
	wall.hp = 20
	var wood: int = _state.resources.get_amount("wood")
	var scrap: int = _state.resources.get_amount("scrap")
	var rebuilds: int = _state.flow.rebuild_count
	assert_false(_state.map.is_passable(_origin))
	assert_eq(_state.try_upgrade(wall.uid), Placement.Result.OK)
	assert_eq(_state.resources.get_amount("wood"), wood - 5)
	assert_eq(_state.resources.get_amount("scrap"), scrap - 5)
	assert_eq(_state.flow.rebuild_count, rebuilds, "map listeners do not rebuild during replacement")
	assert_eq(_state.buildings.get_by_uid(wall.uid), null)
	var upgrade: Building = _state.buildings.get_at(_origin)
	assert_not_null(upgrade)
	if upgrade == null:
		return
	assert_eq(upgrade.type_id, "reinforced_wall")
	assert_eq(upgrade.upgraded_from, "wooden_wall")
	assert_false(upgrade.complete)
	assert_eq(upgrade.progress, 0.0)
	assert_eq(upgrade.build_time, 5.0)
	assert_eq(upgrade.hp, 400)
	assert_false(_state.map.is_passable(_origin))
	assert_true(_state.pathfinder.find_path(_origin + Vector2i.UP, _origin).is_empty())
	for i: int in range(600):
		_state.tick(0.1)
		assert_false(_state.map.is_passable(_origin))
		if upgrade.complete:
			break
	assert_true(upgrade.complete, "default builder completes the upgrade")
	assert_eq(upgrade.max_hp, 400)
	assert_eq(upgrade.hp, 400)

func test_locked_and_unaffordable_do_not_spend_or_replace() -> void:
	var wall: Building = _wall()
	var wood: int = _state.resources.get_amount("wood")
	var scrap: int = _state.resources.get_amount("scrap")
	_state.clock.day = 5
	assert_eq(_state.try_upgrade(wall.uid), Placement.Result.LOCKED)
	assert_eq(_state.resources.get_amount("wood"), wood)
	assert_eq(_state.resources.get_amount("scrap"), scrap)
	_state.clock.day = 6
	_state.resources.take("scrap", scrap)
	assert_eq(_state.try_upgrade(wall.uid), Placement.Result.UNAFFORDABLE)
	assert_eq(_state.resources.get_amount("wood"), wood)
	assert_eq(_state.resources.get_amount("scrap"), 0)
	assert_eq(_state.buildings.get_at(_origin), wall)
	assert_false(_state.map.is_passable(_origin))

func test_not_upgradable_types_and_missing_uid() -> void:
	var wall: Building = _wall(false)
	var gate: Building = _state.buildings.add("gate", _origin + Vector2i(2, 0), true)
	var shelter: Building = _state.buildings.add("shelter", _origin + Vector2i(-3, 0), true)
	var wood: int = _state.resources.get_amount("wood")
	var scrap: int = _state.resources.get_amount("scrap")
	for uid: int in [wall.uid, gate.uid, shelter.uid, 99999]:
		assert_eq(_state.try_upgrade(uid), Placement.Result.NOT_UPGRADABLE)
	assert_eq(_state.resources.get_amount("wood"), wood)
	assert_eq(_state.resources.get_amount("scrap"), scrap)

func _check_cancel(worked: bool) -> void:
	var wall: Building = _wall()
	wall.hp = 1
	var wood: int = _state.resources.get_amount("wood")
	var scrap: int = _state.resources.get_amount("scrap")
	assert_eq(_state.try_upgrade(wall.uid), Placement.Result.OK)
	var upgrade: Building = _state.buildings.get_at(_origin)
	if worked:
		for i: int in range(600):
			_state.tick(0.1)
			if upgrade.progress > 0.0:
				break
		assert_gt(upgrade.progress, 0.0)
	_selection.select_building(upgrade.uid)
	assert_true(_state.cancel_building(upgrade.uid))
	var restored: Building = _state.buildings.get_at(_origin)
	assert_not_null(restored)
	if restored == null:
		return
	assert_eq(restored.type_id, "wooden_wall")
	assert_true(restored.complete)
	assert_eq(restored.hp, 200)
	assert_eq(restored.max_hp, 200)
	assert_eq(restored.upgraded_from, "")
	assert_false(_state.map.is_passable(_origin))
	assert_eq(_selection.selected_uid, restored.uid)
	var loss: int = 3 if worked else 0
	assert_eq(_state.resources.get_amount("wood"), wood - loss)
	assert_eq(_state.resources.get_amount("scrap"), scrap - loss)
	assert_false(_state.cancel_building(upgrade.uid))
	assert_eq(_state.try_upgrade(restored.uid), Placement.Result.OK, "restored wall can upgrade again")

func test_cancel_before_work_restores_wall_and_full_refund() -> void:
	_check_cancel(false)

func test_cancel_after_work_restores_wall_and_floor_half_refund() -> void:
	_check_cancel(true)

func test_direct_placement_and_build_bar_still_exclude_upgrade() -> void:
	assert_eq(Placement.check(_state, "reinforced_wall", _origin), Placement.Result.NOT_PLACEABLE)
	var bar: BuildBar = preload("res://scenes/ui/build_bar.tscn").instantiate() as BuildBar
	bar.bind(_state)
	for button: Node in bar.get_node("Panel/HBox").get_children():
		assert_ne(button.get_meta("type_id"), "reinforced_wall")
	bar.free()

func test_info_panel_unlock_affordability_visibility_and_press() -> void:
	var wall: Building = _wall()
	_state.clock.day = 5
	_selection.select_building(wall.uid)
	assert_true(_panel._upgrade_btn.visible)
	assert_true(_panel._upgrade_btn.disabled)
	assert_eq(_panel._upgrade_btn.tooltip_text, "Unlocks on day 6")
	assert_eq(_panel._upgrade_btn.text, "Upgrade to Reinforced Wall (5 wood · 5 scrap)")
	_state.clock.day = 6
	_state.clock.dawn.emit(6)
	assert_false(_panel._upgrade_btn.disabled)
	assert_eq(_panel._upgrade_btn.tooltip_text, "")
	var scrap: int = _state.resources.get_amount("scrap")
	_state.resources.take("scrap", scrap)
	assert_true(_panel._upgrade_btn.disabled)
	assert_eq(_panel._upgrade_btn.tooltip_text, "Not enough resources")
	_state.resources.add("scrap", scrap)
	assert_false(_panel._upgrade_btn.disabled)
	_panel._upgrade_btn.pressed.emit()
	var upgrade: Building = _state.buildings.get_at(_origin)
	assert_eq(upgrade.type_id, "reinforced_wall", "button invokes try_upgrade")
	assert_eq(_selection.selected_kind, "building")
	assert_eq(_selection.selected_uid, upgrade.uid)
	assert_false(_panel._upgrade_btn.visible)
	assert_true(_panel._cancel_btn.visible)
	var farm: Building = _state.buildings.add("farm", _origin + Vector2i(3, 0), true)
	_selection.select_building(farm.uid)
	assert_false(_panel._upgrade_btn.visible)
	_selection.select_survivor(_state.survivors.all()[0].uid)
	assert_false(_panel._upgrade_btn.visible)

func test_upgrade_link_is_data_driven_and_transfers_direct_selection() -> void:
	_state.data._buildings["reinforced_wall"]["upgrade_from"] = "gate"
	assert_eq(Placement.upgrade_target(_state.data, "wooden_wall"), "")
	assert_eq(Placement.upgrade_target(_state.data, "gate"), "reinforced_wall")
	var gate: Building = _state.buildings.add("gate", _origin, true)
	_selection.select_building(gate.uid)
	assert_eq(_state.try_upgrade(gate.uid), Placement.Result.OK)
	var upgrade: Building = _state.buildings.get_at(_origin)
	assert_eq(upgrade.upgraded_from, "gate")
	assert_eq(_selection.selected_uid, upgrade.uid)
	assert_true(_state.cancel_building(upgrade.uid))
	assert_eq(_state.buildings.get_at(_origin).type_id, "gate")
