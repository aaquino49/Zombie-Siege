class_name TestScavengingUI extends TestCase
## T-167: Send-scavenging buttons, away rows, return toasts and Dawn Report lines.

const SelectionScript = preload("res://scripts/world/selection_controller.gd")

var data: GameData
var state: GameState

func before_each() -> void:
	data = GameData.load_default()
	state = GameState.new(data, 1337)
	state.waves.enabled = false

func after_each() -> void:
	state = null
	data = null

func _morning() -> void:
	state.clock.phase = GameClock.Phase.DAY
	state.clock.elapsed = 0.0

func _past_morning() -> void:
	state.clock.phase = GameClock.Phase.DAY
	state.clock.elapsed = float(data.balance("day_length"))

func _idle(s: Survivor) -> void:
	state.set_job(s.uid, Survivor.Job.IDLE)

func _make_selection() -> SelectionController:
	var selection: SelectionController = SelectionScript.new()
	selection.bind(state)
	return selection

func _make_info(selection: SelectionController) -> InfoPanel:
	var panel: InfoPanel = (load("res://scenes/ui/info_panel.tscn") as PackedScene).instantiate()
	panel.bind(state, selection)
	panel.refresh()
	return panel

func _make_roster(selection: SelectionController) -> RosterPanel:
	var panel: RosterPanel = (load("res://scenes/ui/roster_panel.tscn") as PackedScene).instantiate()
	panel.bind(state, selection)
	if not panel.is_open():
		panel.toggle()
	panel.refresh()
	return panel

