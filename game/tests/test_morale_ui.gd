extends TestCase
## Morale 2 UI: roster mood column, info-panel morale/feast/day-off,
## dawn rows, hint text/trigger, icons and fonts. Detached-node pattern
## from tests/README.md (instantiate, bind by hand, free with free()).

var _state: GameState
var _data: GameData

func before_each() -> void:
	_data = GameData.load_default()
	_state = GameState.new(_data, 1337)
	_state.waves.enabled = false

func after_each() -> void:
	_data = null
	_state = null

# --- Top-two moods (GDD 22.7: absolute value, newest-first ties). ---

func test_top_two_orders_by_absolute_value_newest_first_on_ties() -> void:
	var moods: Array = [
		{"id": "bed", "label": "Slept in a bed", "value": 5, "days": 1},
		{"id": "death", "label": "Mara died", "value": -12, "days": 3},
		{"id": "quiet_night", "label": "Quiet night", "value": 4, "days": 1},
		{"id": "death", "label": "Theo died", "value": -12, "days": 3},
	]
	var top: Array = InfoPanel.top_moods(moods)
	assert_eq(top.size(), 2)
	assert_eq(str(top[0]["label"]), "Theo died")
	assert_eq(str(top[1]["label"]), "Mara died")

func test_moods_line_signs_and_separator() -> void:
	var moods: Array = [
		{"id": "hungry", "label": "Hungry", "value": -15, "days": 1},
		{"id": "bed", "label": "Slept in a bed", "value": 5, "days": 1},
	]
	assert_eq(InfoPanel.moods_line(moods), "Hungry -15 · Slept in a bed +5")

func test_moods_line_empty_without_moods() -> void:
	assert_eq(InfoPanel.moods_line([]), "")

func test_morale_line_shows_number_and_band() -> void:
	var s: Survivor = _state.survivors.all()[0]
	s.moods.clear()
	s.morale = 62
	assert_eq(InfoPanel.morale_line(_state, s), "Morale 62 · Steady")

# --- Feast / refusal toast text comes from the mood config. ---

func test_feast_text_uses_config_value() -> void:
	assert_eq(ScavengeToast.feast_text(_state), "Feast! Everyone +10 morale")

func test_refusal_texts_once_per_name() -> void:
	var report := {"morale": {"bands": {}, "refusing": ["Bob", "Eve"], "left_morale": []}}
	var texts: Array[String] = ScavengeToast.refusal_texts(report)
	assert_eq(texts, ["Bob refuses to work today", "Eve refuses to work today"] as Array[String])

# --- Dawn Report rows: band counts omit empties, lost-heart de-dup. ---

func test_morale_rows_omit_empty_bands_best_first() -> void:
	var report := {"left": [], "morale": {
		"bands": {"inspired": 1, "steady": 0, "low": 2, "breaking": 0},
		"refusing": [], "left_morale": []}}
	var rows: Array[Array] = DawnReportPanel.morale_rows(report)
	assert_eq(rows.size(), 1)
	assert_eq(rows[0], ["Morale", "1 Inspired · 2 Low"] as Array)

func test_morale_rows_refusing_and_lost_heart() -> void:
	var report := {"left": ["Eve"], "morale": {
		"bands": {"inspired": 0, "steady": 3, "low": 0, "breaking": 1},
		"refusing": ["Eve"], "left_morale": ["Eve"]}}
	var rows: Array[Array] = DawnReportPanel.morale_rows(report)
	assert_true(rows.has(["Morale", "3 Steady · 1 Breaking"] as Array))
	assert_true(rows.has(["Refusing work", "Eve"] as Array))
	assert_true(rows.has(["Left (lost heart)", "Eve"] as Array))
	for row: Array in rows:
		assert_false(row[0] == "Left", "morale leaver must not keep a generic Left row")

func test_departure_dedup_keeps_hunger_line_separate() -> void:
	var report := {"left": ["Bob", "Eve"], "morale": {
		"bands": {"inspired": 0, "steady": 2, "low": 0, "breaking": 0},
		"refusing": [], "left_morale": ["Eve"]}}
	var rows: Array[Array] = DawnReportPanel.report_rows(report)
	assert_true(rows.has(["Left", "Bob"] as Array))
	assert_true(rows.has(["Left (lost heart)", "Eve"] as Array))
	var left_rows: int = 0
	for row: Array in rows:
		if str(row[0]).begins_with("Left"):
			left_rows += 1
			assert_false("Eve" in str(row[1]) and str(row[0]) == "Left", "Eve only in lost-heart row")
	assert_eq(left_rows, 2)

