extends TestCase

var _state: GameState
var _selection: SelectionController
var _info: InfoPanel
var _roster: RosterPanel
var _changes: Array[Array] = []

func before_each() -> void:
	_state = GameState.new(GameData.load_default(), 12345)
	_selection = SelectionController.new()
	_selection.bind(_state)
	_selection.selection_changed.connect(_record_change)

func after_each() -> void:
	if _info != null:
		_info.free()
	if _roster != null:
		_roster.free()
	_selection.free()

func _record_change(kind: String, uid: int) -> void:
	_changes.append([kind, uid])

func _bind_info() -> void:
	_info = (load("res://scenes/ui/info_panel.tscn") as PackedScene).instantiate() as InfoPanel
	_info.bind(_state, _selection)

func test_nearest_survivor_radius_priority_and_change_signals() -> void:
	var building: Building = _state.buildings.all()[0]
	var point: Vector2 = building.center_world()
	var farther: Survivor = _state.survivors.add("Farther", "blue", building.origin)
	var nearer: Survivor = _state.survivors.add("Nearer", "blue", building.origin)
	farther.pos = point + Vector2(20, 0)
	nearer.pos = point + Vector2(10, 0)
	_selection.select_at_world(point)
	assert_eq(_selection.selected_kind, "survivor", "survivors take priority over the building")
	assert_eq(_selection.selected_uid, nearer.uid, "nearest survivor wins")
	_selection.select_at_world(point)
	_selection.select_survivor(nearer.uid)
	assert_eq(_changes.size(), 1, "repeated selection emits no extra signal")
	nearer.pos = point + Vector2(24, 0)
	farther.pos = point + Vector2(30, 0)
	_selection.select_at_world(point)
	assert_eq(_selection.selected_uid, nearer.uid, "24 px boundary is included")
	nearer.pos = point + Vector2(24.1, 0)
	_selection.select_at_world(point)
	assert_eq(_selection.selected_kind, "building", "outside 24 px falls back to building")
	assert_eq(_selection.selected_uid, building.uid)
	_selection.select_building(building.uid)
	assert_eq(_changes.size(), 2)
	_selection.select_at_world(Vector2(-100, -100))
	_selection.clear()
	assert_eq(_selection.selected_kind, "")
	assert_eq(_selection.selected_uid, 0)
	assert_eq(_changes.size(), 3, "clear emits exactly once")
	_selection.select_survivor(nearer.uid)
	_state.survivors.remove(farther.uid)
	assert_eq(_changes.size(), 4, "removing another target keeps selection")
	_state.survivors.remove(nearer.uid)
	assert_eq(_changes.size(), 5, "removing selected target emits one clear")
	assert_eq(_changes.back(), ["", 0])

func test_all_job_options_round_trip_and_reject_both_invalid_bounds() -> void:
	var survivor: Survivor = _state.survivors.all()[0]
	var jobs: Array[int] = [Survivor.Job.IDLE, Survivor.Job.GATHERER, Survivor.Job.GATHERER,
		Survivor.Job.FARMER, Survivor.Job.BUILDER, Survivor.Job.CRAFTER, Survivor.Job.GUARD, Survivor.Job.RESEARCHER]
	for index: int in range(JobOptions.LABELS.size()):
		assert_true(JobOptions.apply(_state, survivor.uid, index))
		assert_eq(survivor.job, jobs[index])
		assert_eq(JobOptions.index_for(survivor), index, "all eight options round trip")
		if index == 1 or index == 2:
			assert_eq(survivor.gather_kind, "wood" if index == 1 else "scrap")
	assert_false(JobOptions.apply(_state, survivor.uid, -1))
	assert_false(JobOptions.apply(_state, survivor.uid, JobOptions.LABELS.size()))
	assert_eq(survivor.job, Survivor.Job.RESEARCHER, "invalid indices do not mutate the job")

func test_cancel_button_refunds_unstarted_and_started_blueprints_and_clears_selection() -> void:
	_bind_info()
	var cost: Dictionary = _state.data.get_building("farm")["cost"]
	for fraction: float in [1.0, 0.5]:
		var before: int = _state.resources.get_amount("wood")
		assert_true(_state.resources.spend(cost))
		var building: Building = _state.buildings.add("farm", Vector2i(3, 3), false)
		if fraction == 0.5:
			building.progress = building.build_time * 0.4
		_selection.select_building(building.uid)
		_info.refresh()
		assert_true(_info._cancel_btn.visible)
		_info._cancel_btn.pressed.emit()
		assert_eq(_state.buildings.get_by_uid(building.uid), null, "button removes blueprint")
		assert_eq(_state.resources.get_amount("wood"), before - int(cost["wood"]) + floori(int(cost["wood"]) * fraction))
		assert_eq(_selection.selected_kind, "", "cancel clears selection immediately")
		_info.refresh()
		assert_false(_info.visible, "cancel hides info panel")

func test_complete_building_has_no_cancel_button() -> void:
	_bind_info()
	var building: Building = _state.buildings.add("farm", Vector2i(3, 3), true)
	_selection.select_building(building.uid)
	_info.refresh()
	assert_false(_info._cancel_btn.visible)
	assert_eq(_info._status_label.text, "Complete")

func test_job_controls_synchronize_without_reassigning_during_refresh() -> void:
	_bind_info()
	_roster = (load("res://scenes/ui/roster_panel.tscn") as PackedScene).instantiate() as RosterPanel
	_roster.bind(_state, _selection)
	_roster.toggle()
	var survivor: Survivor = _state.survivors.all()[0]
	_selection.select_survivor(survivor.uid)
	_info.refresh()
	_info._job_btn.item_selected.emit(4)
	_roster.refresh()
	var job_button: OptionButton = _roster._vbox.get_child(0).get_child(1) as OptionButton
	assert_eq(survivor.job, Survivor.Job.BUILDER)
	assert_eq(job_button.selected, 4, "roster reflects info-panel assignment")
	job_button.item_selected.emit(2)
	_info.refresh()
	assert_eq(survivor.gather_kind, "scrap")
	assert_eq(_info._job_btn.selected, 2, "info panel reflects roster assignment")
	survivor.work_uid = 123
	survivor.activity = Survivor.Activity.WALKING
	_info.refresh()
	_roster.refresh()
	assert_eq(survivor.work_uid, 123, "refresh never reassigns the survivor")
	assert_eq(survivor.activity, Survivor.Activity.WALKING)
	_roster.toggle()
	assert_false(_roster.is_open(), "second toggle closes roster")
