class_name InfoPanel extends CanvasLayer

var _state: GameState
var _selection: SelectionController

var _panel: PanelContainer
var _vbox: VBoxContainer
var _name_label: Label
var _hp_label: Label
var _morale_label: Label
var _morale_bar: ProgressBar
var _moods_label: Label
var _range_label: Label
var _job_btn: OptionButton
var _activity_label: Label
var _carry_label: Label
var _status_label: Label
var _workers_label: Label
var _cancel_btn: Button
var _upgrade_btn: Button
var _scavenge_btn: Button
var _day_off_btn: Button
var _survivor_actions: HBoxContainer
var _feast_btn: Button

## Top two moods by absolute value; ties prefer the newest (GDD 22.7).
static func top_moods(moods: Array) -> Array:
	var ranked: Array = []
	for i: int in range(moods.size()):
		var mood: Dictionary = moods[i]
		ranked.append({"abs": absi(int(mood.get("value", 0))), "index": i, "mood": mood})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["abs"]) != int(b["abs"]):
			return int(a["abs"]) > int(b["abs"])
		return int(a["index"]) > int(b["index"]))
	var out: Array = []
	for i: int in range(mini(2, ranked.size())):
		out.append(ranked[i]["mood"])
	return out

static func signed_value(value: int) -> String:
	if value >= 0:
		return "+%d" % value
	return "%d" % value

static func moods_line(moods: Array) -> String:
	var parts: Array[String] = []
	for mood: Dictionary in top_moods(moods):
		parts.append("%s %s" % [str(mood.get("label", "")), signed_value(int(mood.get("value", 0)))])
	return " · ".join(parts)

static func morale_line(state: GameState, s: Survivor) -> String:
	return "Morale %d · %s" % [s.morale, str(Morale.band(state, s).get("name", ""))]

static func feast_cost(state: GameState) -> int:
	return int(state.data.morale_config().get("feast", {}).get("food_per_survivor", 2)) * state.survivors.count()

static func feast_button_text(state: GameState) -> String:
	return "Hold a feast (-%d food)" % feast_cost(state)

func _ready() -> void:
	visible = false

func _make_label(text: String, font_size: int) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return lbl

func bind(state: GameState, selection: SelectionController) -> void:
	_state = state
	_selection = selection

	_panel = get_node("PanelContainer")
	_vbox = _panel.get_node("VBoxContainer")

	_name_label = _vbox.get_node("NameLabel")
	_hp_label = _vbox.get_node("HPLabel")
	_range_label = _vbox.get_node("RangeLabel")
	_job_btn = _vbox.get_node("JobButton")
	JobOptions.fill(_job_btn)
	_job_btn.item_selected.connect(_on_job_selected)

	_morale_label = _make_label("", UiFont.BODY)
	_morale_label.name = "MoraleLabel"
	_vbox.add_child(_morale_label)
	_vbox.move_child(_morale_label, _hp_label.get_index() + 1)

	_morale_bar = ProgressBar.new()
	_morale_bar.name = "MoraleBar"
	_morale_bar.min_value = 0.0
	_morale_bar.max_value = 100.0
	_morale_bar.show_percentage = false
	_morale_bar.custom_minimum_size = Vector2(0, 10)
	_vbox.add_child(_morale_bar)
	_vbox.move_child(_morale_bar, _morale_label.get_index() + 1)

	_moods_label = _make_label("", UiFont.BODY)
	_moods_label.name = "MoodsLabel"
	_vbox.add_child(_moods_label)
	_vbox.move_child(_moods_label, _morale_bar.get_index() + 1)

	_activity_label = _vbox.get_node("ActivityLabel")
	_carry_label = _vbox.get_node("CarryLabel")
	_status_label = _vbox.get_node("StatusLabel")
	_workers_label = _vbox.get_node("WorkersLabel")
	_cancel_btn = _vbox.get_node("CancelButton")
	_cancel_btn.pressed.connect(_on_cancel_pressed)
	_upgrade_btn = _vbox.get_node("UpgradeButton")
	_upgrade_btn.pressed.connect(_on_upgrade_pressed)
	_survivor_actions = HBoxContainer.new()
	_survivor_actions.name = "SurvivorActions"
	_survivor_actions.visible = false
	_vbox.add_child(_survivor_actions)
	_vbox.move_child(_survivor_actions, _job_btn.get_index() + 1)
	_scavenge_btn = Button.new()
	_scavenge_btn.name = "ScavengeButton"
	_scavenge_btn.text = "Send scavenging"
	_scavenge_btn.visible = false
	_survivor_actions.add_child(_scavenge_btn)
	_scavenge_btn.pressed.connect(_on_scavenge_pressed)
	_day_off_btn = Button.new()
	_day_off_btn.name = "DayOffButton"
	_day_off_btn.text = "Day off"
	_day_off_btn.visible = false
	_survivor_actions.add_child(_day_off_btn)
	_day_off_btn.pressed.connect(_on_day_off_pressed)
	_feast_btn = Button.new()
	_feast_btn.name = "FeastButton"
	_feast_btn.visible = false
	_vbox.add_child(_feast_btn)
	_feast_btn.pressed.connect(_on_feast_pressed)
	_state.resources.changed.connect(_on_resources_changed)
	_state.clock.dawn.connect(_on_dawn)
	_state.clock.phase_changed.connect(_on_phase_changed)
	_selection.selection_changed.connect(_on_selection_changed)