func test_old_fixture_without_morale_has_no_morale_rows() -> void:
	var report := {"left": ["Bob"], "hungry": [], "arrived": []}
	var rows: Array[Array] = DawnReportPanel.report_rows(report)
	assert_true(rows.has(["Left", "Bob"] as Array))
	for row: Array in rows:
		assert_false(str(row[0]).begins_with("Morale"), "old fixtures gain no morale rows")
		assert_false(str(row[0]).begins_with("Refusing"), "old fixtures gain no refusal rows")

# --- Morale tutorial hint: one-shot, gated by Low/Breaking. ---

func _quiet_day_five() -> void:
	_state.clock.day = 5
	_state.clock.phase = GameClock.Phase.DAY
	_state.clock.elapsed = float(_state.data.balance("day_length"))
	for s: Survivor in _state.survivors.all():
		s.moods.clear()
		s.morale = 60

func test_morale_hint_fires_once_on_low() -> void:
	_quiet_day_five()
	var hints := TutorialHints.new()
	assert_eq(hints.check(_state, 0.0), "")
	_state.survivors.all()[0].morale = 30
	assert_eq(hints.check(_state, 0.0), "morale")
	assert_true(hints.shown.has("morale"))
	assert_eq(hints.check(_state, 0.0), "")

func test_morale_hint_text_matches_gdd() -> void:
	assert_eq(TutorialHints.text("morale"),
		"Morale is slipping. Low and Breaking survivors work slower and guards miss shots. Build a Campfire, keep beds and food up, or hold a Feast at the Command Center.")

func test_morale_hint_respects_off_and_seen_state() -> void:
	_quiet_day_five()
	_state.survivors.all()[0].morale = 10
	var off := TutorialHints.new()
	off.enabled = false
	assert_eq(off.check(_state, 0.0), "")
	var seen := TutorialHints.new()
	seen.shown = {"morale": true}
	assert_eq(seen.check(_state, 0.0), "")
	# Seen-state round-trips through the HintPanel persistence shape.
	var saved: Dictionary = seen.shown.duplicate(true)
	var restored := TutorialHints.new()
	restored.shown = saved.duplicate(true)
	assert_eq(restored.check(_state, 0.0), "")

# --- Icons, fonts, roster rows, info panel, how-to-play. ---

func test_mood_icons_are_16px_sources_shown_at_2x() -> void:
	for band_id: String in ["inspired", "steady", "low", "breaking"]:
		var tex: Texture2D = RosterPanel.mood_icon(band_id)
		assert_not_null(tex, band_id)
		assert_eq(tex.get_width(), 16, band_id)
	assert_eq(RosterPanel.MOOD_ICON_SIZE, 32.0)

func test_ui_font_sizes_are_integers_of_native() -> void:
	for size: int in [UiFont.SMALL, UiFont.BODY, UiFont.LARGE, UiFont.TITLE]:
		assert_true(UiFont.is_crisp(size), "font size %d" % size)

func test_roster_row_shows_mood_number_and_status() -> void:
	var selection := SelectionController.new()
	selection.bind(_state)
	var roster := load("res://scenes/ui/roster_panel.tscn").instantiate() as RosterPanel
	roster.bind(_state, selection)
	if not roster.is_open():
		roster.toggle()
	roster.refresh()
	var people: Array[Survivor] = _state.survivors.all()
	people[0].morale = 82
	people[1].refusing = true
	roster.refresh()
	var rows: Array[Node] = roster.get_node("PanelContainer/VBox/ScrollContainer/Rows").get_children()
	assert_eq(rows.size(), people.size())
	var icon: TextureRect = rows[0].get_node("MoodIcon") as TextureRect
	assert_not_null(icon.texture, "mood icon set")
	assert_eq(icon.custom_minimum_size, Vector2(32, 32))
	assert_eq((rows[0].get_node("MoodNumber") as Label).text, "82")
	assert_eq((rows[1].get_child(2) as Label).text, "Refusing work")
	people[1].refusing = false
	people[1].day_off = true
	roster.refresh()
	assert_eq((rows[1].get_child(2) as Label).text, "Day off")
	roster.free()
	selection.free()

