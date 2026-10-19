class_name RosterPanel extends CanvasLayer

const MAX_PANEL_HEIGHT: float = 420.0
const STATUS_MIN_TEXTS: Array[String] = ["Walking", "Gathering wood · Hungry", "Away till dusk"]
## Mood icons are 16 px sources shown at 2x (GDD 22.7).
const MOOD_ICON_SIZE: float = 32.0

var _state: GameState
var _selection: SelectionController

var _toggle_btn: Button
var _panel: PanelContainer
var _header: Label
var _scroll: ScrollContainer
var _vbox: VBoxContainer

static func mood_icon_path(band_id: String) -> String:
	return "res://assets/pixel/ui/icon_mood_%s.png" % band_id

## Short roster job labels in JobOptions order (index_for/apply are
## index-based, so assignment round-trips unchanged). Full labels stay in
## the info panel; the short faces keep the mood column inside 1280x720.
const ROSTER_JOB_LABELS: Array[String] = JobOptions.SHORT_LABELS

static func fill_job_options(btn: OptionButton) -> void:
	btn.clear()
	for label in ROSTER_JOB_LABELS:
		btn.add_item(label)

static func mood_band_id(state: GameState, s: Survivor) -> String:
	return str(Morale.band(state, s).get("id", "steady"))

static func mood_icon(band_id: String) -> Texture2D:
	if not _icon_cache.has(band_id):
		_icon_cache[band_id] = load(mood_icon_path(band_id)) as Texture2D
	return _icon_cache[band_id] as Texture2D

static var _icon_cache: Dictionary = {}

static func status_text(s: Survivor, state: GameState = null) -> String:
	return JobOptions.activity_text(s, state)

func bind(state: GameState, selection: SelectionController) -> void:
	_state = state
	_selection = selection

	_toggle_btn = get_node("ToggleButton")
	_toggle_btn.pressed.connect(toggle)

	_panel = get_node("PanelContainer")
	_header = _panel.get_node("VBox/HeaderLabel")
	_scroll = _panel.get_node("VBox/ScrollContainer")
	_vbox = _scroll.get_node("Rows")

	_state.survivors.survivor_added.connect(_on_survivors_changed)
	_state.survivors.survivor_removed.connect(_on_survivors_changed)

	_panel.hide()
	_rebuild_rows()

func _on_survivors_changed(_s: Survivor) -> void:
	_rebuild_rows()

func is_open() -> bool:
	return _panel.visible

func toggle() -> void:
	_panel.visible = not _panel.visible

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("roster"):
		toggle()
		get_viewport().set_input_as_handled()

func _make_mood_icon() -> TextureRect:
	var icon := TextureRect.new()
	icon.name = "MoodIcon"
	icon.custom_minimum_size = Vector2(MOOD_ICON_SIZE, MOOD_ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return icon

func _rebuild_rows() -> void:
	if not _state:
		return

	for c in _vbox.get_children():
		_vbox.remove_child(c)
		c.queue_free()

	var survivors: Array[Survivor] = _state.survivors.all()
	_header.text = "Survivors (%d)" % survivors.size()

	for s in survivors:
		var row: HBoxContainer = HBoxContainer.new()
		var uid: int = s.uid
		row.set_meta("uid", uid)
		row.add_theme_constant_override("separation", 2)

		var name_btn: Button = Button.new()
		name_btn.text = s.name
		name_btn.add_theme_font_size_override("font_size", UiFont.SMALL)
		name_btn.clip_text = false
		name_btn.custom_minimum_size.x = _button_text_width(name_btn, _state.data.balance("survivor_names"))
		name_btn.pressed.connect(func(): _selection.select_survivor(uid))
		row.add_child(name_btn)

		var job_btn: OptionButton = OptionButton.new()
		RosterPanel.fill_job_options(job_btn)
		job_btn.add_theme_font_size_override("font_size", UiFont.SMALL)
		job_btn.fit_to_longest_item = false
		job_btn.clip_text = false
		job_btn.custom_minimum_size.x = _button_text_width(job_btn, ROSTER_JOB_LABELS)
		job_btn.custom_minimum_size.x += job_btn.get_theme_icon("arrow").get_width()
		# Reserve themed arrow spacing so the longest label cannot grow its row.
		job_btn.custom_minimum_size.x += job_btn.get_theme_constant("arrow_margin") + job_btn.get_theme_constant("h_separation")
		job_btn.select(JobOptions.index_for(s))
		job_btn.item_selected.connect(func(idx: int): JobOptions.apply(_state, uid, idx))
		row.add_child(job_btn)

		var act_lbl: Label = Label.new()
		act_lbl.text = RosterPanel.status_text(s, _state)
		act_lbl.add_theme_font_size_override("font_size", UiFont.BODY)
		act_lbl.custom_minimum_size.x = _status_min_width(act_lbl)
		act_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		act_lbl.clip_text = true
		row.add_child(act_lbl)

		var scavenge_btn: Button = Button.new()
		scavenge_btn.name = "ScavengeButton"
		scavenge_btn.text = "Scavenge"
		scavenge_btn.add_theme_font_size_override("font_size", UiFont.SMALL)
		scavenge_btn.clip_text = true
		scavenge_btn.custom_minimum_size.x = 76
		scavenge_btn.pressed.connect(func(): _send_scavenging(uid))
		row.add_child(scavenge_btn)

		var mood_icon: TextureRect = _make_mood_icon()
		row.add_child(mood_icon)

		var mood_lbl: Label = Label.new()
		mood_lbl.name = "MoodNumber"
		mood_lbl.add_theme_font_size_override("font_size", UiFont.BODY)
		mood_lbl.custom_minimum_size.x = 40
		row.add_child(mood_lbl)

		var day_off_btn: Button = Button.new()
		day_off_btn.name = "DayOffButton"
		day_off_btn.text = "Day off"
		day_off_btn.add_theme_font_size_override("font_size", UiFont.SMALL)
		day_off_btn.clip_text = true
		day_off_btn.custom_minimum_size.x = 68
		day_off_btn.pressed.connect(func(): _give_day_off(uid))
		row.add_child(day_off_btn)

		_update_row(s, row)
		_vbox.add_child(row)

	# Reserve only the rows' height, with vertical scrolling for larger colonies.
	var chrome_height: float = _panel.get_theme_stylebox("panel").get_minimum_size().y
	chrome_height += _header.get_combined_minimum_size().y
	chrome_height += _header.get_parent().get_theme_constant("separation")
	var rows_height: float = maxf(survivors.size() - 1, 0) * _vbox.get_theme_constant("separation")
	for row in _vbox.get_children():
		rows_height += (row as Control).get_combined_minimum_size().y
	_scroll.custom_minimum_size.y = minf(rows_height, MAX_PANEL_HEIGHT - chrome_height)
	_panel.size.y = chrome_height + _scroll.custom_minimum_size.y

func _button_text_width(button: Button, texts: Array) -> float:
	var width: float = 0.0
	var font: Font = button.get_theme_font("font")
	for text: String in texts:
		width = maxf(width, font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFont.SMALL).x)
	return ceilf(width + button.get_theme_stylebox("normal").get_minimum_size().x)