func _on_resources_changed(_kind: String, _amount: int) -> void:
	refresh()

func _on_dawn(_day: int) -> void:
	refresh()

func _on_phase_changed(_phase: int, _day: int) -> void:
	refresh()

func _on_selection_changed(_kind: String, _uid: int) -> void:
	refresh()

func _on_upgrade_pressed() -> void:
	if _state and _selection and _selection.selected_kind == "building":
		_state.try_upgrade(_selection.selected_uid)
		refresh()

func _on_job_selected(index: int) -> void:
	if _state and _selection and _selection.selected_kind == "survivor":
		JobOptions.apply(_state, _selection.selected_uid, index)

func _on_cancel_pressed() -> void:
	if _state and _selection and _selection.selected_kind == "building":
		_state.cancel_building(_selection.selected_uid)

func _on_scavenge_pressed() -> void:
	if _state and _selection and _selection.selected_kind == "survivor":
		_state.expeditions.send(_selection.selected_uid)
		refresh()

func _on_day_off_pressed() -> void:
	if _state and _selection and _selection.selected_kind == "survivor":
		Morale.give_day_off(_state, _selection.selected_uid)
		refresh()

func _on_feast_pressed() -> void:
	if _state == null:
		return
	if Morale.hold_feast(_state):
		_toast(ScavengeToast.feast_text(_state))
	refresh()

func _toast(text: String) -> void:
	if not is_inside_tree() or get_parent() == null:
		return
	ScavengeToast.push_to_hud(get_parent().get_node_or_null("HUD"), text)

func refresh() -> void:
	if not _state or not _selection or _selection.selected_kind == "":
		_hide_survivor_buttons()
		if visible:
			visible = false
		return

	if not visible:
		visible = true

	if _selection.selected_kind == "survivor":
		var s: Survivor = _state.survivors.get_by_uid(_selection.selected_uid)
		if not s:
			_hide_survivor_buttons()
			if visible:
				visible = false
			return

		_set_text(_name_label, s.name)
		_set_text(_hp_label, "HP %d/%d" % [s.hp, s.max_hp])
		_refresh_morale(s)
		_refresh_range_line()

		var job_idx: int = JobOptions.index_for(s)
		if _job_btn.selected != job_idx:
			_job_btn.select(job_idx)

		_set_text(_activity_label, RosterPanel.status_text(s, _state))
		if s.carry_amount > 0:
			_set_text(_carry_label, "Carrying %d %s" % [s.carry_amount, s.carry_kind])
			_carry_label.show()
		else:
			_carry_label.hide()

		_job_btn.show()
		_activity_label.show()
		_status_label.hide()
		_workers_label.hide()
		_cancel_btn.hide()
		_upgrade_btn.hide()
		_feast_btn.hide()
		_update_scavenge(s)
		_update_day_off(s)
		_survivor_actions.visible = _scavenge_btn.visible or _day_off_btn.visible

	elif _selection.selected_kind == "building":
		var b: Building = _state.buildings.get_by_uid(_selection.selected_uid)
		if not b:
			if visible:
				visible = false
			return

		var b_data: Dictionary = _state.data.get_building(b.type_id)
		var b_name: String = b_data.get("name", b.type_id)

		_set_text(_name_label, b_name)
		_set_text(_hp_label, "HP %d/%d" % [b.hp, b.max_hp])
		_hide_morale()
		_refresh_range_line()
		_refresh_upgrade(b)

		if b.complete:
			_set_text(_status_label, "Complete")
			_cancel_btn.hide()
		else:
			var pct: int = int(b.progress_ratio() * 100)
			_set_text(_status_label, "Under construction %d%%" % pct)
			_cancel_btn.show()

		var workers: int = int(b_data.get("workers", 0))
		if workers > 0:
			var n: int = ProductionJob.workers_at(_state, b)
			var output: String = BuildInfoCard.output_line(_state.data, b.type_id, _state)
			_set_text(_workers_label, "Workers: %d/%d" % [n, workers] + ("\n" + output if output != "" else ""))
			_workers_label.show()
		else:
			var output: String = BuildInfoCard.output_line(_state.data, b.type_id, _state)
			_set_text(_workers_label, output)
			_workers_label.visible = output != ""

		_job_btn.hide()
		_activity_label.hide()
		_carry_label.hide()
		_status_label.show()
		_hide_survivor_buttons()
		_refresh_feast(b)

