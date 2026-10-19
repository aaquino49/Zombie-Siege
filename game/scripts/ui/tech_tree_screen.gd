class_name TechTreeScreen extends CanvasLayer
## Research never owns simulation pause. Modal owners retain that responsibility.

const MODALS: Array[String] = ["MainMenu", "PauseMenu", "SettingsScreen", "HowToPlay", "CreditsScreen", "DawnReport", "VictoryScreen", "GameOverScreen"]
var _state: GameState
var _overlay_root: Node
var cards: Dictionary = {}
var _header: Label
var _active: Label
var _bar: ProgressBar
var _pause: Button

func bind(state: GameState, overlay_root: Node = null) -> void:
	_state = state
	_overlay_root = overlay_root
	visible = false
	_build()
	# Close immediately on a modal transition, before another click can select.
	if _overlay_root:
		for path: String in MODALS:
			var modal: CanvasLayer = _overlay_root.get_node_or_null(path) as CanvasLayer
			if modal and not modal.visibility_changed.is_connected(_modal_changed):
				modal.visibility_changed.connect(_modal_changed)
	refresh()

func blocked() -> bool:
	if not _state or _state.game_over or (_state.won and not _state.endless):
		return true
	if _overlay_root:
		for path: String in MODALS:
			var modal: Node = _overlay_root.get_node_or_null(path)
			if modal and modal.get("visible") == true:
				return true
	return false

func _modal_changed() -> void:
	if blocked():
		close()

func open() -> bool:
	if blocked():
		return false
	visible = true
	refresh()
	return true

func close() -> void:
	visible = false

func toggle() -> void:
	if visible:
		close()
	else:
		open()

func choose(id: String) -> bool:
	if not visible or blocked():
		return false
	var accepted: bool = _state.tech.choose(id)
	refresh()
	return accepted

## Returns whether input is consumed; also usable in detached tests.
func handle_input(event: InputEvent) -> bool:
	if event.is_echo():
		return false
	if event.is_action_pressed("tech_tree"):
		toggle()
		return true
	if visible and event.is_action_pressed("cancel"):
		close()
		return true
	return false

func _input(event: InputEvent) -> void:
	if handle_input(event) and is_inside_tree():
		get_viewport().set_input_as_handled()

static func working_researchers(state: GameState) -> Array[Survivor]:
	var workers: Array[Survivor] = []
	if state.clock.phase != GameClock.Phase.DAY:
		return workers
	for s: Survivor in state.survivors.all():
		if s.job != Survivor.Job.RESEARCHER or s.activity != Survivor.Activity.RESEARCHING or s.is_moving() or s.away or s.sheltered or s.refusing or s.day_off or state.expeditions.is_running(s):
			continue
		var lab: Building = state.buildings.get_by_uid(s.work_uid)
		if lab and lab.complete and lab.type_id == "field_lab" and Grid.in_ring(s.tile(), lab.origin, lab.size):
			workers.append(s)
	return workers

static func rate_per_day(state: GameState) -> float:
	var rate: float = 0.0
	for s: Survivor in working_researchers(state):
		var hunger: float = float(state.data.balance("food_hungry_speed")) if s.is_hungry() else 1.0
		rate += float(state.tech.data.rp_per_researcher_per_day) * hunger * Morale.work_mult(state, s)
	return rate

static func header_text(state: GameState) -> String:
	var bank: String = "Banked %d RP" % floori(state.tech.banked)
	if state.buildings.all_of_type("field_lab").filter(func(b: Building) -> bool: return b.complete).is_empty():
		return bank + " · Build a Field Lab and assign Researchers."
	return "%s · %d Researchers (+%s RP/day at current speed)" % [bank, working_researchers(state).size(), TechUpgradeCard.number(rate_per_day(state))]

func refresh() -> void:
	if not _state or _header == null:
		return
	if blocked():
		close()
	_header.text = header_text(_state)
	var id: String = _state.tech.active
	_pause.disabled = id == ""
	_bar.visible = id != ""
	_active.text = "No active research. Choose an available upgrade; saved progress is kept."
	if id != "":
		var upgrade: Dictionary = _state.tech.data.upgrades[id]
		_active.text = "Researching: %s · %d / %d RP" % [upgrade.name, floori(float(_state.tech.progress.get(id, 0.0))), int(upgrade.cost)]
		_bar.max_value = int(upgrade.cost)
		_bar.value = float(_state.tech.progress.get(id, 0.0))
	for card: TechUpgradeCard in cards.values():
		card.refresh(_state)

func _process(_delta: float) -> void:
	if visible:
		refresh()

func _label(text: String, font_size: int = UiFont.BODY) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", MenuStyle.CREAM)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", UiFont.BODY)
	button.pressed.connect(callback)
	return button

func _build() -> void:
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 32
	panel.offset_right = -32
	panel.offset_top = 56
	panel.offset_bottom = -16
	dim.add_child(panel)
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	margin.add_child(content)
	var heading := HBoxContainer.new()
	content.add_child(heading)
	var title: Label = _label("Research", UiFont.TITLE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	_pause = _button("Pause research", func() -> void: choose(""))
	heading.add_child(_pause)
	heading.add_child(_button("Close [T / Esc]", close))
	_header = _label("")
	content.add_child(_header)
	_active = _label("")
	content.add_child(_active)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size.y = 8
	content.add_child(_bar)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var columns := HBoxContainer.new()
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 12)
	scroll.add_child(columns)
	for branch: Dictionary in _state.tech.data.branches:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.size_flags_stretch_ratio = 1.0
		column.add_theme_constant_override("separation", 4)
		columns.add_child(column)
		var branch_heading := HBoxContainer.new()
		column.add_child(branch_heading)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(32, 32)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.texture = load("res://assets/pixel/ui/%s.png" % branch.icon) as Texture2D
		branch_heading.add_child(icon)
		var branch_label: Label = _label(str(branch.name), UiFont.LARGE)
		branch_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		branch_heading.add_child(branch_label)
		var ids: Array[String] = []
		for id: String in _state.tech.data.upgrades:
			if _state.tech.data.upgrades[id].branch == branch.id:
				ids.append(id)
		ids.sort_custom(func(a: String, b: String) -> bool: return int(_state.tech.data.upgrades[a].tier) < int(_state.tech.data.upgrades[b].tier))
		for i: int in range(ids.size()):
			if i > 0:
				var connector := ColorRect.new()
				connector.color = MenuStyle.NEUTRAL
				connector.custom_minimum_size = Vector2(2, 6)
				connector.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				column.add_child(connector)
			var card := TechUpgradeCard.new()
			card.configure(_state, ids[i])
			card.pressed.connect(choose.bind(ids[i]))
			column.add_child(card)
			cards[ids[i]] = card