func _status_min_width(label: Label) -> float:
	var font: Font = label.get_theme_font("font")
	var min_width: float = 0.0
	for text: String in STATUS_MIN_TEXTS:
		min_width = maxf(min_width, font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFont.BODY).x)
	return min_width

func _send_scavenging(uid: int) -> void:
	if _state:
		_state.expeditions.send(uid)
		refresh()

func _give_day_off(uid: int) -> void:
	if _state:
		Morale.give_day_off(_state, uid)
		refresh()

func _refresh_mood(s: Survivor, row: Node) -> void:
	var band_id: String = RosterPanel.mood_band_id(_state, s)
	var mood_icon: TextureRect = row.get_node("MoodIcon") as TextureRect
	var wanted: Texture2D = RosterPanel.mood_icon(band_id)
	if mood_icon.texture != wanted:
		mood_icon.texture = wanted
	mood_icon.tooltip_text = str(Morale.band(_state, s).get("name", band_id))
	var mood_lbl: Label = row.get_node("MoodNumber") as Label
	var number: String = str(s.morale)
	if mood_lbl.text != number:
		mood_lbl.text = number

func _update_row(s: Survivor, row: Node) -> void:
	var name_btn: Button = row.get_child(0)
	var job_btn: OptionButton = row.get_child(1)
	var act_lbl: Label = row.get_child(2)
	var scavenge_btn: Button = row.get_node("ScavengeButton") as Button
	var day_off_btn: Button = row.get_node("DayOffButton") as Button
	_refresh_mood(s, row)
	act_lbl.text = "Away till dusk" if s.away else RosterPanel.status_text(s, _state)
	act_lbl.tooltip_text = "Away (back at nightfall)" if s.away else act_lbl.text
	if s.away:
		scavenge_btn.hide()
		day_off_btn.hide()
		name_btn.disabled = true
		job_btn.disabled = true
		return
	name_btn.disabled = false
	job_btn.disabled = _state.expeditions.is_running(s)
	var reason: String = _state.expeditions.can_send(s)
	if reason == "dead":
		scavenge_btn.hide()
	else:
		scavenge_btn.show()
		scavenge_btn.disabled = reason != ""
		scavenge_btn.tooltip_text = ScavengeToast.reason_text(reason)
	day_off_btn.show()
	var off_reason: String = Morale.day_off_block_reason(_state, s)
	day_off_btn.disabled = off_reason != ""
	day_off_btn.tooltip_text = off_reason

func refresh() -> void:
	if not _state or not is_open():
		return

	var survivors: Array[Survivor] = _state.survivors.all()
	var rows: Array[Node] = _vbox.get_children()

	if survivors.size() != rows.size():
		_rebuild_rows()
		return

	for i in range(survivors.size()):
		var s: Survivor = survivors[i]
		var row: Node = rows[i]
		if not row.has_meta("uid") or int(row.get_meta("uid")) != s.uid:
			_rebuild_rows()
			return

	for i in range(survivors.size()):
		var s: Survivor = survivors[i]
		var row: Node = rows[i]

		var name_btn: Button = row.get_child(0)
		var job_btn: OptionButton = row.get_child(1)
		var act_lbl: Label = row.get_child(2)

		if name_btn.text != s.name:
			name_btn.text = s.name

		var job_idx: int = JobOptions.index_for(s)
		if job_btn.selected != job_idx:
			job_btn.select(job_idx)
		job_btn.tooltip_text = JobOptions.LABELS[job_idx]

		if not s.away:
			var act: String = RosterPanel.status_text(s, _state)
			if act_lbl.text != act:
				act_lbl.text = act
		_update_row(s, row)

func _process(_delta: float) -> void:
	refresh()