func _hide_survivor_buttons() -> void:
	if _survivor_actions:
		_survivor_actions.hide()
	if _scavenge_btn:
		_scavenge_btn.hide()
	if _day_off_btn:
		_day_off_btn.hide()

func _hide_morale() -> void:
	_morale_label.hide()
	_morale_bar.hide()
	_moods_label.hide()

func _refresh_morale(s: Survivor) -> void:
	_set_text(_morale_label, InfoPanel.morale_line(_state, s))
	_morale_label.show()
	_morale_bar.value = clampf(float(s.morale), 0.0, 100.0)
	_morale_bar.show()
	var line: String = InfoPanel.moods_line(s.moods)
	_set_text(_moods_label, line)
	_moods_label.visible = not line.is_empty()

func _refresh_feast(b: Building) -> void:
	if b.type_id != "command_center":
		_feast_btn.hide()
		return
	_feast_btn.show()
	_feast_btn.text = InfoPanel.feast_button_text(_state)
	var reason: String = Morale.feast_block_reason(_state)
	_feast_btn.disabled = reason != ""
	_feast_btn.tooltip_text = reason

func _refresh_upgrade(b: Building) -> void:
	var target: String = Placement.upgrade_target(_state.data, b.type_id) if b.complete else ""
	_upgrade_btn.visible = target != ""
	if target == "":
		return
	var target_data: Dictionary = _state.data.get_building(target)
	var cost: Dictionary = target_data.get("cost", {})
	_upgrade_btn.text = "Upgrade to %s (%s)" % [target_data.get("name", target), BuildBar.cost_text(cost)]
	var unlock_day: int = int(target_data.get("unlock_day", 0))
	var reason: String = ""
	if _state.clock.day < unlock_day:
		reason = "Unlocks on day %d" % unlock_day
	elif not _state.resources.can_afford(cost):
		reason = "Not enough resources"
	_upgrade_btn.disabled = reason != ""
	_upgrade_btn.tooltip_text = reason

func _update_scavenge(s: Survivor) -> void:
	if s.away:
		_scavenge_btn.hide()
		return
	var reason: String = _state.expeditions.can_send(s)
	if reason == "dead":
		_scavenge_btn.hide()
		return
	_scavenge_btn.show()
	_scavenge_btn.disabled = reason != ""
	_scavenge_btn.tooltip_text = ScavengeToast.reason_text(reason)

func _update_day_off(s: Survivor) -> void:
	if s.away:
		_day_off_btn.hide()
		return
	var dead: bool = _state.survivors.get_by_uid(s.uid) != s
	if dead:
		_day_off_btn.hide()
		return
	_day_off_btn.show()
	var reason: String = Morale.day_off_block_reason(_state, s)
	_day_off_btn.disabled = reason != ""
	_day_off_btn.tooltip_text = reason

func _set_text(lbl: Label, t: String) -> void:
	if lbl.text != t:
		lbl.text = t

func _refresh_range_line() -> void:
	var preview: Dictionary = _selection.range_preview()
	if preview.is_empty():
		_range_label.hide()
		return
	var tiles: float = float(preview["radius_tiles"])
	var value: String = _format_range(tiles)
	var text: String = "Range: %s tiles" % value
	if _state.clock.phase == GameClock.Phase.DAY and _state.weather_night() == "fog":
		var fog_tiles: float = float(preview["forecast_fog_radius_tiles"])
		text += " · %s in fog tonight" % _format_range(fog_tiles)
	_set_text(_range_label, text)
	_range_label.show()

func _format_range(tiles: float) -> String:
	return str(roundi(tiles)) if is_equal_approx(tiles, roundf(tiles)) else String.num(tiles, 1)

func _process(_delta: float) -> void:
	refresh()