func test_roster_day_off_button_uses_sim_reason() -> void:
	var selection := SelectionController.new()
	selection.bind(_state)
	var roster := load("res://scenes/ui/roster_panel.tscn").instantiate() as RosterPanel
	roster.bind(_state, selection)
	if not roster.is_open():
		roster.toggle()
	_state.clock.elapsed = 5.0
	roster.refresh()
	var rows: Array[Node] = roster.get_node("PanelContainer/VBox/ScrollContainer/Rows").get_children()
	var day_off_btn: Button = rows[0].get_node("DayOffButton") as Button
	assert_true(day_off_btn.visible)
	assert_false(day_off_btn.disabled, "morning day off is available")
	_state.clock.elapsed = 28.0
	roster.refresh()
	assert_true(day_off_btn.disabled, "past the morning fraction the button disables")
	assert_eq(day_off_btn.tooltip_text, "Not morning")
	roster.free()
	selection.free()

func test_info_panel_survivor_morale_and_day_off() -> void:
	var selection := SelectionController.new()
	selection.bind(_state)
	var panel := load("res://scenes/ui/info_panel.tscn").instantiate() as InfoPanel
	panel.bind(_state, selection)
	var s: Survivor = _state.survivors.all()[0]
	s.moods.clear()
	Morale.add_mood(_state, s, "hungry")
	Morale.add_mood(_state, s, "rough_night")
	selection.select_survivor(s.uid)
	assert_eq(panel.get_node("PanelContainer/VBoxContainer/MoraleLabel").text, "Morale 29 · Low")
	assert_eq(panel.get_node("PanelContainer/VBoxContainer/MoraleBar").value, 29.0)
	assert_eq(panel.get_node("PanelContainer/VBoxContainer/MoodsLabel").text, "Hungry -15 · Rough night -6")
	_state.clock.elapsed = 5.0
	panel.refresh()
	var day_off_btn: Button = panel.get_node("PanelContainer/VBoxContainer/SurvivorActions/DayOffButton") as Button
	var actions: HBoxContainer = panel.get_node("PanelContainer/VBoxContainer/SurvivorActions")
	assert_eq(day_off_btn.get_parent(), actions, "Day off sits beside Send scavenging")
	assert_not_null(actions.get_node("ScavengeButton"))
	assert_true(actions.visible)
	assert_true(day_off_btn.visible)
	assert_false(day_off_btn.disabled)
	s.refusing = true
	panel.refresh()
	assert_eq(day_off_btn.tooltip_text, "Refusing work")
	assert_true(day_off_btn.disabled)
	selection.select_building(_state.buildings.all_of_type("command_center")[0].uid)
	assert_false(actions.visible, "building selection removes the survivor action row")
	panel.free()
	selection.free()

func test_info_panel_cc_feast_cost_and_reason() -> void:
	var selection := SelectionController.new()
	selection.bind(_state)
	var panel := load("res://scenes/ui/info_panel.tscn").instantiate() as InfoPanel
	panel.bind(_state, selection)
	var cc: Building = _state.buildings.all_of_type("command_center")[0]
	selection.select_building(cc.uid)
	var feast_btn: Button = panel.get_node("PanelContainer/VBoxContainer/FeastButton") as Button
	assert_true(feast_btn.visible)
	assert_eq(feast_btn.text, "Hold a feast (-8 food)")
	assert_false(feast_btn.disabled, "day 1 feast is affordable")
	_state.last_feast_day = _state.clock.day
	panel.refresh()
	assert_true(feast_btn.disabled)
	assert_eq(feast_btn.tooltip_text, "Next feast: day 4")
	panel.free()
	selection.free()

func test_how_to_play_has_morale_paragraph() -> void:
	var screen := load("res://scenes/ui/how_to_play.tscn").instantiate() as HowToPlay
	screen.bind(_data)
	assert_eq(screen.get_node("Dim/Center/Panel/Margin/Content/Scroll/Sections/Morale").text, HowToPlay.morale_text())
	assert_true(HowToPlay.morale_text().begins_with("Morale."))
	screen.free()