func _bound_hud() -> CanvasLayer:
	var hud: CanvasLayer = (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate() as CanvasLayer
	hud.set("top_bar", hud.get_node("TopBar"))
	for kind: String in ResourceStore.KINDS:
		var box_path: String = "TopBar/Margin/HBox/Resources/%sBox" % kind.capitalize()
		hud.set(kind + "_icon", hud.get_node(box_path + "/Icon"))
		hud.set(kind + "_label", hud.get_node(box_path + "/Label"))
	hud.set("day_label", hud.get_node("TopBar/Margin/HBox/DayArea/DayLabel"))
	hud.set("time_label", hud.get_node("TopBar/Margin/HBox/ClockArea/TimeLabel"))
	for button_name: String in ["BtnPause", "Btn1x", "Btn2x", "Btn3x"]:
		hud.set("btn_" + button_name.to_lower().trim_prefix("btn"), hud.get_node("TopBar/Margin/HBox/ClockArea/SpeedButtons/" + button_name))
	hud.set("shelter_warning_label", hud.get_node("ShelterWarning"))
	hud.set("phase_icon", hud.get_node("TopBar/Margin/HBox/DayArea/PhaseIcon"))
	hud.set("night_forecast_panel", hud.get_node("NightForecast"))
	hud.set("night_forecast_label", hud.get_node("NightForecast/Label"))
	hud.call("_ready")
	hud.call("bind", state)
	return hud

func _send_and_leave(s: Survivor) -> void:
	assert_true(state.expeditions.send(s.uid), "send must succeed in the morning")
	state.survivors.tick(1000.0, state.pathfinder, state.map)
	state.expeditions.tick(state, 0.0)
	assert_true(s.away, "runner must reach the edge and go away")

func _dusk() -> void:
	state.clock.elapsed = float(data.balance("day_length")) - 0.1
	state.clock.advance(0.2)

func _dawn() -> void:
	state.clock.elapsed = float(data.balance("night_min_length")) - 0.1
	state.clock.advance(0.2)

func _row_for(roster: RosterPanel, uid: int) -> HBoxContainer:
	for row: Node in roster._vbox.get_children():
		if int(row.get_meta("uid")) == uid:
			return row
	return null

func test_reason_texts() -> void:
	assert_eq(ScavengeToast.reason_text("not morning"), "Only in the morning")
	assert_eq(ScavengeToast.reason_text("guard"), "Guards stay on watch")
	assert_eq(ScavengeToast.reason_text("already away"), "Already out")
	assert_eq(ScavengeToast.reason_text("run limit"), "No more runs today")
	assert_eq(ScavengeToast.reason_text("sheltered"), "Can't leave the shelter")
	assert_eq(ScavengeToast.reason_text(""), "")
	assert_eq(ScavengeToast.reason_text("dead"), "")

func test_info_button_disabled_outside_morning() -> void:
	_morning()
	var selection: SelectionController = _make_selection()
	var panel: InfoPanel = _make_info(selection)
	var s: Survivor = state.survivors.all()[0]
	_idle(s)
	_past_morning()
	selection.select_survivor(s.uid)
	panel.refresh()
	assert_true(panel._scavenge_btn.visible, "button shows outside the morning")
	assert_true(panel._scavenge_btn.disabled, "button disabled outside the morning")
	assert_eq(panel._scavenge_btn.tooltip_text, "Only in the morning")
	panel.free()
	selection.free()

func test_info_button_disabled_for_guard() -> void:
	_morning()
	var selection: SelectionController = _make_selection()
	var panel: InfoPanel = _make_info(selection)
	var s: Survivor = state.survivors.all()[0]
	state.set_job(s.uid, Survivor.Job.GUARD)
	selection.select_survivor(s.uid)
	panel.refresh()
	assert_true(panel._scavenge_btn.visible, "button shows for a guard")
	assert_true(panel._scavenge_btn.disabled, "button disabled for a guard")
	assert_eq(panel._scavenge_btn.tooltip_text, "Guards stay on watch")
	panel.free()
	selection.free()

func test_info_button_disabled_at_run_limit() -> void:
	_morning()
	for s: Survivor in state.survivors.all():
		_idle(s)
	var first: Survivor = state.survivors.all()[0]
	assert_true(state.expeditions.send(first.uid))
	var selection: SelectionController = _make_selection()
	var panel: InfoPanel = _make_info(selection)
	var second: Survivor = state.survivors.all()[1]
	selection.select_survivor(second.uid)
	panel.refresh()
	assert_true(panel._scavenge_btn.visible, "button shows at the run limit")
	assert_true(panel._scavenge_btn.disabled, "button disabled at the run limit")
	assert_eq(panel._scavenge_btn.tooltip_text, "No more runs today")
	panel.free()
	selection.free()

func test_info_button_disabled_when_sheltered_and_hidden_when_dead() -> void:
	_morning()
	var selection: SelectionController = _make_selection()
	var panel: InfoPanel = _make_info(selection)
	var s: Survivor = state.survivors.all()[0]
	_idle(s)
	s.sheltered = true
	selection.selected_kind = "survivor"
	selection.selected_uid = s.uid
	panel.refresh()
	assert_true(panel._scavenge_btn.visible, "button shows for a sheltered survivor")
	assert_true(panel._scavenge_btn.disabled, "button disabled for a sheltered survivor")
	assert_eq(panel._scavenge_btn.tooltip_text, "Can't leave the shelter")
	s.sheltered = false
	s.hp = 0
	panel.refresh()
	assert_false(panel._scavenge_btn.visible, "button hidden for the dead")
	panel.free()
	selection.free()

func test_info_button_enabled_and_sends_in_morning() -> void:
	_morning()
	var selection: SelectionController = _make_selection()
	var panel: InfoPanel = _make_info(selection)
	var s: Survivor = state.survivors.all()[0]
	_idle(s)
	selection.select_survivor(s.uid)
	panel.refresh()
	assert_true(panel._scavenge_btn.visible, "button shows in the morning")
	assert_false(panel._scavenge_btn.disabled, "button enabled in the morning")
	assert_eq(panel._scavenge_btn.tooltip_text, "")
	panel._scavenge_btn.pressed.emit()
	assert_true(state.expeditions.is_running(s), "pressing the button sends the run")
	assert_eq(state.expeditions.active().size(), 1)
	panel.free()
	selection.free()

func test_info_button_hidden_for_buildings() -> void:
	_morning()
	var selection: SelectionController = _make_selection()
	var panel: InfoPanel = _make_info(selection)
	var b: Building = state.buildings.all()[0]
	selection.select_building(b.uid)
	panel.refresh()
	assert_false(panel._scavenge_btn.visible, "no scavenge button on buildings")
	panel.free()
	selection.free()

func test_roster_away_row_hides_button_and_disables_select() -> void:
	_morning()
	for s: Survivor in state.survivors.all():
		_idle(s)
	var away_one: Survivor = state.survivors.all()[1]
	_send_and_leave(away_one)
	var selection: SelectionController = _make_selection()
	var roster: RosterPanel = _make_roster(selection)
	var row: HBoxContainer = _row_for(roster, away_one.uid)
	assert_not_null(row, "away survivor keeps a roster row")
	assert_eq((row.get_child(2) as Label).text, "Away till dusk")
	assert_eq((row.get_child(2) as Label).tooltip_text, "Away (back at nightfall)")
	assert_false((row.get_child(3) as Button).visible, "scavenge button hidden while away")
	assert_true((row.get_child(0) as Button).disabled, "away survivor cannot be selected")
	selection.select_survivor(away_one.uid)
	assert_eq(selection.selected_kind, "", "selection refuses away survivors")
	var home: HBoxContainer = _row_for(roster, state.survivors.all()[0].uid)
	assert_true((home.get_child(3) as Button).visible, "home survivors keep the button")
	roster.free()
	selection.free()

func test_roster_buttons_follow_reasons() -> void:
	_morning()
	for s: Survivor in state.survivors.all():
		_idle(s)
	state.set_job(state.survivors.all()[0].uid, Survivor.Job.GUARD)
	var selection: SelectionController = _make_selection()
	var roster: RosterPanel = _make_roster(selection)
	var guard_row: HBoxContainer = _row_for(roster, state.survivors.all()[0].uid)
	var guard_btn: Button = guard_row.get_child(3)
	assert_true(guard_btn.visible, "guard row shows the button")
	assert_true(guard_btn.disabled, "guard row button disabled")
	assert_eq(guard_btn.tooltip_text, "Guards stay on watch")
	roster.free()
	selection.free()

func test_toast_text_for_loot_hurt_lost_and_newcomer() -> void:
	var loot: Dictionary = {"wood": 0, "scrap": 32, "food": 12, "ammo": 0}
	assert_eq(ScavengeToast.text("Mara", {"loot": loot, "hurt": false, "lost": false, "newcomer": false}),
		"Mara is back: +32 scrap, +12 food")
	assert_eq(ScavengeToast.text("Mara", {"loot": {"wood": 10, "scrap": 0, "food": 0, "ammo": 0}, "hurt": true, "lost": false, "newcomer": false}),
		"Mara came back hurt: +10 wood")
	assert_eq(ScavengeToast.text("Mara", {"loot": loot, "hurt": false, "lost": true, "newcomer": false}),
		"Mara didn't come back")
	assert_eq(ScavengeToast.text("Mara", {"loot": loot, "hurt": false, "lost": false, "newcomer": true}),
		"Mara is back: +32 scrap, +12 food, and found a newcomer")
	assert_eq(ScavengeToast.text("Mara", {"loot": loot, "hurt": true, "lost": false, "newcomer": true}),
		"Mara came back hurt: +32 scrap, +12 food, and found a newcomer")
	assert_eq(ScavengeToast.loot_text({"wood": 5, "scrap": 3, "food": 2, "ammo": 1}),
		"+5 wood, +3 scrap, +2 food, +1 ammo")
	assert_eq(ScavengeToast.loot_text({"wood": 0, "scrap": 0, "food": 0, "ammo": 0}), "")

func test_dawn_report_lists_scavenging_runs() -> void:
	var report: Dictionary = {
		"zombies_killed": 1,
		"scavenging": [
			{"name": "Mara", "loot": {"wood": 0, "scrap": 32, "food": 12, "ammo": 0}, "hurt": false, "lost": false},
			{"name": "Theo", "loot": {"wood": 10, "scrap": 0, "food": 0, "ammo": 0}, "hurt": true, "lost": false},
			{"name": "Ash", "loot": {"wood": 0, "scrap": 0, "food": 0, "ammo": 0}, "hurt": false, "lost": true},
		],
		"objective": "Hold on.",
	}
	var lines: Array[String] = DawnReport.lines(report)
	assert_true(lines.has("Scavenging (Mara): +32 scrap, +12 food"), "loot line present")
	assert_true(lines.has("Scavenging (Theo): (hurt) +10 wood"), "hurt line present")
	assert_true(lines.has("Scavenging (Ash): didn't come back"), "lost line present")
	var rows: Array[Array] = DawnReportPanel.report_rows(report)
	var row_by_label: Dictionary = {}
	for row: Array in rows:
		row_by_label[str(row[0])] = str(row[1])
	assert_eq(row_by_label.get("Scavenging (Mara)", ""), "+32 scrap, +12 food", "panel splits scavenging label and value")
	assert_eq(row_by_label.get("Scavenging (Theo)", ""), "(hurt) +10 wood", "panel splits hurt label and value")
	assert_eq(row_by_label.get("Scavenging (Ash)", ""), "didn't come back", "panel splits lost label and value")
	var quiet: Array[String] = DawnReport.lines({"scavenging": [], "objective": ""})
	assert_true(quiet.is_empty(), "empty scavenging adds no lines")

func test_full_day_return_adds_loot_and_lists_in_dawn_report() -> void:
	_morning()
	for s: Survivor in state.survivors.all():
		_idle(s)
	var hud: CanvasLayer = _bound_hud()
	var s: Survivor = state.survivors.all()[0]
	var returned: Array[Dictionary] = []
	state.expeditions.run_returned.connect(func(_sx: Survivor, result: Dictionary) -> void:
		returned.append(result))
	_send_and_leave(s)
	var before: Dictionary = {}
	for kind: String in ["wood", "scrap", "food", "ammo"]:
		before[kind] = state.resources.get_amount(kind)
	_dusk()
	assert_eq(returned.size(), 1, "one return toast fires at nightfall")
	var result: Dictionary = returned[0]
	if bool(result.get("lost", false)):
		assert_eq(ScavengeToast.text(s.name, result), "%s didn't come back" % s.name)
	else:
		for kind: String in ["wood", "scrap", "food", "ammo"]:
			assert_eq(state.resources.get_amount(kind) - int(before[kind]), int((result["loot"] as Dictionary)[kind]),
				"loot reaches the stockpile")
	var box: VBoxContainer = hud.get_node("ToastLayer/ScavengeToasts")
	assert_eq(box.get_child_count(), 1, "HUD shows the return toast")
	var shown: String = (box.get_child(0).get_child(0) as Label).text
	assert_eq(shown, ScavengeToast.text(s.name, result), "toast text matches the result")
	hud.call("_tick_toasts", 4.1)
	assert_eq(box.get_child_count(), 0, "toast expires after four seconds")
	_dawn()
	assert_true(state.last_dawn_report.has("scavenging"), "dawn report carries scavenging")
	var scav: Array = state.last_dawn_report["scavenging"]
	assert_eq(scav.size(), 1, "one run listed")
	assert_eq(str((scav[0] as Dictionary)["name"]), s.name)
	assert_true(DawnReport.lines(state.last_dawn_report).has(
		"Scavenging (%s): %s" % [s.name, ScavengeToast.dawn_value(result)]), "panel lines include the run")
	hud.free()

func test_toasts_queue_and_ignore_clicks() -> void:
	_morning()
	var hud: CanvasLayer = _bound_hud()
	var box: VBoxContainer = hud.get_node("ToastLayer/ScavengeToasts")
	assert_eq(box.mouse_filter, Control.MOUSE_FILTER_IGNORE, "toasts never block map clicks")
	hud.call("show_scavenge_toast", "A", {"loot": {"wood": 1, "scrap": 0, "food": 0, "ammo": 0}, "hurt": false, "lost": false, "newcomer": false})
	hud.call("show_scavenge_toast", "B", {"loot": {"wood": 0, "scrap": 0, "food": 0, "ammo": 0}, "hurt": false, "lost": true, "newcomer": false})
	assert_eq(box.get_child_count(), 2, "several toasts queue")
	for toast: Node in box.get_children():
		assert_eq(toast.mouse_filter, Control.MOUSE_FILTER_IGNORE, "each toast ignores clicks")
		assert_eq((toast.get_child(0) as Label).mouse_filter, Control.MOUSE_FILTER_IGNORE, "labels ignore clicks")
	hud.free()

func test_selection_refuses_away_survivors() -> void:
	_morning()
	for s: Survivor in state.survivors.all():
		_idle(s)
	var s: Survivor = state.survivors.all()[0]
	_send_and_leave(s)
	var selection: SelectionController = _make_selection()
	selection.select_survivor(s.uid)
	assert_eq(selection.selected_kind, "", "away survivors cannot be selected")
	selection.free()

func test_scavenge_hint_on_day_two_and_tips_line() -> void:
	var hints := TutorialHints.new()
	hints.shown["welcome"] = true
	hints.shown["farm"] = true
	hints.shown["night_soon"] = true
	hints.shown["ammo"] = true
	state.clock.day = 2
	assert_eq(hints.check(state, 0.0), "scavenge", "day-2 morning teaches scavenging")
	assert_true(TutorialHints.text("scavenge").length() > 0, "scavenge hint has text")
	state.clock.day = 3
	var hints_late := TutorialHints.new()
	hints_late.shown["welcome"] = true
	hints_late.shown["farm"] = true
	hints_late.shown["night_soon"] = true
	hints_late.shown["ammo"] = true
	hints_late.shown["scavenge"] = true
	assert_ne(hints_late.check(state, 0.0), "scavenge", "scavenge hint fires once")
	var page: CanvasLayer = (load("res://scenes/ui/how_to_play.tscn") as PackedScene).instantiate()
	var tips: Label = page.get_node("Dim/Center/Panel/Margin/Content/Scroll/Sections/Tips")
	assert_true(tips.text.to_lower().contains("scaveng"), "how-to-play tips mention scavenging")
	page.free()
